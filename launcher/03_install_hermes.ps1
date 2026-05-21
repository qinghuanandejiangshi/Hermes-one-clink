# =============================================================================
# 03_install_hermes.ps1 — 在 WSL2 Ubuntu 中安装 Hermes Agent
#
# 步骤:
#   1. 检测 hermes 命令是否已存在 → 跳过
#   2. 更新 apt 源（使用阿里云镜像加速）
#   3. 安装 curl 依赖
#   4. 运行官方 install.sh
#   5. 验证安装结果
#
# 依赖: utils.ps1 已被 dot-source；Ubuntu 已安装（step=2 完成）
# =============================================================================

function Install-Hermes {
    param(
        [Parameter(Mandatory)][string]$ScriptDir,
        [Parameter(Mandatory)][string]$RootDir,
        [Parameter(Mandatory)][string]$ProgressFile
    )

    # ── 1. 检测是否已安装 ───────────────────────────────────────────────────
    Write-Log "检测 Hermes Agent 是否已安装..." -Level "INFO"
    if (_Test-HermesInstalled) {
        Write-Log "Hermes Agent 已安装，跳过。" -Level "SUCCESS"
        return
    }

    # ── 2. 替换 apt 源为阿里云镜像（加速国内下载，兼容所有 Ubuntu 版本）────
    Write-Log "配置 apt 阿里云镜像源（加速国内网络）..." -Level "INFO"
    # 用 sed 替换 URL，不依赖版本代号，ubuntu 22.04/24.04 均适用
    $setMirrorCmd = @'
cp /etc/apt/sources.list /etc/apt/sources.list.bak 2>/dev/null || true
sed -i 's|http://archive.ubuntu.com|https://mirrors.aliyun.com|g' /etc/apt/sources.list
sed -i 's|http://security.ubuntu.com|https://mirrors.aliyun.com|g' /etc/apt/sources.list
# Ubuntu 24.04+ 使用 sources.list.d/ubuntu.sources (DEB822 格式)
if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
    sed -i 's|http://archive.ubuntu.com|https://mirrors.aliyun.com|g' /etc/apt/sources.list.d/ubuntu.sources
    sed -i 's|http://security.ubuntu.com|https://mirrors.aliyun.com|g' /etc/apt/sources.list.d/ubuntu.sources
fi
'@
    Invoke-WSL -Command $setMirrorCmd
    Write-Log "apt 镜像源配置完成。" -Level "SUCCESS"

    # ── 3. 更新 apt 并安装依赖 ──────────────────────────────────────────────
    Write-Log "更新 apt 包索引..." -Level "INFO"
    Invoke-WSL -Command "apt-get update -qq"

    Write-Log "安装 curl、git、python3-pip、unzip..." -Level "INFO"
    Invoke-WSL -Command "DEBIAN_FRONTEND=noninteractive apt-get install -y curl git python3-pip unzip -q"

    # ── 4. 安装 uv（pip + 阿里云 PyPI，完全不依赖 GitHub）──────────────────
    Write-Log "安装 uv 包管理器（pip + 阿里云 PyPI 镜像）..." -Level "INFO"
    Invoke-WSL -Command "pip3 install uv --break-system-packages -q -i https://mirrors.aliyun.com/pypi/simple/ --trusted-host mirrors.aliyun.com"

    # ── 5. 安装 Hermes Agent（优先离线 ZIP，次选 PyPI 在线）─────────────────
    $resourcesDir = Join-Path $RootDir "resources"
    $hermesZip    = Join-Path $resourcesDir "hermes-agent.zip"

    if (Test-Path $hermesZip) {
        # ── 5a. 离线安装：从 U 盘内置 ZIP ──────────────────────────────
        Write-Log "检测到离线包 resources/hermes-agent.zip，使用本地安装..." -Level "INFO"
        # 先把 ZIP 复制到纯 ASCII 路径（避免中文路径在 bash 中乱码）
        $asciiZip = 'C:\Windows\Temp\hermes-agent.zip'
        Copy-Item $hermesZip -Destination $asciiZip -Force
        Write-Log "ZIP 已复制到 $asciiZip" -Level "INFO"

        $offlineCmd = @'
rm -rf /tmp/hermes-src
mkdir -p /tmp/hermes-src
unzip -qo /mnt/c/Windows/Temp/hermes-agent.zip -d /tmp/hermes-src/
HDIR=$(ls /tmp/hermes-src/ | head -1)
if [ -z "$HDIR" ]; then echo 'ZIP解压失败' >&2; exit 1; fi
# 保留源码到 ~/hermes-agent，供 hermes-webui 的 start.sh 自动发现
rm -rf ~/hermes-agent
cp -r "/tmp/hermes-src/$HDIR" ~/hermes-agent
cd ~/hermes-agent
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
export UV_INDEX_URL=https://mirrors.aliyun.com/pypi/simple/
uv tool install . 2>&1
# 从 hermes 可执行文件的 shebang 读取真实 Python 路径，创建 venv 软链接
UVPY_PATH=$(head -1 "$HOME/.local/bin/hermes" 2>/dev/null | sed 's/#!//;s/[[:space:]]//g')
if [ -n "$UVPY_PATH" ] && [ -x "$UVPY_PATH" ]; then
    UVTOOL=$(dirname "$(dirname "$UVPY_PATH")")
    ln -sfn "$UVTOOL" ~/hermes-agent/venv
    echo "[OK] venv -> $UVTOOL  (Python: $UVPY_PATH)"
else
    echo "[WARN] 无法从 hermes shebang 确定 uv 工具路径，shebang=$(head -1 $HOME/.local/bin/hermes 2>/dev/null)"
fi
PATH="$HOME/.local/bin:/usr/local/bin:$PATH" which hermes && echo "[OK] hermes installed: $(PATH=$HOME/.local/bin:/usr/local/bin:$PATH which hermes)"
'@
        Invoke-WSL -Command $offlineCmd
    } else {
        # ── 5b. 在线安装：通过 PyPI 镜像 ──────────────────────────────────
        Write-Log "未找到离线包，尝试 PyPI 在线安装 hermes-agent..." -Level "INFO"
        Write-Log "  提示：在有网络的环境下载 github.com/NousResearch/hermes-agent 的 ZIP" -Level "INFO"
        Write-Log "  保存到 resources/hermes-agent.zip 后可实现离线安装，无需 GitHub 访问。" -Level "INFO"

        _Prepare-WslNetwork

        $onlineCmd = @'
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
export UV_INDEX_URL=https://mirrors.aliyun.com/pypi/simple/
uv tool install hermes-agent 2>&1 || uv tool install hermes-agent --index-url https://pypi.tuna.tsinghua.edu.cn/simple/ 2>&1
'@
        Invoke-WSL -Command $onlineCmd
    }

    # ── 5. 验证安装 ──────────────────────────────────────────────────────────────
    Write-Log "验证 Hermes Agent 安装..." -Level "INFO"
    # 直接检查文件是否存在，不依赖 PATH（which 在非交互 bash 里找不到 /root/.local/bin）
    $checkOut = (& wsl -d Ubuntu -u root -- bash -c 'ls /root/.local/bin/hermes 2>/dev/null' 2>$null) -join ""
    Write-Log "  hermes 路径 → $checkOut" -Level "INFO"

    if (-not (_Test-HermesInstalled)) {
        throw @"
Hermes Agent 安装失败。
解决方案（任选一种）:
  [A] 将 resources/hermes-agent.zip 放入 U 盘目录（推荐）:
      1. 在有 VPN 的设备上打开： github.com/NousResearch/hermes-agent
      2. 点「 Code 」→「 Download ZIP 」
      3. 将 ZIP 改名为 hermes-agent.zip ，放入 resources/ 目录
      4. 重新运行安装
  [B] 在 Clash/V2Ray 中开启「允许局域网」，然后重运行安装
"@
    }
    Write-Log "Hermes Agent 安装验证通过！" -Level "SUCCESS"
}

# ── 私有辅助函数 ─────────────────────────────────────────────────────────────

function _Test-HermesInstalled {
    try {
        # 直接检查文件是否存在，不依赖 PATH
        $out = (& wsl -d Ubuntu -u root -- bash -c 'test -x /root/.local/bin/hermes && echo HERMES_OK' 2>$null) -join ""
        return $out -match "HERMES_OK"
    } catch {
        return $false
    }
}

function _Prepare-WslNetwork {
    Write-Log "配置 WSL 网络加速..." -Level "INFO"

    # 清理可能残留的旧代理配置，避免错误 curlrc 干扰
    Invoke-WSL -Command "rm -f /root/.curlrc /etc/profile.d/hermes-proxy.sh"

    # A. 检测 Windows localhost 代理（Clash/V2Ray），转发给 WSL2
    $reg = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction SilentlyContinue
    if ($reg.ProxyEnable -eq 1 -and $reg.ProxyServer -match '(?:127\.0\.0\.1|localhost):(\d+)') {
        $proxyPort = $Matches[1]
        # 从默认路由获取 Windows 宿主机 IP（NAT 模式下为默认网关）
        # /etc/resolv.conf 的 nameserver 可能是 WSL DNS 服务 IP，不是宿主机 IP
        $hostIpCmd = "ip route show default | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1"
        $hostIp = (& wsl -d Ubuntu -- bash -c $hostIpCmd 2>$null) |
            Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -Last 1

        if ($hostIp -and $hostIp.Trim() -match '^\d+\.\d+\.\d+\.\d+$') {
            $ip   = $hostIp.Trim()
            # 测试代理端口是否真的可从 WSL2 连通
            # Clash/V2Ray 默认只监听 127.0.0.1，不监听 WSL2 网关地址，需开「允许局域网」
            $tcpTest  = "(echo >/dev/tcp/$ip/$proxyPort) 2>/dev/null && echo PROXY_OK || echo PROXY_FAIL"
            $tcpResult = (& wsl -d Ubuntu -- bash -c $tcpTest 2>$null) -join ""

            if ($tcpResult -match 'PROXY_OK') {
                $p = "http://${ip}:${proxyPort}"
                Invoke-WSL -Command "echo 'proxy = $p' > /root/.curlrc"
                $writeProxy = @"
echo '#!/bin/sh' > /etc/profile.d/hermes-proxy.sh
echo 'export http_proxy=$p' >> /etc/profile.d/hermes-proxy.sh
echo 'export https_proxy=$p' >> /etc/profile.d/hermes-proxy.sh
echo 'export HTTP_PROXY=$p' >> /etc/profile.d/hermes-proxy.sh
echo 'export HTTPS_PROXY=$p' >> /etc/profile.d/hermes-proxy.sh
chmod +x /etc/profile.d/hermes-proxy.sh
"@
                Invoke-WSL -Command $writeProxy
                Write-Log "Windows 代理已转发至 WSL: $p" -Level "SUCCESS"
            } else {
                Write-Log "[!] 代理端口 ${ip}:${proxyPort} 从 WSL2 无法连通！" -Level "WARN"
                Write-Log "    原因: Clash/V2Ray 默认只监听 127.0.0.1，不监听 WSL2 网关地址。" -Level "WARN"
                Write-Log "    解决: 在 Clash / V2Ray / 其他代理工具中开启「允许局域网」(Allow LAN) 选项，" -Level "WARN"
                Write-Log "          然后重新运行安装。当前将仅使用 ghproxy 国内镜像继续。" -Level "WARN"
            }
        } else {
            Write-Log "无法从默认路由获取宿主机 IP，跳过代理转发（将直接使用 ghproxy 镜像）" -Level "WARN"
        }
    }

    # B. 配置 git 使用国内 GitHub 镜像（双重保障）
    $gitCmd = @'
git config --global url."https://mirror.ghproxy.com/https://github.com/".insteadOf "https://github.com/"
git config --global url."https://mirror.ghproxy.com/https://raw.githubusercontent.com/".insteadOf "https://raw.githubusercontent.com/"
'@
    Invoke-WSL -Command $gitCmd
    Write-Log "git GitHub 镜像已配置 (mirror.ghproxy.com)" -Level "SUCCESS"
}

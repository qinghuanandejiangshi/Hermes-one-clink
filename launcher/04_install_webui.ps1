# =============================================================================
# 04_install_webui.ps1 — 在 WSL2 Ubuntu 中安装 hermes-webui
#
# 步骤:
#   1. 检测 ~/hermes-webui 是否已存在 → 跳过
#   2. 从 resources/hermes-webui.zip 离线解压（避免访问 GitHub）
#   3. 使用 ~/hermes-agent/venv 中的 pip 安装 Python 依赖（阿里云镜像）
#   4. 确保 start.sh / ctl.sh 有执行权限
#
# 依赖: utils.ps1 已被 dot-source；Hermes Agent 已安装（step=3 完成）
# =============================================================================

function Install-WebUI {
    param(
        [Parameter(Mandatory)][string]$ScriptDir,
        [Parameter(Mandatory)][string]$RootDir,
        [Parameter(Mandatory)][string]$ProgressFile
    )

    $webuiZip = Join-Path $RootDir "resources\hermes-webui.zip"

    # ── 1. 检测是否已存在 ───────────────────────────────────────────────────
    Write-Log "检测 hermes-webui 是否已安装..." -Level "INFO"
    if (_Test-WebUIInstalled) {
        Write-Log "hermes-webui 已存在，跳过解压。" -Level "SUCCESS"
        _Ensure-WebUIDeps
        return
    }

    # ── 2. 从本地 ZIP 离线安装 ────────────────────────────────────────────
    if (-not (Test-Path $webuiZip)) {
        throw "未找到 resources\hermes-webui.zip。请将 hermes-webui 的 ZIP 放入 resources/ 目录后重试。"
    }

    Write-Log "检测到离线包 resources/hermes-webui.zip，使用本地安装..." -Level "INFO"
    $asciiZip = 'C:\Windows\Temp\hermes-webui.zip'
    Copy-Item $webuiZip -Destination $asciiZip -Force
    Write-Log "ZIP 已复制到 $asciiZip" -Level "INFO"

    $installCmd = @'
rm -rf /tmp/webui-src
mkdir -p /tmp/webui-src
unzip -qo /mnt/c/Windows/Temp/hermes-webui.zip -d /tmp/webui-src/
WDIR=$(ls /tmp/webui-src/ | head -1)
if [ -z "$WDIR" ]; then echo 'WebUI ZIP 解压失败' >&2; exit 1; fi
rm -rf ~/hermes-webui
cp -r "/tmp/webui-src/$WDIR" ~/hermes-webui
rm -rf /tmp/webui-src
chmod +x ~/hermes-webui/start.sh ~/hermes-webui/ctl.sh 2>/dev/null || true
echo "hermes-webui 已安装到 ~/hermes-webui"
'@
    Invoke-WSL -Command $installCmd

    if (-not (_Test-WebUIInstalled)) {
        throw "hermes-webui 解压失败，~/hermes-webui 目录不存在。"
    }
    Write-Log "hermes-webui 安装成功！" -Level "SUCCESS"

    # ── 3. 安装依赖 ──────────────────────────────────────────────────────────
    _Ensure-WebUIDeps
}

# ── 私有辅助函数 ─────────────────────────────────────────────────────────────

function _Test-WebUIInstalled {
    $out = & wsl -d Ubuntu -u root -- bash -c "test -d ~/hermes-webui && echo yes" 2>$null
    return ($out -join "") -match "yes"
}

function _Ensure-WebUIDeps {
    Write-Log "安装 hermes-webui Python 依赖..." -Level "INFO"

    # 使用 ~/hermes-agent/venv 中的 pip（与 hermes-agent 共用同一 Python 环境，
    # 避免重复安装 openai/httpx 等大包；若 venv 不存在则回退到 pip3）
    $depsCmd = @'
cd ~/hermes-webui
# 优先使用 hermes-agent 的 venv Python
if [ -x ~/hermes-agent/venv/bin/pip ]; then
    PIP=~/hermes-agent/venv/bin/pip
else
    PIP=pip3
fi
if [ -f requirements.txt ]; then
    echo "使用 $PIP 安装依赖..."
    $PIP install -r requirements.txt \
        -i https://mirrors.aliyun.com/pypi/simple/ \
        --trusted-host mirrors.aliyun.com \
        -q 2>&1
else
    echo '[INFO] 未找到 requirements.txt，跳过 pip install'
fi
'@
    Invoke-WSL -Command $depsCmd

    Write-Log "hermes-webui 依赖安装完成。" -Level "SUCCESS"
}

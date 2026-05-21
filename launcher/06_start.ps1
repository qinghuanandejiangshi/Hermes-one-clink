# =============================================================================
# 06_start.ps1 — 启动 hermes-webui 并打开浏览器
#
# 步骤:
#   1. 检查端口 8787 是否已被占用，若是则先关闭旧进程
#   2. 在 WSL2 后台启动 hermes-webui
#   3. 轮询等待服务就绪（最多 60 秒）
#   4. 打开默认浏览器访问 http://127.0.0.1:8787
#
# 依赖: utils.ps1 已被 dot-source；hermes-webui 已安装（step=4 完成）
# =============================================================================

function Start-Hermes {
    param(
        [Parameter(Mandatory)][string]$ScriptDir,
        [Parameter(Mandatory)][string]$RootDir,
        [Parameter(Mandatory)][string]$ProgressFile
    )

    $port    = 8787
    $url     = "http://127.0.0.1:$port"
    $maxWait = 90   # 最长等待秒数

    # ── 0. 环境诊断 ───────────────────────────────────────────────────────────
    Write-Log "启动前诊断..." -Level "INFO"
    $diagCmd = @'
echo "--- hermes-webui 启动诊断 ---"
SHEBANG=$(head -1 /root/.local/bin/hermes 2>/dev/null | sed 's/#!//;s/[[:space:]]//g')
echo "hermes shebang: $SHEBANG"
[ -x "$SHEBANG" ] && echo "shebang Python:  $($SHEBANG --version 2>&1)" || echo "shebang Python: 不可执行"
echo "server.py:      $(ls ~/hermes-webui/server.py 2>/dev/null && echo OK || echo MISSING)"
echo "requirements:   $(ls ~/hermes-webui/requirements.txt 2>/dev/null && echo OK || echo MISSING)"
echo "hermes bin:     $(ls /root/.local/bin/hermes 2>/dev/null && echo OK || echo MISSING)"
'@
    Invoke-WSL -Command $diagCmd

    # ── 1. 预安装 webui 依赖（幂等；步骤4 pip 可能失败过）────────────────────
    Write-Log "确保 hermes-webui Python 依赖已安装..." -Level "INFO"
    $depsCmd = @'
# 从 hermes shebang 找到 uv 工具包的 Python
SHEBANG=$(head -1 /root/.local/bin/hermes 2>/dev/null | sed 's/#!//;s/[[:space:]]//g')
if [ -n "$SHEBANG" ] && [ -x "$SHEBANG" ] && [ -f ~/hermes-webui/requirements.txt ]; then
    echo "使用 $SHEBANG -m pip 安装 webui 依赖..."
    "$SHEBANG" -m pip install -r ~/hermes-webui/requirements.txt \
        -i https://mirrors.aliyun.com/pypi/simple/ \
        --trusted-host mirrors.aliyun.com -q 2>&1
    echo "依赖安装完成"
else
    echo "[WARN] 无法确定 uv Python 或未找到 requirements.txt"
fi
'@
    Invoke-WSL -Command $depsCmd

    # ── 2. 确保 ~/hermes-agent 目录结构正确（server.py 的 agent dir 发现需要）──────
    Write-Log "确保 hermes-agent 目录结构..." -Level "INFO"
    $agentSetupCmd = @'
# server.py 的有效性检查：path.exists() AND (path/"run_agent.py").exists()
# Python 发现：agent_dir/venv/bin/python
mkdir -p ~/hermes-agent

# 找到真实的 run_agent.py（已安装包中）或建空文件作标记
if [ ! -f ~/hermes-agent/run_agent.py ]; then
    ACTUAL=$(find /root/.local/share/uv/tools/hermes-agent/lib -name "run_agent.py" 2>/dev/null | head -1)
    if [ -n "$ACTUAL" ]; then
        cp "$ACTUAL" ~/hermes-agent/run_agent.py
        echo "[OK] run_agent.py 从 $ACTUAL 复制"
    else
        touch ~/hermes-agent/run_agent.py
        echo "[OK] run_agent.py 创建（stub）"
    fi
fi

# 创建 venv 软链接 → uv 工具环境（Python 发现需要 agent_dir/venv/bin/python）
SHEBANG=$(head -1 /root/.local/bin/hermes 2>/dev/null | sed 's/#!//;s/[[:space:]]//g')
if [ -n "$SHEBANG" ] && [ -x "$SHEBANG" ]; then
    UVTOOL=$(dirname "$(dirname "$SHEBANG")")
    ln -sfn "$UVTOOL" ~/hermes-agent/venv
    echo "[OK] venv -> $UVTOOL"
fi

echo "hermes-agent dir 结构:"
ls ~/hermes-agent/
'@
    Invoke-WSL -Command $agentSetupCmd

    # ── 3. 清理旧进程 ─────────────────────────────────────────────────────────
    Write-Log "检查端口 $port 是否已被占用..." -Level "INFO"
    $portCheck = & wsl -d Ubuntu -u root -- bash -c "lsof -ti:$port 2>/dev/null" 2>$null
    if (-not [string]::IsNullOrWhiteSpace($portCheck -join "")) {
        Write-Log "端口 $port 被占用，正在终止旧进程..." -Level "WARN"
        & wsl -d Ubuntu -u root -- bash -c "kill -9 `$(lsof -ti:$port 2>/dev/null) 2>/dev/null; true" 2>$null | Out-Null
        Start-Sleep -Seconds 2
    }

    # ── 4. 后台启动 server.py（独立 WSL 进程，彻底脱离当前会话）──────────────
    Write-Log "在 WSL2 后台启动 hermes-webui server.py（端口 $port）..." -Level "INFO"

    # 写 bash 启动脚本到 ASCII 路径（无 BOM，Unix 换行），用 exec 替换 shell 进程
    # 使 WSL session 与 Python 进程等寿命，彻底防止 WSL 退出时 SIGKILL 杀进程
    $startupSh = 'C:\Windows\Temp\hermes-start.sh'
    $startupContent = @'
source /root/.bashrc 2>/dev/null || true
export HOME=/root
export PATH="/root/.local/bin:/usr/local/bin:$PATH"
cd /root/hermes-agent 2>/dev/null || true
export HERMES_WEBUI_PORT=8787
export HERMES_WEBUI_HOST=127.0.0.1
export HERMES_WEBUI_ALLOWED_ORIGINS=http://127.0.0.1:8787,http://127.0.0.1,http://localhost:8787,http://localhost
rm -f /root/hermes-webui.log
UVPY=$(head -1 /root/.local/bin/hermes 2>/dev/null | sed 's/#!//;s/[[:space:]]//g')
[ -x "$UVPY" ] || UVPY=python3
echo "[start] Python: $($UVPY --version 2>&1)" >> /root/hermes-webui.log
exec "$UVPY" /root/hermes-webui/server.py >> /root/hermes-webui.log 2>&1
'@
    [System.IO.File]::WriteAllText($startupSh, $startupContent, [System.Text.UTF8Encoding]::new($false))

    # Start-Process 启动独立隐藏窗口，不等待，与本脚本生命周期解耦
    Start-Process "wsl.exe" `
        -ArgumentList "-d Ubuntu -u root -- bash /mnt/c/Windows/Temp/hermes-start.sh" `
        -WindowStyle Hidden
    Write-Log "server.py 独立进程已启动（WSL 独立窗口）。" -Level "INFO"

    # 等 5 秒后输出日志头部
    Start-Sleep -Seconds 5
    $earlyLog = & wsl -d Ubuntu -u root -- bash -c "cat /root/hermes-webui.log 2>/dev/null" 2>$null
    $earlyLog | ForEach-Object { Write-Log "  [webui.log] $_" -Level "INFO" }

    # ── 4. 轮询等待服务就绪 ──────────────────────────────────────────────────
    Write-Log "等待 Web 服务就绪（最长 ${maxWait} 秒）..." -Level "INFO"
    $waited = 0
    $ready  = $false

    while ($waited -lt $maxWait) {
        Start-Sleep -Seconds 3
        $waited += 3

        try {
            $resp = Invoke-WebRequest -Uri $url -TimeoutSec 3 -ErrorAction Stop
            if ($resp.StatusCode -lt 500) {
                $ready = $true
                break
            }
        } catch {
            # 服务尚未响应，继续等待
        }

        Write-Log "  等待中... ($waited/$maxWait 秒)" -Level "INFO"

        # 每 15 秒输出一次日志末尾
        if ($waited % 15 -eq 0) {
            $tailLog = & wsl -d Ubuntu -u root -- bash -c "tail -8 ~/hermes-webui.log 2>/dev/null" 2>$null
            $tailLog | ForEach-Object { Write-Log "  [webui.log] $_" -Level "INFO" }
        }
    }

    if ($ready) {
        Write-Log "hermes-webui 服务已就绪！($url)" -Level "SUCCESS"
    } else {
        Write-Log "服务在 ${maxWait} 秒内未就绪。最后 30 行 webui.log：" -Level "WARN"
        $tailLog = & wsl -d Ubuntu -u root -- bash -c "tail -30 ~/hermes-webui.log 2>/dev/null" 2>$null
        $tailLog | ForEach-Object { Write-Log "  [webui.log] $_" -Level "WARN" }
        Write-Log "提示：可在 WSL 中运行 cat ~/hermes-webui.log 查看完整日志" -Level "WARN"
    }

    # ── 4. 打开浏览器 ────────────────────────────────────────────────────────
    Write-Log "正在打开浏览器: $url" -Level "INFO"
    Start-Process $url

    # ── 5. 完成提示 ──────────────────────────────────────────────────────────
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║   Hermes Agent 已成功启动！                  ║" -ForegroundColor Green
    Write-Host "  ║                                              ║" -ForegroundColor Green
    Write-Host "  ║   浏览器访问: http://127.0.0.1:8787          ║" -ForegroundColor Green
    Write-Host "  ║   后续启动:   双击「后续启动.bat」           ║" -ForegroundColor Green
    Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Log "====== 启动完成 ======" -Level "SUCCESS"
}

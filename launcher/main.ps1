# =============================================================================
# main.ps1 — 主控编排脚本
# 依次执行各安装步骤，支持从断点续装
# 用法: powershell -File main.ps1 -ScriptDir <path> -RootDir <path>
# =============================================================================
param(
    [Parameter(Mandatory)][string]$ScriptDir,
    [Parameter(Mandatory)][string]$RootDir
)

# WSL 输出为 UTF-8，必须在此处统一设置，否则 PowerShell 用 GBK 解码导致乱码
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

# ── 初始化日志 ──────────────────────────────────────────────────────────────
$Global:LogFile = Join-Path $RootDir "logs\install.log"

# 引入公共工具（此后所有模块复用同一 Write-Log）
. "$ScriptDir\utils.ps1"

$ProgressFile = Join-Path $RootDir "progress.txt"

Show-Banner -Title "一键安装程序"
Write-Log "====== Hermes 安装程序启动 ======" -Level "STEP"
Write-Log "根目录   : $RootDir"   -Level "INFO"
Write-Log "脚本目录 : $ScriptDir" -Level "INFO"
Write-Log "日志文件 : $Global:LogFile" -Level "INFO"

# ── Step 0: 前置环境检测（每次都运行，不受断点影响）────────────────────────
Write-Log "──────────────────────────────────" -Level "INFO"
Write-Log "[0/6] 前置环境检测" -Level "STEP"
try {
    . "$ScriptDir\00_check_env.ps1"
    Invoke-EnvCheck
} catch {
    Show-ErrorAndExit "环境检测未通过: $_"
}

# ── 读取断点 ─────────────────────────────────────────────────────────────────
$currentStep = Get-Progress -ProgressFile $ProgressFile
Write-Log "当前断点: step=$currentStep（大于此步骤编号的步骤将被跳过）" -Level "INFO"

# ── 步骤定义表（顺序不可变）─────────────────────────────────────────────────
$steps = @(
    [ordered]@{ Id = 1; Name = "安装 WSL2";           Script = "01_install_wsl2.ps1";   Func = "Install-WSL2"    },
    [ordered]@{ Id = 2; Name = "安装 Ubuntu";          Script = "02_install_ubuntu.ps1"; Func = "Install-Ubuntu"  },
    [ordered]@{ Id = 3; Name = "安装 Hermes Agent";    Script = "03_install_hermes.ps1"; Func = "Install-Hermes"  },
    [ordered]@{ Id = 4; Name = "安装 Hermes WebUI";    Script = "04_install_webui.ps1";  Func = "Install-WebUI"   },
    [ordered]@{ Id = 5; Name = "配置 API Key";         Script = "05_configure.ps1";      Func = "Invoke-Configure"},
    [ordered]@{ Id = 6; Name = "启动并打开浏览器";     Script = "06_start.ps1";          Func = "Start-Hermes"    }
)

# ── 逐步执行 ─────────────────────────────────────────────────────────────────
foreach ($step in $steps) {

    if ($step.Id -le $currentStep) {
        Write-Log "[ 跳过 ] 步骤 [$($step.Id)/6] $($step.Name)（已完成）" -Level "INFO"
        continue
    }

    Write-Log "──────────────────────────────────" -Level "INFO"
    Write-Log "[ 开始 ] 步骤 [$($step.Id)/6] $($step.Name)" -Level "STEP"

    try {
        # 独立 dot-source 每个模块，隔离作用域避免函数名冲突
        . "$ScriptDir\$($step.Script)"

        # 调用模块主函数，传入公共参数
        & $step.Func `
            -ScriptDir    $ScriptDir `
            -RootDir      $RootDir `
            -ProgressFile $ProgressFile

        # 函数正常返回 → 保存断点
        Set-Progress -ProgressFile $ProgressFile -Step $step.Id
        Write-Log "[ 完成 ] 步骤 [$($step.Id)/6] $($step.Name)" -Level "SUCCESS"

    } catch {
        Write-Log "[DEBUG] 出错位置: $($_.InvocationInfo.PositionMessage)" -Level "ERROR"
        Write-Log "[DEBUG] 调用堆栈: $($_.ScriptStackTrace)" -Level "ERROR"
        Show-ErrorAndExit "步骤 [$($step.Id)/6] $($step.Name) 执行失败: $_"
    }
}

# ── 全部完成 ─────────────────────────────────────────────────────────────────
Write-Log "====== 所有步骤已完成！Hermes Agent 已就绪 ======" -Level "SUCCESS"
Write-Host ""
Write-Host "  下次启动请双击「后续启动.bat」即可。" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# start_only.ps1 — 后续启动入口（供「后续启动.bat」调用）
# 跳过所有安装步骤，直接执行启动逻辑
# =============================================================================
param(
    [Parameter(Mandatory)][string]$ScriptDir,
    [Parameter(Mandatory)][string]$RootDir
)

$Global:LogFile = Join-Path $RootDir "logs\install.log"

# WSL 输出为 UTF-8，必须统一设置，否则 PowerShell 用 GBK 解码导致乱码
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

. "$ScriptDir\utils.ps1"

Show-Banner -Title "启动器        "
Write-Log "====== Hermes 启动器 ======" -Level "STEP"

# 检测安装是否已完成（断点应为 6）
$ProgressFile = Join-Path $RootDir "progress.txt"
$step = Get-Progress -ProgressFile $ProgressFile

if ($step -lt 6) {
    Write-Log "检测到安装尚未完成（当前 step=$step），请先运行「一键启动.bat」完成安装。" -Level "ERROR"
    Write-Host ""
    Write-Host "  请先双击「一键启动.bat」完成完整安装！" -ForegroundColor Red
    Write-Host ""
    Write-Host "  按任意键退出..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# 检测 Ubuntu 是否运行
Write-Log "检测 WSL2 Ubuntu 状态..." -Level "INFO"
$wslStatus = & wsl --list --running 2>&1
Write-Log "WSL 运行中的发行版: $($wslStatus -join ', ')" -Level "INFO"

# 执行启动
try {
    . "$ScriptDir\06_start.ps1"
    Start-Hermes `
        -ScriptDir    $ScriptDir `
        -RootDir      $RootDir `
        -ProgressFile $ProgressFile
} catch {
    Write-Log "启动失败: $_" -Level "ERROR"
    Write-Host ""
    Write-Host "  启动失败，请查看日志: $Global:LogFile" -ForegroundColor Red
    Write-Host "  按任意键退出..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

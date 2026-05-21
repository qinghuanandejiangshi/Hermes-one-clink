# =============================================================================
# utils.ps1 — 公共工具函数（日志 / 断点 / 提示框）
# 所有模块通过 dot-source 引用本文件，不产生任何副作用
# =============================================================================

# ── 日志输出 ──────────────────────────────────────────────────────────────────
# $Global:LogFile 必须在 main.ps1 / start_only.ps1 中初始化后再 dot-source 本文件

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "STEP")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine   = "[$timestamp][$Level] $Message"

    # 控制台带颜色输出
    switch ($Level) {
        "INFO"    { Write-Host $logLine -ForegroundColor Cyan }
        "WARN"    { Write-Host $logLine -ForegroundColor Yellow }
        "ERROR"   { Write-Host $logLine -ForegroundColor Red }
        "SUCCESS" { Write-Host $logLine -ForegroundColor Green }
        "STEP"    { Write-Host "`n$logLine" -ForegroundColor Magenta }
    }

    # 写入日志文件（FileShare.ReadWrite 防止与编辑器并发冲突）
    if ($Global:LogFile) {
        $logDir = Split-Path $Global:LogFile
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        try {
            $fs = [System.IO.FileStream]::new(
                $Global:LogFile,
                [System.IO.FileMode]::Append,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::ReadWrite
            )
            $sw = [System.IO.StreamWriter]::new($fs, [System.Text.Encoding]::UTF8)
            $sw.WriteLine($logLine)
            $sw.Flush()
            $sw.Dispose()
        } catch {
            # 日志写入失败时静默忽略，不中断安装
        }
    }
}

# ── 断点读写 ──────────────────────────────────────────────────────────────────

function Get-Progress {
    param([string]$ProgressFile)

    if (Test-Path $ProgressFile) {
        $raw = ([string](Get-Content $ProgressFile -Raw -Encoding UTF8)).Trim()
        if ($raw -match '^\d+$') { return [int]$raw }
    }
    return 0
}

function Set-Progress {
    param(
        [string]$ProgressFile,
        [int]$Step
    )
    Set-Content -Path $ProgressFile -Value $Step -Encoding UTF8
    Write-Log "断点已保存: step=$Step" -Level "INFO"
}

# ── Banner 显示 ──────────────────────────────────────────────────────────────

function Show-Banner {
    param([string]$Title = "一键安装程序")
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                                                      ║" -ForegroundColor Cyan
    Write-Host "  ║      HERMES  AGENT   智能助手   一键部署工具         ║" -ForegroundColor White
    Write-Host "  ║       Powered by NousResearch  |  Windows Edition    ║" -ForegroundColor DarkCyan
    Write-Host "  ║                                                      ║" -ForegroundColor Cyan
    Write-Host "  ╠══════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "  ║  发行人: 清华男德讲师                                ║" -ForegroundColor Yellow
    Write-Host "  ║  版  本: v1.0.0          Build: 2026.05             ║" -ForegroundColor DarkGray
    Write-Host "  ║  适用于: Windows 10 2004+  /  Windows 11             ║" -ForegroundColor DarkGray
    Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

# ── 错误终止（显示提示后等待按键退出）────────────────────────────────────────

function Show-ErrorAndExit {
    param([string]$Message)
    Write-Log $Message -Level "ERROR"
    Write-Host ""
    Write-Host "  !! 安装已终止。" -ForegroundColor Red
    if ($Global:LogFile) {
        Write-Host "  日志文件: $Global:LogFile" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "  按任意键退出..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# ── WSL 列表输出（正确读取 UTF-16LE 编码）───────────────────────────────────

function Get-WslListText {
    param([string]$Arguments = "--list --quiet")
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo "wsl"
        $psi.Arguments = $Arguments
        $psi.RedirectStandardOutput = $true
        $psi.UseShellExecute = $false
        $psi.StandardOutputEncoding = [System.Text.Encoding]::Unicode  # WSL 输出 UTF-16LE
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        $proc.Start() | Out-Null
        $output = $proc.StandardOutput.ReadToEnd()
        $proc.WaitForExit()
        return $output
    } catch {
        return ""
    }
}

# ── 带旋转进度条的命令执行 ────────────────────────────────────────────────────

function Invoke-WithSpinner {
    param(
        [string]$Message,
        [scriptblock]$ScriptBlock
    )
    $job = Start-Job -ScriptBlock $ScriptBlock
    $frames = @('|', '/', '-', '\')
    $i = 0
    Write-Host ""
    while ($job.State -eq 'Running') {
        $f = $frames[$i % 4]
        Write-Host "`r  [$f] $Message ..." -NoNewline -ForegroundColor Yellow
        $i++
        Start-Sleep -Milliseconds 200
    }
    $exitState = $job.State
    $output = Receive-Job -Job $job
    Remove-Job -Job $job -Force
    if ($exitState -eq 'Failed') {
        Write-Host "`r  [!] $Message  [失败]                    " -ForegroundColor Red
        Write-Host ""
        throw "后台任务执行失败"
    }
    Write-Host "`r  [√] $Message  [完成]                    " -ForegroundColor Green
    Write-Host ""
    return $output
}

# ── WSL 命令包装（统一记录输出） ──────────────────────────────────────────────

function Invoke-WSL {
    param(
        [string]$Command,
        [string]$Distro = "Ubuntu",
        [string]$User   = "root"
    )
    Write-Log "WSL[$Distro] 执行: $Command" -Level "INFO"
    # 规范化行尾（CRLF→LF）
    $Command = $Command.Replace("`r`n", "`n").Replace("`r", "`n")
    # 多行命令写入临时脚本文件执行：PowerShell 5.1 向原生命令传参时会截断多行字符串
    $tmpSh = $null
    if ($Command.Contains("`n")) {
        $tmpSh = 'C:\Windows\Temp\wsl-invoke.sh'
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($tmpSh, $Command, $utf8NoBom)
        $wslSh = '/mnt/c/Windows/Temp/wsl-invoke.sh'
    }
    # 用临时文件接管 stderr，防止 WSL NAT 警告触发 NativeCommandError
    $tmpErr = [System.IO.Path]::GetTempFileName()
    $prevEAP = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'SilentlyContinue'
        if ($tmpSh) {
            $output = & wsl -d $Distro -u $User -- bash $wslSh 2>$tmpErr
        } else {
            $output = & wsl -d $Distro -u $User -- bash -c $Command 2>$tmpErr
        }
        $ErrorActionPreference = $prevEAP
        $output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { Write-Log "  > $_" -Level "INFO" }
        if ($LASTEXITCODE -ne 0) {
            $rawErr = Get-Content $tmpErr -Raw -ErrorAction SilentlyContinue
            if (-not [string]::IsNullOrWhiteSpace($rawErr)) {
                Write-Log "  [stderr] $rawErr" -Level "WARN"
            }
        }
        return $output
    } finally {
        $ErrorActionPreference = $prevEAP
        Remove-Item $tmpErr -Force -ErrorAction SilentlyContinue
        if ($tmpSh) { Remove-Item $tmpSh -Force -ErrorAction SilentlyContinue }
    }
}

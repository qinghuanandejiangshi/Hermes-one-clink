# =============================================================================
# 01_install_wsl2.ps1 — 安装 / 检测 WSL2
#
# 断点设计:
#   ├─ WSL2 已可用           → 直接 return，progress 由 main.ps1 推进到 step=1
#   ├─ 功能已启用待重启      → 写 wsl_reboot.flag，弹窗提示重启，exit 0
#   │                          （progress 保持 step=0，重启后再次运行本步骤）
#   └─ 重启后重新进入本步骤  → 检测 flag + wsl --version 验证 → return
#
# 依赖: utils.ps1 已被 dot-source
# =============================================================================

function Install-WSL2 {
    param(
        [Parameter(Mandatory)][string]$ScriptDir,
        [Parameter(Mandatory)][string]$RootDir,
        [Parameter(Mandatory)][string]$ProgressFile
    )

    $flagFile = Join-Path $RootDir "wsl_reboot.flag"

    # ── Case A: WSL2 已完整可用 ──────────────────────────────────────────────
    Write-Log "检测 WSL2 是否已可用..." -Level "INFO"
    if (_Test-WSL2Ready) {
        Write-Log "WSL2 已安装且可用，跳过安装步骤。" -Level "SUCCESS"
        if (Test-Path $flagFile) { Remove-Item $flagFile -Force }
        return
    }

    # ── Case B: 重启后继续（flag 文件存在）──────────────────────────────────
    if (Test-Path $flagFile) {
        Write-Log "检测到 WSL2 安装重启标记，继续完成安装..." -Level "INFO"
        Write-Log "正在更新 WSL 内核..." -Level "INFO"

        $updateOut = & wsl --update 2>&1
        $updateOut | ForEach-Object { Write-Log "  > $_" -Level "INFO" }

        Write-Log "设置 WSL 默认版本为 2..." -Level "INFO"
        & wsl --set-default-version 2 2>&1 | ForEach-Object { Write-Log "  > $_" -Level "INFO" }

        # 验证
        if (_Test-WSL2Ready) {
            Remove-Item $flagFile -Force
            Write-Log "WSL2 安装完成（重启后续步骤）。" -Level "SUCCESS"
            return
        } else {
            throw "WSL2 重启后验证失败，请手动检查 WSL 状态后重试（wsl --version）。"
        }
    }

    # ── Case C: 首次安装 ────────────────────────────────────────────────────
    Write-Log "WSL2 未检测到，开始安装..." -Level "INFO"

    $build = [int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild
    $restartNeeded = $false

    if ($build -ge 19044) {
        # 现代方式（Win10 21H2+ / Win11）: wsl --install 一步到位
        Write-Log "使用现代安装方式 (wsl --install --no-distribution)..." -Level "INFO"
        $out = & wsl --install --no-distribution 2>&1
        $out | ForEach-Object { Write-Log "  > $_" -Level "INFO" }

        # 安装后直接测试 WSL2 是否可用；不可用则需重启
        # （WSL 输出 UTF-16LE，文本匹配不可靠，改用功能性检测）
        if (-not (_Test-WSL2Ready)) {
            $restartNeeded = $true
        }

    } else {
        # 传统方式（Win10 19041-19043）: 手动启用 Windows 功能
        Write-Log "使用传统方式启用 Windows 可选功能..." -Level "INFO"

        $r1 = Enable-WindowsOptionalFeature -Online `
              -FeatureName "Microsoft-Windows-Subsystem-Linux" `
              -NoRestart -ErrorAction Stop
        Write-Log "  WSL 功能: $($r1.State)" -Level "INFO"

        $r2 = Enable-WindowsOptionalFeature -Online `
              -FeatureName "VirtualMachinePlatform" `
              -NoRestart -ErrorAction Stop
        Write-Log "  虚拟机平台: $($r2.State)" -Level "INFO"

        if ($r1.RestartNeeded -or $r2.RestartNeeded) {
            $restartNeeded = $true
        }
    }

    if ($restartNeeded) {
        # 写 flag，保证重启后知道功能已启用
        Set-Content -Path $flagFile -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Encoding UTF8
        Write-Log "WSL2 功能已启用，需要重启系统才能生效。已写入重启标记: $flagFile" -Level "WARN"

        _Show-RestartDialog
        # _Show-RestartDialog 内部会 exit 0 或 Restart-Computer，不会返回
    }

    # 无需重启的情况：直接设置默认版本并验证
    Write-Log "设置 WSL 默认版本为 2..." -Level "INFO"
    & wsl --set-default-version 2 2>$null

    if (_Test-WSL2Ready) {
        Write-Log "WSL2 安装完成（无需重启）。" -Level "SUCCESS"
    } else {
        throw "WSL2 安装后验证失败，请重启电脑后重新运行安装程序。"
    }
}

# ── 私有辅助函数 ─────────────────────────────────────────────────────────────

function _Test-WSL2Ready {
    # 用 exit code 判断：wsl --version 在 WSL2 可用时返回 0
    # 避免解析 UTF-16LE 输出导致的乱码误判
    try {
        & wsl --version 2>&1 | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function _Show-RestartDialog {
    Add-Type -AssemblyName System.Windows.Forms

    $msg = "WSL2 功能已成功启用！`n`n" +
           "需要重启电脑才能继续安装。`n`n" +
           "重启后请重新双击「一键启动.bat」，`n" +
           "程序将自动从此处继续，无需重复操作。`n`n" +
           "是否立即重启？"

    $result = [System.Windows.Forms.MessageBox]::Show(
        $msg,
        "需要重启 | Hermes 安装程序",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )

    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        Write-Log "用户确认重启，5 秒后重启计算机..." -Level "WARN"
        Start-Sleep -Seconds 5
        Restart-Computer -Force
    } else {
        Write-Log "用户取消重启。请手动重启后重新运行「一键启动.bat」。" -Level "WARN"
        exit 0
    }
}

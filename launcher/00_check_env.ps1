# =============================================================================
# 00_check_env.ps1 — 前置环境检测
# 任何一项不满足则抛出异常，由 main.ps1 捕获并终止安装
# 依赖: utils.ps1 已被 dot-source
# =============================================================================

function Invoke-EnvCheck {

    # ── 1. 系统架构 ──────────────────────────────────────────────────────────
    Write-Log "检测系统架构..." -Level "INFO"
    $arch = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
    if ($arch -notlike "*64*") {
        throw "系统架构不受支持（当前: $arch）。WSL2 需要 64 位系统。"
    }
    Write-Log "系统架构: $arch  ✓" -Level "SUCCESS"

    # ── 2. Windows 版本（Build >= 19041 即 Windows 10 2004）────────────────
    Write-Log "检测 Windows 版本..." -Level "INFO"
    $buildStr = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild
    $build    = [int]$buildStr
    $winVer   = (Get-WmiObject Win32_OperatingSystem).Caption

    if ($build -lt 19041) {
        throw "Windows 版本过低（当前: $winVer, Build $build）。" +
              "需要 Windows 10 版本 2004（Build 19041）或更新版本。" +
              "请先升级系统后再运行本程序。"
    }
    Write-Log "Windows 版本: $winVer (Build $build)  ✓" -Level "SUCCESS"

    # ── 3. CPU 硬件虚拟化 ────────────────────────────────────────────────────
    Write-Log "检测 CPU 虚拟化（VT-x / AMD-V）..." -Level "INFO"
    $cpuVirt = $false
    try {
        $cpuVirt = (Get-WmiObject Win32_Processor).VirtualizationFirmwareEnabled
    } catch {
        Write-Log "无法通过 WMI 查询虚拟化状态，尝试备用方式..." -Level "WARN"
    }

    if (-not $cpuVirt) {
        # 备用：检查 Hyper-V 是否已经在运行（说明虚拟化已开启）
        $hvRunning = (Get-WmiObject Win32_ComputerSystem).HypervisorPresent
        if ($hvRunning) {
            Write-Log "检测到 Hyper-V 运行中，虚拟化已开启  ✓" -Level "SUCCESS"
        } else {
            throw "CPU 虚拟化未开启。`n`n" +
                  "请重启电脑，进入 BIOS/UEFI 设置：`n" +
                  "  · Intel CPU: 找到「Intel Virtualization Technology」选项，设为 Enabled`n" +
                  "  · AMD   CPU: 找到「SVM Mode」或「AMD-V」选项，设为 Enabled`n`n" +
                  "保存退出 BIOS 后，重新运行本程序。"
        }
    } else {
        Write-Log "CPU 虚拟化: 已开启  ✓" -Level "SUCCESS"
    }

    # ── 4. 系统盘剩余空间（要求 >= 5 GB）────────────────────────────────────
    Write-Log "检测系统盘剩余空间..." -Level "INFO"
    $sysDrive = $env:SystemDrive
    $disk     = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$sysDrive'"
    $freeGB   = [math]::Round($disk.FreeSpace / 1GB, 2)

    if ($freeGB -lt 5) {
        throw "系统盘（$sysDrive）空间不足（当前剩余: ${freeGB} GB）。" +
              "WSL2 + Ubuntu + Hermes 约需 4-5 GB，请清理磁盘后重试。"
    }
    Write-Log "系统盘剩余: ${freeGB} GB  ✓" -Level "SUCCESS"

    # ── 5. 内存（<= 4 GB 仅警告，不阻断安装）───────────────────────────────
    Write-Log "检测物理内存..." -Level "INFO"
    $ramGB = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
    if ($ramGB -lt 4) {
        Write-Log "内存较低（${ramGB} GB）。建议 4 GB 以上，程序可继续但运行可能较慢。" -Level "WARN"
    } else {
        Write-Log "物理内存: ${ramGB} GB  ✓" -Level "SUCCESS"
    }

    Write-Log "──── 环境检测全部通过 ────" -Level "SUCCESS"
}

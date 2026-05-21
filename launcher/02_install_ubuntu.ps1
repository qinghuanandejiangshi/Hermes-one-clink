# =============================================================================
# 02_install_ubuntu.ps1 — 在 WSL2 中安装 Ubuntu
#
# 步骤:
#   1. 检测 Ubuntu 是否已安装 → 跳过
#   2. 安装 Ubuntu 发行版
#   3. 初始化：设置默认用户为 root（避免交互式账户创建弹窗）
#
# 依赖: utils.ps1 已被 dot-source；WSL2 已安装（step=1 完成）
# =============================================================================

function Install-Ubuntu {
    param(
        [Parameter(Mandatory)][string]$ScriptDir,
        [Parameter(Mandatory)][string]$RootDir,
        [Parameter(Mandatory)][string]$ProgressFile
    )

    # ── 1. 检测 Ubuntu 是否已存在 ───────────────────────────────────────────
    Write-Log "检测 Ubuntu 是否已安装..." -Level "INFO"
    if (_Test-UbuntuInstalled) {
        Write-Log "Ubuntu 已安装，跳过。" -Level "SUCCESS"
        _Ensure-RootDefault
        return
    }

    # ── 2. 安装 Ubuntu ──────────────────────────────────────────────────────
    Write-Log "正在安装 Ubuntu（首次下载约 300-500 MB，请保持网络连接）..." -Level "INFO"
    Write-Log "提示: Ubuntu 从 Microsoft 服务器下载，进度由系统显示" -Level "INFO"

    # 当 wsl --install 运行时展示旋转进度条
    $installOut = Invoke-WithSpinner "正在下载并安装 Ubuntu" {
        & wsl --install -d Ubuntu 2>&1
    }
    $installOut | ForEach-Object { Write-Log "  > $_" -Level "INFO" }

    # 安装后次级检测，最多再等 2 分钟
    Write-Log "等待 Ubuntu 完全就绪..." -Level "INFO"
    $waited = 0; $maxWait = 120
    while ($waited -lt $maxWait) {
        Start-Sleep -Seconds 5
        $waited += 5
        if (_Test-UbuntuInstalled) { break }
        Write-Host "`r  [/] 等待中... ($waited / $maxWait 秒)" -NoNewline -ForegroundColor Yellow
    }
    Write-Host ""

    if (-not (_Test-UbuntuInstalled)) {
        throw "Ubuntu 安装超时或失败。请检查网络，或手动执行: wsl --install -d Ubuntu"
    }
    Write-Log "Ubuntu 安装成功！" -Level "SUCCESS"

    # ── 3. 初始化：设置 root 为默认用户 ─────────────────────────────────────
    _Ensure-RootDefault
}

# ── 私有辅助函数 ─────────────────────────────────────────────────────────────

function _Test-UbuntuInstalled {
    # 使用 Get-WslListText 正确解码 UTF-16LE，避免中文 Windows 下乱码误判
    try {
        $list = Get-WslListText "--list --quiet"
        return ($list -match "Ubuntu")
    } catch {
        return $false
    }
}

function _Ensure-RootDefault {
    # 设置 WSL Ubuntu 默认以 root 运行（免去交互式账户初始化）
    Write-Log "配置 Ubuntu 默认用户为 root..." -Level "INFO"

    # 写入 /etc/wsl.conf（如已存在则覆盖 [user] 节）
    $wslConf = "[user]`ndefault=root"
    & wsl -d Ubuntu -u root -- bash -c "echo '$wslConf' > /etc/wsl.conf" 2>$null

    # 重启 Ubuntu 使配置生效
    Write-Log "重新启动 Ubuntu WSL 实例..." -Level "INFO"
    & wsl --terminate Ubuntu 2>$null
    Start-Sleep -Seconds 3

    # 验证：whoami 应返回 root（过滤掉 WSL 的 NAT 警告行）
    $whoami = (& wsl -d Ubuntu -- bash -c "whoami" 2>$null) |
        Where-Object { $_.Trim() -ne '' } |
        Select-Object -Last 1
    Write-Log "当前 Ubuntu 用户: $whoami" -Level "INFO"

    Write-Log "Ubuntu 初始化完成。" -Level "SUCCESS"
}

# =============================================================================
# 05_configure.ps1 — API Key 配置界面（Windows Forms GUI）
#
# 弹出一个深色主题配置窗口，用户填写 API Key 后写入 WSL2 Ubuntu 的 ~/.bashrc
# 若已检测到配置则询问是否重新配置
#
# 依赖: utils.ps1 已被 dot-source；Hermes Agent 已安装（step=3 完成）
# =============================================================================

function Invoke-Configure {
    param(
        [Parameter(Mandatory)][string]$ScriptDir,
        [Parameter(Mandatory)][string]$RootDir,
        [Parameter(Mandatory)][string]$ProgressFile
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # ── 检测是否已配置过 API Key ─────────────────────────────────────────────
    Write-Log "检测现有 API Key 配置..." -Level "INFO"
    $existingKey = _Get-ExistingApiKey
    if ($existingKey) {
        Write-Log "检测到已有 API Key 配置（已脱敏）: $existingKey" -Level "INFO"
        $ans = [System.Windows.Forms.MessageBox]::Show(
            "检测到已有 API Key 配置。`n`n是否重新配置？（选「否」将跳过此步骤）",
            "API Key 配置 | Hermes",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($ans -eq [System.Windows.Forms.DialogResult]::No) {
            Write-Log "用户跳过 API Key 重新配置。" -Level "INFO"
            return
        }
    }

    # ── 构建配置窗口 ─────────────────────────────────────────────────────────
    $form                  = New-Object System.Windows.Forms.Form
    $form.Text             = "Hermes Agent — API Key 配置"
    $form.Size             = New-Object System.Drawing.Size(540, 520)
    $form.StartPosition    = "CenterScreen"
    $form.FormBorderStyle  = "FixedDialog"
    $form.MaximizeBox      = $false
    $form.BackColor        = [System.Drawing.Color]::FromArgb(28, 28, 28)
    $form.ForeColor        = [System.Drawing.Color]::White

    # 标题
    $lblTitle          = New-Object System.Windows.Forms.Label
    $lblTitle.Text     = "配置 API Key"
    $lblTitle.Font     = New-Object System.Drawing.Font("Microsoft YaHei UI", 16, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(24, 20)
    $lblTitle.Size     = New-Object System.Drawing.Size(480, 36)
    $lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(255, 200, 0)
    $form.Controls.Add($lblTitle)

    # 副标题
    $lblSub          = New-Object System.Windows.Forms.Label
    $lblSub.Text     = "请填写至少一个 AI 模型 API Key"
    $lblSub.Font     = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)
    $lblSub.Location = New-Object System.Drawing.Point(24, 62)
    $lblSub.Size     = New-Object System.Drawing.Size(480, 22)
    $lblSub.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
    $form.Controls.Add($lblSub)

    # ── OpenRouter Key ───────────────────────────────────────────────────────
    $lblOR          = New-Object System.Windows.Forms.Label
    $lblOR.Text     = "OpenRouter API Key  （推荐：免费模型可用，200+ 模型选择）"
    $lblOR.Font     = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)
    $lblOR.Location = New-Object System.Drawing.Point(24, 100)
    $lblOR.Size     = New-Object System.Drawing.Size(480, 20)
    $lblOR.ForeColor = [System.Drawing.Color]::White
    $form.Controls.Add($lblOR)

    $txtOR                  = New-Object System.Windows.Forms.TextBox
    $txtOR.Location         = New-Object System.Drawing.Point(24, 124)
    $txtOR.Size             = New-Object System.Drawing.Size(480, 28)
    $txtOR.Font             = New-Object System.Drawing.Font("Consolas", 9)
    $txtOR.BackColor        = [System.Drawing.Color]::FromArgb(45, 45, 45)
    $txtOR.ForeColor        = [System.Drawing.Color]::White
    $txtOR.BorderStyle      = "FixedSingle"
    $form.Controls.Add($txtOR)

    # OpenRouter 获取链接
    $lnkOR          = New-Object System.Windows.Forms.LinkLabel
    $lnkOR.Text     = "没有 Key？点此前往 openrouter.ai 免费注册获取"
    $lnkOR.Font     = New-Object System.Drawing.Font("Microsoft YaHei UI", 8)
    $lnkOR.Location = New-Object System.Drawing.Point(24, 156)
    $lnkOR.Size     = New-Object System.Drawing.Size(480, 18)
    $lnkOR.LinkColor = [System.Drawing.Color]::FromArgb(100, 160, 240)
    $lnkOR.Add_LinkClicked({ Start-Process "https://openrouter.ai/keys" })
    $form.Controls.Add($lnkOR)

    # ── OpenAI Key ───────────────────────────────────────────────────────────
    $lblOA          = New-Object System.Windows.Forms.Label
    $lblOA.Text     = "OpenAI API Key  （可选）"
    $lblOA.Font     = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)
    $lblOA.Location = New-Object System.Drawing.Point(24, 186)
    $lblOA.Size     = New-Object System.Drawing.Size(480, 20)
    $lblOA.ForeColor = [System.Drawing.Color]::White
    $form.Controls.Add($lblOA)

    $txtOA                  = New-Object System.Windows.Forms.TextBox
    $txtOA.Location         = New-Object System.Drawing.Point(24, 210)
    $txtOA.Size             = New-Object System.Drawing.Size(480, 28)
    $txtOA.Font             = New-Object System.Drawing.Font("Consolas", 9)
    $txtOA.BackColor        = [System.Drawing.Color]::FromArgb(45, 45, 45)
    $txtOA.ForeColor        = [System.Drawing.Color]::White
    $txtOA.BorderStyle      = "FixedSingle"
    $form.Controls.Add($txtOA)

    # ── DeepSeek Key ─────────────────────────────────────────────────────────
    $lblDS          = New-Object System.Windows.Forms.Label
    $lblDS.Text     = "DeepSeek API Key  （推荐国内用户使用）"
    $lblDS.Font     = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)
    $lblDS.Location = New-Object System.Drawing.Point(24, 250)
    $lblDS.Size     = New-Object System.Drawing.Size(480, 20)
    $lblDS.ForeColor = [System.Drawing.Color]::White
    $form.Controls.Add($lblDS)

    $txtDS                  = New-Object System.Windows.Forms.TextBox
    $txtDS.Location         = New-Object System.Drawing.Point(24, 274)
    $txtDS.Size             = New-Object System.Drawing.Size(480, 28)
    $txtDS.Font             = New-Object System.Drawing.Font("Consolas", 9)
    $txtDS.BackColor        = [System.Drawing.Color]::FromArgb(45, 45, 45)
    $txtDS.ForeColor        = [System.Drawing.Color]::White
    $txtDS.BorderStyle      = "FixedSingle"
    $form.Controls.Add($txtDS)

    $lnkDS          = New-Object System.Windows.Forms.LinkLabel
    $lnkDS.Text     = "没有 Key？点此前往 platform.deepseek.com 申请"
    $lnkDS.Font     = New-Object System.Drawing.Font("Microsoft YaHei UI", 8)
    $lnkDS.Location = New-Object System.Drawing.Point(24, 306)
    $lnkDS.Size     = New-Object System.Drawing.Size(480, 18)
    $lnkDS.LinkColor = [System.Drawing.Color]::FromArgb(100, 160, 240)
    $lnkDS.Add_LinkClicked({ Start-Process "https://platform.deepseek.com/api_keys" })
    $form.Controls.Add($lnkDS)

    # ── 提示文字 ─────────────────────────────────────────────────────────────
    $lblNote          = New-Object System.Windows.Forms.Label
    $lblNote.Text     = "* Key 将以环境变量形式存储于 WSL2 Ubuntu 中，不会上传至任何服务器`n* 后续可通过 hermes model 命令随时更换模型，或在 WebUI 侧边栏 Profiles 面板创建自定义 Endpoint（如 Kimi）"
    $lblNote.Font     = New-Object System.Drawing.Font("Microsoft YaHei UI", 8)
    $lblNote.Location = New-Object System.Drawing.Point(24, 334)
    $lblNote.Size     = New-Object System.Drawing.Size(480, 36)
    $lblNote.ForeColor = [System.Drawing.Color]::FromArgb(120, 120, 120)
    $form.Controls.Add($lblNote)

    # ── 按钮 ─────────────────────────────────────────────────────────────────
    $btnSave               = New-Object System.Windows.Forms.Button
    $btnSave.Text          = "保存并继续"
    $btnSave.Location      = New-Object System.Drawing.Point(24, 390)
    $btnSave.Size          = New-Object System.Drawing.Size(200, 44)
    $btnSave.Font          = New-Object System.Drawing.Font("Microsoft YaHei UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnSave.BackColor     = [System.Drawing.Color]::FromArgb(255, 200, 0)
    $btnSave.ForeColor     = [System.Drawing.Color]::Black
    $btnSave.FlatStyle     = "Flat"
    $btnSave.DialogResult  = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($btnSave)
    $form.AcceptButton     = $btnSave

    $btnSkip               = New-Object System.Windows.Forms.Button
    $btnSkip.Text          = "跳过（稍后手动配置）"
    $btnSkip.Location      = New-Object System.Drawing.Point(244, 390)
    $btnSkip.Size          = New-Object System.Drawing.Size(260, 44)
    $btnSkip.Font          = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)
    $btnSkip.BackColor     = [System.Drawing.Color]::FromArgb(55, 55, 55)
    $btnSkip.ForeColor     = [System.Drawing.Color]::LightGray
    $btnSkip.FlatStyle     = "Flat"
    $btnSkip.DialogResult  = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($btnSkip)

    # 帮助链接
    $lblHelp          = New-Object System.Windows.Forms.Label
    $lblHelp.Text     = "安装完成后可运行 hermes setup 重新进行完整配置"
    $lblHelp.Font     = New-Object System.Drawing.Font("Microsoft YaHei UI", 8)
    $lblHelp.Location = New-Object System.Drawing.Point(24, 448)
    $lblHelp.Size     = New-Object System.Drawing.Size(480, 18)
    $lblHelp.ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
    $form.Controls.Add($lblHelp)

    # ── 显示窗口并处理结果 ───────────────────────────────────────────────────
    $dialogResult = $form.ShowDialog()

    if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
        $orKey = $txtOR.Text.Trim()
        $oaKey = $txtOA.Text.Trim()
        $dsKey = $txtDS.Text.Trim()

        if ($orKey -or $oaKey -or $dsKey) {
            _Write-ApiKeys -OrKey $orKey -OaKey $oaKey -DsKey $dsKey
        } else {
            Write-Log "用户点击保存但未填写任何 Key，跳过配置。" -Level "WARN"
        }
    } else {
        Write-Log "用户跳过 API Key 配置（可稍后手动运行 hermes setup 完成）。" -Level "WARN"
    }
}

# ── 私有辅助函数 ─────────────────────────────────────────────────────────────

function _Get-ExistingApiKey {
    $out = & wsl -d Ubuntu -u root -- bash -c "grep -E 'OPENROUTER_API_KEY|OPENAI_API_KEY' ~/.bashrc 2>/dev/null | head -1" 2>&1
    $val = ($out -join "").Trim()
    if ($val) {
        # 脱敏：只显示前 8 位
        return ($val -replace '(sk-[a-zA-Z0-9]{0,8}).*', '$1****')
    }
    return $null
}

function _Write-ApiKeys {
    param([string]$OrKey, [string]$OaKey, [string]$DsKey)

    Write-Log "正在写入 API Key 到 WSL2 Ubuntu ~/.bashrc..." -Level "INFO"

    # 删除旧的 Key 行，重新写入
    $cleanCmd = "sed -i '/OPENROUTER_API_KEY\|OPENAI_API_KEY\|DEEPSEEK_API_KEY/d' ~/.bashrc"
    & wsl -d Ubuntu -u root -- bash -c $cleanCmd 2>&1 | Out-Null

    if ($OrKey) {
        $appendCmd = "echo 'export OPENROUTER_API_KEY=""$OrKey""' >> ~/.bashrc"
        & wsl -d Ubuntu -u root -- bash -c $appendCmd 2>&1 | Out-Null
        Write-Log "OpenRouter API Key 已写入。" -Level "SUCCESS"
    }

    if ($OaKey) {
        $appendCmd = "echo 'export OPENAI_API_KEY=""$OaKey""' >> ~/.bashrc"
        & wsl -d Ubuntu -u root -- bash -c $appendCmd 2>&1 | Out-Null
        Write-Log "OpenAI API Key 已写入。" -Level "SUCCESS"
    }

    if ($DsKey) {
        $appendCmd = "echo 'export DEEPSEEK_API_KEY=""$DsKey""' >> ~/.bashrc"
        & wsl -d Ubuntu -u root -- bash -c $appendCmd 2>&1 | Out-Null
        Write-Log "DeepSeek API Key 已写入。" -Level "SUCCESS"
    }

    Write-Log "API Key 配置完成！" -Level "SUCCESS"
}

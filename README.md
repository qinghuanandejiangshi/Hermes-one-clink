# Hermes Agent Windows One-Click Installer

**[中文](#中文说明)** | **[English](#english)**

> A zero-friction Windows installer for [Hermes Agent](https://github.com/NousResearch/hermes-agent) + [Hermes WebUI](https://github.com/nesquena/hermes-webui), designed for non-technical users. Double-click to install, double-click to launch.

---

## English

### What is this?

Hermes Agent is a powerful open-source AI coding assistant. The official installation requires WSL2 setup, Ubuntu configuration, Python environment management, and CLI familiarity — a significant barrier for non-developers.

This project eliminates that friction: a single `.bat` file handles everything automatically, from WSL2 installation to WebUI launch, with a GUI dialog for API key configuration.

Inspired by the [u-claw](https://github.com/dongsheng123132/u-claw) USB installer concept for OpenClaw.

### Features

- **One-click install** — runs all 6 installation steps automatically with progress display
- **Offline support** — place `hermes-agent.zip` and `hermes-webui.zip` in `resources/` for air-gapped installation
- **GUI API key setup** — Windows Forms dialog for OpenRouter / OpenAI / DeepSeek keys; no terminal required
- **Persistent background service** — WebUI survives PowerShell session exit (uses `Start-Process` WSL detachment)
- **Resumable** — progress checkpoint saved; re-running skips completed steps
- **Subsequent launch** — `后续启动.bat` / `Start Again.bat` starts the WebUI with one click
- **Chinese mirror support** — Aliyun PyPI mirror used automatically for faster installs in China
- **DeepSeek / Kimi ready** — domestic Chinese model providers supported out of the box

### Requirements

| | Minimum |
|-|---------|
| OS | Windows 10 (build 2004+) or Windows 11 |
| RAM | 8 GB recommended |
| Disk | 10 GB free space |
| Network | Internet access for first install (or offline ZIPs) |
| Privileges | Administrator rights |

### Quick Start

```
1. Clone or download this repo (or copy to USB drive)
2. Right-click  一键启动.bat  → Run as Administrator
3. Follow the GUI dialog to enter your API key
4. Browser opens automatically at http://127.0.0.1:8787
```

For subsequent launches:
```
Right-click  后续启动.bat  → Run as Administrator
```
<img width="1470" height="983" alt="image" src="https://github.com/user-attachments/assets/bfc65b41-71ae-4926-b179-5ae19b10b01c" />
<img width="802" height="263" alt="image" src="https://github.com/user-attachments/assets/2bb040ca-f09f-4626-baae-869df73dd63a" />
<img width="1902" height="958" alt="image" src="https://github.com/user-attachments/assets/3c347797-b0bd-44ae-8ff9-87bd21dbab7c" />

### Offline Installation

Place the following files in the `resources/` directory before running:

```
resources/
├── hermes-agent.zip    ← source from NousResearch/hermes-agent
└── hermes-webui.zip    ← source from nesquena/hermes-webui
```

The installer detects these files and skips all network downloads.

### Supported AI Providers

| Provider | Notes |
|----------|-------|
| DeepSeek | Recommended for Chinese users; cost-effective |
| OpenRouter | Access to 100+ models via one key |
| OpenAI | GPT-4o, o1, etc. |
| Kimi (Moonshot) | Configure via WebUI Profiles panel |
| Ollama / LM Studio | Local models via custom Base URL |
| Any OpenAI-compatible | Custom endpoint in Profiles |

### Project Structure

```
├── 一键启动.bat              ← First-time installer (run as Admin)
├── 后续启动.bat              ← Subsequent launcher
├── launcher/
│   ├── main.ps1             ← Orchestration + progress checkpoint
│   ├── utils.ps1            ← Logging, WSL helpers, spinner
│   ├── 00_check_env.ps1     ← System requirement checks
│   ├── 01_install_wsl2.ps1  ← Enable WSL2 feature
│   ├── 02_install_ubuntu.ps1← Install Ubuntu distro
│   ├── 03_install_hermes.ps1← Install hermes-agent via uv
│   ├── 04_install_webui.ps1 ← Extract & setup hermes-webui
│   ├── 05_configure.ps1     ← GUI dialog for API keys
│   ├── 06_start.ps1         ← Start server + open browser
│   └── start_only.ps1       ← Used by 后续启动.bat
└── resources/               ← Optional offline ZIPs go here
```

### How It Works

```
Windows (PowerShell)
│
├── 01  Enable-WindowsOptionalFeature (WSL2 + VirtualMachinePlatform)
├── 02  wsl --install -d Ubuntu
├── 03  wsl: uv tool install hermes-agent  (offline ZIP if present)
├── 04  wsl: unzip hermes-webui.zip; pip install requirements.txt
├── 05  Windows Forms GUI → write API keys to WSL ~/.bashrc
└── 06  Start-Process wsl.exe -WindowStyle Hidden
        └─→ exec python server.py (detached, survives PS exit)
              └─→ http://127.0.0.1:8787
```

Key technical decisions:
- **`Start-Process -WindowStyle Hidden`** for server launch — prevents WSL from killing the Python process when the PowerShell session ends
- **Shebang parsing** to locate the correct `uv` tool Python without hardcoding paths
- **`~/hermes-agent/run_agent.py` + `venv/` symlink** to satisfy WebUI's agent directory discovery heuristic
- **`HERMES_WEBUI_ALLOWED_ORIGINS`** to handle browsers that omit port in `Origin` header

### Known Limitations

- Windows only (Mac/Linux users can run `./start.sh` natively — see upstream docs)
- Requires admin rights for WSL2 installation (one-time)
- Browser cache may cause `Cross-origin request rejected` on first launch — use incognito mode if this occurs

### Contributing

Issues and PRs welcome. Core areas for improvement:

- [ ] Auto-update mechanism for hermes-agent and hermes-webui
- [ ] Uninstaller script
- [ ] Progress bar GUI (replacing the console window)
- [ ] Mac `.command` launcher parity

### License

MIT. Hermes Agent and Hermes WebUI are subject to their own licenses.

---

## 中文说明

### 这是什么？

Hermes Agent 是一款强大的开源 AI 编程助手。官方安装需要手动配置 WSL2、Ubuntu、Python 环境，对非技术人员门槛较高。

本项目参考 [u-claw U盘安装方案](https://github.com/dongsheng123132/u-claw) 的思路，将全部安装流程封装为一个双击运行的 `.bat` 文件，并提供 GUI 界面配置 API Key，**无需任何命令行操作**。

### 功能亮点

- **一键安装**：自动完成 WSL2 → Ubuntu → Hermes Agent → WebUI 全流程
- **离线支持**：在 `resources/` 放入 ZIP 包即可在无网环境安装
- **图形界面配置**：Windows 弹窗填入 API Key，支持 DeepSeek / OpenAI / OpenRouter
- **持久后台服务**：WebUI 服务在 PowerShell 退出后仍持续运行
- **断点续装**：中断后重新运行自动跳过已完成步骤
- **国内加速**：自动使用阿里云 PyPI 镜像
<img width="1470" height="983" alt="image" src="https://github.com/user-attachments/assets/bfc65b41-71ae-4926-b179-5ae19b10b01c" />
<img width="802" height="263" alt="image" src="https://github.com/user-attachments/assets/2bb040ca-f09f-4626-baae-869df73dd63a" />
<img width="1902" height="958" alt="image" src="https://github.com/user-attachments/assets/3c347797-b0bd-44ae-8ff9-87bd21dbab7c" />

### 快速开始

```
1. 下载本仓库（或复制到 U 盘）
2. 右键 一键启动.bat → 以管理员身份运行
3. 在弹出窗口中填写 API Key（推荐 DeepSeek）
4. 浏览器自动打开 http://127.0.0.1:8787

为方便中国大陆用户，项目源文件中已经下载好了hermes-agent.zip和hermes-webui.zip，但由于体积限制所以无法上传，系统启动后会自动下载，如果下载速度过慢或其他原因，请手动下载对应的两个项目放置在根目录下的resources目录下，分别命名为hermes-agent.zip和hermes-webui.zip
```
hermes-agent项目地址：https://github.com/NousResearch/hermes-agent;
hermes-webui项目地址：https://github.com/nesquena/hermes-webui；

后续每次使用：
```
右键 后续启动.bat → 以管理员身份运行
```

详细使用说明见：[使用说明（小白版）.md](使用说明（小白版）.md)

---

### Star History

如果本项目对你有帮助，欢迎 ⭐ Star！

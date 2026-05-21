@echo off
title Hermes Agent Launcher

:: Request administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b 0
)

:: Build paths without trailing backslash (prevents \" quote-escape bug)
set "ROOTDIR=%~dp0"
set "ROOTDIR=%ROOTDIR:~0,-1%"
set "SCRIPTDIR=%ROOTDIR%\launcher"

:: Fix encoding: re-save all PS1 files as UTF-8 with BOM (required for PowerShell 5 on Chinese Windows)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$bom=New-Object System.Text.UTF8Encoding $true; Get-ChildItem '%SCRIPTDIR%\*.ps1' | ForEach-Object { $c=[System.IO.File]::ReadAllText($_.FullName,[System.Text.Encoding]::UTF8); [System.IO.File]::WriteAllText($_.FullName,$c,$bom) }"

:: Launch Hermes Agent
powershell -NoProfile -ExecutionPolicy Bypass ^
    -File "%SCRIPTDIR%\start_only.ps1" ^
    -ScriptDir "%SCRIPTDIR%" ^
    -RootDir "%ROOTDIR%"

if %errorLevel% neq 0 (
    echo.
    echo [ERROR] Launch failed. Error code: %errorLevel%
    echo If this is first run, please use Setup.bat instead.
    echo Check log: %ROOTDIR%\logs\install.log
    echo.
)

echo.
pause

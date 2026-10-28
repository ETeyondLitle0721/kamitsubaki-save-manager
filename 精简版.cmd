@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -NoLogo -ExecutionPolicy Bypass -File "%~dp0launcher.ps1"
set "EXIT_CODE=%errorlevel%"
echo.
if not "%EXIT_CODE%"=="0" echo 程序异常退出，退出码：%EXIT_CODE%
pause
exit /b %EXIT_CODE%
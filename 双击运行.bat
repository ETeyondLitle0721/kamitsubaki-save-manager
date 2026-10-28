@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion
title Kamitsubaki 存档管理工具 - 启动器

rem ============================================================
rem  切换到脚本所在目录，保证所有相对路径都以 bat 所在目录为准
rem  这样无论从哪里双击或通过快捷方式启动都能正确定位文件
rem ============================================================
cd /d "%~dp0"

echo ==========================================
echo   Kamitsubaki City Under Construction
echo   REGENERATE 存档管理工具
echo ==========================================
echo.

set "FAILED=0"

rem ---------- 1. 检查 Node.js ----------
echo [1/4] 检查 Node.js...
where node >nul 2>nul
if errorlevel 1 (
    echo   [X] 未检测到 Node.js
    echo       请安装 Node.js 18 或更高版本：https://nodejs.org/
    set "FAILED=1"
) else (
    for /f "delims=v." %%a in ('node -v') do set "NODE_MAJOR=%%a"
    for /f "delims=" %%v in ('node -v') do set "NODE_VER=%%v"
    if not defined NODE_MAJOR set "NODE_MAJOR=0"
    if !NODE_MAJOR! LSS 18 (
        echo   [X] Node.js 版本过低：!NODE_VER!，需要 18 或更高
        set "FAILED=1"
    ) else (
        echo   [OK] Node.js !NODE_VER!
    )
)

rem ---------- 2. 检查 PowerShell 7 ----------
echo [2/4] 检查 PowerShell 7...
where pwsh >nul 2>nul
if errorlevel 1 (
    echo   [X] 未检测到 PowerShell 7 ^(pwsh.exe^)
    echo       请安装：https://github.com/PowerShell/PowerShell/releases
    set "FAILED=1"
) else (
    for /f "delims=" %%v in ('pwsh -NoProfile -NonInteractive -Command "$PSVersionTable.PSVersion.ToString()"') do set "PWSH_VER=%%v"
    if not defined PWSH_VER set "PWSH_VER=未知"
    echo   [OK] PowerShell !PWSH_VER!
)

rem ---------- 3. 检查程序文件 ----------
echo [3/4] 检查程序文件...
set "FILES_OK=1"
if not exist "index.mjs" (
    echo   [X] 缺少 index.mjs
    set "FILES_OK=0"
)
if not exist "registry-ops.ps1" (
    echo   [X] 缺少 registry-ops.ps1
    set "FILES_OK=0"
)
if not exist "package.json" (
    echo   [X] 缺少 package.json
    set "FILES_OK=0"
)
if !FILES_OK! equ 1 (
    echo   [OK] 程序文件齐全
) else (
    set "FAILED=1"
)

rem ---------- 4. 检查备份目录 ----------
echo [4/4] 检查备份目录...
if not exist "backups" (
    mkdir "backups" 2>nul
    if errorlevel 1 (
        echo   [X] 无法创建 backups 目录
        set "FAILED=1"
    ) else (
        echo   [OK] 已创建 backups 目录
    )
) else (
    echo   [OK] backups 目录存在
)

echo.
if !FAILED! neq 0 (
    echo ==========================================
    echo   环境检查未通过，请根据上面的提示修复后重试。
    echo ==========================================
    echo.
    pause
    endlocal
    exit /b 1
)

echo ==========================================
echo   环境检查通过，正在启动存档管理工具...
echo ==========================================
echo.

rem ============================================================
rem  前台直接运行主程序，保留 stdin/stdout 供 readline 交互
rem ============================================================
node index.mjs
set "EXIT_CODE=!errorlevel!"

echo.
if !EXIT_CODE! neq 0 (
    echo 程序异常退出，退出码：!EXIT_CODE!
) else (
    echo 程序已正常退出。
)
echo.
pause
endlocal
exit /b !EXIT_CODE!
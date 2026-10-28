#Requires -Version 5.1
<#
    Kamitsubaki City Under Construction REGENERATE 存档管理工具
    纯 PowerShell 5.1 实现（无需 Node.js / PowerShell 7）
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# 控制台编码：保证中日文正常显示（配合 启动.cmd 的 chcp 65001）
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding           = [System.Text.Encoding]::UTF8
} catch { }

# ---------- 常量 ----------
$ScriptRoot   = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$RegistryPath = 'HKCU:\Software\株式会社THINKR\Kamitsubaki City Under Construction REGENERATE'
$NativePath   = 'HKEY_CURRENT_USER\Software\株式会社THINKR\Kamitsubaki City Under Construction REGENERATE'
$BackupDir    = Join-Path $ScriptRoot 'backups'

# ---------- 工具函数 ----------
function Format-Size {
    param([long]$Bytes)
    if ($Bytes -lt 1KB) { return "$Bytes B" }
    if ($Bytes -lt 1MB) { return ('{0:F1} KB' -f ($Bytes / 1KB)) }
    return ('{0:F2} MB' -f ($Bytes / 1MB))
}

function Show-Header {
    Write-Host ''
    Write-Host '══════════════════════════════════════════'
    Write-Host '  Kamitsubaki City Under Construction'
    Write-Host '  REGENERATE 存档管理工具'
    Write-Host '══════════════════════════════════════════'
}

function Show-Menu {
    Write-Host ''
    Write-Host '  1. 备份当前存档'
    Write-Host '  2. 从备份恢复'
    Write-Host '  3. 清空当前存档'
    Write-Host '  4. 检查注册表状态'
    Write-Host '  0. 退出'
    Write-Host ''
}

# ---------- 注册表操作 ----------
function Test-SaveExists {
    return Test-Path -LiteralPath $RegistryPath
}

function Invoke-Backup {
    if (-not (Test-SaveExists)) {
        throw '注册表路径不存在，无法备份（请先在游戏中保存一次）'
    }
    if (-not (Test-Path -LiteralPath $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $fileName  = "KamitsubakiSave_$timestamp.reg"
    $fullPath  = Join-Path $BackupDir $fileName

    # 用 cmd /c 包装，防止 PowerShell 的 ErrorActionPreference 拦截 stderr
    $out = & cmd.exe /c "reg.exe export `"$NativePath`" `"$fullPath`" /y 2>&1"
    $exitCode = $LASTEXITCODE

    # 只要文件生成了，并且大小大于 0，就说明备份成功
    if (-not (Test-Path -LiteralPath $fullPath) -or (Get-Item -LiteralPath $fullPath).Length -eq 0) {
        throw "reg export 失败（退出码 $exitCode）：`n$($out -join "`n")"
    }
    
    return [pscustomobject]@{
        File     = $fileName
        FullPath = $fullPath
        Time     = (Get-Item -LiteralPath $fullPath).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
    }
}

function Invoke-Restore {
    param([Parameter(Mandatory)][string]$BackupPath)
    if (-not (Test-Path -LiteralPath $BackupPath)) {
        throw "备份文件不存在：$BackupPath"
    }
    if (Test-SaveExists) {
        Remove-Item -LiteralPath $RegistryPath -Recurse -Force
    }

    # 同样用 cmd /c 包装
    $out = & cmd.exe /c "reg.exe import `"$BackupPath`" 2>&1"
    $exitCode = $LASTEXITCODE

    # reg.exe 的退出码不可靠，只要导入后注册表路径真实存在，就说明成功
    if (-not (Test-Path -LiteralPath $RegistryPath)) {
        throw "reg import 失败（退出码 $exitCode）：`n$($out -join "`n")"
    }
}

function Get-BackupItems {
    if (-not (Test-Path -LiteralPath $BackupDir)) { return @() }
    return @(Get-ChildItem -LiteralPath $BackupDir -Filter '*.reg' -File |
             Sort-Object LastWriteTime -Descending)
}

function Invoke-Clear {
    if (-not (Test-SaveExists)) { return $false }
    Remove-Item -LiteralPath $RegistryPath -Recurse -Force
    return $true
}

# ---------- 业务逻辑 ----------
function Do-Backup {
    Write-Host ''
    Write-Host '⏳ 正在备份...'
    try {
        $r = Invoke-Backup
        Write-Host "✅ 备份成功：$($r.File)" -ForegroundColor Green
        Write-Host "   时间：$($r.Time)"
        Write-Host "   路径：$($r.FullPath)"
    } catch {
        Write-Host "❌ 备份失败：$($_.Exception.Message)" -ForegroundColor Red
    }
}

function Do-Restore {
    try { $backups = @(Get-BackupItems) }
    catch { Write-Host "❌ 读取备份列表失败：$($_.Exception.Message)" -ForegroundColor Red; return }

    if ($backups.Count -eq 0) { Write-Host ''; Write-Host '📭 暂无备份文件。'; return }

    Write-Host ''
    Write-Host '📦 可用备份：'
    Write-Host ''
    for ($i = 0; $i -lt $backups.Count; $i++) {
        $b = $backups[$i]
        Write-Host ('  {0,2}. {1}' -f ($i + 1), $b.Name)
        Write-Host ('      时间：{0}  大小：{1}' -f $b.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'), (Format-Size $b.Length))
        Write-Host ''
    }

    $answer = Read-Host '请选择要恢复的备份编号（直接回车取消）'
    if ([string]::IsNullOrWhiteSpace($answer)) { Write-Host '↩️  已取消。'; return }
    $idx = 0
    if (-not [int]::TryParse($answer.Trim(), [ref]$idx)) { Write-Host '↩️  已取消。'; return }
    $idx--
    if ($idx -lt 0 -or $idx -ge $backups.Count) { Write-Host '↩️  已取消。'; return }

    $chosen = $backups[$idx]
    Write-Host ''
    Write-Host "⚠️  即将恢复备份：$($chosen.Name)" -ForegroundColor Yellow
    Write-Host '   恢复前会先清空当前存档，确定继续？'
    $confirm = Read-Host '   输入 yes 确认'
    if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.Trim().ToLower() -ne 'yes') {
        Write-Host '↩️  已取消。'; return
    }
    Write-Host ''
    Write-Host '⏳ 正在恢复...'
    try {
        Invoke-Restore -BackupPath $chosen.FullName
        Write-Host "✅ 恢复成功：$($chosen.Name)" -ForegroundColor Green
    } catch {
        Write-Host "❌ 恢复失败：$($_.Exception.Message)" -ForegroundColor Red
    }
}

function Do-Clear {
    if (-not (Test-SaveExists)) {
        Write-Host ''
        Write-Host 'ℹ️  当前注册表路径不存在，已经是空状态。'
        return
    }
    Write-Host ''
    Write-Host '⚠️  即将清空当前存档（删除整个注册表路径及其子项）。' -ForegroundColor Yellow
    Write-Host '   建议先执行备份。确定继续？'
    $confirm = Read-Host '   输入 yes 确认'
    if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.Trim().ToLower() -ne 'yes') {
        Write-Host '↩️  已取消。'; return
    }
    Write-Host ''
    Write-Host '⏳ 正在清空...'
    try {
        if (Invoke-Clear) { Write-Host '✅ 存档已清空。' -ForegroundColor Green }
        else              { Write-Host 'ℹ️  当前已经是空状态，无需清空。' }
    } catch {
        Write-Host "❌ 清空失败：$($_.Exception.Message)" -ForegroundColor Red
    }
}

function Do-Check {
    $exists = Test-SaveExists
    Write-Host ''
    Write-Host "注册表路径：$NativePath"
    if ($exists) { Write-Host '是否存在：✅ 是' -ForegroundColor Green }
    else         { Write-Host '是否存在：❌ 否' -ForegroundColor Red }
}

# ---------- 主入口 ----------
function Main {
    if (-not (Test-Path -LiteralPath $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }
    Show-Header
    while ($true) {
        Show-Menu
        $choice = Read-Host '请输入选项'
        if ($null -eq $choice) { break }
        switch ($choice.Trim()) {
            '1' { Do-Backup }
            '2' { Do-Restore }
            '3' { Do-Clear }
            '4' { Do-Check }
            '0' { Write-Host ''; Write-Host '👋 再见。'; Write-Host ''; return 0 }
            default { Write-Host '⚠️  无效选项，请重新输入。' -ForegroundColor Yellow }
        }
    }
    return 0
}

$exitCode = 1
try {
    $exitCode = Main
} catch {
    Write-Host ''
    Write-Host "未处理的错误：$($_.Exception.Message)" -ForegroundColor Red
    $exitCode = 1
}
exit $exitCode
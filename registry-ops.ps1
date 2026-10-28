# registry-ops.ps1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Check','Backup','Restore','Clear','ListBackups')]
    [string]$Action,

    [Parameter(Mandatory=$false)]
    [string]$BackupPath = "",

    [Parameter(Mandatory=$false)]
    [string]$BackupDir = ""
)

$ErrorActionPreference = 'Stop'
$RegistryPath = 'HKCU:\Software\株式会社THINKR\Kamitsubaki City Under Construction REGENERATE'
$NativePath   = 'HKEY_CURRENT_USER\Software\株式会社THINKR\Kamitsubaki City Under Construction REGENERATE'

function Output-Json($obj) {
    $obj | ConvertTo-Json -Compress -Depth 4
}

function Get-Existing {
    return Test-Path -LiteralPath $RegistryPath
}

switch ($Action) {

    'Check' {
        Output-Json @{
            ok         = $true
            exists     = Get-Existing
            registryPath = $NativePath
        }
    }

    'ListBackups' {
        if (-not (Test-Path -LiteralPath $BackupDir)) {
            Output-Json @{ ok = $true; backups = @() }
            break
        }
        $files = Get-ChildItem -LiteralPath $BackupDir -Filter '*.reg' -File |
                 Sort-Object LastWriteTime -Descending |
                 ForEach-Object {
                     @{
                         name = $_.Name
                         path = $_.FullName
                         time = $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
                         size = $_.Length
                     }
                 }
        Output-Json @{ ok = $true; backups = @($files) }
    }

    'Backup' {
        if (-not (Get-Existing)) {
            Output-Json @{ ok = $false; error = '注册表路径不存在，无法备份' }
            break
        }
        if (-not (Test-Path -LiteralPath $BackupDir)) {
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        }
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $fileName  = "KamitsubakiSave_$timestamp.reg"
        $fullPath  = Join-Path $BackupDir $fileName

        # reg export 原生支持中文路径，加 /y 静默覆盖
        & reg.exe export $NativePath $fullPath /y | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Output-Json @{ ok = $false; error = "reg export 失败，退出码 $LASTEXITCODE" }
            break
        }
        Output-Json @{
            ok       = $true
            file     = $fileName
            fullPath = $fullPath
            time     = (Get-Item -LiteralPath $fullPath).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
        }
    }

    'Restore' {
        if (-not (Test-Path -LiteralPath $BackupPath)) {
            Output-Json @{ ok = $false; error = "备份文件不存在：$BackupPath" }
            break
        }
        # reg import 是合并写入，先清空再恢复可避免旧值残留
        if (Get-Existing) {
            Remove-Item -LiteralPath $RegistryPath -Recurse -Force
        }
        & reg.exe import $BackupPath | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Output-Json @{ ok = $false; error = "reg import 失败，退出码 $LASTEXITCODE" }
            break
        }
        Output-Json @{
            ok   = $true
            file = Split-Path $BackupPath -Leaf
        }
    }

    'Clear' {
        if (-not (Get-Existing)) {
            Output-Json @{ ok = $true; alreadyEmpty = $true }
            break
        }
        Remove-Item -LiteralPath $RegistryPath -Recurse -Force
        Output-Json @{ ok = $true; alreadyEmpty = $false }
    }
}
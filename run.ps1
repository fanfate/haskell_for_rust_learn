#!/usr/bin/env pwsh
# 用法:
#   ./run.ps1                      # 列出所有练习
#   ./run.ps1 exercises/Ex01Adt.hs # 跑一个练习
#   ./run.ps1 solutions/Ex01Adt.hs # 看参考答案
#
# 等价于 run.sh 的 `runghc -isrc -Wall`。和 run.sh 的区别只有一处：
# 中文由 PowerShell 按控制台码页现场转码输出，所以 chcp 936 / 65001 都对。
# 本文件必须是 UTF-8 with BOM，否则 Windows PowerShell 5.1 会把中文读成乱码。
[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments = $true)][string[]] $File)

if (-not $File) {
    Write-Host "用法: ./run.ps1 <文件.hs>"
    Write-Host ""
    Write-Host "练习:"
    Get-ChildItem -LiteralPath "$PSScriptRoot/exercises" -Filter *.hs |
        ForEach-Object { Write-Host "  exercises/$($_.Name)" }
    Write-Host ""
    Write-Host "参考答案:"
    Get-ChildItem -LiteralPath "$PSScriptRoot/solutions" -Filter *.hs |
        ForEach-Object { Write-Host "  solutions/$($_.Name)" }
    exit 1
}

Push-Location -LiteralPath $PSScriptRoot
try {
    & runghc -isrc -Wall @File
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}

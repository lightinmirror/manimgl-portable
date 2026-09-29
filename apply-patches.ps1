<#
    apply-patches.ps1 -- apply this repository's patch set to manimgl 1.7.2

    Usage:
        powershell -ExecutionPolicy Bypass -File apply-patches.ps1 -VenvDir <venv>
        powershell -ExecutionPolicy Bypass -File apply-patches.ps1 -ManimlibDir <manimlib dir>

    Safety:
      patches/manifest.json records pre_sha256 / post_sha256 for every file.
        * current hash == post -> already patched, skip
        * current hash == pre  -> upstream file, replace
        * anything else        -> stop; the version or file has changed
      这样绝不会把本补丁静默混进一个不同版本的 manimlib 里。
#>

param(
    [string]$VenvDir,
    [string]$ManimlibDir,
    [string]$PatchesDir = (Join-Path $PSScriptRoot 'patches'),
    [switch]$WhatIf
)

$ErrorActionPreference = 'Continue'

# ---------------------------------------------------------------- 定位 manimlib
if (-not $ManimlibDir) {
    if (-not $VenvDir) {
        Write-Host "需要 -VenvDir 或 -ManimlibDir" -ForegroundColor Red
        exit 2
    }
    $ManimlibDir = Join-Path $VenvDir 'Lib\site-packages\manimlib'
}
if (-not (Test-Path -LiteralPath $ManimlibDir)) {
    Write-Host "找不到 manimlib 目录: $ManimlibDir" -ForegroundColor Red
    exit 2
}
$manifestPath = Join-Path $PatchesDir 'manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    Write-Host "找不到 $manifestPath" -ForegroundColor Red
    exit 2
}

Write-Host ""
Write-Host "== 应用 manimlib 补丁 ==" -ForegroundColor Cyan
Write-Host "  manimlib : $ManimlibDir"
Write-Host "  patches  : $PatchesDir"
if ($WhatIf) { Write-Host "  (WhatIf: 只检查，不写文件)" -ForegroundColor Yellow }
Write-Host ""

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
Write-Host "  上游基准 : $($manifest.upstream)"
Write-Host ""

$applied = 0; $skipped = 0; $conflict = @()

foreach ($entry in $manifest.files) {
    $rel = $entry.path -replace '^manimlib/', ''
    $target = Join-Path $ManimlibDir $rel
    $src = Join-Path $PatchesDir $entry.path   # manifest 里的 path 已含 manimlib/

    $cur = ''
    if (Test-Path -LiteralPath $target) {
        $cur = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLower()
    }

    if ($cur -eq $entry.post_sha256) {
        Write-Host ("  已打过   {0}" -f $entry.path) -ForegroundColor DarkGray
        $skipped++
        continue
    }
    if ($cur -ne $entry.pre_sha256) {
        $conflict += $entry.path
        Write-Host ("  冲突!    {0}" -f $entry.path) -ForegroundColor Red
        continue
    }

    if (-not (Test-Path -LiteralPath $src)) {
        $conflict += $entry.path
        Write-Host ("  源文件缺失! {0}" -f $src) -ForegroundColor Red
        continue
    }
    if (-not $WhatIf) {
        New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
        Copy-Item -LiteralPath $src -Destination $target -Force
        $after = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLower()
        if ($after -ne $entry.post_sha256) {
            $conflict += $entry.path
            Write-Host ("  写入校验失败! {0}" -f $entry.path) -ForegroundColor Red
            continue
        }
    }
    Write-Host ("  已应用   {0}" -f $entry.path) -ForegroundColor Green
    $applied++
}

Write-Host ""
if ($conflict.Count -gt 0) {
    Write-Host "被中止：以下文件的哈希既不是“打补丁前”也不是“打补丁后”： " -ForegroundColor Red
    $conflict | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    Write-Host ""
    Write-Host "含义：安装的 manimgl 不是 1.7.2，或这些文件已被第三方改动。" -ForegroundColor Yellow
    Write-Host "处理：装上游基准版本后再试 ——  uv pip install manimgl==1.7.2" -ForegroundColor Yellow
    exit 1
}

Write-Host ("完成：应用 {0} 个，跳过 {1} 个（已打过）" -f $applied, $skipped) -ForegroundColor Cyan
if ($WhatIf) { Write-Host "（WhatIf 模式，未写任何文件）" -ForegroundColor Yellow }
Write-Host ""
exit 0

<#
    build-exe.ps1 -- build the Rust launcher and append the self-contained zip

    The resulting file is [launcher.exe][payload.zip][trailer].  The trailer
    contains the payload offset and MGLPORT1, which the launcher checks before
    extracting.

    Usage:
      powershell -ExecutionPolicy Bypass -File build-exe.ps1
      Optional parameters: -Zip -Out -Repo
#>

param(
    [string]$Zip  = '',
    [string]$Out  = '',
    [string]$Repo = ''
)

$ErrorActionPreference = 'Continue'

if (-not $Repo) { $Repo = $PSScriptRoot }
if (-not $Zip) {
    $Zip = Join-Path (Split-Path $Repo -Parent) 'manimgl-portable\manimgl-selfcontained-win64.zip'
}
if (-not $Out) { $Out = Join-Path (Split-Path $Zip -Parent) 'manimgl-portable.exe' }

function Fail([string]$m) { Write-Host ""; Write-Host "FAILED: $m" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "== build-exe ==" -ForegroundColor Cyan
Write-Host "  repo     : $Repo"
Write-Host "  payload  : $Zip"
Write-Host "  output   : $Out"

if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) { Fail "需要 cargo/rust（https://rustup.rs）" }
if (-not (Test-Path -LiteralPath $Zip)) { Fail "找不到载荷 zip: $Zip" }

$manifest = Join-Path $Repo 'launcher\Cargo.toml'
if (-not (Test-Path -LiteralPath $manifest)) { Fail "找不到 launcher\Cargo.toml" }

Write-Host ""
Write-Host "[1/3] cargo build --release ..."
Push-Location (Join-Path $Repo 'launcher')
& cargo build --release
$ok = ($LASTEXITCODE -eq 0)
Pop-Location
if (-not $ok) { Fail "cargo build 失败" }

$launcher = Join-Path $Repo 'launcher\target\release\manimgl-portable.exe'
if (-not (Test-Path -LiteralPath $launcher)) { Fail "没生成 $launcher" }

Write-Host ""
Write-Host "[2/3] 拼接 launcher + payload ..."
$off = (Get-Item -LiteralPath $launcher).Length
$fs = [System.IO.File]::Create($Out)
try {
    foreach ($src in @($launcher, $Zip)) {
        $in = [System.IO.File]::OpenRead($src)
        try { $in.CopyTo($fs, 1MB) } finally { $in.Dispose() }
    }
    $tr = New-Object byte[] 16
    [BitConverter]::GetBytes([uint64]$off).CopyTo($tr, 0)
    [System.Text.Encoding]::ASCII.GetBytes('MGLPORT1').CopyTo($tr, 8)
    $fs.Write($tr, 0, 16)
} finally { $fs.Dispose() }

Write-Host ""
Write-Host "[3/3] 校验 trailer ..."
$fi = Get-Item -LiteralPath $Out
$st = [System.IO.File]::OpenRead($Out)
try {
    $st.Seek(-16, 'End') | Out-Null
    $tail = New-Object byte[] 16
    $st.Read($tail, 0, 16) | Out-Null
} finally { $st.Dispose() }
$magic = [System.Text.Encoding]::ASCII.GetString($tail, 8, 8)
$gotOff = [BitConverter]::ToUInt64($tail, 0)
if ($magic -ne 'MGLPORT1') { Fail "trailer magic 不对: $magic" }
if ($gotOff -ne $off) { Fail "trailer 偏移不对: $gotOff != $off" }

Write-Host ("  OK  offset={0}  载荷={1:N1} MB  总计={2:N1} MB" -f `
        $off, ((($fi.Length - $off - 16) / 1MB)), ($fi.Length / 1MB))

Write-Host ""
Write-Host "更新 MANIFEST ..."
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Repo 'update-manifest.ps1') `
    -OutDir (Split-Path $Out -Parent)

Write-Host ""
Write-Host "产物: $Out" -ForegroundColor Green
Write-Host ""
exit 0

<#
    make-release.ps1 -- build manimgl-portable from the upstream package

    Requires uv and network access to PyPI, GitHub, and gyan.dev unless the
    relevant executables or assets are supplied as parameters.  TeX assets can
    come from an installed TeX Live tree or from tex-assets.zip.

    The script creates a Python 3.12 environment, installs manimgl 1.7.2,
    applies the checked patch set, installs the native tools and font tree,
    builds the Tectonic cache, then calls build.ps1 for packaging and auditing.
#>

param(
    [string]$WorkDir      = '',
    [string]$PkgDir       = '',
    [string]$OutDir       = '',
    [string]$BuildPath    = '',
    [string]$TexLiveDir   = '',
    [string]$TexAssetsZip = '',
    [string]$TectonicExe  = '',
    [string]$FfmpegExe    = '',
    [string]$FandolFont   = '',            # 额外单独添加的字体文件（可选）
    [switch]$SkipCache,
    [switch]$SkipAudit
)

$ErrorActionPreference = 'Continue'

if (-not $PkgDir) { $PkgDir = $PSScriptRoot }
if (-not $WorkDir) { $WorkDir = Join-Path (Split-Path $PkgDir -Parent) 'manimgl-portable-build' }
if (-not $OutDir) { $OutDir = Join-Path (Split-Path $PkgDir -Parent) 'manimgl-portable' }

function Step([string]$s) { Write-Host ""; Write-Host "== $s ==" -ForegroundColor Cyan }
function Fail([string]$m) { Write-Host ""; Write-Host "FAILED: $m" -ForegroundColor Red; exit 1 }

# 最小字体树的目录清单（相对 TeX Live 的 texmf-dist/）
$FontDirs = @(
    'fonts\tfm\public\cm',
    'fonts\tfm\public\amsfonts',
    'fonts\tfm\public\lm',
    'fonts\type1\public\amsfonts',
    'fonts\opentype\public\lm',
    'fonts\opentype\public\fandol'
)

Write-Host ""
Write-Host "== make-release ==" -ForegroundColor Cyan
Write-Host "  work    : $WorkDir"
Write-Host "  pkg     : $PkgDir"
Write-Host "  out     : $OutDir"

$VenvDir = Join-Path $WorkDir 'manim-env'
$Scripts = Join-Path $VenvDir 'Scripts'
$PyExe   = Join-Path $Scripts 'python.exe'

# --------------------------------------------------------------- 0. 前置检查
Step "[0/6] 前置检查"
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) { Fail "需要 uv（https://docs.astral.sh/uv/）" }
foreach ($f in @('build.ps1', 'apply-patches.ps1', 'audit_zip.py', 'assets\texmf.cnf')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PkgDir $f))) { Fail "仓库缺少文件: $f" }
}
if (-not $TexLiveDir -and -not $TexAssetsZip) {
    Fail "需要 -TexLiveDir 或 -TexAssetsZip（dvisvgm 与字体树的来源）"
}
Write-Host "  OK"

New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

# ------------------------------------------------------------ 1. venv + manimgl
Step "[1/6] 建 venv 并安装 manimgl 1.7.2"
if (-not (Test-Path -LiteralPath $PyExe)) {
    & uv venv $VenvDir --python 3.12
    if ($LASTEXITCODE -ne 0) { Fail "uv venv 失败" }
}

# uv/venv 生成的 activate.bat 会写死创建时的绝对路径 —— 改成自定位，
# 否则换个机器 VIRTUAL_ENV 就是错的（审计的 [A] 项也会因此不通过）
$activateBat = Join-Path $Scripts 'activate.bat'
if (Test-Path -LiteralPath $activateBat) {
    $t = Get-Content -LiteralPath $activateBat -Raw
    $patched = [regex]::Replace(
        $t,
        '(?m)^@for %%i in \("[^"]*"\) do @set "VIRTUAL_ENV=%%~fi"',
        '@for %%i in ("%~dp0..") do @set "VIRTUAL_ENV=%%~fi"')
    if ($patched -ne $t) {
        [System.IO.File]::WriteAllText($activateBat, $patched, (New-Object System.Text.UTF8Encoding $false))
        Write-Host "  activate.bat 已改为自定位"
    }
}
& uv pip install --python $PyExe 'manimgl==1.7.2'
if ($LASTEXITCODE -ne 0) { Fail "安装 manimgl 失败" }
# manimgl 会 import pkg_resources，它来自 setuptools；uv 建的环境默认没有
# manimgl 1.7.2 在 __init__ 里 import pkg_resources；而 setuptools 从 82 起
# 把它移除了（官方弃用警告原话：“pin to Setuptools<81”）。
# 上游 master 已改用别的写法，但我们固定 1.7.2，所以这里必须钉住 setuptools。
& uv pip install --python $PyExe 'setuptools==81.0.0'
if ($LASTEXITCODE -ne 0) { Fail "安装 setuptools 失败" }
Write-Host "  已安装"

# ------------------------------------------------------------------ 2. 打补丁
Step "[2/6] 应用本仓库补丁"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PkgDir 'apply-patches.ps1') -VenvDir $VenvDir
if ($LASTEXITCODE -ne 0) { Fail "补丁应用失败（看上面的冲突清单）" }

# --------------------------------------------------- 3. tectonic / ffmpeg exe
Step "[3/6] tectonic.exe + ffmpeg.exe"
if ($TectonicExe) {
    Copy-Item -LiteralPath $TectonicExe -Destination $Scripts -Force
} else {
    $api = 'https://api.github.com/repos/tectonic-typesetting/tectonic/releases?per_page=5'
    $rels = Invoke-RestMethod $api -Headers @{ 'User-Agent' = 'make-release' }
    $asset = $null
    foreach ($r in $rels) {
        $asset = $r.assets | Where-Object { $_.name -match 'x86_64-pc-windows-msvc\.zip$' } | Select-Object -First 1
        if ($asset) { break }
    }
    if (-not $asset) { Fail "找不到 tectonic 的 Windows msvc 资产" }
    Write-Host "  下载 $($asset.name)"
    $tmp = Join-Path $WorkDir 'tectonic.zip'
    Invoke-WebRequest $asset.browser_download_url -OutFile $tmp -UseBasicParsing
    Expand-Archive -LiteralPath $tmp -DestinationPath (Join-Path $WorkDir 'tectonic') -Force
    $exe = Get-ChildItem (Join-Path $WorkDir 'tectonic') -Recurse -Filter 'tectonic.exe' | Select-Object -First 1
    if (-not $exe) { Fail "解压后没有 tectonic.exe" }
    Copy-Item $exe.FullName $Scripts -Force
}
if ($FfmpegExe) {
    Copy-Item -LiteralPath $FfmpegExe -Destination (Join-Path $Scripts 'ffmpeg.exe') -Force
} else {
    Write-Host "  下载 ffmpeg (gyan.dev essentials)"
    $tmp = Join-Path $WorkDir 'ffmpeg.zip'
    Invoke-WebRequest 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' -OutFile $tmp -UseBasicParsing
    Expand-Archive -LiteralPath $tmp -DestinationPath (Join-Path $WorkDir 'ffmpeg') -Force
    $exe = Get-ChildItem (Join-Path $WorkDir 'ffmpeg') -Recurse -Filter 'ffmpeg.exe' | Select-Object -First 1
    if (-not $exe) { Fail "解压后没有 ffmpeg.exe" }
    Copy-Item $exe.FullName (Join-Path $Scripts 'ffmpeg.exe') -Force
}
Write-Host "  OK"

# ------------------------------------------------- 4. dvisvgm + 字体树 + cnf
Step "[4/6] dvisvgm.exe + 最小字体树"
$Texmf = Join-Path $Scripts 'texmf'
Remove-Item $Texmf -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path (Join-Path $Texmf 'web2c') | Out-Null

if ($TexAssetsZip) {
    Write-Host "  从 $TexAssetsZip 解出"
    Expand-Archive -LiteralPath $TexAssetsZip -DestinationPath $Texmf -Force
    if (-not (Test-Path (Join-Path $Texmf 'dvisvgm.exe'))) { Fail "tex-assets.zip 里没有 dvisvgm.exe" }
    Move-Item (Join-Path $Texmf 'dvisvgm.exe') (Join-Path $Scripts 'dvisvgm.exe') -Force
} else {
    $tlBin = Join-Path $TexLiveDir 'bin\windows'
    $tlDist = Join-Path $TexLiveDir 'texmf-dist'
    if (-not (Test-Path (Join-Path $tlBin 'dvisvgm.exe'))) { Fail "找不到 $tlBin\dvisvgm.exe" }
    Copy-Item (Join-Path $tlBin 'dvisvgm.exe') $Scripts -Force
    foreach ($d in $FontDirs) {
        $src = Join-Path $tlDist $d
        if (Test-Path $src) {
            Copy-Item $src (Join-Path $Texmf $d) -Recurse -Force
        } else {
            Write-Host "  [警告] TeX Live 里没有 $d" -ForegroundColor Yellow
        }
    }
}
if ($FandolFont) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Texmf 'fonts\opentype\public\fandol') | Out-Null
    Copy-Item -LiteralPath $FandolFont -Destination (Join-Path $Texmf 'fonts\opentype\public\fandol') -Force
}
# texmf.cnf 以仓库里的为准（无绝对路径，用 $SELFAUTOLOC 自定位）
Copy-Item (Join-Path $PkgDir 'assets\texmf.cnf') (Join-Path $Texmf 'web2c\texmf.cnf') -Force
Write-Host "  OK"

# ------------------------------------------------------------ 5. tectonic 缓存
$CacheZip = Join-Path $PkgDir 'tectonic-cache.zip'
if ($SkipCache) {
    Step "[5/6] 跳过 TeX 缓存 (-SkipCache)"
} else {
    Step "[5/6] 生成 tectonic 缓存（首跑免联网）"
    $docDir = Join-Path $WorkDir 'cachegen'
    New-Item -ItemType Directory -Force -Path $docDir | Out-Null
    $tex = @'
\documentclass[preview]{standalone}
\usepackage[UTF8]{ctex}
\usepackage{amsmath}
\usepackage{amssymb}
\usepackage{xcolor}
\begin{document}
\centering
\begin{align*}
\text{缓存生成} \quad \sum_{i=1}^{n} x_i^2 + \int_0^\infty e^{-t}dt + \sqrt{\alpha\beta} \rightarrow \infty
\end{align*}
\end{document}
'@
    [System.IO.File]::WriteAllText((Join-Path $docDir 'cachegen.tex'), $tex, (New-Object System.Text.UTF8Encoding $false))
    & (Join-Path $Scripts 'tectonic.exe') (Join-Path $docDir 'cachegen.tex') --outfmt xdv -o $docDir
    if ($LASTEXITCODE -ne 0) { Fail "tectonic 缓存生成失败（需联网）" }
    $cacheRoot = Join-Path $env:LOCALAPPDATA 'TectonicProject'
    if (-not (Test-Path (Join-Path $cacheRoot 'Tectonic\cache\bundles'))) { Fail "没生成缓存: $cacheRoot" }
    Remove-Item $CacheZip -Force -ErrorAction SilentlyContinue
    & tar.exe -a -c -f $CacheZip -C (Split-Path $cacheRoot -Parent) (Split-Path $cacheRoot -Leaf)
    if ($LASTEXITCODE -ne 0) { Fail "打包缓存失败" }
    Write-Host "  -> $CacheZip"
}

# ---------------------------------------------------------------- 6. 打包+审计
Step "[6/6] 打包 + 审计"
$args = @('-File', (Join-Path $PkgDir 'build.ps1'),
    '-VenvDir', $VenvDir, '-PkgDir', $PkgDir, '-OutDir', $OutDir, '-BuildPath', $BuildPath)
if ($SkipAudit) { $args += '-SkipAudit' }
& powershell -NoProfile -ExecutionPolicy Bypass @args
if ($LASTEXITCODE -ne 0) { Fail "打包/审计未通过" }

Write-Host ""
Write-Host "完成。产物在: $OutDir" -ForegroundColor Green
Write-Host ""
exit 0

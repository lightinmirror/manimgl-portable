<#
    build.ps1 -- build the two zip packages, audit them, and write MANIFEST.txt

    The self-contained package includes CPython.  The portable package expects
    Python 3.12 on the target machine.  The audit rejects build-machine paths,
    unexpected absolute paths in configuration, and non-ASCII configuration bytes.

    Usage:
      powershell -ExecutionPolicy Bypass -File build.ps1
      Optional parameters: -VenvDir -PythonDir -PkgDir -OutDir -BuildPath
#>

param(
    [string]$VenvDir   = '',   # 必需：已打好补丁的 venv
    [string]$PythonDir = '',   # 空 = 自动探测（包内 python\ ，或 uv 的 3.12）
    [string]$PkgDir    = '',   # 空 = 本脚本所在目录
    [string]$OutDir    = '',   # 空 = <PkgDir 的父目录>\manimgl-portable
    [string]$BuildPath = '',   # 空 = VenvDir 的父目录（禁止出现在产物里）
    [switch]$SkipAudit
)

$ErrorActionPreference = 'Continue'

# 默认把包根当成"build.ps1 所在目录"
if (-not $PkgDir) { $PkgDir = $PSScriptRoot }
if (-not $PkgDir) { $PkgDir = (Get-Location).Path }
if (-not $OutDir) { $OutDir = Join-Path (Split-Path $PkgDir -Parent) 'manimgl-portable' }
# 构建机路径默认取 venv 的父目录（例如 venv 在 ...\manimgl\manim-env → 禁止 ...\manimgl）
if (-not $BuildPath -and $VenvDir) { $BuildPath = Split-Path (Resolve-Path -LiteralPath $VenvDir -ErrorAction SilentlyContinue).Path -Parent }

# 必需：缺任何一个就中止。数组项 = “任选其一”，适配两种目录布局：
#   构建套件里叫 PROJECT-README.md，仓库里叫 README.md
$required = @(
    'custom_config.yml', 'RESTORE.md', 'bootstrap.ps1', 'setup.cmd',
    'run-demo.cmd', 'run-showcase.cmd', 'check.cmd', 'demo.py', 'showcase.py', 'demo.gif', 'showcase.gif', 'START-HERE.txt',
    'THIRD-PARTY.md', 'RELEASE-CHECKLIST.md', 'LICENSES',
    @('README.md', 'PROJECT-README.md')
)
# 可选：缺失只警告（仓库里不放这个大文件，从 Release 附件取）
$optionalFiles = @('tectonic-cache.zip')
$excludes = @(
    '--exclude=*/__pycache__', '--exclude=*/__pycache__/*',
    '--exclude=__pycache__', '--exclude=__pycache__/*',
    '--exclude=*.bak', '--exclude=*.prepatch.bak',
    # 非 Windows shell 的激活脚本：Windows 上用不到，且携带创建时的绝对路径
    # （activate.bat 已改成自定位，保留）
    '--exclude=*/Scripts/activate', '--exclude=*/Scripts/activate.csh',
    '--exclude=*/Scripts/activate.fish', '--exclude=*/Scripts/activate.nu',
    # pip 生成的控制台启动器：二进制里写死了创建时的 python 路径，换机器必坏，
    # 且审计扫描看不到（二进制）。直接用 Scripts\python.exe -m manimlib 即可。
    '--exclude=*/Scripts/f2py.exe', '--exclude=*/Scripts/fonttools.exe',
    '--exclude=*/Scripts/ipython.exe', '--exclude=*/Scripts/ipython3.exe',
    '--exclude=*/Scripts/isympy.exe', '--exclude=*/Scripts/manim-render.exe',
    '--exclude=*/Scripts/manimgl.exe', '--exclude=*/Scripts/markdown-it.exe',
    '--exclude=*/Scripts/numpy-config.exe', '--exclude=*/Scripts/pyftmerge.exe',
    '--exclude=*/Scripts/pyftsubset.exe', '--exclude=*/Scripts/pygmentize.exe',
    '--exclude=*/Scripts/tqdm.exe', '--exclude=*/Scripts/ttx.exe'
)

function Fail([string]$msg) {
    Write-Host ""
    Write-Host "BUILD FAILED: $msg" -ForegroundColor Red
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "== manimgl portable build ==" -ForegroundColor Cyan
Write-Host "  venv    : $VenvDir"
Write-Host "  python  : $PythonDir"
Write-Host "  pkg     : $PkgDir"
Write-Host "  out     : $OutDir"
Write-Host "  buildPath: $BuildPath   (禁止出现在产物里)"
Write-Host ""

# ------------------------------------------------------------------ 前置检查
Write-Host "[0/4] 前置检查 ..."

if (-not (Get-Command tar -ErrorAction SilentlyContinue)) { Fail 'tar.exe 不可用' }
foreach ($p in @($VenvDir, $PkgDir)) {
    if (-not (Test-Path -LiteralPath $p)) { Fail "路径不存在: $p" }
}
if (-not (Test-Path -LiteralPath (Join-Path $VenvDir 'pyvenv.cfg'))) { Fail "不是 venv: $VenvDir" }
foreach ($f in $rootFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $PkgDir $f))) { Fail "包根缺少文件: $f" }
}
$packFiles = @()
foreach ($f in $required) {
    if ($f -is [array]) {
        $hit = @($f | Where-Object { Test-Path -LiteralPath (Join-Path $PkgDir $_) })
        if ($hit.Count -eq 0) { Fail ("包根缺少文件（以下任一）: " + ($f -join ' / ')) }
        $packFiles += $hit[0]
    } else {
        if (-not (Test-Path -LiteralPath (Join-Path $PkgDir $f))) { Fail "包根缺少文件: $f" }
        $packFiles += $f
    }
}
foreach ($f in $optionalFiles) {
    if (Test-Path -LiteralPath (Join-Path $PkgDir $f)) {
        $packFiles += $f
    } else {
        Write-Host "  [警告] 可选文件缺失: $f  -> 产物不含 TeX 缓存，目标机首跑会联网下载约 90 MB" -ForegroundColor Yellow
    }
}
# 基础解释器：优先用参数；否则自动探测（包内 python\ ，或 uv 的 3.12）
$pyOk = $false
if ($PythonDir) { $pyOk = Test-Path -LiteralPath (Join-Path $PythonDir 'python.exe') }
if (-not $pyOk) {
    $cands = @()
    if ($PkgDir) { $cands += (Join-Path $PkgDir 'python') }
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        $uf = (& uv python find 3.12 2>$null | Select-Object -First 1)
        if ($uf) { $cands += (Split-Path -Parent ($uf -replace '"', '').Trim()) }
    }
    foreach ($d in @((Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312'), 'C:\Python312')) { $cands += $d }
    foreach ($c in $cands) {
        if ($c -and (Test-Path -LiteralPath (Join-Path $c 'python.exe'))) { $PythonDir = $c; break }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $PythonDir 'python.exe'))) {
        Fail "找不到基础解释器；请用 -PythonDir 指定一个 CPython 3.12 目录"
    }
    Write-Host "  基础解释器 -> $PythonDir"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Remove-Item (Join-Path $PkgDir '__pycache__') -Recurse -Force -ErrorAction SilentlyContinue

# 只扫【将要打包】的东西 —— 构建脚本本身可以合法地含有默认路径
$scanExt = @('.yml', '.yaml', '.cfg', '.cnf', '.txt', '.md', '.cmd', '.ps1', '.py', '.json', '.toml', '.ini')
$scanTargets = @()
foreach ($f in $packFiles) {
    $p = Join-Path $PkgDir $f
    if (Test-Path -LiteralPath $p -PathType Container) {
        $scanTargets += Get-ChildItem -LiteralPath $p -Recurse -File -ErrorAction SilentlyContinue
    } else {
        $scanTargets += Get-Item -LiteralPath $p -ErrorAction SilentlyContinue
    }
}
$badBuild = @()
$badAscii = @()
foreach ($f in ($scanTargets | Where-Object { $scanExt -contains $_.Extension })) {
    $text = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
    if ($text -and $text -match [regex]::Escape($BuildPath)) { $badBuild += $f.Name }
    if ($f.Extension -in '.yml', '.yaml', '.cfg', '.cnf') {
        $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
        if (@($bytes | Where-Object { $_ -gt 127 }).Count -gt 0) { $badAscii += $f.Name }
    }
}
if ($badBuild.Count) { Fail ("包根文件里出现构建机路径 $BuildPath : " + ($badBuild -join ', ')) }
if ($badAscii.Count) { Fail ("配置类文件含非 ASCII（locale 编码雷）: " + ($badAscii -join ', ')) }
Write-Host "  OK"

# ---------------------------------------------------------------------- 打包
Write-Host "[1/4] 打包 ..."
$z1 = Join-Path $OutDir 'manimgl-selfcontained-win64.zip'
$z2 = Join-Path $OutDir 'manimgl-env-portable.zip'
foreach ($z in @($z1, $z2)) { Remove-Item $z -Force -ErrorAction SilentlyContinue }

# 基础解释器可能叫 cpython-3.12.x-...，但包里必须叫 python/
# 用 junction 免复制；Windows 下创建 junction 不需要管理员权限
$stage = Join-Path $env:TEMP ('mgl-build-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $stage | Out-Null
$link = Join-Path $stage 'python'
if ((Split-Path $PythonDir -Leaf) -eq 'python') {
    $pyParent = Split-Path $PythonDir -Parent
} else {
    New-Item -ItemType Junction -Path $link -Target $PythonDir | Out-Null
    $pyParent = $stage
    Write-Host "  (junction) $link -> $PythonDir"
}
$venvParent = Split-Path $VenvDir -Parent
$venvLeaf = Split-Path $VenvDir -Leaf

Write-Host "  selfcontained ..."
& tar.exe -a -c -f $z1 @excludes -C $venvParent $venvLeaf -C $pyParent python -C $PkgDir @packFiles
if ($LASTEXITCODE -ne 0) { Fail "tar 打包失败 (selfcontained), code=$LASTEXITCODE" }

Write-Host "  portable ..."
& tar.exe -a -c -f $z2 @excludes -C $venvParent $venvLeaf -C $PkgDir @packFiles
if ($LASTEXITCODE -ne 0) { Fail "tar 打包失败 (portable), code=$LASTEXITCODE" }

Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue

foreach ($z in @($z1, $z2)) {
    Write-Host ("  {0,-38} {1,8:N1} MB" -f (Split-Path $z -Leaf), ((Get-Item $z).Length / 1MB))
}

# ---------------------------------------------------------------------- 审计
if ($SkipAudit) {
    Write-Host "[2/4] 审计已跳过 (-SkipAudit)" -ForegroundColor Yellow
} else {
    Write-Host "[2/4] 审计产物 ..."
    $audit = Join-Path $PkgDir 'audit_zip.py'
    $py = Join-Path $VenvDir 'Scripts\python.exe'
    if (-not (Test-Path -LiteralPath $audit)) { Fail "缺少 audit_zip.py" }
    if (-not (Test-Path -LiteralPath $py)) { Fail "找不到 python: $py" }
    & $py $audit $z1 $z2 --build-path $BuildPath
    if ($LASTEXITCODE -ne 0) { Fail "审计不通过（产物不可发布）" }
}

# -------------------------------------------------------------------- MANIFEST
Write-Host "[3/4] 写 MANIFEST ..."
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PkgDir 'update-manifest.ps1') -OutDir $OutDir

Write-Host "[4/4] 完成" -ForegroundColor Green
Write-Host ""
Write-Host "产物目录: $OutDir" -ForegroundColor Cyan
Write-Host ""
exit 0

<#
    bootstrap.ps1 -- prepare and check one extracted package

    The script locates the package from its own file, removes Windows download
    blocking, installs the bundled TeX cache, repairs the venv interpreter path,
    and checks the files used by the renderer.  -RunDemo runs demo.py afterwards.

    ErrorActionPreference stays Continue because PowerShell 5.1 can otherwise
    treat stderr from native commands as a terminating error.
#>

param([switch]$RunDemo)

$ErrorActionPreference = 'Continue'

# ----------------------------------------------------------------- 自身定位
# 优先 $PSScriptRoot（被 -File 调用时可靠），退化到 $MyInvocation
$root = $PSScriptRoot
if (-not $root) { $root = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $root) { $root = (Get-Location).Path }
try { $root = (Resolve-Path -LiteralPath $root).Path.TrimEnd('\') } catch {}

$LONGEST_REL = 146        # 包内最长的相对路径（构建时测得）
$SAFE_ROOT   = 260 - $LONGEST_REL - 20

Write-Host ""
Write-Host "== manimgl portable 安装/自检 ==" -ForegroundColor Cyan
Write-Host "包根目录 : $root"

# ------------------------------------------------- 路径过长 -> 自动迁移重跑
if ($root.Length -gt $SAFE_ROOT) {
    Write-Host ""
    Write-Host ("[!] 当前路径 {0} 字符；venv 内部还要深 {1} 字符，" -f $root.Length, $LONGEST_REL) -ForegroundColor Yellow
    Write-Host ("    超过 Windows 的 260 字符上限（安全上限约 {0}）。" -f $SAFE_ROOT) -ForegroundColor Yellow

    $short = Join-Path $env:LOCALAPPDATA 'manimgl-portable'
    if ($root -ieq $short) {
        Write-Host "    已经在最短位置了，仍然过长，无法自动修复。" -ForegroundColor Red
        Write-Host "    请手工把它挪到例如 D:\mgl 这样的短目录。" -ForegroundColor Red
        exit 1
    }

    Write-Host "    自动迁移到更短的位置：$short" -ForegroundColor Yellow
    # 复用前先确认目标是一份完整副本，避免复用上次残留的残缺目录
    $shortOk = (Test-Path -LiteralPath (Join-Path $short 'bootstrap.ps1')) -and
               (Test-Path -LiteralPath (Join-Path $short 'manim-env\pyvenv.cfg'))
    if (-not $shortOk) {
        Write-Host "    （首次迁移要复制约 0.5 GB，请稍候）"
        robocopy $root $short /E /NFL /NDL /NJH /NJS /NP /R:1 /W:1 | Out-Null
        if ($LASTEXITCODE -ge 8) {
            Write-Host "    复制失败（robocopy 代码 $LASTEXITCODE）。请手工挪到短目录。" -ForegroundColor Red
            exit 1
        }
    }
    Write-Host "    迁移完成，从新位置继续 ..." -ForegroundColor Green
    Write-Host ""
    & (Join-Path $short 'bootstrap.ps1')
    exit $LASTEXITCODE
}

# ------------------------------------------------------------- 自适应找 venv
$venv = $null
foreach ($name in @('manim-env', 'venv', '.venv')) {
    $p = Join-Path $root $name
    if (Test-Path -LiteralPath (Join-Path $p 'pyvenv.cfg')) { $venv = $p; break }
}
if (-not $venv) {
    $hit = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'pyvenv.cfg') } |
        Select-Object -First 1
    if ($hit) { $venv = $hit.FullName }
}
if (-not $venv) {
    Write-Host ""
    Write-Host "在 $root 下找不到含 pyvenv.cfg 的虚拟环境目录。" -ForegroundColor Red
    Write-Host "请确认压缩包完整解压（应有一个 manim-env 目录）。" -ForegroundColor Red
    exit 1
}
$cfg = Join-Path $venv 'pyvenv.cfg'
$py = Join-Path $venv 'Scripts\python.exe'
if (-not (Test-Path -LiteralPath $py)) { $py = Join-Path $venv 'bin\python' }   # 非 Windows 布局兜底
Write-Host "虚拟环境 : $venv"

# ---------------------------------------------------------------- 1. 解除封锁
Write-Host ""
Write-Host "[1/4] 解除「来自网络」标记 ..."
$exes = @(Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in '.exe', '.dll', '.ps1', '.cmd', '.bat', '.pyd' })
foreach ($f in $exes) { Unblock-File -LiteralPath $f.FullName -ErrorAction SilentlyContinue }
Write-Host ("      已处理 {0} 个可执行文件" -f $exes.Count)

# -------------------------------------------------------------- 2. 路径检查
Write-Host "[2/4] 路径检查 ..."
Write-Host ("      OK（{0} 字符，安全上限 {1}）" -f $root.Length, $SAFE_ROOT)

# ---------------------------------------------------------- 3. tectonic 缓存
Write-Host "[3/4] tectonic 缓存 ..."
$texCache = Join-Path $env:LOCALAPPDATA 'TectonicProject'
$okCache = Test-Path -LiteralPath (Join-Path $texCache 'Tectonic\cache\bundles')
if ($okCache) {
    Write-Host "      OK  已存在，首次编译可离线"
} else {
    # 自适应：包里任何 *tectonic*cache*.zip 都认
    $cacheZip = Get-ChildItem -LiteralPath $root -File -Filter '*.zip' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'tectonic' } | Select-Object -First 1
    if ($cacheZip) {
        Write-Host ("      未安装，正在从 {0} 解出（约 92 MB，十几秒）..." -f $cacheZip.Name)
        if (Get-Command tar -ErrorAction SilentlyContinue) {
            & tar -xf $cacheZip.FullName -C $env:LOCALAPPDATA
        } else {
            Expand-Archive -LiteralPath $cacheZip.FullName -DestinationPath $env:LOCALAPPDATA -Force
        }
        if (Test-Path -LiteralPath (Join-Path $texCache 'Tectonic\cache\bundles')) {
            Write-Host "      OK  安装完成，首次编译可离线"
        } else {
            Write-Host "      解出后仍未找到缓存，请手工把该 zip 解到 %LOCALAPPDATA%" -ForegroundColor Yellow
        }
    } else {
        Write-Host "      未找到 tectonic 缓存包" -ForegroundColor Yellow
        Write-Host "      首次渲染公式会联网下载 TeX 资源（约 90 MB）。" -ForegroundColor Yellow
    }
}

# ------------------------------------------------------------ 4. 解释器路径
Write-Host "[4/4] 解释器路径 ..."
$lines = @(Get-Content -LiteralPath $cfg)
$homeLine = $lines | Where-Object { $_ -match '^\s*home\s*=' } | Select-Object -First 1
$current = ''
if ($homeLine) { $current = ($homeLine -replace '^\s*home\s*=\s*', '').Trim() }

function Test-BasePython([string]$dir) {
    if (-not $dir) { return $false }
    if (-not (Test-Path -LiteralPath $dir)) { return $false }
    if ((Test-Path -LiteralPath (Join-Path $dir 'python.exe')) -or (Test-Path -LiteralPath (Join-Path $dir 'bin\python3'))) {
        $dll = @(Get-ChildItem -LiteralPath $dir -Filter 'python3*.dll' -File -ErrorAction SilentlyContinue)
        $lib = Test-Path -LiteralPath (Join-Path $dir 'Lib\os.py')
        $lib2 = Test-Path -LiteralPath (Join-Path $dir 'lib')
        return ($dll.Count -gt 0) -or $lib -or $lib2
    }
    return $false
}

$candidates = New-Object System.Collections.Generic.List[string]
# 0) 包内自带解释器（本包含 python\，目标机无需安装任何 Python）
$candidates.Add((Join-Path $root 'python'))
if ($current) { $candidates.Add($current) }
# 1) uv 管理的解释器
foreach ($uvRoot in @((Join-Path $env:APPDATA 'uv\python'), (Join-Path $env:LOCALAPPDATA 'uv\python'))) {
    if (Test-Path -LiteralPath $uvRoot) {
        Get-ChildItem -LiteralPath $uvRoot -Directory -Filter 'cpython-3.12*' -ErrorAction SilentlyContinue |
            ForEach-Object { $candidates.Add($_.FullName) }
    }
}
# 2) uv python find 3.12
if (Get-Command uv -ErrorAction SilentlyContinue) {
    $uvFound = (& uv python find 3.12 2>$null | Select-Object -First 1)
    if ($uvFound) { $candidates.Add((Split-Path -Parent ($uvFound -replace '"', '').Trim())) }
}
# 3) Windows py launcher
if (Get-Command py -ErrorAction SilentlyContinue) {
    $base = (& py -3.12 -c "import sys; print(sys.base_prefix)" 2>$null | Select-Object -First 1)
    if ($LASTEXITCODE -eq 0 -and $base) { $candidates.Add($base.Trim()) }
}
# 4) 常见安装位置
foreach ($d in @(
    (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312'),
    'C:\Python312',
    (Join-Path $env:ProgramFiles 'Python312')
)) { $candidates.Add($d) }

$found = $null
foreach ($c in $candidates) { if (Test-BasePython $c) { $found = $c.Trim(); break } }

if (-not $found) {
    Write-Host ""
    Write-Host "找不到任何 CPython 3.12（64 位）。" -ForegroundColor Yellow
    Write-Host "装一个再重跑本脚本（任意 3.12.x 都行）："
    Write-Host "    uv python install 3.12.10"
    exit 1
}

if ($found -ne $current) {
    $out = @($lines | ForEach-Object {
        if ($_ -match '^\s*home\s*=') { "home = $found" } else { $_ }
    })
    [System.IO.File]::WriteAllLines($cfg, $out, (New-Object System.Text.UTF8Encoding $false))
    Write-Host ("      已更新 home -> {0}" -f $found)
} else {
    Write-Host "      OK  已指向可用的解释器"
}

# ------------------------------------------------------------------ 工具校验
# ------------------------------------------ 5. 本机专有的绝对路径（换机器就崩）
Write-Host ""
Write-Host "-- custom_config.yml 绝对路径检查 --"
$cfgLocal = Join-Path $root 'custom_config.yml'
if (Test-Path -LiteralPath $cfgLocal) {
    $bad = @(Get-Content -LiteralPath $cfgLocal -ErrorAction SilentlyContinue |
        Where-Object { $_ -notmatch '^\s*#' } |
        Where-Object { $_ -match '[A-Za-z]:[\\/]' })
    if ($bad.Count -gt 0) {
        Write-Host "  [警告] 里面有绝对路径，换机器会直接崩：" -ForegroundColor Yellow
        $bad | ForEach-Object { Write-Host ("         " + $_.Trim()) -ForegroundColor Yellow }
        Write-Host "         建议注释掉，或改成裸名（例如 ffmpeg_bin: \"ffmpeg\"）" -ForegroundColor Yellow
    } else {
        Write-Host "  OK   没有本机专有的绝对路径"
    }
} else {
    Write-Host "  （无 custom_config.yml，用包内默认值）"
}

Write-Host ""
Write-Host "-- 自带工具 --"
$missing = 0
foreach ($f in @(
    'Scripts\tectonic.exe',
    'Scripts\dvisvgm.exe',
    'Scripts\ffmpeg.exe',
    'Scripts\texmf\web2c\texmf.cnf',
    'Lib\site-packages\manimlib\utils\tex_file_writing.py'
)) {
    if (Test-Path -LiteralPath (Join-Path $venv $f)) {
        Write-Host ("  OK   {0}" -f $f)
    } else {
        Write-Host ("  缺失 {0}" -f $f) -ForegroundColor Red
        $missing++
    }
}

# ------------------------------------------------------------------ 冒烟测试
Write-Host ""
Write-Host "-- 冒烟测试 --"
& $py -c "import manimlib; print('manimlib import OK')" 2>&1 |
    Select-String -NotMatch 'pkg_resources|UserWarning|Refrain|deprecated|SyntaxWarning|re\.match|elif re'

if ($missing -gt 0) {
    Write-Host ""
    Write-Host "$missing 个自带文件缺失，渲染前请先补齐。" -ForegroundColor Yellow
}

# ------------------------------------------------------------------ 可选：跑 demo
if ($RunDemo) {
    Write-Host ""
    Write-Host "-- 跑 demo（第一次编译公式较慢，请耐心）--" -ForegroundColor Cyan
    $demoPy = Join-Path $root 'demo.py'
    if (-not (Test-Path -LiteralPath $demoPy)) {
        Write-Host "找不到 demo.py" -ForegroundColor Red
        exit 1
    }
    Push-Location -LiteralPath $root
    & $py -m manimlib $demoPy Demo -w -m
    Pop-Location

    $vid = Join-Path $root 'videos\Demo.mp4'
    Write-Host ""
    if (Test-Path -LiteralPath $vid) {
        Write-Host "[成功] 视频已生成：videos\Demo.mp4" -ForegroundColor Green
        Start-Process explorer.exe -ArgumentList $root
    } else {
        Write-Host "[失败] 没有生成 videos\Demo.mp4" -ForegroundColor Red
        Write-Host "       请把上面窗口里的报错信息发回去。" -ForegroundColor Red
    }
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Host "完成。跑个 demo 确认整条链路（或双击 run-demo.cmd）：" -ForegroundColor Cyan
Write-Host ("  `"{0}`" -m manimlib demo.py Demo -w -m" -f $py)
Write-Host "  成功标志: 当前目录下 videos\Demo.mp4"
Write-Host ""

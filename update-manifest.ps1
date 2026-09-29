<#
    update-manifest.ps1 -- write MANIFEST.txt for the zip and exe artifacts

    Shared by build.ps1 and build-exe.ps1 so both commands produce the same format.
#>
param(
    [Parameter(Mandatory = $true)][string]$OutDir,
    [string]$Note = ''
)

$lines = @(
    "manimgl portable -- release manifest",
    "built: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    ""
)
$items = @(Get-ChildItem -LiteralPath $OutDir -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in '.zip', '.exe' } | Sort-Object Name)
foreach ($f in $items) {
    $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
    $lines += ("{0,-38} {1,9:N1} MB  sha256={2}" -f $f.Name, ($f.Length / 1MB), $h)
}
$lines += ""
if ($Note) { $lines += $Note; $lines += "" }
$lines += "构建: build.ps1（打包+审计）· build-exe.ps1（单文件 exe）"

$path = Join-Path $OutDir 'MANIFEST.txt'
$lines | Set-Content -LiteralPath $path -Encoding UTF8
Write-Host "  清单 -> $path  ($($items.Count) 项)"

param([string]$VlcDirectory = "$env:ProgramFiles\VideoLAN\VLC")
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
$runtimeDirectory = Join-Path $projectDirectory 'src-tauri\resources\vlc'
if (-not (Test-Path -LiteralPath (Join-Path $VlcDirectory 'libvlc.dll'))) {
    throw 'Install 64-bit VLC 3 from https://www.videolan.org/vlc/ or pass -VlcDirectory to this script.'
}
New-Item -ItemType Directory -Path $runtimeDirectory -Force | Out-Null
foreach ($runtimeFile in @('libvlc.dll', 'libvlccore.dll', 'COPYING.txt', 'AUTHORS.txt', 'README.txt')) {
    Copy-Item -LiteralPath (Join-Path $VlcDirectory $runtimeFile) -Destination $runtimeDirectory -Force
}
Copy-Item -LiteralPath (Join-Path $VlcDirectory 'plugins') -Destination $runtimeDirectory -Recurse -Force
Write-Host "Prepared VLC runtime in $runtimeDirectory. These generated files are excluded from Git."

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $projectRoot
try {
    & .\.venv\Scripts\python.exe -m PyInstaller --noconfirm --distpath build/worker --workpath build/pyinstaller tools/raster_worker.spec
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo empaquetar el procesador raster.' }
    Push-Location apps/field_shift
    try {
        flutter build windows --release
        if ($LASTEXITCODE -ne 0) { throw 'Falló la compilación Windows.' }
    } finally { Pop-Location }
    $releasePath = Join-Path $projectRoot 'apps/field_shift/build/windows/x64/runner/Release'
    $workersPath = Join-Path $releasePath 'workers'
    New-Item -ItemType Directory -Force -Path $workersPath | Out-Null
    Copy-Item -LiteralPath 'build/worker/raster_worker' -Destination $workersPath -Recurse -Force
    Copy-Item -LiteralPath 'docs/USO_WINDOWS.md' -Destination $releasePath -Force
    $crtPath = Get-ChildItem -Path 'C:/Program Files/Microsoft Visual Studio/*/*/VC/Redist/MSVC/*/x64/Microsoft.VC*.CRT' -Directory | Sort-Object FullName -Descending | Select-Object -First 1
    if ($null -eq $crtPath) { throw 'No se encontró el runtime redistribuible MSVC.' }
    Get-ChildItem -LiteralPath $crtPath.FullName -Filter '*.dll' | Copy-Item -Destination $releasePath -Force
    # Keep generated distributions versioned; never delete user data/installations.
    $bundlePath = Join-Path $projectRoot 'dist/NASA_Field_Shift_Windows_0.2.2'
    New-Item -ItemType Directory -Force -Path $bundlePath | Out-Null
    Get-ChildItem -LiteralPath $releasePath | Copy-Item -Destination $bundlePath -Recurse -Force
    Write-Output (Join-Path $bundlePath 'field_shift.exe')
} finally { Pop-Location }

param([int]$AppProcessId)
$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$samples=@()
for($i=0;$i -lt 5;$i++) {
    $app=Get-Process -Id $AppProcessId
    $samples += [pscustomobject]@{utc=(Get-Date).ToUniversalTime().ToString('o');cpuSeconds=$app.CPU;workingSetBytes=$app.WorkingSet64;privateBytes=$app.PrivateMemorySize64;peakWorkingSetBytes=$app.PeakWorkingSet64}
    Start-Sleep -Seconds 1
}
$gpu=$null
if(Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
    $gpu=(& nvidia-smi --query-gpu=name,memory.used,utilization.gpu --format=csv,noheader,nounits) -join '; '
}
$bundle=Join-Path $projectRoot 'dist/NASA_Field_Shift_Windows_0.1.0'
$bytes=(Get-ChildItem -LiteralPath $bundle -Recurse -File | Measure-Object Length -Sum).Sum
[pscustomobject]@{scenario='Release abierto en reposo después de cargar mapa; 5 muestras de 1 segundo, sin benchmark comparativo';pid=$AppProcessId;samples=$samples;distributionBytes=$bytes;gpuSystemWide=$gpu;limitations='GPU/VRAM si aparecen son del sistema completo, no de la aplicación. No se midió tráfico de red, FPS ni carga sostenida.'} | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 (Join-Path $projectRoot 'docs/evidence/performance_windows.json')

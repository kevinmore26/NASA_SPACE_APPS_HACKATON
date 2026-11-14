param(
    [string]$Proyecto = (Get-Location).Path,
    [string]$Salida = ""
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$raiz = (Resolve-Path -LiteralPath $Proyecto).ProviderPath.TrimEnd([char[]]@('\', '/'))
if (-not (Test-Path -LiteralPath $raiz -PathType Container)) {
    throw "No existe la carpeta del proyecto: $raiz"
}

if ([string]::IsNullOrWhiteSpace($Salida)) {
    $nombre = Split-Path -Path $raiz -Leaf
    $padre = Split-Path -Path $raiz -Parent
    $Salida = Join-Path $padre ("{0}_fuentes_{1}.zip" -f $nombre, (Get-Date -Format 'yyyyMMdd_HHmmss'))
}
$Salida = [System.IO.Path]::GetFullPath($Salida)
if (Test-Path -LiteralPath $Salida) {
    throw "El ZIP de destino ya existe; elige otra ruta: $Salida"
}

# Limites conservadores para cargas en fuentes de ChatGPT.
$limiteTotal = 450MB
$limiteArchivo = 20MB
$limiteRecurso = 3MB

$carpetasExcluidas = @(
    '.git', '.dart_tool', 'build', '.gradle', '.idea', '.vs', '.cxx',
    'node_modules', 'Pods', 'DerivedData', 'coverage', 'dist', 'out',
    'Debug', 'Release', 'CMakeFiles', '.venv', 'venv', '__pycache__',
    '.pytest_cache', '.next', '.turbo', 'tmp', 'temp', 'cache', '.cache'
)

$extensionesCodigo = @(
    '.dart', '.yaml', '.yml', '.json', '.md', '.txt', '.xml', '.arb',
    '.gradle', '.kts', '.kt', '.java', '.swift', '.m', '.mm',
    '.h', '.hpp', '.c', '.cc', '.cpp', '.cmake', '.pro', '.def',
    '.rc', '.manifest', '.properties', '.plist', '.entitlements',
    '.pbxproj', '.xcconfig', '.sh', '.bat', '.cmd', '.ps1', '.py',
    '.sql', '.html', '.css', '.js', '.jsx', '.ts', '.tsx', '.lock',
    '.glsl', '.vert', '.frag', '.metal', '.gitignore', '.gitattributes'
)
$extensionesRecursos = @('.png', '.jpg', '.jpeg', '.webp', '.svg', '.ico', '.ttf', '.otf', '.woff', '.woff2')
$nombresSinExtension = @('.gitignore', '.gitattributes', '.metadata', 'Dockerfile', 'Makefile', 'gradlew', 'LICENSE')
$nombresExcluidos = @(
    'local.properties', 'key.properties', 'google-services.json',
    'GoogleService-Info.plist', 'firebase_options.dart', 'id_rsa', 'id_ed25519'
)

$archivos = New-Object 'System.Collections.Generic.List[System.IO.FileInfo]'
$omitidos = New-Object 'System.Collections.Generic.List[string]'
$pendientes = New-Object 'System.Collections.Generic.Stack[string]'
$pendientes.Push($raiz)

while ($pendientes.Count -gt 0) {
    $actual = $pendientes.Pop()
    foreach ($subdir in [System.IO.Directory]::EnumerateDirectories($actual)) {
        $nombreDir = [System.IO.Path]::GetFileName($subdir)
        if ($carpetasExcluidas -contains $nombreDir) { continue }
        if (([System.IO.File]::GetAttributes($subdir) -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
        $pendientes.Push($subdir)
    }

    foreach ($rutaArchivo in [System.IO.Directory]::EnumerateFiles($actual)) {
        $archivo = New-Object System.IO.FileInfo($rutaArchivo)
        $nombreArchivo = $archivo.Name
        $extension = $archivo.Extension.ToLowerInvariant()

        if ($rutaArchivo -eq $Salida) { continue }
        if ($nombresExcluidos -contains $nombreArchivo -or
            $nombreArchivo -like '.env*' -or
            $nombreArchivo -match '(?i)(secret|credential|service[-_]?account|private[-_]?key)' -or
            $extension -in @('.pem', '.p12', '.pfx', '.key', '.jks', '.keystore', '.sqlite', '.db')) {
            continue
        }

        $esRecurso = $extensionesRecursos -contains $extension
        $esCodigo = ($extensionesCodigo -contains $extension) -or ($nombresSinExtension -contains $nombreArchivo)
        if (-not ($esCodigo -or $esRecurso)) { continue }

        $limite = if ($esRecurso) { $limiteRecurso } else { $limiteArchivo }
        if ($archivo.Length -gt $limite) {
            $omitidos.Add("Archivo grande: $($archivo.FullName)")
            continue
        }
        $archivos.Add($archivo)
    }
}

# Priorizar codigo/configuracion antes que imagenes y fuentes.
$ordenados = @($archivos | Sort-Object @{ Expression = { if ($extensionesRecursos -contains $_.Extension.ToLowerInvariant()) { 1 } else { 0 } } }, FullName)
$acumulado = [long]0
$incluidos = New-Object 'System.Collections.Generic.List[System.IO.FileInfo]'
foreach ($archivo in $ordenados) {
    if ($acumulado + $archivo.Length -gt $limiteTotal) {
        $omitidos.Add("Limite total: $($archivo.FullName)")
        continue
    }
    $incluidos.Add($archivo)
    $acumulado += $archivo.Length
}

if ($incluidos.Count -eq 0) { throw 'No se encontraron archivos fuente con los filtros actuales.' }

$zip = [System.IO.Compression.ZipFile]::Open($Salida, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($archivo in $incluidos) {
        $relativa = $archivo.FullName.Substring($raiz.Length).TrimStart([char[]]@('\', '/'))
        $entrada = $relativa.Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip, $archivo.FullName, $entrada,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
}
finally {
    $zip.Dispose()
}

$tamanoMB = [math]::Round((Get-Item -LiteralPath $Salida).Length / 1MB, 2)
Write-Host "ZIP creado: $Salida" -ForegroundColor Green
Write-Host "Archivos incluidos: $($incluidos.Count)"
Write-Host "Tamano ZIP: $tamanoMB MB"
Write-Host "Archivos omitidos por tamano/limite: $($omitidos.Count)"
if ($omitidos.Count -gt 0) {
    Write-Warning 'Revisar estos archivos omitidos (primeros 20):'
    $omitidos | Select-Object -First 20 | ForEach-Object { Write-Host " - $_" }
}
if ((Get-Item -LiteralPath $Salida).Length -gt 500MB) {
    throw 'El archivo final supera 500 MB. No lo subas; reduce los limites.'
}

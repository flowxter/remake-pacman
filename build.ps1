# Exporta el juego y deja en build/ un ZIP listo para pasar a otro PC.

$GodotVersion = "4.7.2.stable"
$Root = $PSScriptRoot
$Stage = Join-Path $Root "build\PacManRemake"

function Find-Godot {
    $cmd = Get-Command godot_console -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $pkg = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
    $hit = Get-ChildItem $pkg -Recurse -Filter "Godot_v4*console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $hit) {
        $hit = Get-ChildItem $pkg -Recurse -Filter "Godot_v4*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if ($hit) { return $hit.FullName }
    Write-Host "No encuentro Godot 4. Instalalo con: winget install GodotEngine.GodotEngine" -ForegroundColor Red
    exit 2
}

# Plantillas de exportacion. El paquete oficial son 1.2 GB con todas las
# plataformas; tools/fetch_template.py saca solo la de Windows (69 MB).
$tplDir = Join-Path $env:APPDATA "Godot\export_templates\$GodotVersion"
$tpl = Join-Path $tplDir "windows_release_x86_64.exe"
if (-not (Test-Path $tpl)) {
    Write-Host "Faltan las plantillas de exportacion, bajando solo la de Windows..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force $tplDir | Out-Null
    python -I (Join-Path $Root "tools\fetch_template.py") $tplDir
    if ($LASTEXITCODE -ne 0) { Write-Host "Fallo la descarga de plantillas" -ForegroundColor Red; exit 1 }
    Set-Content -Path (Join-Path $tplDir "version.txt") -Value $GodotVersion -NoNewline -Encoding ascii
}

$godot = Find-Godot
New-Item -ItemType Directory -Force (Join-Path $Root "build") | Out-Null

Write-Host "`nExportando..." -ForegroundColor Cyan
& $godot --headless --path $Root --export-release "Windows Desktop" (Join-Path $Root "build\PacManRemake.exe") | Out-Null
$exe = Join-Path $Root "build\PacManRemake.exe"
if (-not (Test-Path $exe)) { Write-Host "La exportacion no produjo el .exe" -ForegroundColor Red; exit 1 }

Write-Host "Empaquetando..." -ForegroundColor Cyan
if (Test-Path $Stage) { Remove-Item $Stage -Recurse -Force }
New-Item -ItemType Directory -Force $Stage | Out-Null
Copy-Item $exe $Stage
Copy-Item (Join-Path $Root "LEEME.txt") $Stage

# Los assets van SUELTOS junto al .exe, no dentro: asi se pueden cambiar sin
# reexportar, y el binario no lleva material con copyright ajeno.
$assets = Join-Path $Root "assets"
if (Test-Path (Join-Path $assets "sprites")) {
    Copy-Item $assets (Join-Path $Stage "assets") -Recurse
    # Los .import los genera Godot para el proyecto; fuera de el no sirven.
    Get-ChildItem (Join-Path $Stage "assets") -Recurse -Filter "*.import" | Remove-Item -Force
} else {
    Write-Host "  (sin assets propios: el juego usara los procedurales)" -ForegroundColor Yellow
}

$zip = Join-Path $Root "build\PacManRemake-win64.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $Stage -DestinationPath $zip -CompressionLevel Optimal

$mb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Host "`nListo: $zip ($mb MB)" -ForegroundColor Green
Write-Host "Se extrae y se ejecuta PacManRemake.exe. No hace falta instalar nada."

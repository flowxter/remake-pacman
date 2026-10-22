# Ejecuta los tests headless. Devuelve codigo distinto de 0 si algo falla.

function Find-Godot {
    $cmd = Get-Command godot_console -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $pkg = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
    $hit = Get-ChildItem $pkg -Recurse -Filter "Godot_v4*console.exe" -ErrorAction SilentlyContinue |
           Select-Object -First 1
    if ($hit) { return $hit.FullName }
    $hit = Get-ChildItem $pkg -Recurse -Filter "Godot_v4*.exe" -ErrorAction SilentlyContinue |
           Select-Object -First 1
    if ($hit) { return $hit.FullName }
    Write-Host "No encuentro Godot 4. Instalalo con: winget install GodotEngine.GodotEngine" -ForegroundColor Red
    exit 2
}

$godot = Find-Godot
$failed = 0
foreach ($t in @("res://tests/test_maze.gd", "res://tests/test_sim.gd")) {
    Write-Host "`n=== $t ===" -ForegroundColor Cyan
    & $godot --headless --path $PSScriptRoot --script $t
    if ($LASTEXITCODE -ne 0) { $failed = 1 }
}
if ($failed -ne 0) { Write-Host "`nHAY FALLOS" -ForegroundColor Red } else { Write-Host "`nTODO OK" -ForegroundColor Green }
exit $failed

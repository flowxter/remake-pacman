# Lanza el juego. Busca Godot 4 en PATH y en la instalacion de winget.

function Find-Godot {
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $pkg = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
    $hit = Get-ChildItem $pkg -Recurse -Filter "Godot_v4*.exe" -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -notlike "*console*" } |
           Select-Object -First 1
    if ($hit) { return $hit.FullName }
    Write-Host "No encuentro Godot 4. Instalalo con: winget install GodotEngine.GodotEngine" -ForegroundColor Red
    exit 2
}

& (Find-Godot) --path $PSScriptRoot @args

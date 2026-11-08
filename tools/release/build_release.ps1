# Construit les fichiers d'une version : le contenu du jeu (.pck), le moteur (.exe) et version.json, dans build/release/.
# Le moteur est le modèle d'export de Godot, sans contenu : il ne change que si Godot change, donc les amis ne le
# retélécharge pas à chaque mise à jour. Usage : powershell -File tools/release/build_release.ps1
param(
    [string]$Godot = 'C:\Users\ilan_\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe',
    [string]$Template = "$env:APPDATA\Godot\export_templates\4.7.2.stable\windows_release_x86_64.exe"
)
$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$Out = Join-Path $Root 'build\release'
New-Item -ItemType Directory -Force $Out | Out-Null
Set-Location $Root

& $Godot --headless --path . --import | Out-Null
$pck = Join-Path $Out 'JeuDePirates.pck'
& $Godot --headless --path . --export-pack 'Windows' $pck
if (-not (Test-Path $pck)) { throw "L'export du contenu a échoué." }
$exe = Join-Path $Out 'JeuDePirates.exe'
# Un antivirus peut garder le fichier un instant : quelques tentatives avant d'abandonner.
for ($try = 1; $try -le 6; $try++) {
    try { Copy-Item $Template $exe -Force; break } catch { if ($try -eq 6) { throw }; Start-Sleep -Seconds 5 }
}

function Describe([string]$path) {
    [ordered]@{ name = Split-Path -Leaf $path; size = (Get-Item $path).Length; sha256 = (Get-FileHash $path -Algorithm SHA256).Hash.ToLower() }
}
$manifest = [ordered]@{ version = (Get-Date -Format 'yyyy.MM.dd-HHmm'); exe = Describe $exe; pck = Describe $pck }
$manifest | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $Out 'version.json') -Encoding UTF8
Get-ChildItem $Out | Select-Object Name, @{ n = 'Mo'; e = { [math]::Round($_.Length / 1MB, 1) } }

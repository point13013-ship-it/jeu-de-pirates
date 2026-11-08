# Publie une nouvelle version du Jeu de pirates sur GitHub Releases : construit les fichiers (build_release.ps1) et crée la
# release. Les joueurs qui ont la salle de jeux (le lanceur d'Aventurier de Poche, jeux.json) la reçoivent d'un clic sur
# « Mettre à jour ». Le dépôt GitHub doit exister (une seule fois : gh repo create point13013-ship-it/jeu-de-pirates --public).
# Usage : powershell -ExecutionPolicy Bypass -File tools/release/publish.ps1 -Notes "ce qui change"
param(
    [string]$Notes = 'Nouvelle version.',
    [string]$Repo = 'point13013-ship-it/jeu-de-pirates',
    [string]$Gh = 'C:\Program Files\GitHub CLI\gh.exe'
)
$ErrorActionPreference = 'Stop'
$Root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $Root
& (Join-Path $PSScriptRoot 'build_release.ps1') | Out-Null
$Out = Join-Path $Root 'build\release'
$manifest = Get-Content (Join-Path $Out 'version.json') -Raw | ConvertFrom-Json
$version = $manifest.version

# GitHub refuse une release dans un dépôt vide : on y met d'abord un petit README (une seule fois).
$ErrorActionPreference = 'Continue'
& $Gh api "repos/$Repo/commits?per_page=1" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    $readme = "# Jeu de pirates`n`nVersions du jeu. Elles se téléchargent depuis la salle de jeux (Jouer.bat), bouton « Mettre à jour ».`n"
    $content = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($readme))
    & $Gh api -X PUT "repos/$Repo/contents/README.md" -f message="README" -f content=$content 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Impossible d'initialiser le dépôt (existe-t-il ?)." }
}

& $Gh release create "v$version" (Join-Path $Out 'version.json') (Join-Path $Out 'JeuDePirates.pck') (Join-Path $Out 'JeuDePirates.exe') `
    --repo $Repo --title "Version $version" --notes $Notes --latest
if ($LASTEXITCODE -ne 0) { throw 'La publication a échoué.' }
Write-Host "Publié : https://github.com/$Repo/releases/tag/v$version"

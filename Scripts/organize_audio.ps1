# Organiza todos os áudios em subpastas (UI, ambient, music, player, world).
# Execute uma vez no PowerShell: .\scripts\organize_audio.ps1
# Ou no Cursor: terminal na raiz do projeto e rodar o comando abaixo.

$root = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
$projectRoot = Split-Path $root -Parent
$sounds = Join-Path $projectRoot "Assets\sounds"

function Move-Audio {
    param([string]$From, [string]$ToDir, [string]$FileName)
    $fromPath = Join-Path $sounds $From
    $toPath = Join-Path $sounds (Join-Path $ToDir $FileName)
    if (Test-Path $fromPath) {
        $toDirFull = Split-Path $toPath -Parent
        if (-not (Test-Path $toDirFull)) { New-Item -ItemType Directory -Force -Path $toDirFull | Out-Null }
        Move-Item -Path $fromPath -Destination $toPath -Force
        $importFrom = "$fromPath.import"
        $importTo = "$toPath.import"
        if (Test-Path $importFrom) {
            Move-Item -Path $importFrom -Destination $importTo -Force
            $content = Get-Content $importTo -Raw
            $newResPath = "res://Assets/sounds/$ToDir/$FileName".Replace("\", "/")
            $content = $content -replace 'source_file="res://[^"]*"', "source_file=`"$newResPath`""
            Set-Content -Path $importTo -Value $content -NoNewline
        }
        Write-Host "OK: $From -> $ToDir/$FileName"
    }
}

# Raiz do projeto (attack_sword)
$projRoot = $projectRoot
$attackFrom = Join-Path $projRoot "attack_sword.mp3"
$playerDir = Join-Path $sounds "player"
if (Test-Path $attackFrom) {
    if (-not (Test-Path $playerDir)) { New-Item -ItemType Directory -Force -Path $playerDir | Out-Null }
    $attackTo = Join-Path $playerDir "attack_sword.mp3"
    Move-Item -Path $attackFrom -Destination $attackTo -Force
    $importFrom = "$attackFrom.import"
    $importTo = "$attackTo.import"
    if (Test-Path $importFrom) {
        Move-Item -Path $importFrom -Destination $importTo -Force
        (Get-Content $importTo -Raw) -replace 'source_file="res://attack_sword.mp3"', 'source_file="res://Assets/sounds/player/attack_sword.mp3"' | Set-Content $importTo -NoNewline
    }
    Write-Host "OK: attack_sword.mp3 (raiz) -> player/attack_sword.mp3"
}

# Sons da raiz de sounds/ -> subpastas
Move-Audio -From "button.mp3" -ToDir "UI" -FileName "button.mp3"
Move-Audio -From "hover.mp3" -ToDir "UI" -FileName "hover.mp3"
Move-Audio -From "teleport.mp3" -ToDir "UI" -FileName "teleport.mp3"
Move-Audio -From "windaudio.mp3" -ToDir "ambient" -FileName "windaudio.mp3"
Move-Audio -From "music_ingame.mp3" -ToDir "music" -FileName "music_ingame.mp3"
Move-Audio -From "night.wav" -ToDir "ambient" -FileName "night.wav"
Move-Audio -From "day.wav" -ToDir "ambient" -FileName "day.wav"
Move-Audio -From "ambient-sound.mp3" -ToDir "ambient" -FileName "ambient-sound.mp3"
Move-Audio -From "street-corner-jazz-cafe-338559.mp3" -ToDir "music" -FileName "street-corner-jazz-cafe-338559.mp3"
Move-Audio -From "fast-sword.wav" -ToDir "player" -FileName "fast-sword.wav"
Move-Audio -From "WASD Sound Grass Run 06.wav" -ToDir "player" -FileName "WASD Sound Grass Run 06.wav"

Write-Host "Concluido. Abra o projeto no Godot para reimportar se necessario."

@echo off
chcp 65001 >nul
title Jeu de pirates
set GODOT=C:\Users\ilan_\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe
echo.
echo  Que veux-tu faire ?
echo    1 = jouer seul
echo    2 = heberger une partie (tes amis te rejoignent)
echo    3 = rejoindre un ami
echo.
choice /c 123 /n /m "Tape 1, 2 ou 3 : "
set MODE=%errorlevel%

if %MODE%==3 goto rejoindre

echo.
echo  Quel bateau ?
echo    1 = sloop (2 places)
echo    2 = brigantin (3 places)
echo    3 = galion (4 places)
echo.
choice /c 123 /n /m "Tape 1, 2 ou 3 : "
if errorlevel 3 (set SHIP=galion) else if errorlevel 2 (set SHIP=brigantin) else (set SHIP=sloop)
if %MODE%==2 (
    start "" "%GODOT%" --path "%~dp0." scenes/sailing.tscn -- --host --ship=%SHIP%
) else (
    start "" "%GODOT%" --path "%~dp0." scenes/sailing.tscn -- --ship=%SHIP%
)
goto fin

:rejoindre
echo.
set /p IP=Code d'invitation de l'ami qui heberge (affiche en haut a droite chez lui) :
start "" "%GODOT%" --path "%~dp0." scenes/sailing.tscn -- --join=%IP%

:fin

@echo off
chcp 65001 >nul
title Jeu de pirates
echo.
echo  Quel bateau ?
echo    1 = sloop (2 places)
echo    2 = brigantin (3 places)
echo    3 = galion (4 places)
echo.
choice /c 123 /n /m "Tape 1, 2 ou 3 : "
if errorlevel 3 (set SHIP=galion) else if errorlevel 2 (set SHIP=brigantin) else (set SHIP=sloop)
start "" "C:\Users\ilan_\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." scenes/sailing.tscn -- --ship=%SHIP%

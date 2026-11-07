@echo off
chcp 65001 >nul
title Jeu de pirates
set GODOT=C:\Users\ilan_\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe
rem Tout se choisit dans le menu du jeu : jouer seul, heberger, rejoindre, creer son pirate.
start "" "%GODOT%" --path "%~dp0." scenes/sailing.tscn

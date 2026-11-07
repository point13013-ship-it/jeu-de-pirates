# Jouer avec des amis

## Préparer le jeu à envoyer
Le jeu complet tient dans un seul fichier : `build/JeuDePirates.exe` (environ 110 Mo).
Pour le refaire après une modification, depuis ce dossier :

```
"C:\Users\ilan_\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --export-release "Windows" build/JeuDePirates.exe
```

Envoie ce fichier à tes amis (Google Drive, WeTransfer… il est trop gros pour Discord sans Nitro).
Windows peut afficher « Windows a protégé votre ordinateur » : cliquer sur « Informations
complémentaires » puis « Exécuter quand même » (le jeu n'est pas signé).

## Héberger (toi)
1. Lance le jeu, choisis le bateau, clique sur **Héberger une partie**.
2. Le jeu demande à ta box d'ouvrir le port UDP 7777 (il le referme quand tu quittes).
3. En haut à droite s'affiche ton **code d'invitation** (ex. `K7QD-M2XP-9WAB`), déjà copié :
   colle-le à tes amis.

Si la box refuse (UPnP désactivé, ou fournisseur qui partage une adresse entre plusieurs foyers),
le jeu l'indique. Deux solutions :
- ouvrir à la main le port **UDP 7777** vers ton PC dans l'interface de ta box ;
- ou installer tous un VPN gratuit de jeu (Radmin VPN ou ZeroTier), rejoindre le même réseau, et
  utiliser le code « pour un ami chez toi » affiché par le jeu.

## Rejoindre (tes amis)
1. Lancer le jeu, taper le code d'invitation dans le champ, cliquer sur **Rejoindre**.
2. Ils apparaissent sur ton bateau (jusqu'à 4 joueurs, selon le bateau choisi pour l'équipage).

## Commandes
ZQSD ou flèches : marcher — E : agir (barre, voiles, ancre, boulets, canons) — R : affaler les voiles.

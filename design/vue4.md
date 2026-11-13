# Vue 4 : la mer en perspective basse, la terre en 3/4

Décidée le 14/11 avec Ilan (réglage retenu : 7° et zoom 0,5, comparé à 13° et 22°).

## Principe

- **Un seul format de pixel.** Le jeu est rendu en gros pixels (`_hd()` = 1, comme à 960x540) partout ; `--hd=2` redonne le rendu fin.
- **En mer, caméra en perspective basse (7°)** : horizon, ciel et brume visibles, on voit les îles arriver de loin.
  Actif quand le pirate est sur le pont, à la nage, sur le radeau, sur une échelle de mât ou dans la vigie.
  À la barre, la caméra se place derrière le bateau.
- **À terre et dans la cale : 3/4 orthographique** (40°), comme avant : ville, îles, combat.
- **Le changement est direct et automatique** (pas de transition) : projection, inclinaison, zoom et cadrage changent à la même image,
  dès que le pirate change d'endroit. Un répit de 0,15 s évite de basculer en boucle au bord de l'eau.
- La perspective est réglée à l'échelle du plan du pirate (fov = 2·atan(taille/2/60)) : là où il se tient, un pixel du jeu a la même
  taille qu'en orthographique.

## Réglages

- `VUE4_ELEV` (7°), `VUE4_ZOOM_SEA` (0,5) dans `sailing_game.gd`.
- En jeu : molette enfoncée + souris haut/bas = inclinaison de la vue mer (5° à 32°) ; molette = zoom (plancher 0,4) ;
  trois clics rapides sur la molette = vue de base.
- `--no-vue4` : ancienne vue orthographique. Essais : `--v4-elev=<deg>`, `--v4-test-ship=<s>` (remet le pirate sur le pont à cet instant).

## Vérifié / pas vérifié

- Captures : `qa_vue4/defaut_mer.png`, `defaut_terre.png`, `ancienne_mer.png` ; tests unitaires : tous verts sauf `test_town.gd`
  (déjà en échec sur la branche avant ce changement).
- Pas rejoués en jeu : nager au bord de l'eau, monter au mât, entrer dans la cale, mer en mouvement longue durée, jeu à plusieurs.

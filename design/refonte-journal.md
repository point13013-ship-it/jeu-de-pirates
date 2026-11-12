# Refonte gameplay : journal des lots

Branche `feature/refonte-gameplay`. Tous les réglages ajoutés sont dans `src/game_config.gd` (une constante commentée par
valeur). Les sons marqués **PROVISOIRE** dans `src/audio/synth.gd` sont fabriqués par le code en attendant de vrais fichiers
(Epidemic Sound). Lancer les tests : `godot --headless --path . -s tests/unit/test_X.gd` (`test_town.gd` échouait déjà
avant la refonte : il attend 10 habitants, il y en a 11 depuis l'armurier).

Options d'essai ajoutées (après `--`) : `--look-seed=N`, `--fake-remote=dx,dy` (+ `--fake-carry=t:calice`,
`--fake-act=repair`, `--fake-swim`), `--local-only` (héberger sans alerte du pare-feu), `--swell=0..1`, `--down=t`,
`--water-time=s`.

Version réseau : **12** (tout l'équipage doit avoir la même version).

---

## Lot 1 : bugs

| | Cause | Correction |
|---|---|---|
| 1.1 Retour au point de départ en sautant sur une estrade | À l'atterrissage, le sol était cherché à la hauteur de départ | Plus haute surface sous les pieds (`Land.surface_below`) ; le flanc d'une estrade trop haute arrête le saut |
| 1.2 HUD haut droit qui se chevauche | État réseau posé à hauteur fixe sur les lignes de l'or | Colonne empilée (`VBoxContainer`) |
| 1.3 Ennemi tout blanc quand on le frappe | Voile blanc opaque | Flash rouge-orangé 90 ms, recul, étincelles |
| 1.4 Pirate « sans visage » / beige après un skin d'arme | 1) palette du filtre qui ne faisait que grossir ; 2) **feuilles de sprites composées en parallèle** : couches mal empilées | Palette refaite à partir des pirates affichés ; une composition à la fois |
| 1.5 Sable en ville | Plage dessinée mais pas marchable | Retirée au chargement (sol, palmiers, collisions) |
| 1.6 Pluie seulement sur le bateau | La surface de la mer, transparente, passait devant les gouttes | Pluie dessinée après la mer, 70 m autour de la vue, impacts sur l'eau |
| 1.7 Traversée de la coque vers la cabine | Recalage au « point libre le plus proche » à travers les murs ; remonter par la coque posait dans la cabine | Atterrissage seulement sans traverser de mur ; on ne remonte à bord que par l'échelle |

## Lot 2 : personnage, actions

- Sprint -10 %. Saut : élan gardé, contrôle en l'air limité, descente plus franche (3 m en marchant, ~4,5 m en courant).
- Saut : écrasement du sprite à l'appel et à la réception, son, poussière (vu par tous).
- Porter : objet entre les mains, visible par tous ; pas d'arme ni de pouvoir les mains prises ; **G** pose au sol,
  **E** reprend (à terre).
- Actions longues (`TimedAction`) : jauge circulaire, sons 3D (`Sfx3D`), interruption (bouger, sauter, frapper, coup reçu),
  geste vu par les autres. Ancre 3,5 s, réparer 2,5 s, écoper 1,5 s, hisser un camarade 1,6 s.
- Échelle de coque : animation d'escalade, pas sur le bois ; à la nage on ne remonte que par l'échelle.

## Lot 3 : bateau

- Vitesse +10 %, malus de mauvais vent -25 %. Houle (pluie, orage) : vagues, tangage, caméra, son de coque, maniabilité.
- Son de coque : gerbes au hasard. Roue de gouvernail détaillée qui tourne avec la barre (chez tous) et grince.
- Voiles : toile (tissage, coutures, usure), panneaux moins contrastés. Cale plus grande et décorée. Brigantin : canons écartés.
- **Non traité** : 3.1 agrandir le pont, 3.2 reculer la cabine (modèles Blender : `tools/art/blender/make_ship.py`, Blender
  absent de cette machine). Pas d'IK des mains sur la roue (personnages en pixel art).

## Lot 4 : mort, eau, réapparition

- À terre à 0 PV (25 s), relevé par un camarade (4 s, compte à rebours en pause), sinon mort : objet porté et pouvoir de
  baie perdus, réapparition sur le bateau après 10 s.
- Eau : sirène à 20 s (E : retour à bord), requins à 45 s, morsures dès 60 s (un coup de sabre les fait fuir), noyade à 90 s
  (alerte 15 s avant). Remise à zéro en quittant l'eau. Les autres voient l'état « à terre », la sirène et les ailerons.

## Lot 5 : ennemis (partie 1)

- Coques +25 %, 10 % plus lents, apparitions plus rares (premier à 90 s, puis 150 à 300 s).
- Quatre rangs (★ sloop, ★★ sloop, ★★★ brigantin, ★★★★ galion, poids 52/30/14/4) : résistance, canonniers, stock de
  planches et butin croissants (`GameConfig.ENEMY_RANKS`), couleurs propres (voiles, coque, pavillon), rang affiché.
- L'équipage ennemi répare au calme (une planche par voie d'eau, stock limité). Un navire qui nous touche apparaît sur la
  carte de tout l'équipage (60 s sans échange de tirs, ou jusqu'au naufrage).
- Mobs : un boulet direct les blesse et les sonne 1,5 s ; blessés et à l'écart, ils mangent une ration (2) pour se soigner.
- **Non traités** : 6.5 abordage (marcher sur un autre bateau qui bouge : gros chantier), 6.10 kraken.

## Lot 6 : météo et jour/nuit

- Journée de 35 min (+40 %), moment de la journée affiché. Mauvais temps plus rare (clair 76 %) et plus court.
- Périodes de houle forte hors tempête ; tempête rare (4 %) avec houle maximale, pluie forte, éclairs. Même météo pour tous.
- Pas fait : un vrai « vent fort » qui pousse le bateau pendant la tempête (le vent n'a pas de force dans la simulation).

## Lot 8 (en avance)

- Noms des habitants au-dessus de leur tête, de près, dans un style distinct des joueurs ; plus de boussole dans leurs mains.

## Pas encore commencés

Lot 7 (îles, ville, baies, trésors, mouettes) et le reste du lot 8 (audio, curseur d'interface partout, carte à grille et
marqueurs, point d'exclamation de quête, partage de l'or à la vente).

## Choix à valider

- Mort : on ne perd pas les réserves du bateau (boulets/planches de la caisse) ni les baies du sac ; « nourriture » n'existe
  pas encore dans le jeu.
- À terre : le pirate est seulement « tassé » (il faudrait une image « au sol » en pixel art). Sirène et ailerons : maquettes.
- Lot 5 : les ennemis sont déjà 18 % plus lents ; avec +10 % pour les joueurs et -10 % demandés pour eux, l'écart monte
  à ~33 % : à surveiller pour les poursuites.

## Assets à fournir

Sons (remplacent les PROVISOIRES de `synth.gd`) : cabestan, coups de marteau, seau (remplir, vider), saut, réception
(bois, sol), objet posé, corde, grincement de la roue, alerte requins, mort, (et plus tard : pluie, combat, musiques).
Images pixel art : pirate au sol, gestes (cabestan, clouer, écoper, hisser). Modèles : sirène, requin.

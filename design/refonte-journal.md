# Refonte gameplay : journal des lots

Branche `feature/refonte-gameplay`. Tous les réglages ajoutés sont dans `src/game_config.gd` (une constante commentée par
valeur). Les sons marqués **PROVISOIRE** dans `src/audio/synth.gd` sont fabriqués par le code en attendant de vrais fichiers
(Epidemic Sound). Lancer les tests : `godot --headless --path . -s tests/unit/test_X.gd` (`test_town.gd` échouait déjà
avant la refonte : il attend 10 habitants, il y en a 11 depuis l'armurier).

Options d'essai ajoutées (après `--`) : `--look-seed=N`, `--fake-remote=dx,dy` (+ `--fake-carry=t:calice`,
`--fake-act=repair`, `--fake-swim`), `--local-only` (héberger sans alerte du pare-feu), `--swell=0..1`, `--down=t`,
`--water-time=s`.

Version réseau : **13** (tout l'équipage doit avoir la même version).

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
- 3.1 / 3.2 (12/11, après retour de Jimmy : « on se tape toutes les collisions ») : coques agrandies dans
  `tools/art/blender/make_ship.py` (longueur x1,35, largeur x1,4, mâts x1,12 ; sloop 19 m, brigantin 25 m, galion 32 m), objets
  du pont à leur taille d'origine. Barre dans l'axe, devant la cabine, roue face à l'étrave. Tonneau de boulets et caisses
  rangés contre le plat-bord. Obstacles réduits à la base visible (barre : la colonne ; mât : le mât). On glisse autour des
  obstacles ronds au lieu d'y rester collé. Couloirs mesurés par `tests/unit/test_deck_space.gd` (≥ 1,2 m ; sloop 1,95 m).
  Au port, la poupe garde sa place (`HULL_LENGTH_GROWTH`). Les ennemis ont les mêmes coques : cibles plus grandes.
  Les canons ne sont toujours pas des obstacles (on passe à travers, comme avant). Pas d'IK des mains sur la roue.

## Lot 4 : mort, eau, réapparition

- À terre à 0 PV (25 s), relevé par un camarade (4 s, compte à rebours en pause), sinon mort : objet porté et pouvoir de
  baie perdus, réapparition sur le bateau après 10 s.
- Eau : sirène à 20 s (E : retour à bord), requins à 45 s, morsures dès 60 s (un coup de sabre les fait fuir), noyade à 90 s
  (alerte 15 s avant). Remise à zéro en quittant l'eau. Les autres voient l'état « à terre », la sirène et les ailerons.

## Lot 5 : ennemis (partie 1)

- Coques +25 %, apparitions plus rares (premier à 90 s, puis 150 à 300 s).
- Vitesse (rééquilibrée le 12/11, l'écart de 33 % rendait les poursuites trop faciles) : par rapport à un joueur sur le même
  bateau, ★ 85 %, ★★ 92 %, ★★★ et ★★★★ 95 % (`ENEMY_SPEED_VS_PLAYER`). Avant la refonte : 82 % pour tous.
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
- 11.1 Toute vente (coffre du capitaine ou trésor dans les bras) se partage entre tout l'équipage de la partie ; la part
  d'un absent est gardée par l'hôte et versée à son retour (reconnu par son pseudo), avec un message. En solo : tout au vendeur.
  Limite : les parts en attente sont perdues si l'hôte quitte la partie.
- 10.2 Carte : grille lettres/chiffres calée sur le monde (même case pour tous), case du bateau affichée. Les marqueurs
  partagés (carte + horizon) restent à faire.

## Pas encore commencés

Lot 7 (îles, ville, baies, trésors, mouettes) et le reste du lot 8 (audio, curseur d'interface partout, carte à grille et
marqueurs, point d'exclamation de quête, partage de l'or à la vente).

## Choix à valider

- Mort : on ne perd pas les réserves du bateau (boulets/planches de la caisse) ni les baies du sac ; « nourriture » n'existe
  pas encore dans le jeu.
- À terre : le pirate est seulement « tassé » (il faudrait une image « au sol » en pixel art). Sirène et ailerons : maquettes.

## Son (12/11)

Recherche des pratiques du son de jeu (doc Godot AudioStreamRandomizer, Wwise/Audiokinetic, CRIWARE, Violet Recording,
GDC « horizontal resequencing », interviews de Rare sur Sea of Thieves). Appliqué :
- **Variantes** : 3 à 7 prises par bruit fréquent (pas, marteau, canon, impacts), tirées au hasard **sans rejouer la même
  deux fois de suite** (`AudioStreamRandomizer`, mode RANDOM_NO_REPEATS). Hauteur ±1 demi-ton, volume ±1,5 dB à chaque
  lecture (au-delà de 2 demi-tons, ça sonne comique). Une variante rare possible (`<nom>_rare_1.ogg`, poids 0,15).
- **Couches** : le canon = détonation + grondement joués ensemble ; entendu jusqu'à 140 m (les autres sons : 22 m).
- **Anti-saturation** : un même son pas plus de 4 fois en même temps, ni relancé à moins de 60 ms.
- **Distance** : les sons lointains perdent leurs aigus (passe-bas à 4 kHz).
- **Musique** : par état (mer, escale, tempête, combat) ; au calme, un morceau puis 60 à 180 s de silence (on n'entend
  que la mer), jamais le même morceau deux fois de suite ; combat : entre en 1,5 s, ne sort qu'après 10 s sans combat
  (pas de va-et-vient), fondu de 5 s. Musique à -21 LUFS, bruitages à -16 (musique 5 dB sous les effets).
- Nouveaux sons : tir de canon (ennemi aussi : il n'y en avait pas), choc de boulet sur une coque/un mob/un récif, boulet à
  l'eau, pas sur bois/sable/herbe/eau (enregistrés). 70 prises de bruitages (`assets/audio/sfx`), 12 morceaux
  (`assets/audio/music`, Epidemic Sound, série « Scandinavian Folk » pour la mer, l'escale et le combat ; ~19 Mo).
- Le choc d'un boulet de joueur sur un ennemi est relayé à tous (action réseau `ball_hit`).
- « Ducking » : un coup de canon proche creuse la musique de 4 dB, qui remonte en 0,6 s.
- Combat en couches (musique « verticale ») : les morceaux de combat livrés en pistes séparées (Epidemic « stems » :
  `music/stems/combat_N_instruments.ogg` + `_melody.ogg`) jouent l'accompagnement seul, et la mélodie entre quand le
  combat chauffe (intensité = navires engagés pondérés par leur rang, mobs proches, coups reçus récents).

## Canon (12/11)

- Bug : en visant au canon on pouvait partir se promener (on ne lâchait le canon qu'à 4,8 m) et continuer à tirer. Au canon,
  on est maintenant placé derrière la culasse et on ne bouge plus ; R pour lâcher.

## Retours du premier essai de Jimmy (12/11)

- Barre trop haute : centre de la roue à 1,26 m du pont (2 m avant), colonne raccourcie.
- Grincement de la barre « toujours pareil » : chaque coup de barre tire sa force (55 à 100 %) et sa hauteur, la boucle change
  de prise (3 prises), et des craquements de bois tombent au hasard par-dessus (7 prises).
- Lumières du bateau : fenêtres refaites (vitre ambrée en retrait, cadre et croisillon en bois, appui), lanterne de poupe en
  fer avec une flamme ; lumière moins forte (émission 2,2 au lieu de 7 : elle « brûlait » en blanc).
- Pirate qui rentre dans la table / disparaît derrière la coque : l'image du pirate est dessinée 0,6 m vers la caméra (même
  place à l'écran) et une silhouette claire apparaît là où un décor le cache (shader `depth_test_inverted`). Pour tous les
  pirates (joueurs, habitants).
- Cabine : les murs côté caméra sont rabattus en muret (0,5 m) au lieu de disparaître : on voit la porte pour sortir.
- Tonneau de boulets qui donnait des planches : le tonneau ne donne que des boulets, la caisse du pont que des planches (des
  planches dépassent maintenant de la caisse). L'étagère de la cale garde les deux.
- Traînées de vent plus légères (opacité 0,18 au lieu de 0,32).

## Deuxième essai de Jimmy (12/11, après-midi)

- Poste bloqué : pendant l'ancre, une réparation, l'écope, au canon ou au grappin, on ne bouge plus ; R (ou une touche
  d'action) pour lâcher. Avant, bouger coupait l'action ou laissait partir en visant.
- Caméra : vue de base au TRIPLE clic de molette (un clic suffisait, par mégarde) ; molette enfoncée + haut/bas : incliner
  la vue (24° à 72°). M : vol libre d'essai au-dessus de la carte (Maj : plus vite) ; couper le son passe sur Maj+M.
- Boussole rangée par défaut (B pour la sortir).
- Pas selon le sol : pavés de la ville, bois des pontons, des planchers et du pont, sable, herbe, eau (enregistrements).
  Avant, la ville jouait des clapotis. Ville : murmure de foule et enfants qui jouent, très bas, plein en ville seulement.
- Nage : bas du corps coupé à la surface (shader du pirate), pose flottante au lieu de la marche, brassées, plongeon.
  Requins : arrivent de 32 m, tournent, resserrent, chargent l'un après l'autre, mordent, repartent au large ; musique des
  requins (pistes séparées : la batterie monte quand ils approchent). Sirène : apparaît à 22 m (côté du bateau), nouveau
  modèle, traînée de lumière qui monte au ciel, chant 3D, texte « nage vers sa lumière » / « E : … ». Échelle de coque
  jusque dans l'eau.
- Voiles : plus de trous ni de damier, une toile par voile (coordonnées de texture), tête de mort peinte sur la grand-voile,
  dessinée sur le pavillon (fini le disque blanc) ; elles ne deviennent plus transparentes (la silhouette suffit).
- Cabine collée à la poupe. Récifs : autour des îles, à 120 m au moins du port, espacés de 26 m, variés (rocher, aiguille,
  amas de petits rochers, banc de sable).
- Ville : maisons du fond à deux étages au plus, maisons ordinaires de la rangée nord moins profondes (rue plus large). La
  rangée du fond ne peut pas reculer : elle s'adosse aux remparts (escaliers des ruelles).
- Interface : style commun `UiTheme` (bois, laiton, parchemin, encre ; recherche des pratiques des jeux actuels). Sac en
  cases avec icônes pixel art (`ItemIcons`) et quantités, fabrication à droite (vert / rouge), fiche sur parchemin, souris et
  clavier. Menu pause et menu principal refaits. Pas encore : HUD de jeu (lignes en haut à gauche), police dédiée (Pirata
  One / IM Fell English, licence libre OFL : à télécharger avec ton accord).

## Vent visible (12/11)

- Traînées blanches très fines qui filent dans le sens du vent à hauteur des voiles (`src/sea/wind_streaks.gd`), plus vives
  quand les voiles prennent bien le vent.
- Voiles : creusées quand elles prennent le vent (rendement vent x réglage), flasques et qui battent quand il les prend mal ;
  pareil sur les navires ennemis (on voit s'ils sont bien réglés).
- Sons : « vlouf » de toile quand le rendement franchit 60 % en montant, battement de toile en boucle quand les voiles
  hissées sont mal réglées. Réglages `WIND_STREAK_*` et `SAIL_*` dans `game_config.gd`.

## Assets à fournir

Sons : **faits le 12/11** avec le compte Epidemic Sound de Jimmy (19 fichiers dans `assets/audio/sfx/`, 1 ou 2 variantes
chacun, coupés et normalisés). `Synth.recorded()` charge le fichier s'il existe, sinon le son fabriqué reste. Plus tard :
pluie, combat, musiques. ⚠ À vérifier : que la licence Epidemic Sound couvre un jeu distribué à d'autres joueurs.
Images pixel art : pirate au sol, gestes (cabestan, clouer, écoper, hisser). Modèles : sirène, requin.


## Quatrième essai (12/11/2026, soir)

- Coups de feu : un son par arme (pistolet 10 prises, fusil 8, tromblon 7, Epidemic), clic à vide sans munitions.
- Sac : seul l'or reste à part (en-tête) ; boulets, planches, balles, cartouches redeviennent des cases. Deux armes seulement
  (plus de râtelier ni de case « apparence » qu'on prenait pour une 3e arme : cliquer une arme change son apparence). À
  l'armurerie, une nouvelle arme passe en 1, l'ancienne en 2 si la place est libre, sinon elle reste à l'armurerie.
- Porter : le fardeau balance au rythme des pas ; clic droit lâche ce qu'on porte (à terre et sur le pont).
- Sirène : toujours en eau libre (ni quai, ni ponton, ni ville à 3 m près, ni île, ni récif, ni sous le bateau).
- Horizon : mer dessinée sur 200 m (au lieu de 110) et fond couleur de brume : plus de vide noir en vue rasante.
- Quai : les deux flancs (là où la plage a été retirée au lot 1) ont maintenant mur, algues et couronnement.
- Sons muets après le vol : non reproduit (pas, sabre et tirs se jouent après un vol puis un atterrissage, en ville comme sur
  une île). Traces activables avec la variable d'environnement SFX_DEBUG=1.
- Essais : --carry=<trésor>, M dans --press.
- Direction artistique : recherche en trois volets et proposition dans design/bible-direction-artistique.md (à valider avant
  toute refonte graphique).

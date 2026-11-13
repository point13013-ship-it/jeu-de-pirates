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

## Cinquième essai (12/11/2026, soir) : brigantin passe 2, haute ville, cale et cabine

- Brigantin : la poupe devient une façade (quatre fenêtres sur le tableau, trois sur la cabine, balcon à balustres dorés,
  galeries de flanc, couronnement doré avec ses deux lanternes) ; voiles plus gonflées, bordure en arc, deux rustines (elles
  suivent leur voile : même nom « sail_zNNN_patch ») ; tonneau de grog, caisses sous filet, mouette sur la poupe.
- Cabine du capitaine meublée : lanterne suspendue (plus de cube qui éblouit), tapis bordé d'or, carte, bougie et chope sur la
  table, deux chaises, étagère à livres, coffre à rouleaux, montants du lit. Vérifié : tous les postes restent accessibles à pied.
- Ombre de contact (SSAO) avec le rendu v2 (GameConfig.TOON_SSAO*, --no-ssao pour comparer).
- Haute ville (demande de Jimmy : ville plus grande, rangées en plus, rien d'aligné, chemins, verdure) : un plateau praticable
  à 2,4 m derrière les remparts, par une porte dans le chemin de ronde. Treize maisons décalées et tournées, ruelles pavées qui
  serpentent, sentiers de terre, placette et fontaine, clocher, potager clos, verger, haies, massifs, arbres et palmiers, colline
  et moulin. Son sol est un niveau du jeu décrit dans la méta du port (« levels »), ajouté à data/town.json au chargement ; pas
  sur l'herbe ou les pavés selon l'endroit ; terre étendue pour les bateaux (Land.SHIP_LAND).
- Ville : palette v1 (façades, tuiles, bois, pierre, volets, tissus, végétation), vitres éclairées crème.
- Cale : la brume (toujours allumée depuis sa refonte) la noyait dans un fond pâle : éteinte dans la cale. Le pont porte
  l'ombre, le soleil n'entre que par l'écoutille (rai de lumière, poussières), lumière à paliers, palette v1, deux hamacs.
- Tests : tous passent sauf test_town (« 11 habitants au lieu de 10 », échec antérieur à la refonte).
## Retours de la session à 3 joueurs (13/11/2026) : lot 1, voiles, échelles, pavillon

Plan complet et réponses de Jimmy : design/plan-retours-session-3-joueurs.md.

- Voile qui s'envole : la hauteur d'une voile est lue dans son nom. `to_int()` ramassait tous les chiffres : le second foc
  (« sail_z743_jib2 ») était lu à 74 m. Lecture stricte (`ShipModel.sail_top`), foc renommé, test (tests/unit/test_sails.gd).
- Voiles accrochées : les vergues s'appellent « yard_zNNN » et « yardlow_zNNN » et suivent leur voile (rotation autour du mât,
  vergue du bas qui remonte quand on cargue) ; le haut de la toile part de la vergue.
- Voiles qui se croisent : focs envergués sur leurs étais (ils longeaient le mât), butée des vergues 65° -> 55°
  (`ShipSim.MAX_TRIM`), creux réduit de 30 % vergues à fond (`SAIL_BULGE_TRIMMED`), creux du modèle 1,3 -> 1,15.
- Voile dans l'échelle : la brigantine passait entre les montants de l'échelle de mât ; elle est reculée derrière.
- Échelles de coque : posées sur le vrai profil de la coque (`hull_side` dans make_ship.py).
- Crâne du pavillon : une des deux têtes de mort était dans le plan du pavillon (clignotement au roulis) ; 7 cm de chaque côté.
- Les trois bateaux ont été régénérés. Tests : tous passent sauf test_town (échec antérieur).
- Reste ouvert : « finition de la coque » (à préciser avec Jimmy).

## Retours de la session à 3 joueurs : lot 2, personnages et rendu (13/11/2026)

- Pirate caché par un décor : vraies couleurs à 50 % d'opacité, 15 % de teinte claire (`SPRITE_XRAY_COLOR`, `SPRITE_XRAY_TINT`).
- « Les jambes ne bougent plus en portant » : ce n'était pas propre au port. De face et de dos, les images de marche ne montrent
  pas les pas (les jambes viennent vers la caméra). Le shader du pirate lève un pied puis l'autre (jusqu'à 3 pixels).
- Chapeaux : planche de contrôle chapeaux x coiffures faite dans Godot (python absent du PC). Seul le bicorne flottait (6 pixels,
  hors profils) : images recalées dans les douze animations, et le script du générateur (tools/art/pixel_hair.py) corrigé pareil.
- Cercle de l'ancre : la jauge ne se redessinait plus quand son opacité atteignait zéro ; après une saccade elle restait affichée.
- Vagues depuis la vigie : surface de mer étendue (400 m, maille 1 m) dans le nid, en vue dézoomée (< 0,5) ou rasante (< 30°).
- Brume : bancs du filtre d'image coupés (`FOG_SCREEN_BANKS`), densité -15 % (`FOG_DENSITY_BASE`, `FOG_DENSITY_GAIN`).

## Retours de la session à 3 joueurs : lots 3, 4 et 5 (nuit du 13/11/2026)

### Lot 3 : collisions, multijoueur, naufrage
- Nageur repoussé par les coques ennemies (`_push_out_of_enemy_hulls`, calculé par chaque joueur). Un bateau qui chevauche déjà
  une coque ennemie ne peut plus que s'en éloigner (il finissait par la traverser). À vérifier en vraie partie.
- Plages : le nageur prend pied sur la pente de sable et sort en marchant (`_beach_height`, `_wading`).
- Canons des alliés : angle envoyé toutes les 0,12 s s'il change (action « gun_aim », relayée par l'hôte), tube lissé.
- Hisser un coéquipier : fonctionnait en local ; indication « E : hisser … à bord » ajoutée, portée 2,6 -> 4,5 m (`HOIST_REACH`).
- Naufrage : trésors du coffre du capitaine et trésors portés à bord à la dérive sur place 5 minutes (`SINK_LOOT_TTL`).
- Protocole réseau 14.

### Lot 4 : navigation et météo (réglages dans GameConfig, section « Retours de la session à 3 joueurs »)
- Barre : `RUDDER_RATE` 0,6 (1,6 s du centre à fond, avant 0,63 s), `RUDDER_RETURN` 0,45, `TURN_INERTIA` 1,2 s,
  `PLAYER_TURN_SCALE` 0,77. Ancre : `ANCHOR_BRAKE` 1,2 (avant 2,6), `ANCHOR_RESTART` 2 s à 40 %.
- Vent : zones de calme fixes (src/sea/wind_zones.gd, mêmes chez tous) et sautes de vent (hôte). Voiles hautes : freinage x2,2 ;
  carguées : le bateau court sur son erre (`SAILS_FURLED_GLIDE` 0,5). Hors calme et saute, le vent debout ralentit sans arrêter.
- Canons : arc de 100° (`GUN_ARC_DEG` 50), boulet 31 m/s (`BALL_SPEED`). Crochet : 22 m. Météo : 83 / 8 / 6 / 3 %.

### Lot 5 : combat et PNJ
- Un ennemi touché par balle ne se fige plus (`GUN_KNOCK_SCALE` 0,3, son élan n'est plus cassé).
- Mobs : PV 3 / 5 / 6 / 11 / 24, vitesse +10 %, repos -15 % (data/enemies.json).
- Dispersion des armes x2,5 en courant, x3,5 en sautant ; marche à 85 % et course à 1,35 en portant un trésor.
- Bateaux ennemis : plus de barre de vie ; dégâts visibles par paliers (`EnemyFleet._update_damage`) ; équipages renforcés par
  rang (canonniers en plus 0/1/2/3, `ENEMY_LOAD_TIME`, `ENEMY_AIM_PER_RANK`).
- Abordage : depuis l'eau, E près de l'échelle de coque ennemie. Le pont ennemi est un sol mobile (le pirate reste en mode
  « à terre », position tenue dans le repère du bateau ennemi : `_board_id`, `_bpos`). Sabre et armes à feu abattent
  l'équipage (`CREW_HP` 3, retour après `CREW_RESPAWN` 30 s, demande « crew_hit » à l'hôte). Timonier abattu : bateau désemparé.
  E au cabestan : leur ancre (`ENEMY_ANCHOR_TIME` 40 s). Les squelettes à portée frappent. Espace : plonger.
  Les armes servent aussi sur notre pont (sans dégâts entre coéquipiers).
- Limites connues de l'abordage : on ne monte que depuis l'eau (pas de saut de pont à pont, pas de crochet) ; les squelettes
  ne poursuivent pas, ils frappent ce qui passe à leur portée ; à valider à plusieurs.
- Essais : --enemy-hp=0.3 (dégâts visibles), --swim près d'une échelle ennemie puis --press=E.

## Retours de la session à 3 joueurs : lots 6, 7, 11 et début du lot 8 (nuit du 13/11/2026)

### Lot 6 : interactions
- Les mains prises, on ne tient plus la barre, les voiles, l'ancre, la carte, le crochet ni un canon (sauf pour le charger
  avec le boulet porté). Clic gauche ou droit : poser ce qu'on porte.
- Échelle de mât à la main : Z monte, S descend, on peut s'arrêter (plus de montée automatique). Le pirate est derrière l'échelle.
  Les échelles de coque restent automatiques (une seconde) : à revoir si la demande les visait aussi.
- Espace dans le nid de pie : saut vers l'extérieur (`NEST_JUMP_UP`, `NEST_JUMP_OUT`). Vigie dézoomée (`NEST_ZOOM` 0,30).

### Lot 7 : planches, boulets, coffre du bateau
- Le sac porte 10 planches et 10 boulets (`BAG_MAX`). Le surplus part tout seul au coffre du bateau.
- Coffre à boulets, caisse à planches et étagère de la cale ouvrent le coffre du bateau : même panneau que le coffre de cabane
  (cases, clic : ranger ou prendre 1 ; Maj + clic : tout). Stock commun tenu par l'hôte (`_ship_stock`, gardé dans son profil :
  `ship_planks`, `ship_balls`), diffusé avec l'état du bateau ; demandes « chest_put » et « chest_take » servies dans l'ordre.
- On répare avec une planche du sac ; un canon se recharge avec un boulet du sac.
- Pas fait : les deux panneaux côte à côte et le glisser-déposer (le panneau liste « ton sac » puis « le coffre »).

### Lot 11 : interface épurée (`GameConfig.HUD_MINIMAL`, `false` pour l'ancien HUD)
- Retirés de l'écran : bandeau du haut, cadran rond, ligne d'aide des armes, or et coffre, quêtes en cours (journal), barre de
  réputation (elle apparaît au moment d'un gain ; la réputation est en tête du sac).
- Indication de touche : « [E] … », courte, sous le centre de l'écran (`_short_prompt`). Les messages passent tels quels.
- Guidage seulement boussole en main (B), boussole redessinée (src/ui/island_hud.gd). Pseudo visible à la nage (dessiné après
  la mer). La sirène s'en va 3 s après la sortie de l'eau. Curseur du jeu (`UiTheme.apply_cursor`).
- Signalé : sans bandeau, la vitesse et l'angle de barre ne sont plus chiffrés (on les lit au sillage et à la roue).

### Lot 8 (en cours)
- Skins de bateau masqués (`SHIP_SKINS_ENABLED` = false : apparence d'origine, voilerie fermée, achats gardés).
- Barre 12 % plus petite (`HELM_WHEEL_RADIUS` 0,44).
- Trésors posés sur le pont : ils y restent (`_deck_items`, tenus par l'hôte, diffusés avec l'état du bateau), E pour reprendre ;
  au naufrage ils partent à la dérive avec le reste.
- Reste : cale en plusieurs pièces et hublots, porte arrière de la cabine et balcon praticable.

### Lot 8 (fin)
- Cale en trois pièces (`HoldLayout.walls`, `HOLD_LENGTH_MULT` 1,8, portes `HOLD_DOOR_HALF`), hublots (`HOLD_PORTHOLE_EVERY`).
- Cabine : porte arrière et balcon praticable (`WALK_EXTRA` dans make_ship.py, méta `walk_extra`, lue par `ShipModel.is_walkable`).

### Lot 9 : haute ville
- Maisons toutes droites, rangée du fond aérée (quatre maisons, jardins, arbres), bords du plateau solides (make_port.py).
- Pas fait : apparence des trésors (trois pistes dans le plan, choix attendu), collision du « fond en herbe » (endroit non retrouvé).

### Lot 10 : audio
- Tromblon : prises faibles retirées. Fusil refait à partir des prises existantes (plus grave, écho).
- Pluie : -50 % (`RAIN_VOL`), averses et accalmies, curseur « Pluie » dans les réglages (`AudioSettings.rain_gain`).
- Écoper et réparer : hauteur et volume tirés à chaque coup (`WORK_PITCH_VAR`, `WORK_VOL_VAR`). Barre adoucie.
- Volume des morceaux varié (`MUSIC_TRACK_GAIN_MIN`). Pas fait : nouvelles musiques (fichiers Epidemic à fournir).

### Refonte graphique, suite (13/11, après les lots)
- Îles : les taches d'herbe suivaient la grille du bruit (pavés carrés). Octaves tournées, dessin déformé par un second bruit,
  verts de la palette v1 (shaders/island_ground.gdshader).
- Rivage : la houle traversait la nappe d'eau claire (elle monte plus haut que prévu avec les vagues à crête pointue). La houle
  tombe maintenant à 20 % au bord d'une île et reprend sur 30 m (`SHORE_SWELL`, `SHELTER_WIDTH`), même formule dans
  shaders/water.gdshader (`shelter_at`) et dans `SailingGame._shelter_at` : l'eau dessinée et la flottaison restent d'accord, et
  c'est pareil chez tous les joueurs (les îles sont au même endroit). Le calcul prend le cercle englobant de l'île : une baie
  est donc calme elle aussi. Bord extérieur de la nappe irrégulier, plus de trait de contour (pixel_edges : `shallow_y`).
- Menu principal : fond refait (shaders/menu_sea.gdshader, coucher de soleil en gros pixels, palette v1), ponton sous le pirate.
- Reste de la refonte : silhouettes d'îles (falaises en strates, épaves, ruines), autres menus (pause, boutique, création du
  pirate), sillage en texture, reflets des lanternes, vue sous l'eau.

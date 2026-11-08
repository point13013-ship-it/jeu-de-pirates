# Navigation façon Sea of Thieves — principes retenus

Chaque poste du bateau est une activité physique : on se déplace à pied sur le pont, on va
au poste, on appuie sur E. Personne ne « pilote » depuis un menu.

| Poste | Où | Effet | État |
|---|---|---|---|
| Barre | devant la cabine | gouverner (gauche/droite) ; tant qu'on y est, on ne marche plus | fait |
| Voiles | au pied des mâts | hisser (E) / affaler (R) en 3 crans, elles se déploient en quelques secondes | fait |
| Ancre | cabestan | stoppe le bateau net, il ne pivote plus que lentement | fait |
| Canons | flancs | prendre un boulet au tonneau, charger, tirer ; bâbord et tribord | fait (tir simple) |
| Cabine | château arrière | entrer par la porte ; toit et murs côté caméra disparaissent | fait |
| Table de cartes | cabine | choisir la destination | à faire |
| Vigie | nid-de-pie | voir loin, signaler | à faire |
| Cale | écoutille sur le pont (E) | descendre, boucher les voies d'eau avec une planche (étagère au fond), écoper au seau | fait |

## Vent
Le vent a une direction. Le rendement des voiles va de 12 % (face au vent) à 100 % (vent arrière) ;
le vent de travers donne environ 70 %. Il reste à régler l'orientation des voiles (comme la
manœuvre des cordages de Sea of Thieves) et à faire varier le vent lentement.

## Barre
La barre agit d'autant plus que le bateau avance (12 % à l'arrêt, 100 % aux deux tiers de la
vitesse maximale). À l'ancre, le bateau pivote à 30 % de son taux de virage.

## Équipage et réseau (fait : src/sailing_net.gd)
Un joueur héberge (ENet, port 7777), jusqu'à 3 amis rejoignent le même bateau.
- L'hôte fait autorité sur le bateau : il diffuse 30 fois/s position, cap, vitesse, barre, voiles,
  ancre, canons chargés, barreur et temps de la houle. Les clients prédisent le bateau et se recalent
  en douceur (au-delà de 6 m d'écart, recalage immédiat).
- Chaque joueur fait autorité sur sa position sur le pont (repère du bateau), envoyée 20 fois/s.
- Les actions aux postes sont des demandes à l'hôte, qui les vérifie : une seule personne à la barre
  (libérée si elle se déconnecte), voiles et ancre pour tous, chargement et tir des canons ; le tir
  est rejoué chez tout le monde.
- Une couleur de pirate par place dans l'équipage (rouge, bleu, vert, jaune).
- À faire : plusieurs bateaux (PvP), reprise de partie par un client si l'hôte part, jeu par Internet
  sans ouvrir de port (tunnel type playit.gg ou relais).

## Réglages (data/ship_stats.json)
`max_speed` (m/s), `turn_rate` (rad/s), `accel` (m/s²), `sail_speed` (ouverture par seconde).

## Dégâts de coque et cale (src/hull_damage.gd, hold_layout.gd, hold_room.gd, sea_rocks.gd)
Un choc à plus de 1,6 m/s (récif, quai ou mur, boulet) ouvre 1 à 3 voies d'eau sur 12 emplacements fixes le long
des deux flancs (6 par côté, autour de l'impact). Chaque voie d'eau remplit la cale de 0,8 % par seconde ; cale
pleine = le bateau coule (remorqué au port, remis à neuf). L'eau enfonce le bateau et le ralentit (jusqu'à -45 %).
- Cale : écoutille du pont (E), fondu au noir, vue en coupe. Au fond : l'échelle, l'étagère à planches, le seau.
  Bâbord est au fond de l'écran, tribord devant ; les trous sont sur les pentes des bordés, visibles des deux côtés.
- Réparer : prendre une planche à l'étagère (E), aller devant la voie d'eau (E). La planche reste clouée.
  Écoper : E devant le seau, une fois par coup (-5 %).
- Récifs : `rocks` dans data/hull.json ([x, z, rayon]). Boulets ennemis : `spawn_enemy_ball()` (essai
  `--enemy-fire=secondes,côté`), prêt pour le PvP.
- Réseau : l'hôte décide ; l'état de la coque (masque des voies d'eau, des planches, niveau d'eau) est dans
  l'état du bateau (protocole 2), les chocs et le naufrage sont des événements fiables.
- Essais : `--hold --hpos=x,z --hit=abscisse,côté,nombre --water=0.4 --send=patch:3,bail:0`.

## Îles, ennemis, trésors et carte (src/islands/, src/ui/sea_chart.gd)
- `data/islands.json` : 5 îles (Crabes, Naufragé, Squelettes, Fort de la Marine, Capitaine Rouille). Terre = union de
  disques (`lobes`), sol à la hauteur 0, plage en pente ; le bateau s'arrête à 0,8 m du bord marchable (choc de
  coque comme un quai). `data/enemies.json` : réglages des ennemis et du joueur (6 cœurs, sabre).
- À terre : F ou clic gauche = coup de sabre (croissant), E sur un coffre = or. Les ennemis rôdent, poursuivent, arment
  un coup (reculer l'évite), reviennent à la vie 150 s après, quand l'île est vide ; coffres remplis après 600 s.
  À 0 cœur : évanoui, réveil sur le pont. Soin sur le bateau (1 cœur / 3 s).
- Carte : E à la table de la cabine. Îles inconnues = rumeur « ? » ; repérage à 70 m du bord. Clic sur une île = cap
  (flèche + distance en haut de l'écran), R l'efface. Îles repérées sauvegardées dans le profil.
- Réseau (protocole 5) : l'hôte fait vivre ennemis et coffres et diffuse l'état à 12 Hz ; coups, coffres et or par requêtes.
  Non testé à plusieurs fenêtres.

### Rendu des îles (v2)
Sol peint par `shaders/island_ground.gdshader` (herbe en taches de 4 tons, touffes, fleurs, sentiers, sable ondulé, roche),
eaux peu profondes + écume animée par `island_shallows.gdshader`, décor assemblé en un maillage par objet
(`mesh_kit.gd`, `island_decor.gd`) : palmiers, buissons, fougères, mares, arbres morts, rocher-crâne, tours, épave du galion.
Ambiance par île (`tone` : lush / dead / fort), falaises (`cliffs`), semis (`scatter`) dans `data/islands.json`.
Les teintes ajoutées sont dans `tools/art/sea_palette.json` (palette du filtre, à régénérer avec make_palette_shader.py).

### Relief des îles
`plateaus` dans `data/islands.json` : disque surélevé (`h` m) à bord en falaise à pic, accessible seulement par une rampe
(`ramp` : angle, largeur, longueur). `IslandWorld.height()` donne la hauteur ; Land (`island_height`) la suit à pied,
les ennemis ne montent pas les falaises, objets et coffres sont posés à la bonne hauteur. Chaque île à danger garde un
coffre sur son plateau.

## Session du 8 novembre 2026 — manœuvres, nage, butin, armes, ennemis (code écrit, PAS encore lancé : voir la fin)

### Postes du pont : on vise l'objet en lui faisant face
`INTERACT_PARAMS` (sailing_game.gd) donne, par poste, une portée, un cône de vue (cosinus de l'angle max. entre le regard et l'objet)
et la hauteur de la flèche jaune. Le poste visé est celui qui est à portée ET devant le pirate, le mieux placé si plusieurs
(`_compute_target`) ; une flèche jaune le désigne et le texte du bas dit ce que E ou R feront. La barre a une portée large et
un cône très ouvert (elle était trop dure à prendre : un canon voisin la masquait).

### Voiles, vergues et vent
- Vergues : E au mât entre dans le poste de voilure (Q/D tournent les vergues, Z/S hissent/affalent, E ou Espace lâchent), R affale.
  `ShipSim.sail_trim` (angle, sens de `Vector2.rotated`), `trim_efficiency()` : la poussée d'une voile plate vaut
  (vent·normale)² · cos(angle) ; le rendement est comparé à l'idéal pour le vent du moment (`optimal_trim()`), plancher 18 %.
  Vent debout : rien à régler. Hisser depuis des voiles affalées règle d'emblée les vergues au mieux ; ensuite c'est à
  l'équipage de les suivre (le vent dérive lentement : `drift_wind`, ±45°). Cadran `SailHud` (flèche du vent, vergue crème,
  repère vert idéal). Réseau : état du bateau (protocole 7) porte vergues, vent, coffre, grappin ; requête `trim`.
- Voiles transparentes : celles que le rayon pirate -> caméra traverse passent à 30 % (`ShipModel.update_sail_fade`).
- Zoom : plus loin en mer (`ZOOM_SEA`), un peu plus près à terre, molette pour régler ; `_ppm()` remplace la constante partout.

### Saut, nage, canon humain
- Espace : on enjambe caisses, tonneau et roue (`ShipModel.low_boxes/low_circles`) et on passe le bastingage (`is_walkable_air`) ;
  au-dessus de l'eau on tombe (`_fall_floor`, `_touch_down`) : `Loc.SWIM` (buste hors de l'eau : le sprite est enfoncé de
  `SWIM_DEPTH` et l'eau opaque cache le bas). E près de la coque remonte à bord, une plage ou un quai : on sort en nageant.
- R devant un canon vide : on s'y glisse (`Mode.CANNON`, Q/D visent, E tire, R/Espace sortent) ; `Loc.FLIGHT` : vol balistique
  puis pont, terre ou eau. Codes réseau de lieu : 5 nage, 6 vol (position monde, altitude dans `pz`).
- T deux fois (ou menu Échap) : le bateau est remis sur l'eau libre la plus proche (`_unstick_ship`) ; « Ramener au port » aussi.

### Canons, caisse, trésors, grappin
- Canons : `ShipCannons` (affût rouge, fût de fonte, frettes de laiton, x1,4, recul au tir, fumée). Les petits canons du glb sont masqués.
- Caisse de provisions (la pile de caisses du pont) : E prend un boulet / range ce qu'on porte, R prend une planche.
- Trésors (`data/treasures.json`, `Treasure`) : un coffre d'île donne son or ET un trésor à porter ; on le dépose dans le coffre du
  capitaine (le coffre de la cabine, `stash`) ; Corbin le receleur rachète le trésor porté, ou tout le coffre quand le bateau est
  à moins de `FENCE_RANGE` du quai (l'or se partage entre l'équipage).
- Grappin à l'étrave : voir « Session du 8 novembre (suite) » plus bas (il se vise et se choisit désormais). `WorldLoot` : butin du
  monde (trésors, boulets, planches, bourses), ramassé à la nage ou à pied, synchronisé à 6 Hz.

### Îles : plus grandes, tirées au hasard, tonneaux cassables, baies rares
- Les îles du fichier sont agrandies ×`ISLAND_SCALE` (2) avec plus d'ennemis, de tonneaux et de caisses.
- `IslandGen` : une case de 520 m sur ~0,55 porte une île dont tout dépend de (graine, case) ; l'hôte les génère une par une autour
  du bateau, les clients refont la même liste dans le même ordre (`chunk_order` dans l'état réseau).
- Tonneaux et caisses (`BREAKABLE`) se cassent au sabre, aux balles et aux sorts ; ils lâchent planches, boulets, or (et
  rarement un trésor) ; ils se reforment au bout de 700 s si l'île est vide.
- Baies des dieux : trois seulement dans le monde du fichier (îles dangereuses), 4 % des îles tirées au hasard, repousse en 3 h ;
  elles se cueillent SANS être mangées (sac, touche Tab) ; on mange depuis le sac, l'ancienne baie y retourne.

### Armes et sac
`data/weapons.json` : sabre, pistolet à silex (balle), tromblon (gerbe de 7 plombs, cartouches), fusil de précision (traverse
les ennemis, longue portée). F ou clic tire vers où l'on vise ; X change d'arme ; Tab ouvre le sac. Armes chez l'armurier Armand,
munitions au Magasin Général.

### Bateaux ennemis (`EnemyFleet`)
Deux au plus, voiles noires : patrouille, chasse dès 150 m, se placent bord à bord à 30-70 m et tirent des volées (les boulets
n'abîment le bateau des joueurs que si l'hôte les voit toucher). Les boulets des joueurs les abîment (18 points, 70 ou 130 de vie) ;
coulés, ils laissent flotter 2 à 3 trésors, des planches, des boulets et des bourses d'or pendant 8 minutes.

### État de la vérification (8 novembre 2026)
Vérifié : les 9 fichiers de `tests/unit` passent (dont `test_sea.gd`, nouveau ; `test_berries` et `test_town` adaptés) ; en jeu,
captures dans `qa/session2/` : canons visibles et flèche de visée (v2), nage et remontée à bord, saut par-dessus bord, canon humain
(vol de 30 m puis nage), vergues (dial et rotation visibles, sens cohérent), grappin qui hisse un trésor dans le coffre, trésor
déposé au coffre du capitaine, sac (Tab), île agrandie, île tirée au hasard, tonneau cassé qui donne un boulet, ennemi qui tire et
touche, naufrage avec butin flottant, déblocage du bateau (T, T), hôte + client sur deux fenêtres sans erreur.
Corrigé en route : sprite caché dans le canon (échelle 0,001 et non 0 : la boussole inverse sa base), état réseau des îles trop gros
pour un paquet (découpé en `net_dynamic`, ennemis proches seulement, et `net_static`, 2 fois par seconde, fiable), pirates distants
ajoutés à la scène avant `set_look`.
Pas encore regardé : vente à Corbin au quai, boutique de l'armurier Armand, tir des armes à feu (traînées), ciblage d'un ennemi
par le tromblon, partie à plusieurs avec un client qui nage ou se fait tirer d'un canon.

## Session du 8 novembre 2026 (suite) — saut libre, grappin visé, radeau à voile

### Saut libre (quai, ponton, bateau, eau)
- Cause du « je ne peux pas sauter du quai à l'eau ni du ponton au bateau » : à terre, `Land.step` s'arrête à 0,22 m du bord (marge du
  pirate) et le saut n'avançait librement qu'au-dessus d'un point déjà « vide » : entre les deux, une zone morte de 0,44 m où l'on ne
  pouvait plus avancer. Un saut passe maintenant par `Land.air_move` / `air_clear` : le bord du quai ou de la plage ne l'arrête plus,
  les petits obstacles (poteaux, tonneaux) s'enjambent à `Land.LOW_CLEAR` (0,5 m), seuls les murs des bâtiments l'arrêtent.
- L'atterrissage ne dépend plus d'où l'on est parti : `_fall_floor` / `_touch_down` regardent ce qu'il y a SOUS le pirate (pont du bateau,
  radeau, sol, eau). On peut donc sauter du quai ou du ponton sur le pont (avant : on tombait à l'eau), du pont au quai, de partout à l'eau.
  Au bord d'un quai, `_stand_on_ground` recale sur le point libre le plus proche ; contre un mur on revient d'où l'on a sauté.
- Saut plus généreux : `JUMP_SPEED` 7 (sommet 1,6 m), `AIR_SPEED` ×1,3 en l'air (~4 m franchis). Sur le pont : plat-bord dès 0,35 m
  (`RAIL_HEIGHT`), caisses/tonneau/roue dès 0,5 m (`ShipModel.LOW_CLEAR`) ; la pile de caisses du sloop, collée à la cabine, redevient
  une caisse (`_compute_low_obstacles` après `_index_nodes`). Mâts et murs de cabine restent infranchissables.
- Corrigé au passage : les éclaboussures du plouf étaient posées en coordonnées de la scène dans le monde fixe (invisibles loin du port).

### Grappin du bateau : on le vise, on choisit, il s'accroche à tout (`src/hook.gd`, section « grappin » de sailing_game.gd)
- E au canon à grappin de l'étrave prend le grappin en main (il faut rester à moins de 2,6 unités du canon) : on VISE à la souris,
  dans TOUTES les directions, avec un ruban en tirets et un cercle (vert + croix : le crochet saisirait quelque chose, rouge : rien) ;
  la ligne du bas dit quoi et à quelle distance. Clic gauche ou E : lancer. R : ranger.
- Le crochet file en ligne droite (`Hook.trace`, portée 26 m) et s'accroche à la PREMIÈRE chose qu'il touche : butin (même au sol),
  bateau ennemi (le crochet le suit), récif, rivage (plage, quai, ponton), mur de bâtiment, tonneau, arbre, poteau. Un tir sans prise
  n'est pas lancé. L'hôte rejoue le même tracé (requête `grapple` : direction en dixièmes de degré).
- Une fois accroché (état 5) RIEN ne se fait tout seul : E halera le bateau jusqu'au crochet (point fixe ou bateau ennemi) ou ramènera
  le butin ; E de nouveau arrête de haler ; R décroche. « Ne pas s'attirer » = ne rien faire, ou R. Requêtes : `grapple_haul`,
  `grapple_reel`, `grapple_pause`, `grapple_release`. Corde cassée au-delà de 44 m.
- État réseau du bateau : 26 champs (état du crochet, position, cible, espèce d'accroche en code, tireur).

### Fabrication et radeau à voile (`src/crafting.gd`, `data/crafting.json`, `src/raft.gd`)
- Le sac (Tab) a une rubrique « Fabrication » : le radeau à voile coûte 6 planches (on en a 4 au départ ; planches des tonneaux et caisses
  des îles, de l'étagère de la cale, du Magasin Général). E dans le sac : il se pose sur l'eau libre la plus proche du pirate (à terre,
  au bord de l'eau, pas contre un récif ni le bateau), étrave vers le large. Un seul radeau par joueur.
- On y monte avec E (à terre ou à la nage, tout contre lui) ou en SAUTANT dessus. Sur le radeau : A/D barrent, W hisse, S affale
  (la voile se règle toute seule au meilleur du vent), E débarque (terre ou pont du bateau à moins de 4,6 m), Espace plonge. Il va à
  ~4,6 m/s vent arrière, tourne vite, glisse le long des îles et des récifs (`_raft_touches`), reste ancré quand personne n'est dessus.
  La voile devient translucide et le pirate est dessiné par-dessus quand il est derrière.
- Réseau (protocole 8) : chaque joueur diffuse son radeau (`raft_net_state`) ; les autres le voient glisser. Lieu réseau 7 = sur un radeau.

### Vérification (8 novembre 2026, soir)
`tests/unit` : 12 fichiers verts (nouveaux : `test_hook.gd`, `test_craft.gd`, `test_air.gd` ; `test_sea.gd` adapté à la pile de caisses du sloop).
En jeu (captures dans `qa/session3/`, traces `--log`) : quai → eau, ponton → pont du bateau, pont → ponton, quai → radeau en sautant,
visée du grappin, accroche sur le ponton / un butin / un bateau ennemi, bateau halé vers lui, planche ramenée au sac, radeau fabriqué
depuis le sac puis navigué vent arrière, E pour débarquer, plonger puis remonter ; hôte + client sur deux fenêtres : le client voit le radeau.
Arguments d'essai ajoutés : `--aim=°` (impose la visée), `--planks=N`, `--craft=raft@t`, `--raft-ride=t`, `--log` (traces `[essai …]`).
Pas encore regardé : prise de la barre / mât en même temps que le grappin, radeau contre une île générée, équilibre du radeau (planches),
plusieurs joueurs sur un même radeau (un seul pirate se tient dessus pour l'instant).

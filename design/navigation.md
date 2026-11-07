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

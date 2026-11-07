# Port d'attache et économie (façon Sea of Thieves, rendu Eastward)

Décisions de l'utilisateur (2026-11-07) :
- **Or** : trésors trouvés sur les îles et revendus au port, quêtes données au port, butin de combat.
- **Ressources** : planches (réparer les trous), boulets de canon, nourriture (soigner), seau (écoper).
- **Port** : ville portuaire animée, dense, façon Eastward (pas un simple avant-poste).
- **Choix du bateau** : chez le charpentier de marine (PNJ + menu) ; le bateau apparaît à quai.

## Le port
Point d'arrivée de tout l'équipage à la connexion. Une ville sur une île :
- **Quai** (promenade pavée, bittes d'amarrage, caisses, filets) et **ponton principal** où le
  bateau choisi est amarré ; un petit ponton de pêcheurs avec des barques.
- **Place du marché** : étals à auvents rayés, puits, **tableau des quêtes**.
- **Boutiques** (façade, enseigne, PNJ devant la porte) :
  | Lieu | PNJ | Rôle |
  |---|---|---|
  | Chantier naval | charpentier | choisir le bateau (sloop, brigantin, galion) |
  | Tailleur | tailleur | skins de personnage (tenues, chapeaux) |
  | Voilerie | voilier | skins de bateau (voiles, coque, pavillon, figure de proue) |
  | Magasin général | marchand | ressources : planches, boulets, nourriture |
  | Taverne | receleur | rachète les trésors |
  | Place | tableau | quêtes |
- Maisons de remplissage, linge tendu, lanternes, palmiers, plage à l'ouest.

## Économie (à régler)
- Or par joueur, sauvegardé dans son profil (`user://profil.json`) avec les skins achetés et portés.
- Les skins sont visibles par tout l'équipage (envoyés avec l'état du joueur).
- Les ressources sont à bord, dans des tonneaux (stock partagé par l'équipage, géré par l'hôte) ;
  on se réapprovisionne au magasin général ou en trouvant des caisses.

## Ressources et dégâts (étape 4)
- Un boulet qui touche fait un trou ; l'eau monte dans la cale ; au-delà d'un seuil le bateau coule.
- Planche : boucher un trou. Seau : écoper. Nourriture : regagner de la vie. Boulets : stock limité.

## Étapes
1. Ville portuaire (modèle 3D, sols peints), bateau amarré — validation visuelle.
2. Arrivée au port à la connexion, marche à terre, monter à bord / descendre, charpentier.
3. Boutiques, or, profil sauvegardé, skins visibles en réseau.
4. Ressources, trous, eau, réparations.
5. Trésors et receleur, quêtes, butin de combat.

## Vie de la ville : hauteurs, intérieurs, PNJ, quêtes (première tranche : la taverne)
- **Hauteurs** (`data/town.json`, `src/land.gd`) : des niveaux (terrasse à 0,45 m, marches, escalier de 3 m) en
  coordonnées du fichier du port. `Land.step()` suit la hauteur du sol ; on ne saute pas d'un étage à l'autre (marche
  max 0,3 m) ; un niveau « solid » retire le sol dessous, une galerie laisse passer dessous.
- **Intérieurs en coupe** : on est « dedans » quand on est dans l'emplacement du bâtiment ; le bâtiment du port est alors
  masqué et l'intérieur (`src/town/town_builder.gd`) apparaît, sans toit ni façade. Pas de fondu.
  Taverne du Pélican Borgne : salle, bar, tables, escalier, galerie à l'étage.
- **Bâtiments transparents** (`_update_building_fade`, shader fantôme dérivé de `shaders/surface.gdshader`) : un bâtiment qui passe devant le pirate (le rayon de lui vers la caméra traverse sa boîte) passe à 50 % d'opacité en gardant sa forme, et le pirate est dessiné par-dessus, net ; `--fade=0.5` règle l'opacité, `--no-fade` coupe l'effet. Les pirates à terre sont avancés de 0,7 m vers la caméra (`SPRITE_DEPTH_BIAS`) pour ne pas s'enfoncer dans les marches.
- **PNJ** (`data/npcs.json`, `src/town/town_npc.gd`) : 7 habitants à leur place, 4 promeneurs en boucle. Parler : E (portée 2,3 m).
- **Quêtes de livraison** (`data/quests.json`, `src/quest_log.gd`) : Tavernier -> tonnelet -> Charpentier (40 or) ;
  Quartier-maître (étage) -> lettre -> Voilière (65 or). Or et état sauvegardés dans `user://profil.json`
  (`src/profile.gd`). Essais : `--fresh` (rien d'écrit), `--quest=id`, `--land=x,-y --lh=hauteur`.
- **Réseau** : protocole 3 (la hauteur du joueur à terre est envoyée) ; l'or et les quêtes restent propres à chacun.
- **À faire** : intérieurs des autres boutiques (+ achats), relief du reste de la ville (quai bas, haute ville, ponts),
  récompenses autres que l'or, choix et conséquences dans les dialogues.

### Relief de la ville (tranche 2)
Tout dans `data/town.json` (niveaux : `rect`, `h` ou pente `axis/h0/h1`, `solid`, `circles`, et pour le rendu `style`,
`rails`, `walls`, `decor`), construit par `src/town/town_builder.gd`. Carte du dessus : `tools/map_town.gd` -> `qa/ville/carte.png`.
- **Parvis de la batterie** (est, 1,5 m) : marches au sud et à l'ouest, canons, mât au pavillon noir ; Odilon la Sentinelle.
- **Jardin en terrasses** (ouest, 0,8 m) : marches au sud et à l'est, massifs de fleurs.
- **Remparts nord** (2,4 m, tout le long du fond de l'île) : atteints par trois ruelles à escaliers (12 marches) entre les
  bâtiments du fond ; canons, lanternes, bancs ; Hector le Veilleur (quête de la longue-vue, 80 or, livrée à Pétronille).
- Un test (`tests/unit/test_town.gd`) vérifie qu'on monte et descend par les escaliers et qu'aucun accès ne contourne.
- À faire : quai bas (débarcadère), passerelles entre niveaux.

### Intérieurs des boutiques (tranche 3, 2026-11-07)
Trois boutiques de plain-pied, en coupe comme la taverne (`kind` dans `data/town.json`, décor dans `src/town/shop_builder.gd`,
coque commune `TownBuilder._shell`) : **Au Fil d'Or** (tailleur : tissus, mannequins, portant, miroir ; Gaspard), **Le Magasin
Général** (provisions, pyramide de boulets, planches, tonneaux ; Mère Pétronille), **La Voilerie** (voiles pendues, table de coupe,
mât de rechange ; Ariane). Leurs PNJ sont passés de la rue à l'intérieur, derrière le comptoir. Test : `_test_shops` dans
`tests/unit/test_town.gd`. Captures : `qa/boutiques/`. Le chantier naval reste une halle ouverte sur le quai (pas d'intérieur).
### Achats (2026-11-07, non commité)
Parler à un boutiquier (sans quête à proposer ni à rendre) ouvre son menu (`src/ui/shop_menu.gd`, règles dans `src/shop.gd`,
catalogue dans `data/shops.json`) : Haut/Bas (ou Z/S) choisir, E acheter, R sortir.
- **Magasin Général** (Pétronille) : planches (8 or, lot de 3 : 20) et boulets (5 or, caisse de 6 : 27), plafonnés (12 / 30).
  Les réserves sont PERSONNELLES (`Profile.planks`, `balls`, départ 4 et 8) : une prise à l'étagère de la cale ou au tonneau du
  pont en consomme une ; à zéro, on le dit au joueur. Affichées sous l'or. Choix assumé : pas de stock partagé de l'équipage
  (pas de changement du protocole réseau).
- **Tailleur** (Gaspard) : bandana 20, calot 30, paille 40, tricorne 60, bicorne 80, gilet 40, veste 70, manteau de capitaine 160,
  écharpe 25, baudrier 45, marinière 30. Payée une fois (`Profile.owned`), remise ensuite gratuitement ; la pièce qu'on quitte
  est gardée. La tenue est sauvegardée et renvoyée à l'équipage (`SailingNet.broadcast_look`).
- Essais : `--gold=150`, `--press=E@1.5,DOWN@2.5,...` (E, R, SPACE, UP, DOWN). `--fresh` ne sauvegarde ni le profil ni la tenue.
- **Voilerie** (Ariane) : skins de bateau, catalogue `data/ship_skins.json` (`src/ship_skin.gd`) : voiles (blanche 30, carmin/bleu
  marine 50, vert mousse 60, noires 90, pourpres 120), coque (bleu nuit/rouge sang/vert forêt 70, ivoire 140), pavillon (rouge/blanc/
  bleu 25, doré 80). La couleur remplace celle des matières nommées du glb (`sail*`, `hull*`, `flag`). Payé une fois (`Profile.owned`,
  `Profile.ship_skin`). **Le bateau porte le skin de son hôte** (ou du joueur en solo) : l'hôte l'envoie à l'équipage (protocole 4,
  `SailingNet._skin`) ; un client qui achète garde ses couleurs pour quand il hébergera. Essai : `--skin=sail:red,hull:navy,flag:gold`.
- **Chantier naval** (Mathurin, devant sa halle) : sloop offert, brigantin 150 or, galion 400 or (`data/shops.json`, kind `ships`).
  `Profile.ships` (possédés) et `Profile.ship` (le bateau du joueur, mis à jour à chaque départ). Le menu de départ verrouille les
  bateaux non possédés (`MainMenu.set_ships`). Prendre un autre bateau en solo recharge la scène (`SailingGame._restart` porte le
  profil) ; en ligne, le changement vaut pour la prochaine partie. Un profil existant sans `ships` repart avec le sloop seul.
  Essai : `--ship=sloop --gold=500 --land=17,-2.8`.
- À faire : la nourriture (pas encore de points de vie), d'autres sources d'or (trésors, butin) — les prix des bateaux
  (150 / 400) sont à régler quand l'or de trésor existera : les 3 quêtes ne rapportent que 185.

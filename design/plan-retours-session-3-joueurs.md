# Plan : retours de la session en ligne à 3 joueurs (13/11/2026)

Version jouée : 2026.11.12-2257 (branche `feature/refonte-gameplay`). Ce document est le plan proposé AVANT de coder.
Rien n'est encore modifié.

## Ce qu'il faut savoir sur le projet avant de lire le plan

- **Il n'y a presque rien à faire dans l'éditeur Godot.** Le jeu n'a pas de scènes `.tscn` de gameplay : le bateau, la
  ville et les personnages sont fabriqués par des scripts (Blender sans interface pour les modèles, GDScript pour le reste),
  et l'interface est construite par le code. Chaque point indique donc « script seul » ou « script + modèle régénéré ».
  Les modèles régénérés (bateau, ville) sont faits par `tools/art/blender/make_ship.py` et `make_port.py`.
- **Les seuls apports extérieurs nécessaires sont des sons** (Epidemic Sound, compte de Jimmy) : listés au lot Audio.
- **Multijoueur** : l'hôte fait autorité. Les joueurs envoient des demandes (`_request`), l'hôte décide et diffuse l'état
  (`_ship_state`, `_fleet_state`, `_action_event`). Toute nouveauté d'état suit ce schéma. Le numéro de protocole passe de
  13 à 14 dès le premier lot qui touche au réseau : tous les joueurs devront mettre à jour (le lanceur le fait).
- Les réglages chiffrés vont dans `src/game_config.gd` (une constante par réglage), pour les ajuster après essai.
- Un commit par point. À la fin de chaque lot : fichiers modifiés et façon de tester.

## Ordre proposé

| Lot | Contenu | Taille |
|---|---|---|
| 1 | P1 : voiles, échelles, coque, pavillon (modèle du bateau) | moyen |
| 2 | P1 : personnages et rendu (silhouette blanche, course en portant, chapeaux, cercle d'ancre, vagues, brume) | moyen |
| 3 | P1 : collisions, multijoueur, naufrage | moyen |
| 4 | P2 : navigation (barre, vent, ancre, canons, portées) et météo | moyen |
| 5 | P2 : combat et PNJ (mobs, équipages, dégâts visibles des bateaux ennemis, précision) | gros |
| 6 | P2 : interactions (porter, échelles, vigie) | moyen |
| 7 | P2 : planches, réparation et menu des coffres de ressources | gros |
| 8 | P3 : bateau (poser des objets, cale en pièces, hublots, porte du balcon, barre, skins masqués) | gros |
| 9 | P3 : trésors (après choix d'une piste) et haute ville | moyen |
| 10 | Audio | moyen (dépend des sons fournis) |
| 11 | Interface épurée et curseur | moyen |

Les lots 1 à 3 corrigent ce qui gêne le plus. Le lot 11 (interface) est rapide et très visible : il peut passer avant le
lot 8 si vous préférez.

---

## Lot 1 — P1 : voiles, échelles, coque, pavillon

| Point | Cause trouvée ou probable | Correction | Type | Multijoueur |
|---|---|---|---|---|
| Un triangle de voile se détache et s'envole quand on monte ou descend les voiles | **Trouvée et vérifiée.** Le second foc s'appelle `sail_z743_jib2` : le jeu lit la hauteur de la voile dans son nom, et le « 2 » de « jib2 » s'y ajoute (74,3 m au lieu de 7,4 m). En carguant, il part donc très haut | Renommer la voile et rendre la lecture du nom stricte (seuls les chiffres juste après `sail_z`) | script + modèle régénéré | aucun (même modèle chez tous) |
| Les voiles ne sont pas accrochées (elles flottent) | Les vergues ne tournent pas avec leur voile : seule la toile pivote | Les vergues suivent leur voile (même nom de famille), garcettes entre toile et vergue, la toile part de la vergue | script + modèle | l'orientation des voiles est déjà synchronisée |
| Les voiles se chevauchent quand elles tournent | Voiles élargies et gonflées (passe 2) : à 65° d'orientation, misaine et grand-voile se croisent | Largeur des basses voiles réduite (−12 %), butée d'orientation de 65° à 55° (`ShipSim.MAX_TRIM` 1,13 → 0,96 rad), creux réduit quand elles sont orientées | script + modèle | aucun |
| Une voile traverse l'échelle de coque | Le bas de la grand-voile descend sur l'échelle (x = 1,6) | Bordure de la grand-voile relevée de 0,4 m ; si ça ne suffit pas, échelle reculée entre les deux canons arrière | modèle | aucun |
| Les échelles traversent la coque ; coque à revoir | Les montants sont des cylindres droits posés sur une coque courbe et rentrante (ajoutée en passe 2) | Montants et échelons calculés sur le profil réel de la coque ; reprise de la finition (bordé, préceintes, jonction tableau arrière) | modèle | aucun |
| Le crâne du pavillon jaune apparaît et disparaît | Le crâne est posé à 3 cm du pavillon : les deux surfaces se battent pour le même pixel, et le skin jaune l'accentue | Crâne dessiné dans la texture du pavillon (comme l'emblème de la grand-voile) | script | aucun |

**Tester :** hisser et affaler dix fois (aucune voile ne s'envole), tourner les vergues à fond des deux côtés, remonter
par les deux échelles voiles hissées, regarder le pavillon jaune de près et de loin.

## Lot 2 — P1 : personnages et rendu

| Point | Cause | Correction | Type | Multijoueur |
|---|---|---|---|---|
| Personnage caché : on voit son image en blanc | Voulu au départ : une silhouette claire unie (`SPRITE_XRAY_COLOR`, blanc-bleu à 38 %) | La silhouette garde les vraies couleurs du pirate, à 45 % d'opacité (réglable) | script (shader du pirate) | aucun |
| Course en portant un objet : les jambes ne bougent plus | À vérifier : l'animation `carry_walk` existe (8 images) ; elle ne semble pas jouée en sprint | Jouer `carry_walk` accélérée en sprint ; même chose pour les autres joueurs (l'état « porte » est déjà envoyé) | script | déjà synchronisé (`_player_state.carry`) ; vérifier l'animation côté distant |
| Chapeaux qui flottent | À diagnostiquer. « Armand Poudre-Noire » est un seul PNJ (l'armurier, bicorne). Je fabrique une planche de contrôle : tous les chapeaux × toutes les coiffures × 8 directions × toutes les animations, pour repérer les décalages | Recaler les calques fautifs dans le générateur (`tools/art/assemble_pirate.py`) | script + images régénérées | aucun |
| Le cercle de l'ancre reste affiché | À reproduire : probablement quand l'action est coupée (on bouge, un autre joueur finit avant) | Le cercle est effacé à toute fin d'action, quelle qu'elle soit | script | l'action est déjà diffusée ; je vérifie le cas « terminée par un autre » |
| Depuis la vigie, plus de vagues au loin | La surface de mer fait 200 m de côté et suit la caméra : en haut du mât on voit son bord | Surface de 320 m dans la vigie (maille de 1 m au lieu de 0,5 m pour ne pas coûter plus) | script | aucun |
| Brume : traînées opaques à gauche | Les « bancs » du filtre d'image dérivent et s'accumulent d'un côté | Bancs supprimés du filtre (la brume 3D suffit), densité globale −15 % (0,25 + 0,7 × brume → 0,21 + 0,6 × brume) | script (shader) | aucun |

**Tester :** passer derrière une maison et un mât, courir avec un coffre (seul et à deux), ouvrir la planche de contrôle
des chapeaux, jeter l'ancre en se faisant interrompre, monter à la vigie par temps clair et par brume.

## Lot 3 — P1 : collisions, multijoueur, naufrage

| Point | État actuel | Correction | Type | Multijoueur |
|---|---|---|---|---|
| Bateau ennemi traversé à la nage et en bateau | Coque contre coque : le code existe (`_touch_enemy_ship`), à vérifier en ligne (il tourne chez l'hôte seulement). À la nage : rien ne l'empêche | Nageur repoussé par les coques ennemies ; contrôle coque contre coque revu et testé à deux instances | script | l'hôte calcule le choc des bateaux ; chaque joueur calcule sa propre nage contre les coques reçues |
| Sortie de l'eau sur une plage | Le nageur reste à la profondeur de nage jusqu'au bord ; il faut sauter | Près du rivage le fond remonte : on passe de la nage à la marche dans l'eau puis sur le sable, sans saut | script | aucun (chacun calcule sa position) |
| Canons : on ne voit pas ceux des alliés bouger | L'angle n'est envoyé qu'au moment du tir (`aim_fire`) | Le joueur qui vise envoie son angle 10 fois par seconde ; l'hôte le rediffuse ; le tube tourne chez tous, lissé | script | nouveau message léger (non fiable, ordonné) |
| « Grab » sur les alliés | **À préciser (question 1).** Le crochet sait saisir la terre, un butin, notre bateau, un bateau ennemi, pas un joueur | Selon la réponse | script | l'hôte valide la prise |
| Naufrage : perdre aussi les coffres posés et le coffre du capitaine | Le bateau est remorqué au port, coque remise à neuf ; le coffre du capitaine garde son contenu | Au naufrage, les trésors posés sur le pont et le contenu du coffre du capitaine sont perdus (voir question 6 : perdus pour de bon, ou laissés flottants sur place) | script | l'hôte vide le coffre et diffuse ; message à tout l'équipage |

**Tester (à deux instances au moins) :** nager contre un ennemi, l'aborder en bateau, sortir de l'eau sur trois plages,
regarder un allié viser au canon, couler avec trois trésors à bord.

## Lot 4 — P2 : navigation et météo

| Réglage | Actuel | Proposé |
|---|---|---|
| Vitesse de la barre (de droite à fond) | 0,63 s (`rudder` : 1,6 par seconde) | 1,6 s (0,6 par seconde) |
| Retour de la barre au centre quand on lâche | immédiat à la même vitesse | 2,2 s, progressif |
| Inertie du virage | aucune : le cap suit la barre tout de suite | le bateau met environ 1,2 s à prendre son virage et autant à le quitter |
| Puissance de virage (brigantin) | 0,35 rad/s (20°/s) | 0,27 rad/s (15,5°/s), soit −23 % ; même proportion sur sloop (0,45) et galion (0,28) |
| Arrêt à l'ancre | freinage 2,9 m/s² : arrêt en 2,8 s depuis la vitesse maximale | glissement : 1,3 m/s², arrêt en 5 à 6 s |
| Redémarrage ancre levée | accélération normale tout de suite | accélération à 40 % pendant 2 s |
| Arc de visée des canons | 360° (`GUN_ARC`) | 50° de chaque côté de la perpendiculaire (100° en tout) |
| Portée des canons | environ 27 m (vitesse du boulet 28 m/s) | environ 32 m (31 m/s), soit +18 % |
| Portée du crochet (« grab ») | 26 m | 22 m (−15 %) |
| Météo : clair / brume / pluie / orage | 76 / 10 / 10 / 4 % | 83 / 8 / 6 / 3 % |

- **Zones et moments sans vent ou de vent contraire** (script seul). Deux mécanismes courts :
  - *calmes* : des zones de 150 à 250 m, fixes sur la carte et tirées de la graine du monde, où le vent tombe à 15 % ;
  - *sautes de vent* : toutes les 4 à 7 minutes, pendant 25 à 40 s, le vent tourne de 120 à 180°.
  Voiles hissées par vent contraire : elles freinent (rendement négatif, −15 % de vitesse) au lieu du plancher actuel de
  22 %. Les carguer devient donc plus avantageux, comme demandé. On le lit sur la flamme, les voiles qui battent et les
  traînées de vent. Multijoueur : le vent vient de l'hôte (déjà dans l'état du bateau) ; les zones sont calculées
  pareil chez tous à partir de la graine.
- **Frapper le bateau** : à confirmer (question 2).

**Tester :** virer de bord à pleine vitesse (le bateau doit « partir » et « revenir » avec retard), traverser une zone de
calme, jeter l'ancre à pleine vitesse, viser au canon vers l'avant et l'arrière (butée).

## Lot 5 — P2 : combat et PNJ

| Réglage | Actuel | Proposé |
|---|---|---|
| PV crabe / squelette / soldat / officier / capitaine | 2 / 3 / 4 / 8 / 18 | 3 / 5 / 6 / 11 / 24 |
| Vitesse des mobs | 2,4 à 2,7 m/s | +10 % |
| Cadence d'attaque (temps de repos) | 1,0 à 1,3 s | −15 % |
| Canonniers en plus par rang (1 à 4) | 0 / 1 / 1 / 2 | 0 / 1 / 2 / 3 |
| Temps de chargement d'un canon ennemi par rang | 0,9 s partout | 0,9 / 0,8 / 0,7 / 0,6 s |
| Précision des tirs ennemis par rang | la même | dispersion −10 % par rang |
| « Stun » d'un ennemi touché | à mesurer (recul 1,2 à 2,4 m et reprise de l'attaque) ; voir question 3 | −25 % |
| Dispersion des armes en sprint | ×1 | ×2,5 (et +0,05 rad pour le fusil, qui est à 0) |
| Dispersion en saut | ×1 | ×3,5 (et +0,08 rad pour le fusil) |
| Vitesse en portant un coffre | 100 % | 85 % à la marche, sprint limité à 1,35 au lieu de 1,53 |

- **Plus de barre de vie sur les bateaux ennemis** : le texte `[#####-----]` au-dessus du bateau disparaît (le nom et
  le rang restent, voir question 4). À la place, des dégâts visibles par paliers : à 75 % de coque, premiers trous et
  planches cassées ; à 50 %, voiles déchirées et fumée ; à 25 %, gîte et enfoncement ; à 0 %, naufrage. Script seul (trous
  et planches posés sur la coque, voiles remplacées par une version déchirée). Multijoueur : les points de coque sont
  déjà dans l'état de la flotte ; chaque joueur en déduit les mêmes dégâts (graine = identifiant du bateau).

**Tester :** île à squelettes seul puis à deux, combat contre un rang 1 et un rang 3, tirer en courant et en sautant.

## Lot 6 — P2 : interactions

| Point | Proposition | Type | Multijoueur |
|---|---|---|---|
| Lâcher au clic gauche (à confirmer, question 5) | Quand on porte quelque chose, clic gauche et clic droit le lâchent tous les deux (on ne peut pas attaquer en portant) | script | l'objet posé est déjà diffusé |
| Bloquer les postes quand on porte (à confirmer, question 5) | Barre, voiles, ancre, canons, échelle de mât refusés avec le message « Tes mains sont prises ». Restent permis : coffre du capitaine, charger un canon avec le boulet porté, réparer avec la planche portée, échelle de coque | script | aucun |
| Échelles manuelles | Z monte, S descend, on peut s'arrêter ; E pour s'accrocher et se décrocher. Vitesse 2,6 m/s (inchangée). Animation de montée `climb` (4 images, existe) calée sur les barreaux, pirate dessiné devant l'échelle | script | la hauteur est déjà envoyée (`pz`) |
| Sauter depuis la vigie | Espace dans le nid : saut vers l'extérieur dans la direction visée ; on tombe à l'eau ou sur le pont (dégâts de chute sur le pont : 1 cœur) | script | position déjà synchronisée |
| Dézoom de la vigie | Grossissement 0,45 → 0,30 dans le nid (limite basse 0,40 → 0,28) | script | aucun |

## Lot 7 — P2 : planches, réparation, coffres de ressources

- **Limites d'inventaire** : planches 99 → 10, boulets 99 → 10 (question 7 pour les boulets). Les joueurs qui en ont plus
  aujourd'hui gardent leur stock jusqu'à ce qu'il descende sous la limite.
- **Réparer** : déjà possible avec une planche ; inchangé, mais on puise dans ses 10 planches.
- **Menu à deux panneaux** (comme Sea of Thieves) : à gauche le coffre (planches, boulets, puis balles et cartouches),
  à droite le sac. Clic = une unité, Maj + clic = tout ce qui rentre, glisser-déposer dans les deux sens. Réutilise les
  cases et les icônes du sac actuel (`inventory_panel.gd`).
- **Type** : script seul. L'interface du jeu est construite par le code ; aucune scène à faire dans l'éditeur.
- **Multijoueur** : aujourd'hui la caisse est une réserve sans fond côté joueur. Elle devient un stock tenu par l'hôte.
  Chaque prise ou dépôt est une demande (`chest_take`, `chest_put` avec le type et la quantité) ; l'hôte l'applique dans
  l'ordre d'arrivée, borne à ce qui reste et à la place du joueur, puis renvoie le stock à tous. Deux joueurs qui prennent
  la dernière planche : le premier arrivé l'a, l'autre voit le compteur à zéro. Pas de duplication possible, le client
  n'ajoute rien à son sac avant la réponse de l'hôte.
- Le stock de départ et le réapprovisionnement au port sont à régler (proposition : 30 planches, 40 boulets au départ ;
  plein gratuit à quai chez Mère Pétronille comme aujourd'hui).

## Lot 8 — P3 : bateau

| Point | Proposition | Type | Multijoueur |
|---|---|---|---|
| Poser des coffres et des objets dans le bateau | Un objet posé sur le pont ou dans la cale reste à sa place (repère du bateau), sans limite de temps à bord ; on le reprend avec E | script | liste des objets posés tenue par l'hôte, diffusée avec l'état du bateau |
| Cale plus grande, en plusieurs pièces | Trois pièces en enfilade séparées par des cloisons à porte : réserve avant (boulets, planches), pièce centrale (échelle, voies d'eau), cambuse arrière (tonneaux, hamacs). Longueur +40 % | script (la cale est construite par le code) | les voies d'eau et l'eau sont déjà synchronisées |
| Hublots dans la cale | Ouvertures rondes dans le mur du fond : on y voit la mer et l'horizon à la bonne hauteur, avec la houle | script (shader) | aucun |
| Porte arrière de la cabine vers le balcon | Porte dans le mur arrière, balcon praticable avec garde-corps solide (on ne tombe pas à travers, on peut sauter par-dessus) | script + modèle | aucun |
| Barre un peu plus petite | Rayon de la roue 0,50 → 0,44 (−12 %) | script | aucun |
| Skins de bateau masqués | La voilerie ne vend plus proues, voiles, coques ni pavillons ; tous les bateaux reviennent à l'apparence d'origine ; les achats restent dans les profils. Un seul réglage (`SHIP_SKINS_ENABLED`) pour les rallumer | script | l'apparence diffusée est ignorée tant que le réglage est éteint |

## Lot 9 — P3 : trésors et haute ville

**Trésors : trois pistes, à choisir avant de modifier.**

1. **Une forme par valeur.** Petit : bourse de cuir. Moyen : coffret de bois cerclé de fer. Gros : coffre bombé cerclé
   d'or. Légendaire : coffre noir aux chaînes, serrure en crâne, lueur rose nacré. On reconnaît la valeur à la silhouette,
   même de loin.
2. **Une matière par valeur.** Même coffre pour tous, mais bois brut, puis fer, puis argent, puis or, avec un
   scintillement de plus en plus fort. Plus simple à lire, moins varié.
3. **Des objets, pas des coffres.** Idole, calice, crâne de cristal, couronne, carte scellée, tonnelet de rhum rare. Plus
   de variété et d'histoire, mais la valeur se lit moins bien : il faut un liseré de couleur par rareté.

Ma recommandation : la piste 1, avec le scintillement de la piste 2 pour les deux plus hautes valeurs.
Type : script + petits modèles fabriqués par le code. Multijoueur : aucun changement (le type de trésor est déjà diffusé).

**Haute ville.**

- Maisons de biais : remises droites, mais décalées en profondeur les unes par rapport aux autres pour garder le côté
  « pas aligné » (question 8 : toutes droites, ou seulement celles qui gênent ?).
- Fond en herbe traversable (« première partie de la ville ») : à reproduire ; je pense à la bande d'herbe au pied des
  remparts côté ville basse. Mur ou talus solide ajouté.
- Maisons du fond trop serrées : la rangée du fond passe de 6 à 4 maisons, avec jardins et arbres entre elles.
- Type : script + modèle de la ville régénéré. Multijoueur : aucun (même modèle chez tous).

## Lot 10 — Audio

| Point | Diagnostic ou proposition | À fournir |
|---|---|---|
| Fusil de précision : changer le son | Nouveau tir sec et long, avec écho | 1 son Epidemic (je le choisis et le découpe en variantes) |
| Tromblon : parfois un son faible et bizarre | À diagnostiquer avec les traces `SFX_DEBUG` : mauvaise variante, coupure par la limite de 4 voix, ou atténuation chez les autres joueurs | rien |
| Pluie | Volume 0,8 → 0,4 (−50 %) ; nouveau bruitage en trois intensités (fine, soutenue, averse) ; l'intensité varie et s'interrompt par accalmies de 20 à 60 s | 3 boucles Epidemic |
| Curseur « Pluie » dans les réglages | Quatrième curseur dans le panneau des volumes | rien |
| Barre | Nouveau son de roue (bois et corde), moins grinçant | 1 son Epidemic |
| Écoper, réparer | 4 à 6 variantes chacun, hauteur ±1 demi-ton, volume ±1,5 dB (le système existe déjà) | 2 sons Epidemic |
| Musique | Volume par morceau (plus d'écart entre thèmes calmes et forts), nouveaux morceaux, silences entre deux morceaux déjà en place (60 à 180 s) à allonger par moments | 4 à 6 morceaux Epidemic |

Pour les sons, il me suffit que Jimmy soit connecté à Epidemic Sound dans le navigateur intégré, comme la dernière fois.

## Lot 11 — Interface épurée et curseur

| Élément | Décision | Information perdue ? |
|---|---|---|
| Cadran rond en haut à gauche (cap, vent, « voiles affalées ») | supprimé | Le vent reste lisible par la flamme en tête de mât, les voiles qui se gonflent ou battent, les traînées de vent. La vitesse n'est plus chiffrée : on la lit au sillage |
| Bandeau du haut (vitesse, voiles, ancre, barre, vent, moment du jour) | supprimé | Ancre et voiles se voient sur le bateau. **Signalé :** l'angle de barre n'est plus affiché ; la roue le montre (elle tourne), je propose une poignée repère en laiton sur la roue |
| Longue phrase d'aide en bas | supprimée | Les touches restent dans le menu pause |
| Or, nombre de trésors, objectifs de quête permanents | retirés de l'écran ; visibles dans le sac (Tab) et le journal | Aucune |
| Indication contextuelle | « [E] Barre », « [E] Monter », courte, juste sous le centre de l'écran, seulement quand un poste est visé | — |
| Barre de réputation | retirée de l'écran, affichée dans le sac ; petit « +50 » temporaire au gain | Aucune |
| Pseudo des joueurs dans l'eau | affiché au-dessus du nageur | — |
| Boussole et destination (à confirmer, question 9) | la flèche de guidage ne s'affiche que boussole en main | Sans boussole, plus de guidage : c'est le but |
| Sirène | disparaît 3 s après le retour à bord | — |
| Curseur de souris | curseur dessiné dans le style du jeu (pointe de sabre en laiton, version « main » sur un bouton, viseur au canon et à l'arme) | — |

Les cœurs de vie restent (information vitale en temps réel). Type : script seul, plus trois petites images de curseur
que je dessine. Multijoueur : aucun.

---

## Réflexion design : donner de l'intérêt aux îles (propositions, pas de code)

| Idée | Principe | Complexité |
|---|---|---|
| 1. Cartes au trésor à énigme | Une carte dessinée montre un repère de l'île (rocher fendu, trois palmiers) : il faut trouver l'endroit à pied et creuser. Les meilleurs trésors ne viennent que de là | Moyenne : le générateur d'îles pose déjà des repères ; il faut la carte dessinée et l'action de creuser |
| 2. Grottes et camps à nettoyer | Chaque île moyenne a un lieu fermé (grotte, fortin) avec une vague d'ennemis, un chef et un coffre verrouillé dont la clé est sur le chef | Moyenne à forte : nouvelles pièces de décor, un chef par type d'île |
| 3. Ressources qu'on ne trouve qu'à terre | Bois pour les planches, fruits pour se soigner, poudre dans les épaves échouées : le bateau ne se ravitaille plus tout seul au port | Faible à moyenne : la cueillette de baies existe déjà, à étendre |
| 4. Événements d'île à durée limitée | Une fumée ou un feu visible de loin signale un naufragé à secourir, un marchand de passage, un trésor qui sera repris par un équipage ennemi dans 5 minutes | Moyenne : s'appuie sur les naufragés et les ennemis existants |
| 5. Avant-postes à tenir | Capturer une île donne un bonus à tout l'équipage (ravitaillement gratuit, point de réapparition, vigie qui révèle la carte), mais les ennemis reviennent la reprendre | Forte : la capture existe déjà, il faut la défense et les bonus |

Ordre conseillé : 3 puis 1 (peu coûteux, changent tout de suite la raison d'accoster), puis 4.

---

## Questions avant de commencer

1. **« Grab »** : c'est bien le crochet (grappin) ? Et « le grab sur les alliés » : vous voulez accrocher un allié pour
   le tirer vers soi (ou se tirer vers lui), ou c'est « hisser un camarade hors de l'eau » (E au bord) qui ne marche pas ?
2. **Frapper le bateau** : frapper un bateau ennemi au sabre et aux armes à feu pour l'abîmer ? (Proposition : dégâts
   très faibles, 1 % de coque par coup, pour ne pas remplacer les canons.) Ou frapper notre propre bateau ?
3. **« Stun »** : c'est le recul d'un mob touché au sabre, ou le ralentissement après un boulet (1,5 s aujourd'hui) ?
4. **Bateaux ennemis** : sans barre de vie, on garde le nom et les étoiles de rang au-dessus du bateau, ou plus rien ?
5. **Porter** : je confirme « clic gauche lâche aussi » et « postes bloqués quand on porte », avec les exceptions listées
   au lot 6 ?
6. **Naufrage** : les trésors perdus disparaissent pour de bon, ou flottent sur le lieu du naufrage pendant 5 minutes
   (on peut revenir les chercher, les ennemis aussi) ?
7. **Boulets** : limite à 10 comme les planches ?
8. **Haute ville** : toutes les maisons droites, ou seulement celles qui gênent le passage ?
9. **Boussole** : je confirme « guidage seulement boussole en main » ?
10. **Publication** : une version dans le lanceur après chaque lot, ou après les lots 1 à 3 d'un coup ?

---

## Réponses de Jimmy (13/11) : elles remplacent les propositions ci-dessus

1. **Grab** = le crochet. Ce qui ne marche pas : **hisser un coéquipier qui est dans l'eau** pour le remettre à bord (lot 3).
2. **Frapper le bateau** = pouvoir se servir des armes à bord, sur notre bateau comme sur celui des ennemis : **l'abordage**.
   Monté sur un bateau ennemi, on tue les squelettes sur place : les canonniers (ils reviennent après un délai), le timonier
   (le bateau ne manœuvre plus), et on peut jeter leur ancre. Ajouté au lot 5, c'est son plus gros morceau.
   Reste à préciser : les coups entre coéquipiers font-ils des dégâts ?
3. **Stun** : un ennemi touché par balle se fige, on n'a plus qu'à recharger et retirer. Il ne doit plus se figer : un petit
   recul, et il continue d'avancer (lot 5).
4. **Bateaux ennemis** : au-dessus du bateau, le nom et le rang, sans barre de vie.
5. **Porter** : postes bloqués (barre, ancre…) tant qu'on porte un objet ; il faut le poser d'abord. (Le clic gauche pour
   lâcher reste à confirmer.)
6. **Naufrage** : les trésors flottent sur place 5 minutes, puis disparaissent.
7. **Boulets** : limite à 10 comme les planches ; on les reprend au coffre (une action de plus pour recharger).
8. Haute ville : pas encore de réponse.
9. **Boussole** : guidage seulement boussole en main ; son affichage est à refaire plus proprement (lot 11).
10. Publication : pas encore de réponse.

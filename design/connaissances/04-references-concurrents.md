# 04 : Références concurrents et ambiance (bateau, monde, vie, interface)

> Recherche du 12/11/2026. Complète `design/bible-direction-artistique.md` (qui couvre déjà le rendu, la palette et les
> sources de modèles) sans le répéter.
> Méthode : making-of, interviews, wikis, fiches GDC, et **captures officielles Steam regardées une par une** (marquées
> **(vu)**). Limites : le talk GDC de Sea of Thieves est sur GDC Vault ; plusieurs pages refusent la lecture automatique.
> Les proportions de la partie 1.4 sont **nos recommandations**, pas des chiffres sourcés.

---

## 1. Les navires dans les jeux stylisés

### 1.1 Sea of Thieves : la référence absolue pour « un bateau qu'on habite »

**Ce que disent les gens de Rare**
- Le chef du studio, Craig Duncan, résume l'approche des navires : « a little bit warped, a little bit bent ». Tout est un
  peu tordu, et c'est voulu : l'art director Ryan Stevenson voulait que tout soit « un peu bancal » (*wonky*), avec un
  rendu peint et « vécu ». Les tonneaux ont un aspect rugueux (GamesBeat).
- Résumé du talk GDC (blog Habrador) :
  - ne pas viser le réalisme et tout simplifier ;
  - construire les scènes complexes en combinant des objets simples ;
  - les objets doivent paraître **usés** (bosses, éclats) et **réparés** (rustines, sangles de cuir) ;
  - le « bancal » doit rester **réaliste**, c'est-à-dire une déformation plausible du bois et non un cartoon mou à la
    Fortnite ;
  - la direction de la lumière est l'outil d'ambiance le plus oublié.
- Le game designer Ted Timmins insiste sur le moment où l'on voit au loin un navire avec sa **livrée** et sa **figure de
  proue** surgir à l'horizon : la silhouette et la couleur des voiles sont une identité.

**Ce que j'ai vu sur les captures (vu)**
- **Flotte de face** :
  - coques ventrues, plus larges au milieu qu'au pont (rentrée de la muraille) ;
  - poupes très hautes, beaupré long et relevé vers le ciel ;
  - **bandes horizontales de couleur** sur la coque (préceintes peintes), filets dorés ;
  - voiles carrées très **gonflées**, chacune peinte d'un grand emblème ;
  - au sommet des mâts, de **longues flammes ondulantes**, deux à trois fois la largeur d'une vergue : l'élément qui fait le
    plus « pirate » dans la silhouette.
- **Sur le pont** :
  - planches larges aux joints bien visibles, plat-bord épais (pavois à hauteur de hanche) ;
  - **mâts cerclés de fer noir** ;
  - cordages épais qui **pendent en courbe** (jamais tendus droits) ;
  - échelle de corde montant aux hunes ;
  - lanternes carrées fixées **à l'extérieur** de la coque ;
  - échelle de coque, bancs, petits canons trapus sur affût ;
  - peinture de coque turquoise délavée, avec des planches de teintes légèrement différentes.
- **Silhouettes au couchant** : on reconnaît un navire à trois choses, le **nombre de mâts**, la **hauteur de la poupe**
  et les **flammes**. Le détail de la coque disparaît.

**Le brigantin de Sea of Thieves (wiki)**
- 3 joueurs maximum (exactement notre cas), 2 mâts, 4 canons (2 par bord), cabestan à 3 barres.
- Pont principal et un seul pont inférieur.
- **Sur le pont** :
  - barre près de la poupe avec un compas à côté ;
  - nid de pie au grand mât (coffre à pavillons et cloche) ;
  - deux échelles de part et d'autre de la voile arrière ;
  - canot à la poupe, trois lanternes, tonneau de grog, seau d'eau.
- **En dessous** :
  - table des cartes sous l'étrave ;
  - deux tonneaux de vivres avec un poêle, trois tonneaux de boulets, un tonneau de planches ;
  - cinq lanternes ;
  - cabine du capitaine avec lit, étagères, bibliothèque, rideau et coffres.
- Leçon : un pont « vivant » tient en une quinzaine d'objets bien placés. Rare a ajouté après la sortie un poêle, un
  seau, des coins pour dormir et une bibliothèque : des objets « de vie », pas seulement utiles.

**L'interface** : une seule carte du monde, posée sur une table sous le pont ; pas de mini-carte ; boussole tenue en
main. L'interface « dans le monde » fait partie du charme du bateau.

### 1.2 Les autres jeux : ce qu'on retient, ce qu'on évite

| Jeu | Ce qu'il fait bien pour un bateau | À retenir pour nous | À éviter |
|---|---|---|---|
| **Assassin's Creed IV** (Jackdaw) | Le Jackdaw est un **brigantin** (GamesBeat) ; le plan de conception montrait 6 canons au départ et 56 entièrement équipé. L'équipage chante des chants de marins pendant la navigation | Le bateau grandit avec le joueur : améliorations **visibles** (blindage, voiles, figure de proue, barre). L'équipage qui chante = la vie à bord par le son | Le réalisme historique pur (l'équipe visait l'exactitude) : trop de détail pour du 640x360 |
| **Skull and Bones** | Talk GDC 2023 d'Andie Sulistio : partir de l'anatomie des vrais navires puis l'adapter au jeu et à la caméra | Méthode : anatomie réelle d'abord, puis on exagère ce qui se lit à notre caméra | Navires-chars d'assaut, surchargés de pièces d'armement |
| **Sail Forth** (2022) | (vu) Aucune texture, aplats pastel, mâts fins, haubans en lignes simples, mer à deux tons avec grandes taches d'écume blanche, phare avec faisceau | La preuve qu'un bateau charmant n'a pas besoin de texture : silhouette + couleur des voiles + flamme. L'auteur donne à chaque région sa palette | Les ponts vides : vus de près, ses bateaux sont des jouets sans vie |
| **Dredge** (2023) | (vu) Petit chalutier vu en 3/4 plongeant : coque sombre, bandeau clair au-dessus, **pneus en défenses** le long de la coque, cabine avec fenêtre éclairée, mât de charge | La **fenêtre éclairée** suffit à rendre un bateau habité. Une couleur de brume par biome. L'équipe a gardé des « erreurs » du shader d'eau parce qu'elles étaient plus belles (Unity) | Le low-poly anguleux choisi par manque de temps (leurs propres mots) |
| **Return to Monkey Island** (2022) | (vu, intérieur de boutique) Formes découpées dans du papier, perspectives tordues, objets penchés, ombres profondes et lumière jaune de lanterne | Tout penche un peu, rien n'est d'équerre. Lumière chaude localisée dans une scène sombre | Le style a divisé les fans (Ron Gilbert l'a défendu comme volontairement provocant) : à doser |
| **Windbound** (2020) | Bateau construit par le joueur (bambou, peaux), rendu cel-shading | Les pièces du bateau racontent comment il a été fabriqué (ligatures, pièces rapportées) | Les îles procédurales qui se ressemblent |
| **Blackwake** (2017) et **Raft** (2018) | Navires à plusieurs ponts bien modélisés ; radeau qui grandit planche par planche | Le pont des canons comme lieu de jeu (boulets, écouvillons, seaux) ; le bricolage visible (planches dépareillées, bâches) | Le réalisme gris |
| **Tchia** (2023) | Monde inspiré de la Nouvelle-Calédonie, petit voilier personnalisable, faune locale modélisée fidèlement | S'inspirer d'un lieu réel précis donne de l'authenticité (ici : une vraie poule de Hienghène) | : |
| **Wind Waker** (2002) | Cel-shading, Lion Rouge (bateau à une voile et tête sculptée), Windfall ville la plus peuplée, habitants avec emplois du temps | Une **tête sculptée** suffit à donner un caractère au bateau. Les PNJ ont des horaires | : |

### 1.3 Artistes, modèles et pixel art : ce qui rend un bateau « beau » vu de dessus

**Références de modèles stylisés** (à regarder, pas forcément à acheter)
- 3D : *Stylized Pirate Ship* de Maksim Batyrev (Sketchfab, environ 18 000 triangles) ; celui de 3digitalis (750 faces
  seulement : une silhouette juste se passe de polygones) ; un brigantin « chibi » sur CGTrader.
- Pixel art : *Minifantasy Ships and Docks* (navires et quais vus de dessus), *Black Sail Ship* de Bleed (16 directions),
  *Isometric Pirates* de Monogon (voxel), *N64 style - Retro pirate isles* (pièces de navire modulaires).

**Ce qui se lit vu de dessus à 40° (synthèse des captures et des packs)**
1. **La forme du pont en amande** : étroit à la proue, large au milieu, carré et surélevé à la poupe. C'est la silhouette n°1.
2. **Le contraste pont clair / plat-bord foncé** : le liseré sombre du pavois dessine le contour du bateau. À 40°, on voit
   aussi le **flanc de coque** sur un seul côté : c'est là que vont les bandes de couleur, les sabords et les lanternes.
3. **Les planches dans le sens de la longueur** : elles donnent la direction du bateau même immobile. Ajouter quelques
   planches plus claires ou plus foncées au hasard.
4. **Les « ronds »** :
   - mâts vus de dessus avec leur hune ;
   - cabestan, tonneaux.
   Ils cassent la grille des planches et servent de repères.
5. **Les caillebotis** (écoutilles en grille) : un motif en damier minuscule qui fait tout de suite « navire ».
6. **Les vergues en croix et les voiles gonflées** : de dessus, une voile est une forme en croissant avec un côté clair
   (face au soleil) et un côté ombré. Il faut deux tons au minimum.
7. **Les haubans en V** : du haut du mât jusqu'aux porte-haubans sur les flancs. En pixel art, ce sont des **lignes d'un
   pixel**, pas des cylindres 3D (qui scintillent à 640x360).
8. **Le sillage et l'écume** autour de la coque : il ancre le bateau dans l'eau (Sail Forth, Sea of Thieves).

### 1.4 Anatomie d'un brigantin crédible et charmant

**Définition** : deux mâts.
- **Mât de misaine** (avant) : **gréé carré**, avec la misaine (basse voile), le hunier et le perroquet.
- **Grand mât** (arrière, **le plus haut**) : une **grand-voile aurique** (trapèze tenu par une corne en haut et une bôme
  en bas) et au moins un **hunier carré** au-dessus.
- Le brick, plus tardif, est carré sur les deux mâts. Au début du XVIIIe siècle, « brigantin » désignait plutôt ce gréement
  mixte (Wikipédia).

**Base de travail** : notre brigantin fait 25 m (refonte du 12/11, coques x1,35 en longueur, x1,4 en largeur). Les
proportions ci-dessous sont relatives à la **longueur de coque L**.

| Élément | Proportion proposée | Ce qu'on garde | Ce qu'on simplifie |
|---|---|---|---|
| **Coque** | largeur 0,28 à 0,30 L (un vrai navire est plus effilé, vers 0,25 : on élargit pour le pont praticable) ; **tonture exagérée** (le pont remonte nettement vers la proue et la poupe, deux fois le réel) | Ventre arrondi, rentrée de la muraille, 2 ou 3 préceintes peintes (bandes), quille visible à l'avant | Pas de bordages individuels modélisés : planches peintes dans la texture et en couleurs par sommet |
| **Pavois et rambardes** | hauteur 1 m (hanche du personnage) sur le pont principal ; **rambarde à balustres** sur le gaillard d'arrière | Sabords carrés, dalots (petits trous au ras du pont) avec une coulure sombre en dessous | Balustres en 4 ou 5 « dents » répétées, pas en tournage |
| **Gaillard d'arrière** (cabine du capitaine dessous) | 0,25 à 0,30 L, surélevé de 1,2 à 1,5 m, escalier de 4 ou 5 marches sur un ou deux côtés | Barre (roue) dessus ou juste devant ; **lanterne de poupe** sur le couronnement | Une seule hauteur de pont (pas de dunette en plus) |
| **Poupe** | tableau arrière plat, légèrement penché, un peu plus large que haut | **Fenêtres de la cabine** (3 à 5, à petits carreaux, éclairées la nuit), nom du navire peint, galerie ou balcon optionnel, deux lanternes d'angle | Sculptures réduites à un cadre doré et un motif central |
| **Gaillard d'avant** | 0,15 L, à peine surélevé (0,5 m) ou au niveau du pont | Cabestan d'ancre juste derrière ou dessus, bossoirs (poutres qui débordent pour tenir l'ancre), ancre accrochée au flanc | Une seule ancre visible |
| **Proue et figure de proue** | éperon (guibre) 0,1 L devant l'étrave | **Figure de proue** = l'identité du bateau (femme, sirène, animal, crâne) ; elle doit dépasser de la silhouette | 1 forme simple et lisible, peinte de 2 ou 3 couleurs |
| **Beaupré** | 0,35 à 0,40 L au-delà de l'étrave, relevé de 20 à 30° | 2 focs triangulaires (3 au maximum), martingale (petit espar vers le bas) | Pas de bâton de clinfoc séparé |
| **Mât de misaine** | à 0,30 L de l'étrave ; hauteur au-dessus du pont 0,75 à 0,85 L | 3 vergues (misaine, hunier, perroquet), voiles de plus en plus petites vers le haut, **hune** (plateforme) à mi-hauteur | Hauteur réelle (environ L) écrasée : notre caméra plongeante n'en a pas besoin, et les voiles cachent le pont |
| **Grand mât** | à 0,60 L de l'étrave ; hauteur 0,85 à 0,95 L ; léger **penché vers l'arrière** (quelques degrés) | Grand-voile aurique avec corne et bôme débordant sur la poupe, 1 hunier carré, **nid de pie** au-dessus de la hune | 1 seul hunier, pas de perroquet |
| **Voiles** | gonflées, bas courbe | 2 tons minimum (lumière, ombre), **coutures verticales** (lés de toile), 1 ou 2 **rustines** de couleur différente, ralingue (bordure) plus foncée | Pas de ris (rangées de garcettes), ou une seule rangée suggérée |
| **Gréement** | haubans de chaque côté, étais d'un mât à l'autre et vers le beaupré | **Haubans + enfléchures** (échelles de corde) car on y grimpe ; drisses qui pendent en courbe ; quelques cordages lovés (en rond) sur le pont | Lignes d'un pixel, couleur fixe ; pas de poulies sauf 2 ou 3 grosses près du pont |
| **Pavillons** | pavillon de poupe au bout de la corne (1,5 à 2 m de large), **flamme** en tête de grand mât (longue : 3 à 4 m) | Pavillon noir ou livrée de l'équipage ; flamme animée par le vent : elle indique sa direction | Animation en 4 à 6 images ou par shader de vague |
| **Lanternes** | 3 sur le pont, 1 de poupe, 1 au nid de pie | Corps carré en métal noir, verre jaune, **halo chaud la nuit** | Pas d'éclairage dynamique par lanterne si trop coûteux : halo peint + bloom (bible) |
| **Canons** | 3 par bord, affûts à 4 roues rouges ou noirs, palans de rappel | Boulets empilés en pyramide, écouvillon et seau à côté | Palans suggérés par 2 lignes |
| **Cale** | sous le pont principal, hauteur 2 m | Tonneaux, caisses, sacs, hamacs, lanternes, eau qui clapote au fond | Cloisons simples |
| **Canot** | 0,20 L, retourné sur le pont ou suspendu à la poupe | Lisible, utile au récit (débarquer) | : |

**La recette du charme (règles transversales)**
1. **Rien d'horizontal ni de vertical parfait** :
   - tonture courbe, mâts légèrement penchés ;
   - vergues un peu de travers quand le vent tourne ;
   - planches de longueurs inégales.
2. **Usure et réparation**, à la Sea of Thieves :
   - peinture écaillée sur les arêtes et les bords du pont ;
   - planches neuves plus claires plantées au milieu des vieilles ;
   - rustines sur les voiles, cordage épissé ;
   - coulures de rouille sous les ferrures et les dalots.
3. **Une couleur d'identité** : coque à bandes (par exemple bois sombre et bande rouge ou turquoise), voiles crème, une
   couleur d'accent (or ou rouge) réservée à la figure de proue et à la poupe.
4. **La silhouette d'abord** : 2 mâts, poupe haute, flamme et beaupré relevé doivent se reconnaître en noir sur fond clair à
   60 px de large.
5. **Lisibilité du joueur** : le pont est d'une valeur moyenne et chaude ; les personnages (48x64) doivent ressortir en
   valeur. Pas de motif chargé là où l'on marche.
6. **Ne jamais cacher le joueur**. Eastward le dit : la caméra fixe oblige à arranger le monde pour que le joueur ne soit
   jamais masqué par le décor. Pour nous : **voiles et vergues qui s'estompent** quand un joueur passe dessous (comme les toits
   coupés des jeux isométriques), et pont de la cabine en coupe quand on y entre.

---

## 2. Villes portuaires et îles stylisées

### 2.1 Les références de jeux

- **Sea of Thieves (avant-postes)**
  - Chaque avant-poste est une petite ville-île avec une taverne nommée (*The Unicorn*, *The George & Kraken*, *The Drowned
    Rat*), un forgeron, une boutique d'équipement, une boutique de vêtements, un charpentier de marine et des comptoirs
    de compagnies marchandes.
  - Les plans varient : Ancient Spire est faite de deux îles séparées par un chenal, avec ponts, grottes et échelles
    jusqu'à la taverne au sommet. Sanctuary a un gros rocher d'un côté et trois îlots autour.
  - Port Merrick, ancien Golden Sands, est devenu un avant-poste fortifié avec une auberge.
  - Leçon : peu de bâtiments, mais **chacun a une enseigne et une fonction** ; une verticalité forte (taverne en haut).
- **Monkey Island**
  - Mêlée est un village de nuit, bleu et violet, aux fenêtres jaunes.
  - Dans *Monkey Island 2*, **Woodtick est une ville entière faite d'épaves reliées par des passerelles** : idée parfaite pour
    un quartier pauvre ou un repaire.
  - *Return to Monkey Island* (direction artistique de Rex Crowle) : bâtiments penchés, formes découpées, lumière de lanterne.
- **Eastward**
  - Ville multi-niveaux, gare en bois de récupération au toit en forme de baleine, maison en forme de bateau.
  - L'équipe voulait au moins **un élément singulier par lieu** ; l'élévation et les escaliers rendent une zone dense sans
    cacher le joueur.
  - Les chemins doivent suivre les directions de l'écran.
  - La brume en couches et les rayons de soleil marquent l'aube et le crépuscule.
  - (vu) Taches de lumière qui filtrent à travers les arbres sur le sol, végétation très dense, vieux bâtiments mangés par
    la nature.
- **Zelda Wind Waker** : Windfall, ville la plus peuplée, habitants avec horaires et relations ; l'île est un refuge,
  la mer l'épreuve.
- **A Short Hike** : une île unique lisible avec le moins de pixels possible, ombrage plat, contour doux, curiosité
  récompensée hors du chemin.
- **Cassette Beasts** (Godot, 2023)
  - (vu) Harbourtown : quais en pierre, bittes d'amarrage, pontons en planches orange, petits murets de brique, garde-corps
    en bois, canaux bleu profond avec reflets, flou de profondeur en arrière-plan.
  - Les cartes sont pensées comme un jeu 2D vu de dessus (caméra fixe, terrain en grille), les tuiles 3D sont faites dans
    un éditeur voxel (Qubicle) puis exportées vers Godot.
  - Le monde est dessiné en **boucles concentriques** qui ramènent à la ville.
  - Deux développeurs seulement : la référence technique la plus proche de nous.
- **Sea of Stars**
  - (vu) Le port de Brisk vu de haut : un **amas compact de maisons cubiques à toits plats** accroché à une falaise, un ponton en
    bois, un navire amarré, des falaises en strates brunes à sommets verts, des palmiers.
  - L'eau est turquoise près de la côte et bleu sombre au large ; les ombres des nuages passent sur le décor.
- **Octopath Traveler II / HD-2D** : villes en diorama, flou de profondeur sur les bords de l'écran, flaques de lumière.
- **Assassin's Creed IV** : La Havane, Nassau, Kingston ; architecture plausible mais trop dense pour nous.

### 2.2 Architecture caribéenne et coloniale (XVIIe-XVIIIe siècle)

Trois « accents » qui peuvent servir à différencier les quartiers ou les îles :

1. **Espagnol (La Havane, Carthagène)**
   - Façades enduites et peintes, **balcons** en bois ou en fer, **volets** pleins ou à lames.
   - **Arcades** (*portales*) au rez-de-chaussée sur les places.
   - **Patios** entourés de galeries à colonnes et arcs.
   - Portes très hautes avec un petit guichet (*postigo*), plafonds en bois sculpté, styles mudéjar et baroque (églises).
   - Les places (plazas) et les promenades (prados) structurent la ville.
2. **Hollandais (Willemstad, Curaçao)**
   - Pignons à redents ou en « cou » sur la rue, **toits de tuiles très pentus**, maisons alignées sur l'eau.
   - Une palette vive « inconnue en métropole ».
   - Ajouts tropicaux : vérandas, porches, lambrequins découpés et volets.
3. **Anglais (Port Royal, Jamaïque)**
   - Ville dense de **maisons en brique** : la brique et la pierre arrivaient comme **lest dans les cales**, d'où les
     entrepôts de brique rouge sur le front de mer.
   - Un front de mer pavé de brique, avec des **quais privés derrière les maisons de marchands** (on accoste à la porte
     de l'entrepôt).
   - En 1692 : environ 6 500 habitants et 2 000 bâtiments (tavernes, entrepôts, belles maisons) sur 21 hectares.
     Chiffre d'un site touristique : [À VÉRIFIER].
   - Un tiers de la ville a glissé dans la mer au séisme de 1692 : idée de **quartier englouti** visible sous l'eau.

**Le vernaculaire**, partout :
- *Chattel houses* : petites maisons de bois d'une pièce, posées sur des pierres, avec quelques marches.
- Toits de bardeaux ou de chaume.
- Dentelle de bois découpée sur les façades (*gingerbread*, plus tardive).
- Fer forgé (influence française).

La logique commune est climatique : **l'ombre et la ventilation** (galeries, volets à lames, plafonds hauts, maisons
surélevées).

**Pour nous, en pratique**
- **Couleurs des façades** : enduits ocre, corail, turquoise, vert menthe, jaune paille, blanc cassé, toujours **délavés** ;
  menuiseries d'une couleur contrastée (volets verts sur ocre, bleus sur blanc).
- **Toits** : tuiles canal orange-rouge (accent espagnol), tuiles plates pentues (accent hollandais), bardeaux gris ou
  chaume (vernaculaire), tôle rouillée (bas quartiers).
- **Détails de façade** : balcon en bois sur consoles, volets entrouverts, auvent en toile, enseigne en fer pendue, pot de
  fleurs, linge, bougainvillier qui grimpe, lanterne murale, arcade au rez-de-chaussée.
- **Matériaux par richesse** : pierre de corail et brique (port, fort, église) → enduit peint (centre) → planches peintes
  (faubourgs) → planches brutes, tôle, morceaux d'épave (quartier pauvre).

### 2.3 Organisation d'une ville de port (de l'eau vers la colline)

1. **L'eau et les quais** :
   - quai de pierre avec bittes d'amarrage, anneaux et escaliers vers l'eau ;
   - pontons en bois sur pilotis pour les petits bateaux ;
   - une grue en bois (bigue) ou un palan.
2. **Le front de mer** :
   - entrepôts de brique aux grandes portes ;
   - capitainerie ou douane ;
   - **chantier naval** avec une coque sur cale.
3. **La place du marché**, juste derrière : étals sous auvents, tonneaux, cages à volailles, fontaine ou puits, crieur.
4. **La taverne** : à l'angle de la place et du port, grosse enseigne, terrasse, bruit, lumière la nuit.
5. **Les ruelles** :
   - elles montent en serpentant, avec des escaliers ;
   - des passages couverts relient les maisons d'un côté à l'autre ;
   - le linge est tendu entre les façades.
6. **Les repères verticaux** :
   - **église ou clocher** au point haut du centre ;
   - **fort ou batterie de canons** sur un promontoire ;
   - **phare** au bout de la jetée ou sur le cap (Dredge, Sail Forth : le phare est le repère la nuit).
7. **Les marges** :
   - quartier pauvre sur pilotis ou en épaves (Woodtick) ;
   - cimetière ;
   - chemin qui sort vers la jungle ou la plantation.

Règle de composition : alterner **plein** (ruelles, marché) et **vide** (place, quai, plage), comme le dit la bible.

### 2.4 Les îles

- **Typologies** (une silhouette signature par île) :
  - atoll plat à lagon ;
  - île à piton volcanique ;
  - île à falaises en strates ;
  - îlot rocheux avec épave ;
  - mangrove (Dredge en a une très réussie, vue : racines en arches, brume ocre, eau brune) ;
  - île morte.
- **La plage en bandes** :
  - eau profonde, puis eau turquoise sur le sable immergé ;
  - un liseré d'écume, du sable mouillé plus foncé, puis du sable sec clair ;
  - une laisse de mer (algues, bois flotté, coquillages) ;
  - de l'herbe rase, puis la végétation.
  - Ce dégradé suffit à rendre une côte belle à 640x360.
- **Palmiers** :
  - troncs **courbés vers la mer**, en groupes de 2 ou 3 de hauteurs différentes ;
  - noix de coco au pied, quelques palmes mortes brunes.
- **Végétation en couches** :
  1. au sol : herbe, fougères, plantes grasses ;
  2. buissons à grandes feuilles (bananiers, alocasias) ;
  3. palmiers et arbres moyens ;
  4. grands arbres (fromagers) ;
  5. lianes.
  - Les couches se chevauchent et **débordent sur les chemins et les ruines**.
- **Falaises** :
  - strates horizontales visibles, sommets herbus qui débordent (Sea of Stars, vu) ;
  - éboulis au pied, grottes marines.
- **Épaves** :
  - coque couchée sur le flanc, côtes de bois à nu, mât brisé ;
  - à moitié dans le sable, envahie d'algues et de crabes ;
  - parfois réutilisée en abri.
- **Ruines** :
  - tour de guet, fort espagnol effondré, chapelle sans toit ;
  - pierres moussues, racines qui fendent les murs ;
  - autel ou totem pour la touche fantastique.

---

## 3. Ambiance et vie : ce qui rend ces mondes vivants

| Famille | Exemples concrets | Références |
|---|---|---|
| **PNJ** | Horaires (marché le matin, taverne le soir), petits gestes en boucle (balayer, pêcher, réparer un filet, rouler un tonneau), 2 PNJ qui discutent | Wind Waker (Windfall), Sea of Thieves, A Short Hike |
| **Animaux** | Mouettes et frégates (sur les mâts, les bittes), perroquets, crabes qui fuient, chats sur les quais, chèvres et poules (Tchia modélise la poule locale), cochons, dauphins et poissons volants au large, tortues sur la plage | Tchia, Sea of Thieves, A Short Hike |
| **Mouvement** | Linge et drapeaux au vent (même direction que la flamme du bateau = le vent du jeu), palmes qui bougent, bateaux à quai qui tanguent, cordages qui se balancent | Sea of Thieves, Sail Forth |
| **Fumées** | Cheminées de la taverne et des maisons, forge, feu de camp sur la plage, poêle de la cale | Sea of Thieves (poêle ajouté sur le brigantin) |
| **Lumières** | Fenêtres jaunes le soir, lanternes de quai, phare qui tourne, feux de signalisation, lueur de forge | Dredge (fenêtre de cabine, phare), Monkey Island (nuit bleue, fenêtres jaunes), Octopath (flaques de lumière) |
| **Traces** | Caisses empilées, filets qui sèchent, tonneaux, cordages lovés, affiches « recherché », flaques, empreintes dans le sable | Eastward (rien n'est vide), Sea of Thieves (usé et réparé) |
| **Sons** | Grincement de coque et de poulies, clapot, cloche du bord, chants de marins, brouhaha de taverne, mouettes, ressac | AC IV (chants de l'équipage), Sea of Thieves |
| **Temps** | Ombres de nuages qui passent (Sea of Stars, vu), brume en couches à l'aube, rayons de soleil, pluie et éclairs | Eastward, Dredge, Sea of Stars |

Règle : **une source de vie à l'écran à tout moment**, même en pleine mer (oiseau, poisson, nuage, flamme qui bat).

---

## 4. Jeux récents (2023-2026) salués pour leurs graphismes, et ce qu'on leur emprunte

| Jeu (année) | Technique | À emprunter |
|---|---|---|
| **Octopath Traveler II** (2023), **Octopath Traveler 0** (4 déc. 2025) | HD-2D : décor 3D, sprites pixel, flou de profondeur, lumière dynamique. L'équipe visait des images « belles quelle que soit la capture » | (vu) Menus : panneau sombre translucide centré sur le jeu flouté, filets fins clairs, boutons en losange. Le flou de profondeur sur les bords de l'écran |
| **Dragon Quest III HD-2D** (14 nov. 2024), **Dragon Quest I & II HD-2D** (30 oct. 2025) | HD-2D adapté au style Toriyama ; palette proche de l'original ; nouveau : **villes au crépuscule**, chaque ville avec sa lumière et **ses propres drapeaux** | Une lumière et un drapeau par ville. Le crépuscule comme moment signature |
| **The Adventures of Elliot** (2026, date exacte [À VÉRIFIER]) | HD-2D en action-RPG, par l'équipe d'Octopath | La profondeur des cartes en 3D derrière des personnages 2D, en temps réel |
| **Sea of Stars** (2023) | Pixel art 2D avec **éclairage dynamique** (jour/nuit à volonté, travaillé dès 2018) ; la production des décors a été pensée autour de la lumière | (vu) Flaques de lumière chaude dans des décors violets, ville portuaire compacte en falaise, ombres de nuages. HUD minimal en bas à gauche (portrait, PV/PM) |
| **Cassette Beasts** (2023, Godot) | Monde 3D voxel + sprites 2D, caméra fixe, cartes pensées en 2D vue de dessus | Le pipeline le plus proche du nôtre : tuiles voxel → Godot, boucles concentriques autour de la ville |
| **Dredge** (2023) | Low-poly stylisé, brume par biome, portraits peints | (vu) HUD : arc jour/heure + boussole en haut au centre, 3 icônes en bas à gauche. La fenêtre éclairée, le phare |
| **Dave the Diver** (2023) | Personnages et poissons en pixel art, océan en modèles 3D | Le mélange assumé sprites + 3D, la mer comme personnage |
| **Eastward** (2021, toujours la référence pixel) | Décor pixel peint en 3D avec cartes de relief, brume en couches | (vu) Taches de lumière au sol, HUD cœurs + portrait en bas à gauche, végétation qui déborde |
| **Shipwrecked 64** (2024) | Faux jeu Nintendo 64 (horreur, île de naufrage) | Textures basse définition et couleurs par sommet, proches de notre rendu |
| **Project Shadowglass** (en développement), démos de **t3ssel8r** | 3D rendue comme du pixel art : contours d'un pixel « parfaits », reflet sur les arêtes convexes seulement, ombrage toon simple, herbe en couches (*shell texturing*) | Déjà dans la bible ; à appliquer au bateau : reflet d'arête sur le plat-bord, les vergues, les marches |
| **Draco and the Seven Scales** (2026), **TinyWind** (annoncé) | Pixel art pirate vu de dessus | À surveiller pour se démarquer (nous : 3D, coop, pont praticable) |

---

## 5. Pour conclure

### 5.1 Planche d'ambiance écrite

**Le bateau**
- Silhouette et livrée : **Sea of Thieves** (flottes de la page Steam : coques à bandes, voiles gonflées à emblème,
  longues flammes).
- Vie sur le pont : **Sea of Thieves**, pont du brigantin (mâts cerclés de fer, cordages qui pendent, lanternes sur le
  flanc).
- Usure et bancal plausible : talk GDC de **Ryan Stevenson** (usé, réparé, réalistement bancal).
- Lisibilité de dessus : **Dredge** (bateau en 3/4 plongeant, bandeau clair, défenses, fenêtre éclairée).
- Simplicité : **Sail Forth** (aplats) et le bateau low-poly de **3digitalis** (750 faces).
- Caractère : la tête sculptée du **Lion Rouge** (Wind Waker), et la fierté du **Jackdaw** qui s'améliore à vue (AC IV).

**La ville**
- Structure : avant-postes de **Sea of Thieves** (taverne nommée, verticalité) ; densité : **Eastward**.
- Port vu de haut : **Sea of Stars** (Brisk) et **Cassette Beasts** (quais, bittes, pontons).
- Architecture : **La Havane**, **Willemstad**, **Port Royal**.
- Repaire : **Woodtick** (Monkey Island 2) ; nuit : **Monkey Island** (bleu-violet, fenêtres jaunes).

**L'île**
- Falaises en strates : **Sea of Stars** ; une île, une silhouette : **A Short Hike**, Ancient Spire (Sea of Thieves).
- Mangrove et brume : **Dredge** ; faune locale : **Tchia** ; végétation qui déborde : **Eastward**.

**La lumière**
- Crépuscule signature, une lumière par ville : **Dragon Quest III HD-2D**.
- Flaques de lumière chaude dans le froid : **Sea of Stars**, **Octopath II** ; ombres de nuages : **Sea of Stars**.
- Brume par biome et phare : **Dredge** ; rayons et brume à l'aube : **Eastward**.

**L'interface**
- HUD minimal et diégétique : **Sea of Thieves** (carte sur la table de la cale, boussole en main).
- Indicateurs de navigation : **Dredge** (arc jour/heure + boussole en haut au centre).
- PV en bas à gauche avec portrait : **Sea of Stars**, **Eastward**.
- Menus sombres translucides, jeu flouté derrière, boutons en losange : **Octopath Traveler II**.
- Catalogue de comparaison : **Game UI Database**.

### 5.2 Quinze détails pour notre brigantin, par ordre d'impact visuel

1. **La flamme et le pavillon** : longue flamme animée en tête de grand mât (3 à 4 m) et pavillon au bout de la corne.
   Ils montrent le vent et c'est le signe « pirate » le plus visible de loin.
2. **La poupe haute et ses fenêtres éclairées** : gaillard d'arrière surélevé, 3 à 5 fenêtres à petits carreaux jaunes la
   nuit, lanterne de poupe.
3. **Les voiles gonflées à deux tons** : misaine, hunier et perroquet carrés à l'avant, grand-voile aurique à l'arrière,
   coutures verticales, une rustine, et un emblème d'équipage peint sur une voile.
4. **La coque à bandes** : bois sombre + une préceinte de couleur (rouge ou turquoise) + filet doré, tonture exagérée
   (pont qui remonte aux deux bouts).
5. **La figure de proue** sur un éperon, dépassant nettement de la silhouette, avec un beaupré relevé et deux focs.
6. **Le contraste pont clair / plat-bord sombre** : pavois à hauteur de hanche avec un liseré foncé, planches dans la
   longueur, quelques planches neuves plus claires.
7. **Les lanternes** : 3 sur le pont, 1 au nid de pie, accrochées aux mâts et au flanc, avec halo et bloom la nuit.
8. **Les haubans et enfléchures en V** de chaque côté des mâts, en lignes d'un pixel ; drisses qui pendent en courbe.
9. **Les mâts cerclés de fer** et légèrement penchés vers l'arrière, avec une hune à mi-hauteur et le **nid de pie** en
   haut du grand mât.
10. **Les canons sur affûts rouges** (3 par bord) avec boulets en pyramide, écouvillon et seau, et sabords peints sur le
    flanc visible.
11. **Le caillebotis** (écoutille en grille) au milieu du pont : il annonce la cale et fait « navire » en un motif.
12. **La barre** : roue à poignées sur sa colonne, compas à côté, devant la cabine.
13. **Le cabestan et l'ancre** : cabestan à barres à l'avant, ancre pendue au bossoir sur le flanc, chaîne ou câble qui
    descend dans l'écubier.
14. **La vie à bord** :
    - cordages lovés, tonneau de grog, caisses arrimées sous un filet ;
    - **mouette posée sur une vergue** ;
    - canot retourné ou suspendu à la poupe ;
    - poêle qui fume par un tuyau sur le pont.
15. **L'usure** :
    - écailles de peinture sur les arêtes ;
    - coulures sombres sous les dalots et les ferrures ;
    - échelle de coque en bois usée, avec des algues et des coquillages au ras de l'eau.

---

## Sources

**Navires**
- Sea of Thieves, conférence GDC 2018 « Visual Adventures on Sea of Thieves » : https://gdcvault.com/play/1025015/Visual-Adventures-on-Sea-of ; vidéo : https://www.youtube.com/watch?v=BzppoQTG3m0
- Résumé 80.lv du talk : https://80.lv/articles/gdc18-visual-adventures-on-sea-of-thieves
- Règles « wonky », usé et réparé (blog Habrador) : https://blog.habrador.com/2018/08/stylized-graphics-fortnite-sea-of-thieves.html
- Craig Duncan et Ted Timmins sur les navires (GamesBeat) : https://gamesbeat.com/how-microsofts-rare-imagined-the-pirate-world-of-sea-of-thieves/
- Article de fond sur l'esthétique de Sea of Thieves (Fandom) : https://www.fandom.com/articles/sea-of-thieves-amazing-visuals
- SIGGRAPH 2018, « The Technical Art of Sea of Thieves » : https://history.siggraph.org/wp-content/uploads/2022/09/2018-Talks-Ang_The-Technical-Art-of-Sea-of-Thieves.pdf
- Brigantin de Sea of Thieves (wiki) : https://seaofthieves.wiki.gg/wiki/Brigantine
- Captures Sea of Thieves (Steam) : https://store.steampowered.com/app/1172620/
- AC IV, le Jackdaw est un brigantin (GamesBeat) : https://gamesbeat.com/ubisoft-40-percent-of-assassins-creed-iv-is-naval-missions/
- AC IV, interview Jean-Sébastien Decant : https://www.thesixthaxis.com/2013/09/30/interview-talking-to-the-high-seas-of-ac-iv-with-jean-sebastien-decant/
- Skull and Bones, GDC 2023 (Andie Sulistio) : https://gdcvault.com/play/1028938/An-Uncharted-Sea-Developing-the
- Skull and Bones, construction des navires (Jewell Koh) : https://gdcvault.com/play/1028934/All-Hands-On-Deck-Building
- Sail Forth (Steam) : https://store.steampowered.com/app/1031460/Sail_Forth/ ; interview David Evans : https://www.trueachievements.com/n48178/sail-forth
- Dredge, Unity : https://unity.com/resources/crafting-dredge-cozy-atmospheric-horror ; Steam : https://store.steampowered.com/app/1562430/DREDGE/
- Return to Monkey Island, Rex Crowle (GamesBeat) : https://gamesbeat.com/return-to-monkey-islands-art-director-talks-inspirations-and-expectations ; Ron Gilbert défend le style : https://www.videogamer.com/news/return-to-monkey-island-director-defends-its-art-style
- Windbound (interview) : https://segmentnext.com/2020/06/03/windbound-interview/
- Blackwake (PC Gamer) : https://pcgamer.com/blackwakes-pirate-deathmatches-are-great-multiplayer
- Raft (NME) : https://www.nme.com/features/raft-is-a-quietly-brilliant-survival-game-3119396
- Shipwrecked 64 (Steam) : https://store.steampowered.com/app/2160220/Shipwrecked_64/
- Tchia (LNC) : https://www.lnc.nc/article/nouvelle-caledonie/culture/tchia-un-jeu-video-sur-le-caillou-cree-par-des-caledoniens
- Brigantin (définition) : https://en.wikipedia.org/wiki/Brigantine
- Modèles stylisés : https://sketchfab.com/3d-models/stylized-pirate-ship-1c62191534174bf7a67470fb02b97db1 ; https://3digitalis.itch.io/stylizedpirateship ; https://www.cgtrader.com/3d-models/watercraft/historic-watercraft/stylized-pirate-brigantine-ship-3d-model-3d-model
- Pixel art : https://krishna-palacio.itch.io/minifantasy-ships-and-docks ; https://opengameart.org/content/black-sail-ship-bleeds-game-art ; https://maxparata.itch.io/isometricpirates-monogon ; https://theretrorealms.itch.io/n64-style-retro-pirate-isles

**Villes et îles**
- Avant-postes Sea of Thieves : https://seaofthieves.wiki.gg/wiki/Sanctuary_Outpost ; https://seaofthieves.wiki.gg/wiki/Ancient_Spire_Outpost ; https://seaofthieves.fandom.com/wiki/Port_Merrick
- Eastward (Game Developer) : https://www.gamedeveloper.com/art/eastward-s-creators-share-insights-on-making-pixel-art-adventures ; Steam : https://store.steampowered.com/app/977880/
- A Short Hike (blog PlayStation) : https://blog.playstation.com/2021/08/05/crafting-a-tiny-open-world-a-look-behind-the-scenes-at-the-creation-of-a-short-hike/
- Cassette Beasts (vitrine Godot) : https://godotengine.org/article/godot-showcase-cassette-beasts/ ; Steam : https://store.steampowered.com/app/1321440/
- Sea of Stars (Steam) : https://store.steampowered.com/app/1244090/ ; éclairage dynamique (MobileSyrup) : https://mobilesyrup.com/2023/09/11/sea-of-stars-level-design-sabotage-studio-thierry-boulanger-interview/
- Wind Waker, philosophie des îles : https://www.gamedeveloper.com/design/the-philosophy-of-the-wind-waker-part-one
- Architecture de Willemstad : https://www.curacao.com/de/article/dutch-caribbean-architecture
- Architecture caribéenne et climat : https://insightguides.com/inspire-me/blog/caribbean-architecture
- La Havane : https://thirdeyemom.com/2014/04/13/a-brief-look-at-old-havanas-glorious-architecture/ ; https://www.sah.org/publications/sah-blog/sah-blog/2017/02/13/prados-and-plazas-investigations-into-the-cultural-resources-and-key-urban-elements-of-the-island
- Port Royal : https://en.wikipedia.org/wiki/Port_Royal ; https://whc.unesco.org/ES/list/1595 ; https://www.icomos.org/public/risk/2006/17hamilton2006an.pdf ; https://jamaicaportroyal.com/wealth.html

**Jeux récents et rendu**
- Octopath Traveler II (Nintendo Life) : https://www.nintendolife.com/news/2022/10/octopath-traveler-ii-devs-aimed-to-make-its-hd-2d-visuals-picture-perfect ; Steam : https://store.steampowered.com/app/1971650/
- Octopath Traveler 0 : https://www.videogameschronicle.com/news/square-enix-announces-octopath-traveler-0-coming-to-switch-and-switch-2-this-december
- Dragon Quest III HD-2D (blog PlayStation) : https://blog.playstation.com/2024/11/08/dragon-quest-iii-hd-2d-remake-interview-how-the-classic-rpg-was-revamped-for-its-ps5-debut/ ; Gamescom : https://www.gamesradar.com/games/dragon-quest/dragon-quest-3-hd-2d-remake-may-have-never-happened-without-its-gorgeous-pixel-art-and-after-playing-for-30-minutes-i-can-see-why
- Dragon Quest I & II HD-2D : https://www.siliconera.com/dragon-quest-1-and-2-hd-2d-remake-release-date-set/
- The Adventures of Elliot : https://www.techradar.com/gaming/nintendo/two-square-enix-rpgs-have-been-announced-for-nintendo-switch-2-including-the-next-entry-in-the-octopath-traveler-series
- Dave the Diver : https://gameworldobserver.com/2023/12/04/dave-the-diver-unity-2d-3d-graphics-optimization-mintrocket
- t3ssel8r et rendu 3D pixel (David Holland) : https://davidholland.netlify.app/articles/3d-pixel-art-rendering
- Draco and the Seven Scales : https://www.timeextension.com/news/2026/09/after-years-of-development-the-pirate-themed-zelda-like-draco-and-the-seven-scales-has-set-sail-on-steam-and-itch
- HD-2D (définition) : https://en.wikipedia.org/wiki/HD-2D

**Interface**
- Game UI Database : https://www.gameuidatabase.com
- Carte diégétique de Sea of Thieves : https://www.galaxus.ch/en/page/die-minimap-muss-weg-30543 ; boussole : https://seaofthieves.wiki.gg/wiki/Compasses

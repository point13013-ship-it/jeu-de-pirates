# Direction artistique et level design : base de connaissances

> Recherche du 12/11/2026. Les **principes** (livres, conférences, jeux de référence) **appliqués à notre jeu**, en complément
> de `design/bible-direction-artistique.md`, qui reste le document de décision. Rien n'est appliqué sans validation.
> Les numéros entre crochets renvoient aux sources ; « Pour nous » signale notre interprétation.

---

## 1. Les fondamentaux de la direction artistique

### 1.1 Une direction artistique, c'est un petit nombre de règles appliquées partout

Le message le plus constant des directeurs artistiques est le même : une identité ne naît pas d'un bel écran, mais de
**quelques règles simples appliquées à tout**.

- **Sea of Thieves** : Ryan Stevenson (Rare) a résumé son talk GDC 2018 ainsi : « quelques règles simples » qui imprègnent tous
  les aspects des visuels créent un look stylisé unique [1]. Les règles connues publiquement :
  - un style « intemporel », qui ne dépend pas de la dernière technologie [2] ;
  - tout est « un peu de guingois » (*wonky*) : les bateaux sont « un peu tordus, un peu courbés », les tonneaux ont un aspect
    rugueux [3][4] ;
  - partir d'une base réaliste pour la physique (l'eau se comporte comme de l'eau) et styliser par-dessus. L'écume est un masque
    adouci mélangé à des textures peintes à la main [5].
- **Breath of the Wild** : Satoru Takizawa a choisi le style de Wind Waker parce qu'il « garantit la jouabilité sous tous les
  aspects, y compris la visibilité et l'action », et voulait une image qui « suggère intuitivement » la physique du jeu [6].
- **Hades** : Jen Zee (Supergiant) tient les idées d'art pour « jetables » tant que le gameplay n'est pas solide. L'encre a
  remplacé la peinture parce qu'elle « va beaucoup plus vite », et un *color script* de tout le jeu a servi à repérer les
  creux du rythme [7].
- **Firewatch** : Jane Ng (GDC 2015) part d'une seule affiche d'Olly Moss : formes simplifiées, contours lisibles, couleurs en
  plans successifs, et « embrasse tes limites » [8].

**Pour nous** : nos règles doivent tenir sur une fiche (§ 7) et se vérifier sur une capture.

### 1.2 Les piliers visuels

Un pilier est une **intention** en deux ou trois mots qui sert à trancher : un asset doit servir au moins un pilier sans en
trahir un autre. Les bons piliers sont **peu nombreux** (3 à 5), **en tension** (« luxuriant » et « lisible » se surveillent)
et **reliés au gameplay**, comme BotW avec la physique [6] ou Hades avec le combat [7].

### 1.3 Le langage des formes (*shape language*)

C'est la convention la plus partagée de l'animation et du jeu vidéo :

| Forme | Ce qu'elle évoque | Exemples |
|---|---|---|
| Rond, courbe | amical, sûr, doux | personnages bienveillants, refuges |
| Carré, rectangle | stable, solide, institutionnel | forts, entrepôts, autorité |
| Triangle, pointe | danger, dynamisme, agressivité | ennemis, pièges, récifs |

- La règle d'or : **si la lisibilité dépend de la couleur ou de la texture, la structure des formes n'est pas assez forte** [9].
- Overwatch voulait chaque héros « immédiatement identifiable au milieu d'une bataille » et refusait toute silhouette trop
  proche d'un héros existant [10]. Riot traite aussi la silhouette comme un critère de clarté [11].

### 1.4 Hiérarchie visuelle, valeurs et « lecture » d'un écran

- **La valeur (clair/sombre) passe avant la teinte.** Riot simplifie « les formes et les valeurs » pour que la lecture soit
  facile partout sur la carte. Les plans y sont empilés dans un ordre fixe : fond, personnages, effets, interface [11].
- **Les effets aussi ont un budget.** Le guide VFX de Riot vise la clarté du gameplay et le minimum de bruit visuel, en jouant
  sur cinq leviers : gameplay, valeur, couleur, forme, rythme [12].
- **Lire en un coup d'œil**, c'est savoir en moins d'une seconde où je suis, où est le danger, où je peux aller. On le vérifie
  en niveaux de gris, en flou (« plisser les yeux ») et en vignette.
- **Plans et profondeur** : Hollow Knight donne au plan de jeu le plus de contraste et les contours les plus épais ; les
  dangers sont plus clairs que le décor, l'avant-plan passe en silhouette sombre [13].
- **La lumière lit l'espace** : Sable a ajouté des ombres « aussi souvent que possible » pour situer les objets sur les
  surfaces ; la brume lointaine a eu le plus gros impact, et les contours s'estompent avec la distance [14].

### 1.5 La cohérence

La cohérence, c'est **une seule grammaire** : même taille de pixel, même lumière, mêmes contours, mêmes proportions, même
palette ; Saint11 y consacre un tutoriel quand on mélange le pixel art à d'autres techniques [15]. Les jeux critiqués pour
leurs visuels le sont rarement pour un manque de beauté, plutôt pour l'incohérence ou le vide (§ 6).

### 1.6 Comment ces jeux ont construit leur identité

| Jeu | La « patte » en une phrase | Leçon pour nous |
|---|---|---|
| **Hades** | Encre noire épaisse, couleurs saturées par dieu, lisibilité totale en combat | Une couleur par faction ou par pouvoir ; le style suit le gameplay [7] |
| **Sea of Thieves** | Monde « de guingois », peint, intemporel ; mer et ciel comme vedettes | Rien de droit ; l'eau doit rester de l'eau [1-5] |
| **Wind Waker / BotW** | Formes simples, lisibles de loin, qui suggèrent la physique | Lisibilité avant réalisme ; le relief guide [6][16] |
| **Eastward** | Pixel art dense peint à la main, éclairé en 3D (cartes de relief peintes), brume et rayons de soleil | Le détail et la lumière chaude font le « luxuriant » [17] |
| **Tunic** | Caméra orthographique en 3/4, lumière rebondie, renard orange dans un monde vert | Ce que la caméra cache est un outil ; le héros est l'accent complémentaire du décor [18][19] |
| **Dredge** | Low-poly net, jour ouvert et nuit fermée par le brouillard, silence nocturne | Le contraste jour/nuit est un design ; une petite rampe de couleurs par biome [20][21] |
| **Sable** | Aplats façon Moebius, lignes, brume par biome | Ombres, brume et contours qui s'estompent font la profondeur [14] |
| **Hollow Knight** | Palette presque monochrome par zone, trois plans, silhouettes | Un thème de couleur par zone ; le plan de jeu concentre le contraste [13] |
| **A Short Hike** | 3D rendue en basse résolution, agrandie sans lissage | La basse résolution rend le monde « luxuriant » : l'imagination complète [22] |

### 1.7 Livres, cours et conférences de référence

- **James Gurney, *Color and Light* (2010)** : distinguer couleur locale et couleur de la lumière ; penser en températures
  (lumière chaude, ombre froide) ; perspective atmosphérique (au loin, les valeurs se resserrent vers la couleur du ciel) ; et
  le **masque de gamut** : une forme posée sur la roue chromatique, on ne peint qu'avec ce qu'elle contient [23][24].
- **Jesse Schell, *The Art of Game Design*** : ses « lentilles » rappellent que chaque élément visuel sert l'expérience visée.
- **Celia Hodent, *The Gamer's Brain* (2017)** : attention et mémoire sont limitées ; ses piliers d'utilisabilité comptent les
  *signes et retours* et la charge cognitive [25].
- **The Level Design Book** (gratuit, en ligne) [26][27][28], **Kevin Lynch, *The Image of the City*** [29],
  **Christopher Alexander, *A Pattern Language*** [30], **Francis Ching, *Architecture : Form, Space and Order***,
  **Christopher Totten, *An Architectural Approach to Level Design*** : détails au § 4.
- **Conférences GDC** : Stevenson, Sea of Thieves (2018) [1] ; BotW (2017) [6] ; Jane Ng, Firewatch (2015) [8] ; Smith et
  Worch, « What Happened Here? » (2010) [31] ; Miriam Bellard, « Environment Design as Spatial Cinematography » (2019) et
  Jim Brown, « The Importance of Nothing » (2014), tous deux cités par [26].

---

## 2. Construire une palette

### 2.1 Les méthodes concrètes

1. **Palette limitée** : moins de couleurs, plus de cohérence. Lospec recense des milliers de palettes, classées par taille et
   par étiquettes (dont « hue shift »), pour étudier des rampes qui marchent [32].
2. **Rampes à décalage de teinte** (méthode Slynyrd [33]) :
   - 9 tons par rampe, ordonnés par luminosité ;
   - décalage de **20° de teinte au plus** d'un ton à l'autre : en montant vers la lumière, on glisse vers le jaune (« des
     couleurs plus naturelles ») ;
   - **saturation maximale au milieu**, jamais à 0 % ni à 100 % ; les sombres restent plutôt saturés ;
   - écarts de luminosité plus serrés vers le blanc, pour un contraste égal entre voisins ;
   - des gris « naturels » obtenus en désaturant une rampe ;
   - à retenir : un décalage de 15 à 25° paraît naturel, au-delà de 30° le rendu devient très stylisé [34].
3. **Couleurs d'accent réservées.** On réserve une ou deux teintes saturées à un **sens** (danger, trésor, magie). Le Level
   Design Book le recommande explicitement : « réserver des couleurs à des significations précises » [28].
4. **Palettes par biome, par heure et par météo** : Dredge partage de petites textures de dégradé (64x64 ou 128x128) entre
   bâtiments et créatures d'un même biome [20] ; Hollow Knight donne une dominante à chaque zone [13] ; Firewatch associe un
   *color script* aux moments clés et laisse le ciel piloter la couleur de l'écran [8].
5. **LUT** : Godot 4 accepte une LUT 3D (Texture3D) ou un dégradé 1D dans `Environment.adjustment_color_correction`, appliquée
   après le tonemapping [35][36]. **Pour nous** : la LUT d'ambiance s'applique **avant** la quantification vers la palette
   maître, sinon elle détruit la palette (c'est déjà le plan de la bible).
6. **Masque de gamut** (Gurney) : un masque par ambiance, par exemple un triangle orange, rose et bleu pour le crépuscule
   [23] ; Krita les intègre à son sélecteur [24].

### 2.2 Les outils

| Outil | Usage |
|---|---|
| **Lospec** (lospec.com/palette-list) | étudier et exporter des palettes (.hex, .png) [32] |
| **Coolors** (coolors.co) | générer et ajuster des harmonies, vérifier un contraste [37] |
| **Adobe Color** (color.adobe.com) | roue chromatique, harmonies, extraire une palette d'une image |
| **Aseprite** | peindre les sprites et les rampes, gérer la palette en .png |
| **Color Oracle** (colororacle.org) | simulateur de daltonisme gratuit, plein écran, en temps réel (Windows, Mac, Linux) [38] |
| **Krita** | masques de gamut [24] |

### 2.3 Vérifier une palette et un écran

- **Niveaux de gris.** Désaturer l'écran entier : le joueur, les dangers et les objets utiles doivent rester lisibles. Si ce
  n'est pas le cas, le problème vient de la valeur, pas de la teinte.
- **Daltonisme** (environ 8 % des hommes d'origine européenne) :
  - **aucune information essentielle ne passe par la couleur seule** (*Game Accessibility Guidelines* [39]) ; sinon, laisser le
    joueur choisir ses couleurs (Xbox [40]) ;
  - l'IGDA déconseille les filtres plein écran et préfère doubler la couleur par une forme ou un symbole [41] ;
  - pour les couleurs d'équipe, partir de la palette Okabe-Ito, conçue pour les daltoniens (#E69F00, #56B4E9, #009E73,
    #F0E442, #0072B2, #D55E00, #CC79A7) [42].
- **Contraste d'interface** : viser les ratios WCAG (4,5:1 pour le texte normal) avec le vérificateur de Coolors ou de WebAIM [37].

### 2.4 Méthode pas à pas pour notre jeu

1. **Planche d'ambiance** : 6 images clés (port à midi, port au coucher, mer ouverte, île tropicale, île maudite la nuit,
   tempête), où l'on cherche d'abord les **masses de valeurs**.
2. **Script de valeurs** : chaque image en 3 à 5 gris ; le plan de jeu reste dans les valeurs moyennes.
3. **Rampes maîtres** (§ 7.3), méthode Slynyrd : ombres vers le bleu-violet, lumières vers le jaune, saturation au milieu.
4. **Couleurs réservées** (danger, trésor, magie, 4 équipages), absentes du décor.
5. **Sous-palettes de biome** piochées dans la palette maître : dominante 60 %, secondaire 30 %, accent 10 %.
6. **6 LUT au plus** (aube, midi, heure dorée, nuit, tempête, brume), appliquées avant la quantification et testées sur les
   6 images clés.
7. **Contrôles** pour chaque LUT : niveaux de gris, Color Oracle, vignette à 25 %.
8. **Gel** : palette versionnée (`palette_v1.png`, `.hex`) ; toute nouvelle couleur demande une justification écrite.

---

## 3. Pixel art en vue 3/4 : les fondamentaux

### 3.1 Les auteurs de référence et ce qu'ils enseignent

- **Pedro Medeiros (Saint11)**, *Celeste*, *TowerFall* : tutoriels courts (512x512) des bases à l'animation, plus des notes
  sur la très basse résolution, le mélange des styles, la 3D comme référence et l'agrandissement par facteurs entiers [15].
- **Slynyrd (Raymond Schlitter)**, *Pixelblog* : palettes à décalage de teinte (§ 2.1), sprites vus de dessus, tuiles,
  isométrie [33].
- **Brandon James Greer** et **MortMort** (chaînes YouTube) : pédagogie de la lisibilité (*clusters* propres, pas de pixels
  orphelins, valeurs avant couleurs, sprites testés à l'échelle 1).
- **Michael Azzi, *Pixel Logic*** : un livre visuel organisé en chapitres (trait, anticrénelage, couleurs, **lisibilité**,
  tramage), avec les défauts classiques : *banding* (alignements qui créent de fausses lignes), *pillow shading* (ombrage en
  coussin qui suit le contour), « jaggies » (escaliers irréguliers) [43].
- **Lospec, articles sur les contours** [44][45] :
  - un contour doit toujours **augmenter** le contraste, jamais le réduire ;
  - le contour extérieur sépare l'objet du fond ;
  - pas de contour au contact du sol, sinon l'objet flotte ;
  - « selout » (contour sélectif) : un contour plus sombre là où le sprite est sombre, plus clair là où il est clair, en
    tenant compte du fond.
- **Pixel Parmesan** : garder l'anticrénelage **à l'intérieur** du sprite. Sur le bord extérieur, il nuit à la lisibilité
  quand le fond change [46].

### 3.2 Le rendu « pixel art en 3D »

- **t3ssel8r** a popularisé le style : rendu basse résolution, caméra orthographique accrochée à la grille des texels, contours
  d'un pixel, **reflets uniquement sur les arêtes convexes** [47].
- **David Holland** l'a reproduit dans Godot [48] : caméra accrochée à une grille de la taille d'un texel puis image décalée en
  espace écran pour un mouvement fluide ; contours sur la profondeur (silhouettes) et les normales (reflets) ; bruit sur les
  normales contre le scintillement des ombres ; herbe en quads face caméra ; ombres de nuages ; particules 2D (Pixel Composer).
- **A Short Hike** : rendu dans une texture réduite, agrandie sans lissage. Pour Adam Robinson-Yu, le monde paraît plus
  luxuriant et les assets demandent moins de détail [22].

### 3.3 Faire lire un sprite 48x64 sur un décor 3D

**Pour nous**, à partir des sources ci-dessus :

1. **Même taille de pixel** : le décor 3D et les sprites ont la même densité de texels à l'écran. Jamais de sprite agrandi d'un
   facteur non entier (Saint11 [15]).
2. **Le décor est plus calme que le personnage** [13][28] : sols et murs en valeurs moyennes, avec deux ou trois tons voisins ;
   les sprites ont un contour sombre teinté, un reflet clair, et au moins **deux paliers de valeur d'écart** avec le sol.
3. **Ombre de contact.** Une ombre portée dans la direction du soleil ancre le sprite dans le décor 3D, sans contour au contact
   du sol [44].
4. **Silhouette de dos et de profil.** En vue plongeante à 40°, on voit beaucoup le haut des têtes et des épaules. Les signes
   distinctifs (chapeau, foulard, plume, couleur d'équipage) doivent se lire **d'en haut**.
5. **Échelle** : un sprite de 64 px sur une image de 360 px fait environ 18 % de la hauteur d'écran. Portes, fenêtres et
   marches doivent suivre, sinon la ville paraîtra en maquette. Eastward conseille un monde « plus grand que le joueur », qui
   paraît habité et chargé d'histoire [17].
6. **Occlusion** : la caméra fixe ne doit **jamais cacher le joueur sans le vouloir** ; Eastward joue sur la verticalité et
   les escaliers [17]. Chez nous : toits et feuillages qui s'effacent en tramage, silhouette de l'équipage à travers les murs.

---

## 4. Level design et environnement vus de dessus

### 4.1 Composition : ce qui marche, ce qui est un mythe

Le Level Design Book distingue la composition **spatiale** (l'agencement des masses en 3D, qui doit tenir sous tous les angles)
de la composition **de plan** (une image fixe). Il insiste : « le joueur ne joue jamais ta capture d'écran » [26].

- La **hiérarchie** naît du contraste local (hauteur, densité, orientation, forme) : une tour parmi des maisons basses, un
  rond parmi des rectangles, une place ouverte entourée de rues étroites [26].
- Un **repère** est une forme unique et mémorable, *utile* à l'orientation ; un décor de fond qui n'aide pas à s'orienter
  n'en est pas un [26].
- Une **vista** donne un aperçu de la zone suivante, l'**approche** est le chemin qui y mène [26].
- Les **lignes directrices** sont surestimées : les joueurs regardent ailleurs, il vaut mieux tester [26].

**Pour nous** : avec un cadrage imposé, la composition de plan compte plus qu'à la première personne ; mais en mer, les
repères se jouent à l'échelle de la carte.

### 4.2 Repères, gravité et révélation progressive (BotW)

Les principes du level design de terrain de BotW (conférence CEDEC 2017) [16] :

- **La règle du triangle** : une colline ou un rocher pose un choix (par-dessus ou autour) et masque ce qui est derrière, d'où
  la curiosité. Les grands triangles sont des repères, les moyens masquent la vue, les petits règlent le tempo. Les rectangles,
  eux, cachent complètement.
- **La gravité** : des tours régulièrement espacées rendaient le jeu linéaire. Des structures de visibilité et d'importance
  variées « tirent » le joueur dans plusieurs directions et lui donnent envie de dévier.
- **La révélation en chaîne** : une colline, puis un pont, puis la tour qu'il cachait.

**Pour nous** : chaque île est un grand triangle à silhouette signature ; rochers, épaves et bouées sont les moyens ; récifs et
hauts-fonds les petits. Depuis le quai, au moins **trois attracteurs** de visibilité différente (fumée sur une île, épave
échouée, éclat d'un phare).

### 4.3 Orientation et « miettes de pain »

Le Level Design Book [27] :

- **La carte mentale** s'appuie sur les cinq éléments de Lynch : chemins, limites, quartiers, nœuds, repères [29].
- **Échelle de certitude** des aides, à doser au playtest en partant du plus subtil : repère haut (environ 35 %), lumière et
  contraste de couleur (environ 40 %), panneaux (environ 40 %), miettes de pain, c'est-à-dire des objets ramassables alignés
  (environ 80 %), murs pleins (95 à 98 %).
- **L'« architecture de réassurance »** (balisage lourd) convient à un parc d'attractions, pas à une île sauvage.
- Les joueurs regardent rarement en l'air, regardent là où ils vont, et remarquent les contrastes de couleur, de forme, de
  lumière et le **mouvement**. Les *weenies* (terme de Disney) sont des objets désirables visibles de loin.

**Pour nous** : sur les îles, pièces, coquillages, empreintes et cordages tendus ; en ville, lanternes le long de la rue
principale, enseignes et linge tendu ; en mer, mouettes, débris flottants et fumée.

### 4.4 La narration environnementale

Pour Harvey Smith et Matthias Worch (GDC 2010), le joueur **interprète** et reconstitue « ce qui s'est passé ici » : les
éléments forment une image d'ensemble tout en gardant chacun un sens, et renvoient à la prémisse du monde [31]. Les objets
« héros » donnent leur identité aux lieux, mais leur abus les dilue [28].

**Pour nous**, quelques vignettes : un campement abandonné avec une carte déchirée, un squelette qui serre un coffre vide, des
traces de canonnade sur une falaise, le quai de la marine opposé au quai des contrebandiers.

### 4.5 La ville portuaire coloniale

**Le modèle historique** : les ordonnances espagnoles de 1573 (*Lois des Indes*) placent la place principale d'une ville
côtière **au débarcadère du port**, rectangulaire, avec des rues droites en grille ; les dimensions souvent citées (environ
600 x 400 pieds) sont un idéal rarement respecté [49]. Les ports anglais, français et hollandais sont plus organiques : front
de mer continu, entrepôts, rues perpendiculaires au quai qui montent vers la colline.

**Les patrons d'Alexander** [30] : une place trop grande se vide, il la veut bien plus petite qu'on ne l'imagine (de l'ordre
de 15 à 20 m), et sa vie se fait **sur ses bords**, grâce à des **poches d'activité** semi-fermées (étal, banc, terrasse,
puits) qui avancent dans l'espace ouvert.

**La lecture de Lynch appliquée au port** [29][50] :

| Élément de Lynch | Dans notre port |
|---|---|
| Chemins | rue principale qui serpente du quai à l'église ou au fort ; contre-allées ; ruelles |
| Limites | front de mer, rempart, lisière de la jungle |
| Quartiers | quais et entrepôts, marché, quartier résidentiel aux façades pastel, colline des notables, bidonville de pêcheurs |
| Nœuds | place du débarcadère, marché, taverne, chantier naval |
| Repères | phare (vu de la mer), clocher (vu de la ville), fort (vu des deux) |

Brian Upton résume : les nœuds sont les lieux où l'on s'arrête et où l'on décide [50].

**Règles de placement, pour nous** :
1. **Le quai d'abord** : la place du débarcadère est le nœud principal, les rues en partent en éventail et montent.
2. **Une grille déformée, pas un labyrinthe** : les rues suivent le relief et se coudent, les îlots sont inégaux, les façades
   décalées de 0,5 à 1 m.
3. **Trois largeurs** : rue principale (4 joueurs de front), contre-allées, ruelles d'un seul personnage.
4. **Places petites et vivantes** : poches d'activité sur les bords, centre dégagé (fontaine, arbre).
5. **Les jardins dans les creux** : arrière-cours, potagers, verdure qui déborde des murs et adoucit les angles.
6. **Quais en couches** : eau, pieux et algues, quai de pierre, bande de travail (caisses, filets, grues), façades.
7. **Une ligne de toits variée** (hauteurs, pentes, tuiles, bardeaux, tôle rouillée) : c'est ce que la caméra montre le plus.

### 4.6 Les îles

- **Silhouette** : chaque île se reconnaît à sa forme (pic, arche, cratère, épave, phare) depuis la mer. C'est le triangle
  géant de BotW [16].
- **Zonage concentrique** : récif et haut-fond, plage, lisière, cœur (jungle, ruines, grotte), point haut (vue sur les îles
  voisines). L'approche (§ 4.1) part de la plage et mène à la vista du sommet.
- **Une révélation par île** : un élément caché derrière un triangle moyen.
- **Un thème de couleur par type d'île** (§ 7.3), comme Hollow Knight par zone [13].

### 4.7 Densité, rythme et bruit visuel

- **Le détail s'additionne** : plus on en ajoute, plus la géométrie devient « bruitée », jusqu'à l'« illisible ». D'abord les
  masses, puis les détails, en passes successives. Le décor se place en **grappes** : un objet dupliqué, mis à l'échelle,
  tourné et décalé forme une composition « fractale » [28].
- **Pour nous**, des règles chiffrées à tester :
  - **grappes de 3 à 5 éléments**, de trois tailles (grand, moyen, petit), comme les trois échelles de triangles de BotW [16] ;
  - **rythme** : environ un tiers de surface calme (place, plage, mer libre), jamais deux zones denses collées ;
  - **gradient de détail** : dense le long des chemins et autour des points d'intérêt, sobre aux bords et au loin ;
  - **un seul objet « héros » par écran** ; le bruit fin (herbes, cailloux) reste en contraste faible.

### 4.8 Bordures et transitions entre matériaux

**Principe** : deux matériaux ne se touchent jamais par une arête nette. Il faut une bande de transition qui raconte le
contact. Le Level Design Book le formule ainsi : un matériau doit se lire comme tel, même de loin [28].

| Contact | Bande de transition (de l'un vers l'autre) |
|---|---|
| Eau / quai | écume, algues, pieux, mur taché par la marée, cordages |
| Eau / sable | écume, sable mouillé plus sombre, coquillages, bois flotté |
| Sable / herbe | touffes clairsemées, galets, herbe sèche plus jaune |
| Pavé / herbe | pavés disjoints, herbe dans les joints, fleurs au pied des murs |
| Mur / sol | soubassement plus sombre (saleté, humidité), plantes au pied, ombre de contact |
| Falaise / mer | éboulis, rochers noirs mouillés, embruns |

---

## 5. L'expérience utilisateur liée au visuel

### 5.1 Guider par la lumière et la couleur

- **Le débat de la « peinture jaune »** : le balisage peint aide les joueurs perdus mais casse l'immersion. Pour le responsable
  design de The Witcher 4, c'est une question de **crédibilité** : qui serait venu peindre une ligne jaune à cet endroit
  précis [51] ? L'alternative : la lumière et un décor qui guide, comme des entrées éclairées ou une porte bleue dans un
  paysage orange [27].
- **Pour nous**, un balisage **diégétique** : lanterne au-dessus des portes utiles, éclat doré sur ce qui se ramasse, mouette
  qui tourne au-dessus d'un trésor, fumée au-dessus d'un campement, cordages usés sur les prises d'escalade.

### 5.2 Signes d'interaction

- **Hodent** : un signe invite (« ici il se passe quelque chose »), un retour confirme (« c'est fait »). Bien placés, ils évitent
  le texte de tutoriel. Une information mal placée augmente la charge cognitive [25].
- **Pour nous**, un vocabulaire **constant** :

  | Objet | Signe |
  |---|---|
  | Objet interactif | reflet d'arête plus clair et léger scintillement doré, toutes les 3 s environ |
  | À portée | plaque de laiton avec la touche, au-dessus de l'objet (comme dans la bible) |
  | Action faite | son, petite secousse, particule |
  | Danger imminent | rouge réservé et forme triangulaire (zone d'impact, éclat d'yeux de squelette) |

### 5.3 Lisibilité en coopération (1 à 4 joueurs)

1. **Identité de chaque joueur** triplée : couleur d'équipage (foulard, fanion), **symbole** sur le fanion, nom. Jamais la
   couleur seule [39][41].
2. **Hiérarchie** : joueurs et ennemis au contraste maximal (les ennemis avec les formes et couleurs de danger), PNJ amis un
   cran en dessous.
3. **Budget des effets** à la manière de Riot [11][12] : effets alliés plus discrets que ceux des ennemis, et aucun effet ne
   cache un personnage plus de quelques images.
4. **Occlusion** : silhouette colorée à travers murs et voiles.
5. **Postes du bateau** (barre, canons, voiles, pompe) avec une forme et une icône stables, pour se répartir d'un mot.

### 5.4 Onboarding visuel

- **Le port est le tutoriel** : depuis le point d'apparition, on voit le bateau (le but), un chemin éclairé (lanternes, foule)
  et un repère lointain, une île à silhouette signature qui crée la « gravité » de BotW [16].
- **Montrer avant de dire** : un PNJ qui hisse une voile, un tonneau qui flotte, un squelette aperçu de loin le premier soir.
- **Le contraste jour/nuit de Dredge** : un jour sûr, une menace nocturne introduite peu à peu [20][21]. Bonne courbe pour nos
  squelettes et nos sirènes, avec un premier soir scénarisé où les lanternes du port s'allument et guident le retour.

---

## 6. Analyse des références maritimes et pirates

| Jeu | Ce qu'il met en place | Ce qui est salué | Ce qui est critiqué |
|---|---|---|---|
| **Sea of Thieves** (Rare, 2018) | Monde « de guingois » peint, eau simulée puis stylisée, mer et ciel comme vedettes | Prix du meilleur style artistique 2018 chez Shacknews [62] ; l'eau | (Pas sur le visuel) |
| **Dredge** (Black Salt, 2023) | Low-poly net, brouillard centré sur le joueur, jour ouvert et nuit fermée, une petite rampe de couleurs par biome, silence nocturne | Direction artistique et lumière [52] ; tension née de ce qu'on ne voit pas | — (low-poly choisi par manque de temps, devenu une force [20]) |
| **Sail Forth** (2022) | Style cartoon presque minimaliste, couleurs vives et pastel | Comparé à Wind Waker ; paysages « étonnamment beaux » [53] | Chutes de fluidité sur Switch |
| **Windbound** (2020) | Cel-shading à la Zelda | Style « plaisant » | « Manque de détail et de netteté », « boueux », trop emprunté à BotW [54] |
| **Return to Monkey Island** (2022) | Découpage papier anguleux (Rex Crowle) | Audace et cohérence, inspirée des palettes des épisodes 1 à 3 [55] | Rejet d'une partie des fans ; l'art souligne parfois des zones sans importance [56] |
| **Tchia** (Awaceb, 2023) | Couleurs très saturées de la Nouvelle-Calédonie, style « jouet », quelques formes de texture pour tous les effets [57] | Monde vivant, envie de monter sur les points hauts pour voir | Qualité inégale dans certaines zones du monde ouvert |
| **Shipwrecked 64** (2024) | Faux jeu N64 perdu, horreur derrière la naïveté | Cohérence totale de l'esthétique (95 % d'avis positifs sur Steam) [58] | — |
| **Ship of Fools** (Fika, 2022) | 2D dessinée à la main, coop à 2, créatures marines comiques | Détail, personnages reconnaissables [59] | Manque de variété des environnements |
| **Under the Waves** (Parallel, 2023) | 3D stylisée, années 70 alternatives, palette et grain de cinéma | Direction artistique saluée « malgré » une technique modeste [60] | Le gameplay ne suit pas l'image |
| **Skull and Bones** (Ubisoft, 2024) — contre-exemple | Réalisme spectaculaire | Panoramas | Monde « fade », PNJ robotiques qui répètent les mêmes gestes, peu de vie [61] |

**Les leçons qui reviennent** :
1. **L'intention pèse plus que la technique** : Under the Waves et Shipwrecked 64 sont salués avec des moyens modestes,
   Skull and Bones critiqué malgré les siens.
2. **La vie fait la beauté** : on reproche à Skull and Bones le vide et les routines mécaniques ; Sea of Thieves et Tchia sont
   « habités ».
3. **Emprunter ne suffit pas** : Windbound est jugé trop proche de BotW. Notre signature possible : **le pixel art en 3D sous
   la lumière dorée des Caraïbes**, rare dans le jeu de pirates à notre connaissance.
4. **« Boueux » est le pire reproche**, et le risque numéro un d'un rendu basse résolution : d'où la netteté (accrochage de la
   caméra, contours, reflets d'arête).
5. **Le contraste d'ambiance est un outil de design** : Dredge a bâti son identité sur le jour et la nuit.

---

## 7. Proposition d'identité pour notre jeu

### 7.1 Les piliers

1. **« Or et lagon. »** Une lumière dorée sur des ombres froides couleur de mer ; la nuit appartient aux lanternes.
2. **« De guingois et rond. »** Rien de droit ni de parfait ; le langage des formes ci-dessous.
3. **« Lu en un clin d'œil, à quatre. »** La valeur avant la teinte ; joueurs, dangers et trésors détiennent les extrêmes.
4. **« Un monde qui déborde, une mer qui respire. »** Ville et jungles denses et habitées, séparées par de grandes
   respirations (mer, plages, places).
5. **« La mer est un personnage. »** Elle change de couleur, d'humeur et de son avec l'heure et la météo, et donne le ton de
   l'écran.

**Mots-clés** : doré, salé, patiné, de guingois, habité, chaleureux, mystérieux la nuit, aventure de livre d'images, maquette
vivante.

**Mots interdits** : sale, gris, réaliste, sanglant, néon, propre comme du neuf.

### 7.2 Le langage des formes appliqué

| Catégorie | Formes dominantes | Exemples |
|---|---|---|
| Équipage, ville amie, sloop | rondes, ventrues | coques bombées, chapeaux mous, toits affaissés, palmiers courbes |
| Autorité (marine, fort, gouverneur) | carrées, symétriques | bastions, uniformes droits, galion de la marine aux lignes tendues |
| Danger (squelettes, requins, récifs) | pointues, en zigzag | côtes, ailerons, rochers en dents, voiles noires déchirées |
| Magie (sirènes, baies des dieux) | spirales, courbes en S | chevelures, vagues, motifs de coquillages |

### 7.3 Palette de départ (à tester)

Construction : rampes à décalage de teinte (méthode Slynyrd). Ombres vers le bleu-violet, lumières vers le jaune, saturation
maximale au milieu. Aucun noir ni blanc purs.

| Rampe | Couleurs (de l'ombre à la lumière) | Justification |
|---|---|---|
| Ombre commune | `#1C1726` `#2E2A44` | Violet presque noir pour les contours et les ombres profondes : jamais de noir mort |
| Mer | `#14304A` `#1F5470` `#2A8290` `#4FB8A8` `#A6E3C8` `#EEF6E4` | Du bleu nuit au lagon ; écume blanc cassé chaud, qui ne rivalise pas avec les reflets des personnages |
| Sable | `#6B4A3F` `#A87A52` `#D9B077` `#F4E1AD` | Ombre brun-violet, lumière jaune pâle |
| Végétation | `#1D3B3A` `#2D6444` `#5A9440` `#A3C650` `#E4E88A` | Ombre bleu-vert, lumière jaune-vert : le glissement « luxuriant » d'Eastward |
| Bois | `#3A2630` `#6A4532` `#9C6A43` `#CF9C62` | Brun chaud, ombre prune qui rejoint `#1C1726` |
| Chaux et pierre | `#4A4258` `#7D7488` `#B9AD9C` `#EFE4CC` | Gris colorés qui laissent respirer les couleurs vives |
| Façades | `#D68A6E` `#DCAE5C` `#5F8FB0` `#93C4A6` `#D9A0A8` | Corail, ocre, bleu volet, menthe, rose : caribéen, mais en valeurs moyennes et saturation modérée pour ne pas concurrencer les personnages |
| Tuiles | `#7A3530` `#B25A3E` `#DE8A5E` | Les toits sont ce que la caméra montre le plus : valeur moyenne, pour que les joueurs ressortent |
| Nuit et lanternes | `#1A2240` ; `#FFB35C` `#FFE2A0` | Ambiance bleue ; le seul orange lumineux du jeu, qui guide la nuit vers les lieux sûrs |

**Couleurs réservées** (absentes du décor)
- **Danger et vie** : `#E8352B`, ombre `#8C1F2B`.
- **Or et trésor** : `#FFD23F`, reflet `#FFF6C2`, toujours accompagné d'un scintillement animé.
- **Magie et sirènes** : la bible propose un turquoise lumineux, mais **c'est la couleur de nos hauts-fonds** (`#4FB8A8`,
  `#A6E3C8`). Une sirène dans le lagon serait invisible. Je propose plutôt un **rose nacré bioluminescent** `#E46BE0`, avec un
  reflet `#FFC4F4`, absent de la mer et de la jungle. **À trancher.**

**Couleurs d'équipage** (dérivées d'Okabe-Ito [42], chacune doublée d'un symbole sur le fanion)
- `#0072B2` bleu (ancre)
- `#E69F00` orange (étoile)
- `#CC79A7` mauve (plume)
- `#F2EEE4` blanc cassé (crâne)

Elles ne sont portées que par les foulards, les fanions et les marqueurs, jamais par le décor. Un risque à tester : l'orange
d'équipage contre l'or des trésors chez les daltoniens. Le scintillement et la forme les départagent.

**Ambiances (LUT)**

| Moment | Effet |
|---|---|
| Aube | rose-orangé, ombres lilas |
| Midi | neutre, légèrement chaud, contraste maximal |
| Heure dorée | orange, ombres longues bleu-violet |
| Nuit | bleu `#1A2240` dominant, seules les lanternes restent chaudes |
| Tempête | désaturé vert-gris, valeurs resserrées, éclairs blancs |
| Brume | valeurs resserrées vers le ciel (perspective atmosphérique de Gurney [23]) |

**Dominantes par biome** (règle 60/30/10)

| Biome | Dominante (60 %) | Secondaire (30 %) | Accent (10 %) |
|---|---|---|---|
| Port | façades et tuiles | bois des quais | verdure et linge |
| Île tropicale | verts | sable | fleurs `#D9A0A8` et `#DCAE5C` |
| Île maudite | chaux violacée et sable sombre, ambiance plus froide | — | **aucune** couleur de façade : seuls les yeux des squelettes portent le rouge réservé |
| Mer ouverte | rampe mer | ciel | voiles et écume |

### 7.4 Règles de composition

1. **Un point focal par écran**, plus un secondaire au maximum.
2. **Bande de valeurs** : le décor du plan de jeu reste entre environ 25 % et 75 % de luminosité ; au-delà, c'est réservé aux
   joueurs, aux dangers, aux trésors et aux lumières.
3. **Grappes de 3 à 5 éléments** de trois tailles ; rien d'aligné à intervalles réguliers, et même les pieux sont un peu de
   travers.
4. **Rythme** : environ un tiers de surface calme entre les zones denses.
5. **Trois plans** : avant-plan sombre et rare, plan de jeu contrasté, arrière-plan dans la brume.
6. **Repères** : un repère visible de partout dans le port, un attracteur visible depuis chaque île, trois tailles de formes
   par paysage.
7. **Bordures partout** (§ 4.8), **une seule lumière** (ombres de la 3D et des sprites dans la même direction, ombres
   colorées), et **le joueur n'est jamais caché**.

### 7.5 Checklist de validation d'un écran

À faire sur chaque capture de référence, et pour chaque ambiance : midi, heure dorée, nuit, tempête.

**Lecture**
- [ ] En une seconde, je sais où je suis, où est le danger, où je peux aller.
- [ ] En **niveaux de gris**, les joueurs, les dangers et les objets utiles restent les éléments les plus contrastés.
- [ ] Écran **flouté** (ou plissé) : on distingue encore les grandes masses et le point focal.
- [ ] En **vignette à 25 %**, l'écran reste reconnaissable (lieu, heure).
- [ ] Avec **Color Oracle** (deutéranopie, protanopie, tritanopie), aucune information n'est perdue. Chaque couleur
  d'information a sa forme ou son symbole.

**Coopération**
- [ ] Les 4 joueurs sont identifiables et distinguables entre eux en moins d'une seconde, y compris derrière un obstacle.
- [ ] Les effets des alliés ne masquent ni un ennemi ni un joueur.

**Cohérence**
- [ ] Une seule taille de pixel à l'écran : aucun sprite ni aucune texture agrandi d'un facteur non entier.
- [ ] Une seule direction de lumière ; les ombres des sprites suivent celle du décor.
- [ ] Toutes les couleurs viennent de la palette maître. Les couleurs réservées n'apparaissent que pour leur sens.
- [ ] Les contours sont teintés (jamais noir pur) et n'apparaissent que sur les silhouettes ; les reflets d'arête sont présents.

**Composition et densité**
- [ ] Un point focal (plus un secondaire au maximum).
- [ ] Une zone calme visible, ou à moins d'un écran.
- [ ] Les décors sont en grappes de tailles variées, sans alignement mécanique.
- [ ] Aucune arête nette entre deux matériaux.
- [ ] Au moins un élément de vie en mouvement (personnage, oiseau, linge, fumée, vague).

**Guidage**
- [ ] Le prochain objectif ou un attracteur est suggéré par le monde : lumière, repère, mouvement.
- [ ] Les objets interactifs portent le signe commun (reflet et scintillement), et seulement eux.

---

## Sources

1. Ryan Stevenson, « Visual Adventures on Sea of Thieves », GDC 2018 : https://gdcvault.com/play/1025015/Visual-Adventures-on-Sea-of ; vidéo : https://www.youtube.com/watch?v=BzppoQTG3m0 ; résumé : https://80.lv/articles/gdc18-visual-adventures-on-sea-of-thieves
2. Gamereactor, aperçu de Sea of Thieves : https://www.gamereactor.eu/previews/631753/Sea+of+Thieves+A+Rare+Invitation+to+Become+a+Pirate+Legend/
3. GamesBeat, « How Microsoft's Rare imagined the pirate world of Sea of Thieves » : https://gamesbeat.com/how-microsofts-rare-imagined-the-pirate-world-of-sea-of-thieves/
4. Engadget, aperçu de Sea of Thieves (2018) : https://www.engadget.com/2018-02-13-sea-of-thieves-preview.html
5. SIGGRAPH 2018, « The Technical Art of Sea of Thieves » : https://history.siggraph.org/wp-content/uploads/2022/09/2018-Talks-Ang_The-Technical-Art-of-Sea-of-Thieves.pdf
6. Takizawa sur le style de BotW, GDC 2017 : https://zeldauniverse.net/2017/03/14/takizawa-explains-how-the-wind-waker-hd-inspired-the-visual-style-for-breath-of-the-wild/
7. MCV, « Behind the art of Hades » (Jen Zee) : https://mcvuk.com/business-news/behind-the-art-of-hades-we-value-artistic-integrity-and-excellence-in-artistic-craft-at-supergiant-however-were-first-and-foremost-a-game-design-lead-team/
8. Thumbsticks, « GDC 2015 : The Art of Firewatch » : https://www.thumbsticks.com/gdc-2015-the-art-of-firewatch
9. RocketBrush, langage des formes en character design : https://rocketbrush.com/blog/shape-language-in-game-character-design-how-to-make-characters-readable-and-consistent
10. Cook & Becker, « Designing Overwatch » : https://cookandbecker.com/en/article/378/designing-overwatch.html ; talk GDC 2017 : https://gdcvault.com/play/1024268/
11. Riot Games, « Clarity in League » : https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/ ; « Ask Riot: Let's Talk Clarity » : https://www.leagueoflegends.com/en-us/news/dev/ask-riot-let-s-talk-clarity/
12. Riot Games, guide de style VFX : https://nexus.leagueoflegends.com/en-us/2017/10/dev-leagues-vfx-style-guide/
13. « The Art of Hollow Knight » (analyse) : https://medium.com/3d-environmental-art/the-art-of-hollow-knight-f4c05dda3882
14. Game Developer, « How Shedworks refined the art of Sable in pursuit of readability » : https://www.gamedeveloper.com/marketing/how-shedworks-refined-the-art-of-sable-in-pursuit-of-readability
15. Pedro Medeiros (Saint11), tutoriels : https://saint11.art
16. Résumé de la conférence CEDEC 2017 sur le terrain de BotW (règle du triangle, gravité) : https://gist.github.com/idbrii/e39fe96279aa1670319bfa521d907399
17. Game Developer, « Eastward's creators share insights on making pixel art adventures » : https://www.gamedeveloper.com/art/eastward-s-creators-share-insights-on-making-pixel-art-adventures
18. Wireframe, « Tunic and the art of keeping a secret » : https://wireframe.raspberrypi.com/articles/wireframe-cover-star-tunic-and-the-art-of-keeping-a-secret
19. GamesBeat, Andrew Shouldice : https://gamesbeat.com/tunic-creator-andrew-shouldice-on-indie-gaming-success/
20. Unity, « Crafting DREDGE's cozy atmospheric horror » : https://unity.com/resources/crafting-dredge-cozy-atmospheric-horror
21. Game Developer, « Turning players' worst fears against them in Dredge » : https://www.gamedeveloper.com/production/leveraging-the-unseen-to-turn-players-worst-fears-against-them-in-dredge
22. Game Developer, Road to the IGF, A Short Hike : https://www.gamedeveloper.com/disciplines/road-to-the-igf-adam-robinson-yu-s-i-a-short-hike-i- ; PlayStation Blog : https://blog.playstation.com/2021/08/05/crafting-a-tiny-open-world-a-look-behind-the-scenes-at-the-creation-of-a-short-hike/
23. James Gurney, méthode du masque de gamut : https://gurneyjourney.blogspot.com/2011/09/part-3-gamut-masking-method.html
24. Krita, masques de gamut : https://docs.krita.org/en/user_manual/gamut_masks.html
25. Creative Bloq, Celia Hodent et *The Gamer's Brain* : https://www.creativebloq.com/features/how-neuroscience-and-ux-impacts-video-game-design
26. The Level Design Book, composition : https://book.leveldesignbook.com/process/blockout/massing/composition
27. The Level Design Book, orientation (*wayfinding*) : https://book.leveldesignbook.com/process/blockout/wayfinding
28. The Level Design Book, art d'environnement : https://book.leveldesignbook.com/process/env-art
29. Kevin Lynch, *The Image of the City* : https://en.wikipedia.org/wiki/The_Image_of_the_City
30. Christopher Alexander, *A Pattern Language* : https://urbigenous.net/a-pattern-language/ ; poches d'activité (patron 124) : https://urbigenous.net/a-pattern-language/pattern-124.html
31. Smith et Worch, « What Happened Here? Environmental Storytelling », GDC 2010 : https://www.gdcvault.com/play/1012647
32. Lospec, liste de palettes : https://lospec.com/palette-list
33. Slynyrd, « Pixelblog 1 : Color Palettes » : https://www.slynyrd.com/blog/2018/1/10/pixelblog-1-color-palettes
34. Générateur de rampes à décalage de teinte (repères 15-25° / 30°) : https://ziva.sh/tools/pixel-art-palette-generator
35. Godot, classe Environment (`adjustment_color_correction`) : https://docs.godotengine.org/en/stable/classes/class_environment.html
36. Démo de LUT 3D pour Godot 4 (Calinou) : https://github.com/calinou/godot-3d-lut-demo
37. Coolors, vérificateur de contraste : https://coolors.co/contrast-checker
38. Color Oracle : https://colororacle.org/
39. Game Accessibility Guidelines, « Ensure no essential information is conveyed by a fixed colour alone » : https://gameaccessibilityguidelines.com/ensure-no-essential-information-is-conveyed-by-a-fixed-colour-alone/
40. Xbox Accessibility Guideline 103 : https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/103
41. IGDA GA-SIG, « Do not implement colorblind filters » : https://igda-gasig.org/how/platform-level-accessibility-recommendations/do-not-implement-colorblind-filters/
42. Okabe et Ito, *Color Universal Design* : https://jfly.uni-koeln.de/color/
43. Michael Azzi, *Pixel Logic* (présentation et chapitres) : https://upcarta.onrender.com/resources/53069-pixel-logic-a-guide-to-pixel-art
44. Lospec, « Pixel Art Outlines » : https://lospec.com/articles/pixel-art-outlines
45. Lospec, « Pixel Art Outlines Part 2 : Using Color » : https://lospec.com/articles/pixel-art-outlines-part-2-using-color
46. Pixel Parmesan, « Anti-Aliasing Fundamentals for Pixel Artists » : https://pixelparmesan.com/anti-aliasing-fundamentals-for-pixel-artists
47. Projet Godot inspiré de t3ssel8r : https://relatedrepos.com/gh/Robert-K/godot-3d-pixel-art ; article « Texel Splatting » qui cite t3ssel8r : https://arxiv.org/abs/2603.14587
48. David Holland, « 3D Pixel Art Rendering » (Godot) : https://davidholland.netlify.app/articles/3d-pixel-art-rendering
49. Lois des Indes : https://en.wikipedia.org/wiki/Laws_of_the_Indies ; urbanisme colonial espagnol : https://www.patriciasendin.com/2014/06/the-spanish-colonial-town-planning.html
50. Game Developer, Brian Upton sur Lynch et le paysage des mondes de jeu : https://www.gamedeveloper.com/game-platforms/post-gdc-i-rainbow-six-i-s-upton-talks-landscaping-game-worlds
51. Débat de la peinture jaune : https://en.wikipedia.org/wiki/Yellow_paint_debate ; The Witcher 4 : https://www.gamesradar.com/games/the-witcher-4-design-lead-says-the-problem-with-yellow-paint-in-games-is-subtlety-someone-went-into-this-specific-spot-and-painted-a-yellow-line-at-that-point-its-not-necessarily-believable
52. WellPlayed, critique de Dredge : https://www.well-played.com.au/dredge-review/
53. TechRaptor, critique de Sail Forth : https://techraptor.net/gaming/reviews/sail-forth-review ; Nintendo Life : https://www.nintendolife.com/reviews/switch-eshop/sail-forth
54. GamingBolt, critique de Windbound : https://gamingbolt.com/windbound-review-beauty-is-skin-deep
55. GamesBeat, Rex Crowle sur Return to Monkey Island : https://gamesbeat.com/return-to-monkey-islands-art-director-talks-inspirations-and-expectations/
56. NME, critique de Return to Monkey Island : https://nme.com/reviews/game-reviews/return-to-monkey-island-review-3313165 ; VideoGamer, Ron Gilbert défend le style : https://www.videogamer.com/news/return-to-monkey-island-director-defends-its-art-style
57. Unreal Engine, entretien Tchia : https://www.unrealengine.com/developer-interviews/tchia-is-a-beautiful-ambitious-undertaking-from-a-small-indie-studio
58. Shipwrecked 64 sur Steam : https://store.steampowered.com/app/2160220
59. TheSixthAxis, critique de Ship of Fools : https://www.thesixthaxis.com/2024/01/04/ship-of-fools-review/
60. GamingBolt, critique d'Under the Waves : https://gamingbolt.com/under-the-waves-review-rolling-in-the-deep ; ActuGaming : https://actugaming.net/test-under-the-waves-review-582113
61. Neowin, critique de Skull and Bones : https://www.neowin.net/reviews/skull-and-bones-review-an-unsatisfying-grind-across-the-high-seas/ ; Prima Games : https://primagames.com/reviews/skull-and-bones-review-deep-as-a-puddle
62. Shacknews, « Best Art Style of 2018 : Sea of Thieves » : https://www.shacknews.com/article/109011/shacknews-best-art-style-of-2018-sea-of-thieves

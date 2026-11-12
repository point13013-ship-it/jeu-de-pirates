# Modélisation Blender pour le jeu de pirates : base de connaissances

> Recherche du 12/11/2026. Objectif : passer de modèles « boîtes et cylindres » à des modèles stylisés qui lisent bien
> en vue 3/4 plongeante, rendus en basse résolution façon pixel art. On commence par le brigantin, puis la ville et les
> îles. Sources en fin de document. Certaines pages viennent de vendeurs d'outils : c'est signalé quand une information
> n'a que cette origine.

---

## 0. En bref

1. **Le problème n'est pas le nombre de polygones**, mais les formes trop parfaites, l'absence de biseaux et de
   variation de couleur. La règle de Sea of Thieves : formes simplifiées, objets usés et rafistolés, un peu « bancals »
   (wonky) mais crédibles.
2. **Notre écran impose les tailles : 36 pixels par mètre.** Un détail de moins de 2 px devient du bruit, une corde
   réaliste fait 1 px. On **exagère** cordages, rambardes et sabords, on **supprime** les petits détails.
3. **Densité de texture : environ 32 px/m**, jamais plus que l'écran, sinon les textures « nearest » scintillent.
4. **Trois couches de couleur suffisent :** couleurs par sommet de la palette, ombre de contact cuite, petite trim sheet
   en pixel art.
5. **La coque se construit par sections transversales**, comme sur un chantier. Le bateau s'exagère pour se lire de
   dessus : plus large, pavois hauts, château arrière marqué, voiles séparées pour pouvoir les estomper.
6. **Un biseau fin partout** (2 à 4 cm) : c'est lui qui crée le liseré clair d'un pixel sur les arêtes.
7. **Export .glb vers Godot** avec suffixes de nom (`-colonly`, `-convcol`, `-noimp`, `-vcol`) et un script d'import.
8. **On peut déjà « voir » nos modèles sans rien installer** (rendu PNG depuis la caméra du jeu, ou capture Godot).
   Un serveur MCP Blender est un confort, à installer en mode prudent.
9. **La génération 3D par IA** sert aux ébauches et accessoires de fond, jamais au bateau praticable.

---

## 1. Les chiffres de notre jeu

| Grandeur | Valeur | Source dans le dépôt |
|---|---|---|
| Pixels par mètre | 36 px/m | `PIXELS_PER_METER`, `src/sailing_game.gd` |
| Image interne | 960x540 dans le code, 640x360 visé | `VIEW_SIZE`. À cadrage égal, 640x360 donnerait 24 px/m : à trancher |
| Caméra | orthographique, 40° | `ELEVATION_DEG` |
| Pirate | 64 px, soit 1,78 m | sprite 48x64 |
| Bateau | 24 m de long (jusqu'à 32 m) | `src/ship_model.gd`, `HULL_LENGTH_GROWTH` |

À 40° en orthographique, une surface **horizontale** (pont, quai) est écrasée à l'écran d'un facteur 0,64 (sin 40°),
une surface **verticale** face à la caméra (flanc, façade) d'un facteur 0,77 (cos 40°).

| Objet | Taille réelle | À l'écran | Décision |
|---|---|---|---|
| Planche de pont | 25 cm | 9 px (6 px dans le sens écrasé) | peinte dans la texture |
| Corde de hauban | 3 cm | 1 px ou moins | exagérer à 6-8 cm, ou carte pixel art |
| Rambarde | 8 cm | 3 px | géométrie exagérée à 10-12 cm |
| Sabord, tonneau | 60 cm | 22 px | géométrie simple + texture |
| Bateau | 24 à 32 m | 860 à 1150 px | presque tout l'écran : notre « décor héros » |

Le bateau est vu **de près** : on peut se permettre une vraie richesse de formes, mais rien sous 2 px.

---

## 2. Formations et chaînes : ce qui nous sert vraiment

**Imphenzia** (YouTube, gratuit). Low-poly rapide et plein de caractère : silhouette d'abord, on ajoute du détail
puis on décime. Tout est texturé avec **une seule image de palette**, son atlas **PixPal** (prix libre, mis à jour pour
Blender 5 et Godot 4.6) : chaque face pointe sur une case de couleur. C'est l'équivalent « texture » de nos couleurs
par sommet, avec un avantage : on change toute la palette en remplaçant une image.

**Grant Abbitt** (YouTube, cours GameDev.tv). Fondamentaux (« Get Good at Blender »), low-poly, et surtout **peinture
de textures à la main dans Blender** (cours « Blender Texture Painting », 6 h 30 : pierre, bois, métal, herbe). Leçons :
déplier proprement et corriger l'étirement avant de peindre ; grandes masses, puis ombres et lumières, puis arêtes
usées ; toujours des références et l'échelle réelle. Sa vidéo gratuite « rocher stylisé » (14 min) est la meilleure
entrée pour nos îles.

**Polygon Runway** (YouTube, cours payants). Scènes isométriques complètes (marché médiéval, donjon, ferme). Leçons :
une couleur dominante et un ou deux accents, des formes un peu bombées plutôt que des boîtes, des accessoires groupés
par trois. Son « marché médiéval » s'applique directement à notre port.

**CG Cookie** (abonnement). « Texture Your Models in Blender : UV, Paint, Bake (5.2) », le cours le plus à jour pour
notre version. « Building Modular Game Assets » et « Texturing Game Assets » (Kent Trammell) : un jeu de pièces
modulaires texturées pour un moteur, exactement notre stratégie « kitbashing ».

**Blender Guru.** La série « Donut » reste la meilleure introduction à l'interface, si Jimmy ou l'auteur du jeu veulent
retoucher un modèle à la main. Rien de spécifique au jeu.

**Kenney et Synty.** Pas de cours, mais leurs fichiers sont la leçon. Kenney (CC0) : formes trapues, une seule texture
« colormap » par pack, échelle cohérente, livraison en GLB. Son **Pirate Kit** contient des bateaux : les ouvrir et
mesurer largeur, longueur et hauteur de pavois, c'est une heure très rentable. Synty : même logique d'atlas partagé,
à regarder pour l'organisation modulaire.

**Ian Hubert** (« Lazy Tutorials »). Ne modéliser que ce que la caméra voit. Notre caméra ne voit jamais le dessous de
la coque ni l'arrière des façades : on ne les détaille pas.

**Joey Carlino.** « Geometry Nodes for Beginners » (14 épisodes : instances, courbes, champs, matériaux). Les épisodes
« Instances » et « Curves » couvrent nos besoins : planches, cordages, végétation, rangées de maisons.

**Spécifiques à notre problème :**

- **3D Tudor, « Blender Geometry Nodes - Boats »** : coque procédurale par courbes de Bézier, quille, membrures, lisse.
  Il vend aussi un générateur (7,99 $, Blender 4.x) réglable en hauteur, largeur, arrondi du fond, avant/arrière rond ou
  carré. Le tutoriel le plus proche de notre besoin.
- **Polygon Academy (Tim Simpson), « Creating Trim Sheets »** : la référence citée sur Polycount.
- **Ben Simonds, HMS Victory** (2009, ancien mais juste sur la méthode) : coque par sections, gréement par chemins.

---

## 3. Modéliser un bateau pirate stylisé

### 3.1 Ce que font les jeux de référence

**Sea of Thieves.** La conférence GDC 2018 de Ryan Stevenson et ses résumés donnent quatre règles : une scène riche,
c'est beaucoup d'objets simples ; tout porte une histoire d'usure (réparations de fortune, bois recloué) ; rien n'est
droit mais tout reste crédible ; on ne plaque jamais une photo, on simplifie la référence à la main. Rare n'a pas publié
le nombre de polygones de ses navires (les « 150 000 » de Polycount sont une estimation d'utilisateur).

**Dredge.** D'après Unity : textures **minuscules et partagées** (« 64 by 64, 128 by 128 »), un atlas par biome,
peintes au lasso pour des bords nets ; les détails importants sont **modélisés** plutôt que peints ; le jeu est
« deceptively high-poly in some areas ». C'est notre modèle le plus proche : peu de pixels de texture, beaucoup
d'ambiance par la lumière et le brouillard.

### 3.2 Proportions qui lisent en vue plongeante

- **Largeur.** Un vrai brigantin fait environ 1 de large pour 4 de long. Viser **1 pour 3**, voire 1 pour 2,5 : le
  pont doit accueillir 4 joueurs, des canons et une cabine.
- **Pavois.** Hauts et épais (90 cm à 1 m, 15 à 20 cm), avec une lisse claire dessus. Ils dessinent le contour.
- **Tonture.** Exagérer la remontée du pont vers l'avant et l'arrière : c'est ce qui fait « bateau » et pas « caisse ».
- **Château arrière.** Plus haut et large que nature, fenêtres de poupe, lanternes. C'est le « visage » du bateau.
- **Mâts et voiles.** De dessus, ils cachent le pont. **Objets séparés avec leur propre matériau**, pour que le jeu
  les estompe quand un joueur passe dessous. Mâts un peu plus courts, voiles plus larges.
- **Silhouette.** Un brigantin, c'est une misaine à voiles carrées et un grand mât à voile aurique (trapèze). Ce
  contraste le distingue du sloop et du galion.
- **Œuvres vives.** La caméra ne voit presque jamais la coque sous l'eau : forme simple, sans détail.

### 3.3 Construire la coque

**A. Par sections transversales (recommandé pour nos scripts).** On définit 8 à 12 profils (les « couples ») le long
de la quille : en U serré à l'avant, plus large au maître-couple (vers 40 % de la longueur depuis l'avant), plus plat et
haut à l'arrière. On les relie (boucles d'arêtes reliées, ou « skinning » de courbes), puis on ajoute l'épaisseur
(Solidify), la tonture et les fermetures (étrave, tableau arrière). C'est la méthode de Ben Simonds et du manuel
Blender, et elle se scripte très bien : les profils deviennent des données qu'on ajuste. Ben Simonds déconseille les
booléens pour percer les sabords (topologie abîmée) : on prévoit les ouvertures dans la grille.

**B. Par Geometry Nodes (3D Tudor).** Réglage par curseurs, mais un réseau de nœuds est plus dur à générer et
déboguer par script qu'une liste de profils.

**C. Par treillis (Lattice).** Une boîte subdivisée déformée par un treillis 3x3x5. Rapide pour barques, radeaux et
épaves, trop approximatif pour un pont praticable.

### 3.4 Bordages, membrures, rambardes

- **Bordages.** Planches **peintes** dans une texture qui suit les UV de la coque (comme Dredge), sauf les **deux ou
  trois préceintes** (ceintures de bois sombre autour de la coque), modélisées en relief de 3 à 5 cm : ce sont elles
  qui structurent la coque à l'écran. Si on veut des bordages en relief, une courbe par rangée, un profil plat en
  « Curve to Mesh » et un léger bruit de rotation par planche.
- **Membrures.** Inutiles dehors. Dans la cale, une tous les 1 à 1,5 m suffit à dire « ventre de bateau ».
- **Rambardes et lisses.** Plus épaisses que nature (10 à 12 cm), plus claires que le pavois, biseautées.
- **Pont.** Surface plate texturée ; les bordures (gouttière, hiloires d'écoutilles, caillebotis) sont modélisées pour
  casser la grande surface.

### 3.5 Gréement, enfléchures, voiles

- **Cordages.** Ben Simonds utilise des **chemins d'ordre 2 ou 3** : presque droits, coudés aux poulies. Pour nous, une
  courbe à profil rond de **6 à 8 cm** (exagéré) et 4 à 6 côtés. Plus fine, la corde se coupe en pointillés.
- **Enfléchures** (échelles de corde). En géométrie, des dizaines de petits cylindres qui scintillent. Standard du jeu
  vidéo : une **carte** (plan) avec une texture pixel art du filet en transparence découpée (alpha scissor). Nette en
  filtrage « nearest ».
- **Voiles.** Une grille de 6x6 à 10x10 quads, **gonflée** (pas plate), un léger creux en bas des voiles carrées.
  Animation au vent : un shader pousse les sommets le long de leur normale, pondéré par une couleur de sommet (0 aux
  bords fixés, 1 au centre). Une voile trop pauvre en sommets donne un ventre « en escalier ». Appliquer les
  transformations avant export, sinon le shader et les collisions se dérèglent.

### 3.6 Les détails qui font la différence (du plus rentable au moins rentable)

1. **Sabords** à encadrement clair, volet entrouvert, bouche du canon qui dépasse : « bateau pirate » au premier coup d'œil.
2. **Lanternes** émissives (poupe, mâts) pour le bloom de nuit, **fenêtres de poupe** éclairées.
3. **Cordages lovés** en spirale, **tonneaux et caisses** par deux ou trois, un filet, un seau.
4. **Figure de proue** et **barre** : une forme reconnaissable suffit.
5. **Usure** : une planche plus claire, une plaque clouée, une voile rapiécée (la signature de Sea of Thieves).
6. **Pavillon** animé en pixel art.

### 3.7 Budget de polygones

Godot 4.7 en Forward+ encaisse sans peine plusieurs centaines de milliers de triangles. La vraie limite est la
**lisibilité**. Pour un bateau héros vu de près en basse résolution :

| Partie | Triangles |
|---|---|
| Coque, pont, pavois, préceintes | 4 000 à 8 000 |
| Château arrière, cabine, cale | 3 000 à 6 000 |
| Mâts, vergues, voiles, gréement | 3 000 à 7 000 |
| 10 canons (300 à 600 chacun) | 3 000 à 6 000 |
| Accessoires | 3 000 à 6 000 |
| **Total** | **15 000 à 35 000** |

Pour comparaison, un bateau « low-poly » vendu sur FlippedNormals fait environ 1 500 triangles : c'est le niveau de nos
modèles actuels, trop pauvre pour un pont vu de près.

**LOD.** Godot choisit le niveau de détail selon la taille à l'écran (seuil d'un pixel par défaut). En orthographique à
zoom fixe, un bateau ne rapetisse pas en s'éloignant : la LOD ne sert qu'au dézoom. À tester, et à désactiver mesh par
mesh si un biseau « saute ».

---

## 4. Textures stylisées

### 4.1 La densité de texels

- **Règle :** jamais plus de pixels de texture par mètre que l'écran. Sinon, en « nearest » sans mipmaps, les texels
  plus petits qu'un pixel scintillent quand la caméra ou la houle bouge.
- **Notre valeur : 32 px/m** (écran à 36 px/m). Sur le pont, écrasé à 0,64, on tombe à environ 23 px d'écran par mètre :
  **activer les mipmaps** sur les textures du décor, ou passer à **24 px/m** si l'image interne devient 640x360.
- **Une seule densité pour tout le jeu**, décor et sprites (principe n° 4 de la bible). **Texel Density Checker**
  (gratuit, extension Blender) la mesure et l'uniformise.
- **Pixels alignés :** **Pixel Unwrapper** (gratuit, MIT, version alpha qui peut planter) aligne les UV sur une grille
  de pixels, fixe des pixels par unité, crée la texture en interpolation « Closest » et peut envoyer une sélection sur
  un seul pixel. Pixel Art Studio (payant) fait de même, plus abouti.

### 4.2 Les façons de colorer un modèle

| Méthode | Principe | Atouts | Limites | Pour nous |
|---|---|---|---|---|
| Couleurs par sommet | une couleur par sommet | aucun dépliage, idéal en script | pas de détail plus fin qu'une face | **base de tout** (déjà en place) |
| Atlas de palette (PixPal, Kenney) | les UV pointent sur une case de couleur | une texture pour tout le jeu, palette changeable d'un coup | UV nécessaires, pas de motif | alternative propre |
| Atlas de dégradés | les UV glissent sur une rampe sombre-clair | volume immédiat | redondant avec notre éclairage en paliers | rochers, troncs |
| Trim sheet | une image en bandes (planches, moulures, cordage) réutilisées par les UV | énorme réutilisation | discipline UV | **bois, façades, tuiles** |
| Peint à la main | texture unique par objet | le plus personnel | long | 3 ou 4 objets héros |

**Recommandation (cohérente avec la bible) :** couleurs par sommet de la palette maître pour les aplats, plus **une
trim sheet pixel art de 256x256 à 32 px/m**, en bandes d'1 m (32 px) : planches de pont, bordages, bois sombre, cordage,
toile, tuiles, pierre, enduit, métal. Dredge fait un biome entier en 64 à 128 px.

**Trim sheet, mode d'emploi :** chaque bande se raccorde à gauche et à droite. On déplie chaque planche, poutre ou
moulure en bande droite et on la pose sur la bonne rangée. L'auteur du bateau de pêche stylisé (80.lv) superpose
volontairement les UV et ajoute des **variations de couleur par sommet** dans le moteur pour casser la répétition :
exactement notre combinaison.

### 4.3 Peindre en pixel art pour la 3D

- **Aseprite** pour dessiner (palette verrouillée, mode tuile pour les raccords). Boucle : peindre, sauvegarder,
  recharger dans Blender (Alt+R).
- **Règles :** couleurs de la palette maître uniquement ; textures **peu contrastées** (c'est la lumière et les contours
  qui font le volume) ; pas d'ombre peinte qui suppose une direction de lumière, sauf l'ombre de contact ; motifs à
  l'échelle (une planche de 25 cm = 8 px).
- **Dans Godot :** filtrage « Nearest Mipmap ». Un import glTF peut garder un filtrage linéaire malgré le réglage du
  projet : on le force dans le script d'import (5.4).

### 4.4 L'occlusion ambiante cuite

L'ombre de contact (coins, dessous des rambardes, pied des tonneaux) donne du poids aux objets.

- **Cycles sait cuire vers les couleurs de sommets.** Il faut assez de sommets, et des taches noires sont signalées
  dans le suivi de bugs. **Vertex Oven** (gratuit sur GitHub) le fait plus vite.
- On **multiplie** cette occlusion dans les couleurs de palette, puis on **requantifie** vers la palette.
- Godot importe les couleurs de sommets mais pas le matériau Blender : il faut un matériau Godot qui les lit (suffixe
  `-vcol` ou script d'import).

### 4.5 Outils de texture

| Outil | Prix | Apport | Verdict |
|---|---|---|---|
| Aseprite | environ 20 $ (source ouverte à compiler) | standard du pixel art | **indispensable** |
| Ucupaint (add-on) | gratuit | calques façon Substance dans Blender, cuisson AO ; version 3.0 annoncée le 23/10/2026 (une seule source) | objets héros |
| Material Maker | gratuit (soutien 14,99 $ sur Steam) | textures procédurales par nœuds, **fait avec Godot**, v1.7 (juillet 2026), export en ligne de commande | bases de bois et pierre à réduire puis repeindre |
| ArmorPaint | gratuit à compiler | peinture 3D, v1.0 en septembre 2026 | optionnel |
| Substance 3D Painter | abonnement | référence du métier | surdimensionné pour du pixel art |

---

## 5. Add-ons et outils Blender

### 5.1 Modélisation

- **Bool Tool** (extension officielle gratuite, v2.1.0 de juillet 2026) : booléens rapides pour portes et fenêtres de
  la ville. Pas sur la coque.
- **LoopTools** (gratuit, « support limité ») : Relax, Circle, Space, Flatten, pour arrondir et lisser des boucles.
- **Modificateurs intégrés à exploiter dans nos scripts :** Bevel (avec « Harden Normals »), Weighted Normal,
  Solidify, Array + Curve (planches, rambardes), Lattice, Simple Deform, Displace léger (le côté bancal).
- **Hard Ops / BoxCutter** (payants) : faits pour le « hard surface » (machines, armes). Pas prioritaires pour du bois.

### 5.2 Geometry Nodes

- **Usages :** semer végétation et rochers sur les îles (Distribute Points on Faces, puis Instance on Points avec
  rotation et échelle aléatoires), aligner des maisons le long d'une rue courbe, générer clôtures, quais et pontons le
  long d'une courbe, poser des tuiles.
- Blender 5.0 a ajouté des modificateurs construits en Geometry Nodes (dont un nouvel Array), la 5.1 de nouveaux nœuds.
- **En pilotage par script :** ne pas générer de grands réseaux de nœuds par code (fragile). Créer **quelques groupes
  réutilisables** (semis, objets le long d'une courbe, rangée de planches) dans un `.blend` bibliothèque, puis les
  appliquer et les paramétrer depuis nos scripts. « Realize Instances » avant export, ou export en instances que Godot
  transforme en MultiMesh.

### 5.3 Remaillage et UV

- **Remaillage :** QuadriFlow (intégré) et Instant Meshes (gratuit) suffisent pour une ébauche sculptée ou générée.
  Quad Remesher (payant) seulement si on sculpte beaucoup.
- **UV :** TexTools (gratuit : dépliage, rectification, cuisson), Texel Density Checker (gratuit), UVPackmaster 3
  (payant, empaquetage), Zen UV et TrimForge (payants, confort pour les trim sheets). Pour nous, **outils intégrés +
  TexTools + Texel Density Checker suffisent**, si nos scripts déplient chaque planche en bande droite.

### 5.4 Export glTF vers Godot

**Côté Blender :** 1 unité = 1 m, transformations appliquées, `.glb` en +Y, modificateurs appliqués, **pas de
compression Draco** (Godot ne la lit pas). Pas de n-gones (triangulation imprévisible). Noms stables
(`brigantin_coque`, `brigantin_voile_misaine`) : le code retrouve les pièces par leur nom. Un matériau par famille (bois,
toile, métal, verre émissif). Éclairage réglé dans Godot, pas dans Blender.

**Suffixes reconnus à l'import** (avec `-`, `$` ou `_`) :

| Suffixe | Effet | Chez nous |
|---|---|---|
| `-col` / `-convcol` | ajoute une collision en triangles / convexe | quais / tonneaux, caisses |
| `-colonly` / `-convcolonly` | collision seule, visuel supprimé | **collision simplifiée du pont et des pavois** |
| `-noimp` | non importé | aides de construction |
| `-navmesh` | maillage de navigation | zones de marche des PNJ |
| `-rigid` | corps rigide | objets qui roulent sur le pont |
| `-loop` | animation en boucle | pavillon |
| `-vcol` (matériau) | albédo depuis la couleur de sommet | **nos matériaux à couleurs par sommet** |
| `-alpha` (matériau) | transparence | cartes d'enfléchures (alpha scissor plutôt, via script) |

La doc Godot conseille **quelques formes primitives** plutôt que des collisions en triangles. Pour le pont praticable :
un maillage `-colonly` très simple (plan du pont, pavois en boîtes, escaliers en rampes), séparé du visuel.

**Côté Godot :**

- **Script d'import** (`EditorScenePostImport`, `@tool`, `_post_import(scene)`) : force le filtrage « nearest »,
  remplace les matériaux par notre shader, active la couleur de sommet, range les nœuds.
- « Extract Textures » pour régler l'import des textures (nearest, mipmaps, pas de compression avec perte).
- « Generate LODs » actif par défaut, à couper mesh par mesh si besoin.
- Rester sur des **.glb générés par nos scripts et versionnés** : l'import direct de `.blend` impose Blender sur chaque
  machine qui ouvre le projet.

---

## 6. Piloter Blender par une IA

### 6.1 Ce qui existe en novembre 2026

**MCP for Blender (ex-« blender-mcp » d'`ahujasid`).** Communautaire, MIT, environ 34 000 étoiles, renommé en
septembre 2026 ; non affilié à la Blender Foundation.

- **Outils :** `execute_blender_code` (Python dans Blender), `look` (capture du viewport, d'une caméra, de plusieurs
  angles), `get_scene_info`, recherche et import Poly Haven, Sketchfab, Poly Pizza, `generate_3d` (Tripo, Hunyuan3D,
  Hyper3D Rodin, Meshy, avec ses clés ou une offre payante), mondes en « Gaussian splats » (Blender 5.3+).
- **Installation :** Blender 3.0+, Python 3.10+, `uv`. Claude Code : `claude mcp add blender uvx mcp-for-blender`,
  puis `addon.py` dans Blender, panneau N, « Start MCP Server ». Port 9876.
- **Risques :** le README demande de **toujours sauvegarder avant usage** ; socket sans authentification (rester en
  `localhost`) ; **mode sûr** `BLENDER_MCP_SAFE_MODE=1` (bloque fichiers, réseau, processus) ; télémétrie anonyme
  **activée par défaut** (`DISABLE_TELEMETRY=true`) ; quatre failles (CVE) publiées en 2026 selon un comparatif rédigé
  par un concurrent.
- **Limites :** découper les opérations longues (délais dépassés), Poly Haven gèle Blender pendant les téléchargements,
  une seule instance du serveur à la fois.

**Serveur officiel Blender Lab** (projects.blender.org/lab/blender_mcp). GPL, Blender 5.1+, v1.0 en avril 2026, utilisé
par le connecteur Blender de Claude. Il **embarque la documentation de l'API et du manuel** (moins d'erreurs de code),
exécute du code, et selon StraySpark propose des captures de zone et des rendus du viewport. Pas de génération 3D :
c'est un outil d'analyse et de script. Il faut activer « Allow Online Access », et le code s'exécute **sans garde-fou**
(machine virtuelle recommandée).

**Retours d'expérience** (rares, souvent écrits par des concurrents) : l'IA est un **bon exécutant, pas un directeur
artistique** ; elle ne voit pas seule qu'une lumière est fausse. La boucle qui marche : premier jet, l'humain dit ce qui
ne va pas, l'IA corrige.

### 6.2 Ce que ça changerait pour nous

Aujourd'hui Claude exécute un script Blender en ligne de commande et exporte un `.glb`, **sans voir le résultat**. Le
vrai gain d'un MCP, c'est la **boucle visuelle**. Mais on peut l'avoir sans rien installer :

1. nos scripts rendent un PNG depuis une caméra identique à celle du jeu (orthographique, 40°, basse résolution,
   agrandie en « nearest »), que Claude lit et critique ;
2. mieux, une capture **dans Godot** avec notre vrai shader (le dépôt a déjà `tools/crew_shot.gd`). C'est la seule image
   qui compte.

**Recommandation :** commencer par cette boucle sans add-on. Si on veut une session Blender ouverte en direct (Jimmy
retouche à la main pendant que Claude regarde), installer le **serveur officiel** ou **MCP for Blender en mode sûr**,
télémétrie coupée, installation manuelle (pas de `curl | sh` ni `irm | iex`). Toujours sur une copie du `.blend`,
sauvegardée avant chaque session.

### 6.3 La génération 3D par IA en appoint

- **Utile pour :** ébauches de forme (figure de proue en sirène), accessoires de fond (rochers, souches, jarres), formes
  organiques dures à scripter (troncs tordus, coraux).
- **Inutile pour :** le bateau praticable, les bâtiments modulaires, tout ce qui a des collisions précises.
- **Coût caché : le nettoyage.** Sur Polycount, un artiste compte une demi-journée de « surveillance » pour 30
  accessoires ; un autre compare le travail à une photogrammétrie. Trop de polygones, éclairage cuit dans la texture,
  échelle arbitraire.
- **Méthode :** générer, remailler à 300-1 500 triangles, **jeter la texture** et recolorer en couleurs par sommet de
  la palette, remettre à l'échelle, biseauter, vérifier à 36 px/m.
- **Steam :** depuis le 16/01/2026, Valve demande de déclarer le contenu IA **livré dans le jeu** (modèles, textures) ;
  les outils internes sont exemptés. À revérifier avant publication, et une partie du public réagit mal à la mention.

---

## 7. Méthode de travail

### 7.1 Le pipeline

On garde nos scripts `bpy`, avec un **rendu de contrôle** à la fin de chaque étape.

1. **Références (30 min).** Plan de forme d'un vrai brigantin, captures Sea of Thieves et Dredge pour le style, un
   bateau Kenney ouvert dans Blender pour les proportions de jeu. Mesures cibles en mètres.
2. **Blockout (1 h).** Volumes aux vraies dimensions et un **pirate témoin de 1,78 m**. On vérifie le gameplay :
   passages d'1,2 m minimum, escaliers, accès à la cale. **Export et test dans Godot dès maintenant.**
3. **Silhouette.** Sections de coque, tonture, château, mâts. Contrôle **en noir sur fond blanc** depuis la caméra du
   jeu : si on ne reconnaît pas un brigantin en ombre chinoise, on ne continue pas.
4. **Formes secondaires.** Préceintes, pavois, sabords, rambardes, escaliers, cabine, cale. Biseau de 2 à 4 cm,
   normales pondérées, léger bruit (1 à 3 cm, 1 à 2°) sur planches et poutres.
5. **Détails.** Seulement ceux de plus de 2 px. Accessoires en pièces réutilisables (bibliothèque `kit_pieces.blend`).
6. **UV.** Projection simple pour les couleurs par sommet, bandes droites sur la trim sheet, densité 32 px/m.
7. **Couleur.** Palette maître, occlusion cuite et requantifiée, trim sheet. Contrôle **en niveaux de gris**.
8. **Export.** `.glb`, noms stables, matériaux par famille, collisions `-colonly`, voiles et mâts séparés.
9. **Test Godot.** Capture avec notre rendu, jour et nuit, comparée à l'ancien modèle (comme
   `design/comparaison_quai.png`). Jimmy valide sur image avant le modèle suivant.

### 7.2 Checklists

**Silhouette validée si :** reconnaissable en ombre chinoise ; proportions exagérées là où la caméra regarde ; aucune
ligne parfaitement droite sur plus de 3 m sans raison ; le pirate témoin passe partout.

**Avant export :** échelle 1 = 1 m et transformations appliquées ; origine logique (centre du pont au niveau de l'eau) ;
pas de n-gones ni de faces en double, normales vers l'extérieur ; biseaux sur toutes les arêtes visibles ; rien sous
2 px (sauf volontaire) ; densité 32 px/m uniforme ; couleurs de la palette seulement ; noms, matériaux et collisions
en ordre.

**Après import :** filtrage nearest sans scintillement ; contours et liserés visibles sur les biseaux ; lisible en
niveaux de gris de jour comme de nuit ; même finesse que les sprites 48x64 ; collisions testées en marchant (pas
d'accroche aux pavois, escaliers praticables).

### 7.3 Les erreurs classiques

1. **Modéliser l'invisible** : clous, nœuds, gravures fines deviennent du bruit qui scintille.
2. **Tout droit et symétrique** : le défaut actuel de nos modèles. Le « bancal crédible » est un choix.
3. **Oublier les biseaux** : pas de liseré, aspect « boîte ».
4. **Densités de texture différentes** d'un objet à l'autre : flagrant en pixel art.
5. **Textures trop contrastées ou à ombres peintes**, qui contredisent l'éclairage.
6. **Une nuance de brun par objet** : une palette maître, sans exception.
7. **Échelle fausse** (portes trop petites, marches trop hautes) : le pirate témoin l'évite.
8. **Ne juger que dans Blender** : le seul juge est la capture Godot.
9. **Tout en un seul objet** : impossible d'estomper les voiles, d'ouvrir la cabine, de séparer les collisions.
10. **Commencer par les détails**, ou **booléens et subdivision sur la coque**.
11. **Croire qu'un modèle IA ou un pack est « prêt »** : il faut toujours recolorer, remettre à l'échelle et biseauter.

---

## 8. Sources

### Formations et chaînes

- Imphenzia, PixPal : https://payhip.com/b/8KOlD
- Billets suivant les tutoriels d'Imphenzia : https://medium.com/nerd-for-tech/low-poly-models-1-timelapses-dce93654fff3
- PixPal en pratique : https://jsabbott.artstation.com/blog/7olL1/how-do-you-model-a-low-poly-animal-in-blender-3d
- Grant Abbitt, Blender Texture Painting : https://www.gamedev.tv/p/blender-texture-painting
- Grant Abbitt, Low Poly Landscapes : https://www.gamedev.tv/p/low-poly-landscapes
- Grant Abbitt, Old Cart : https://www.blendernation.com/2018/08/19/hand-painted-style-tutorial-old-cart/
- Polygon Runway : https://polygonrunway.teachable.com/p/become-a-3d-illustrator et https://www.classcentral.com/institution/polygon-runway
- CG Cookie, Texture Your Models (5.2) : https://cgcookie.com/courses/core-5-2-fundamentals-of-texturing
- CG Cookie, Texturing Game Assets : https://cgcookie.com/courses/texturing-game-assets-with-blender
- CG Cookie, Building Modular Game Assets : https://cgcookie.com/courses/building-modular-game-assets
- Joey Carlino, Geometry Nodes for Beginners : https://classcentral.com/course/youtube-getting-started-geometry-nodes-for-beginners-209604
- Kenney, import des modèles : https://kenney.nl/knowledge-base/game-assets-3d/importing-3d-models-into-game-engines
- Polygon Academy (mention) : https://80.lv/articles/creating-a-stylized-elven-wagon-in-blender-and-zbrush?amp=1

### Bateaux

- 3D Tudor, Geometry Nodes - Boats : https://www.skillshare.com/en/classes/blender-geometry-nodes-boats/1585649366
- 3D Tudor, générateur : https://superhivemarket.com/products/3d-tudor-blender-boat-geometry-node-build-any-boat-in-seconds
- Ben Simonds, HMS Victory : https://bensimonds.com/2009/03/18/hms-victory-model-tutorial/
- Manuel Blender, skinning : https://wiki.blender.org/index.php/User:Fade/Doc:2.6/Tutorials/Modeling/Surfaces/Skinning
- Cordages dans Blender : https://modelshipworld.com/topic/36161-3d-ropesrigging-in-blender
- Bateau de pêche stylisé : https://80.lv/articles/creating-a-stylized-fishing-boat-in-blender-zbrush-substance-3d/
- Bateau de 1 457 triangles : https://flippednormals.com/product/stylized-pirate-ship-low-poly-42071
- Voiles au vent : https://lukasstratmann.artstation.com/projects/LeR1k5 et https://discussions.unity.com/t/wind-shader-add-on/816713

### Jeux de référence

- Sea of Thieves, GDC 2018 : https://gdcvault.com/play/1025015/Visual-Adventures-on-Sea-of
- Résumé des règles : https://blog.habrador.com/2018/08/stylized-graphics-fortnite-sea-of-thieves.html
- SIGGRAPH 2018 : https://history.siggraph.org/wp-content/uploads/2022/09/2018-Talks-Ang_The-Technical-Art-of-Sea-of-Thieves.pdf
- Polycount, polygones des navires : https://polycount.com/discussion/comment/2753277
- Dredge : https://unity.com/resources/crafting-dredge-cozy-atmospheric-horror

### Textures et pixel art en 3D

- 3D pixel art in Blender : https://studio.blender.org/blog/3d-pixel-art-in-blender
- Pixel Unwrapper : https://github.com/noio/Pixel-Unwrapper
- Pixel Art Studio : https://superhivemarket.com/products/pixel-art-studio
- Scène pixel art (Aseprite, densité) : https://80.lv/articles/take-a-look-at-this-scene-of-pixel-style-snowy-japanese-town
- Texel Density Checker : https://mrven.gumroad.com/l/CEIOR
- Texturing en dégradés : https://80.lv/articles/elevating-gradient-texturing-to-a-standard-workflow-in-blender
- Environnement basse résolution : https://spiralatlas.github.io/making-a-low-res-environment-in-blender
- TrimForge : https://superhivemarket.com/products/trimforge--trim-sheet-workflow/docs
- Cuisson vers couleurs de sommets : https://docs.blender.org/manual/en/3.1/render/cycles/baking.html
- Vertex Oven : https://blenderartists.org/t/vertex-oven-bake-ao-to-vertex-colors/1208146
- Couleurs de sommets dans Godot : https://forum.godotengine.org/t/importing-blender-file-yields-no-vertex-colours-in-godot/113404
- Pixel art dans Godot 4 : https://www.gdquest.com/library/pixel_art_setup_godot4/
- Ucupaint 3.0 : https://digitalproduction.com/2026/11/03/ucupaint-3-blender-texture-painting/
- Material Maker 1.7 : https://www.cgchannel.com/2026/07/open-source-material-authoring-software-material-maker-1-7-is-out/
- ArmorPaint 1.0 : https://www.cgchannel.com/2026/09/armorpaint-1-0-is-out-after-eight-years-in-early-access/

### Add-ons, Blender, export

- Bool Tool : https://extensions.blender.org/add-ons/bool-tool/
- LoopTools : https://extensions.blender.org/add-ons/looptools/
- Blender 5.0 : https://www.cgchannel.com/2025/11/blender-5-0-is-out-check-out-its-5-key-features
- Blender 5.1 : https://www.cgchannel.com/2026/03/discover-5-key-features-in-blender-5-1
- Godot, suffixes : https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html
- Godot, import : https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html
- Godot, LOD : https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html
- Godot, conseils d'export : https://docs.godotengine.org/en/4.2/tutorials/assets_pipeline/importing_3d_scenes/model_export_considerations.html
- Checklist Blender vers Godot : https://app.cinevva.com/guides/blender-to-godot-export-checklist

### IA et Blender

- MCP for Blender : https://github.com/ahujasid/blender-mcp
- Serveur officiel Blender Lab : https://projects.blender.org/lab/blender_mcp/raw/branch/main/readme.md
- Comparatif (éditeur concurrent) : https://www.strayspark.studio/blog/official-blender-mcp-server-comparison-2026
- Limites relevées : https://blenderartists.org/t/blender-mcp-pro-100-tool-mcp-server-for-controlling-blender-from-ai-assistants/1633350
- Claude + Blender en pratique : https://www.mindstudio.ai/blog/claude-blender-mcp-real-world-performance
- Nettoyage des maillages IA : https://polycount.com/discussion/238705/how-are-you-actually-handling-ai-generated-mesh-cleanup-before-engine-handoff
- Générateurs 3D IA (2026) : https://wavect.io/blog/ai-3d-model-generators-game-development-2026/
- Steam, déclaration IA : https://www.pcgamer.com/software/ai/steam-updates-ai-disclosure-form-to-specify-that-its-focused-on-ai-generated-content-that-is-consumed-by-players-not-efficiency-tools-used-behind-the-scenes/

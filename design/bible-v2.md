# Bible graphique v2 : identité, méthode et plan de reprise (12/11/2026)

> Synthèse de quatre recherches approfondies, dans `design/connaissances/` (sources et détails) :
> - `01-modelisation-blender.md` : formations, bateau, textures, outils, export, IA (environ 4 500 mots) ;
> - `02-direction-artistique-level-design.md` : identité, palette, pixel art, level design, UX (environ 5 200 mots) ;
> - `03-rendu-godot.md` : Godot 4.3 à 4.7, rendu 3D pixel art, mouvement, eau (environ 5 500 mots) ;
> - `04-references-concurrents.md` : navires, villes, îles, vie, jeux récents (environ 5 000 mots).
>
> Elle remplace `bible-direction-artistique.md` pour les décisions ; celle-ci reste comme première étape.
>
> **Ordre de reprise voulu par Jimmy :**
> 1. le **brigantin** (le bateau qu'on utilise entre amis) ; le sloop et le galion attendent ;
> 2. **le monde** : ville, îles, environnement ;
> 3. **menus et interface** ;
> 4. **l'eau**, en dernier.

---

## 1. Ce que disent toutes les sources, en dix phrases

1. **Une identité, c'est quelques règles appliquées partout**, pas un bel écran isolé. C'est ce qui ressort de Sea of Thieves
   (GDC 2018), de Breath of the Wild, de Hades et de Firewatch.
2. **Le problème n'est pas le nombre de polygones** : ce sont les formes trop parfaites, l'absence de biseaux et de
   variations de couleur, et le vide. Skull and Bones a été critiqué pour son monde vide, Windbound pour son image
   « boueuse ».
3. **Rien de droit, mais crédible.** Sea of Thieves est « un peu tordu, un peu courbé » (*wonky*), usé et réparé.
4. **La valeur (clair/sombre) passe avant la teinte.** Le décor reste dans des valeurs moyennes ; joueurs, dangers et
   trésors ont les extrêmes.
5. **La lumière fait l'ambiance** : ombres froides, lumières chaudes, brume, rayons, lanternes la nuit. C'est l'outil le
   plus oublié, d'après Rare.
6. **Le détail se règle sur l'écran.** On voit 36 pixels par mètre (72 sur ton écran) : rien de moins de 2 pixels, on
   exagère cordages et rambardes, on supprime le reste.
7. **Peu de pixels de texture, mais partagés.** Dredge habille un biome entier avec des textures de 64 à 128 px.
   Couleurs par sommet, ombre de contact cuite, une petite feuille de textures pixel art.
8. **La vie fait la beauté** : au moins une source de mouvement à l'écran à tout moment (oiseau, linge, fumée, flamme,
   vague).
9. **Les transitions** : deux matériaux ne se touchent jamais par une arête nette (quai/eau, sable/herbe, mur/sol).
10. **La stabilité de l'image distingue un jeu « pro » d'un jeu « amateur »** en pixel art 3D : la caméra doit être
    calée sur la grille des pixels.

---

## 2. L'identité du jeu

### 2.1 Les cinq piliers

1. **Or et lagon.** Une lumière dorée sur des ombres froides couleur de mer ; la nuit appartient aux lanternes.
2. **De guingois et rond.** Rien de droit ni de parfait. Les formes rondes sont amies, les carrées représentent
   l'autorité, les pointues le danger.
3. **Lu en un clin d'œil, à quatre.** La valeur avant la teinte. Chaque joueur est reconnaissable en moins d'une seconde.
4. **Un monde qui déborde, une mer qui respire.** Ville et jungles denses et habitées, séparées par de grandes
   respirations : mer, plages, places.
5. **La mer est un personnage.** Elle change de couleur, d'humeur et de son avec l'heure et la météo.

**Mots-clés** : doré, salé, patiné, de guingois, habité, chaleureux, mystérieux la nuit, livre d'images, maquette vivante.
**À bannir** : sale, gris, réaliste, sanglant, néon, propre comme du neuf.

**Notre signature** (rare chez les jeux de pirates) : *le pixel art en 3D sous la lumière dorée des Caraïbes, en
coopération sur un vrai pont praticable.*

### 2.2 La palette de départ

Elle est montrée en image dans `design/palette_v1.png`. Méthode : des rampes à décalage de teinte, c'est-à-dire que les
ombres glissent vers le bleu-violet et les lumières vers le jaune, avec la saturation au milieu. Ni noir ni blanc purs.

| Rampe | De l'ombre à la lumière |
|---|---|
| Ombre commune | `#1C1726` `#2E2A44` |
| Mer | `#14304A` `#1F5470` `#2A8290` `#4FB8A8` `#A6E3C8` `#EEF6E4` |
| Sable | `#6B4A3F` `#A87A52` `#D9B077` `#F4E1AD` |
| Végétation | `#1D3B3A` `#2D6444` `#5A9440` `#A3C650` `#E4E88A` |
| Bois | `#3A2630` `#6A4532` `#9C6A43` `#CF9C62` |
| Chaux et pierre | `#4A4258` `#7D7488` `#B9AD9C` `#EFE4CC` |
| Façades | `#D68A6E` `#DCAE5C` `#5F8FB0` `#93C4A6` `#D9A0A8` |
| Tuiles | `#7A3530` `#B25A3E` `#DE8A5E` |
| Nuit et lanternes | `#1A2240` · `#FFB35C` `#FFE2A0` |

**Couleurs réservées** (jamais dans le décor) :
- danger et vie : `#E8352B` ;
- or et trésor : `#FFD23F`, toujours avec un scintillement ;
- magie et sirènes : rose nacré `#E46BE0` (à trancher, voir § 7) ;
- équipages (couleurs lisibles par les daltoniens, chacune doublée d'un symbole) : bleu `#0072B2` (ancre), orange
  `#E69F00` (étoile), mauve `#CC79A7` (plume), blanc cassé `#F2EEE4` (crâne).

**Ambiances par moment** (une table de couleurs, ou LUT, appliquée avant la palette) :
- **aube** : rose-orangé ;
- **midi** : neutre ;
- **heure dorée** : orange, ombres longues violettes ;
- **nuit** : bleue, avec seulement les lanternes chaudes ;
- **tempête** : vert-gris ;
- **brume** : valeurs resserrées.

**Dominantes par lieu** (règle 60/30/10 : dominante, secondaire, accent) :
- **port** : façades et tuiles, puis bois des quais, puis verdure et linge ;
- **île tropicale** : verts, puis sable, puis fleurs ;
- **île maudite** : froide et violacée ; seuls les yeux des squelettes portent le rouge.

### 2.3 Les règles de composition

1. Un point focal par écran, plus un secondaire au maximum.
2. Le décor reste entre 25 % et 75 % de luminosité ; au-delà, c'est réservé aux joueurs, aux dangers, aux trésors et aux
   lumières.
3. Les objets vont par grappes de 3 à 5, en trois tailles (grand, moyen, petit) ; rien n'est aligné à intervalles réguliers.
4. Environ un tiers de surface calme entre les zones denses.
5. Trois plans : avant-plan sombre et rare, plan de jeu contrasté, arrière-plan dans la brume.
6. Des bordures partout, une seule direction de lumière, et le joueur n'est jamais caché.

---

## 3. Le brigantin : cahier des charges

Modèle de référence : le brigantin de Sea of Thieves (3 joueurs, 2 mâts). Notre version garde nos fonctions de jeu :
pont praticable, cabine du capitaine, cale, 3 canons par bord, barre, cabestan, coffre à boulets, caisse à planches,
échelles de coque, nid de pie.

### 3.1 Silhouette et proportions (par rapport à la longueur de coque L, environ 25 m dans le jeu)

| Élément | Règle |
|---|---|
| Coque | 1 de large pour 3 de long (un vrai fait 1 pour 4 : on élargit pour le jeu). Ventre arrondi, flancs qui rentrent vers le haut. **Tonture exagérée** : le pont remonte nettement à l'avant et à l'arrière |
| Pavois | Hauts (90 cm à 1 m) et épais, avec une lisse claire biseautée par-dessus : ils dessinent le contour vu de dessus |
| Gaillard d'arrière | 0,25 à 0,30 L, surélevé de 1,2 à 1,5 m, escalier de 4 ou 5 marches ; la cabine du capitaine dessous, la barre dessus ou juste devant |
| Poupe | Tableau un peu penché, 3 à 5 fenêtres à petits carreaux éclairées la nuit, lanterne de poupe, nom peint, cadre doré |
| Proue | Guibre, **figure de proue** qui dépasse de la silhouette, beaupré relevé de 20 à 30°, deux focs |
| Mât de misaine (avant) | Gréé carré : misaine, hunier, perroquet ; hune à mi-hauteur |
| Grand mât (arrière) | Le plus haut, légèrement penché vers l'arrière ; grand-voile aurique (corne et bôme) plus un hunier carré ; nid de pie |
| Voiles | Gonflées, deux tons au minimum, coutures verticales, une ou deux rustines, bordure plus foncée, emblème d'équipage sur une voile |
| Gréement | Haubans et enfléchures en V de chaque côté (on y grimpe), drisses qui pendent en courbe |
| Pavillons | **Flamme** de 3 à 4 m en tête du grand mât, qui montre le vent ; pavillon au bout de la corne |

### 3.2 Les 15 détails, par ordre d'impact visuel

1. La flamme et le pavillon.
2. La poupe haute et ses fenêtres éclairées.
3. Les voiles gonflées à deux tons.
4. La coque à bandes : bois sombre, préceinte de couleur, filet doré.
5. La figure de proue.
6. Le contraste entre le pont clair et le plat-bord sombre, avec des planches dans la longueur et quelques planches neuves
   plus claires.
7. Les lanternes : 3 sur le pont, 1 au nid de pie, avec un halo la nuit.
8. Les haubans et enfléchures.
9. Les mâts cerclés de fer.
10. Les canons sur affûts rouges, avec boulets en pyramide, écouvillon et seau ; les sabords sur le flanc visible.
11. Le caillebotis (écoutille en grille).
12. La barre et son compas.
13. Le cabestan et l'ancre pendue au bossoir.
14. La vie à bord : cordages lovés, tonneau de grog, caisses sous filet, mouette sur une vergue, canot, poêle qui fume.
15. L'usure : écailles de peinture, coulures sous les dalots, algues et coquillages au ras de l'eau.

### 3.3 Règles de lisibilité propres au bateau

- **Rien sous 2 pixels.** Cordages de 6 à 8 cm de diamètre (exagérés), rambardes de 10 à 12 cm. Les enfléchures sont
  dessinées en pixel art sur un plan, pas en dizaines de cylindres qui scintillent.
- **Mâts, vergues et voiles sont des objets séparés**, que le jeu estompe quand un joueur passe dessous.
- **Pont de valeur moyenne et chaude** : les pirates doivent ressortir dessus ; pas de motif chargé là où l'on marche.
- **Budget** : 15 000 à 35 000 triangles (le modèle actuel en a environ 2 000). Le dessous de la coque reste simple :
  la caméra ne le voit jamais.

---

## 4. La méthode de fabrication

### 4.1 Le pipeline, pour chaque modèle

1. **Références** : une planche (captures de jeux, plans, photos) et la liste des fonctions de jeu (où l'on marche, ce
   qu'on touche).
2. **Ébauche** (blockout) en volumes simples, à l'échelle, testée **dans Godot** avec un pirate : couloirs, hauteurs,
   lisibilité depuis la caméra du jeu.
3. **Silhouette** : on la vérifie en noir sur fond clair, à la taille réelle à l'écran.
4. **Formes** :
   - la coque par **sections transversales** (8 à 12 profils reliés), ce qui se scripte bien ;
   - des biseaux fins partout (2 à 4 cm), qui créent les reflets d'arête ;
   - un léger bruit sur les sommets, des pièces un peu de travers.
5. **Couleur**, en trois couches :
   - **couleurs par sommet** tirées de la palette maître ;
   - **ombre de contact cuite** dans ces couleurs (avec Cycles) ;
   - une **feuille de textures pixel art** de 256 px à environ 32 px par mètre (planches, bordages, cordage, toile,
     tuiles, pierre, enduit, métal), en filtrage net.
6. **Export glTF** avec les conventions de noms (collisions `-colonly`, couleurs `-vcol`) et un script d'import Godot qui
   règle le filtrage net et la lumière commune.
7. **Contrôle** : rendu dans le jeu sous 4 ambiances (midi, heure dorée, nuit, tempête), puis la checklist du § 6.
   **Captures avant/après pour ta validation.**

### 4.2 Les outils

- **Blender 5.3 piloté par script**, comme aujourd'hui. Je vois mes modèles par des rendus PNG depuis la caméra du jeu et
  des captures Godot, sans rien installer.
- **Extensions gratuites utiles**, si on les installe :
  - Texel Density Checker : uniformiser la finesse des textures ;
  - Pixel Unwrapper : aligner les textures sur la grille de pixels ;
  - Vertex Oven : cuire l'ombre de contact.
- **Piloter Blender en direct par l'IA** (« MCP for Blender ») : je le déconseille pour l'instant. Il exécute du code sans
  authentification, sa télémétrie est active par défaut, et quatre failles ont été signalées. Les rendus PNG suffisent.
- **Génération 3D par IA** : seulement pour des ébauches et des accessoires de fond (figure de proue, statue, épave), en
  forme seule, recolorée dans notre palette. Jamais pour le bateau praticable.
- **Packs gratuits (CC0)** : Kenney Pirate Kit (à ouvrir pour étudier ses proportions), Quaternius, KayKit, comme pièces
  détachées.

### 4.3 Les formations de référence (leçons résumées dans 01)

- **Imphenzia** : low-poly plein de caractère, une seule image de palette.
- **Grant Abbitt** : peinture de textures à la main, rochers stylisés.
- **Polygon Runway** : scènes isométriques, accessoires groupés par trois.
- **CG Cookie** : pièces modulaires, textures de jeu.
- **3D Tudor** : coques de bateau procédurales.
- **Polygon Academy** : feuilles de textures en bandes (trim sheets).
- **Ben Simonds** : coque par sections, gréement.
- **Joey Carlino** : Geometry Nodes.

---

## 5. L'architecture de rendu cible (dans Godot)

**Dans la 3D**, par ordre :
1. **Caméra stabilisée** : calée sur la grille des pixels, le reste compensé par un décalage de l'image. C'est la première
   chose à faire, tout le reste se juge mieux une fois l'image stable.
2. **Un matériau commun** (fichier `.gdshaderinc` partagé) :
   - lumière en 3 paliers, ombres froides venues de l'ambiance ;
   - ombres de nuages qui défilent, vent ;
   - couleurs par sommet et textures nettes.
3. **Ombres du soleil nettes et stables.**
4. **Contours de silhouette et reflets d'arête** : le quad actuel suffit.
5. **Ce qui bouge** :
   - un vent global, animé à cadence réduite (8 à 12 images/s, façon pixel art) ;
   - les voiles en formes clés pilotées par la navigation ;
   - pavillons et lanternes animés par des ressorts (`SpringBoneSimulator3D`).

**En post-traitement, sur l'image basse résolution** :
6. LUT d'ambiance (heure, météo, lieu).
7. Palette maître, avec une trame optionnelle.
8. Brume et ciel en couleurs pleines.

**À éviter** :
- l'éclairage global temps réel (SDFGI, VoxelGI, qui ne gèrent pas l'orthographique) ;
- les reflets d'écran (SSR), le brouillard volumétrique global, tout anticrénelage ;
- le tissu simulé pour les voiles ;
- un shader différent par objet.

**Budget visé** : 5 ms de calcul graphique par image au plus, moins de 1 500 appels de rendu.

**Eau (pour la fin)** : une seule fonction de vagues, identique pour l'image et pour la flottaison ; une flottaison par 4
à 8 points de mesure ; l'horloge des vagues synchronisée entre joueurs ; un sillage dessiné dans une texture qui suit le
bateau. Une simulation de type FFT n'apporterait presque rien à notre résolution.

---

## 6. La checklist de validation d'un écran

**Lecture**
- [ ] En une seconde, je sais où je suis, où est le danger et où je peux aller.
- [ ] En niveaux de gris, joueurs, dangers et objets utiles restent les éléments les plus contrastés.
- [ ] L'écran flouté garde ses grandes masses ; en vignette à 25 %, le lieu et l'heure restent reconnaissables.
- [ ] Avec un simulateur de daltonisme (Color Oracle), aucune information n'est perdue.

**Cohérence**
- [ ] Une seule taille de pixel, une seule direction de lumière.
- [ ] Toutes les couleurs viennent de la palette ; les couleurs réservées n'apparaissent que pour leur sens.
- [ ] Contours teintés, seulement sur les silhouettes ; reflets d'arête présents.

**Composition et vie**
- [ ] Un point focal, une zone calme, des grappes de tailles variées, aucune arête nette entre deux matériaux.
- [ ] Au moins un élément de vie en mouvement.

**Coopération**
- [ ] Les 4 joueurs se distinguent en moins d'une seconde, même derrière un obstacle.

---

## 7. Les décisions à prendre avec Jimmy

1. **Figure de proue du brigantin** : sirène, crâne, animal (lion, aigle, serpent de mer) ou autre ?
2. **Couleur d'identité de la coque** : bois sombre avec bande rouge, bande turquoise, ou autre ?
3. **Couleur de la magie et des sirènes** : rose nacré (proposé, car le turquoise se confond avec les lagons) ou turquoise ?
4. **Ton de la palette** : la palette de départ (`design/palette_v1.png`) te plaît-elle, faut-il plus vif ou plus doux ?
5. **Avis de l'auteur du jeu** sur cette direction, avant de remplacer ses modèles.

---

## 8. Le plan de reprise

Chaque étape s'arrête sur des captures avant/après et ta validation.

**Étape 0 : fondations** (une fois pour tout le jeu)
- Caméra stabilisée sur la grille des pixels.
- Matériau commun (paliers, ombres froides, ombres de nuages, vent).
- Palette maître et LUT d'ambiance.
- Script d'import Godot et conventions d'export.
- Feuille de textures pixel art v1 (bois, cordage, toile, métal).

**Étape 1 : le brigantin**
1. Ébauche testée dans le jeu (couloirs, postes, cabine, cale) ; **validation**.
2. Coque par sections, pavois, gaillard d'arrière, poupe, proue, figure de proue.
3. Mâts, vergues, voiles gonflées en formes clés, gréement, pavillons animés.
4. Couleurs, ombre de contact, textures, usure.
5. Les 15 détails et la vie à bord, puis la cale et la cabine refaites.
6. **Validation** sous 4 ambiances.

**Étape 2 : le monde**
- **Ville** :
  - plan organique : place au débarcadère, rue principale qui serpente, contre-allées et ruelles en trois largeurs ;
  - maisons plus grandes, avec des rangées de plus ;
  - jardins, repère (clocher ou phare) ;
  - bordures entre matériaux, vie (PNJ, linge, fumées).
- **Îles** :
  - une silhouette signature par île ;
  - plages en bandes, végétation en couches, falaises en strates, épaves, ruines.

**Étape 3 : menus et interface**
- Theme commun, cadres pixel art.
- HUD contextuel : instrument de bord à la barre, invites au-dessus des objets.
- Menus refaits ; références dans le rapport HUD et dans 04.

**Étape 4 : l'eau**
- Houle commune image/flottaison, flottaison par points de mesure, sillage en texture.
- Écume de rivage, reflets truqués, vue sous l'eau.

# Bible de direction artistique : proposition (12/11/2026)

> Synthèse de trois recherches : jeux de référence et rendu, interfaces, sources de modèles et IA (sources en fin de document).
> **Rien n'est appliqué au jeu tant que ce document n'est pas validé** (par Jimmy et par l'auteur du jeu).

## 1. Le diagnostic

Le jeu est « trop low-poly, trop anguleux, toujours la même palette ». Les recherches convergent : ça ne vient pas surtout du
nombre de polygones, mais de quatre choses.

1. **La lumière et les contours.**
   - Aujourd'hui : aplats, ombres grises, contour noir partout.
   - Les jeux salués (Eastward, Dredge, Sable, t3ssel8r) ont des ombres colorées, deux ou trois paliers de lumière, et un
     contour seulement sur les silhouettes, avec un reflet clair sur les arêtes.
2. **La palette.**
   - Notre filtre ramène tout à une palette fixe. L'heure et la météo ne font que teinter par-dessus, d'où l'impression que
     « rien ne change ».
3. **Les formes.**
   - Primitives parfaites : boîtes, cylindres, lignes droites.
   - Il manque les biseaux, les toits affaissés, les planches de travers, les poutres qui débordent.
4. **La densité et les transitions.**
   - Pas de « bordures » entre matériaux : quai/eau, sable/herbe, chemin/herbe.
   - Peu de verdure qui déborde, ville en lignes droites.

## 2. Les cinq principes

1. **Chaud et habité.** Une lumière dorée le jour, des lanternes chaudes dans un monde bleuté la nuit, et partout des traces de
   vie : linge, pots de fleurs, caisses, cordages, oiseaux.
2. **Lisible de loin.** Chaque île a une silhouette signature, la ville a un repère (phare, clocher). Le joueur, les dangers et
   les objets utiles ressortent en *valeur* (clair/sombre), pas seulement en couleur.
3. **Rien de rectiligne.** Rues qui serpentent, façades décalées, toits de hauteurs différentes, rivages irréguliers.
4. **Une seule taille de pixel.** Le décor 3D et les sprites 48x64 ont la même finesse à l'écran, la même palette et la même
   direction de lumière.
5. **Du calme entre les zones chargées.** On alterne zones denses (rues, marché) et zones calmes (places, plages, mer libre).

## 3. Le rendu « pixel art en 3D » (le plus gros gain, sans refaire un seul modèle)

| Étape | Aujourd'hui | Proposé | Référence |
|---|---|---|---|
| Résolution | rendu basse résolution + filtre | identique, densité de texels calée sur les sprites | t3ssel8r, Holland |
| Lumière | aplats, ombres grises | lumière en 3 paliers, ombres froides (bleu/violet), lumières chaudes (orange), lumière d'appoint quand le soleil fait face à la caméra | Holland, Shadowglass |
| Contours | trait noir partout | trait sombre teinté seulement sur les silhouettes (profondeur), reflet clair d'un pixel sur les arêtes saillantes (normales), qui s'estompe au loin | shader de Leo Peltola (licence MIT, démo Godot), Sable |
| Couleur | palette fixe + teinte | LUT d'ambiance par heure, météo et biome **avant** la quantification, puis palette maître de 48 couleurs environ | Graveyard Keeper, Dredge |
| Brume | refaite le 12/11 (profondeur + ras de l'eau) | à régler par biome, en couleurs pleines (pas quantifiée) | Dredge, Sable, Shadowglass |
| Eau | 4 tons + houle | plus : écume de rivage par profondeur, reflets des lanternes et du soleil | Sea of Thieves, Holland |
| Post-traitement | vignette, brume | bloom seulement sur les lanternes, très léger effet « maquette » (tilt-shift) ; ni grain ni aberration | HD-2D, Tunic |
| Sprites | ombre ronde | ombre portée dans la direction du soleil, contact au sol | HD-2D |

## 4. La palette

- **Palette maître** d'environ 48 couleurs, en rampes de 6 à 9 tons « décalés en teinte » (méthode Slynyrd) :
  - en descendant vers l'ombre, la teinte glisse vers le bleu ou le violet ; en montant vers la lumière, vers le jaune ou
    l'orange ;
  - la saturation culmine au milieu de la rampe ;
  - quelques gris désaturés laissent respirer les couleurs vives.
- **Sous-palettes** par biome : port (ocres, tuiles, laiton), île tropicale (verts chauds, sable doré), île morte (gris
  violacés), mer (nos 4 tons, revus).
- **Couleurs réservées** :
  - rouge vif : danger et vie seulement ;
  - or : l'or et les objets utiles ;
  - turquoise lumineux : la sirène et la magie.
- **Contrôle** : chaque écran-type est vérifié en niveaux de gris.

## 5. Les modèles

### Méthode retenue

1. **Bateaux et ville : à refaire nous-mêmes par « kitbashing ».**
   - Une bibliothèque de pièces modulaires (planche, poutre, rambarde, fenêtre, porte, sabord, tuiles, auvent), assemblées
     par nos scripts Blender.
   - C'est le seul moyen de garder un pont praticable, une cabine et des collisions maîtrisées. Aucun pack ni aucune IA ne
     sait faire un bateau praticable.
2. **Montée en qualité dans les scripts Blender** :
   - biseaux (deux segments, donc des reflets d'arête) ;
   - léger bruit sur les sommets, toits affaissés, planches légèrement de travers ;
   - couleurs par sommet tirées de la palette, et ombre de contact (occlusion) précalculée dans les couleurs ;
   - une petite feuille de textures peintes (planches, cordage, pierre, tuiles), à la même densité de pixels que l'écran.
3. **Décor et accessoires : packs gratuits (CC0)**, recolorés dans notre palette.
   - Kenney Pirate Kit, Quaternius Pirate Kit, KayKit Forest.
   - Formats glTF, import direct dans Godot.
4. **IA en appoint**, pour des pièces uniques : figure de proue, étal, statue, épave.
   - On génère la forme seule, en low-poly (Tripo P2 ou Meshy 7 en mode low-poly, disponibles via Higgsfield, déjà connecté),
     puis on y applique notre palette.
   - Les textures « photo » de l'IA deviennent de la bouillie en pixel art : on ne les garde pas.

### Budget

| Option | Coût | Contenu |
|---|---|---|
| Gratuit | 0 € | packs CC0, scripts Blender, Meshy gratuit (100 crédits/mois, crédit d'auteur obligatoire) pour essayer |
| Léger | moins de 30 € | KayKit Forest Extra (9,99 $) + 1 mois Higgsfield Starter (15 $, 200 crédits) **ou** 1 mois Meshy Pro (9,50 € le premier mois) |
| Complet | 50 à 100 € | + Synty POLYGON Pirate Pack (49,99 $). Style plus « fini », mais à harmoniser : il se marie mal avec Kenney et Quaternius |

À vérifier avant de payer :

- le coût en crédits d'un modèle 3D chez Higgsfield (l'outil peut l'afficher sans rien générer) ;
- le prix officiel de Tripo ;
- la licence Synty à plusieurs : si le dépôt contient des assets payants, il doit rester privé.

Pièges : Hunyuan3D en local n'est pas autorisé en Union européenne. Les modèles CC-BY demandent un fichier `CREDITS`.

## 6. Composition et décors (level design)

- **La ville du port** (retour de Jimmy) :
  - maisons plus grandes, deux ou trois rangées de plus en profondeur ;
  - une rue principale qui serpente, des contre-allées et des ruelles, des rues de largeurs différentes ;
  - une place ouverte (marché, fontaine), des jardins et de la verdure, des escaliers et des niveaux ;
  - des façades décalées, des encorbellements, des auvents, des cordes à linge, des enseignes ;
  - un repère visible de loin (phare ou clocher).
- **Bordures partout** : jamais d'arête nette entre deux matériaux.
  - Quai/eau : mur, algues, pieux, écume (fait le 12/11 sur les flancs du quai).
  - Sable/herbe : touffes, galets, bois flotté.
  - Chemin/herbe : bords irréguliers, fleurs.
- **Jardins** : potagers clôturés, pots aux fenêtres, lierre sur les murs, buissons variés. La verdure doit « déborder » (c'est
  ce qui rend Eastward luxuriant).
- **Îles** : une silhouette signature chacune (rocher en arche, épave, volcan, phare), et de la mer libre entre elles.
- **Plans superposés** : avant-plan (palmiers, mâts), plan de jeu, arrière-plan (collines dans la brume).

## 7. Ambiance

- Particules :
  - poussière dorée dans les rayons de soleil ;
  - embruns à la proue ;
  - fumée de cheminées, lucioles la nuit ;
  - pluie en traits pixel, feuilles portées par le vent.
- Vie :
  - mouettes, poissons qui sautent ;
  - pêcheurs et dockers qui ont des routines ;
  - linge et drapeaux qui bougent (animation saccadée, moins d'images au loin).
- Son lié à l'image :
  - grincements calés sur la houle, cloches du port ;
  - la nuit, la musique se tait par moments, il reste la coque et les vagues (Dredge).

## 8. Interface (HUD et menus)

### Principes

- **HUD contextuel.** Chaque élément a une raison d'apparaître et un délai pour disparaître ; au plus trois éléments
  permanents hors combat.
- **Pas de texte brut** quand une icône ou un instrument fait mieux le travail : la ligne de texte du haut à gauche disparaît.
- **Une seule couleur vive**, pour les alertes et ce qui est interactif, toujours doublée d'une forme ou d'une icône.
- **Grille de 640x360 « pixels d'interface »**, agrandie d'un facteur entier (x3 en 1080p, x6 en 4K), avec des cadres en
  9-slice dessinés en pixel art : parchemin, planche, anneau de laiton, bandeau de tissu.
- **Typographie** :
  - Pirata One pour les titres ;
  - IM Fell English seulement à partir de 26 px, avec un contour sombre (elle s'empâte en petit) ;
  - une police pixel lisible pour les chiffres et le petit texte.
- **Animations d'entrée** de 120 à 250 ms et un son court sur chaque action (bois, laiton, papier).
- **Tout passe par un seul Theme Godot** (et ses variantes), jouable à la manette.

### Le HUD, situation par situation

- **En mer, à la barre** : un seul instrument de bord en bas au centre, qui remplace le cadran du vent, la flèche de cap et la
  ligne de texte. C'est une rose des vents en laiton qui sort quand on prend la barre et rentre quand on la lâche. Elle porte :
  - l'aiguille du cap ;
  - la flèche du vent, verte s'il est porteur, jaune de travers, rouge contraire ;
  - un repère d'objectif et sa distance ;
  - une petite voile sur 3 niveaux ;
  - l'ancre, visible seulement si elle est mouillée ;
  - la vitesse en nœuds.
- **À terre** :
  - cœurs en haut à gauche ;
  - objectif en haut à droite, qui s'efface après 6 s et revient quand il change ;
  - une fine bande de cap en haut, seulement si un objectif est suivi.
- **À la nage** : une flèche au bord de l'écran vers ton bateau (l'information vitale), et une jauge en anneau qui n'apparaît
  que quand elle baisse.
- **En combat** :
  - les cœurs grossissent et battent quand on est blessé ;
  - une case d'arme compacte en bas à droite, avec les munitions en petites billes ;
  - une barre de vie seulement sur les boss.
- **Alertes** : quand la cale prend l'eau, une jauge en forme de seau pulse en haut au centre.
- **Invites** (« E : prendre la barre ») : une petite plaque de laiton au-dessus de l'objet lui-même, plus en bas d'écran.
- **Réputation** : un bandeau seulement quand elle change.
- **Coéquipiers** : nom et fanion au-dessus de la tête, et une flèche au bord de l'écran quand ils sont hors champ.

### Les menus

- **Menu principal** : une scène vivante (le bateau au mouillage, la nuit, l'équipage qui attend sur le pont), quatre choix au
  plus, et quand on lance la partie, la caméra plonge dans la scène.
- **Sac** : un registre de bord qui s'ouvre, des cases avec des cadres de rareté, et une bulle qui compare un objet à celui
  qu'on a en main.
- **Boutique** : le portrait du marchand, son stock et ton sac sur deux colonnes, l'achat par appui long.
- **Carte** : un parchemin qui se dévoile en explorant, avec des repères posés par les joueurs.
- **Transitions** : moins de 250 ms (tache d'encre, page tournée).

## 9. Plan de mise en œuvre proposé

1. **Prototype du rendu**, sur le port et le sloop seulement :
   - lumière en paliers, contours et reflets, LUT d'ambiance, nouvelle palette ;
   - comparaison avant/après en captures, **validation**.
2. **Kit de pièces modulaires** et refonte du sloop : biseaux, couleurs par sommet, occlusion, feuille de textures.
   **Validation.**
3. **Refonte de la ville** : plan organique, nouvelles maisons, jardins, bordures, repère. **Validation.**
4. **Interface** : Theme commun, cadres pixel en 9-slice, instrument de bord, HUD contextuel, menus. **Validation.**
5. **Déploiement** : brigantin, galion, îles, végétation, particules, vie ambiante.

Chaque étape s'arrête sur des captures avant/après. On ne passe à la suivante qu'avec ton accord.

## 10. Sources principales

- Rendu 3D en pixel art dans Godot (David Holland) : https://davidholland.netlify.app/articles/3d-pixel-art-rendering
- Shader contours et reflets (Leo Peltola, licence MIT) : https://godotshaders.com/shader/3d-pixel-art-outline-highlight-post-processing-shader/ ; démo : https://github.com/leopeltola/Godot-3d-pixelart-demo
- Project Shadowglass : https://80.lv/articles/interview-how-project-shadowglass-creates-its-impossible-fully-3d-pixel-art-look
- Eastward : https://www.gamedeveloper.com/art/eastward-s-creators-share-insights-on-making-pixel-art-adventures
- Dredge : https://unity.com/resources/crafting-dredge-cozy-atmospheric-horror
- Sable : https://www.gamedeveloper.com/marketing/how-shedworks-refined-the-art-of-sable-in-pursuit-of-readability
- Sea of Thieves : https://80.lv/articles/gdc18-visual-adventures-on-sea-of-thieves
- Palettes décalées en teinte (Slynyrd) : https://www.slynyrd.com/blog/2018/1/10/pixelblog-1-color-palettes
- LUT jour/nuit (Graveyard Keeper) : https://www.gamedeveloper.com/programming/graveyard-keeper-how-the-graphics-effects-are-made
- Composition : https://book.leveldesignbook.com/process/blockout/massing/composition
- Interfaces :
  - Game UI Database : https://www.gameuidatabase.com
  - refonte de l'interface de Sunless Skies : https://www.gamedeveloper.com/design/reading-by-gaslight-a-look-inside-sunless-skies-ui-redesign
  - le vent-guide de Ghost of Tsushima : https://gdconf.com/news/see-how-ghost-tsushima%E2%80%99s-guiding-wind-came-life-gdc-2021
  - accessibilité Xbox : https://learn.microsoft.com/en-us/gaming/accessibility/guidelines
- Modèles :
  - Kenney Pirate Kit : https://kenney.nl/assets/pirate-kit
  - Quaternius Pirate Kit : https://quaternius.com/packs/piratekit.html
  - KayKit Forest : https://kaylousberg.itch.io/kaykit-forest
  - Meshy (tarifs) : https://www.meshy.ai/pricing
  - Synty POLYGON Pirate Pack : https://assetstore.unity.com/packages/3d/environments/historic/polygon-pirates-pack-92579

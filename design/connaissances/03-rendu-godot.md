# 03. Rendu dans Godot 4.3 à 4.7 : ce qui existe, ce qui marche, ce qu'on fait

> Recherche du 12/11/2026, pour la reprise totale du rendu (lumière, reflets, ombres, mouvement, textures, puis eau).
> Complète `design/bible-direction-artistique.md`. Rien ici n'est appliqué au jeu tant que la bible n'est pas validée.
> Les chiffres de performance sont des ordres de grandeur : **à mesurer** avec le profileur sur notre scène.
> `[à vérifier]` = information trouvée mais non confirmée par une source officielle ou un test.

## 0. En bref : les dix décisions que cette recherche soutient

1. **La caméra orthographique est une chance** : la stabilité « pixel » n'est soluble proprement qu'en ortho. Snapping
   de la caméra sur la grille des texels, puis décalage sous-pixel de l'image agrandie.
2. **Un seul matériau « maison »** (include `.gdshaderinc`) : paliers de lumière dans `light()`, ombres de nuages, vent,
   ambiance teintée. C'est là que se joue l'essentiel du rendu.
3. **Pas de GI temps réel** (SDFGI et VoxelGI non pris en charge en ortho) : ambiance colorée par heure, occlusion
   peinte dans les couleurs de sommets, lumières d'appoint.
4. **Ombres dures et stables** : 1 ou 2 découpes, filtre « Hard », distance max serrée, `shadow_caster_mask`.
5. **Contours** : le quad actuel suffit ; `CompositorEffect` seulement si les transparents posent problème.
6. **Ni SSR, ni brouillard volumétrique, ni TAA.** Reflets d'eau truqués, brume par profondeur (déjà faite).
7. **Vent global** en uniformes globaux, animation **à cadence réduite** (8 à 12 images/s).
8. **Voiles en formes clés** pilotées par la navigation, plus un frisson en vertex shader. Pas de tissu simulé.
9. **Eau : une seule fonction de vagues partagée GPU/CPU**, flottaison par sondes, temps synchronisé en coop, sillage
   dans une texture qui suit le bateau. La FFT n'apporte presque rien à 640x360.
10. **Post-traitement en basse résolution**, dans cet ordre : LUT d'ambiance, quantification palette, brume pleine.

---

## 1. Ce que Godot 4.3 à 4.7 apporte au rendu stylisé

### 1.1 Les nouveautés par version (rendu seulement)

| Version | Nouveautés utiles pour nous | Remarques |
|---|---|---|
| **4.3** (août 2024) | Compositor et `CompositorEffect` ; brouillard **par profondeur** (`FOG_MODE_DEPTH`, début et fin réglables) ; graphe de rendu acyclique (+5 à 15 % de FPS, plus avec beaucoup de `GPUParticles`) ; mode de fusion alpha prémultiplié (flamme additive + fumée dans la même particule) | base de notre brume actuelle |
| **4.4** (mars 2025) | Tonemapper **AgX** ; ubershaders (fin des saccades de compilation) ; interpolation physique **3D** ; `SpringBoneSimulator3D` ; `LookAtModifier3D` ; ombres de lightmap mixtes (shadowmask) ; **Shadow Caster Mask** sur les lumières ; mode « vertex shading » forcé | interpolation physique = mouvement fluide des bateaux sans augmenter les ticks |
| **4.5** (sept. 2025) | **Stencil buffer** (expérimental) ; **Shader Baker** à l'export (jusqu'à 20x plus rapide au démarrage sur Metal/D3D12) ; SMAA 1x ; occlusion spéculaire de la lumière ambiante ; bent normal maps | stencil lisible seulement en passe transparente |
| **4.6** (janv. 2026) | **SSR réécrit** (Hi-Z, demi ou pleine résolution) ; sondes de réflexion en **cartes octaédriques** (moins de mémoire) ; **glow appliqué avant le tonemapping**, mode Screen par défaut ; AgX réglable (`agx_white`, `agx_contrast`) ; debanding des matériaux 3D ; Jolt par défaut ; D3D12 par défaut sur les nouveaux projets Windows ; brouillard volumétrique plus lumineux | **changements de valeurs par défaut du glow** : à revérifier si on a migré |
| **4.7** (juin 2026) | `AreaLight3D` (lumières rectangulaires) ; sortie **HDR** ; mise à l'échelle 3D **au plus proche voisin** (`scaling_3d_mode`) ; `DrawableTexture2D` (dessiner dans une texture sans Viewport) ; particules 3D : échelle et rotation réglables ; aperçu des shaders en direct | `DrawableTexture2D` est très utile pour le sillage (§ 4.4) |

Sources : notes de version officielles 4.3 à 4.7 et guides de migration 4.6 et 4.7 (liens en fin de document).

### 1.2 Compositor et CompositorEffect

- Ressource `Compositor` posée sur le `WorldEnvironment` (tous les viewports) ou sur la `Camera3D` (un seul).
  Forward+ et Mobile seulement.
- Chaque `CompositorEffect` lance un **compute shader** (GLSL, `RenderingDevice`) à une étape précise :
  `PRE_OPAQUE`, `POST_OPAQUE` (avant le ciel), `POST_SKY`, `PRE_TRANSPARENT`, `POST_TRANSPARENT` (avant les
  post-traitements intégrés).
- Drapeaux : `needs_normal_roughness` (Forward+, tampon compressé à décoder), `needs_motion_vectors`.
- Tourne sur le **thread de rendu** (`Mutex`, `rd.free_rid`, `UniformSetCacheRD`). Le stencil n'y est **pas lisible**.

**Pour nous** : dessiner les contours **avant** les transparents (`POST_OPAQUE`) évite de « contourer » particules et
eau ; coût négligeable à 640x360. À étudier : « Godot Compositor - 3D Pixel Art » (PixelageGames, gratuit, 4.4) et la
conférence d'Acerola à la GodotCon 2025.

Squelette (doc officielle) :

```gdscript
func _render_callback(type, render_data):
    if type != EFFECT_CALLBACK_TYPE_POST_OPAQUE: return
    var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
    var size := buffers.get_internal_size()
    for view in buffers.get_view_count():
        var couleur := buffers.get_color_layer(view)
        # uniform set (UniformSetCacheRD), push constants, dispatch...
```

### 1.3 Lumière et ombres

- **DirectionalLight3D** : modes « Orthogonal » (une carte), PSSM 2 ou 4 découpes (4 par défaut ; un objet à cheval sur
  4 découpes est rendu 5 fois). En vue de dessus orthographique, la zone visible est petite : **1 ou 2 découpes**,
  `directional_shadow_max_distance` calée sur ce que voit la caméra (plus elle est basse, plus les ombres sont nettes et
  rapides).
- Filtre : réglage projet `rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality` sur **Hard** pour
  des bords francs (les filtres « soft » produisent un grain qui jure avec le pixel art). `shadow_blur` à 0.
- Biais : préférer `shadow_normal_bias` à `shadow_bias`. En ortho, ombres parfois dégradées : la démo Peltola conseille
  d'ajuster le `far` de la caméra ou la découpe 1 de la lumière.
- **Shadow Caster Mask** (4.4) : retirer l'herbe, les particules, les petits accessoires des ombres.
- Lanternes : beaucoup de lumières sans ombre ne coûtent presque rien en Forward+ ; **ombres sur 2 ou 3 lanternes clés**.
- Pas de projecteur de texture sur le soleil : les ombres de nuages se font dans le shader (§ 2.6).
- Retour d'expérience de Project Shadowglass : un soleil face à la caméra aplatit tout, il faut une **lumière d'appoint**
  ; un mauvais niveau d'ambiance efface les détails (joints de briques) ; les courbes d'atténuation par défaut
  « boueuses » brouillent la limite de l'ombre.

### 1.4 Illumination globale : quoi choisir pour une scène ouverte vue de dessus

| Technique | Coût | Dynamique | Avec caméra orthographique | Verdict pour nous |
|---|---|---|---|---|
| SDFGI | moyen à élevé | semi temps réel | **non pris en charge** (démo Peltola) | non |
| VoxelGI | moyen | temps réel | **non pris en charge** (idem) ; fuites sur murs fins | non |
| LightmapGI | quasi nul au rendu | précalculé | OK | seulement pour intérieurs fixes ; incompatible avec un cycle jour/nuit |
| ReflectionProbe | faible (mode « Once ») | optionnel | OK | une par zone si besoin de reflets métalliques |
| SSIL / SSAO | réglable | temps réel | historique de bugs en ortho (issue #49204, Godot 3) | SSAO léger **à tester** ; SSIL non |
| Ambiance (ciel ou couleur) | nul | oui | OK | **oui**, couleur par heure et météo |

Recommandation : « GI peinte ». Occlusion de contact précalculée dans les couleurs de sommets (déjà prévue par les
scripts Blender), lumière ambiante teintée (bleu-violet le jour pour des ombres froides), soleil chaud, et une lumière
d'appoint quand le soleil est face caméra.

### 1.5 Brouillard

- `FOG_MODE_DEPTH` (4.3) : ce qu'on a. Bon choix : gratuit, contrôlable, et appliqué dans les passes (donc sous la
  quantification si on le souhaite).
- **Brouillard volumétrique** (`FogVolume`) : Forward+ seulement, coût proportionnel à la surface d'écran couverte,
  volumes fins qui scintillent, aucun retour fiable en ortho. Vu de dessus, des nappes (quads transparents qui
  défilent) font aussi bien. **À éviter**, sauf effet ponctuel testé (île maudite).

### 1.6 Decals

`Decal` (Forward+ et Mobile) projette une texture sur tout ce qu'il touche : idéal pour les **transitions** que la bible
réclame (sable mouillé au bord de l'eau, terre sur les pavés, mousse, taches de goudron sur le pont), et pour les
**ombres de contact des sprites** sur un pont qui tangue. Pour le pixel art, régler
`rendering/textures/decals/filter` sur **Nearest** (même chose pour `light_projectors/filter`).

### 1.7 Reflets : SSR et sondes

- SSR réécrit en 4.6 (Hi-Z). Mais il ne voit que l'écran, ignore les transparents (notre eau en est un) et a un
  historique de rendus faux en ortho. **Non** pour l'eau.
- ReflectionProbe (octaédriques depuis 4.6) : pour le laiton ou les vitres, si besoin.

### 1.8 Glow, tonemapping, couleur

- Glow 4.6 : appliqué **avant** le tonemapping, mode Screen par défaut, intensité par défaut 0,3, niveaux par défaut
  changés. Pour « bloom seulement sur les lanternes » : matériau émissif à énergie > 1, `glow_hdr_threshold` autour de
  1,0, niveaux bas (1 à 3) pour un halo serré. Rendu à 640x360 puis agrandi, le halo devient naturellement « en pixels ».
- Tonemapping : AgX (4.4, réglable en 4.6) gère bien les hautes lumières mais désature les couleurs vives. Comme l'image
  finit **quantifiée sur une palette**, un tonemapper **linéaire** (ou AgX à contraste réglé) est plus prévisible. À
  trancher à l'œil sur 3 écrans types.
- `Environment.adjustment_color_correction` accepte une LUT 3D, mais avant notre brume : on garde la LUT en filtre.

### 1.9 Shaders : les outils qui comptent

- **`light()` personnalisé** : `LIGHT`, `LIGHT_COLOR` (inclut un facteur π), `ATTENUATION` (distance **et ombre**),
  `LIGHT_IS_DIRECTIONAL`, sortie `DIFFUSE_LIGHT` (à additionner `+=`). C'est là qu'on fait les paliers et l'ombre de
  nuages. Attention : `light()` ne tourne pas en `vertex_lighting` ni en `unshaded`.
- **`LIGHT_VERTEX`** (fragment) : position utilisée pour l'éclairage et les ombres, sans déplacer le fragment. C'est **la**
  clé pour l'herbe et les sprites : on éclaire tout le brin ou tout le personnage avec la valeur de son pied
  (technique de David Holland, devenue possible sans modifier le moteur grâce à la PR #91136).
- **Uniformes globaux** (`global uniform`, déclarés dans Paramètres du projet > Shader Globals) : vent, nuages, heure,
  couleur d'ambiance, partagés par tous les matériaux et réglés d'un seul `RenderingServer.global_shader_parameter_set`.
- **`#include "res://...gdshaderinc"`** : un tronc commun d'éclairage pour tous les matériaux.
- **Uniformes d'instance** (`instance uniform`) : une variation par objet (phase du vent, gonflement d'une voile)
  sans dupliquer le matériau.
- **Stencil** (4.5, expérimental) : un objet écrit une valeur, un autre la teste ; lecture seulement en passe
  transparente. Utile pour : silhouette du joueur derrière une voile ou un toit (effet « rayons X »), ou pour exclure
  les sprites des contours 3D (les sprites ont déjà leur contour dessiné).
- Les textures d'écran (`hint_depth_texture`, `hint_normal_roughness_texture`, `hint_screen_texture`) **poussent le
  matériau en passe transparente**, et les transparents ne sont **pas** dans les tampons profondeur et normales.

### 1.10 MultiMesh, particules, niveaux de détail

- `MultiMeshInstance3D` : des milliers d'instances en un appel, animées en vertex shader, variation par
  `INSTANCE_CUSTOM` (tutoriel officiel « Animating thousands of fish »). Un MultiMesh est éliminé (culling) **en bloc**
  : le découper en **tuiles** (par exemple 16 x 16 m) pour que le hors-écran ne coûte rien.
- `GPUParticles3D` : traînées, collisions (carte de hauteur pour la pluie), attracteurs, turbulence, sous-émetteurs,
  `amount_ratio` pour moduler l'émission.
- **Visibility ranges** (HLOD) et LOD automatique (meilleur depuis 4.6) : en ortho à zoom fixe, la distance varie peu ;
  utiles surtout pour les **îles lointaines** et le mode carte.

### 1.11 Performances et déploiement

- Ubershaders (4.4) + **Shader Baker** (4.5, option d'export) : à activer, sinon saccades à la première apparition d'un
  effet.
- D3D12 par défaut sur Windows depuis 4.6 pour les nouveaux projets (Vulkan reste valable) : tester les deux.
- **Mise à l'échelle 3D au plus proche (4.7)** : rendrait la 3D à 1/3 sans `SubViewport`, mais on perdrait le décalage
  sous-pixel de la couche 3D et notre filtre tournerait en pleine résolution. **On garde le SubViewport.**

---

## 2. La « 3D pixel art » de pointe dans Godot

### 2.1 Projets et démos de référence

| Projet | Ce qu'il montre | Version, licence | Intérêt pour nous |
|---|---|---|---|
| **David Holland**, « 3D Pixel Art Rendering » (article) | caméra stabilisée, contours profondeur + normales (4 voisins), reflets d'arête convexes seulement, herbe éclairée uniformément, ombres de nuages, eau avec réfraction et réflexions planaires, rayons de lumière en raymarching (1,7 ms sur GTX 1060) | Godot 4.3 modifié | **la** référence technique, recrée le style t3ssel8r |
| **Leo Peltola**, `Godot-3d-pixelart-demo` | shader de contour et reflet (post-traitement ou par objet) | Godot 4, Forward+, MIT | base de nos contours ; signale SDFGI/VoxelGI non pris en charge en ortho |
| **voithos**, `godot-smooth-pixel-camera-demo` | rendu 320x180 dans un SubViewport de 322x182, caméra aux pixels entiers, image décalée du reste sous-pixel | Godot 4.1+, MIT | recette exacte de notre caméra (en 2D, transposable) |
| **BradFitz66**, `Godot-3D-pixel-art-camera` | caméra sous-pixel 3D | GPL-3.0, **archivé** (renvoie vers un projet sourcehut) | historique seulement ; GPL incompatible avec un jeu fermé |
| **Project Shadowglass** (Starhelm Studios) | 3D pixel art en **perspective** stable, renderer Godot modifié, LUT, filtrage au plus proche, palette limitée mais brume en couleurs pleines | commercial | leçons d'éclairage et d'assets (§ 1.3, § 2.9) |
| **Texel Splatting** (Dylan Ebert, arXiv 2603.14587, mars 2026) | rendu dans une cubemap depuis une origine calée sur une grille, puis texels projetés à l'écran | article | explique pourquoi la perspective est dure et l'ortho facile |
| **CUBY** (LunarBlank, 14,99 $) | cubemaps, quantification, dithering, LUT, accumulation temporelle | Godot 4.5 à 4.7, Forward+ | 13 caméras : pensé pour la vue subjective, inutile en ortho |
| **PixelageGames** : « Compositor - 3D Pixel Art », « 3D PixelArt Vegetation » | contours en compute ; herbe et arbres stylisés | 4.4 / 4.5.1, gratuits, licence non précisée | à lire, pas à copier sans licence |

### 2.2 Stabilité de la caméra (le point qui fait « pro » ou « amateur »)

**Pourquoi l'ortho est soluble** : en orthographique, un déplacement de la caméra d'un texel décale *tous* les pixels de
exactement un pixel. En perspective, le proche bouge plus que le lointain : « le grouillement ne peut être résolu que
pour les projections orthographiques » (cité par l'article Texel Splatting).

**Recette** (Holland, d'après une vidéo 2D d'aarthifical ; voithos en 2D) :

1. Rendre la 3D dans un SubViewport de **(640 + 2) x (360 + 2)** : un pixel de marge de chaque côté.
2. Garder une position « lisse » de la caméra, la convertir dans le **repère de la caméra**, l'arrondir à la taille
   d'un texel sur les axes X et Y de l'écran, et placer la vraie caméra sur ce point arrondi.
3. Décaler l'image agrandie du **reste** (position lisse moins position arrondie), multiplié par le facteur d'échelle.

```gdscript
# Camera3D orthographique (keep_aspect = KEEP_HEIGHT, donc size = hauteur visible en mètres)
@export var affichage: Control      # TextureRect qui montre le SubViewport
@export var echelle := 3            # facteur entier
var pos_lisse: Vector3              # mise à jour en _process (cible interpolée + lissage)

func _placer():
    var texel := size / 360.0                      # mètres par pixel bas-résolution
    var b := global_transform.basis
    var l := b.inverse() * pos_lisse               # repère caméra
    var s := Vector3(roundf(l.x / texel) * texel, roundf(l.y / texel) * texel, l.z)
    global_position = b * s
    var reste := Vector2(l.x - s.x, -(l.y - s.y)) / texel   # en pixels bas-rés, Y écran vers le bas
    affichage.position = (-reste - Vector2.ONE) * echelle    # -1 : la marge
```

Pièges :

- **Jamais de rotation ni de zoom non entier** pendant le jeu : tout se remet à grouiller. Pour un « zoom », changer le
  facteur entier ou faire une transition en fondu.
- Les objets **mobiles** (bateaux, PNJ) restent soumis aux demi-pixels. Arrondir aussi leur position *affichée*
  (pas physique) à la grille des texels dans le repère caméra supprime le tremblement en diagonale signalé sur le forum
  Godot en 4.7 ; leurs rotations, elles, ne peuvent pas être stabilisées (acceptable).
- Activer l'**interpolation physique 3D** (4.4+) et suivre la cible dans `_process`, sinon saccades entre ticks.
- Le `Sprite3D` doit avoir `pixel_size = size / 360` (taille ortho divisée par la hauteur en pixels) pour qu'un pixel
  du sprite fasse un pixel d'écran (principe 4 de la bible : « une seule taille de pixel »). Filtrage `Nearest`.
- Densité des textures : à 40°, le sol est comprimé verticalement d'environ sin 40° ≈ 0,64 et les murs d'environ
  cos 40° ≈ 0,77. Viser 1 texel = 1 pixel en largeur, utiliser un filtrage au plus proche **avec** mipmaps
  (`Nearest Mipmap`) pour limiter le moiré sur les surfaces fuyantes.

### 2.3 Contours et reflets d'arête

Principe (Peltola, Holland) : sur l'image basse résolution, comparer chaque pixel à ses **4 voisins** :

- **profondeur** (écart positif = on est devant) : contour sombre de silhouette ;
- **normales** (`1 - dot(n, voisin)`, seulement si la profondeur est proche) : reflet clair d'un pixel sur les arêtes
  ; Holland ne garde que les arêtes **convexes** (produit vectoriel des normales voisines) ;
- teinter les deux avec la lumière (Holland) : contour plus clair côté soleil, plus sombre côté ombre.

Pièges connus :

- Seuils écrits en dur chez Peltola : les exposer en uniformes, régler par scène.
- **Transparents absents des tampons** : l'eau (qui lit la profondeur, donc transparente) n'est pas dans la profondeur
  lue par le quad. Conséquences : le fond marin peut recevoir des contours *à travers* l'eau, et la ligne de rivage n'a
  pas de contour. Solutions : contour de rivage dessiné **par l'eau elle-même** (elle connaît l'écart de profondeur :
  c'est déjà notre écume), ou effet en `CompositorEffect` placé avant les transparents.
- Holland a dû modifier le moteur pour que les objets contourés apparaissent dans la texture d'écran utilisée par la
  réfraction de l'eau. On évite la réfraction, donc le problème.
- L'herbe pollue la profondeur (contours autour de chaque touffe) : la sortir des contours (couche ou stencil) ou
  l'éclairer « à plat » pour que les contours ne se voient pas.
- Les sprites (alpha scissor, donc opaques) **reçoivent** des contours 3D en plus de leur contour peint : les exclure
  (stencil en 4.5+ : le sprite écrit 1, le quad ignore les pixels marqués).

### 2.4 Lumière en paliers et ombres « pixel »

Tronc commun proposé (`res://shaders/eclairage.gdshaderinc`), à inclure dans tous les matériaux du décor :

```glsl
global uniform sampler2D nuages_bruit;    // texture de bruit en répétition (Shader Globals)
global uniform vec2 nuages_vent;          // m/s
global uniform float nuages_force;        // 0 = ciel clair
varying vec3 pos_monde;                   // à remplir dans vertex() : (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz

float ombre_nuages(vec3 p) {
    float n = texture(nuages_bruit, p.xz * 0.008 + nuages_vent * TIME * 0.008).r;
    return 1.0 - nuages_force * step(0.55, n);       // seuil net = nuage « pixel »
}

void light() {
    float a = ATTENUATION;                            // distance + ombre portée
    if (LIGHT_IS_DIRECTIONAL) a *= ombre_nuages(pos_monde);
    float n = max(dot(NORMAL, LIGHT), 0.0) * a;
    float palier = n > 0.55 ? 1.0 : (n > 0.12 ? 0.55 : 0.0);   // 3 paliers
    DIFFUSE_LIGHT += palier * LIGHT_COLOR / PI;
}
```

- Le 3e palier (zéro) laisse voir la **lumière ambiante**, teintée bleu-violet : ce sont nos « ombres froides ».
- Holland : atténuation lissée du soleil (moins de scintillement d'ombre quand il bouge lentement), léger bruit sur les
  normales des grandes surfaces planes pour éviter le « popping ».
- **Ombres alignées sur les texels** : en fragment, arrondir `LIGHT_VERTEX` (et éventuellement `NORMAL`) sur la grille
  des texels de la texture, via les dérivées d'écran (shader « Texel Space Quantization »). Résultat : bords d'ombre
  qui suivent les pixels de la texture. Coût faible, mais artefacts d'auto-ombrage signalés : **expérimental**.
  La carte d'ombre elle-même reste du moteur (non modifiable sans recompiler).
- Le soleil qui tourne lentement fait « ramper » les bords d'ombre : faire avancer l'angle du soleil **par crans**
  (toutes les quelques secondes) plutôt qu'en continu.

### 2.5 Herbe pixel

- Holland : des **quads face caméra** (billboards) avec une texture de touffe, éclairés **uniformément** comme le sol :
  `LIGHT_VERTEX` = base du brin, `NORMAL` = normale du terrain. L'herbe prend l'ombre du mât au bon endroit, sans
  ombrage propre qui grouille.
- Répartition : `MultiMeshInstance3D` par tuile ; outils de placement : **Spatial Gardener** (MIT, pinceau, Godot 4.2+,
  un retour signale un correctif nécessaire en 4.6) ou **ProtonScatter** (MIT, règles, jugé lent par certains) ;
  sinon un petit script de Poisson-disk à nous.
- Vent par bruit en coordonnées monde (Hexaquo), interaction joueur par une position passée en uniforme (Hexaquo,
  « Stylized Multimesh Grass Shader »). Pour une **trace persistante**, écrire les passages dans une texture (§ 4.4).
- Ne pas faire projeter d'ombre à l'herbe (`cast_shadow = off`).

### 2.6 Ombres de nuages

Bruit en **uniforme global**, lu dans `light()` (Holland : `get_cloud_attenuation(world_pos)` dans un include, c'est le
code du § 2.4). Variante : décaler l'échantillon selon la direction du soleil pour que l'ombre s'étire avec l'heure
(forum Godot 4.6). Un plan de nuages en alpha scissor projette de vraies ombres, mais coûte une passe d'ombre. Appliquer
la même fonction à l'eau : la mer assombrie par les nuages donne beaucoup de vie.

### 2.7 Eau pixel (rendu)

- Holland : bandes horizontales alignées sur la vue (une texture procédurale), réfraction, réflexions planaires (plan
  de coupe oblique : **impossible sans modifier le moteur**, la projection personnalisée de `Camera3D` n'a jamais été
  intégrée).
- Notre version (4 tons, houle, écume au contact) est la bonne base ; ajouts au § 4.6.

### 2.8 Sprites dans la 3D

- Alpha **scissor** (pas de blend) : tri correct, ombres possibles, présence dans la profondeur.
- Ombres de billboard : la doc l'écrit, en mode billboard l'ombre **suit la caméra**, pas le soleil, et c'est indéfini
  avec plusieurs caméras. Solutions : pas d'ombre portée par le sprite + **decal d'ombre** allongée dans la direction du
  soleil (bible : « ombre portée dans la direction du soleil »), ou un maillage invisible non billboard qui ne fait
  que projeter l'ombre (`cast_shadow = shadows_only`).
- Éclairage des sprites : un shader de sprite **éclairé** dont le `LIGHT_VERTEX` est le pied du personnage, et dont la
  `light()` n'utilise que `ATTENUATION` : le personnage entier passe à l'ombre quand il passe sous la grand-voile, et
  prend la couleur du soleil et de l'ambiance. Les sprites partagent ainsi la lumière du décor (principe 4 de la bible).

### 2.9 Ce qui marche, et les pièges récurrents

Marche : basse résolution + agrandissement entier, caméra stabilisée, 2 ou 3 paliers, contours + reflets d'arête,
palette limitée **mais** brume et ciel en couleurs pleines (Shadowglass), modèles à arêtes franches (Holland),
animations à cadence réduite.

Pièges : assets lointains qui deviennent du « bruit pixelisé » (prévoir des versions simplifiées), dégradés qui tournent
au grain, ombres douces, transparents absents des tampons, tout mouvement de moins d'un pixel par image non quantifié.

---

## 3. Mouvement et vie

### 3.1 Un vent unique pour tout le monde

Le vent est déjà une donnée de jeu (navigation). On l'expose une fois en uniformes globaux : `vent_dir` (vec3 monde),
`vent_force` (0 à 1), `vent_temps` (horloge commune). Tous les shaders (végétation, voiles, drapeaux, nuages, herbe,
particules) lisent les mêmes valeurs : cohérence garantie, et en coop chaque client anime localement à partir de la
valeur synchronisée.

```glsl
global uniform vec3 vent_dir;
global uniform float vent_force;
uniform sampler2D rafales : repeat_enable;

void vertex() {
    vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float t = floor(TIME * 10.0) / 10.0;                  // 10 images/s : mouvement « pixel »
    float raf = texture(rafales, p.xz * 0.04 - vent_dir.xz * t * 0.15).r;
    float souplesse = COLOR.r;                            // peint dans Blender : 0 = rigide
    vec3 d = vent_dir * vent_force * (0.2 + raf) * souplesse;
    d += vent_dir * sin(t * 3.0 + p.x * 0.6 + p.z * 0.4) * 0.04 * souplesse;
    VERTEX += inverse(mat3(MODEL_MATRIX)) * d;
}
```

- Le masque de souplesse en **couleur de sommet** se peint dans les scripts Blender (tronc 0, palmes 1).
- Le vertex shader tourne aussi dans la passe d'ombre : les ombres bougent avec les feuilles.
- Quantifier le temps (et si possible l'amplitude) évite le scintillement sous-pixel ; c'est aussi ce que recommandent
  les auteurs du jeu présenté à la GodotCon 2025 (cadence réduite par asset pour un rendu « 2D »).

### 3.2 Végétation

Palmiers : balancement proportionnel à la hauteur au carré, plus frisson des palmes. Feuilles en billboards (Holland)
seulement pour quelques arbres « héros ». Shaders prêts : « Wind Area Effect », « Pixel Art Wind Sway » (godotshaders).

### 3.3 Voiles qui gonflent

| Option | Coût | Contrôle | Stabilité pixel | Coop | Verdict |
|---|---|---|---|---|---|
| **Formes clés** (shape keys Blender : ferlée, à plat, gonflée, faseyante) pilotées par `set_blend_shape_value` | très faible | total, lié au modèle de navigation | excellente | trivial (état synchronisé) | **oui, base** |
| **Vertex shader** : gonflement `force * sin(π u) * sin(π v)` le long de la normale, plus ondulation près de la chute quand la voile faseye | faible | bon (uniforme d'instance) | bonne si quantifié | trivial | **oui, en complément** |
| `SpringBoneSimulator3D` sur une voile riggée | faible à moyen | moyen | moyenne | local | pour pavillons et coins libres |
| `SoftBody3D` (tissu, Jolt) | élevé (subdivision, précision) | faible | mauvaise (bruit) | non déterministe ; pas d'interpolation physique | **non** |

Le gonflement doit **lire l'angle vent/voile** du modèle de navigation : vent arrière = gonflée, près du vent = tendue,
vent de face = faseye. C'est un signal de gameplay lisible (on voit qu'on navigue mal).

### 3.4 Drapeaux, pavillons, cordages, lanternes

- **Pavillons** : vertex shader « drapeau » (tutoriel GDQuest « flag shader 3D ») : vague qui part de la hampe,
  amplitude croissante avec `UV.x`, vitesse et direction lues dans le vent global. Inverser la normale pour la face
  arrière.
- **Cordages fixes** (haubans, enfléchures) : maillages générés dans Blender avec un léger ventre ; rien à simuler.
  Les cordes **molles** (écoutes) : petite ondulation en vertex shader.
- **Cordes dynamiques** (grappin, ancre, abordage) : intégration de Verlet. Addon `verlet-rope-4` (MIT, C#, collisions
  par rayons, vent intégré) ou ~60 lignes de GDScript à nous si le projet n'est pas en C#.
- **Lanternes suspendues, filets, linge** : `SpringBoneSimulator3D` (4.4), avec `external_force` = vent ; pas de
  physique, retour à la pose de repos.

### 3.5 Particules

- **Embruns d'étrave** : `GPUParticles3D` à l'étrave, `amount_ratio` proportionnel à la vitesse et à la houle, billboards
  alignés sur la vitesse, durée de vie courte. GodotOceanWaves fait apparaître les embruns là où il y a de l'écume.
- Poussière, feuilles, pluie, étincelles de canon, fumée (mode prémultiplié pour flamme + fumée).
- **Pixel art** : texture au plus proche, tailles multiples de `pixel_size`, flipbooks à faible cadence (Holland les
  génère dans **Pixel Composer**), `fog_disabled` sur les particules additives.

### 3.6 PNJ

- `AnimatedSprite3D` en 4 ou 8 directions, 8 à 12 images/s.
- Vie à bas coût en shader de sprite : respiration (1 pixel), rebond de marche, roulis hérité du pont.
- Foules du port : un `MultiMesh` de quads, indice de frame en `INSTANCE_CUSTOM`.

---

## 4. Eau dynamique (pour plus tard)

### 4.1 Ce qui existe

| Projet | Technique | État | Flottaison | Notes |
|---|---|---|---|---|
| **GodotOceanWaves** (2Retr0) | FFT inverse (Stockham, compute), spectre TMA/JONSWAP, cascades, écume par Jacobien (accumulation et décroissance), embruns en GPUParticles | MIT, actif | **non** | les images où le pipeline tourne « saccadent encore » ; une cascade mise à jour par image |
| **godot4-oceanfft** (tessarakkt) | FFT de Tessendorf (compute), spectre unifié, quadtree CDLOD, réfraction, SSS, effet sous-marin basique | MIT, Godot 4.3+, « travail en cours » | basique | l'autrice prépare un addon océan monde ouvert |
| **Boujie Water Shader** | Gerstner, maillage multi-LOD qui suit la caméra, écume | MIT, Godot 4.1+, peu mis à jour | non | bonne base d'océan infini simple |
| **Ocean3D** (Codeberg) | vagues calculées **identiques** sur CPU et GPU, `FloatingBody` (RigidBody, CharacterBody, AnimatableBody, Node3D) | Godot 4 ; code annoncé comme assisté par IA | **oui** | API `height()` / `normal()` : le bon modèle d'architecture |
| Démo forum « Endless Ocean with Buoyancy » | 28 vagues de Gerstner tuilées, flottaison CPU | tous renderers | oui | |
| Démo officielle **Compute Texture** | équation d'ondes en compute (ping-pong de 3 textures), ronds dans l'eau à la souris | MIT, 4.2+, Forward+ | — | base des ondulations interactives |

### 4.2 Gerstner ou FFT, pour nous ?

- La FFT donne une mer réaliste et « choppy », mais : coût GPU, cascades délicates, et surtout **lecture GPU vers CPU**
  pour la flottaison (latence, blocages ; le transfert de textures est justement ce qui a fait échouer l'essai asynchrone
  de 2Retr0). La seule parade est de recalculer sur le CPU les basses fréquences.
- À 640x360 vu de dessus, une vague de moins de ~2 pixels devient du **bruit** : le détail haute fréquence de la FFT
  disparaît ou scintille.
- **Recommandation** : rester sur une **somme de 4 à 8 vagues** (Gerstner ou notre exp-sinus), écrite **deux fois** à
  l'identique : un `.gdshaderinc` et une fonction GDScript `hauteur(x, z, t)`. Le « réalisme » vient de la houle qui
  soulève les bateaux, de l'écume et du sillage, pas du spectre. La FFT reste une option pour une tempête
  spectaculaire, plus tard.

### 4.3 Flottaison

- **4 à 8 sondes** par coque (proue, poupe, flancs, plus si la coque est longue) ; à chaque tick physique, pour chaque
  sonde immergée : force vers le haut proportionnelle à l'enfoncement, appliquée **à la position de la sonde**
  (`apply_force(f, sonde - centre)`), plus amortissement vertical et traînée latérale (quille). Une seule sonde = le
  bateau monte et descend sans s'incliner (piège classique).
- `RigidBody3D` sous Jolt (par défaut depuis 4.6) ; Ocean3D conseille de désactiver ses modes d'inclinaison visuelle
  avec un RigidBody.
- **Coop** : l'hôte simule, les clients interpolent ; le **temps des vagues** doit être celui du serveur, sinon chacun voit
  une mer différente et les bateaux flottent au-dessus ou sous l'eau.
- Variante « arcade » si la physique devient capricieuse en réseau : bateau cinématique, hauteur et tangage tirés des
  sondes et filtrés par ressorts. Petits objets : une sonde suffit.

### 4.4 Écume, sillage, interaction

- **Écume de rivage** : profondeur sous l'eau (déjà fait) ; pour la stabilité, préférer une **carte de distance au
  rivage** précalculée par île (pas de scintillement quand la houle bouge).
- **Écume de crête** : là où la vague se resserre (Jacobien < 1 en Gerstner, comme la FFT) ou simplement au sommet.
- **Sillage persistant** : une texture monde centrée sur le joueur (par exemple 256 x 256 pour 64 x 64 m) où l'on
  « tamponne » l'écume du sillage et des remous à chaque image, puis qu'on fait décroître. Trois façons :
  `DrawableTexture2D` (4.7, `blit_rect` avec matériau, expérimental), un SubViewport orthographique « vue de dessus »
  qui ne voit qu'une couche d'émetteurs d'écume, ou un compute shader. Le shader de l'eau la lit en coordonnées monde.
  C'est la méthode à laquelle aboutit le fil du forum Godot sur les sillages de navire.
- **Ondulations interactives** (boulets qui tombent, nageurs) : équation d'ondes en compute (démo Compute Texture) dans la
  même texture, qui perturbe normales et écume.

### 4.5 « Volumétrique » et sous-marin

En vue de dessus, « volumétrique » veut dire : **absorption** selon l'épaisseur d'eau (Beer-Lambert par canal, à partir de
l'écart de profondeur déjà lu), fond visible près des côtes, **caustiques** projetées sur le fond (dans le shader du
terrain, par position monde, ou en decal), et légère déformation du fond. Un vrai rendu sous-marin (caméra sous la
surface, FogVolume, rayons) ne sert que si le gameplay plonge ; tessarakkt n'a qu'un effet sous-marin « basique ».

### 4.6 L'adapter au pixel art

- Couleurs : garder les **4 tons**, transitions en **dither ordonné** (Bayer 4x4) plutôt qu'en dégradé ; l'écume en
  traits d'un pixel.
- Maillage : grille qui **suit la caméra**, déplacée par pas entiers de maille (sinon les sommets « nagent »), densité
  calée sur la vue (environ un sommet tous les 0,5 m) au lieu d'un plan de 200 m uniforme.
- Mouvement : animer les motifs de surface à cadence réduite ; la houle (déplacement des sommets) peut rester continue.
- Reflets : **pas de SSR, pas de réflexion planaire.** Scintillements du soleil (seuil sur la normale, quelques pixels
  blancs), **traînées verticales** des lanternes (quads additifs posés sur l'eau sous chaque lumière, ondulés par la
  normale), assombrissement par les nuages (§ 2.6).
- Contour de rivage dessiné par l'eau elle-même (§ 2.3).

### 4.7 Feuille de route eau

1. Fonction de vagues partagée GPU/CPU + horloge serveur.
2. Flottaison par sondes (bateaux puis objets).
3. Grille qui suit la caméra ; carte de distance au rivage.
4. Sillage et remous dans une texture monde ; embruns d'étrave.
5. Absorption, caustiques, faux reflets.
6. (Option) tempête : vagues plus hautes, pluie, éclairs ; FFT seulement si tout le reste ne suffit pas.

---

## 5. Jeux à étudier et chaînes de référence

### 5.1 Jeux faits avec Godot

| Jeu | Pourquoi le regarder |
|---|---|
| **Cassette Beasts** (Bytten Studio) | Le plus proche de nous : personnages en **sprites pixel art dans un monde 3D**, caméra fixe, tuiles 3D modélisées dans un éditeur voxel (Qubicle) pour coller aux sprites. Les auteurs ont dû **patcher le moteur** pour gagner des images. La suite (2002) passe en caméra troisième personne en gardant des sprites en billboard. |
| **Project Shadowglass** (en développement) | 3D pixel art en perspective, renderer modifié ; leçons d'éclairage et de lisibilité (§ 1.3, § 2.9). |
| **Rift Riff** | Projet 3D stylisé en Godot 4 vitrine officielle ; ses auteurs ont contribué aux correctifs Vulkan Mobile de 4.6 : Godot 4 en 3D tient sur mobile. |
| **DOGWALK** (Blender Studio) | Pipeline Blender → glTF → Godot pour une 3D stylisée « papier découpé » ; sources accessibles aux abonnés Blender Studio ; conférence « Making of DOGWALK » (GodotFest 2025). |
| **Buckshot Roulette** | Très basse résolution, peu de lumières, ambiance forte : la retenue paie. |

Hors Godot mais incontournables (déjà dans la bible) : t3ssel8r (Unity, la référence 3D pixel art), Sable, Dredge,
Eastward, Octopath (HD-2D).

### 5.2 Chaînes, blogs et tutoriels

| Source | Contenu utile | Vérifié |
|---|---|---|
| **David Holland** (blog) | l'article de référence du § 2 | oui |
| **GDQuest** | cours et tutoriels shaders 2D/3D (dont « flag shader 3D »), dépôt `godot-shaders` (toon avancé, eau, feu) | oui |
| **FencerDevLog** | plus de 125 tutoriels de shaders Godot 4 (surtout 2D et post-traitement : Sobel, flou, glow, brouillard 2D), un tutoriel shader sous-marin | oui |
| **Acerola** | conférence GodotCon 2025 sur les `CompositorEffect` ; chaîne de référence en techniques graphiques | oui |
| **Hexaquo** (blog) | série herbe (rendu, vent, interaction), article sur les `light()` toon | oui |
| **Crigz vs Game Dev** | shaders, physique, animation procédurale ; portage d'un shader d'ondulations d'eau Unity vers Godot | oui |
| **StayAtHomeDev**, **Bramwell Williams** | créateur présent à la GodotCon 2025 ; cours Godot 4 avec shaders d'eau | partiel |
| **godotshaders.com** | bibliothèque : contours pixel art, herbe MultiMesh, nuages, eau pixel, sillage, texel quantization | oui (qualité variable) |
| Nathan Hoad, Pixezy | non retrouvés sur le rendu 3D dans mes recherches : à confirmer par Jimmy | non |
| t3ssel8r (Unity) | vidéos de référence du style ; pas de code, mais tout est expliqué visuellement | oui |

---

## 6. Architecture de rendu recommandée pour notre jeu

### 6.1 Les passes, dans l'ordre

**A. Préparation (CPU, `_process`)**
1. Horloge et état partagés : vent, heure, météo, temps des vagues (synchronisés en coop) poussés en uniformes globaux.
2. Caméra : position lisse, puis snapping texel et calcul du reste sous-pixel (§ 2.2). Positions *affichées* des objets
   mobiles arrondies à la grille.

**B. Monde 3D dans le SubViewport 642 x 362 (Forward+)**

3. Ombres du soleil : 1 ou 2 découpes, filtre Hard, distance max serrée, masque de projecteurs (sans herbe ni
   particules). 2 ou 3 lanternes ombrées maximum.
4. Pré-passe profondeur + normales (opaques : décor, bateaux, sprites en alpha scissor).
5. Opaques avec **le matériau commun** : paliers de lumière, ombre de nuages, vent en vertex, `LIGHT_VERTEX` pour herbe
   et sprites, couleurs de sommets (occlusion peinte), textures au plus proche. Ambiance teintée par l'Environment.
6. (Option) `CompositorEffect` `POST_OPAQUE` : contours et reflets d'arête, si l'on quitte le quad.
7. Ciel (dégradé simple ou couleur par heure).
8. Transparents : eau (houle, écume, sillage, absorption, faux reflets), quad de contours (tant qu'il existe),
   particules, fumée, traînées de lanternes.
9. Brume par profondeur (Environment), glow serré sur les émissifs, tonemapping linéaire (ou AgX réglé).

**C. Post-traitement en basse résolution (canvas_item sur la texture 640 x 360)**

10. LUT d'ambiance (heure, météo, biome).
11. Quantification sur la palette maître (avec dither ordonné optionnel).
12. Brume et ciel en **couleurs pleines** (masque par profondeur ou par couche), vignette légère.

**D. Affichage**

13. Agrandissement entier au plus proche voisin + décalage sous-pixel ; interface en pleine résolution par-dessus.

### 6.2 Matériau ou post-traitement ?

| Effet | Où | Pourquoi |
|---|---|---|
| Paliers de lumière, ombres froides, ombre de nuages | matériau (`light()` + include) | dépend de la normale et de l'ombre réelle ; impossible proprement en post |
| Vent, voiles, drapeaux, herbe | matériau (vertex) | déplace la géométrie, donc les ombres |
| Écume, sillage, absorption, faux reflets, contour de rivage | matériau de l'eau | l'eau connaît sa profondeur ; elle n'est pas dans les tampons |
| Contours de silhouette, reflets d'arête | post (quad ou Compositor) | besoin des voisins dans les tampons |
| LUT, palette, dither, brume pleine | post basse résolution | une seule fois, sur 230 000 pixels |
| Ombres de sprites, transitions de matériaux | decals | projetées sur tout, y compris le pont qui tangue |

### 6.3 Budget de performance (cible 60 images/s, PC milieu de gamme type GTX 1060)

À 640 x 360, le coût par pixel est minuscule : **le goulot sera le CPU** (nombre d'objets, appels de rendu, GDScript) et
**la passe d'ombre** (géométrie rendue une fois de plus par découpe). Ordres de grandeur à confirmer au profileur :

| Poste | Budget indicatif |
|---|---|
| Ombres du soleil (1 à 2 découpes, 2048 à 4096) | 0,5 à 1,5 ms GPU |
| Pré-passe + opaques | 1 à 2 ms GPU |
| Eau (vertex + fragment) | < 0,5 ms GPU |
| Contours, post basse résolution | < 0,3 ms GPU au total |
| Particules (quelques milliers) | < 0,3 ms GPU |
| **Total GPU visé** | **≤ 5 ms** |
| Appels de rendu | **< 1 500** (moniteur « Draw Calls ») : fusionner le décor statique par île, MultiMesh par tuile pour les répétitions |
| CPU rendu + scripts | ≤ 8 ms |

En coop sur écran partagé (si jamais), tout le bloc B est payé deux fois : le budget ci-dessus le permet.

### 6.4 À éviter

- SDFGI, VoxelGI, SSIL ; LightmapGI en extérieur (cycle jour/nuit) ; SSR et réflexions planaires.
- Brouillard volumétrique global ; TAA, FSR, MSAA (flou, traînées) : pas d'antialiasing du tout.
- Filtrage linéaire, ombres « soft », rotation ou zoom non entier de la caméra.
- `SoftBody3D` pour les voiles ; FFT avant d'avoir épuisé Gerstner.
- Alpha blend sur le décor ; ombres de sprites en billboard ; un shader différent par objet.
- Des dizaines d'omni ombrées ; un glow à seuil bas.
- Oublier le Shader Baker à l'export et les nouvelles valeurs par défaut du glow après migration.

### 6.5 Ordre de mise en œuvre proposé

1. Caméra stabilisée (snapping + décalage) et `pixel_size` des sprites : tout le reste se juge mieux une fois stable.
2. Include d'éclairage commun : paliers, ambiance teintée, réglage des ombres (Hard, découpes, distance).
3. Contours : seuils exposés, exclusion des sprites et de l'herbe, contour de rivage par l'eau.
4. Post basse résolution : LUT → palette → brume pleine.
5. Vent global + végétation + pavillons ; puis voiles en formes clés.
6. Ombres de nuages, decals de transition et ombres de sprites.
7. Particules (embruns, poussière) ; PNJ « vivants ».
8. Eau dynamique selon § 4.7.

---

## Sources

**Godot, officiel**
- Notes de version : [4.3](https://godotengine.org/releases/4.3/), [4.4](https://godotengine.org/releases/4.4/), [4.5](https://godotengine.org/releases/4.5/), [4.6](https://godotengine.org/releases/4.6/), [4.7](https://godotengine.org/releases/4.7/)
- Migration : [vers 4.6](https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html), [vers 4.7](https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html)
- [The Compositor](https://docs.godotengine.org/en/stable/tutorials/rendering/compositor.html), [CompositorEffect](https://docs.godotengine.org/en/stable/classes/class_compositoreffect.html)
- [Spatial shaders (LIGHT_VERTEX, light(), stencil)](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)
- [Introduction à l'illumination globale](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/introduction_to_global_illumination.html), [LightmapGI](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/using_lightmap_gi.html)
- [Lumières et ombres 3D](https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html), [Brouillard volumétrique](https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html)
- [Visibility ranges](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html), [Limites du rendu 3D](https://docs.godotengine.org/en/stable/tutorials/3d/3d_rendering_limitations.html)
- [Animating thousands of fish (MultiMesh)](https://docs.godotengine.org/en/stable/tutorials/performance/vertex_animation/animating_thousands_of_fish.html)
- [SpringBoneSimulator3D](https://docs.godotengine.org/en/stable/classes/class_springbonesimulator3d.html), [SoftBody3D](https://docs.godotengine.org/en/stable/tutorials/physics/soft_body.html), [SpriteBase3D](https://docs.godotengine.org/en/stable/classes/class_spritebase3d.html), [DrawableTexture2D](https://docs.godotengine.org/en/latest/classes/class_drawabletexture2d.html)
- [PR #79731 : mise à l'échelle 3D au plus proche](https://github.com/godotengine/godot/pull/79731), [issue #49204 : SSR/SSAO en orthographique (3.x)](https://github.com/godotengine/godot/issues/49204)
- [Démo Compute Texture](https://github.com/godotengine/godot-demo-projects/tree/master/compute/texture)
- [Vitrine officielle](https://godotengine.org/showcase/), [Cassette Beasts](https://godotengine.org/article/godot-showcase-cassette-beasts/), [DOGWALK](https://godotengine.org/article/godot-showcase-dogwalk/)
- GodotCon 2025 : [Acerola, Compositor Effects](https://talks.godotengine.org/godotcon-us-2025/talk/UAQ7H9/), [Making Stylized 3D Games In Godot](https://talks.godotengine.org/godotcon-us-2025/speaker/WBZLLN/)

**3D pixel art**
- [David Holland, 3D Pixel Art Rendering](https://davidholland.netlify.app/articles/3d-pixel-art-rendering)
- [leopeltola/Godot-3d-pixelart-demo](https://github.com/leopeltola/Godot-3d-pixelart-demo), [shader de contour sur godotshaders](https://godotshaders.com/shader/3d-pixel-art-outline-highlight-post-processing-shader/)
- [voithos/godot-smooth-pixel-camera-demo](https://github.com/voithos/godot-smooth-pixel-camera-demo), [BradFitz66/Godot-3D-pixel-art-camera](https://github.com/BradFitz66/Godot-3D-pixel-art-camera)
- [Interview Project Shadowglass (80.lv)](https://80.lv/articles/interview-how-project-shadowglass-creates-its-impossible-fully-3d-pixel-art-look)
- [Texel Splatting, D. Ebert (arXiv 2603.14587)](https://arxiv.org/abs/2603.14587)
- [CUBY](https://lunarblank.itch.io/cuby), [PixelageGames Compositor 3D Pixel Art](https://pixelagegames.itch.io/godot-compositor-3d-pixel-art), [PixelageGames Vegetation](https://pixelagegames.itch.io/3d-pixelart-vegetation)
- [Texel Space Quantization](https://godotshaders.com/shader/texel-space-quantization/), [fil « sprite jitters 2.5D », Godot 4.7](https://forum.godotengine.org/t/pixel-art-sprite-jitters-while-moving-in-a-2d-gameplay-in-a-3d-world-2-5d-setup-godot-4-7/145750)
- [Flexible Toon Shader (port Godot 4)](https://github.com/atzuk4451/FlexibleToonShaderGD-4.0), [Hexaquo, light shaders toon](https://hexaquo.at/pages/understanding-godot-light-shaders-and-light-calculations-by-implementing-a-toon-light-shader/)

**Mouvement**
- [Hexaquo, herbe partie 3 (vent, interaction)](https://hexaquo.at/pages/grass-rendering-series-part-3-animating-and-interacting-with-grass-in-godot/), [Stylized Multimesh Grass](https://godotshaders.com/shader/stylized-multimesh-grass-shader/)
- [Spatial Gardener](https://github.com/dreadpon/godot_spatial_gardener), [ProtonScatter](https://github.com/HungryProton/scatter)
- [GDQuest, flag shader 3D](https://gdquest.com/tutorial/godot/shaders/flag-shader-3d), [Wind Area Effect](https://godotshaders.com/shader/wind-area-effect/), [Pixel Art Wind Sway](https://godotshaders.com/shader/pixel-art-wind-sway-meshinstance3d-godot-4-0/)
- [verlet-rope-4](https://github.com/Tshmofen/verlet-rope-4)
- [Simulating Cloud Shadows Analytically](https://godotshaders.com/shader/simulating-cloud-shadows-analytically/), [fil ombres de nuages étirées](https://forum.godotengine.org/t/how-to-make-texture-stretch-in-direction-of-light/138203)

**Eau**
- [2Retr0/GodotOceanWaves](https://github.com/2Retr0/GodotOceanWaves), [tessarakkt/godot4-oceanfft](https://github.com/tessarakkt/godot4-oceanfft), [Boujie Water Shader](https://github.com/Chrisknyfe/boujie_water_shader), [Ocean3D](https://codeberg.org/alvlp/Ocean3D)
- [WIP Ocean, buoyancy](https://forum.godotengine.org/t/wip-ocean-buoyancy-dynamic-weather-and-seagulls/143553), [Endless Ocean with Buoyancy](https://forum.godotengine.org/t/endless-ocean-with-buoyancy-all-renderes-supported/144369)
- [Sillage : fil du forum](https://forum.godotengine.org/t/rendering-gpuparticles2d-onto-a-3d-plane/81460), [Water Trail](https://godotshaders.com/shader/water-trail/), [Pixel Art Water Shader](https://godotshaders.com/shader/pixel-art-water-shader/)

**Chaînes et tutoriels**
- [Liste des tutoriels FencerDevLog](https://forum.godotengine.org/t/godot-4-shaders-a-list-of-video-tutorials/36500), [Crigz : portage d'un shader d'ondulations (80.lv)](https://80.lv/articles/tutorial-porting-a-water-ripple-shader-from-unity-to-godot), [GDQuest](https://gdquest.com/)
- [Cassette Beasts 2002 (Creative Bloq)](https://www.creativebloq.com/features/cassette-beasts-2002-is-pokemon-in-a-zone-6-suburb-with-no-paddington-and-not-a-wizard-in-sight)

# Recherche documentaire : îles, trésors, ennemis

Document de recherche pour la refonte des îles du jeu de pirates coopératif (Godot 4, caméra orthographique inclinée, low poly peint).
Date de la recherche : 13 novembre 2026. Sources en anglais et en français, listées avec leurs URL en fin de document.

## Comment lire ce document

- Chaque partie se termine par des **règles** ou des **procédures** applicables telles quelles.
- Trois niveaux de confiance sont signalés :
  - **[Source]** : fait lu dans une source citée en partie (d).
  - **[Fan]** : chiffre issu d'un wiki, d'un guide ou d'une mesure de joueurs, pas d'un document officiel.
  - **[Proposition]** : valeur que je propose pour notre jeu, déduite des sources mais non mesurée. À régler en jeu.
- `[À VÉRIFIER : …]` marque ce que la recherche n'a pas permis de confirmer.

## Le constat de départ, reformulé en problèmes de conception

| Ce que dit le joueur | Problème de conception | Parties qui y répondent |
|---|---|---|
| Îles plates et petites | Aucune silhouette, aucun choix de chemin, rien n'est caché par le relief | 1, 2, 3 |
| Deux ennemis « débiles » | Pas de rôles, pas de télégraphie, pas de coordination | 6 |
| Coffre posé par terre, ramassé en une seconde | Récompense sans recherche ni épreuve | 5 |
| On repart aussitôt | Pas de boucle de parcours, pas de raison de revenir | 1, 7 |
| « Sans âme » | Pas d'identité par île (biome, repère, histoire lisible) | 1, 4 |

---

## 1. Concevoir une île

### 1.1 Ce que font les jeux de référence

**Sea of Thieves (Rare).** Les îles sont faites à la main, pas générées, et chacune a une fonction : baie pour cacher un navire, réseau de grottes pour semer un poursuivant, etc. [Source : PCGamesN]. Le wiki compte 74 îles cartographiées : 25 grandes, 39 petites, 10 forts de squelettes, réparties en 4 régions de 15 à 20 îles [Fan : wiki]. Seules les grandes îles reçoivent des cartes à énigmes, parce qu'il faut assez de repères uniques pour écrire des énigmes [Fan : wiki]. La taille du monde est réglée sur un objectif de rythme : croiser un autre navire toutes les 15 à 30 minutes environ [Source : interview Rare reprise par GamingBolt et WCCFTech]. Une mesure de joueurs sur la bêta donne environ 18,8 km² de carte [Fan : forum officiel]. `[À VÉRIFIER : dimensions en mètres d'une grande île de Sea of Thieves, aucune source fiable trouvée]`.

**Zelda Breath of the Wild (Nintendo, conférence CEDEC 2017).** Trois idées directement transposables :
- La première version reliait des tours par des routes jalonnées d'événements. Résultat des tests : environ 80 % des joueurs suivaient le même couloir, 20 % erraient. Nintendo a abandonné les « points et lignes » pour des repères qui attirent de loin [Source : Game Maker's Toolkit, « How Nintendo Solved Zelda's Open World Problem »].
- La **règle du triangle** : le relief est fait de formes triangulaires. Un triangle pose un choix (grimper ou contourner), attire l'œil vers son sommet où l'on place une récompense, et cache ce qu'il y a derrière. En s'approchant, on découvre deux ou trois nouveaux lieux.
- La **« gravité »** : chaque type de lieu a une signature visible de loin (colonne de fumée d'un feu de camp, rocher en forme de crâne pour un camp ennemi, tête de cheval géante pour une écurie) et une force d'attraction différente selon ce que le joueur cherche à ce moment.

**Zelda Wind Waker.** Carte de 7 × 7 = 49 cases, une île ou un groupe d'îles par case [Fan : Zelda Dungeon]. Leçon négative : une bonne partie des cases ne contient qu'un récif ou une plate-forme à un seul usage, ce qui est le reproche le plus fréquent fait au jeu. Leçon positive : les grottes secrètes (un trou sombre dans lequel on tombe) et les cartes au trésor donnent une deuxième couche à des îles minuscules.

**Assassin's Creed IV Black Flag.** L'intention affichée de l'équipe : pas d'activités « posées là sans raison », et un monde fait de petites villes, d'îles et de fonds sous-marins intégrés [Source : interview Ashraf Ismail, PC Gamer]. Le jeu d'origine compte 22 cartes au trésor menant à des coffres enterrés [Fan : guide]. Une analyse avance que la plupart des îles se traversent en moins de trois minutes : la sensation d'immensité vient de la mer et de la variété, pas de la surface `[À VÉRIFIER : source de faible qualité]`.

**Tunic.** La caméra orthographique fixe est l'outil principal du secret : des passages existent dès le début derrière un mur ou un pont, simplement invisibles sous cet angle [Source : blog Unity, Game Developer]. Le créateur distingue un vrai secret d'un simple objet à collectionner, et suit le principe « adoucir les portes dures » : mieux vaut un obstacle qu'on peut contourner avec de l'adresse qu'une porte fermée à clé.

**Sid Meier's Pirates!** Les morceaux de carte s'assemblent et montrent des repères ; à terre, on navigue de repère en repère. En difficulté haute, la caméra se rapproche : il faut être plus près d'un repère pour le voir [Fan : guides].

**Raft.** Une dizaine de petites îles faites à la main, puis des grandes îles débloquées par la progression, puis des îles d'histoire uniques avec énigmes [Fan : wiki et forum Steam]. La variété arrive par paliers, pas d'un coup.

**Windbound (contre-exemple).** Îles générées au lancement, biomes ajoutés chapitre après chapitre. Reproche récurrent des tests : les îles des deux premiers chapitres se ressemblent toutes, « jamais les mêmes, sauf qu'elles le sont » [Source : critiques Well Played, TheSixthAxis]. Le procédural seul ne donne pas d'identité.

### 1.2 Les outils du level designer

- **Weenie** (terme de Walt Disney) : un grand repère visible de loin qui attire et oriente, comme le château au centre du parc [Source : Game Developer, « What Mario Learned from Mickey Mouse »].
- **Refus puis récompense** (denial and reward) : montrer le but, faire passer le joueur par un chemin où il le perd de vue, puis le lui remontrer de plus près [Source : Unity, « Level design basics »].
- **Leurre** (bait and switch) : tout mène à une grille fermée ; en se retournant, on voit le vrai passage.
- **Portes et clapets** : une porte (gate) bloque tant qu'une condition n'est pas remplie ; un clapet (valve) empêche de revenir en arrière, par exemple un saut depuis une corniche [Source : blog du CDM].
- **Chemin critique** : le trajet minimal pour finir. **Boucle de retour** (loopback) : un parcours linéaire qui revient à son point de départ, forme classique des donjons en monde ouvert [Source : The Level Design Book].
- **Savoir où l'on est et comment aller où l'on veut** : c'est la définition de base de l'orientation ; un repère à l'horizon est le premier moyen [Source : Unity, version française].

### 1.3 Règles pour une île

1. **Test de la silhouette.** Depuis le pont du bateau, une île doit se reconnaître à sa forme seule, en noir sur fond de ciel. Une île = un profil unique (deux cornes, un doigt de pierre, un plateau, un cratère, une arche).
2. **Un grand repère et deux ou trois repères moyens.** Le grand se voit de la mer ; les moyens se découvrent en marchant et ne sont jamais tous visibles en même temps (règle du triangle).
3. **Signature par type de lieu.** Fumée = camp ; mât à pavillon noir = bande de pirates ; lueur bleue = entrée de grotte ; mouettes qui tournent = épave. Le joueur apprend ce code une fois et lit ensuite toutes les îles.
4. **Deux à quatre points d'accostage, chacun avec son prix.** Une plage large et sûre mais loin du but ; une crique étroite, proche, gardée ou semée de récifs. Le choix de l'accostage est la première décision de l'expédition.
5. **Le trésor n'est jamais visible depuis le point d'accostage.** Il faut au moins un changement de niveau ou un franchissement entre la plage et la récompense.
6. **Parcours en boucle, pas en aller-retour.** Montée par le chemin long, retour par un raccourci à sens unique (saut dans l'eau, échelle de corde qu'on déroule, éboulement qu'on déclenche). Le retour avec le coffre dans les bras doit être plus court mais plus exposé.
7. **Rythme d'une visite : accostage calme, première escarmouche, respiration avec vue, épreuve, récompense, fuite.** Jamais deux combats sans pause entre eux. La vue depuis un sommet sert de pause et montre l'île suivante.
8. **Trois couches de contenu par île moyenne ou grande.** La couche évidente (le trésor principal), la couche curieuse (un coffre derrière une cascade, vu par ceux qui font le tour), la couche secrète (un passage que seule la caméra cache, ou qui demande un objet d'une autre île).
9. **Composition par zones.** Découper l'île en 3 à 6 zones à fonction nette : plage d'arrivée, ceinture de végétation, camp, hauteur, intérieur (grotte ou ruine), côte dangereuse. Une zone = une ambiance sonore et une famille d'ennemis.
10. **Portes douces avant portes dures.** Un gardien très fort qu'on peut éviter, un passage sous-marin qu'on peut tenter sans l'objet prévu, plutôt qu'une serrure. La serrure dure est réservée au cœur du donjon.

### 1.4 Tailles et densités

Chiffres connus des jeux étudiés :

| Jeu | Donnée | Fiabilité |
|---|---|---|
| Sea of Thieves | 74 îles cartographiées (25 grandes, 39 petites, 10 forts) | Fan |
| Sea of Thieves | carte de la bêta ≈ 18,8 km² | Fan |
| Sea of Thieves | rencontre entre navires visée toutes les 15 à 30 min | Source |
| Wind Waker | 49 cases, une île ou un groupe par case | Fan |
| Breath of the Wild | 120 sanctuaires, 900 graines Korogu, environ 15 tours | Fan / Source |
| Black Flag (2013) | 22 cartes au trésor | Fan |
| Valheim | chambres funéraires : espacement minimal 128 m, biomes par anneaux de distance au centre | Fan |
| Sunless Sea | ≈ 40 tuiles de terrain, certaines fixes, la plupart mélangées à l'intérieur d'une région | Source |

Barème proposé pour notre jeu [Proposition], à partir d'une vitesse de marche de 5 m/s :

| Classe | Diamètre | Traversée à pied | Durée de visite visée | Part des îles | Contenu minimum |
|---|---|---|---|---|---|
| Îlot | 40 à 70 m | 10 à 15 s | 1 à 3 min | 30 % | 1 repère, 1 surprise (coffre enfoui, épave, ermite) |
| Petite | 90 à 140 m | 20 à 30 s | 4 à 7 min | 30 % | 2 zones, 1 dénivelé, 1 rencontre, 1 cachette |
| Moyenne | 180 à 260 m | 40 à 55 s | 8 à 15 min | 25 % | 3 à 4 zones, 2 accostages, 1 intérieur (grotte ou ruine), 1 bande |
| Grande | 320 à 450 m | 65 à 90 s | 20 à 35 min | 12 % | 5 à 6 zones, mini-donjon de 4 à 7 salles, 1 élite ou mini-boss |
| Île capitale | 500 à 700 m | 100 à 140 s | 40 min et plus, plusieurs visites | 3 % | donjon complet, boss, zones verrouillées par des objets venus d'ailleurs |

Règles de densité [Proposition] :
- Un point d'intérêt toutes les 20 à 40 secondes de marche sur le chemin principal, soit tous les 100 à 200 m.
- Depuis n'importe quel point d'intérêt, au moins un autre est visible, jamais plus de trois.
- Dénivelé maximal de l'île ≈ 15 à 25 % de son diamètre (une île de 400 m culmine vers 60 à 100 m). En dessous de 8 %, l'île se lit comme plate sous caméra inclinée.
- Les îlots restent nombreux, mais aucun n'est vide : la leçon de Wind Waker est qu'un îlot à usage unique et répété (six récifs identiques) est vécu comme du remplissage.

---

## 2. Générer des îles de façon procédurale

### 2.1 La base : bruit, masque d'île, redistribution

Procédure tirée de Red Blob Games, « Making maps with noise functions » [Source], directement applicable avec `FastNoiseLite` de Godot :

1. **Bruit en octaves.** `e = 1·bruit(1x) + 0,5·bruit(2x) + 0,25·bruit(4x)`, divisé par la somme des amplitudes (1,75). Décaler les coordonnées de chaque octave pour les décorréler.
2. **Redistribution.** `e = pow(e × 1,2 ; exposant)`. Un exposant supérieur à 1 aplatit les plaines et garde des pics ; inférieur à 1, tout devient plateau.
3. **Masque d'île.** Coordonnées ramenées entre −1 et +1, puis une distance `d` :
   - bosse carrée : `d = 1 − (1 − nx²)·(1 − ny²)` ;
   - euclidienne² : `d = min(1 ; (nx² + ny²) / √2)` pour une île ronde.
   Puis `e = lerp(e ; 1 − d ; mélange)`. À 0 on garde le bruit, à 1 on force la forme.
4. **Terrasses.** `e = round(e × n) / n` avec n entre 2 et 15. C'est exactement ce qu'il faut pour des paliers lisibles vus du dessus (voir partie 3).
5. **Niveau de la mer.** Seuil fixe ; tout ce qui est dessous est eau.

Pour sortir de l'île ronde : remplacer le masque radial unique par **plusieurs points d'ancrage** (deux bosses = île en haricot ou en deux cornes ; un anneau = atoll ou cratère ; une ligne brisée = île-arête). Un article de 2026 généralise précisément le masque radial à N ancres [Source : Dagstuhl SoCG 2026]. Variante pratique : des **tampons d'élévation** dessinés à la main et additionnés au bruit (voir Red Blob Games, « Elevation Stamps »).

### 2.2 Érosion

L'érosion hydraulique par gouttes : on lâche une goutte à un point aléatoire, elle descend la pente, arrache de la matière, la dépose dans les creux ou en s'évaporant ; on répète des dizaines de milliers de fois [Source : dépôts d'implémentation, documentation Unity Terrain Tools]. Elle creuse des ravines et des deltas crédibles.

Avis pour notre jeu [Proposition] : en low poly et vu du dessus, l'érosion fine se voit peu. Une passe légère suffit, calculée hors-ligne à la génération du gabarit, pas au chargement. Le gain visible vient surtout des terrasses et des falaises nettes.

### 2.3 Biomes

Méthode de Whittaker adaptée par Red Blob Games [Source] : l'altitude sert de température, un second bruit sert d'humidité, et un tableau à deux entrées donne le biome. Seuils d'exemple : sous 0,10 océan, sous 0,12 plage, au-dessus de 0,8 roche nue ou neige selon l'humidité, entre les deux désert, prairie, forêt ou jungle selon l'humidité. Les auteurs précisent que ces seuils se règlent pour chaque générateur.

Pour un jeu d'îles, deux échelles [Proposition] :
- **Biome d'île** (une ambiance dominante par île), choisi selon la région de la carte et la distance au port de départ, comme Valheim place ses biomes par anneaux de distance au centre et Sunless Sea place ses tuiles difficiles à l'est [Fan / Source].
- **Sous-zones par altitude et humidité** à l'intérieur de l'île : plage, ceinture basse, pente, sommet.

Adoucir les frontières entre zones (mélange de textures sur 3 à 6 m), car une classification brute donne des coupures nettes.

### 2.4 Placement des objets

- **Disque de Poisson (algorithme de Bridson)** : des points aléatoires qui respectent tous une distance minimale, en temps linéaire. On part d'une liste active, on tire jusqu'à k candidats (30 dans l'article, 10 suffisent en 2D) dans un anneau autour d'un point, on rejette ceux qui sont trop près [Source : article de Bridson, SIGGRAPH 2007].
- **Densité variable** : un rayon différent par biome ou tiré d'une carte de densité (rayon court en jungle, long en savane) [Source : « Procedural Urban Forestry », Red Blob Games].
- **Règles de placement à la Valheim** : pour chaque type de lieu, un nombre d'essais, un biome autorisé, une plage d'altitude, une distance minimale aux lieux du même type ; l'essai qui échoue est abandonné [Fan : metabot.gg].

Ordre de placement [Proposition] : d'abord les lieux majeurs (accostages, repère, entrée de donjon, camp), puis les chemins qui les relient, puis les obstacles et la végétation autour des chemins, enfin le décor fin. La végétation ne doit jamais boucher un chemin ni masquer une entrée.

### 2.5 Mélanger fait main et procédural

C'est le point sur lequel toutes les sources convergent :

- **Sea of Thieves** : tout est fait main, puis testé en jeu, et des îles sont revues quand elles ne se jouent pas comme prévu [Source : carnet de développement Rare].
- **Enter the Gungeon** : chaque salle est faite et testée à la main ; l'aléatoire ne sert qu'à les relier, à partir d'un graphe de « flux » par étage, où certaines salles sont remplacées par des chaînes de longueur variable ou par un choix entre plusieurs chemins [Source : Boris the Brave ; Game Developer].
- **Don't Starve** : un monde = des tâches obligatoires et optionnelles ; chaque tâche = un groupe de salles (petits biomes à contenu défini) ; des **pièces fixes** (set pieces) faites à la main sont attachées à des tâches ; les tâches se relient par verrous et clés, et celles qui n'obtiennent pas leur clé sont écartées [Fan : wiki ; forum Klei].
- **Valheim** : terrain procédural, mais lieux préfabriqués posés par règles ; l'intérieur des donjons est assemblé à partir d'un lot de salles par thème [Fan].
- **Sunless Sea** : des tuiles faites main ; certaines fixes, la plupart mélangées à l'intérieur d'une région, pour garder la difficulté sous contrôle [Source : Failbetter]. Pour la suite, Failbetter a encore réduit l'aléatoire au profit de segments préparés.
- **Bad North et Townscaper (Oskar Stålberg)** : des îles-dioramas assemblées par *wave function collapse* à partir de tuiles modelées à la main [Source : conférence Everything Procedural 2018].
- **Unexplored (Joris Dormans)** : génération **cyclique** : on trace une boucle entre départ et arrivée, on choisit un type de cycle parmi 24 (deux routes alternatives, verrou et clé, carrefour à trois leviers, lac central), on ajoute des cycles mineurs, puis on fait grandir le niveau [Source : Boris the Brave ; Game Developer].

Recommandation : **îles à gabarit** [Proposition].

1. Un gabarit est un schéma fait main : silhouette (ancres du masque), emplacements nommés (accostages, repère, entrée, camp, sommet, cachettes A/B/C), graphe de parcours (qui mène à quoi, par quel franchissement).
2. Le procédural habille le gabarit : détail du relief par bruit, biome, végétation, variante de chaque emplacement tirée dans une bibliothèque de pièces faites main (3 à 5 variantes par type de pièce).
3. Le contenu tourne : parmi les cachettes A/B/C, une seule porte le trésor à chaque visite ; la famille d'ennemis et l'événement changent.
4. Chaque île produite passe des **tests automatiques** : tout emplacement est atteignable depuis au moins un accostage ; le trésor n'est pas visible d'un accostage ; aucune pente de chemin ne dépasse la limite marchable ; le parcours forme au moins une boucle.
5. Avec 6 gabarits × 10 biomes × 3 à 5 variantes de pièces, on obtient des centaines d'îles qui ont chacune une structure pensée.

La *wave function collapse* est utile pour deux choses précises : assembler les intérieurs (grottes, ruines) sur grille, et habiller une falaise ou un village à partir de modules. Elle ne garantit ni parcours ni rythme : il faut la contraindre par le graphe du gabarit.

Notes Godot [Proposition] : `FastNoiseLite` pour le bruit ; maillage généré par `SurfaceTool` ou `ArrayMesh` ; collision par `HeightMapShape3D` en vérifiant l'échelle, car un forum signale une collision plus plate que le maillage quand les hauteurs ne sont pas dans la même unité [Source : Godot Forums] ; végétation en `MultiMeshInstance3D` ; `NavigationRegion3D` recalculée par île ; graine de génération partagée entre les joueurs pour que tous aient la même île.

---

## 3. Relief et lisibilité vus du dessus

### 3.1 Le problème

Sous caméra orthographique inclinée, la hauteur ne produit aucun effet de perspective : un plateau et une plaine de même couleur se confondent. Un fabricant de tuiles le résume ainsi : une bande grise entre deux pelouses identiques se lit comme un chemin, pas comme une falaise [Source : page du jeu de tuiles « Verdant 02 »]. Le tri d'affichage et les objets qui cachent le joueur ajoutent un second problème.

### 3.2 Règles de lecture du relief

1. **Paliers discrets.** Hauteurs en marches de 3 à 4 m [Proposition], pas en pentes continues. Trois à cinq paliers pour une grande île. La fonction de terrasses de la partie 2 fait le travail.
2. **Deux matériaux, deux valeurs.** Tout ce qui est marchable est clair et peu saturé ; toute paroi est sombre et texturée verticalement. Le contraste sol clair / mur sombre est la recommandation centrale des concepteurs de jeux de tir vus du dessus [Source : MY.GAMES].
3. **Montrer la face.** Orienter les falaises importantes vers la caméra pour qu'on en voie la paroi. Une falaise tournée dos à la caméra est invisible : elle sert alors de cachette, à dessein.
4. **Liseré de crête.** Un bord clair de 20 à 30 cm en haut de chaque falaise, et une ombre portée ou une occlusion ambiante au pied.
5. **La couleur monte avec l'altitude.** Sable, herbe, roche, sommet : une teinte par palier. Le joueur lit la hauteur par la couleur.
6. **Rampes signées.** Une rampe ou un escalier a toujours la même largeur (2,5 à 3 m), le même matériau de sol (terre battue, planches) et un marqueur en haut et en bas (poteau, torche, crâne). Un franchissement non marchable (liane, échelle, corde) a son propre objet, toujours le même.
7. **Ombre au sol.** Tout personnage en l'air ou sur une corniche garde une ombre ronde projetée, pour qu'on lise sa hauteur.
8. **Cap sur l'île.** Tourner la caméra de 90° en mer est permis ; à terre, garder un angle fixe par île rend les secrets de type Tunic possibles, parce que le concepteur sait ce qui est caché.

### 3.3 Occlusion

Techniques relevées [Source : 80.lv sur la reproduction dans Godot de l'effet de Baldur's Gate 3 ; GameDev.net ; godotshaders.com] :
- **Découpe circulaire** autour du joueur dans tout ce qui se trouve entre lui et la caméra, par masque sphérique dans le shader.
- **Tramage** (dither) par motif de Bayer 4 × 4 entre un rayon intérieur transparent et un rayon extérieur opaque. Moins coûteux que la vraie transparence, et cohérent avec un rendu peint.
- **Silhouette** du joueur dessinée par-dessus l'obstacle.
- Garder le sol et les ombres hors du lot qui s'efface.

Règle [Proposition] : arbres et feuillages en tramage ; murs de bâtiment en découpe ; jamais d'ennemi entièrement caché sans silhouette, sauf embuscade voulue et annoncée par un son.

### 3.4 Grottes, sous-sols, intérieurs

Quatre solutions, de la plus simple à la plus riche :

| Solution | Principe | Avantage | Inconvénient |
|---|---|---|---|
| Scène séparée | L'entrée charge un intérieur à part (grottes secrètes de Wind Waker : on tombe dans un trou) | Liberté totale de taille, caméra et lumière propres | Coupure ; en coop, le groupe est séparé si un seul entre |
| Toit qui s'efface | Le plafond ou la colline devient transparent quand un joueur est dessous | Aucune coupure, on voit l'extérieur | Limite la profondeur à un niveau |
| Coupe en écorché | L'intérieur est modelé sans plafond, entouré de noir, sous le niveau du sol | Lecture parfaite ; style maison de poupée | Demande des transitions soignées |
| Grotte à ciel ouvert | Gouffre, cénote, faille : un « intérieur » sans toit | Aucun problème technique | Moins de mystère |

Règles [Proposition] :
- Par défaut, **coupe en écorché en scène continue** pour les mini-donjons : l'île reste chargée, le plafond s'efface par zone, l'extérieur s'assombrit.
- En coopération, l'entrée d'un donjon est une **porte de rassemblement** : elle s'ouvre quand tous les joueurs vivants sont dans la zone, ou un compte à rebours de 10 s téléporte les retardataires. Un des patrons de conception coopérative étudiés à Chalmers [Source].
- Chaque entrée se voit de loin par un signe constant : lueur, souffle de poussière, chauves-souris, courant d'air sonore.
- Sous terre, la lumière est une ressource : torche portée par un joueur (qui n'a alors qu'une main libre), braseros à allumer. Sea of Thieves fait de la lanterne un outil d'énigme et une arme contre certains squelettes [Fan : wiki].
- La falaise tournée dos à la caméra et le dessous d'un pont sont les cachettes naturelles de la vue orthographique.

---

## 4. Biomes et ambiances

Dix biomes proposés [Proposition], chacun pensé pour changer la façon de jouer et pas seulement la couleur. Sea of Thieves fait de même : ses Ancient Isles sont décrites par leur artiste comme plus verticales, plus denses et luxuriantes, et sa région volcanique ajoute des dangers d'environnement [Source : ArtStation, Joachim Coppens ; wiki].

| # | Biome | Palette | Végétation et décor | Dangers | Son et musique | Ennemis typiques |
|---|---|---|---|---|---|---|
| 1 | Tropical classique | sable crème, turquoise, vert vif | cocotiers, bananiers, rochers ronds | crabes, marée | ukulélé, percussions légères, ressac | naufragés, crabes, petits pirates |
| 2 | Jungle profonde | verts sombres, ocre, fleurs rouges | canopée dense, lianes, ruines moussues | visibilité courte, pièges à fosse, plantes à spores | tambours graves, oiseaux, insectes | fauves, sarbacaniers, plante carnivore |
| 3 | Mangrove et marais | vert-de-gris, brun, brume jaune | palétuviers, pontons pourris, eau stagnante | eau lente, sangsues, brume qui cache | contrebasse, grenouilles, bois qui craque | noyés, crocodile, sorcière des marais |
| 4 | Volcanique | noir basalte, orange lave, cendre | arbres calcinés, fumerolles, obsidienne | coulées de lave, geysers, séismes, pluie de roches | cuivres, grondements sourds | golems de scories, cultistes du feu |
| 5 | Falaises de craie et vent | blanc, vert d'herbe rase, bleu dur | herbes couchées, moulins brisés, nids | bourrasques qui poussent, corniches étroites | violon, vent, mouettes | harpies ou oiseaux marins, tireurs embusqués |
| 6 | Récif et épaves | corail rose, bleu lagon, bois gris | coraux géants, coques éventrées, bancs de sable | marée qui noie les passages, oursins, courant | harpe de verre, clapotis, bois creux | crabes cuirassés, murènes, pilleurs d'épaves |
| 7 | Désert et canyon | ocre, rouge brique, ombres violettes | cactus, arches de grès, ossements | chaleur (endurance), sables mouvants, scorpions | flûte, silence, vent sec | scorpions, momies de marins, bandits |
| 8 | Île brumeuse maudite | gris-bleu, vert spectral, noir | arbres morts, tombes, feux follets | brume qui efface la carte, apparitions, peur | chœur lointain, cloche, quasi-silence | squelettes, spectres, capitaine fantôme |
| 9 | Glaces du nord | blanc, bleu glacier, bois sombre | sapins, banquise, baleinières | froid (feu obligatoire), glace glissante, crevasses | cordes tenues, craquements de glace | loups, baleiniers renégats, morse géant |
| 10 | Ruines englouties | pierre dorée, turquoise profond, algues | temples à demi noyés, statues, bassins | niveaux d'eau à manœuvrer, pièges anciens | carillons, eau qui goutte, écho | gardiens de pierre, sirènes, anguilles |
| 11 (option) | Forteresse coloniale | pierre grise, rouge d'uniforme, cuivre | remparts, canons, potagers, quais | canons côtiers, alarmes, patrouilles | tambour militaire, fifres | soldats en formation, officier, canonniers |
| 12 (option) | Atoll-cratère fleuri | rose, lavande, vert tendre | prairie, lac central, cerisiers | faux calme : le danger est sous le lac | boîte à musique | créature lacustre, abeilles géantes |

Règles :
1. **Un biome = une règle de jeu en plus**, lisible en dix secondes (la brume efface la carte, le vent pousse, la marée ferme un passage).
2. **Un danger d'environnement par biome**, jamais mortel d'un coup, toujours annoncé (fumerolle avant le geyser, sifflement avant la bourrasque).
3. **Une couleur dominante et une couleur d'accent** par biome, pour qu'on sache où l'on est sur une capture d'écran.
4. **La musique suit trois états** : exploration, tension (ennemi alerté), combat. Changement par couches et non par coupure.
5. **Difficulté par région** : biomes 1, 2, 6 près du port de départ ; 3, 5, 7 au milieu ; 4, 8, 9, 10 au large.

---

## 5. Trésors et énigmes

### 5.1 Ce que fait Sea of Thieves

- **Carte au X** : un dessin de l'île avec une croix. Le joueur compare le dessin au terrain. Aucune interface ne montre la position exacte.
- **Carte à énigmes** : 2 à 4 énigmes sur une grande île. La première ne donne que le nom de l'île. Les suivantes désignent un repère où il faut faire un geste en restant immobile : jouer un air, lire la carte, lever une lanterne allumée. Un signe (grondement, lueur) valide l'étape et révèle la ligne suivante. La dernière donne un repère, une direction au compas et un nombre de pas avant de creuser [Fan : wiki ; Fandom].
- **Caveaux au trésor** : une quête mène à une clé ; la clé ouvre un caveau **chronométré** qui se referme après 3 minutes. À l'intérieur, 3 médaillons cachés à poser sur une table centrale pour obtenir le coffre le plus précieux. Le butin sorti avant la fermeture est gardé [Fan : wiki].
- **Le butin est physique** : rien n'est acquis tant que ce n'est pas vendu au port ; l'équipe revendique la « paranoïa » d'avoir le trésor à bord [Source : interview Mike Chapman, Windows Central].

Ce qu'on en retient : l'énigme se résout **avec le terrain**, pas dans un menu. Elle n'est possible que si l'île a assez de repères nommables, ce qui renvoie à la partie 1.

### 5.2 Structure d'un donjon : verrous, clés, graphes

- **Formule Zelda** (série « Boss Keys » de Game Maker's Toolkit) : petites clés pour plusieurs serrures, une clé de boss pour une seule porte, et l'objet du donjon qui sert de clé à de nombreux obstacles. La formule est fixée par Link's Awakening. Un donjon peut aussi s'organiser en moyeu et rayons : une salle centrale où l'on revient sans cesse [Source : transcriptions des épisodes ; Zelda Dungeon].
- **Graphe de mission** (Boris the Brave, d'après Joris Dormans) : on dessine seulement les dépendances logiques (A est requis pour B), sans la géographie. On y voit le choix réel : des branches parallèles = du choix, une chaîne = aucun. Les « clés » ne sont pas que des clés : objets, améliorations, mots de passe, drapeaux d'événement. Une exigence est dure ou douce (un monstre fort qu'un joueur adroit peut esquiver) [Source].
- **Mission d'abord, espace ensuite** : on écrit le graphe, puis on le plie dans des salles. Le graphe ne montre pas le coût des retours : il faut superposer les deux.
- **Cycles** (Unexplored) : deux arcs entre l'entrée et le but valent mieux qu'un arbre. Types utiles : deux routes alternatives à obstacles différents ; verrou sur un arc et clé sur l'autre ; carrefour dont la sortie demande trois leviers dispersés ; portes à sens unique pour éviter les retours [Source].

### 5.3 Gabarits de mini-donjon

Trois tailles [Proposition] :

**Cache (2 à 3 salles, 3 à 5 min).** Entrée cachée → salle d'épreuve (un piège ou une petite bande) → salle du coffre. Graphe : chaîne simple. Sert aux petites îles.

**Crypte (4 à 5 salles, 8 à 12 min).** Graphe en cycle verrou-clé :
1. Vestibule : on voit la porte du trésor, fermée (refus puis récompense).
2. Arc gauche : salle de combat, donne la clé ou abaisse une herse.
3. Arc droit : salle d'énigme (levier, plaques de pression, miroirs), ouvre un raccourci à sens unique vers le vestibule.
4. Salle du trésor, puis sortie par un passage qui débouche ailleurs sur l'île (la boucle de la partie 1).

**Donjon (6 à 9 salles, 15 à 25 min).** Moyeu et rayons :
- Salle centrale avec une grande porte à trois sceaux.
- Trois rayons : un combat (vagues), une énigme (niveau d'eau, leviers à ordre), un parcours (pièges à rythme). En coopération, les rayons peuvent se faire en parallèle si le groupe se sépare, plus vite mais plus risqué.
- Un secret dans le moyeu, visible mais inaccessible jusqu'au retour.
- Antichambre (repos, sauvegarde du groupe), salle de boss, sortie rapide.

### 5.4 Catalogue d'énigmes, de cachettes et de pièges

Énigmes de terrain :
- Compter des pas depuis un repère dans une direction donnée, puis creuser.
- Aligner deux repères vus d'un troisième point (« là où la corne touche le phare »).
- Allumer des braseros dans l'ordre indiqué par une fresque.
- Marée : le passage n'existe qu'à marée basse, ou le coffre ne flotte jusqu'à la corniche qu'à marée haute.
- Lever une lanterne ou jouer un air à un endroit précis pour révéler un signe.
- Statue à tourner vers le repère de l'île.

Énigmes coopératives (patrons de Chalmers et de l'article DiGRA : rôles complémentaires, porte de séparation, porte de rassemblement, information chiffrée, simultanéité) [Source] :
- Deux leviers éloignés à tenir en même temps.
- Un joueur voit le symbole (en haut d'une tour), l'autre agit (dans la salle) : information partagée à la voix.
- Un joueur porte la torche, l'autre porte le coffre : ni l'un ni l'autre ne peut se battre à pleine capacité.
- Plaques de pression : il faut autant de poids que de joueurs, ou des objets lourds pour remplacer un absent. Toujours prévoir la version solo.

Cachettes :
- Derrière une cascade ; sous un pont ; au dos d'une falaise (invisible à la caméra) ; dans une épave à marée basse ; sous une dalle fêlée ; dans un tronc creux ; au fond d'un puits ; dans la cale d'un bâtiment dont le plancher sonne creux.
- Indice obligatoire : une cachette a toujours un signe (terre retournée, mouettes, éclat, bruit creux). Tunic cache sans tricher : le passage existe, il est seulement masqué.

Pièges (toujours annoncés) :
- Dalle qui s'enfonce puis fléchettes d'un mur troué ; plafond qui descend avec sablier ; boulet roulant dans un couloir à alcôves ; sol qui s'effondre vers une salle inférieure (qui peut être un raccourci) ; faux coffre qui mord ; statue qui crache du feu à rythme fixe ; salle qui se remplit d'eau.
- Règle de Mike Stout appliquée aux pièges : la première occurrence d'un mécanisme se rencontre sans danger, la deuxième avec, la troisième combinée à des ennemis [Source, adapté].

### 5.5 Règles pour les trésors

1. **Un trésor = une recherche + une épreuve + un transport.** Supprimer une des trois parties donne le coffre « ramassé en une seconde ».
2. **Le coffre se porte à deux mains** : le porteur ne se bat pas, marche moins vite. Les gros coffres se portent à deux joueurs.
3. **Niveaux de coffre visibles** (bois, fer, or, maudit) et effets de coffres spéciaux à la Sea of Thieves (un coffre qui fait pleurer et remplit la cale, un coffre qui enivre).
4. **Chronomètre de sortie** sur les meilleurs trésors : prendre le coffre déclenche l'effondrement, l'inondation ou le réveil des gardiens.
5. **Butin secondaire sans coffre** : pièces, cartes, clés d'une autre île, plans de navire. Une île sur trois donne une piste vers une autre île.
6. **Jamais deux fois la même cachette de suite** sur une île revisitée.

---

## 6. Ennemis et intelligence artificielle

### 6.1 Architectures de décision

| Architecture | Principe | Référence | Bon pour | Limite |
|---|---|---|---|---|
| Machine à états (FSM) | Un état actif, des transitions | F.E.A.R. n'a que trois états : aller à, animer, utiliser un objet [Source : Orkin, GDC 2006] | Animations, ennemis simples, phases de boss | Explose en transitions au-delà de 6 à 8 états |
| Machine hiérarchique, arbre de comportement | Arbre de sélecteurs et de séquences évalué de haut en bas | Halo 2, Damian Isla, GDC 2005 [Source] | La grande majorité des ennemis ; lisible, réutilisable | Les priorités fixes donnent des comportements rigides |
| GOAP (planification par buts) | L'ennemi a des buts et des actions à préconditions et effets ; un planificateur de type STRIPS enchaîne les actions | F.E.A.R. [Source] | Ennemis qui improvisent avec le décor | Coûteux, dur à déboguer, superflu pour des combats courts |
| IA à utilité | Chaque action reçoit une note selon le contexte, la meilleure gagne | Travaux de Dave Mark `[À VÉRIFIER : source primaire non consultée]` | Choix d'attaque, de cible, de position | Réglage des courbes délicat |

Les sources décrivent ces approches comme complémentaires : arbre pour la structure, utilité pour les choix tactiques, machine à états pour l'animation [Source : synthèses citées].

Recommandation [Proposition] :
- **Arbre de comportement** par ennemi, avec l'extension **LimboAI** (arbres + machines à états hiérarchiques, éditeur et débogueur visuels, C++ avec tâches en GDScript, licence MIT) ou **Beehave** (plus léger, tout en GDScript) [Source : dépôts et documentation].
- **Notation par utilité** dans deux nœuds seulement : choix de la cible et choix de l'attaque.
- **Machine à états** pour les phases de boss.
- **Un directeur de combat par joueur ciblé** pour la coordination (voir 6.5).
- Pas de GOAP.
- En multijoueur, l'IA tourne chez l'hôte ; les clients reçoivent l'état, l'intention (télégraphie) et la position.

### 6.2 Perception, aggro, patrouilles

Synthèse des pratiques décrites [Source : études et tutoriels sur la perception, dont une analyse de The Last of Us] :
- **Vue** : un cône (110 à 120°, 12 à 18 m) [Proposition] plus un test de ligne de vue ; un cône unique est facile à exploiter, d'où un second petit rayon de proximité (2 à 3 m) à 360°.
- **Jauge d'éveil** plutôt que détection instantanée : elle monte selon la distance, la lumière, le mouvement, et redescend hors de vue.
- **Ouïe** : chaque bruit a un rayon selon son volume (pas, course, coup de feu, coffre lâché, cloche).
- **États** : inactif → soupçonneux (va voir) → alerté (combat) → recherche (dernière position connue) → retour.
- **Laisse** : au-delà d'une distance de son point d'origine (25 à 40 m) ou hors de sa zone, l'ennemi décroche, rentre et récupère sa vie progressivement. Signalé par une animation, pour ne pas paraître buggé.
- **Alerte de groupe** : un ennemi alerté prévient ceux de sa bande dans un rayon (8 à 12 m) après un délai de 1 s : le tuer vite a un intérêt.
- **Cible en coopération** : note par cible = dégâts récents reçus + proximité + vulnérabilité (porteur de coffre, joueur à terre), avec un verrou minimal de 3 à 4 s pour éviter les changements nerveux.

Patrouilles : rondes sur points de passage, pauses avec animation (boire, pêcher, se disputer), sentinelles fixes sur les hauteurs, dormeurs autour d'un feu la nuit. Un ennemi qui fait quelque chose avant de voir le joueur paraît vivant ; un ennemi planté debout paraît « débile ».

### 6.3 Télégraphie et lisibilité

- La télégraphie est le début de l'animation d'attaque, renforcée par couleur, éclat et son ; plus l'attaque est forte, plus le signal est appuyé [Source : Game Developer, « Enemy design and enemy AI for melee combat systems »].
- Le temps de réaction humain est donné autour de 200 à 300 ms ; les sources de conception situent une préparation lisible entre 0,5 et 1 s environ, sans norme établie [Source secondaire ; à régler en jeu].
- Si le joueur tue l'ennemi avant la fin de la préparation, la télégraphie est décorative : la vie de l'ennemi doit laisser à au moins une attaque le temps de partir.
- Dans Hades, les attaques de boss se lisent parce qu'elles sont surtout des zones de mêlée et des projectiles qui partent du boss ; une critique reproche à Hades II de perdre cette lisibilité [Source : nex-3.com].

Barème [Proposition] :

| Type d'attaque | Préparation | Signal | Récupération (fenêtre de punition) |
|---|---|---|---|
| Coup léger | 0,35 à 0,5 s | pose, bref éclat | 0,4 à 0,6 s |
| Coup lourd | 0,7 à 1,0 s | pose large, zone au sol, son grave | 1,0 à 1,5 s |
| Charge | 0,8 à 1,2 s | grattement du sol, ligne au sol | 1,5 s s'il heurte un mur |
| Tir | 0,6 à 0,9 s | visée, ligne ou reflet | 0,5 s |
| Zone (explosion, souffle) | 1,0 à 1,5 s | forme pleine qui se remplit | 1,0 s |

Code de formes au sol, constant dans tout le jeu : cercle = explosion, cône = balayage, ligne = charge ou tir, anneau = onde. Rouge = dégât, jaune = contrôle. Ne jamais attaquer depuis hors de l'écran : les ennemis entrent d'abord dans le champ [Source]. En coop, une icône au-dessus de l'ennemi indique quel joueur il vise.

### 6.4 Tiers et rôles

Tiers de puissance, repris de la classification de DmC citée par Game Developer [Source] : **piétaille, rang moyen, élite, boss**. Les tiers hauts sont toujours moins nombreux.

Fonctions pédagogiques, même source :
- **Défouloir** : facile, fait plaisir, arrive en premier.
- **Incitateur** : encourage une mécanique mais cède quand même aux coups normaux.
- **Imposeur** : ne tombe qu'avec une mécanique précise (le squelette doré de Sea of Thieves, qu'il faut mouiller ; l'ombre, qu'il faut éclairer [Fan : Shacknews, wiki]).
- **Défieur** : teste l'habileté.

Rôles de combat [Proposition, d'usage courant] :

| Rôle | Fonction | Ce qu'il impose au joueur |
|---|---|---|
| Nuée | Nombreux, fragiles | Balayer, ne pas se laisser encercler |
| Bretteur | Mêlée standard, pare | Attendre l'ouverture |
| Brute / tank | Lent, porte bouclier ou armure | Contourner, frapper le dos, travailler à deux |
| Tireur | Garde ses distances, fuit | Fermer la distance, utiliser les couverts |
| Harceleur | Rapide, frappe et se retire | Surveiller ses arrières, protéger le porteur |
| Artificier | Zones au sol, barils | Bouger, retourner l'explosif |
| Soutien | Soigne, renforce, donne l'alarme | Cible prioritaire |
| Invocateur | Fait venir des renforts | Interrompre ou tuer vite |
| Contrôleur | Filet, grappin, ralentit | Délivrer son coéquipier |

Variantes : Sea of Thieves décline un seul squelette en plusieurs matières, chacune avec une faiblesse, et donne à chaque type un capitaine reconnaissable à son chapeau et à son nom affiché [Fan]. God of War 3 décline son squelette en normal, à bouclier, à armure dorée [Source]. Diablo fabrique ses élites par **affixes** combinés : en meute « championne », tous ont les mêmes pouvoirs ; en meute « rare », un chef et ses sbires ; l'équipe a constaté que trop restreindre les combinaisons rendait les rencontres prévisibles [Fan : wiki Diablo].

Règles de composition d'une rencontre [Proposition] :
1. Deux ou trois rôles par bande, jamais un seul. La combinaison de base : une ligne de front + un tireur ou un soutien.
2. Budget par rencontre : piétaille 1 point, rang moyen 3, élite 8. Budget = 4 + 3 par joueur pour une rencontre normale, doublé pour un camp.
3. Un ennemi nouveau apparaît d'abord seul, puis accompagné, puis en version élite.
4. Un solitaire très fort (élite errant) par grande île : évitable, visible de loin, avec une récompense à part.

### 6.5 Comportement de groupe

- **Jetons d'attaque.** Un ennemi doit obtenir un jeton avant d'attaquer ; le jeton est demandé **avant** la télégraphie et rendu à la fin, à l'interruption ou à la mort. Valeurs d'exemple par joueur ciblé : 1 jeton de mêlée, 2 de tir, 1 d'attaque lourde. En coopération, chaque joueur a sa propre réserve. Un « budget d'agressivité » de 0 à 1 multiplie les réserves de 0,5 à 1,5 et sert de réglage de difficulté. Prévoir un nettoyage périodique des jetons perdus [Source : StraySpark]. L'origine souvent citée est Doom (2016) `[À VÉRIFIER : conférence GDC d'id Software non retrouvée]`.
- **Cercle de combat** (« kung-fu circle », attribué à Kingdoms of Amalur) : des emplacements autour du joueur sur deux ou trois anneaux (mêlée 1,5 à 2,5 m, moyen 5 à 8 m, loin 12 à 20 m) ; chaque ennemi prend l'emplacement libre le plus proche de son cap ; après avoir frappé, il recule et laisse sa place [Source : StraySpark ; Tuts+ ; Packt].
- **Cadence** : en moyenne une attaque toutes les 2 à 3 secondes sur le joueur, pas d'attaques simultanées, pas d'attaque pendant qu'un autre ennemi est en animation de recul [Source : Game Developer].
- **Les ennemis sans jeton ne restent pas plantés** : ils tournent, avancent, se repositionnent, provoquent, se mettent à couvert [Source].
- **Positionnement** : ne pas se placer entre le joueur et la caméra ; garder une zone libre autour du joueur [Source].
- **Aztez** n'autorise jamais deux attaques de la même catégorie en même temps [Source].

Tactiques de bande à écrire [Proposition] : encerclement (les harceleurs prennent les emplacements arrière), prise en tenaille depuis deux chemins, repli vers le chef quand la moitié de la bande est tombée, fuite du dernier survivant qui va sonner la cloche, protection du soutien par la brute, tir de suppression pendant qu'un autre contourne.

### 6.6 Rythme des rencontres

Le directeur de Left 4 Dead mesure l'intensité vécue par les joueurs et fait tourner trois phases : montée, pic, relâchement ; les hordes n'apparaissent que pendant la montée [Source : présentation de Michael Booth ; wiki Valve]. Il envoie plus de pression à une équipe qui domine et plus de soins à une équipe en difficulté.

Application [Proposition] : un petit directeur par île. Après un combat dur, il retarde les patrouilles et laisse une pause ; si les joueurs traversent sans dégâts, il réveille une embuscade ou l'élite errant.

### 6.7 Boss

Les huit temps d'un combat de boss selon Mike Stout [Source] :
1. **Annonce** : le boss est préparé avant le combat (traces, récits, mini-boss qui enseigne la mécanique).
2. **Entrée** : une révélation qui pose sa personnalité.
3. **Régime normal** : ses attaques de base ; toute mécanique nouvelle s'apprend ici sans risque.
4. **Escalade** : nouvelles attaques, complications.
5. **Point médian** : fausse défaite, transformation ; courte respiration.
6. **Tout l'arsenal** : toutes les compétences du joueur sont testées.
7. **Mise à mort** : une fin spectaculaire.
8. **Victoire** : récompense et relâchement.

Méthode du même auteur : lister d'abord les compétences à tester, inventer les attaques qui les testent, habiller ensuite. Donner au boss des défenses (bouclier, envol, repoussement) pour que le joueur ne puisse pas l'empêcher d'agir. Voir aussi la conférence d'Itay Keren, « Boss Up: Boss Battle Design Fundamentals and Retrospective », GDC 2018.

Observations sur Hades [Fan : guides] : l'Hydre a des phases d'invulnérabilité où elle appelle d'autres têtes, ce qui empêche de la tuer d'un trait ; le duo Thésée et Astérion oppose un boss qui tient le centre à un boss qui poursuit, et tuer l'un change le comportement de l'autre à mi-vie.

Règles [Proposition] :
1. **Trois phases**, à 100 %, 66 % et 33 % de vie ; chaque phase ajoute un motif et modifie l'arène, sans simplement augmenter les dégâts.
2. **Quatre à six motifs par boss**, pas plus. Chaque motif a une préparation, une exécution, une récupération pendant laquelle on peut frapper.
3. **Pas deux fois le même motif de suite** ; ordre semi-aléatoire avec poids.
4. **L'arène fait partie du boss** : piliers pour faire s'écraser une charge, canons à recharger, marée, barils.
5. **Coopération** : vie +60 % par joueur supplémentaire ; une mécanique qui demande deux joueurs (l'un attire, l'autre frappe le point faible) avec une solution solo plus lente ; relever un coéquipier est possible mais risqué.
6. **Durée visée** : 2 à 3 min pour un mini-boss, 4 à 6 min pour un boss.
7. **Fenêtre de punition longue après la plus grosse attaque** : c'est ce qui donne envie de l'esquiver plutôt que de fuir.

### 6.8 Ce qui rend un combat vu du dessus intéressant

- **Le placement prime** : on voit tout le champ, donc le jeu porte sur où se tenir. Attaques de zone, couverts, bords de falaise d'où l'on peut pousser un ennemi.
- **Le décor agit** : barils, feu qui se propage, pont de corde à couper, rochers à faire rouler. Kotaku rapporte que dans Hades le level design a nourri la conception des ennemis, chacun ayant sa façon de traverser la lave [Source].
- **Priorité de cibles** : toujours une raison de choisir qui tuer d'abord (soutien, invocateur, sonneur de cloche).
- **Une IA lisible vaut mieux qu'une IA forte** : la vidéo « What Makes Good AI? » de Game Maker's Toolkit défend des comportements prévisibles qui permettent de faire des plans `[À VÉRIFIER : résumé de seconde main]`. Voir aussi « What Makes a Good Combat System? » de la même chaîne.
- **Les ennemis parlent** : crier « Je recharge ! », « Par-derrière ! » fait paraître l'IA plus maligne et sert de télégraphie sonore.

---

## 7. Récompense et boucle de jeu

### 7.1 Pourquoi retourner sur une île

1. **Contenu qui tourne** : cachette, famille d'ennemis et événement changent à chaque visite (partie 2.5).
2. **Couches verrouillées par un objet d'ailleurs** : la grille sous-marine vue à la première visite ne s'ouvre qu'avec la cloche de plongée trouvée trois îles plus loin. C'est l'« objet-clé à plusieurs serrures » de la formule Zelda, étendu à tout l'archipel.
3. **Cartes au trésor qui renvoient à une île connue** : la connaissance du terrain devient un avantage, comme les cartes à énigmes de Sea of Thieves qui supposent qu'on connaît les repères.
4. **États du monde** : marée, nuit, tempête, brume changent les passages et les ennemis. La nuit, d'autres lieux deviennent visibles et attirants, comme dans Breath of the Wild [Source].
5. **Île qui se souvient** : un camp vidé reste vide quelques jours de jeu, puis est repris par une autre faction, plus forte.
6. **Ressources propres à un biome** : bois noir des îles volcaniques pour la coque, perles des récifs pour le commerce.
7. **Rumeurs au port** : la taverne vend des pistes vers des îles déjà visitées (« on a vu de la lumière dans la crypte de l'île aux Deux Cornes »).

### 7.2 Variété

- Varier l'**objectif**, pas seulement le décor : trouver, voler sans être vu, tenir une position, escorter, s'échapper, chasser une créature, délivrer un prisonnier.
- Introduire les biomes et les ennemis **par paliers** (Raft) et non tous ensemble (reproche fait à Windbound d'îles interchangeables).
- Aucun type d'île ne doit représenter plus d'un tiers des îles d'une région.
- Dans un voyage de 30 minutes, viser une alternance : un îlot, une île moyenne, une rencontre en mer, une grande île.

### 7.3 Risque et récompense

- **Butin physique, non sécurisé avant le port** [Source : Sea of Thieves]. Mourir fait lâcher ce qu'on porte ; le coffre reste sur place un temps.
- **S'arrêter ou continuer** : après le premier coffre, l'île propose une salle plus profonde, visible, plus dangereuse. Partir avec ce qu'on a est une décision.
- **Le niveau de danger se lit avant d'accoster** : pavillon, crânes sur des piques, couleur du ciel, nombre de feux.
- **Coffres maudits** : meilleure valeur contre un handicap pendant le transport.
- **Échec jamais sec** : même une expédition ratée laisse quelque chose (un morceau de carte, une connaissance de l'île), dans l'esprit de la remarque de Rare sur les moments qui méritent d'être récompensés [Source].

### 7.4 Coopération à 2–4 joueurs

Patrons de conception validés par des études de joueurs (Chalmers ; Reuter et al., DiGRA 2014) [Source] : rôles complémentaires, synergies entre capacités, énigmes partagées, portes de séparation et de rassemblement, information chiffrée, ressources partagées, simultanéité. Une étude à trois joueurs trouve les rôles asymétriques et la simultanéité très efficaces, et recommande la prudence avec les portes de séparation, sources de frustration.

Règles [Proposition] :
1. **Test de l'interdépendance** : la présence d'un coéquipier doit changer ce que je peux faire, pas seulement ajouter des dégâts.
2. **Rôles par ce qu'on porte, pas par classe** : porteur de coffre, porteur de torche, porteur de carte, celui qui reste au bateau. On en change librement.
3. **Le bateau est un poste** : un joueur resté à bord peut couvrir au canon, déplacer le navire vers la sortie, mais il est seul si le navire est attaqué.
4. **Tout doit être faisable à deux** ; à quatre, c'est plus rapide et plus sûr, pas obligatoire. Les énigmes à deux leviers ont une solution solo plus lente.
5. **Mise à l'échelle** : nombre et vie des ennemis selon les joueurs présents dans la zone, jetons d'attaque par joueur, butin partagé (pas de course au coffre).
6. **Relever un allié** en 3 s, interruptible ; si tout le groupe tombe, retour au bateau et le butin porté reste sur l'île.
7. **Communication intégrée** : signaux au sol (« ici », « danger », « trésor ») pour ceux qui jouent sans micro.
8. **Séparations courtes** : jamais plus de 60 à 90 s loin du groupe, et toujours avec une vue sur les autres.

---

## (a) Synthèse : 22 règles prioritaires

1. Chaque île se reconnaît à sa silhouette depuis la mer.
2. Un grand repère visible du large, deux ou trois repères moyens jamais tous visibles ensemble.
3. Le relief est fait de formes qui posent un choix (grimper ou contourner) et qui cachent ce qu'il y a derrière.
4. Deux à quatre accostages, chacun avec un avantage et un prix.
5. Le trésor n'est jamais visible du point d'accostage.
6. Le parcours est une boucle : aller long, retour court et exposé.
7. Trois couches de contenu : évidente, curieuse, secrète.
8. Cinq classes de taille, de 40 à 700 m ; aucun îlot vide ; aucune classe au-dessus d'un tiers des îles d'une région.
9. Îles à gabarit : structure faite main, habillage procédural, contenu tournant, tests automatiques d'atteignabilité.
10. Relief en paliers de 3 à 4 m, sol clair, parois sombres, liseré de crête, couleur qui monte avec l'altitude.
11. Rampes et franchissements toujours signés de la même façon.
12. Occlusion par tramage ou découpe ; jamais d'ennemi caché sans silhouette, sauf embuscade annoncée.
13. Intérieurs en écorché, en scène continue ; entrée de donjon = porte de rassemblement.
14. Un biome = une couleur dominante, une règle de jeu en plus, un danger annoncé.
15. Un trésor = une recherche + une épreuve + un transport.
16. Les énigmes se résolvent avec le terrain et ses repères, pas dans un menu.
17. Tout mini-donjon est un graphe écrit avant d'être construit, avec au moins un cycle et un raccourci de retour.
18. Chaque bande mélange deux ou trois rôles ; un ennemi nouveau arrive d'abord seul.
19. Toute attaque est télégraphiée (0,35 à 1,5 s selon sa force) avec un code de formes au sol constant, et suivie d'une fenêtre de punition.
20. Jetons d'attaque et cercle de combat par joueur ciblé ; les ennemis sans jeton bougent, ils n'attendent pas.
21. Boss en trois phases, quatre à six motifs, arène active, mécanique à deux avec solution solo.
22. Le butin n'est acquis qu'au port ; l'île propose toujours d'aller plus loin pour plus gros ; chaque île a au moins une raison d'y revenir.

---

## (b) Six gabarits d'îles

Toutes les valeurs sont des propositions à régler en jeu.

### Gabarit 1 : Le Croc

- **Taille** : petite, 110 × 80 m. **Biome** conseillé : tropical classique ou falaises de craie.
- **Relief** : un seul piton incliné de 22 m, comme une dent, avec une plage en croissant du côté sous le vent. Trois paliers.
- **Parcours** : plage → sentier en lacet autour du piton → corniche du sommet → saut dans l'eau profonde côté large (clapet), nage jusqu'au bateau. 4 à 6 minutes.
- **Cachette du trésor** : trois emplacements tournants. A : niche sous la corniche, au dos du piton, invisible à la caméra depuis la plage. B : enterré au pied d'un palmier tordu, à « douze pas au nord du crâne ». C : dans un nid au sommet.
- **Ennemis** : 3 à 5 piétailles et un tireur posté sur le deuxième palier, qui couvre le lacet.
- **Mémorable par** : le saut final avec le coffre, et la silhouette en dent qu'on reconnaît à un kilomètre.

### Gabarit 2 : Les Deux Cornes

- **Taille** : moyenne, 240 × 160 m. **Biome** : jungle profonde ou désert et canyon.
- **Relief** : deux collines de 30 et 38 m reliées par un col bas ; un pont de corde relie les deux sommets au-dessus du col. Quatre paliers.
- **Parcours** : deux accostages (plage sud large ; crique nord étroite entre les récifs). Le col abrite un camp. On monte par la corne ouest, on traverse le pont, on redescend par la corne est jusqu'à la crique. Boucle complète de 10 à 14 minutes.
- **Cachette du trésor** : dans une grotte de la corne est dont l'entrée n'est visible que depuis le pont (refus puis récompense : on voit la lueur d'en bas sans trouver l'accès).
- **Ennemis** : une bande de 6 à 8 au camp (brute, deux bretteurs, artificier, sonneur de cloche), deux tireurs aux extrémités du pont. Le pont peut être coupé, par les joueurs comme par les ennemis.
- **Mémorable par** : le combat sur le pont, et le choix d'attaquer le camp ou de le contourner par les hauteurs.

### Gabarit 3 : Le Chaudron

- **Taille** : grande, 380 m de diamètre. **Biome** : volcanique ou atoll-cratère fleuri.
- **Relief** : anneau de falaises de 45 m, cratère intérieur avec un lac (ou de la lave) et un îlot central. Une brèche unique permet d'entrer en barque ; un tunnel de lave traverse la paroi à l'opposé.
- **Parcours** : accoster dehors et grimper la paroi (long, sûr), ou passer la brèche en barque sous le feu d'une batterie (court, risqué). À l'intérieur : rive, village sur pilotis, îlot central. Sortie par le tunnel, qui débouche sur une plage cachée. 20 à 30 minutes.
- **Cachette du trésor** : crypte sous l'îlot central, mini-donjon de 5 salles en cycle verrou-clé ; la clé est chez le chef du village sur pilotis.
- **Ennemis** : faction complète (piétaille, tireurs sur la crête, artificiers à la batterie), un élite gardien de la clé, mini-boss dans la crypte. Danger d'environnement : geysers ou montée du lac.
- **Mémorable par** : la révélation du cratère quand on franchit la crête ou la brèche : un monde clos qu'on ne soupçonnait pas depuis la mer.

### Gabarit 4 : L'Échine

- **Taille** : grande et longue, 450 × 120 m. **Biome** : falaises de craie et vent, ou glaces du nord.
- **Relief** : une arête rocheuse qui monte de 0 à 70 m d'un bout à l'autre, avec des deux côtés des falaises tombant dans la mer. Cinq paliers en enfilade, un phare en ruine au point haut.
- **Parcours** : linéaire en montée, par étapes, avec à chaque palier une vue sur le phare (weenie) qui se rapproche. Retour par une tyrolienne ou une descente en rappel depuis le phare jusqu'à une crique où le coéquipier resté à bord peut amener le bateau. 20 à 25 minutes.
- **Cachette du trésor** : dans le soubassement du phare, sous une trappe. Il faut rallumer la lanterne du phare (énigme des miroirs) pour que la lumière désigne la dalle.
- **Ennemis** : embuscades de harceleurs sur les corniches, tireurs en hauteur, oiseaux marins qui poussent ; un élite solitaire à mi-parcours, sur le palier le plus étroit, qu'on peut contourner par une vire.
- **Mémorable par** : l'ascension avec le phare en ligne de mire, les bourrasques, et le phare rallumé qui reste visible depuis la mer pour le reste de la partie.

### Gabarit 5 : Le Labyrinthe d'eau

- **Taille** : moyenne à grande, 300 × 260 m, dont la moitié en eau peu profonde. **Biome** : mangrove et marais, ou récif et épaves.
- **Relief** : presque plat (8 m au plus), mais découpé en dizaines d'îlots par des chenaux. La verticalité est remplacée par la marée : deux niveaux d'eau qui ouvrent et ferment des passages.
- **Parcours** : on entre en barque, puis à pied d'îlot en îlot par des pontons, des racines et des épaves. Le chemin de l'aller disparaît à marée haute ; il faut en trouver un autre pour revenir. 12 à 20 minutes.
- **Cachette du trésor** : dans la cale d'une épave posée sur un banc, accessible seulement à marée basse ; l'intérieur se remplit quand la marée remonte (chronomètre naturel).
- **Ennemis** : noyés qui sortent de l'eau (embuscade annoncée par des bulles), crocodile solitaire, sorcière des marais (invocatrice) sur un îlot central. Visibilité réduite par la brume.
- **Mémorable par** : l'île qui change de forme pendant qu'on y est, et la fuite de l'épave qui se noie.

### Gabarit 6 : La Citadelle engloutie

- **Taille** : île capitale, 560 × 480 m. **Biome** : ruines englouties, forteresse coloniale ou île brumeuse maudite.
- **Relief** : trois terrasses concentriques (0, 20, 45 m) reliées par des escaliers monumentaux en partie effondrés ; au sommet, une acropole ; sous l'île, un réseau de citernes.
- **Parcours** : conçue pour plusieurs visites. Première visite : port en ruine et première terrasse. La deuxième terrasse demande un objet d'une autre île (grappin, cloche de plongée ou clé de bronze). Trois quartiers font office de rayons autour de la grande place (moyeu). Raccourcis permanents à ouvrir (herse, monte-charge) qui restent ouverts d'une visite à l'autre. 40 minutes et plus.
- **Cachette du trésor** : trésor principal dans la salle du trône, derrière la porte aux trois sceaux (un sceau par quartier). Trésors secondaires dans les citernes, dont le niveau d'eau se règle par des vannes.
- **Ennemis** : gardiens de pierre (imposeurs : vulnérables seulement quand leur cœur est exposé), patrouilles en formation, un élite par quartier, boss dans la salle du trône.
- **Mémorable par** : la taille, les raccourcis qu'on ouvre et qu'on retrouve, et la silhouette en gradins visible depuis tout l'archipel, qui sert de repère de navigation.

---

## (c) Bestiaire en tiers

Budget de rencontre : piétaille 1 point, rang moyen 3, élite 8. Toutes les durées de télégraphie suivent le barème de la partie 6.3.

### Tier 1 : piétaille

| # | Ennemi | Rôle | Comportement |
|---|---|---|---|
| 1 | **Crabe des sables** | Nuée | Enterré, sort quand on passe (le sable bouge avant). Avance en crabe, pince courte. Carapace devant : il faut le frapper de côté ou le retourner. Fuit vers l'eau à basse vie. |
| 2 | **Moussaillon naufragé** | Défouloir | Coup de sabre simple, recule après avoir frappé. Lâche : s'enfuit s'il reste seul et va prévenir le camp. Avant le combat : pêche, dort, joue aux dés. |
| 3 | **Singe chapardeur** | Harceleur | N'attaque pas : vole un objet (pièces, munitions, carte) et s'enfuit dans les arbres. Le rattraper ou l'appâter avec une banane rend l'objet. Détourne l'attention pendant un combat. |
| 4 | **Squelette de marin** | Bretteur | Marche lente, coup lourd bien télégraphié. Se reconstitue une fois si son crâne n'est pas détruit ou jeté à l'eau. Variantes par matière, chacune avec une faiblesse (rouille à l'eau, craint la lumière). |
| 5 | **Mousquetaire de fortune** | Tireur | Garde 10 à 14 m, vise 0,8 s (reflet sur le canon), tire, recharge 2,5 s en criant. Recule si on approche, se met à couvert. Pénalisé en mêlée. |

### Tier 2 : rang moyen

| # | Ennemi | Rôle | Comportement |
|---|---|---|---|
| 6 | **Bretteur au tricorne** | Bretteur / défieur | Pare les attaques de face, riposte après trois coups bloqués. Enchaîne deux coups puis une fente longue (fenêtre de punition après la fente). Provoque en duel le joueur qui a fait le plus de dégâts. |
| 7 | **Brute au tonneau** | Tank | Porte un tonneau comme bouclier : invulnérable de face. Charge en ligne droite (grattement du sol, 1 s), s'assomme 1,5 s contre un mur ou un rocher. Protège le soutien de sa bande en se plaçant devant. |
| 8 | **Artificier** | Zone | Lance des bombes à mèche (cercle au sol, 1,2 s). Les bombes peuvent être renvoyées d'un coup. Pose des barils près des passages étroits. Explose s'il est tué par le feu. |
| 9 | **Sorcière des marées** | Soutien / invocatrice | Reste loin. Soigne un allié (rayon vert visible, interruptible), fait sortir deux noyés de l'eau toutes les 12 s tant qu'elle est debout. Se téléporte d'une flaque à l'autre quand on l'approche. Cible prioritaire. |
| 10 | **Harponneur** | Contrôleur | Lance un grappin (ligne au sol, 0,9 s) qui tire un joueur vers la bande ou l'immobilise 2 s ; un coéquipier peut couper la corde. Vise en priorité le porteur de coffre. |
| 11 | **Chien de garde** | Harceleur / alarme | Flaire les joueurs cachés, aboie (alerte toute la bande), contourne pour mordre dans le dos, lâche prise dès qu'on se retourne. Peut être distrait avec de la viande. |
| 12 | **Sentinelle à la cloche** | Soutien / alarme | Poste fixe sur une hauteur. Dès qu'elle voit un joueur, court vers la cloche (4 s) : si elle sonne, des renforts arrivent par le chemin opposé. La neutraliser d'abord, ou couper la corde de la cloche, change tout le combat. |

### Tier 3 : élites et solitaires

| # | Ennemi | Rôle | Comportement |
|---|---|---|---|
| 13 | **Second du capitaine** | Chef de bande | Donne des ordres criés qui changent la tactique de la bande (« Encerclez-les ! », « Repli ! »). Tant qu'il vit, la bande a un jeton de mêlée de plus. Deux pistolets puis sabre ; à 50 % de vie, il boit du rhum et devient plus rapide mais moins précis. |
| 14 | **Crabe cuirassé géant** | Solitaire | Garde une plage ou une épave. Invulnérable sauf aux articulations (visibles après ses attaques) et au ventre (quand il est retourné par un baril ou une chute de rocher). Balayage en cône, saut avec onde de choc en anneau. Évitable : ne quitte pas sa plage. |
| 15 | **Gardien de pierre** | Imposeur | Statue qui s'anime quand on prend un objet. Lent, coups dévastateurs en ligne. Son cœur ne s'expose que 3 s après une attaque lourde, ou quand deux joueurs activent deux glyphes en même temps (solo : un glyphe, exposition plus courte). |
| 16 | **Chasseur de primes** | Solitaire errant | Apparaît sur une île où les joueurs portent un gros butin. Traque à la trace, pose des pièges à mâchoires, tire de loin puis se déplace. Se retire à 30 % de vie et revient plus tard sur une autre île : un ennemi récurrent, avec un nom. |

### Boss

**Boss 1 : Capitaine Barbe-de-Corail** (boss de camp, Deux Cornes ou Chaudron)
- *Annonce* : son pavillon flotte sur l'île ; les moussaillons parlent de lui.
- *Phase 1 (100–66 %)* : duel au sabre et au pistolet. Motifs : enchaînement de trois coups, tir au jugé en cône, saut fendu (cercle).
- *Phase 2 (66–33 %)* : siffle ; son équipage arrive par vagues de trois, et il se replie sur une plate-forme d'où il tire au tromblon. Il faut monter le déloger ou faire tomber la plate-forme avec un baril.
- *Phase 3 (33–0 %)* : met le feu au camp (l'arène rétrécit), devient frénétique, mais chaque attaque lourde le laisse essoufflé 1,5 s.
- *Coop* : pendant la phase 2, un joueur peut retourner un canon du camp contre la plate-forme pendant que les autres tiennent l'équipage.
- *Butin* : sa clé, son tricorne, un morceau de carte vers la Citadelle.

**Boss 2 : La Mère des Marées** (boss de biome, Labyrinthe d'eau)
- *Annonce* : la marée se comporte bizarrement sur toute l'île ; les noyés murmurent son nom.
- *Phase 1* : elle reste sous l'eau ; seuls ses tentacules sortent (ombre sous la surface, 1 s avant la frappe). On frappe les tentacules ; trois tentacules coupés la font émerger.
- *Phase 2* : elle émerge au centre. Motifs : crachat d'encre (zone qui aveugle : la caméra s'obscurcit par endroits), vague en anneau à sauter ou à éviter sur un ponton, saisie d'un joueur qu'un coéquipier doit libérer.
- *Phase 3* : elle fait monter l'eau. L'arène se réduit à quelques épaves et pontons ; elle plonge et ressurgit sous un joueur (bulles, 1,2 s). Les canons d'une épave peuvent être rechargés pour la toucher de loin.
- *Coop* : un joueur aux canons, un qui éclaire à la lanterne pour dissiper l'encre, les autres au contact. Solo : fenêtres plus longues, pas d'encre totale.
- *Butin* : la perle de marée, objet-clé qui permet de faire baisser l'eau dans certains donjons d'autres îles.

**Boss 3 : Le Roi Englouti** (boss de l'île capitale, Citadelle)
- *Annonce* : sa statue est dans chaque quartier ; les trois sceaux racontent sa chute.
- *Phase 1* : un colosse en armure sur son trône, qui se lève. Lent, coups en ligne et en cône sur toute la largeur de la salle ; les piliers de la salle arrêtent ses coups mais se brisent.
- *Point médian* : il s'effondre ; fausse victoire. Le sol cède : tout le monde tombe dans la grande citerne.
- *Phase 2* : l'armure est vide ; son spectre en sort, rapide, qui se téléporte et lance des lames en éventail. L'armure reste un obstacle à utiliser comme couvert. Il n'est vulnérable que dans la lumière : il faut ouvrir les vannes de la citerne pour faire entrer le jour par les reflets de l'eau.
- *Phase 3* : il réintègre l'armure, qui prend l'eau : chaque vanne ouverte la ralentit. Tout l'arsenal des deux phases, plus des gardiens de pierre mineurs.
- *Coop* : les vannes sont réparties aux quatre coins ; à plusieurs on les ouvre en parallèle, seul on les ouvre une à une entre deux esquives.
- *Mise à mort et victoire* : la citadelle se vide de son eau, révélant le trésor et un nouveau quai : l'île devient un port utilisable.

---

## (d) Sources

Regroupées par thème. Les mentions « non consulté directement » indiquent une source connue par un résumé ou une reprise.

### Conception d'îles et de mondes ouverts
- Game Maker's Toolkit, « How Nintendo Solved Zelda's Open World Problem » (version texte) : https://gmtk.substack.com/p/how-nintendo-solved-zeldas-open-world
- Traduction par Matt Walker des conférences CEDEC 2017 de Nintendo (version illustrée) : https://gist.github.com/idbrii/e39fe96279aa1670319bfa521d907399
- Nintendo Life, « Zelda: Breath of the Wild's ingenious design is all about triangles » : https://www.nintendolife.com/news/2017/10/zelda_breath_of_the_wilds_ingenious_design_is_all_about_triangles_apparently
- Source Gaming, « Holism: Breath of the Wild's Golden Triangles » : https://sourcegaming.info/2017/11/25/holism-breath-of-the-wilds-golden-triangles/
- Radiator Blog (Robert Yang), « Open world level design: spatial… » : https://www.blog.radiator.debacle.us/2017/10/open-world-level-design-spatial.html
- Game Developer, « 5 design lessons learned from The Legend of Zelda: Breath of the Wild » : https://gamedeveloper.com/design/5-design-lessons-learned-from-i-the-legend-of-zelda-breath-of-the-wild-i-
- Game Developer, « What Mario Learned from Mickey Mouse, part 3: Decision making and weenies » : https://gamedeveloper.com/design/what-mario-learned-from-mickey-mouse---part-3-decision-making-and-weenies
- Unity, « Bases de la conception de niveaux : guider les joueurs sans leur dire » (français) : https://unity.com/fr/blog/level-design-basics
- Unity, « Level design basics: Guiding players without telling them » : https://unity.com/blog/level-design-basics
- The Level Design Book (site canonique) : https://book.leveldesignbook.com
- Dan Taylor, « Ten Principles for Good Level Design », GDC 2013 : https://gdcvault.com/play/1017803/Ten-Principles-for-Good-Level
- 80.lv, résumé de « Ten Principles for Good Level Design » : https://80.lv/articles/gdc-ten-principles-for-good-level-design
- Centre for Digital Media, « Universal level design techniques » (portes et clapets) : https://blogs.thecdm.ca/techspeak/?p=2488
- CNC, « Comment travaille un level designer ? » (français) : https://www.cnc.fr/jeu-video/actualites/comment-travaille-un-level-designer_1187385
- B. Todaro, « Architecture du paysage et level design », Université de Liège, 2016 (français) : https://orbi.uliege.be/bitstream/2268/306569/1/Todaro_B_2016_Architecture_du_paysage_and_Level_Design.pdf
- Thèse sur le langage du level design dans The Legend of Zelda, Université de Lorraine, 2020 (français) : https://hal.univ-lorraine.fr/tel-03098076v1/document
- Journal du Geek, chronique BioShock / Prey (français) : https://www.journaldugeek.com/2017/05/04/chronique-bioshock-prey/
- Christopher Totten, « An Architectural Approach to Level Design », 2e éd. (non consulté directement) : https://www.routledge.com/An-Architectural-Approach-to-Level-Design/Totten/p/book/9780815361367

### Sea of Thieves
- Wiki, liste et comptage des îles : https://seaofthieves.wiki.gg/wiki/Islands
- Wiki, grandes îles : https://seaofthieves.wiki.gg/wiki/Large_Islands
- Wiki, régions : https://seaofthieves.wiki.gg/wiki/Regions
- Wiki, cartes à énigmes : https://seaofthieves.wiki.gg/wiki/Riddle_Map
- Fandom, « How Riddles Work in Sea of Thieves » : https://www.fandom.com/articles/sea-thieves-riddles
- Wiki, caveaux anciens : https://seaofthieves.wiki.gg/wiki/Ancient_Vaults
- Wiki, clés de caveau : https://seaofthieves.wiki.gg/wiki/Treasure_Vault_Keys
- Wiki, squelettes : https://seaofthieves.wiki.gg/wiki/Skeletons
- Wiki, seigneurs squelettes : https://seaofthieves.wiki.gg/wiki/Skeleton_Lords
- Shacknews, « How to Kill All Skeleton Types in Sea of Thieves » : https://www.shacknews.com/article/104080/how-to-kill-all-skeleton-types-in-sea-of-thieves
- PCGamesN, aperçu de Sea of Thieves (îles faites main et à fonction) : https://pcgamesn.com/sea-of-thieves/sea-of-thieves-preview
- WCCFTech, « Sea of Thieves Map Size Is Linked To The Frequency of Encounters » : https://wccftech.com/sea-of-thieves-map-size-linked-frequency
- Forum officiel, « Finding the Beta Map Size (Amateur Cartography) » : https://seaofthieves.com/forum/post/347306
- Windows Central, interview sur la vision du monde de Sea of Thieves : https://www.windowscentral.com/the-sea-of-thieves-vision-interview
- Game Developer, « How emotional psychology and The Goonies inspired Sea of Thieves » : https://www.gamedeveloper.com/design/how-emotional-psychology-and-the-goonies-inspired-i-sea-of-thieves-i-
- Game Developer, vidéo GDC 2018 « How Rare crafted the look and feel of Sea of Thieves » : https://gamedeveloper.com/art/video-how-rare-crafted-the-look-and-feel-of-i-sea-of-thieves-i-
- 80.lv, « GDC18: Visual Adventures on Sea of Thieves » : https://80.lv/articles/gdc18-visual-adventures-on-sea-of-thieves
- ArtStation, Joachim Coppens, « Sea of Thieves – The Ancient Isles » : https://joachimcoppens.artstation.com/projects/832eG
- Mein-MMO, « Head of Sea of Thieves explains: We reward you when you fail » : https://mein-mmo.de/en/head-of-sea-of-thieves-explains-we-reward-you-when-you-fail,642729

### Autres jeux étudiés
- Zelda Dungeon, wiki « Great Sea » (Wind Waker) : https://www.zeldadungeon.net/wiki/Great_Sea
- Zelda Dungeon, « The Wind Waker – An Ocean of Missed Potential » : https://www.zeldadungeon.net/the-legend-of-zelda-the-wind-waker-an-ocean-of-missed-potential/
- Zelda Dungeon, « Defending the Great Sea » : https://www.zeldadungeon.net/defending-the-great-sea/
- Zelda Wiki, « Secret Cave Chart » : https://zeldawiki.wiki/wiki/Secret_Cave_Chart
- Zelda Dungeon, cartes au trésor de Wind Waker : https://zeldadungeon.net/wiki/The_Wind_Waker_Treasure_Chart
- GamesRadar, « Breath of the Wild has a ridiculous amount of Korok seeds… » : https://www.gamesradar.com/zelda-breath-of-the-wild-has-a-ridiculous-amount-of-korok-seeds-because-you-were-never-meant-to-find-them-all
- PC Gamer, interview d'Ashraf Ismail (Black Flag) : https://www.pcgamer.com/interview-assassins-creed-iv-black-flag-game-director-ashraf-ismail
- Destructoid, « How Super Mario 64 influenced Assassin's Creed IV » : https://www.destructoid.com/how-super-mario-64-influenced-assassins-creed-iv/
- Prima Games, guide des collectibles de Black Flag : https://primagames.com/eguides/assassins-creed-iv-black-flag-eguide/reference-analysis/collectibles
- Unity, « Smoke, mirrors, and scrolling textures: Behind the scenes of TUNIC » : https://blog.unity.com/games/smoke-mirrors-and-scrolling-textures-behind-the-scenes-of-tunic
- Game Developer, « Designing content for "no one" to create Tunic's vibrant and charming world » : https://www.gamedeveloper.com/design/designing-content-for-no-one-an-interview-with-the-team-behind-tunic
- Game Developer, vidéo GDC « How the Tunic developers built a mysterious world » : https://www.gamedeveloper.com/design/video-how-the-tunic-developers-built-a-mysterious-world
- Red Bull, interview d'Andrew Shouldice (version française) : https://www.redbull.com/fr-fr/andrew-shouldice-tunic-interview
- Vice, « The delicate balancing act of making a video game built on secrets » : https://www.vice.com/en/article/the-delicate-balancing-act-of-making-a-video-game-built-on-secrets
- SegmentNext, interview Windbound : https://segmentnext.com/2020/06/03/windbound-interview/
- Well Played, « Made in Australia: we talk Windbound with 5 Lives Studios » : https://www.well-played.com.au/made-in-australia-we-talk-windbound-with-5-lives-studios/
- Well Played, critique de Windbound : https://www.well-played.com.au/windbound-review/
- Game Developer, « Looting game design gold from Sid Meier's Pirates! » : https://www.gamedeveloper.com/business/looting-game-design-gold-from-sid-meier-s-pirates-
- Manuel de Pirates! : https://www.mocagh.org/miscgame/pirates-manual.pdf
- Raft Wiki, îles : https://raft.fandom.com/wiki/Islands
- Valheim, emplacements et règles de placement (données de fans) : https://metabot.gg/en/valheim/locations
- Valheim, génération du monde (données de fans) : https://metabot.gg/en/valheim/map
- Valheimians, « How to procedurally generate locations in Valheim » : https://www.valheimians.com/article/how-to-procedurally-generate-locations-in-valheim/
- Don't Starve Wiki, génération du monde : https://dontstarve.wiki.gg/wiki/World_Generation
- Forum Klei, « Guide: intro to worldgen » : https://kleiforums.com/topic/48070-guide-intro-to-worldgen/
- Failbetter Games, « Mapping the Sunless Sea: geography » : https://www.failbettergames.com/news/mapping-the-sunless-sea-geography-spoilers
- Failbetter Games, « Sunless Skies pre-production: talkin' 'bout proc generation » : https://www.failbettergames.com/sunless-skies-pre-production-talkin-bout-proc-generation
- Game Developer, « Generating the world of Sunless Skies » : https://gamedeveloper.com/design/generating-the-world-of-sunless-skies
- Kotaku, « Hades' level design is less random than it seems » : https://kotaku.com/hades-level-design-is-less-random-than-it-seems-1845254545
- nex-3.com, « Hades II Has a Legibility Problem » : https://nex-3.com/blog/hades-ii-has-a-legibility-problem/
- Prima Games, guide de Thésée et Astérion (Hades) : https://primagames.com/tips/hades-boss-guide-how-beat-theseus-and-asterius
- Wiki Diablo, modificateurs de boss et d'élites : https://di.diablowiki.net/Boss_mods
- Maxroll, affixes d'élites de Diablo IV : https://maxroll.gg/d4/resources/elites-affixes

### Génération procédurale
- Red Blob Games, « Making maps with noise functions » : https://www.redblobgames.com/maps/terrain-from-noise/
- Red Blob Games, « Polygonal Map Generation for Games » : https://www.redblobgames.com/maps/polygon-map-generation/
- Red Blob Games, « Elevation Stamps » : https://www.redblobgames.com/x/2426-elevation-stamps/
- Red Blob Games, dépôt mapgen2 : https://github.com/redblobgames/mapgen2
- Article SoCG 2026 sur les masques d'île à plusieurs ancres : https://drops.dagstuhl.de/storage/00lipics/lipics-vol367-socg2026/LIPIcs.SoCG.2026.101/LIPIcs.SoCG.2026.101.pdf
- Robert Bridson, « Fast Poisson Disk Sampling in Arbitrary Dimensions », SIGGRAPH 2007 : https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph07-poissondisk.pdf
- Extreme Learning, version améliorée de l'algorithme de Bridson : https://extremelearning.com.au/an-improved-version-of-bridsons-algorithm-n-for-poisson-disc-sampling/
- « Procedural Urban Forestry » (disque de Poisson à rayons variables) : https://arxiv.org/pdf/2008.05567
- Unity Terrain Tools, érosion hydraulique : https://docs.unity3d.com/Packages/com.unity.terrain-tools@5.1/manual/erosion-hydraulic.html
- GameDev.net, « Real-time hydraulic erosion using compute shaders » : https://www.gamedev.net/blogs/entry/2277785-real-time-hydraulic-erosion-using-compute-shaders-opengl
- Sebastian Lague, vidéo « Coding Adventure: Hydraulic Erosion » (non consultée directement, à chercher par son titre sur YouTube)
- 80.lv, Oskar Stålberg et la wave function collapse dans Bad North : https://80.lv/articles/using-wave-function-collapse-algorithm-for-dioramas
- Game Developer, « How Townscaper Works: A Story Four Games in the Making » : https://www.gamedeveloper.com/game-platforms/how-townscaper-works-a-story-four-games-in-the-making
- Dépôt d'origine de WaveFunctionCollapse : https://github.com/mxgmn/WaveFunctionCollapse
- Boris the Brave, « Dungeon Generation in Enter The Gungeon » : https://www.boristhebrave.com/2019/07/28/dungeon-generation-in-enter-the-gungeon
- Game Developer, « Q&A: The guns and dungeons of Enter the Gungeon » : https://gamedeveloper.com/design/q-a-the-guns-and-dungeons-of-i-enter-the-gungeon-i-
- Boris the Brave, « Dungeon Generation in Unexplored » : https://www.boristhebrave.com/2021/04/10/dungeon-generation-in-unexplored/
- Game Developer, « Unexplored's secret: cyclic dungeon generation » : https://gamedeveloper.com/design/unexplored-s-secret-cyclic-dungeon-generation-
- Boris the Brave, « Graph Rewriting for Procedural Level Generation » : https://www.boristhebrave.com/2021/04/02/graph-rewriting/
- Joris Dormans, « Adventures in Level Design », PCG Workshop 2010 : https://www.pcgworkshop.com/archive/dormans2010adventures.pdf
- Dormans et Bakkes, « Generating Missions and Spaces for Adaptable Play Experiences », 2011 : https://www.pcgworkshop.com/archive/dormans2011design.pdf
- Rune Skovbo Johansen, « Procedural game progression dependency graphs » : https://blog.runevision.com/2024/10/procedural-game-progression-dependency.html
- Bob Nystrom, « Rooms and Mazes: A Procedural Dungeon Generator » : https://journal.stuffwithstuff.com/2014/12/21/rooms-and-mazes
- Forum Godot, « Need help with shaping procedural island generation » : https://forum.godotengine.org/t/need-help-with-shaping-procedural-island-generation/52574
- Forum Godot, « Gradual beach at the border of map » : https://forum.godotengine.org/t/gradual-beach-at-the-border-of-map/131262
- Blog d'Alex Laverty, terrain par bruit de Perlin dans Godot : https://alexlaverty.github.io/blog/terrain-from-perlin-noise/
- Godot Forums, collision HeightMapShape3D qui ne correspond pas au maillage : https://godotforums.org/d/35135-help-generating-heightmapshape3d-that-matches-vertex-shader
- Documentation Godot, FastNoiseLite : https://docs.godotengine.org/en/stable/classes/class_fastnoiselite.html

### Relief, vue du dessus, occlusion
- MY.GAMES, « Top-down shooter level design: how map design supports game mechanics » : https://medium.com/my-games-company/top-down-shooter-level-design-how-map-design-supports-game-mechanics-6ae39fdd095d
- Jeu de tuiles « Verdant 02 — Elevation Tileset » (remarque sur la lecture des falaises) : https://csaf.itch.io/verdant-02-elevation
- RPG Maker, « Tips and Tricks: Mapping Cliffs » : https://rpgmakerweb.com/blog/tips-and-tricks-mapping-cliffs
- 80.lv, « Artist recreates Baldur's Gate 3's occlusion shader in Godot » : https://80.lv/articles/artist-recreates-baldur-s-gate-3-s-occlusion-shader-in-godot
- Godot Shaders, « Camera occlusion dither » : https://godotshaders.com/?p=12207
- GameDev.net, « Hide objects blocking player view » : https://www.gamedev.net/tutorials/programming/general-and-gameplay-programming/hide-objects-blocking-player-view-r3215
- Game Developer, « The crop circle effect in Bombernauts » : https://gamedeveloper.com/programming/the-crop-circle-effect-in-bombernauts
- ArtStation, Brendan Sullivan, « Occlusion Cutout Shader – inspired by Baldur's Gate III » : https://brendansullivan.artstation.com/projects/WXVnyD

### Trésors, énigmes, donjons
- Boris the Brave, « Lock and Key Dungeons » : https://www.boristhebrave.com/2021/02/27/lock-and-key-dungeons
- Game Maker's Toolkit, série « Boss Keys », épisode « The Legend of Zelda: Link's Awakening's dungeon design » (transcription) : https://amara.org/v/C3BF3
- Game Maker's Toolkit, « Boss Keys », épisode « A Link to the Past's dungeon design » (transcription) : https://amara.org/v/C3BF5
- Game Maker's Toolkit, « Boss Keys », épisode « Ocarina of Time's dungeon design » (transcription) : https://amara.org/v/C3BF1
- Room Escape Artist, analyse de la série Boss Keys : https://roomescapeartist.com/2017/09/10/boss-keys-analysis-zelda-dungeons/
- Zelda Dungeon, vidéo sur les donjons « boîtes à énigmes » de Zelda : https://www.zeldadungeon.net/check-out-this-video-exploring-the-zelda-series-puzzle-box-dungeons/

### Ennemis, IA, boss
- Game Developer, « Enemy design and enemy AI for melee combat systems » : https://gamedeveloper.com/design/enemy-design-and-enemy-ai-for-melee-combat-systems
- Game Developer, « Enemy attacks and telegraphing » : https://gamedeveloper.com/design/enemy-attacks-and-telegraphing
- StraySpark, « Attack token system (UE5): group combat that feels fair » : https://www.strayspark.studio/blog/attack-token-system-ue5-group-combat-that-feels-fair
- Tuts+, « Battle circle AI: let your player feel like they're fighting lots of enemies » : https://code.tutsplus.com/battle-circle-ai-let-your-player-feel-like-theyre-fighting-lots-of-enemies--gamedev-13535t
- Packt, « Building a fighting circle » (Unity AI Cookbook) : https://subscription.packtpub.com/book/game-development/9781788626170/5/ch05lvl1sec60/building-a-fighting-circle
- Jeff Orkin, « Three States and a Plan: The A.I. of F.E.A.R. », GDC 2006 : https://pages.cs.wisc.edu/~dyer/cs540/handouts/gdc2006_orkin_jeff_fear.pdf
- Game Developer, « Are behavior trees a thing of the past? » : https://gamedeveloper.com/programming/are-behavior-trees-a-thing-of-the-past-
- Michael Booth, « The AI Systems of Left 4 Dead » : https://cdn.fastly.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf
- Valve Developer Wiki, scripts du directeur de Left 4 Dead 2 : https://developer.valvesoftware.com/wiki/Left_4_Dead_2/Scripting/Director_Scripts
- Étude de l'IA de The Last of Us (perception) : https://nicholasperell.vercel.app/posts/tlou-ai-study
- Bugnet, « How to design enemy attack telegraphs » : https://bugnet.io/blog/how-to-design-enemy-attack-telegraphs
- Bugnet, « How to design a multi-phase boss fight » : https://bugnet.io/blog/how-to-design-a-multi-phase-boss-fight
- Mike Stout, « Boss Battle Design and Structure » : https://www.gamedeveloper.com/design/boss-battle-design-and-structure
- Itay Keren, « Boss Up: Boss Battle Design Fundamentals and Retrospective », GDC 2018 : https://www.gamedeveloper.com/design/video-boss-battle-design-fundamentals
- Game Developer, « 7 memorable boss fights that every developer should study » : https://www.gamedeveloper.com/design/7-memorable-boss-fights-that-every-developer-should-study
- Game Maker's Toolkit, « What Makes a Good Combat System? » (transcription) : https://amara.org/v/C3BEd
- Game Maker's Toolkit, « What Makes Good AI? » (résumé de seconde main) : https://thewizardscode.blogspot.com/2023/04/what-makes-good-ai-video-summary.html
- LimboAI, dépôt : https://github.com/limbonaut/limboai
- LimboAI, documentation : https://limboai.readthedocs.io/
- GameFromScratch, « Beehave Behavior Trees for Godot » : https://gamefromscratch.com/beehave-behavior-trees-for-godot/

### Coopération et boucle de jeu
- Reuter et al., « Game Design Patterns for Collaborative Player Interactions », DiGRA 2014 : https://dl.digra.org/index.php/dl/article/view/639
- Mémoire de Chalmers sur les patrons de coopération à quatre joueurs : https://odr.chalmers.se/bitstreams/c80d6e29-596c-4187-b2d7-01a00b7733bd/download
- Mémoire de Chalmers sur la coopération à trois joueurs : https://odr.chalmers.se/bitstreams/27cf3629-723c-47b5-b938-96f8db7da3a1/download
- Mémoire de l'université de Tampere sur le jeu coopératif : https://trepo.tuni.fi/bitstream/10024/131020/2/HonkalaLasse.pdf
- Co-Optimus, principes de coopération de Splinter Cell: Conviction : https://www.co-optimus.com/article/5783/splinter-cell-conviction-s-co-op-design-core-principles-to-encourage-co-op-behavior.html

### Limites de cette recherche
- Aucune dimension officielle en mètres n'a été trouvée pour les îles de Sea of Thieves, de Black Flag ou de Wind Waker. Le barème de tailles de la partie 1.4 est une proposition.
- Les chiffres de Valheim, Raft, Diablo et des squelettes de Sea of Thieves viennent de wikis et de sites de données tenus par des joueurs.
- L'attribution des jetons d'attaque à une conférence GDC sur Doom (2016) repose sur une seule source indirecte.
- Les durées de télégraphie n'ont pas de norme publiée : le barème de la partie 6.3 part du temps de réaction humain et de recommandations générales, et doit être réglé en jeu.
- Les conférences GDC citées (Dan Taylor, Itay Keren, Jeff Orkin, Rare) ont été consultées par leurs résumés, leurs diapositives ou leurs comptes rendus, pas en vidéo intégrale.
- Peu de sources francophones de fond existent sur le sujet précis des îles ; les sources françaises retenues portent sur le level design en général.

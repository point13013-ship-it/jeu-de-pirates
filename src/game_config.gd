class_name GameConfig
extends RefCounted
## Toutes les valeurs d'équilibrage et de réglage de la refonte (vitesses, durées, pourcentages, volumes, fréquences), au même
## endroit. On ne met plus de nombre « en dur » dans le code pour ces réglages : on ajoute une constante ici et on s'y réfère.
## Les réglages plus anciens restent où ils étaient (data/*.json, constantes en tête des scripts) tant qu'on n'y touche pas.
## Ordre : par lot de la refonte (voir le récapitulatif de chaque lot).

# ------------------------------------------------------------------ Lot 1 : corrections de bugs

## 1.1 Saut sur une estrade ou un plateau : à l'atterrissage, on se pose sur la plus haute surface SOUS les pieds (jusqu'à une
## marche au-dessus). Si le point exact d'atterrissage est trop au bord, on cherche une place libre à cette distance (m) au plus.
const LANDING_SEARCH := 0.6

## 1.2 Interface : marge au bord de l'écran et écart entre deux blocs empilés (pixels, avant le curseur « Taille de l'interface »).
const HUD_MARGIN := 12.0
const HUD_MARGIN_TOP := 8.0
const HUD_STACK_GAP := 4

## 1.3 Retour visuel d'un coup sur un ennemi : flash teinté court (80 à 100 ms), petit recul du corps, étincelles.
const HIT_FLASH_TIME := 0.09          ## s
const HIT_FLASH_COLOR := Color(1.0, 0.35, 0.12)   ## rouge-orangé
const HIT_FLASH_ALPHA := 0.55         ## opacité au début du flash (il s'éteint ensuite)
const HIT_RECOIL_VISUAL := 0.12       ## m : le corps part en arrière de cette distance au moment du coup
const HIT_SPARKS := 8                 ## nombre d'étincelles

## 1.4 Couleurs exactes des pirates (filtre « pixel art ») : nombre de couleurs que la palette peut garder. Elle est refaite à partir
## des pirates affichés (le joueur en premier) ; plus grand coûterait cher au filtre (il compare chaque pixel à toute la liste).
const PIRATE_PALETTE_MAX := 512

## 1.5 Ville : tout ce qui est entièrement à l'ouest de cette abscisse (m, monde) est retiré au chargement (la plage buguée et ses
## palmiers). Le sol de la ville s'arrête à -41,5.
const TOWN_SAND_CUT_X := -41.8

## Prototype de refonte graphique (12/11/2026, design/bible-direction-artistique.md) : lumière en paliers, contours de
## silhouette et reflets d'arête, couleurs vraies. --look=1 au lancement : l'ancien rendu, pour comparer.
const LOOK_V2 := true
const TOON_ROUGHNESS := 0.3          ## plus bas : frontière ombre/lumière plus nette
const TOON_SUN_SCALE := 0.62         ## soleil tempéré en lumière à paliers (sinon les couleurs claires « brûlent »)
const TOON_AMBIENT_SCALE := 1.12     ## ambiance (froide) un peu plus présente : ombres colorées
const TOON_SSAO := true               ## ombre de contact (occlusion ambiante) : les objets se posent au lieu de flotter
const TOON_SSAO_RADIUS := 0.9         ## m : portée de l'ombre de contact
const TOON_SSAO_INTENSITY := 3.0
const TOON_SSAO_LIGHT := 0.25         ## 0…1 : part de l'ombre de contact qui mord aussi sur la lumière directe

## 1.6 Pluie : elle tombe partout dans la zone de météo, pas en colonne au-dessus du bateau.
const RAIN_AREA := 70.0               ## m : côté du carré de pluie autour de la caméra (assez large pour le plus fort dézoom)
const RAIN_DROPS := 2600              ## gouttes à pleine intensité
const RAIN_SPLASHES := 900            ## impacts de gouttes sur l'eau à pleine intensité
const RAIN_FALL_SPEED := 16.0         ## m/s
const RAIN_TOP := 14.0                ## m au-dessus de la mer d'où partent les gouttes
const RAIN_DROP_WIDTH := 0.05         ## m : épaisseur d'un trait (l'image est en basse résolution : plus fin, il disparaît)
const RAIN_DROP_LENGTH := 0.8         ## m
const RAIN_ALPHA := 0.28            ## (0,4 au premier essai : un peu trop opaque selon Jimmy)
const RAIN_RENDER_PRIORITY := 10      ## dessinée après la surface de la mer (transparente), sinon la mer la cache

## 1.7 Coque : un saut ne se pose plus de l'autre côté d'un mur (cabine) ni à travers le toit de la cabine. Quand il ne peut se
## poser nulle part sur le pont, le pirate tombe à l'eau à cette distance (unités du modèle) à l'extérieur de la coque.
const HULL_OUTSIDE_MARGIN := 0.15
## À la nage, on ne remonte à bord que par une échelle de coque : à moins de cette distance (m) de son pied.
const LADDER_SWIM_REACH := 1.8

# ------------------------------------------------------------------ Lot 2 : personnage, actions et interactions

## 2.1 Sprint : multiplicateur appliqué à l'ancien facteur de course (1,7) : -10 %.
const SPRINT_SCALE := 0.9

## 2.2 Saut : on garde l'élan pris au sol, on ne peut que l'infléchir ; la descente est plus rapide que la montée.
const AIR_CONTROL := 6.0              ## m/s² : de combien on peut corriger sa vitesse horizontale en l'air
const AIR_DRAG := 1.5                 ## m/s² : l'élan s'use un peu si on lâche les flèches
const AIR_STANDING_SPEED := 0.55      ## saut sur place : vitesse horizontale maximale qu'on peut se donner (x la marche)
const FALL_GRAVITY_MULT := 1.7        ## la gravité en descente (x la gravité en montée)

## 2.3 Saut : petit écrasement à l'appel et à la réception (le sprite est en pixel art : pas d'images dédiées), poussière.
const JUMP_SQUASH := 0.14             ## part d'écrasement
const JUMP_SQUASH_TIME := 0.12        ## s

## 2.4 Porter : un trésor posé au sol y reste ce temps (s), puis disparaît ; à terre on le reprend avec E.
const DROPPED_TTL := 300.0
const CARRY_HANDS_HEIGHT := 0.80      ## m : hauteur de l'objet porté (dans les mains, devant le torse)
const CARRY_TREASURE_SCALE := 0.68    ## taille de la maquette d'un trésor porté (avant : 1,5 au-dessus de la tête)
const CARRY_TOWARD_CAMERA := 0.35     ## m : avancé vers la caméra, pour passer devant le sprite

## Sons placés dans le monde (Sfx3D).
const SFX_HEAR_RANGE := 22.0          ## m : au-delà, on n'entend plus
const SFX_UNIT_SIZE := 4.0            ## m : distance où le son est à plein volume
const SFX_DB := -4.0                  ## décalage général des bruitages (mixage)
## Variation des bruitages (pratiques du son de jeu, voir design/refonte-journal.md « Son ») :
const SFX_PITCH_VAR := 1.06            ## hauteur tirée entre 1/1,06 et 1,06 (≈ ±1 demi-ton ; au-delà, ça sonne comique)
const SFX_VOL_VAR_DB := 1.5            ## volume tiré à ±1,5 dB
const SFX_RARE_WEIGHT := 0.15          ## poids d'une variante rare (« _rare_ » dans le nom du fichier) face à 1 pour les autres
const SFX_MIN_GAP := 0.06              ## s : un même son n'est pas relancé plus vite (deux pas, deux coups pile ensemble)
const SFX_MAX_VOICES := 4              ## lectures simultanées d'un même son au plus (les plus anciennes sont coupées)
const SFX_FAR_CUTOFF_HZ := 4000.0      ## les sons lointains sont étouffés (filtre passe-bas avec la distance)
const SFX_FAR_RANGE := 140.0           ## m : un coup de canon s'entend jusque-là
const SFX_FAR_UNIT_SIZE := 22.0        ## m : distance où un son fort est à plein volume
## Canon : deux couches jouées ensemble (pratique du « layering ») : la détonation (l'attaque, sèche) et le grondement qui
## roule derrière (le corps et la queue). De loin, la détonation s'efface plus vite que le grondement.
const CANNON_BLAST_VOL := 1.0
const CANNON_TAIL_VOL := 0.7

## Musique (voir src/audio/music.gd) : silences entre deux morceaux au calme, fondus, sortie lente du combat.
const MUSIC_GAP_MIN := 60.0            ## s de silence au moins entre deux morceaux (mer, escale, tempête)
const MUSIC_GAP_MAX := 240.0           ## (13/11 : 180 ; des silences plus longs par moments)
const MUSIC_TRACK_GAIN_MIN := 0.55     ## au calme, un morceau démarre entre ce volume et 100 % (13/11 : tous au même volume)
const MUSIC_FADE := 3.0                ## s : fondu enchaîné ordinaire (on accoste, la tempête se lève)
const MUSIC_FADE_COMBAT_IN := 0.5      ## s : le combat entre vite
const MUSIC_FADE_COMBAT_OUT := 5.0     ## s : et s'éteint lentement
const MUSIC_COMBAT_EXIT := 10.0        ## s sans combat avant de quitter la musique de combat
const MUSIC_DUCK_DB := -4.0            ## « ducking » : la musique baisse d'autant sur un coup de canon proche…
const MUSIC_DUCK_RELEASE := 0.6        ## … et remonte en ce temps (s)
## Combat en couches : la mélodie entre à partir de cette intensité (0…1) et est pleine à MUSIC_LAYER_FULL ; elle monte en
## MUSIC_LAYER_IN s et redescend en MUSIC_LAYER_OUT s. Intensité : ennemis engagés pondérés par leur rang, + coups reçus.
const MUSIC_LAYER_FROM := 0.25
const MUSIC_LAYER_FULL := 0.6
const MUSIC_LAYER_IN := 2.0
const MUSIC_LAYER_OUT := 6.0
const MUSIC_HIT_HEAT := 0.35           ## un coup reçu ajoute ça à l'intensité, qui retombe en MUSIC_HEAT_DECAY s
const MUSIC_HEAT_DECAY := 12.0
const MUSIC_STORM_AT := 0.5          ## force de la tempête (0…1) à partir de laquelle on passe au thème de tempête

## Actions longues (règle commune) : durées en secondes.
const ACTION_TIMES := {
	"anchor": 2.8,    # lever / jeter l'ancre (12/11 : 3,5 s, -20 %)
	"repair": 2.5,    # boucher une voie d'eau avec une planche (2 à 3 s par trou)
	"bail": 1.5,      # un seau : remplir puis vider
	"hoist": 1.6,     # hisser un camarade hors de l'eau
	"revive": 4.0,    # relever un camarade à terre (lot 4)
	"flint": 12.0,    # couper ses liens avec le silex caché (13/11)
}
const ACTION_MOVE_TOLERANCE := 0.12   ## de combien (unités du lieu) on peut glisser sans couper l'action (le pont tangue)
const BAIL_FILL_SHARE := 0.5          ## part de l'écopage passée à remplir le seau (le reste : le vider)
const HAMMER_EVERY := 0.42            ## s entre deux coups de marteau
const HOIST_REACH := 4.5              ## m : on peut attraper un camarade qui nage à cette distance (13/11 : 2,6 ; trop juste, le bateau bouge)
const LADDER_STEP_EVERY := 0.28       ## s entre deux pas sur l'échelle

# ------------------------------------------------------------------ Lot 3 : bateau du joueur

## 3.6 Navigation du bateau des joueurs (les ennemis ne changent pas ici : lot 5).
const PLAYER_SHIP_SPEED_MULT := 1.1          ## +10 % de vitesse
const PLAYER_UPWIND_PENALTY_SCALE := 0.9     ## malus de mauvais vent réduit de 10 % (12/11 : 25 %, le vent ne faisait pas assez de différence)

## 3.7 Houle (SkyCycle.swell : 0 calme … 1 tempête).
const SWELL_FROM_RAIN := 0.35         ## la pluie seule donne cette houle ; l'orage, la houle maximale
const SWELL_FADE := 0.05              ## vitesse de variation de la houle (par seconde)
const SWELL_WAVE_MAX := 2.2           ## hauteur des vagues à houle maximale (x la mer calme)
const SWELL_STEER_PENALTY := 0.2      ## maniabilité perdue à houle maximale (20 %)
const CAM_SWAY := 0.22                ## m : balancement de la caméra à houle maximale
const CAM_HEAVE_FOLLOW := 0.35        ## part du soulèvement du pont que la caméra suit

# ------------------------------------------------------------------ Lot 8 (en avance) : interface

const NPC_NAME_RANGE := 9.0           ## m : le nom d'un habitant s'affiche à cette distance
const CHART_CELL := 100.0             ## 10.2 : m, côté d'une case de la grille de la carte
const CHART_COL_OFFSET := 13          ## la colonne du port (x = 0) est la 14e lettre (N)
const CHART_ROW_OFFSET := 20          ## la ligne du port (z = 0) est la ligne 20

# ------------------------------------------------------------------ Lot 6 : météo et jour/nuit

const DAY_SECS := 2100.0              ## 8.1 : s pour un jour complet (avant : 1 500 s ; +40 %)
const WEATHER_SECS := 420.0           ## s : une tranche de temps (avant : 360)
## 8.2 : chances de chaque temps par tranche (avant : clair 62 %, brume 16 %, pluie 14 %, orage 8 %) …
const WEATHER_ODDS := {"clear": 0.83, "mist": 0.08, "rain": 0.06, "storm": 0.03}   # (13/11 : 76 / 10 / 10 / 4 %, encore trop de pluie)
## … et part de la tranche pendant laquelle il dure (avant : toute la tranche).
const WEATHER_SHARE := {"mist": 0.6, "rain": 0.55, "storm": 0.7}
## 8.3 : périodes de houle plus forte hors tempête (une chance par période, la houle monte puis retombe).
const SWELL_PERIOD := 240.0
const SWELL_ODDS := 0.3
const SWELL_PERIOD_STRENGTH := 0.55
## Moments de la journée (part du jour, 0 = minuit, 0,5 = midi) : début de chaque moment, pour l'affichage.
const DAY_MOMENTS := [[0.0, "Nuit"], [0.22, "Aube"], [0.3, "Matin"], [0.45, "Midi"], [0.56, "Après-midi"], [0.72, "Soir"], [0.8, "Crépuscule"], [0.86, "Nuit"]]

# ------------------------------------------------------------------ Lot 5 : ennemis

const ENEMY_HP_MULT := 1.5            ## 6.1 : coques 25 % plus résistantes
## 6.4 (rééquilibré le 12/11) : vitesse d'un ennemi par rapport à un joueur sur le même bateau, par rang (1 à 4).
## Avant la refonte : 0,82 partout. Avec +10 % joueurs et -10 % ennemis, l'écart montait à 33 % : poursuites trop faciles.
## Un ★ se sème sans peine, un ★★★ presque aussi rapide que nous ; le galion reste lourd (sa vitesse de base est déjà basse).
const ENEMY_SPEED_VS_PLAYER := [0.85, 0.92, 0.95, 0.95]
const ENEMY_SPAWN_FIRST := 90.0       ## 6.3 : s avant le premier ennemi
const ENEMY_SPAWN_MIN := 150.0        ## s entre deux apparitions (tiré au hasard entre les deux)
const ENEMY_SPAWN_MAX := 300.0
const ENEMY_REVEAL_TIME := 60.0       ## 6.7 : s sans échange de tirs avant que l'ennemi disparaisse de la carte
const ENEMY_REPAIR_EVERY := 6.0       ## 6.6 : s entre deux réparations (une planche bouche une voie d'eau)
const ENEMY_REPAIR_HP := 12.0         ## points de coque rendus par planche
const ENEMY_REPAIR_DELAY := 4.0       ## s sans coup reçu avant que l'équipage se mette à réparer
## 6.2 Rangs : poids d'apparition (plus haut = plus rare), bateau, résistance, canonniers en plus, stock de planches, couleurs
## (voiles, coque, pavillon : data/ship_skins.json) et table de butin : trésors (nombre, rareté), planches, boulets, or.
const ENEMY_RANKS := [
	{"weight": 52, "kind": "sloop", "hp": 1.0, "crew": 0, "planks": 2, "skin": {"sail": "black", "hull": "crimson", "flag": "black"},
		"loot": {"treasures": [2, 3], "rarity": 1.4, "planks": [3, 5], "balls": [2, 4], "gold": [60, 160]}},   # (= l'ancien butin d'un sloop)
	{"weight": 30, "kind": "sloop", "hp": 1.35, "crew": 1, "planks": 4, "skin": {"sail": "red", "hull": "ebony", "flag": "red"},
		"loot": {"treasures": [3, 4], "rarity": 1.8, "planks": [4, 6], "balls": [3, 6], "gold": [110, 220]}},
	{"weight": 14, "kind": "brigantin", "hp": 1.6, "crew": 2, "planks": 6, "skin": {"sail": "tempest", "hull": "navy", "flag": "white"},
		"loot": {"treasures": [4, 5], "rarity": 2.4, "planks": [5, 8], "balls": [5, 9], "gold": [200, 340]}},
	{"weight": 4, "kind": "galion", "hp": 2.2, "crew": 3, "planks": 10, "skin": {"sail": "purple", "hull": "royal", "flag": "gold"},
		"loot": {"treasures": [6, 8], "rarity": 3.2, "planks": [8, 12], "balls": [8, 14], "gold": [350, 600]}},
]
const MOB_SLOW_TIME := 1.5            ## 6.8 : s de ralentissement d'un mob touché par un boulet
const MOB_SLOW_FACTOR := 0.35         ## sa vitesse pendant ce temps (x la normale)
const MOB_BALL_DAMAGE := 3            ## PV qu'un boulet direct enlève à un mob
const MOB_BALL_RADIUS := 1.4          ## m : un boulet qui tombe à cette distance d'un mob le touche
const MOB_FOOD := 2                   ## 6.9 : rations qu'un mob a sur lui (chacune le soigne une fois)
const MOB_HEAL_TIME := 2.5            ## s pour manger
const MOB_HEAL_FRAC := 0.5            ## part de ses PV qu'une ration lui rend
const MOB_HEAL_BELOW := 0.45          ## il se soigne quand il lui reste moins de cette part de PV…
const MOB_HEAL_SAFE := 4.0            ## … et que personne n'est à moins de ces mètres

# ------------------------------------------------------------------ Lot 4 : mort, eau et réapparition (lot 3 plus bas)

const DOWNED_TIME := 25.0             ## s « à terre » avant de mourir si personne ne relève (plage 20 à 30 s)
const REVIVED_HP := 3                 ## cœurs rendus à un pirate relevé
const RESPAWN_TIME := 15.0            ## s avant de réapparaître sur le bateau (12/11 : 10, +5 s)
const RESPAWN_INVULNERABLE := 3.0     ## s d'invulnérabilité à la réapparition
const REVIVE_REACH := 1.6             ## m : distance pour relever un camarade
const SIREN_AFTER := 20.0             ## s dans l'eau avant qu'une sirène vienne
const SIREN_DISTANCE := 22.0          ## m : elle apparaît à cette distance (12/11 : 3 m, « toujours collée à nous »), du côté du bateau ;
                                      ## sa traînée de lumière se voit de loin, on nage jusqu'à elle et on la touche (E) à moins de 1,6 m
const SIREN_REACH := 1.6
const SIREN_BEAM_HEIGHT := 26.0       ## m : colonne de lumière au-dessus de la sirène (on la repère de loin, sous tous les angles)
const SHARKS_AFTER := 45.0            ## s : les requins rôdent
const SHARK_ATTACK_AFTER := 60.0      ## s : première morsure
const SHARK_BITE_EVERY := 6.0         ## s entre deux morsures
const SHARK_BITE_DAMAGE := 1          ## cœurs
const SHARK_SCARED := 8.0             ## s : un coup de sabre fait fuir le requin ce temps-là
const SHARK_COUNT := 2
## Comportement des requins (12/11) : ils arrivent de loin, tournent, chargent l'un après l'autre, mordent, repartent au large.
const SHARK_SPAWN_DIST := 32.0        ## m : où ils apparaissent
const SHARK_CIRCLE_R := 9.0           ## m : rayon de leur ronde au début
const SHARK_CIRCLE_TIGHT := 4.5       ## m : ils resserrent jusque-là quand la chasse est ouverte
const SHARK_CIRCLE_MIN := 5.0         ## s de ronde avant une charge (tiré entre les deux)
const SHARK_CIRCLE_MAX := 10.0
const SHARK_RETREAT_DIST := 14.0      ## m : après une morsure (ou un coup de sabre), ils s'éloignent jusque-là
const SHARK_SPEED_APPROACH := 5.0     ## m/s
const SHARK_SPEED_CIRCLE := 3.2       ## (vitesse quand il rôde : il passe et repasse à quelques mètres)
const SHARK_SPEED_ATTACK := 6.4       ## (12/11 : 8, « baisse un peu la vitesse de sprint des requins »)
const SHARK_TURN := 1.6               ## rad/s : vitesse à laquelle ils changent de cap (12/11 : 2,4 ; virages plus larges)
const DROWN_AFTER := 90.0             ## s : noyade (mort directe, sans passer à terre)
const DROWN_WARNING := 15.0           ## s : l'alerte s'affiche dans les dernières secondes
const DOWNED_SQUASH := 0.45           ## un pirate à terre est tassé de 45 % (provisoire, faute d'image « au sol »)

## 3.3 Cale : plus grande et plus vivante.
const HOLD_FLOOR_HALF := 1.8          ## m : demi-largeur du fond plat (avant : 1,2)
const HOLD_WALL_H := 1.8              ## m : mur du fond (avant : 1,4)
const HOLD_LENGTH_MULT := 1.8         ## la cale est 80 % plus longue que la coque utile (13/11 : 1,3 ; +40 %, en trois pièces)
const HOLD_DOOR_HALF := 0.75          ## m : demi-largeur de la porte d'une cloison intérieure de la cale
const HOLD_PORTHOLE_EVERY := 2.6      ## m entre deux hublots, sur le mur du fond
const HOLD_END_STORAGE := 1.3         ## m : à chaque bout, une réserve (tonneaux, caisses, sacs) où l'on ne marche pas
const HOLD_LANTERN_EVERY := 3.2       ## m entre deux lanternes
const HOLD_FLICKER := 0.18            ## vacillement des flammes (part de l'intensité)
const HOLD_AMBIENT := 0.42            ## lumière ambiante de la cale (part de celle du dehors) : les lanternes et l'écoutille éclairent

## 3.5 Toile des voiles : nombre de répétitions de la texture par unité du modèle (un lé = un quart de texture).
const SAIL_CANVAS_SCALE := 0.45
const SAIL_PANEL_DARK := 0.95         ## teinte des panneaux sombres (x la toile ; le modèle : 0,89)
const SAIL_PANEL_LIGHT := 1.02        ## teinte des panneaux clairs (le modèle : 1,04)

## 3.9 Roue du gouvernail.
const HELM_WHEEL_RADIUS := 0.44       ## unités du modèle (13/11 : 0,5 ; la barre est un peu plus petite, -12 %)
const HELM_GAIN_MIN := 0.55            ## chaque coup de barre grince entre 55 % et 100 % du volume (tiré au hasard)
const HELM_CRACK_PER_S := 0.6          ## craquements de bois par seconde (au plus vite de la roue), par-dessus le grincement
const HELM_WHEEL_TURNS := 1.5        ## tours de roue d'une butée à l'autre
const HELM_CREAK_VOL := 0.6           ## volume du grincement à pleine vitesse de rotation (13/11 : 0,9 ; son adouci et plus grave)

## 3.1 Coques agrandies (12/11/2026) : facteur de longueur appliqué par tools/art/blender/make_ship.py (KL). Sert à garder la poupe
## à sa place d'avant au port. À changer en même temps que KL dans le script Blender.
const HULL_LENGTH_GROWTH := 1.35
## Canons (12/11) : taille (avant 1,4) ; ils sont solides (on ne les traverse plus) mais bas : un saut les enjambe.
## Leur position vers le plat-bord se règle dans make_ship.py (CANNON_INSET : distance du bord, unités du modèle).
const CANNON_SIZE := 1.2

## Vent visible (12/11/2026, comme Sea of Thieves) : traînées qui filent dans le sens du vent autour du bateau, voiles qui se
## gonflent quand elles prennent bien le vent et qui battent quand il les prend mal, avec leurs sons.
const WIND_STREAKS := 46               ## traînées en même temps
const WIND_STREAK_LIFE := 2.4          ## s de vie d'une traînée
const WIND_STREAK_SPEED := 11.0        ## m/s
const WIND_STREAK_LENGTH := 2.6        ## m
const WIND_STREAK_WIDTH := 0.07        ## m (très fines)
const WIND_STREAK_ALPHA := 0.18        ## opacité (très légères ; 0,32 au départ, jugé un peu trop marqué)
const WIND_STREAK_BOX := Vector3(26.0, 4.5, 20.0)   ## m : demi-taille de la zone où elles naissent (au vent du bateau)
const WIND_STREAK_HEIGHT := 5.5        ## m au-dessus de l'eau : à hauteur des voiles
const SAIL_FADE := false               ## voiles transparentes quand elles cachent le pirate (abandonné le 12/11 : clignotait)
const SAIL_BULGE_SLACK := 0.08        ## (12/11 : 0,35 ; plus de contraste) creux des voiles qui ne prennent pas le vent (x le creux du modèle)
const SAIL_BULGE_FULL := 1.75          ## (12/11 : 1,3) creux des voiles gonflées (vent bien pris)
const SAIL_BULGE_TRIMMED := 0.7        ## (13/11) part du creux gardée quand les vergues sont orientées à fond (les voiles ne se touchent plus)
const SAIL_LUFF_AT := 0.5              ## en dessous de ce rendement, des voiles hissées battent (faseyent)
const SAIL_LUFF_FLAP := 0.38           ## (12/11 : 0,22) amplitude du battement
const SAIL_FILL_SOUND_AT := 0.6        ## rendement qu'on franchit en montant : « vlouf » des voiles qui se gonflent
const SAIL_FILL_SMOOTH := 1.2          ## s pour que le gonflement suive le rendement (pas de saut)

## Ville (12/11) : murmure des gens et enfants qui jouent, très bas, plein en ville et éteint au large.
const TOWN_CENTER := Vector2(0.0, -26.0)   ## monde x/z
const TOWN_SOUND_NEAR := 30.0
const TOWN_SOUND_FAR := 85.0
const TOWN_CROWD_VOL := 0.14
const TOWN_KIDS_VOL := 0.07
## Récifs (12/11) : autour des îles, à l'écart du port, espacés et variés (voir SeaRocks.generate).
const REEFS_AROUND_ISLANDS := true
const REEF_PER_ISLAND_MIN := 1
const REEF_PER_ISLAND_MAX := 3
const REEF_FROM_SHORE_MIN := 10.0      ## m au large du rivage
const REEF_FROM_SHORE_MAX := 30.0
const REEF_SPACING := 26.0             ## m entre deux récifs au moins
const REEF_PORT_CLEAR := 120.0         ## m autour du port sans aucun récif
const SWIM_STROKE_EVERY := 0.8       ## s entre deux brassées entendues quand on nage
const SWIM_LOOP_VOL := 0.32          ## volume du remous continu quand on nage (sans Maj)
const SWIM_ROLL := 0.17              ## rad : roulis du corps à chaque brassée (faute d'images de nage dessinées)
const SAND_BAND := 3.4               ## m du rivage d'une île où l'on marche dans le sable (au-delà : l'herbe)

## Caméra (12/11) : molette enfoncée + haut/bas pour l'incliner entre ces angles (°, 40 = vue de base) ; trois clics de molette
## en moins de CAM_RESET_CLICK_GAP s entre chaque pour revenir à la vue de base.
const CAM_ELEV_MIN := 16.0             ## (12/11 : 24 ; plus bas, on voit loin devant, presque à hauteur d'yeux)
const CAM_ELEV_MAX := 72.0
const CAM_LOOKAHEAD := 7.0             ## m : de combien la caméra glisse devant l'étrave à pleine vitesse (x2 en vue rasante)
const CAM_RESET_CLICK_GAP := 0.4
## Touche M (essais) : le pirate vole au-dessus de la carte, vite, pour aller voir les îles.
const FLY_SPEED := 45.0                ## m/s
const FLY_FAST := 3.0                  ## x avec Maj
const FLY_HEIGHT := 14.0               ## m au-dessus de l'eau

## Pirates (images plates) : dessinés un peu vers la caméra pour ne pas se couper sur les meubles, et silhouette visible à
## travers le décor qui les cache (alpha 0 : pas de silhouette).
const SPRITE_DEPTH_PUSH := 0.6         ## m
const SPRITE_XRAY_COLOR := Color(0.85, 0.9, 1.0, 0.5)   ## teinte claire et opacité du pirate vu à travers un décor (13/11 : opacité 0,38)
const SPRITE_XRAY_TINT := 0.15         ## part de cette teinte mêlée à ses vraies couleurs (13/11 : 1, une silhouette blanche unie)

## Dans la cabine, les murs côté caméra sont rabattus à cette hauteur (unités du modèle, x1,5 = m) au lieu de disparaître.
const CABIN_STUB_WALL := 0.32

## 3.8 Son de coque : renfort par la houle et gerbes au hasard.
const HULL_SWELL_VOL := 0.25
const HULL_SPLASH_MIN := 1.2          ## s (à pleine vitesse, ces écarts sont raccourcis)
const HULL_SPLASH_MAX := 3.5

## Brume (13/11) : la brume est dans la 3D (profondeur et ras de l'eau, SkyCycle). Les « bancs » ajoutés par le filtre d'image
## s'amassaient d'un côté de l'écran en traînées opaques : coupés. Densité au loin : base + gain x force de la brume.
const FOG_SCREEN_BANKS := 0.0         ## part des bancs du filtre d'image (12/11 : 0,35)
const FOG_DENSITY_BASE := 0.21        ## (12/11 : 0,25 ; -15 %)
const FOG_DENSITY_GAIN := 0.6         ## (12/11 : 0,7 ; -15 %)

# ------------------------------------------------------------------ Retours de la session à 3 joueurs (13/11/2026)

## Navigation du bateau des joueurs (les ennemis gardent leurs réglages).
const RUDDER_RATE := 0.6              ## par seconde : la barre va du centre à fond en 1,6 s (avant : 1,6, soit 0,63 s)
const RUDDER_RETURN := 0.45           ## par seconde : lâchée, elle revient au centre en 2,2 s (avant : 0,63 s)
const TURN_INERTIA := 1.2             ## s : temps que met le bateau à prendre son virage et à le quitter (avant : 0)
const PLAYER_TURN_SCALE := 0.77       ## puissance de virage (x celle de data/ship_stats.json ; brigantin : 20 -> 15,5 °/s)
const ANCHOR_BRAKE := 1.2             ## freinage à l'ancre, x l'accélération (avant : 2,6 ; arrêt en 5 à 6 s au lieu de 2,8 s)
const ANCHOR_RESTART := 2.0           ## s après avoir levé l'ancre où le bateau repart mollement
const ANCHOR_RESTART_ACCEL := 0.4     ## part de l'accélération pendant ce temps
const SAILS_ABACK_BRAKE := 2.2        ## voiles hautes dans un calme ou une saute de vent : freinage x 2,2
const SAILS_FURLED_GLIDE := 0.5       ## voiles carguées : freinage divisé par deux (le bateau court sur son erre)
## Canons et crochet.
const GUN_ARC_DEG := 50.0             ## ° de visée de chaque côté de la perpendiculaire (avant : 180, soit 360° en tout)
const BALL_SPEED := 31.0              ## m/s à la bouche (avant : 28 ; portée d'environ 27 m -> 32 m)
## Combat à terre.
const GUN_KNOCK_SCALE := 0.3          ## recul d'un ennemi touché par balle (x le recul de l'arme ; avant : 1, il reculait de 1 à 2 m
                                      ## à chaque tir et perdait son élan : « figé », il suffisait de recharger et de tirer)
const AIM_SPRINT_SPREAD := 2.5        ## dispersion des armes à feu en courant (x la dispersion de l'arme)
const AIM_SPRINT_ADD := 0.05          ## rad ajoutés en courant (le fusil, sans dispersion, en prend aussi)
const AIM_JUMP_SPREAD := 3.5          ## dispersion en plein saut
const AIM_JUMP_ADD := 0.08            ## rad ajoutés en plein saut
const CARRY_TREASURE_SPEED := 0.85    ## vitesse de marche en portant un trésor (x la normale)
const CARRY_TREASURE_SPRINT := 0.88   ## et sa course : 1,53 x 0,88 = 1,35 x la marche
## Bateaux ennemis : équipages plus forts selon le rang (1 à 4), dégâts visibles à la place de la barre de vie.
## (canonniers en plus par rang : 0 / 1 / 2 / 3, dans ENEMY_RANKS ; avant : 0 / 1 / 1 / 2)
const ENEMY_LOAD_TIME := [0.9, 0.8, 0.7, 0.6]   ## s pour charger un canon, par rang (avant : 0,9 partout)
const ENEMY_AIM_PER_RANK := 0.1       ## dispersion des tirs en moins par rang au-dessus du premier
const ENEMY_DAMAGE_SINK := 0.7        ## m : un bateau à bout de coque s'enfonce d'autant
const ENEMY_DAMAGE_LIST := 0.14       ## rad : et gîte d'autant
## Abordage (13/11) : on monte sur un bateau ennemi par son échelle de coque, depuis l'eau, et on se bat sur son pont.
const BOARD_LADDER_REACH := 2.8       ## m : distance à l'échelle ennemie pour s'y accrocher à la nage
const CREW_HP := 3                    ## points de vie d'un squelette de l'équipage (un coup de sabre : 1 ; pistolet : 2)
const CREW_RESPAWN := 30.0            ## s avant qu'un squelette abattu revienne (timonier compris)
const CREW_STRIKE_REACH := 1.5        ## m : à cette distance d'un joueur monté à bord, un squelette frappe
const CREW_STRIKE_EVERY := 1.6        ## s entre deux coups reçus à bord
const CREW_STRIKE_DAMAGE := 1         ## cœurs
const ENEMY_ANCHOR_TIME := 40.0       ## s pendant lesquelles un ennemi dont on a jeté l'ancre reste sur place
const BOARD_ANCHOR_REACH := 1.9       ## m : distance au cabestan ennemi pour jeter son ancre
## Vigie (13/11).
const NEST_ZOOM := 0.30               ## grossissement de la caméra dans le nid de pie (avant : 0,45)
const NEST_JUMP_UP := 3.0             ## m/s : élan vers le haut en sautant du nid
const NEST_JUMP_OUT := 5.5            ## m/s : élan vers l'extérieur
## Sac et coffre du bateau (13/11) : le sac ne porte que 10 planches et 10 boulets ; le reste est au coffre du bateau, commun à
## tout l'équipage et tenu par l'hôte (le coffre à boulets, la caisse à planches et l'étagère de la cale ouvrent le même menu).
const BAG_MAX := 10                   ## planches, et boulets, qu'un pirate porte dans son sac (avant : 99)
const SHIP_CHEST_STEP := 1            ## ce qu'un clic prend ou range (Maj + clic : tout ce qui rentre)
## Interface épurée (13/11, retours de la session à 3) : à l'écran, seulement ce qui sert dans l'instant. `false` : l'ancien HUD.
const HUD_MINIMAL := true
const HUD_PROMPT_BELOW_CENTER := 96.0 ## pixels sous le centre de l'écran : l'indication de touche du poste visé
const SIREN_LEAVE_AFTER := 3.0        ## s après être sorti de l'eau avant que la sirène disparaisse
## Skins de bateau (proue, voiles, coque, pavillon) : masqués le temps d'être refaits (13/11, ils dégradaient le nouveau bateau).
## Les joueurs gardent leurs achats ; les ennemis gardent les couleurs de leur rang.  : tout revient.
const SHIP_SKINS_ENABLED := false
## Son (13/11).
const RAIN_VOL := 0.5                 ## volume de la pluie (x l'ancien : -50 %) ; son intensité varie en plus (averses, accalmies)
const WORK_PITCH_VAR := 1.08          ## écoper, réparer : hauteur tirée entre 1/1,08 et 1,08 à chaque coup
const WORK_VOL_VAR := 0.25            ## … et volume tiré entre 75 % et 100 %
## Refonte graphique, eau (13/11).
const SHORE_SWELL := 0.2              ## part de la houle qui reste au bord d'une île (1 = comme au large)
const SHELTER_WIDTH := 30.0           ## m : distance au bord de l'île sur laquelle la houle reprend toute sa hauteur
## Ville v3 (13/11, design/ville-v3/conception.md).
const TOWN_V3 := false                ## true : la nouvelle ville (maquette grise de data/town_plan.json) remplace le port ; essai : --town=v3
const LADDER_EXIT_REACH := 2.0        ## m : dans la ville v3, un nageur sort de l'eau à moins de cette distance d'une échelle (ou par la grève)
const LAMP_EVERY_MAIN := 13.0          ## m entre deux lanternes sur le quai et la Grand-Rue
const LAMP_EVERY := 21.0               ## … et sur les autres rues
const LAMP_ENERGY := 3.4               ## force d'une lanterne, la nuit
const LAMP_RANGE := 9.0                ## m : portée de sa lumière
const LAMP_CULL := 60.0                ## m : au-delà de cette distance du pirate, une lanterne n'éclaire plus (elle brille encore)
const LAMP_SHADOWS := 2                ## nombre de lanternes qui portent des ombres (les plus proches du pirate)
const LAMP_REFLECTION_LENGTH := 6.5    ## m : longueur du reflet d'une lanterne sur l'eau
const WINDOW_GLOW := 1.5               ## force des fenêtres allumées, la nuit
const TOWN_SHELTER := Vector3(5.0, -45.0, 85.0)   ## (x, z, rayon) : la houle tombe à SHORE_SWELL dans ce cercle autour de la ville v3 (bassin compris)
const TOWN_LABELS := false             ## les noms numérotés au-dessus des bâtiments de la ville v3 (repères de chantier)
## Bugs de la liste du 13/11.
const WATER_EXIT_STEP := 0.9          ## m : en sortant de l'eau sur un quai ou un ponton, le pirate est posé à cette distance du bord
const WARM_GLOW := Color(1.0, 0.80, 0.46)   ## teinte des fenêtres, vitrines et lanternes allumées (avant : blanc)
const WEAPON_SHIP_DAMAGE := 1.5        ## 1.7 : points de coque qu'un point de dégât d'arme enlève à un bateau ennemi (un boulet : 18)
const WEAPON_OWN_SHIP_WEAR := 0.12     ## 1.7 : usure de notre coque par point de dégât reçu du dehors ; une voie d'eau par unité d'usure
const ENEMY_REPAIR_NOTICE := 60.0      ## m : en deçà, « Ils réparent ! » s'affiche au-dessus du bateau ennemi
const MUSIC_COMBAT_GAIN := 1.25         ## 2.3 : la musique de combat joue plus fort que les autres (x leur volume)
const MUSIC_COMBAT_BOOST := 0.75        ## … et arrive encore plus fort (jusqu'à x 2 au total), puis redescend…
const MUSIC_COMBAT_BOOST_TIME := 14.0   ## … en ce temps (s)
const AGGRO_STING_VOL := 1.0            ## volume de l'alerte (cloche et tambour) quand un navire ennemi nous prend en chasse
const HUD_NOTICES := false              ## les messages au milieu de l'écran (« Boulet ! Voie d'eau… ») : éteints, à la demande de Jimmy
const HUD_KEY_HINT := true              ## la touche du poste visé, « [E] … » : petite, en bas de l'écran (false : rien du tout)
const HUD_PROMPT_FROM_BOTTOM := 46.0    ## pixels au-dessus du bas de l'écran
## Lampadaires (13/11) : un jaune paille, ni blanc ni orange. La nuit est étalonnée en bleu : la lumière est un peu plus jaune
## que ce qu'on veut voir à l'écran, pour qu'elle ne vire pas au rose sur les pavés.
const LAMP_LIGHT := Color(1.0, 0.80, 0.26)     ## couleur de la lumière jetée au sol et sur les murs
const LAMP_GLASS := Color(1.0, 0.86, 0.55)     ## couleur du verre de la lanterne
const LAMP_GLASS_ENERGY := 1.0                 ## force de son éclat (6 dans le modèle : il virait au blanc)
const NIGHT_WARM_KEEP := 0.85               ## part de la couleur d'origine gardée, la nuit, là où une lumière chaude éclaire (0 : tout est bleui)
## Longue-vue (13/11, 4.1).
const SPY_ELEV := 16.0                  ## ° : inclinaison de la vue, l'œil à la longue-vue (presque à hauteur d'homme)
const SPY_AHEAD := 85.0                 ## m : le regard porte à cette distance devant le pirate
const SPY_ZOOM := 0.9                   ## grossissement (la vue de mer ordinaire est vers 0,55)
const SPY_PAN := 0.9                    ## rad/s : vitesse de balayage avec Q/D
## Corde, silex (13/11, 4.2 à 4.4).
const ROPE_REACH := 1.8                 ## m : distance à laquelle on ligote ou délie un autre joueur (touche C)
const ROPE_LENGTH := 9.0                ## m : longueur de la corde qui relie au bateau (on est traîné au bout, derrière la poupe)
const BOUND_MAX_TIME := 180.0           ## s : sans silex et sans aide, les liens lâchent au bout de ce temps
const FLINT_CHEST_CHANCE := 0.35        ## chance de trouver un silex dans un coffre d'île
## Instruments de musique (13/11, 4.5).
const INSTRUMENT_VOL := 0.9             ## volume d'un instrument (son placé sur le pirate : il s'éteint avec la distance)
const NOTE_EVERY := 0.4                 ## s entre deux notes qui s'envolent
const NOTE_LIFE := 1.5                  ## s : durée de vie d'une note
const INSTRUMENT_SCALE := 1.5           ## taille de l'instrument tenu
const NOTE_SCALE := 1.6                 ## taille des notes qui s'envolent
## Vitres (13/11, 2.2).
const WINDOWS_SHOW_INSIDE := false      ## vitres transparentes des bâtiments où l'on entre. ÉTEINT : essayé le 13/11, le résultat est moins bon (la caméra regarde d'en haut : on ne voit pas l'intérieur, et la nuit les fenêtres perdent leur lumière chaude)
const WINDOW_ALPHA := 0.30              ## opacité de ces vitres (1 : opaques)
const PORT_SHELTER := Vector3(0.0, -46.0, 64.0)   ## (x, z, rayon) : la houle tombe à SHORE_SWELL autour de l'ancienne ville
const WINDOW_GLASS := Color(0.72, 0.84, 0.90)   ## teinte du verre de ces vitres
const WINDOW_INTERIORS := true          ## un intérieur peint derrière les vitres (étagères des boutiques, rideaux, silhouettes)
const WINDOW_DAY_LIGHT := 0.55          ## lumière de ces vitres en plein jour (1 la nuit)

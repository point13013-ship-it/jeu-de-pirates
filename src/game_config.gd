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
const CARRY_HANDS_HEIGHT := 0.82      ## m : hauteur de l'objet porté (dans les mains, devant le torse)
const CARRY_TREASURE_SCALE := 1.1     ## taille de la maquette d'un trésor porté (avant : 1,5 au-dessus de la tête)
const CARRY_TOWARD_CAMERA := 0.35     ## m : avancé vers la caméra, pour passer devant le sprite

## Sons placés dans le monde (Sfx3D).
const SFX_HEAR_RANGE := 22.0          ## m : au-delà, on n'entend plus
const SFX_UNIT_SIZE := 4.0            ## m : distance où le son est à plein volume
const SFX_DB := -4.0                  ## décalage général des bruitages (mixage)

## Actions longues (règle commune) : durées en secondes.
const ACTION_TIMES := {
	"anchor": 3.5,    # lever / jeter l'ancre (3 à 4 s)
	"repair": 2.5,    # boucher une voie d'eau avec une planche (2 à 3 s par trou)
	"bail": 1.5,      # un seau : remplir puis vider
	"hoist": 1.6,     # hisser un camarade hors de l'eau
	"revive": 4.0,    # relever un camarade à terre (lot 4)
}
const ACTION_MOVE_TOLERANCE := 0.12   ## de combien (unités du lieu) on peut glisser sans couper l'action (le pont tangue)
const BAIL_FILL_SHARE := 0.5          ## part de l'écopage passée à remplir le seau (le reste : le vider)
const HAMMER_EVERY := 0.42            ## s entre deux coups de marteau
const HOIST_REACH := 2.6              ## m : on peut attraper un camarade qui nage à cette distance du bord ou de l'échelle
const LADDER_STEP_EVERY := 0.28       ## s entre deux pas sur l'échelle

# ------------------------------------------------------------------ Lot 3 : bateau du joueur

## 3.6 Navigation du bateau des joueurs (les ennemis ne changent pas ici : lot 5).
const PLAYER_SHIP_SPEED_MULT := 1.1          ## +10 % de vitesse
const PLAYER_UPWIND_PENALTY_SCALE := 0.75    ## malus de mauvais vent (vent debout, voiles mal réglées) réduit de 25 %

## 3.7 Houle (SkyCycle.swell : 0 calme … 1 tempête).
const SWELL_FROM_RAIN := 0.35         ## la pluie seule donne cette houle ; l'orage, la houle maximale
const SWELL_FADE := 0.05              ## vitesse de variation de la houle (par seconde)
const SWELL_WAVE_MAX := 2.2           ## hauteur des vagues à houle maximale (x la mer calme)
const SWELL_STEER_PENALTY := 0.2      ## maniabilité perdue à houle maximale (20 %)
const CAM_SWAY := 0.22                ## m : balancement de la caméra à houle maximale
const CAM_HEAVE_FOLLOW := 0.35        ## part du soulèvement du pont que la caméra suit

# ------------------------------------------------------------------ Lot 8 (en avance) : interface

const NPC_NAME_RANGE := 9.0           ## m : le nom d'un habitant s'affiche à cette distance

# ------------------------------------------------------------------ Lot 6 : météo et jour/nuit

const DAY_SECS := 2100.0              ## 8.1 : s pour un jour complet (avant : 1 500 s ; +40 %)
const WEATHER_SECS := 420.0           ## s : une tranche de temps (avant : 360)
## 8.2 : chances de chaque temps par tranche (avant : clair 62 %, brume 16 %, pluie 14 %, orage 8 %) …
const WEATHER_ODDS := {"clear": 0.76, "mist": 0.10, "rain": 0.10, "storm": 0.04}
## … et part de la tranche pendant laquelle il dure (avant : toute la tranche).
const WEATHER_SHARE := {"mist": 0.6, "rain": 0.55, "storm": 0.7}
## 8.3 : périodes de houle plus forte hors tempête (une chance par période, la houle monte puis retombe).
const SWELL_PERIOD := 240.0
const SWELL_ODDS := 0.3
const SWELL_PERIOD_STRENGTH := 0.55
## Moments de la journée (part du jour, 0 = minuit, 0,5 = midi) : début de chaque moment, pour l'affichage.
const DAY_MOMENTS := [[0.0, "Nuit"], [0.22, "Aube"], [0.3, "Matin"], [0.45, "Midi"], [0.56, "Après-midi"], [0.72, "Soir"], [0.8, "Crépuscule"], [0.86, "Nuit"]]

# ------------------------------------------------------------------ Lot 5 : ennemis

const ENEMY_HP_MULT := 1.25           ## 6.1 : coques 25 % plus résistantes
const ENEMY_SPEED_MULT := 0.9         ## 6.4 : 10 % plus lents (en plus de l'écart d'origine, 0,82)
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
	{"weight": 14, "kind": "brigantin", "hp": 1.6, "crew": 1, "planks": 6, "skin": {"sail": "tempest", "hull": "navy", "flag": "white"},
		"loot": {"treasures": [4, 5], "rarity": 2.4, "planks": [5, 8], "balls": [5, 9], "gold": [200, 340]}},
	{"weight": 4, "kind": "galion", "hp": 2.2, "crew": 2, "planks": 10, "skin": {"sail": "purple", "hull": "royal", "flag": "gold"},
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
const RESPAWN_TIME := 10.0            ## s avant de réapparaître sur le bateau
const RESPAWN_INVULNERABLE := 3.0     ## s d'invulnérabilité à la réapparition
const REVIVE_REACH := 1.6             ## m : distance pour relever un camarade
const SIREN_AFTER := 20.0             ## s dans l'eau avant qu'une sirène vienne
const SIREN_DISTANCE := 3.0           ## m : elle apparaît à cette distance, et on la touche (E) à moins de 1,6 m
const SIREN_REACH := 1.6
const SHARKS_AFTER := 45.0            ## s : les requins rôdent
const SHARK_ATTACK_AFTER := 60.0      ## s : première morsure
const SHARK_BITE_EVERY := 6.0         ## s entre deux morsures
const SHARK_BITE_DAMAGE := 1          ## cœurs
const SHARK_SCARED := 8.0             ## s : un coup de sabre fait fuir le requin ce temps-là
const SHARK_COUNT := 2
const DROWN_AFTER := 90.0             ## s : noyade (mort directe, sans passer à terre)
const DROWN_WARNING := 15.0           ## s : l'alerte s'affiche dans les dernières secondes
const DOWNED_SQUASH := 0.45           ## un pirate à terre est tassé de 45 % (provisoire, faute d'image « au sol »)

## 3.3 Cale : plus grande et plus vivante.
const HOLD_FLOOR_HALF := 1.8          ## m : demi-largeur du fond plat (avant : 1,2)
const HOLD_WALL_H := 1.8              ## m : mur du fond (avant : 1,4)
const HOLD_LENGTH_MULT := 1.3         ## la cale est 30 % plus longue
const HOLD_END_STORAGE := 1.3         ## m : à chaque bout, une réserve (tonneaux, caisses, sacs) où l'on ne marche pas
const HOLD_LANTERN_EVERY := 3.2       ## m entre deux lanternes
const HOLD_FLICKER := 0.18            ## vacillement des flammes (part de l'intensité)

## 3.5 Toile des voiles : nombre de répétitions de la texture par unité du modèle (un lé = un quart de texture).
const SAIL_CANVAS_SCALE := 0.45
const SAIL_PANEL_DARK := 0.95         ## teinte des panneaux sombres (x la toile ; le modèle : 0,89)
const SAIL_PANEL_LIGHT := 1.02        ## teinte des panneaux clairs (le modèle : 1,04)

## 3.9 Roue du gouvernail.
const HELM_WHEEL_RADIUS := 0.5        ## unités du modèle (la taille de l'ancien disque)
const HELM_WHEEL_TURNS := 1.5         ## tours de roue d'une butée à l'autre
const HELM_CREAK_VOL := 0.9           ## volume du grincement à pleine vitesse de rotation

## 3.8 Son de coque : renfort par la houle et gerbes au hasard.
const HULL_SWELL_VOL := 0.25
const HULL_SPLASH_MIN := 1.2          ## s (à pleine vitesse, ces écarts sont raccourcis)
const HULL_SPLASH_MAX := 3.5

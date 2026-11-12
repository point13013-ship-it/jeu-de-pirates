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

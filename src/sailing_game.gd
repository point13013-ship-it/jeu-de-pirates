extends Control
## Banc d'essai jouable de la navigation façon Sea of Thieves : on marche librement sur le pont
## et dans la cabine, on prend la barre, on hisse les voiles, on jette l'ancre, on charge et tire
## les canons. Rendu : 3D basse résolution + filtre pixel art (palette du port).
##
## Touches : ZQSD / flèches = marcher (ou gouverner à la barre), E = agir, A/D de la barre = bâbord/tribord,
## R = action secondaire (affaler les voiles).
## Arguments de test (après « -- ») : --ship= --yaw= --player=x,y --walkto=x,y --sail=n --rudder=v
## --anchor=1 --helm=1 --fire=1 --shot=chemin --shot-after-secs= --quit-after-secs= --log=1

const PIXELS_PER_METER := 36.0
const VIEW_SIZE := Vector2i(960, 540)
const ELEVATION_DEG := 40.0
const SHOULDER_ELEV_DEG := 22.0       ## vue « épaule » (touche V) : la caméra descend, on regarde presque à l'horizontale
const SHOULDER_ZOOM := 1.6            ## … et se rapproche (multiplie le grossissement)
const SEA_Y := -1.45
const WALK_SPEED := 3.6
const SPRINT_MULT := 1.7               ## facteur de vitesse de marche en maintenant Maj
const INTERACT_RANGE := 1.5
const STATS_PATH := "res://data/ship_stats.json"

enum Mode { WALK, HELM, SAILS, CANNON }   ## ce que fait le pirate à son poste : marche, barre, vergues (au mât), dans un canon
enum Loc { SHIP, LAND, CLIMB, NEST, HOLD, SWIM, FLIGHT, RAFT }   ## où est le pirate : sur le pont, à terre, sur une échelle, dans le nid de pie, dans la cale, à la nage, en vol (canon ou corde), sur son radeau
const SPRITE_DEPTH_BIAS := 0.7         ## m : de combien on avance un pirate à terre vers la caméra (voir _snap_sprite)
const HOLD_Y := 40.0                  ## hauteur (m) où la cale est posée dans la scène, loin au-dessus de tout
const HIT_BALL := 0                    ## types de choc : boulet, récif, quai ou mur
const HIT_ROCK := 1
const HIT_WALL := 2
const JUMP_SPEED := 7.0                ## m/s : sommet à 1,6 m ; assez pour enjamber une caisse, passer le bastingage ou franchir un vide
const AIR_SPEED := 1.3                 ## multiplicateur de la vitesse de marche en plein saut (on franchit ~4 m)
const GRAVITY := 15.0                  ## m/s²
const SWIM_SPEED := 2.3                ## m/s
const SWIM_DEPTH := 0.5                ## m : de combien le pirate est enfoncé dans l'eau (on ne voit que le haut du corps)
const BOARD_REACH := 2.4               ## m : à moins de cette distance de la coque, un nageur peut remonter à bord
const CANNON_SPEED := 19.0             ## m/s : vitesse horizontale du pirate tiré du canon
const CANNON_LIFT := 9.0               ## m/s : vitesse verticale au départ du canon
const ZOOM_SEA := 0.6                  ## grossissement de la caméra en mer (1 = proche, plus petit = on voit plus loin)
const ZOOM_LAND := 0.85
const ZOOM_MIN := 0.4
const ZOOM_MAX := 1.15
const CLIMB_SPEED := 2.6               ## m/s le long du mât
const NEST_RADIUS := Vector2(0.38, 0.54)  ## unités du modèle : distance mini / maxi au mât dans le nid
const LADDER_REACH := 3.2              ## m : distance maxi entre l'échelle de coque et le quai

var _args: Dictionary = {}
var _ship: ShipModel
var _sim := ShipSim.new()
var _world: Node3D
var _cam: Camera3D
var _shoulder := false            ## vue « épaule » (touche V) : caméra plus basse et plus proche
var _cam_yaw := 0.0               ## rad : cap de la caméra autour du pirate (molette enfoncée + souris ; clic simple sur la molette : remet droit)
var _cam_drag := false            ## la molette est enfoncée
var _cam_drag_moved := 0.0        ## px parcourus pendant l'appui (un appui sans mouvement remet la caméra droite)
var _elev_user := ELEVATION_DEG  ## inclinaison choisie par le joueur (molette enfoncée, haut/bas)
var _mid_clicks := 0             ## clics rapides sur la molette (trois : vue de base)
var _mid_click_t := -10.0
var _elev_deg := ELEVATION_DEG   ## inclinaison actuelle de la caméra (lissée entre la vue normale et la vue épaule)
var _sea: MeshInstance3D
var _sprite: PirateSprite
var _my_look: Dictionary = {}       ## mon apparence (éditeur de pirate)
var _remote_looks: Dictionary = {}  ## id du pair -> apparence reçue
var _remote_held: Dictionary = {}   ## id du pair -> 'arme|skin' qu'il tient
var _remote_names: Dictionary = {}  ## id du pair -> son pseudo
var _name_tag: Label3D              ## mon pseudo, au-dessus de mon pirate
var _held_sent := ""                ## ce que les autres savent de mon arme en main
var _prev_ppos := Vector2.INF
var _editor: CharacterEditor
var _loc := Loc.SHIP
var _land := Land.new()
var _lpos := Vector2.ZERO           ## position à terre (monde, x/z)
var _pz := 0.0                      ## hauteur au-dessus du sol ou du pont (saut, échelle, nid)
var _vz := 0.0
var _air_origin: Dictionary = {}    ## d'où le dernier saut est parti : {loc, ppos, lpos, lh} (retour si l'on retombe dans un mur)
var _jump_wind := 0.0              ## s restantes d'accroupissement avant le saut
var _land_t := 0.0                  ## s restantes de réception après un saut
var _climb: Dictionary = {}         ## échelle en cours : {kind: mast|hull, t, ...}
var _notice := ""
var _notice_t := 0.0
var _prev_loc := Loc.SHIP
var _prev_lpos := Vector2.ZERO
var _prev_land_climb := false
var _ball_icon: MeshInstance3D
var _ppos := Vector2.ZERO
var _mode := Mode.WALK
var _carrying := false
var _interactables: Array = []
var _cannon_loaded: Array = []
var _cannon_icons: Array = []
var _cannon_nodes: Array = []       ## les canons 3D (ShipCannons) : {root, barrel}
var _music_heat := 0.0                ## 0…1 : coups reçus récemment (fait monter la musique de combat), retombe tout seul
var _cannon_in := -1               ## le canon dans lequel je suis glissé (je serai tiré dedans), ou -1
var _cannon_aim := 0.0              ## rad : orientation du tir autour de la sortie du canon
var _pface := Vector2(1, 0)         ## direction où je regarde sur le pont (repère du bateau)
var _target: Dictionary = {}        ## l'objet du pont que E actionnerait (devant moi, à portée), ou {}
var _post_rings: Array = []         ## un anneau doré par poste du pont (voir _update_post_rings)
var _ring_mat: StandardMaterial3D
var _ring_mat_hot: StandardMaterial3D
var _target_marker: Node3D         ## la flèche qui le désigne
var _zoom := ZOOM_SEA               ## grossissement actuel de la caméra (lissé)
var _zoom_user := 1.0               ## réglage du joueur (molette) : multiplie le grossissement du lieu
var _stuck_t := 0.0                 ## s pendant lesquelles le bateau est bloqué voiles hissées
var _swim_t := 0.0
var _swim_ring_t := 0.0
var _flight: Dictionary = {}        ## le vol d'un pirate tiré du canon : {vel: Vector2 (horizontale), vz, y (altitude absolue)}
var _inventory: InventoryPanel      ## le sac du pirate (Tab)
var _weapon_label: Label            ## l'arme en main et sa munition, en bas à droite
var _carry_item := ""               ## le trésor que je porte (identifiant de data/treasures.json) quand _carry_kind == "treasure"
var _treasure_icon: Node3D          ## sa maquette au-dessus de ma tête
var _stash: Array = []              ## les trésors du coffre du capitaine (cabine) : identifiants ; l'hôte fait autorité
var _stash_glow: MeshInstance3D     ## l'éclat d'or au-dessus du coffre quand il contient quelque chose
var _loot := WorldLoot.new()        ## butin posé dans le monde : trésors flottants, boulets, planches, bourses
var _fleet := EnemyFleet.new()      ## les bateaux de pirates ennemis (IA chez l'hôte)
var _loot_cd := 0.0
var _gen_t := 0.0                  ## s avant de chercher de nouvelles îles à générer autour du bateau
var _rng := RandomNumberGenerator.new()
var _unstick_armed := 0.0           ## s pendant lesquelles un deuxième appui sur T confirme le déblocage
var _test_move := Vector2.ZERO      ## essais : direction de marche imposée (--move=...)
var _trim_sent := 0                 ## dernière commande de vergues envoyée (-100..100)
var _sail_cd := 0.0                 ## s avant de pouvoir hisser/affaler de nouveau au mât
var _sail_station := Vector2.ZERO   ## le mât où je suis debout
var _aim_line: MeshInstance3D       ## la trajectoire prévue, quand je suis dans un canon
var _sail_hud: SailHud              ## le cadran du vent et des vergues
var _projectiles: Array = []
var _cam_focus := Vector3.ZERO
var _hud: Label
var _hud_root: Control               ## porte tout l'affichage de jeu ; sa taille d'affichage suit DisplaySettings.hud_scale
var _hand_wid := ""                  ## arme secondaire montrée dans la main après un clic droit (vide : l'arme principale)
var _hand_t := 0.0                   ## s : combien de temps elle y reste
var _hud_scale_applied := 0.0
var _hud_size_applied := Vector2.ZERO
var _prompt: Label
var _time := 0.0
var _walkto := Vector2.INF
var _log_timer := 0.0
var _container: SubViewportContainer
var _viewport: SubViewport
var _post_vp: SubViewport
var _post_rect: TextureRect
var _post_mat: ShaderMaterial
var _palette_version := -1
var _factor := 2
var _water_mat: ShaderMaterial
var _waves: Array[Vector4] = []
var _sea_cfg: Dictionary = {}
var _blob: MeshInstance3D
var _sun: DirectionalLight3D
var _frames_left := 0
var _world_fixed: Node3D
var _world_origin := Vector3.ZERO  ## position monde (calée) du bateau : le monde défile sous lui
var _sea_t := 0.0
var _cam_offset := Vector3.ZERO
var _net: SailingNet
var _remotes: Dictionary = {}       ## id du pair -> {sprite, blob, ball, pos, target}
var _helm_owner := 0                ## id du joueur à la barre (0 = personne)
var _menu: Node
var _main_menu: MainMenu
var _status_label: Label
var _top_right: VBoxContainer           ## coin haut droit : or puis état du réseau, empilés sans se chevaucher
var _invite: InvitePanel            ## le cadre « Inviter un ami » de l'hôte (adresse IP, code)
var _pause: PauseMenu               ## le menu de la touche Échap (retour au menu principal)
var _quest_panel: QuestPanel        ## le journal de quêtes (J)
static var _force_menu := false     ## après « Retour au menu principal » : on recharge la scène et on affiche le menu
var _time_offset := 0.0             ## client : décalage pour suivre le temps de la houle de l'hôte
var _net_target: Dictionary = {}    ## client : dernier état du bateau reçu de l'hôte
var _rudder_sent := 0.0
var _port: Node3D
var _port_meta: Dictionary = {}
var _hull := HullDamage.new()        ## voies d'eau et eau dans la cale (l'hôte décide, les clients copient)
var _rocks := SeaRocks.new()
var _hold_layout := HoldLayout.new()
var _hold: HoldRoom
var _hold_items: Array = []
var _hpos := Vector2.ZERO            ## position dans la cale (x, z)
var _prev_hpos := Vector2.ZERO
var _prev_hold := false
var _carry_kind := ""                ## ce que je porte : "" (rien), "ball" (boulet) ou "plank" (planche)
var _plank_icon: MeshInstance3D
var _hull_marks: Array = []          ## par voie d'eau : repère visible sur la coque, vu de dehors
var _env: Environment
var _env_saved: Dictionary = {}
var _fade: ColorRect
var _fade_busy := false
var _gauge_back: ColorRect
var _gauge_fill: ColorRect
var _gauge_label: Label
var _impact_cd := 0.0
var _bail_cd := 0.0
var _shake_t := 0.0
var _spawn_pos := Vector2.ZERO       ## où le bateau est remorqué quand il coule
var _spawn_yaw := 0.0
var _shown_leaks := -1
var _shown_patched := -1
var _lh := 0.0                       ## hauteur du sol sous mes pieds à terre (terrasse, escalier, étage)
var _profile := Profile.new()        ## mon or et mes quêtes
var _quests: QuestLog
var _dialog: DialogueBox
var _dialog_ctx: Dictionary = {}     ## le dialogue en cours : {npc, offer, turn_in}
var _ship_skin: Dictionary = {}      ## couleurs du bateau (ShipSkin)
static var _restart: Dictionary = {} ## changement de bateau en solo : {ship, profile}, lu au rechargement de la scène
var _shop_menu: ShopMenu            ## le menu d'achat ouvert chez un boutiquier
var _shop_defs: Dictionary = {}      ## data/shops.json : id de PNJ -> boutique
var _npcs: Array = []                ## TownNpc de la ville (boutiquiers et promeneurs)
var _npc_range := 2.3
var _interior_nodes: Array = []      ## par intérieur : {root, building}
var _interior_active := -1           ## indice de l'intérieur où je suis, ou -1
var _buildings: Array = []           ## les bâtiments du port : {mesh, normal, ghost, alpha, ghosted}
var _ghost_shader_cache: Shader
var _ghosting := false               ## un bâtiment est rendu transparent devant moi
var _gold_label: Label
var _quest_label: Label
var _islands := IslandWorld.new()    ## les îles : terre, ennemis, coffres (l'hôte fait vivre les ennemis)
var _atmo: Atmosphere                ## ciel, météo, sons, vie des îles
var _atmo_prev := Vector2(1.0e6, 1.0e6)   ## position de l'image précédente (pour compter les pas)
var _atmo_prev_kind := ""
var _castaways_made: Dictionary = {}   ## graines des naufragés dont le PNJ existe déjà
var _chart: SeaChart                 ## la carte des mers, sur la table de la cabine
var _island_hud: IslandHud           ## cœurs, flèche vers l'île choisie, voile rouge des coups reçus
var _rep_hud: ReputationHud          ## rang de réputation et animation de progression
var _destination := -1               ## l'île choisie sur la carte, ou -1
var _quest_dest := -1                ## l'île vers laquelle une quête d'expédition m'envoie, ou -1
var _hp := 6                         ## mes points de vie (chacun les siens)
var _hp_max := 6
var _inv_t := 0.0                    ## s d'invulnérabilité restantes après un coup reçu
var _atk_cd := 0.0                   ## s avant de pouvoir frapper de nouveau
var _spell_cd: Array[float] = [0.0, 0.0, 0.0, 0.0]   ## s avant de pouvoir relancer chacun des 4 sorts de ma baie
var _spell_cd_max: Array[float] = [1.0, 1.0, 1.0, 1.0]
var _face := Vector2(0, 1)           ## direction où je regarde à terre (monde x/z)
var _popups: Array = []              ## textes qui flottent (or gagné) : {node, t}
var _heal_t := 0.0
# ------------------------------------------------------------------ lot 2
var _sfx: Sfx3D                      ## bruitages placés dans la scène (voir Sfx3D)
var _ground_vel := Vector2.ZERO      ## m/s (monde x/z) : ma vitesse à pied, l'élan que prend un saut
var _air_vel := Vector2.ZERO         ## m/s (monde x/z) : ma vitesse horizontale en l'air
var _act: TimedAction = null         ## l'action longue en cours (ancre, réparation, écopage, hisser un allié…), ou null
var _act_gauge: ActionGauge          ## sa jauge circulaire au centre de l'écran
var _remote_acts: Dictionary = {}    ## id du pair -> {kind, t, dur} : l'action longue qu'il fait (pour l'animer chez moi)
var _carry_nodes: Dictionary = {}    ## id du pair -> Node3D : ce qu'il porte, entre ses mains
var _remote_carry: Dictionary = {}   ## id du pair -> code de ce qu'il porte ("", "ball", "plank", "t:<id>")
var _act_loc := -1                   ## où l'action en cours a commencé (Loc) : changer de lieu l'interrompt
var _act_hurt := false               ## j'ai pris un coup pendant l'action
var _act_prev_t := 0.0
var _squash: Dictionary = {}         ## id d'instance d'un sprite -> {t, kind} : écrasement d'appel ou de réception d'un saut
var _ladder_step_t := 0.0
var _act_prop: Node3D                ## l'accessoire en main pendant l'action (seau, marteau…)
# ------------------------------------------------------------------ lot 3
var _wave_amp := 1.0                 ## multiplicateur de la houle (force de la mer)
var _wave_amp_sent := -1.0           ## dernière valeur envoyée au shader de l'eau
var _cam_sway := Vector3.ZERO        ## balancement de la caméra par mer formée
var _prev_rudder := 0.0
var _helm_creak := 0.0               ## 0..1 : vitesse de rotation de la roue (grincement)
# ------------------------------------------------------------------ lot 4
var _downed_t := -1.0                ## s avant de mourir, à terre (-1 : debout)
var _dead_t := -1.0                  ## s avant de réapparaître (-1 : vivant)
var _dead_why := ""
var _revivers: Dictionary = {}       ## id des camarades en train de me relever -> true (mon compte à rebours est en pause)
var _water_t := 0.0                  ## s passées dans l'eau d'affilée
var _water_stage := 0                ## 0 rien, 1 sirène, 2 requins qui rôdent, 3 requins qui mordent
var _siren: Node3D
var _siren_pos := Vector2.ZERO
var _sharks: Array = []              ## {node, a (angle autour de moi), scared (s)}
var _shark_bite_t := 0.0
var _remote_downed: Dictionary = {}  ## id -> {t (s restantes), reviving}
var _remote_dead: Dictionary = {}    ## id -> true
var _remote_water: Dictionary = {}   ## id -> {stage, siren, siren_pos, sharks, t}
var _center_label: Label             ## grand texte au centre (à terre, mort, noyade)
# ------------------------------------------------------------------ lot 8
var _roster: Dictionary = {}         ## pseudos de l'équipage de cette partie (hôte) : présents et partis
var _pending: Dictionary = {}        ## pseudo -> or gardé pour un absent (hôte), versé à son retour


const SEA_PATH := "res://data/sea.json"
const SEA_MESH_SIZE := 110.0      ## m : la surface suit la caméra (assez large pour le plus fort dézoom)
const SEA_MESH_STEP := 0.25       ## m entre deux sommets de la surface (le maillage glisse par pas de 1 m : multiple entier)


func _ready() -> void:
	_args = _parse_args()
	# Synchronisation verticale : une image par rafraîchissement de l'écran. Sans elle, le jeu tournait
	# à ~1 450 images/s et l'écran affichait des morceaux de plusieurs images à la fois (déchirures
	# horizontales qui font « vibrer » tout ce qui défile).
	if not _args.has("no-vsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		# certains pilotes (réglage NVIDIA « synchronisation verticale : désactivée ») ignorent la demande :
		# on limite alors nous-mêmes à la fréquence de l'écran
		var hz := DisplayServer.screen_get_refresh_rate()
		Engine.max_fps = int(roundf(hz)) if hz > 0.0 else 60
	if _args.has("log"):
		print("[affichage] pilote=%s vsync=%d écran=%.0f Hz" % [RenderingServer.get_current_rendering_driver_name(), DisplayServer.window_get_vsync_mode(), DisplayServer.screen_get_refresh_rate()])
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# ce contrôle couvre tout l'écran : par défaut il « mange » les clics et _unhandled_input ne les voit jamais
	# (plus d'attaque, plus de rotation à la molette) ; il les laisse donc passer
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ShipSim.view_sin = sin(deg_to_rad(ELEVATION_DEG))   # le bateau avance à la même vitesse à l'écran dans toutes les directions
	_build_view()
	_build_hud()
	_net = SailingNet.new()
	_net.name = "Net"
	_net.game = self
	add_child(_net)
	_net.status.connect(_set_status)
	_net.welcomed.connect(_setup_ship)
	_net.invite_changed.connect(_refresh_invite)
	if _args.has("back-after-secs"):   # essai : retour au menu principal au bout de N secondes
		get_tree().create_timer(float(_args["back-after-secs"])).timeout.connect(func() -> void:
			if _ship != null:
				_back_to_menu())
	if _args.has("pause"):   # essai : ouvre le menu Échap au bout d'une seconde et demie (captures d'écran)
		get_tree().create_timer(1.5).timeout.connect(_test_open_pause)
	var ship_name := str(_args.get("ship", "brigantin"))
	if not _restart.is_empty():   # on revient d'un changement de bateau au chantier naval (solo)
		_profile = _restart["profile"]
		var next_ship := str(_restart["ship"])
		_restart = {}
		_setup_ship(next_ship)
	elif _args.has("host") and not _force_menu:
		_start_host(ship_name)
	elif _args.has("join") and not _force_menu:
		_start_join(str(_args["join"]))
	elif (_args.has("ship") or _args.has("solo")) and not _force_menu:
		_setup_ship(ship_name)
	else:
		_force_menu = false   # (après « Retour au menu principal », on ignore les arguments de lancement)
		_build_menu()
		if _args.has("editor"):
			_open_editor()
		if _args.has("shot"):   # test : capture d'écran du menu (ou de l'éditeur), puis on quitte
			get_tree().create_timer(float(_args.get("shot-after-secs", "3"))).timeout.connect(func() -> void:
				get_viewport().get_texture().get_image().save_png(str(_args["shot"]))
				get_tree().quit())


## Charge le bateau et place le joueur : en solo, à l'hébergement, ou à l'accueil de l'hôte.
func _setup_ship(ship_name: String) -> void:
	if _ship != null:
		return
	if _menu != null:
		_menu.queue_free()
		_menu = null
		_main_menu = null
	_ship = ShipModel.new()
	if not _ship.load_ship(ship_name):
		push_error("Bateau introuvable : %s" % ship_name)
		_ship = null
		return
	_world.add_child(_ship)
	if _args.has("skin"):   # essai : --skin=sail:red,hull:navy,flag:gold
		for item in str(_args["skin"]).split(","):
			var kv := item.split(":")
			if kv.size() == 2:
				_profile.ship_skin[kv[0]] = kv[1]
	if not _is_client():
		_profile.ship = ship_name   # c'est mon bateau (le chantier naval le montre comme tel)
		if not _profile.ships.has(ship_name):
			_profile.ships.append(ship_name)   # tous les bateaux sont proposés dans le menu : celui qu'on prend est à soi
		_profile.save()
	if not _is_client():   # le bateau porte les couleurs de son hôte (ou les miennes en solo) ; un client reçoit les siennes
		_ship_skin = ShipSkin.sanitize(_profile.ship_skin)
	ShipSkin.apply(_ship, _ship_skin)
	_sim.configure(_load_stats(ship_name))
	_sim.max_speed *= GameConfig.PLAYER_SHIP_SPEED_MULT        # lot 3 (3.6) : +10 %
	_sim.penalty_scale = GameConfig.PLAYER_UPWIND_PENALTY_SCALE   # lot 3 (3.6) : malus de mauvais vent -25 %
	_sim.yaw = deg_to_rad(float(_args.get("yaw", "0")))
	if not _args.has("no-port"):
		_build_port()
	_build_islands()
	_loot.setup(_world_fixed)
	_loot.sea_y = SEA_Y
	_loot.wave = _wave_height
	_loot.over_water = _land.is_over_water
	_loot.ground = _islands.ground_h
	_rng.randomize()
	_fleet.setup(_world_fixed)
	_fleet.wave_cb = _wave_height
	_fleet.blocker_cb = _enemy_would_hit_player
	_fleet.water_free_cb = _water_free
	_fleet.fire_cb = _on_enemy_fire
	_fleet.loot_cb = _on_enemy_loot
	_fleet.sunk_cb = _on_enemy_sunk
	_fleet.spawn_enabled = not _args.has("no-enemies")
	_build_blob()
	_build_player()
	_build_interactables()
	_setup_hull()
	_apply_test_args()
	_float_ship()
	var rel0 := _player_world() - _ship.position
	_cam_offset = Vector3(rel0.x, 0.0, rel0.z)


func _start_host(ship_name: String) -> void:
	var err := _net.host(ship_name, not _args.has("no-upnp"), _args.has("local-only"))
	if err != OK:
		_set_status("Impossible d'héberger (erreur %d) : le port %d est peut-être déjà utilisé (une autre partie est-elle ouverte ?)" % [err, SailingNet.PORT])
		return
	_setup_ship(ship_name)
	_invite.visible = true   # l'hôte voit tout de suite comment ses amis peuvent le rejoindre
	_refresh_invite()


func _start_join(address: String) -> void:
	var err := _net.join(address)
	if err != OK:
		_set_status("Impossible de rejoindre %s (erreur %d)" % [address, err])


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
		_status_label.visible = text != ""
	if _main_menu != null:   # le menu cache le reste : c'est là que le joueur doit lire « Connexion à… » ou l'erreur
		_main_menu.set_message(text)
	print("[réseau] ", text)


func _test_open_pause() -> void:
	if _ship != null:
		_toggle_pause()


func _refresh_invite() -> void:
	if _invite != null and _net != null and _net.is_host:
		_invite.show_info(_net.invite_info())


## « Retour au menu principal » : on coupe la partie en ligne (la box referme le port) et on recharge la scène sur le menu.
func _back_to_menu() -> void:
	_pause.close()
	_profile.save()
	_net.leave()
	_force_menu = true
	_restart = {}
	get_tree().reload_current_scene.call_deferred()


func _toggle_compass() -> void:
	_sprite.compass_enabled = not _sprite.compass_enabled
	_pause.refresh_compass(_sprite.compass_enabled)
	_say("Boussole sortie (B pour la ranger)" if _sprite.compass_enabled else "Boussole rangée (B pour la ressortir)", 2.5)


func _toggle_invite() -> void:
	if _net == null or not _net.is_host:
		_say("L'invitation, c'est pour l'hôte : héberge une partie depuis le menu.", 3.5)
		return
	_invite.visible = not _invite.visible
	_pause.close()


func _toggle_pause() -> void:
	if _pause.is_open():
		_pause.close()
	else:
		_pause.open(_net != null and _net.is_host, _sprite.compass_enabled, _net != null and _net.active)


## Menu de départ : le vrai menu (src/ui/main_menu.gd), posé sur la mer. Au tout premier lancement, on commence
## par créer son pirate.
func _build_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_menu = layer
	_main_menu = MainMenu.new(_local_look())
	layer.add_child(_main_menu)
	_main_menu.set_ships(MainMenu.ship_ids(), _profile.ship)   # tous les bateaux sont proposés d'emblée
	_main_menu.play_solo.connect(func(ship_name: String) -> void: _setup_ship(ship_name))
	_main_menu.host_game.connect(func(ship_name: String) -> void: _start_host(ship_name))
	_main_menu.join_game.connect(func(code: String) -> void: _start_join(code))
	_main_menu.edit_pirate.connect(_open_editor)
	_main_menu.quit_game.connect(func() -> void: get_tree().quit())
	if not FileAccess.file_exists(PirateLook.SAVE_PATH) and not _args.has("editor"):
		_open_editor.call_deferred()


## Ouvre l'éditeur d'apparence par-dessus le menu ; la nouvelle apparence est sauvegardée.
func _open_editor() -> void:
	if _editor != null:
		return
	_editor = CharacterEditor.new(_local_look())
	_menu.hide()
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	layer.add_child(_editor)
	_editor.closed.connect(func(result: Dictionary) -> void:
		if not result.is_empty():
			_my_look = result
			if _main_menu != null:
				_main_menu.set_look(result)
		layer.queue_free()
		_editor = null
		_menu.show())


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else true
	return out


func _load_stats(ship_name: String) -> Dictionary:
	var f := FileAccess.open(STATS_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary and (parsed as Dictionary).has(ship_name):
		return (parsed as Dictionary)[ship_name]
	return {}


# ------------------------------------------------------------------ construction de la vue


## Choisit un agrandissement ENTIER proche de « 540 lignes de pixels à l'écran », puis donne au
## rendu exactement la taille de la fenêtre divisée par ce facteur : l'image remplit toute la
## fenêtre, sans bandes noires, et chaque pixel du jeu fait le même nombre de pixels d'écran.
func _layout_view() -> void:
	if _viewport == null:
		return
	var win := size
	var factor := maxi(1, roundi(win.y / float(VIEW_SIZE.y * _hd())))
	# une marge d'un pixel de jeu de chaque côté : l'image peut être décalée d'une fraction de
	# pixel (caméra au sous-pixel, voir _update_camera) sans laisser de bord vide
	var view := Vector2i(ceili(win.x / factor), ceili(win.y / factor)) + Vector2i(2, 2)
	_factor = factor
	if _post_mat != null:   # rendu fin : vraies couleurs (la palette fixe salirait les teintes du ciel) ; rendu gros pixels : palette
		_post_mat.set_shader_parameter("use_palette", _hd() < 2 and not _args.has("no-palette"))
	_viewport.size = view
	_post_vp.size = view
	_post_rect.size = Vector2(view)
	_container.size = Vector2(view)
	_container.scale = Vector2(factor, factor)
	_container.position = Vector2(-factor, -factor)
	if _cam != null:
		_cam.size = float(view.y) / _ppm()


## Finesse du rendu : 1 = pixels du jeu de 540 lignes, 2 = deux fois plus fins (net à l'écran 1080p).
## Par défaut : fin dès que la fenêtre fait au moins 900 lignes (sinon l'image deviendrait minuscule).
func _hd() -> int:
	if _args.has("hd"):
		return maxi(1, int(str(_args["hd"])))
	return 2 if size.y >= 900.0 else 1


## Pixels de jeu par mètre à l'écran : la caméra s'éloigne (zoom < 1) pour voir plus de mer.
func _ppm() -> float:
	return PIXELS_PER_METER * _hd() * _zoom


## Le grossissement voulu selon où l'on est : plus loin en mer, un peu plus près à terre, très loin dans le nid de pie.
func _zoom_goal() -> float:
	var base := ZOOM_SEA
	match _loc:
		Loc.LAND:
			base = ZOOM_LAND
		Loc.HOLD:
			base = 1.0
		Loc.NEST:
			base = 0.45
		Loc.FLIGHT:
			base = 0.62
	if _loc == Loc.SHIP and _mode == Mode.HELM:
		base = 0.52   # à la barre : on veut voir devant
	var goal := clampf(base * _zoom_user, ZOOM_MIN, ZOOM_MAX)
	return goal * SHOULDER_ZOOM if _shoulder_active() else goal


## La vue épaule ne joue que sur le pont, à terre, à la nage ou sur le radeau : la cale, le mât et les vols ont leur cadrage.
func _shoulder_active() -> bool:
	return _shoulder and (_loc == Loc.SHIP or _loc == Loc.LAND or _loc == Loc.SWIM or _loc == Loc.RAFT)


## Lisse le zoom vers son but ; la taille de la caméra suit (le calage sur la grille de pixels suit aussi : voir _ppm).
func _update_zoom(delta: float) -> void:
	if _args.has("zoom"):
		_zoom = float(_args["zoom"])
	else:
		_zoom = lerpf(_zoom, _zoom_goal(), 1.0 - exp(-delta * 4.0))
	if _cam != null and _viewport != null:
		_cam.size = float(_viewport.size.y) / _ppm()


## Chaîne d'image : la 3D est rendue dans _viewport (taille du jeu, ex. 640x360) ; le filtre pixel
## art (palette + contours) est appliqué dans _post_vp, À LA MÊME TAILLE ; puis _container agrandit
## le résultat par un facteur ENTIER (x2, x3...). Le filtre ne travaille donc que sur les pixels du
## jeu, pas sur ceux de l'écran : 9 fois moins de calcul en 1080p.
func _build_view() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# suréchantillonnage possible (--ss=2) : bords plus doux, mais mesuré plus scintillant en mouvement
	# (les couleurs intermédiaires des bords basculent d'un ton de palette à l'autre) : désactivé par défaut
	_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	_viewport.scaling_3d_scale = float(_args.get("ss", "1.0"))
	add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)

	_container = SubViewportContainer.new()
	_container.stretch = false
	_container.size = Vector2(VIEW_SIZE)
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_container)
	_post_vp = SubViewport.new()
	_post_vp.size = VIEW_SIZE
	_post_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_container.add_child(_post_vp)
	_post_rect = TextureRect.new()
	_post_rect.texture = _viewport.get_texture()
	_post_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_post_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_post_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_post_rect.size = Vector2(VIEW_SIZE)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/pixel_look.gdshader")
	_post_mat = mat
	_post_rect.material = mat
	if _args.has("no-palette"):
		mat.set_shader_parameter("use_palette", false)
	_post_vp.add_child(_post_rect)
	resized.connect(_layout_view)
	_layout_view.call_deferred()

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.10, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var day := str(_args.get("light", "jour")) == "jour"
	env.ambient_light_color = Color(0.52, 0.60, 0.80) if day else Color(0.42, 0.40, 0.68)   # ombres froides, soleil chaud : le contraste fait le volume
	env.ambient_light_energy = 0.88 if day else 1.25
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env = env
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_world.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -40, 0) if day else Vector3(-48, -40, 0)   # soleil plus bas : ombres plus longues
	sun.light_color = Color(1.0, 0.90, 0.72) if day else Color(1.0, 0.72, 0.52)
	sun.light_energy = 1.9 if day else 1.7
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.62
	sun.shadow_blur = 1.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 70.0
	_world.add_child(sun)
	_sun = sun

	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = float(VIEW_SIZE.y) / PIXELS_PER_METER
	_cam.near = 0.1
	_cam.far = 250.0
	_cam.rotation_degrees = Vector3(-ELEVATION_DEG, 0, 0)
	_world.add_child(_cam)

	# surface de la mer : un maillage fin (un sommet tous les 25 cm) que la houle soulève
	_sea = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(SEA_MESH_SIZE, SEA_MESH_SIZE)
	var segments := int(SEA_MESH_SIZE / SEA_MESH_STEP) - 1
	plane.subdivide_width = segments
	plane.subdivide_depth = segments
	_sea.mesh = plane
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://shaders/water.gdshader")
	_sea.material_override = _water_mat
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sea.extra_cull_margin = 4.0
	_world_fixed = Node3D.new()
	_world.add_child(_world_fixed)
	_world_fixed.add_child(_sea)
	# bruitages placés dans la scène (lot 2), entendus depuis le pirate du joueur
	_viewport.audio_listener_enable_3d = true
	_sfx = Sfx3D.new()
	_sfx.name = "Sfx3D"
	_world.add_child(_sfx)
	_load_sea()
	if _args.has("debug-water"):
		_water_mat.set_shader_parameter("debug_view", int(str(_args["debug-water"])) if str(_args["debug-water"]).is_valid_int() else 1)
	if _args.has("shadow-blur"):
		_sun.shadow_blur = float(_args["shadow-blur"])
	if _args.has("noshadow"):
		_sun.shadow_enabled = false
	if _args.has("nomsaa"):
		_viewport.msaa_3d = Viewport.MSAA_DISABLED


## Lit la houle (data/sea.json) : les mêmes vagues servent à l'eau et à la flottaison du bateau.
func _load_sea() -> void:
	var f := FileAccess.open(SEA_PATH, FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_sea_cfg = parsed
	_waves.clear()
	for w: Array in _sea_cfg.get("waves", []):
		_waves.append(Vector4(float(w[0]), float(w[1]), float(w[2]), float(w[3])))
	while _waves.size() < 4:
		_waves.append(Vector4.ZERO)
	_water_mat.set_shader_parameter("waves", _waves)


## Hauteur de la houle (m, autour du niveau de la mer) au point (x, z) du monde. Lot 3 (3.7) : multipliée par la force de la mer.
func _wave_height(p: Vector2) -> float:
	var h := 0.0
	for w: Vector4 in _waves:
		h += w.x * sin(p.x * w.y + p.y * w.z + _sea_t * w.w)
	return h * _wave_amp


var _helm_turning := false
var _helm_gain := 1.0
var _helm_pitch := 1.0


## Lot 3 (3.9) : la roue tourne avec la barre (chez tout le monde : la barre est dans l'état du bateau) et grince d'autant plus
## qu'elle tourne vite.
func _update_helm_wheel(delta: float) -> void:
	_ship.set_helm(_sim.rudder)
	var rate := absf(_sim.rudder - _prev_rudder) / maxf(delta, 0.001)   # (barre par seconde : 1,6 au plus)
	_prev_rudder = _sim.rudder
	_helm_creak = lerpf(_helm_creak, clampf(rate / 1.6, 0.0, 1.0), 1.0 - exp(-delta * 10.0))
	var helm: Array = _ship.meta.get("helm", [0.0, 0.0])
	var at := _ship_point(Vector2(float(helm[0]), float(helm[1])), 1.0)
	# 12/11 : « toujours le même bruit à chaque coup de barre ». Chaque nouveau coup de barre a sa propre force et sa propre
	# hauteur (tirées au départ), la boucle elle-même change de prise, et le bois craque de temps en temps par-dessus, au hasard.
	if _helm_creak > 0.03:
		if not _helm_turning:
			_helm_turning = true
			_helm_gain = randf_range(GameConfig.HELM_GAIN_MIN, 1.0)
			_helm_pitch = randf_range(0.9, 1.08)
			_sfx.stop_loop("helm")   # (relancée juste après : une autre prise du grincement)
		_sfx.loop_at("helm", Synth.wheel_creak(), at, _helm_creak * GameConfig.HELM_CREAK_VOL * _helm_gain,
				_helm_pitch * (0.88 + 0.25 * _helm_creak))
		if randf() < GameConfig.HELM_CRACK_PER_S * _helm_creak * delta:
			_sfx.play_at(Synth.recorded("helm_crack"), at, randf_range(0.35, 0.75))
	else:
		_helm_turning = false
		_sfx.stop_loop("helm")


## Lot 3 (3.7) : la force de la mer (SkyCycle.swell, la même pour tous) agit sur la hauteur des vagues (donc le tangage et le
## roulis), la maniabilité, la caméra et le son de coque.
func _apply_swell(delta: float) -> void:
	var swell := _atmo.sky.swell if _atmo != null else 0.0
	_wave_amp = lerpf(1.0, GameConfig.SWELL_WAVE_MAX, swell)
	if absf(_wave_amp - _wave_amp_sent) > 0.01:   # l'eau dessinée suit la même houle que la flottaison
		_wave_amp_sent = _wave_amp
		var scaled: Array[Vector4] = []
		for w: Vector4 in _waves:
			scaled.append(Vector4(w.x * _wave_amp, w.y, w.z, w.w))
		_water_mat.set_shader_parameter("waves", scaled)
	_sim.handling = 1.0 - GameConfig.SWELL_STEER_PENALTY * swell
	# caméra : elle suit un peu le pont qui se soulève, et se balance doucement par mer formée (sans à-coups)
	var on_board: bool = _loc == Loc.SHIP or _loc == Loc.NEST or (_loc == Loc.CLIMB and _climb.get("kind") == "mast")
	var want := Vector3.ZERO
	if on_board:
		want = Vector3(sin(_sea_t * 0.55) * GameConfig.CAM_SWAY * swell, _ship.position.y * GameConfig.CAM_HEAVE_FOLLOW, cos(_sea_t * 0.41) * GameConfig.CAM_SWAY * 0.5 * swell)
	_cam_sway = _cam_sway.lerp(want, 1.0 - exp(-delta * 2.5))


func _save_frame() -> void:
	if _frames_left <= 0:
		if RenderingServer.frame_post_draw.is_connected(_save_frame):
			RenderingServer.frame_post_draw.disconnect(_save_frame)
		return
	var n := int(_args["frames"]) - _frames_left
	var dir := str(_args.get("frames-dir", "qa/frames"))
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png("%s/f_%03d.png" % [dir, n])
	_frames_left -= 1


## Diagnostic : hauteurs réelles de la coque et de la mer.
func _print_bounds() -> void:
	var lo := INF
	var hi := -INF
	var stack: Array[Node] = [_ship]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and String(n.name).begins_with("hull"):
			var mi := n as MeshInstance3D
			var aabb: AABB = mi.global_transform * mi.get_aabb()
			lo = minf(lo, aabb.position.y)
			hi = maxf(hi, aabb.end.y)
		stack.append_array(n.get_children())
	print("[hauteurs] coque de %.2f à %.2f m ; bateau y=%.2f ; mer y=%.2f" % [lo, hi, _ship.global_position.y, _sea.global_position.y])


## Charge la ville portuaire à l'origine du monde et amarre le bateau le long du ponton principal,
## étrave vers le large (sud). Les sols sont repeints par shaders/ground.gdshader.
func _build_port() -> void:
	var scene := load("res://assets/models/port/port.glb") as PackedScene
	var f := FileAccess.open("res://assets/models/port/port_meta.json", FileAccess.READ)
	if scene == null or f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	_port_meta = parsed if parsed is Dictionary else {}
	_land.load_meta(_port_meta)
	_port = scene.instantiate() as Node3D
	_world_fixed.add_child(_port)
	_remove_town_sand()
	var kinds := {"ground_cobble": 0, "ground_planks": 1, "ground_sand": 2, "ground_grass": 3}
	# matières peintes : le nom du matériau Blender dit quel motif utiliser (enduit, tuiles, bois, pierre)
	var surface_kinds := {"pl_": 0, "roof_": 1, "wood": 2, "stone": 3}
	var ground_shader := load("res://shaders/ground.gdshader") as Shader
	var surface_shader := load("res://shaders/surface.gdshader") as Shader
	var stack: Array[Node] = [_port]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not (n is MeshInstance3D):
			continue
		var mi := n as MeshInstance3D
		var is_ground := false
		for key: String in kinds:
			if String(n.name).contains(key):
				var m := ShaderMaterial.new()
				m.shader = ground_shader
				m.set_shader_parameter("kind", kinds[key])
				mi.material_override = m
				is_ground = true
		if is_ground or mi.mesh == null:
			continue
		var is_building := String(n.name).begins_with("bldg_")
		var record := {"mesh": mi, "normal": {}, "ghost": {}, "alpha": 1.0, "ghosted": false}
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if src == null:
				continue
			var mat: ShaderMaterial = null
			for prefix: String in surface_kinds:
				if src.resource_name.begins_with(prefix):
					mat = ShaderMaterial.new()
					mat.shader = surface_shader
					mat.set_shader_parameter("kind", surface_kinds[prefix])
					mat.set_shader_parameter("base", src.albedo_color)
					break
			if mat == null and is_building:
				# le reste d'un bâtiment (volets, auvents, vitrines) : couleur unie
				mat = ShaderMaterial.new()
				mat.shader = surface_shader
				mat.set_shader_parameter("kind", 4)
				mat.set_shader_parameter("base", src.albedo_color)
				mat.set_shader_parameter("emit", 1.0 if src.emission_enabled else 0.0)
			if mat == null:
				continue
			mi.set_surface_override_material(s, mat)
			if is_building:
				# la même matière en version transparente, qu'on met à la place quand le bâtiment cache le pirate
				var ghost := ShaderMaterial.new()
				ghost.shader = _ghost_shader(surface_shader)
				for param in ["kind", "base", "emit"]:
					ghost.set_shader_parameter(param, mat.get_shader_parameter(param))
				(record["normal"] as Dictionary)[s] = mat
				(record["ghost"] as Dictionary)[s] = ghost
		if is_building and not (record["normal"] as Dictionary).is_empty():
			_buildings.append(record)
	# amarrage : coque contre le flanc est du ponton, étrave au sud (+z dans le jeu)
	if not _args.has("player") and not _args.has("yaw"):
		var dock: Dictionary = _port_meta.get("dock", {})
		var half_beam := _ship.beam * ShipModel.SCALE * 0.5
		var x := float(dock.get("pier_x1", 18.0)) + half_beam + 0.5
		var z := -float(dock.get("y", -14.0))
		# coques agrandies (12/11/2026, longueur x1,35) : la poupe garde sa place d'avant, loin du quai ; c'est l'étrave qui avance
		z += _ship.length * ShipModel.SCALE * 0.5 * (1.0 - 1.0 / GameConfig.HULL_LENGTH_GROWTH)
		_sim.yaw = -PI / 2.0
		# le centre de la coque est décalé du pivot du bateau (beaupré compris) : on le compense
		_sim.position = Vector2(x, z) - Vector2(cos(_sim.yaw), -sin(_sim.yaw)) * (_ship.shift * ShipModel.SCALE)


## Bug 1.5 : la plage à gauche de la ville (ouest, x < -42) était dessinée et arrêtait les bateaux, mais ne faisait pas partie du
## sol où l'on marche : un pirate qui y sautait se retrouvait à nager dans le sable, ou coincé contre son bord. On la retire au
## chargement, avec ses palmiers (fondus dans le maillage « props » de tout le port : on n'en garde que les triangles à droite de la
## coupe) et leurs collisions. Fait ici plutôt que dans port.glb, que tools/art/make_port_scene.py régénère.
func _remove_town_sand() -> void:
	var cut := GameConfig.TOWN_SAND_CUT_X
	var stack: Array[Node] = [_port]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not (n is MeshInstance3D) or (n as MeshInstance3D).mesh == null:
			continue
		var mi := n as MeshInstance3D
		if String(mi.name).contains("ground_sand"):
			mi.visible = false
			continue
		var box := mi.global_transform * mi.mesh.get_aabb()
		if box.position.x < cut and box.end.x > cut:
			_strip_mesh_west_of(mi, cut)
	# plus de palmiers sur la plage disparue : leurs cercles n'arrêtent plus un saut ni un crochet
	_land.circles = _land.circles.filter(func(c: Array) -> bool: return float(c[0]) > cut)


## Retire d'un maillage tous les triangles entièrement à l'ouest de `cut_x` (coordonnées du monde).
func _strip_mesh_west_of(mi: MeshInstance3D, cut_x: float) -> void:
	var src := mi.mesh
	var out := ArrayMesh.new()
	var xf := mi.global_transform
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(verts.size())
			for k in verts.size():
				idx[k] = k
		var kept := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			var west := true
			for k in 3:
				if (xf * verts[idx[t + k]]).x >= cut_x:
					west = false
					break
			if not west:
				kept.append(idx[t])
				kept.append(idx[t + 1])
				kept.append(idx[t + 2])
		if kept.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = kept
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(s))
	mi.mesh = out


## Ombre ronde sous le pirate.
func _build_blob() -> void:
	_blob = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.42
	disc.bottom_radius = 0.42
	disc.height = 0.01
	_blob.mesh = disc
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color = Color(0.02, 0.01, 0.06, 0.42)
	_blob.material_override = bm
	_blob.scale = Vector3(1.0, 1.0, 0.7)
	_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ship.add_child(_blob)


## Place le bateau sur la houle (pilonnement, tangage, roulis) et transmet à l'eau la position du
## bateau pour son sillage.
func _float_ship() -> void:
	# La houle avance en continu (des paliers faisaient « sauter » toute la mer plusieurs fois par
	# seconde, visible à 144 images/s). Le même temps sert à l'eau et à la flottaison ; un client
	# se cale sur le temps de l'hôte pour que tout le monde voie les mêmes vagues.
	_sea_t = _time + _time_offset
	var yaw_basis := Basis(Vector3.UP, _sim.yaw)
	var fwd3 := yaw_basis * Vector3.RIGHT
	var left3 := yaw_basis * Vector3.FORWARD
	# position monde continue (plus de sauts d'un pixel) : la mer glisse sous le bateau en douceur
	var flat := Vector3(_sim.position.x, 0.0, _sim.position.y)
	var center := flat + fwd3 * (_ship.shift * ShipModel.SCALE)
	var hl := _ship.length * ShipModel.SCALE * 0.4
	var hb := _ship.beam * ShipModel.SCALE * 0.45
	var c2 := Vector2(center.x, center.z)
	var f2 := Vector2(fwd3.x, fwd3.z)
	var l2 := Vector2(left3.x, left3.z)
	var h_bow := _wave_height(c2 + f2 * hl)
	var h_stern := _wave_height(c2 - f2 * hl)
	var h_port := _wave_height(c2 + l2 * hb)
	var h_star := _wave_height(c2 - l2 * hb)
	var heave := (h_bow + h_stern + h_port + h_star) * 0.25 * float(_sea_cfg.get("buoyancy_follow", 0.85))
	heave -= _hull.fill() * 0.55   # la cale qui se remplit enfonce le bateau
	var pitch := atan2(h_bow - h_stern, hl * 2.0) * float(_sea_cfg.get("pitch_follow", 0.7))
	var roll := atan2(h_port - h_star, hb * 2.0) * float(_sea_cfg.get("roll_follow", 0.7))
	roll -= _sim.rudder * 0.035 * clampf(_sim.speed / maxf(_sim.max_speed, 0.1), 0.0, 1.0)
	_ship.position = Vector3(0.0, heave, 0.0)
	_world_origin = flat
	_world_fixed.position = Vector3(-flat.x, 0.0, -flat.z)
	_water_mat.set_shader_parameter("world_offset", Vector2(flat.x, flat.z))
	_water_mat.set_shader_parameter("sun_dir", _sun.global_transform.basis.z.normalized())
	_water_mat.set_shader_parameter("view_dir", _cam.global_transform.basis.z.normalized())
	_ship.rotation = Vector3(roll, _sim.yaw, pitch)
	_water_mat.set_shader_parameter("sea_time", _sea_t)
	_water_mat.set_shader_parameter("ship_center", c2)
	_water_mat.set_shader_parameter("ship_fwd", f2)
	_water_mat.set_shader_parameter("ship_speed", clampf(_sim.speed / maxf(_sim.max_speed, 0.1), 0.0, 1.0))
	_water_mat.set_shader_parameter("hull_len", _ship.length * ShipModel.SCALE)
	_water_mat.set_shader_parameter("hull_beam", _ship.beam * ShipModel.SCALE)
	# ombre du pont : le soleil la projette sur l'eau, décalée selon sa direction et la hauteur du pont
	var light_dir := -_sun.global_transform.basis.z
	var deck_above_water := heave - SEA_Y
	if light_dir.y < -0.05:
		var off := Vector2(light_dir.x, light_dir.z) * (deck_above_water / -light_dir.y)
		_water_mat.set_shader_parameter("shadow_offset", off)


func _build_player() -> void:
	_sprite = PirateSprite.new()
	_sprite.palette_first = true   # mes couleurs passent en premier dans la palette du filtre : elles n'en sont jamais exclues
	_sprite.enable_actions()   # mon pirate a aussi ses animations de tir et de pouvoir
	_sprite.set_look(_local_look())
	_sprite.set_weapon(_profile.weapon, _profile.skin_of(_profile.weapon))
	_ship.add_child(_sprite)
	PlayerName.load_saved()
	_name_tag = _make_name_tag(PlayerName.value)
	_sprite.add_child(_name_tag)
	_ball_icon = _make_ball(0.14, Color(0.12, 0.12, 0.16))
	_ball_icon.visible = false
	_sprite.add_child(_ball_icon)
	_ball_icon.position = Vector3(0.0, 2.2, 0.0)
	# point de départ : devant la porte de la cabine, décalé selon la place du joueur dans l'équipage
	var cabin := _ship.cabin
	var door_x := float(cabin.get("door_x", 0.0))
	var spots: Array[Vector2] = [Vector2(door_x + 0.9, 0.7), Vector2(door_x + 0.9, -0.2),
			Vector2(door_x + 1.6, 1.2), Vector2(door_x + 1.7, 0.2)]
	var slot := _crew_ids().find(_my_id())
	_ppos = spots[0]
	for k in spots.size():
		var cand: Vector2 = spots[(maxi(slot, 0) + k) % spots.size()]
		if _ship.is_walkable(cand):
			_ppos = cand
			break
	if _args.has("player") or _args.has("spawn"):
		var parts := str(_args.get("player", _args.get("spawn"))).split(",")
		_ppos = Vector2(float(parts[0]), float(parts[1]))
	# lanterne de la cabine
	if cabin.has("light"):
		var l: Array = cabin["light"]
		var omni := OmniLight3D.new()
		omni.light_color = Color(1.0, 0.7, 0.4)
		omni.light_energy = 1.6
		omni.omni_range = 4.5
		omni.position = Vector3((float(l[0]) + _ship.shift) * ShipModel.SCALE, float(l[1]) * ShipModel.SCALE, -float(l[2]) * ShipModel.SCALE)
		_ship.add_child(omni)


func _make_ball(radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mi.mesh = sphere
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mi.material_override = m
	return mi


## Lit les îles, les pose dans le monde (terre, ennemis, coffres) et les rend praticables à pied.
func _build_islands() -> void:
	_atmo = Atmosphere.new()   # le ciel (heure, météo), les sons et la vie des îles
	add_child(_atmo)
	_atmo.setup(_world, _world_fixed, _islands, _env, _sun, _args)
	if _args.has("no-islands"):
		return
	_islands.setup(IslandWorld.read_json(IslandWorld.ISLANDS_PATH), IslandWorld.read_json(IslandWorld.ENEMIES_PATH))
	_islands.build(_world_fixed, _land)
	_hp_max = int(_islands.player_cfg.get("hp", 6))
	_hp = _hp_max
	_chart.world = _islands
	_sync_quest_destination()   # une expédition en cours (sauvegardée) remet le cap sur son île
	if _args.has("discover"):   # essai : --discover=all (ou une liste d'identifiants) révèle des îles sur la carte
		for isl: Dictionary in _islands.islands:
			if str(_args["discover"]) == "all" or str(isl["id"]) in str(_args["discover"]).split(","):
				if not (isl["id"] in _profile.discovered):
					_profile.discovered.append(isl["id"])


## La table de cartes de la cabine : un parchemin posé dessus, et le point d'interaction.
func _build_chart_table() -> void:
	var table_pos := Vector2(-2.1, 0.0)
	if not _ship.cabin.is_empty():   # la table du modèle est à 0,35 devant le centre de la cabine (voir make_ship.py)
		table_pos = Vector2((float(_ship.cabin["x0"]) + float(_ship.cabin["x1"])) * 0.5 + 0.35, 0.0)
	_interactables.append({"kind": "chart", "pos": table_pos})
	var sheet := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 0.7)
	quad.orientation = PlaneMesh.FACE_Y
	sheet.mesh = quad
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.8, 0.55)
	m.roughness = 1.0
	sheet.material_override = m
	sheet.position = _ship.to_local3(table_pos, 0.0) + Vector3(0, 1.04, 0)
	sheet.rotation.y = deg_to_rad(8.0)
	_ship.add_child(sheet)
	var mark := MeshInstance3D.new()
	var mq := QuadMesh.new()
	mq.size = Vector2(0.14, 0.05)
	mq.orientation = PlaneMesh.FACE_Y
	mark.mesh = mq
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.75, 0.12, 0.1)
	mark.material_override = mm
	mark.position = Vector3(0.12, 0.004, -0.06)
	sheet.add_child(mark)


func _build_interactables() -> void:
	var meta := _ship.meta
	_build_chart_table()
	var helm: Array = meta.get("helm", [0.0, 0.0])
	_interactables.append({"kind": "helm", "pos": Vector2(float(helm[0]), float(helm[1]))})
	for m: Array in meta.get("masts", []):
		_interactables.append({"kind": "mast", "pos": Vector2(float(m[0]), 0.0)})
	for i in _ship.ladders.size():
		var l: Array = _ship.ladders[i]
		_interactables.append({"kind": "ladder", "pos": Vector2(float(l[0]), float(l[1])), "index": i})
	if not _ship.mast_ladder.is_empty():
		_interactables.append({"kind": "mastladder", "pos": Vector2(float(_ship.mast_ladder[0]), float(_ship.mast_ladder[1]))})
	var anchor: Array = meta.get("anchor", [0.0, 0.0])
	_interactables.append({"kind": "anchor", "pos": Vector2(float(anchor[0]), float(anchor[1]))})
	var ammo: Array = meta.get("ammo", [0.0, 0.0])
	_interactables.append({"kind": "ammo", "pos": Vector2(float(ammo[0]), float(ammo[1]))})
	if _ship.crate_pos != Vector2.INF:
		_interactables.append({"kind": "crate", "pos": _ship.crate_pos})
	if _ship.stash_pos != Vector2.INF:
		_interactables.append({"kind": "stash", "pos": _ship.stash_pos})
		# un éclat d'or flotte au-dessus du coffre quand il contient des trésors
		_stash_glow = MeshInstance3D.new()
		var gm := SphereMesh.new()
		gm.radius = 0.16
		gm.height = 0.32
		gm.radial_segments = 8
		gm.rings = 4
		_stash_glow.mesh = gm
		var glow_mat := StandardMaterial3D.new()
		glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow_mat.albedo_color = Color(1.0, 0.88, 0.35)
		_stash_glow.material_override = glow_mat
		_stash_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_stash_glow.position = _ship.to_local3(_ship.stash_pos, 1.0)
		_stash_glow.visible = false
		_ship.add_child(_stash_glow)
	_cannon_nodes = ShipCannons.build(_ship)
	for i in _ship.cannons.size():
		var c: Array = _ship.cannons[i]
		_interactables.append({"kind": "cannon", "pos": Vector2(float(c[0]), float(c[1])), "index": i})
		_cannon_loaded.append(false)
		var icon := _make_ball(0.17, Color(1.0, 0.55, 0.15))
		var mat := icon.material_override as StandardMaterial3D
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		icon.visible = false
		icon.position = (_cannon_nodes[i]["root"] as Node3D).position + Vector3(0.0, 1.35, 0.0)
		_ship.add_child(icon)
		_cannon_icons.append(icon)
	_build_grapple_mount()
	_build_target_marker()


## La flèche jaune qui désigne le poste que E actionnerait : posée au-dessus de l'objet, elle rebondit doucement.
func _build_target_marker() -> void:
	_target_marker = Node3D.new()
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.28
	cm.height = 0.55
	cm.radial_segments = 4
	cone.mesh = cm
	cone.rotation.x = PI   # la pointe vers le bas
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.86, 0.2)
	mat.no_depth_test = true
	mat.render_priority = 8
	cone.material_override = mat
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_target_marker.add_child(cone)
	_target_marker.visible = false
	_ship.add_child(_target_marker)


## Met l'affichage de jeu à l'échelle choisie (si elle ou la fenêtre ont changé) : le bloc est plus petit que la fenêtre
## de ce facteur, puis agrandi du même facteur, et remplit donc exactement la fenêtre.
func _apply_hud_scale() -> void:
	if _hud_root == null:
		return
	var s := DisplaySettings.hud_scale
	if is_equal_approx(s, _hud_scale_applied) and size == _hud_size_applied:
		return
	_hud_scale_applied = s
	_hud_size_applied = size
	_hud_root.position = Vector2.ZERO
	_hud_root.size = size / s
	_hud_root.scale = Vector2(s, s)


func _build_hud() -> void:
	# Tout l'affichage de jeu (texte, cadran, cœurs, barre de sorts) vit dans _hud_root, qu'on agrandit d'un bloc (curseur
	# « Taille de l'interface ») : il garde la taille de la fenêtre divisée par l'échelle, donc les ancres tombent juste.
	_hud_root = Control.new()
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_root)
	_apply_hud_scale()
	_hud = Label.new()
	_hud.position = Vector2(12, 8)
	_hud.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	_hud.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	_hud.add_theme_constant_override("outline_size", 6)
	_hud.add_theme_font_size_override("font_size", 16)
	_hud_root.add_child(_hud)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.position = Vector2(0, -44)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	_prompt.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.add_theme_font_size_override("font_size", 18)
	_hud_root.add_child(_prompt)
	# Coin haut droit : l'or (plusieurs lignes : or, boulets, coffre, trésor porté) puis l'état du réseau, empilés dans une colonne
	# qui suit la hauteur réelle de chaque bloc. Avant, l'état du réseau était posé à une hauteur fixe et chevauchait les lignes de
	# l'or dès qu'il y en avait plus d'une (et d'autant plus avec un grand « Taille de l'interface »).
	_top_right = VBoxContainer.new()
	_top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	_top_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_top_right.offset_right = -GameConfig.HUD_MARGIN
	_top_right.offset_top = GameConfig.HUD_MARGIN_TOP
	_top_right.add_theme_constant_override("separation", GameConfig.HUD_STACK_GAP)
	_hud_root.add_child(_top_right)
	# état du réseau (adresse à donner aux amis, connexion…), en haut à droite, sous l'or
	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.visible = false   # rien à dire : la ligne ne prend pas de place
	_status_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	_status_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	_status_label.add_theme_constant_override("outline_size", 6)
	_status_label.add_theme_font_size_override("font_size", 15)
	_invite = InvitePanel.new()
	_invite.visible = false
	_hud_root.add_child(_invite)
	# jauge de la cale
	_gauge_back = ColorRect.new()
	_gauge_back.color = Color(0.05, 0.03, 0.1, 0.75)
	_gauge_back.position = Vector2(12, 62)
	_gauge_back.size = Vector2(190, 16)
	_gauge_back.visible = false
	_hud_root.add_child(_gauge_back)
	_gauge_fill = ColorRect.new()
	_gauge_fill.position = Vector2(2, 2)
	_gauge_fill.size = Vector2(0, 12)
	_gauge_back.add_child(_gauge_fill)
	_gauge_label = Label.new()
	_gauge_label.position = Vector2(12, 80)
	_gauge_label.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	_gauge_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	_gauge_label.add_theme_constant_override("outline_size", 6)
	_gauge_label.add_theme_font_size_override("font_size", 14)
	_gauge_label.visible = false
	_hud_root.add_child(_gauge_label)
	# cadran du vent et des voiles
	_sail_hud = SailHud.new()
	_sail_hud.position = Vector2(12, 108)
	_hud_root.add_child(_sail_hud)
	# or et quête en cours
	_profile.persistent = not _args.has("fresh")
	_profile.load_file()
	_quests = QuestLog.new(_profile)
	_sync_quest_destination()
	_gold_label = Label.new()
	_gold_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_gold_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	_gold_label.add_theme_constant_override("outline_size", 6)
	_gold_label.add_theme_font_size_override("font_size", 17)
	_top_right.add_child(_gold_label)
	_top_right.add_child(_status_label)   # l'ordre compte : l'or en premier, l'état du réseau dessous
	_quest_label = Label.new()
	_quest_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_quest_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_quest_label.position = Vector2(12, -150)   # au-dessus de la barre de sorts (à terre), qui occupait le bas de l'écran
	_quest_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	_quest_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	_quest_label.add_theme_constant_override("outline_size", 6)
	_quest_label.add_theme_font_size_override("font_size", 14)
	_hud_root.add_child(_quest_label)
	_dialog = DialogueBox.new()
	_dialog.closed.connect(_on_dialog_closed)
	add_child(_dialog)
	_shop_defs = Shop.load_defs()
	_shop_menu = ShopMenu.new()
	_shop_menu.purchased.connect(_on_purchase)
	add_child(_shop_menu)
	_inventory = InventoryPanel.new()
	_inventory.use_item.connect(_on_inventory_use)
	_inventory.closed.connect(_on_inventory_closed)
	_inventory.alt_item.connect(_on_inventory_alt)
	add_child(_inventory)
	_weapon_label = Label.new()
	_weapon_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_weapon_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_weapon_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_weapon_label.position = Vector2(-12, -44)
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weapon_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_weapon_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	_weapon_label.add_theme_constant_override("outline_size", 6)
	_weapon_label.add_theme_font_size_override("font_size", 15)
	_hud_root.add_child(_weapon_label)
	_island_hud = IslandHud.new()
	_hud_root.add_child(_island_hud)
	_act_gauge = ActionGauge.new()   # la jauge circulaire des actions longues (lot 2)
	_hud_root.add_child(_act_gauge)
	# lot 4 (10.3) : le grand texte du centre (à terre, réapparition, noyade qui approche)
	_center_label = Label.new()
	_center_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_center_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_center_label.offset_top = 150.0
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.add_theme_font_size_override("font_size", 26)
	_center_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.8))
	_center_label.add_theme_color_override("font_outline_color", Color(0.12, 0.02, 0.02))
	_center_label.add_theme_constant_override("outline_size", 8)
	_center_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_center_label)
	_rep_hud = ReputationHud.new()   # la réputation : rang, barre de progression et bannière de rang
	_rep_hud.set_points(_profile.reputation)
	_hud_root.add_child(_rep_hud)
	_chart = SeaChart.new()
	_chart.destination_chosen.connect(func(i: int) -> void: _destination = i)
	add_child(_chart)
	_quest_panel = QuestPanel.new()   # le journal de quêtes (J)
	add_child(_quest_panel)
	_pause = PauseMenu.new()
	_pause.show_quests.connect(func() -> void:
		_pause.close()
		_open_quests())
	_pause.resume.connect(_pause.close)
	_pause.show_invite.connect(_toggle_invite)
	_pause.toggle_compass.connect(_toggle_compass)
	_pause.unstick_ship.connect(func() -> void:
		_pause.close()
		_request("unstick", 0))
	_pause.tow_ship.connect(func() -> void:
		_pause.close()
		_request("tow", 0))
	_pause.back_to_menu.connect(_back_to_menu)
	_pause.quit_game.connect(func() -> void: get_tree().quit())
	add_child(_pause)
	# fondu au noir des changements d'étage
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func _apply_test_args() -> void:
	if _args.has("enemy"):   # essai : --enemy=sloop,x,z fait apparaître un bateau ennemi à cet endroit du monde (et pas d'autres)
		var ep := str(_args["enemy"]).split(",")
		_fleet.spawn_enabled = false
		_fleet.spawn(ep[0], Vector2(float(ep[1]), float(ep[2])), float(_args.get("enemy-yaw", "0")) * PI / 180.0)
	if _args.has("carry"):   # essai : --carry=calice met ce trésor dans les bras du pirate
		get_tree().create_timer(0.5).timeout.connect(func() -> void: _pick_up_treasure(str(_args["carry"])))
	if _args.has("enemy-sink"):   # essai : --enemy-sink=6 coule les ennemis à cet instant (naufrage et butin flottant)
		get_tree().create_timer(float(_args["enemy-sink"])).timeout.connect(func() -> void:
			for s: Dictionary in _fleet.ships:
				_fleet.hurt(int(s["id"]), 100000.0))
	if _args.has("loot"):   # essai : --loot=t:calice,x,z pose un butin à flot
		var lp := str(_args["loot"]).split(",")
		_loot.spawn(lp[0], Vector2(float(lp[1]), float(lp[2])), 600.0)
	if _args.has("wind"):   # essai : --wind=60 fixe le vent (degrés, 0 = vers +x) et l'empêche de dériver
		_sim.wind_angle = deg_to_rad(float(_args["wind"]))
		_sim.wind_dir = Vector2.from_angle(_sim.wind_angle)
	if _args.has("sail"):
		_sim.sail_level = int(_args["sail"])
		_sim.sail_open = float(_sim.sail_level) / ShipSim.SAIL_LEVELS
		_sim.auto_trim_pending = false
		_sim.sail_trim_target = _sim.optimal_trim()
		_sim.sail_trim = _sim.sail_trim_target
	if _args.has("trim"):   # essai : --trim=-20 oriente les vergues (degrés)
		_sim.sail_trim_target = deg_to_rad(float(_args["trim"]))
		_sim.sail_trim = _sim.sail_trim_target
		_sim.auto_trim_pending = false
	if _args.has("swim"):   # essai : --swim=x,z met le pirate à l'eau à cet endroit du monde
		var sw := str(_args["swim"]).split(",")
		get_tree().create_timer(0.2).timeout.connect(func() -> void: _enter_swim(Vector2(float(sw[0]), float(sw[1]))))
	if _args.has("move"):   # essai : --move=dx,dy@t0:t1;dx,dy@t2:t3 impose une direction de marche (écran) entre ces instants
		for item in str(_args["move"]).split(";"):
			var halves := item.split("@")
			var dir_parts := halves[0].split(",")
			var times := halves[1].split(":")
			var dir := Vector2(float(dir_parts[0]), float(dir_parts[1]))
			get_tree().create_timer(float(times[0])).timeout.connect(func() -> void: _test_move = dir)
			get_tree().create_timer(float(times[1])).timeout.connect(func() -> void: _test_move = Vector2.ZERO)
	if _args.has("rudder"):
		_sim.rudder_target = float(_args["rudder"])
		_sim.rudder = _sim.rudder_target
	if _args.has("anchor"):
		_sim.anchored = true
	if _args.has("speed"):
		_sim.speed = float(_args["speed"])
	if _args.has("walkto"):
		var parts := str(_args["walkto"]).split(",")
		_walkto = Vector2(float(parts[0]), float(parts[1]))
	if _args.has("helm"):
		_request("helm_take", 0)
		_enter_helm()
	if _args.has("shippos"):
		var sp := str(_args["shippos"]).split(",")
		_sim.position = Vector2(float(sp[0]), float(sp[1]))
	if _args.has("land"):
		var lp := str(_args["land"]).split(",")
		_lpos = Vector2(float(lp[0]), float(lp[1]))
		_loc = Loc.LAND
		_lh = _islands.ground_h(_lpos)   # sur le relief d'une île, on pose le pirate à la hauteur du sol
		if _args.has("lh"):
			_lh = float(_args["lh"])
		_snap_camera()   # (essais : la caméra est déjà sur le pirate au départ)
	if _args.has("planks"):   # essai : --planks=8 donne ce nombre de planches
		_profile.planks = int(_args["planks"])
	if _args.has("craft"):   # essai : --craft=raft@3 fabrique cet objet à cet instant (le pirate doit être à terre, près de l'eau)
		var cr := str(_args["craft"]).split("@")
		get_tree().create_timer(float(cr[1]) if cr.size() > 1 else 1.0).timeout.connect(func() -> void: _craft(cr[0]))
	if _args.has("clear-island"):   # essai : --clear-island=t bat les ennemis et ouvre les coffres de l'île sous le pirate à cet instant
		get_tree().create_timer(float(_args["clear-island"])).timeout.connect(func() -> void:
			var ci := _islands.island_at(_lpos)
			if ci >= 0:
				for en_id: int in (_islands.islands[ci] as Dictionary)["enemies"]:
					_islands.enemies[en_id].hurt(9999, _lpos, 0.0)
				for ch_id: int in (_islands.islands[ci] as Dictionary)["chests"]:
					_islands.open_chest(ch_id))
	if _args.has("capture"):   # essai : --capture=t hisse le drapeau de l'île sous le pirate à cet instant
		get_tree().create_timer(float(_args["capture"])).timeout.connect(func() -> void:
			var ci := _islands.island_at(_lpos)
			if ci >= 0:
				_cabin_send("capture", ci, "", 0, Vector2.ZERO))
	if _args.has("chest-demo"):   # essai : --chest-demo=t range du matériel dans le coffre de la cabane puis l'ouvre
		get_tree().create_timer(float(_args["chest-demo"])).timeout.connect(func() -> void:
			var ci := _islands.island_at(_lpos)
			if ci >= 0 and Outpost.has_cabin(_op(), str((_islands.islands[ci] as Dictionary)["id"])):
				_open_cabin_chest(ci)
				_on_chest_use("cab_put", "plank")
				_on_chest_use("cab_put", "gold"))
	if _args.has("raft-ride"):   # essai : --raft-ride=t monte sur le radeau à cet instant
		get_tree().create_timer(float(_args["raft-ride"])).timeout.connect(func() -> void: _board_raft())
	if _args.has("press"):
		# test : --press=E@2,SPACE@3.5 appuie sur ces touches aux secondes indiquées
		var codes := {"E": KEY_E, "R": KEY_R, "SPACE": KEY_SPACE, "DOWN": KEY_DOWN, "UP": KEY_UP, "F": KEY_F, "ESC": KEY_ESCAPE, "1": KEY_1, "2": KEY_2, "3": KEY_3, "4": KEY_4, "T": KEY_T, "TAB": KEY_TAB, "X": KEY_X, "G": KEY_G, "C": KEY_C, "H": KEY_H, "V": KEY_V, "J": KEY_J}
		for item in str(_args["press"]).split(","):
			var kv := item.split("@")
			var code: Key = codes.get(kv[0], KEY_E)
			get_tree().create_timer(float(kv[1])).timeout.connect(func() -> void:
				var ev := InputEventKey.new()
				ev.physical_keycode = code
				ev.pressed = true
				_unhandled_input(ev))
	if _args.has("send"):
		# test réseau : --send=sail:1,anchor:0 envoyé 2 s après l'arrivée à bord
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			for item in str(_args["send"]).split(","):
				var kv := item.split(":")
				_request(kv[0], int(kv[1]) if kv.size() > 1 else 0))
	if _args.has("fire"):
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			for i in _ship.cannons.size():
				_cannon_loaded[i] = true
				_request("fire", i))
	if _args.has("quest"):   # essai : --quest=crabes_rhum met cette quête en cours
		_profile.quests[str(_args["quest"])] = "active"
		_sync_quest_destination()
	if _args.has("berry"):   # essai : --berry=ignis donne cette baie
		_profile.berry = str(_args["berry"])
	if _args.has("chart"):   # essai : --chart=2 ouvre la carte des mers à cet instant
		get_tree().create_timer(float(_args["chart"])).timeout.connect(_open_chart)
	if _args.has("weapon"):   # essai : --weapon=pistolet met cette arme en main (avec des munitions)
		var wid := str(_args["weapon"])
		if not (wid in _profile.weapons):
			_profile.weapons.append(wid)
		_profile.weapon = wid
		if _args.has("wskin"):   # essai : --wskin=flibustier pose ce skin sur l'arme en main
			var wk := WeaponSkins.key(wid, str(_args["wskin"]))
			if not _profile.skins_owned.has(wk):
				_profile.skins_owned.append(wk)
			_profile.skin_worn[wid] = str(_args["wskin"])
		_profile.bullets = maxi(_profile.bullets, 20)
		_profile.shells = maxi(_profile.shells, 20)
	if _args.has("fake-remote"):   # essai : --fake-remote=dx,dy fait apparaître un « joueur distant » avec mon apparence, à côté de moi
		# sur le pont, dans l'ordre du vrai réseau : d'abord sa position (pirate au hasard), puis son apparence et son arme
		var fr := str(_args["fake-remote"]).split(",")
		var fr_off := Vector2(float(fr[0]), float(fr[1])) if fr.size() > 1 else Vector2(0.8, 0.0)
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if _args.has("fake-swim"):   # essai : --fake-swim il nage à côté de moi (je suis sur le pont) : de quoi le hisser
				apply_remote_player(990001, _ship_to_world(_ppos) + fr_off, "", 5, 0.0, 0.0)
			elif _loc == Loc.LAND:   # à côté de moi, là où je suis (à terre : en mètres du monde)
				apply_remote_player(990001, _lpos + fr_off, str(_args.get("fake-carry", "")), 1, 0.0, _lh)
			else:
				apply_remote_player(990001, _ppos + fr_off, str(_args.get("fake-carry", "")), Loc.SHIP, 0.0, 0.0))
		if _args.has("fake-act"):   # essai : --fake-act=repair le « joueur distant » fait cette action longue (2 s après)
			get_tree().create_timer(2.0).timeout.connect(func() -> void:
				apply_action(990001, "act", "%s|%.2f" % [str(_args["fake-act"]), TimedAction.duration_of(str(_args["fake-act"]))], Vector2.ZERO, Vector2(0, 1)))
		get_tree().create_timer(1.3).timeout.connect(func() -> void:
			apply_remote_look(990001, local_look_json()))
	if _args.has("down"):   # essai : --down=2 je tombe à terre à cet instant (lot 4)
		get_tree().create_timer(float(_args["down"])).timeout.connect(_go_down)
	if _args.has("water-time"):   # essai : --water-time=85 (avec --swim) : déjà ce temps passé dans l'eau
		get_tree().create_timer(0.4).timeout.connect(func() -> void: _water_t = float(_args["water-time"]))
	if _args.has("gold"):   # essai : --gold=150 donne de l'or
		_profile.gold = int(_args["gold"])
	if _args.has("quest"):   # essai : --quest=tonnelet met cette quête en cours
		_profile.quests[str(_args["quest"])] = "active"
	if _args.has("water"):
		_hull.water = float(_args["water"])
	if _args.has("hit"):
		# test : --hit=abscisse,côté,nombre (côté +1 bâbord, -1 tribord) ouvre des voies d'eau 0,5 s après le départ
		var hp := str(_args["hit"]).split(",")
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			apply_hit(HIT_ROCK, float(hp[0]), int(hp[1]), int(hp[2])))
	if _args.has("hold"):
		get_tree().create_timer(0.3).timeout.connect(func() -> void:
			_enter_hold(true)
			if _args.has("hpos"):
				var hq := str(_args["hpos"]).split(",")
				_hpos = Vector2(float(hq[0]), float(hq[1]))
				_prev_hpos = _hpos)
	if _args.has("enemy-fire"):
		# test : --enemy-fire=secondes[,côté] un boulet ennemi arrive sur le bateau à ce moment
		var ef := str(_args["enemy-fire"]).split(",")
		get_tree().create_timer(float(ef[0])).timeout.connect(func() -> void:
			spawn_enemy_ball(int(ef[1]) if ef.size() > 1 else -1))
	if _args.has("shot"):
		get_tree().create_timer(float(_args.get("shot-after-secs", "3"))).timeout.connect(func() -> void:
			get_viewport().get_texture().get_image().save_png(str(_args["shot"])))
	if _args.has("shot2"):
		get_tree().create_timer(float(_args.get("shot-after-secs", "3")) + 0.05).timeout.connect(func() -> void:
			get_viewport().get_texture().get_image().save_png(str(_args["shot2"])))
	if _args.has("bounds"):
		get_tree().create_timer(1.0).timeout.connect(_print_bounds)
	if _args.has("frames"):
		# enregistre N images consécutives (diagnostic des vibrations), dans --frames-dir
		get_tree().create_timer(float(_args.get("shot-after-secs", "3"))).timeout.connect(func() -> void:
			_frames_left = int(_args["frames"])
			RenderingServer.frame_post_draw.connect(_save_frame))
	if _args.has("quit-after-secs"):
		get_tree().create_timer(float(_args["quit-after-secs"])).timeout.connect(get_tree().quit)


# ------------------------------------------------------------------ coque et cale


## Prépare tout ce qui touche à la coque : règles de dégâts, récifs, cale, écoutille, repères sur la coque.
func _setup_hull() -> void:
	var cfg := HullDamage.load_config()
	_hull.configure(cfg, _ship.length)
	_rocks.load_from(cfg)
	if not _args.has("no-rocks"):
		_rocks.build(_world_fixed, SEA_Y)
	_spawn_pos = _sim.position
	_spawn_yaw = _sim.yaw
	_fleet.spawn_origin = _spawn_pos
	_hold_layout.setup(_ship.length, _ship.hatch_pos().x, _hull)
	_hold = HoldRoom.new()
	_hold.position = Vector3(0.0, HOLD_Y, 0.0)
	_world.add_child(_hold)
	_hold.build(_hold_layout)
	_hold.visible = false
	_hold_items = _hold_layout.items()
	if not _land.walk_rects.is_empty():
		_build_town()
	_interactables.append({"kind": "hatch", "pos": _ship.hatch_pos()})
	if _ship.ship_name == "sloop":
		# le modèle du sloop n'a pas d'écoutille : on en pose une, basse, qu'on enjambe
		var hatch := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(1.1, 0.26, 1.1)
		hatch.mesh = hm
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.55, 0.38, 0.22)
		hatch.material_override = wood
		hatch.position = _ship.to_local3(_ship.hatch_pos(), 0.13)
		_ship.add_child(hatch)
		var grate := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(0.9, 0.05, 0.9)
		grate.mesh = gm
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(0.08, 0.06, 0.06)
		grate.material_override = dark
		grate.position = _ship.to_local3(_ship.hatch_pos(), 0.27)
		_ship.add_child(grate)
	# planche portée
	_plank_icon = MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.7, 0.07, 0.16)
	_plank_icon.mesh = pm
	var plank_mat := StandardMaterial3D.new()
	plank_mat.albedo_color = Color(0.82, 0.64, 0.40)
	_plank_icon.material_override = plank_mat
	_plank_icon.visible = false
	_plank_icon.position = Vector3(0.0, 2.2, 0.0)
	_sprite.add_child(_plank_icon)
	# repères des voies d'eau sur la coque
	for slot in _hull.slot_count():
		var bx := _hull.slot_bx(slot)
		var side := _hull.slot_side(slot)
		var mark := Node3D.new()
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.3
		cm.bottom_radius = 0.3
		cm.height = 0.1
		disc.mesh = cm
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color(0.03, 0.02, 0.02)
		disc.material_override = dm
		disc.rotation = Vector3(PI / 2.0, 0.0, 0.0)
		mark.add_child(disc)
		for k in 7:
			var a := TAU * float(k) / 7.0
			var chip := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.1, 0.07, 0.3)
			chip.mesh = bm
			var cmat := StandardMaterial3D.new()
			cmat.albedo_color = Color(0.82, 0.64, 0.40)
			chip.material_override = cmat
			chip.position = Vector3(cos(a) * 0.36, sin(a) * 0.36, 0.0)
			chip.rotation = Vector3(0.0, 0.0, a)
			mark.add_child(chip)
		var hw := _ship.half_width(bx) * ShipModel.SCALE
		mark.position = Vector3((bx + _ship.shift) * ShipModel.SCALE, _ship.deck_height(bx) - 0.95, -float(side) * (hw * 0.93 + 0.04))
		mark.visible = false
		_ship.add_child(mark)
		_hull_marks.append(mark)
	_refresh_hull_visuals()


func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


## La vie de la ville : terrasses et escaliers, intérieurs, habitants et promeneurs (data/town.json, npcs.json).
func _build_town() -> void:
	_land.load_town(_read_json("res://data/town.json"))
	TownBuilder.build_levels(_world_fixed, _land)
	for it: Dictionary in _land.interiors:
		var root := ShopBuilder.build(it) if it.has("kind") else TownBuilder.build_tavern(it)
		root.visible = false
		_world_fixed.add_child(root)
		var building: Node = _port.find_child(str(it.get("building_node", "")), true, false) if _port != null else null
		_interior_nodes.append({"root": root, "building": building})
	var cfg := _read_json("res://data/npcs.json")
	_npc_range = float(cfg.get("range", 2.3))
	for kind in ["npcs", "wanderers"]:
		for d: Dictionary in cfg.get(kind, []):
			var npc := TownNpc.from_data(d, kind == "wanderers")
			_world_fixed.add_child(npc.sprite)
			npc.blob = _blob.duplicate() as MeshInstance3D
			_world_fixed.add_child(npc.blob)
			npc.interior = _land.interior_at(npc.pos)
			if kind == "npcs" and npc.interior < 0 and npc.h == 0.0:
				_land.circles.append([npc.pos.x, -npc.pos.y, 0.45])   # on ne marche pas à travers un boutiquier
			_npcs.append(npc)
			_quests.names[npc.id] = npc.display_name
	_update_npcs(0.0)


## Place les habitants, fait marcher les promeneurs ; ceux d'un intérieur ne se voient que quand on y est.
func _update_npcs(delta: float) -> void:
	for npc: TownNpc in _npcs:
		var move := npc.update(delta)
		var shown := npc.interior < 0 or npc.interior == _interior_active
		npc.sprite.visible = shown and npc.sprite.texture != null
		npc.blob.visible = shown
		npc.sprite.position = Vector3(npc.pos.x, npc.h + 0.02, npc.pos.y)
		npc.blob.position = Vector3(npc.pos.x, npc.h + 0.04, npc.pos.y)
		if shown:
			npc.sprite.drive(delta, move, false, false, Vector2.ZERO)
		if npc.tag != null:   # son nom : seulement d'assez près (sinon la ville serait couverte d'étiquettes)
			var here := _lpos if _loc == Loc.LAND else _my_world_pos()
			npc.tag.visible = shown and here.distance_to(npc.pos) < GameConfig.NPC_NAME_RANGE


## Version « fantôme » du shader des bâtiments : même peinture, mais mélangée à ce qui est derrière (ALPHA), et
## qui écrit la profondeur pour ne montrer que la face avant (pas de murs qui se superposent à travers).
func _ghost_shader(base_shader: Shader) -> Shader:
	if _ghost_shader_cache == null:
		var gs := Shader.new()
		gs.code = base_shader.code \
				.replace("shader_type spatial;", "shader_type spatial;\nrender_mode blend_mix, depth_draw_always;\nuniform float ghost_alpha = 1.0;") \
				.replace("ALBEDO = c;", "ALBEDO = c;\n\tALPHA = ghost_alpha;")
		_ghost_shader_cache = gs
	return _ghost_shader_cache


## Un bâtiment qui passe devant le pirate (le rayon de lui vers la caméra le traverse) devient en partie transparent :
## on le voit toujours, mais on voit le pirate à travers.
func _update_building_fade(delta: float) -> void:
	var watching := _loc == Loc.LAND and not _args.has("no-fade")
	var from := Vector3.ZERO
	var dir := Vector3.ZERO
	if watching:
		from = _sprite.global_position + Vector3(0.0, 1.0, 0.0)
		dir = _cam.global_transform.basis.z
	var target_alpha := float(_args.get("fade", "0.5"))
	_ghosting = false
	for rec: Dictionary in _buildings:
		var mi := rec["mesh"] as MeshInstance3D
		var want := 1.0
		if watching and mi.visible:
			var box := mi.global_transform * mi.get_aabb()
			box.position += Vector3(0.3, 0.0, 0.3)   # un bâtiment à côté de lui ne compte pas
			box.size -= Vector3(0.6, 0.0, 0.6)
			if box.size.x > 0.0 and box.size.z > 0.0 and box.intersects_ray(from, dir) != null:
				want = target_alpha
		var a: float = rec["alpha"]
		if want < 1.0:
			_ghosting = true
		if is_equal_approx(a, want):
			continue
		a = move_toward(a, want, delta * 4.0)
		rec["alpha"] = a
		var ghost_now: bool = a < 0.999
		if ghost_now != rec["ghosted"]:
			rec["ghosted"] = ghost_now
			var mats: Dictionary = rec["ghost"] if ghost_now else rec["normal"]
			for s: int in mats:
				mi.set_surface_override_material(s, mats[s])
		if ghost_now:
			for g: ShaderMaterial in (rec["ghost"] as Dictionary).values():
				g.set_shader_parameter("ghost_alpha", a)


## Montre l'intérieur où je me trouve à la place du bâtiment du port (coupe sans toit ni façade).
func _update_interior() -> void:
	var idx := _land.interior_at(_lpos) if _loc == Loc.LAND else -1
	if idx == _interior_active:
		return
	_interior_active = idx
	for i in _interior_nodes.size():
		var e: Dictionary = _interior_nodes[i]
		(e["root"] as Node3D).visible = i == idx
		if e["building"] != null:
			(e["building"] as Node3D).visible = i != idx


## Le PNJ le plus proche à portée de parole (même étage, même intérieur), ou null.
func _nearest_npc() -> TownNpc:
	var best: TownNpc = null
	var best_d := _npc_range
	for npc: TownNpc in _npcs:
		if npc.interior != _interior_active and npc.interior >= 0:
			continue
		if absf(npc.h - _lh) > 1.0 or not npc.sprite.visible:
			continue
		var d := _lpos.distance_to(npc.pos)
		if d < best_d:
			best_d = d
			best = npc
	return best


## Une quête d'expédition en cours fixe le cap sur son île : la flèche de l'écran la montre, et la carte des mers y
## plante le drapeau (une zone floue « Terre inconnue » tant qu'on ne l'a pas vue). Sans quête, le cap reste au choix du joueur.
func _sync_quest_destination() -> void:
	if _quests == null or _islands.islands.is_empty():
		return
	var id := _quests.current_island()
	if id == "":
		if _quest_dest >= 0 and _destination == _quest_dest:
			_destination = -1
		_quest_dest = -1
		return
	for i in _islands.islands.size():
		if str(_islands.islands[i]["id"]) == id:
			_quest_dest = i
			_destination = i
			return


## À terre : si je pose le pied sur l'île d'une quête, l'expédition est accomplie (il reste à le dire au donneur).
func _check_quest_arrival() -> void:
	if _loc != Loc.LAND:
		return
	var i := _islands.island_at(_lpos, 0.0)
	if i < 0:
		return
	var done := _quests.reach_island(str(_islands.islands[i]["id"]))
	if done.is_empty():
		return
	if not (_islands.islands[i]["id"] in _profile.discovered):
		_profile.discovered.append(_islands.islands[i]["id"])
		_profile.save()
	_sync_quest_destination()
	var giver: String = str(_quests.defs[done[0]]["giver"])
	_say("Île atteinte : %s ! Retourne voir %s au port" % [_islands.islands[i]["name"], _quests.names.get(giver, giver)], 6.0)


func _talk(npc: TownNpc) -> void:
	var t := _quests.talk(npc.id, npc.lines)
	_dialog_ctx = {"npc": npc, "offer": t["offer"], "turn_in": t["turn_in"]}
	npc.sprite.direction = PirateSprite.direction_of(_lpos - npc.pos)   # il se tourne vers moi
	_dialog.start(npc.display_name, t["lines"], t["offer"] != "")


## Fin d'un dialogue : quête acceptée ou refusée, ou rendue (récompense).
func _on_dialog_closed(accepted: bool) -> void:
	var ctx := _dialog_ctx
	_dialog_ctx = {}
	if ctx.is_empty():
		return
	var npc := ctx["npc"] as TownNpc
	if ctx["offer"] != "":
		if accepted:
			var lines := _quests.accept(str(ctx["offer"]))
			if not lines.is_empty():
				_dialog.start(npc.display_name, lines, false)
			_say("Quête acceptée : %s" % str(_quests.defs[ctx["offer"]]["title"]), 3.5)
			if _quests.is_expedition(str(ctx["offer"])):
				_sync_quest_destination()
				_say("Quête acceptée : le cap est fixé sur la carte des mers", 4.0)
		else:
			_say("Tu déclines. Il te reste du temps pour changer d'avis.", 3.0)
	elif ctx["turn_in"] != "":
		var reward := _quests.complete(str(ctx["turn_in"]))
		if reward > 0:
			_say("Quête terminée ! +%d pièces d'or" % reward, 4.5)
			apply_rep(int(Reputation.gain("quest")), "quête terminée")
		_sync_quest_destination()
	elif bool(ctx.get("sell", false)):
		if accepted:
			_sell_to_fence()
	elif _shop_defs.has(npc.id):
		_shop_menu.open(Shop.new(_profile, _shop_defs[npc.id], _local_look()))


## Un achat chez un boutiquier : une nouvelle tenue est appliquée, sauvegardée et envoyée à l'équipage.
func _on_purchase(result: Dictionary) -> void:
	if bool(result.get("ship_changed", false)):
		var next_ship := str(result["ship"])
		if _ship == null or next_ship == _ship.ship_name:
			return
		if _net.active:   # un équipage ne change pas de bateau en pleine partie : ce sera pour la prochaine sortie
			_say("Tu prendras ce bateau à ta prochaine partie.", 4.5)
			return
		_shop_menu.close()
		_restart = {"ship": next_ship, "profile": _profile}
		get_tree().reload_current_scene.call_deferred()
		return
	if bool(result.get("skin_changed", false)):
		if _is_client():
			_say("Ces couleurs seront celles de ton bateau quand tu seras l'hôte.", 4.5)
		else:
			_ship_skin = ShipSkin.sanitize(_profile.ship_skin)
			ShipSkin.apply(_ship, _ship_skin)
			_net.broadcast_skin()
		return
	if not bool(result.get("look_changed", false)):
		return
	_my_look = PirateLook.sanitize(_shop_menu.shop.look)
	if _profile.persistent:   # --fresh (essais) ne touche jamais à la vraie apparence sauvegardée
		PirateLook.save(_my_look)
	_sprite.set_look(_my_look)
	_net.broadcast_look()


## Remet à jour ce qu'on voit des voies d'eau (repères sur la coque, trous dans la cale) quand elles changent.
func _refresh_hull_visuals() -> void:
	if _hold == null:
		return
	if _hull.leaks != _shown_leaks or _hull.patched != _shown_patched:
		_shown_leaks = _hull.leaks
		_shown_patched = _hull.patched
		_hold.set_leaks(_hull.leaks, _hull.patched)
		for s in _hull_marks.size():
			(_hull_marks[s] as Node3D).visible = _hull.has_leak(s)
	_hold.set_water(_hull.fill())


func _is_authority() -> bool:
	return not (_net != null and _net.active and not _net.is_host)


## Entre dans la cale par l'écoutille (en fondu). `instant` : sans fondu (tests).
func _enter_hold(instant: bool = false) -> void:
	if _loc != Loc.SHIP or _fade_busy:
		return
	_mode = Mode.WALK
	# (ce qu'on porte monte et descend avec nous : boulet, planche ou trésor)
	_transition(func() -> void:
		_loc = Loc.HOLD
		_hpos = _hold_layout.spawn_pos()
		_prev_hpos = _hpos
		_set_hold_view(true)
		_snap_camera(), instant)


## Remonte sur le pont, à côté de l'écoutille.
func _leave_hold(instant: bool = false) -> void:
	if _loc != Loc.HOLD:
		return
	if _fade_busy and not instant:
		return
	# (ce qu'on porte monte et descend avec nous)
	_transition(func() -> void:
		_loc = Loc.SHIP
		_ppos = _ship.nearest_walkable(_ship.hatch_pos() + Vector2(0.0, 1.05))
		_prev_ppos = _ppos
		_set_hold_view(false)
		_snap_camera(), instant)


## Fondu au noir, `change` pendant l'écran noir, retour de l'image.
func _transition(change: Callable, instant: bool) -> void:
	if instant or _fade == null:
		change.call()
		return
	_fade_busy = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.16)
	tw.tween_callback(change)
	tw.tween_property(_fade, "color:a", 0.0, 0.2)
	tw.tween_callback(func() -> void: _fade_busy = false)


## Bascule la vue entre le pont (le monde) et la cale : dans la cale on ne voit que la cale, plus sombre.
func _set_hold_view(in_hold: bool) -> void:
	_hold.visible = in_hold
	_ship.visible = not in_hold
	_world_fixed.visible = not in_hold
	var holder: Node3D = _hold if in_hold else _ship
	if _sprite.get_parent() != holder:
		_sprite.reparent(holder, false)
	if _blob.get_parent() != holder:
		_blob.reparent(holder, false)
	if in_hold:
		if _env_saved.is_empty():
			_env_saved = {"bg": _env.background_color, "amb": _env.ambient_light_energy, "sun": _sun.light_energy}
		_env.background_color = Color(0.03, 0.025, 0.04)
		_env.ambient_light_energy = float(_env_saved["amb"]) * 0.62
		_sun.light_energy = float(_env_saved["sun"]) * 0.5
	elif not _env_saved.is_empty():
		_env.background_color = _env_saved["bg"]
		_env.ambient_light_energy = _env_saved["amb"]
		_sun.light_energy = _env_saved["sun"]


## Ce qu'on porte est reposé en changeant d'étage.
## Je lâche ce que je porte. `keep_treasure` : un trésor reste dans mes mains (descendre à la cale, nager).
func _drop_carried(keep_treasure: bool = false) -> void:
	if keep_treasure and _carry_kind == "treasure":
		return
	_carrying = false
	_carry_kind = ""
	_carry_item = ""
	_ball_icon.visible = false
	_plank_icon.visible = false
	if _treasure_icon != null:
		_treasure_icon.queue_free()
		_treasure_icon = null


## Je prends en main un boulet ou une planche (« ball », « plank »).
func _start_carry(kind: String) -> void:
	_carrying = true
	_carry_kind = kind
	_ball_icon.visible = kind == "ball"
	_plank_icon.visible = kind == "plank"


## Je prends en main un trésor : sa maquette flotte au-dessus de ma tête.
func _pick_up_treasure(id: String) -> void:
	if not Treasure.exists(id):
		return
	_drop_carried()
	_carrying = true
	_carry_kind = "treasure"
	_carry_item = id
	_treasure_icon = Treasure.make_icon(id)
	_treasure_icon.scale = Vector3.ONE * GameConfig.CARRY_TREASURE_SCALE
	_treasure_icon.position = Vector3(0.0, 2.25, 0.0)
	_sprite.add_child(_treasure_icon)
	_say("%s : %d or. Rapporte-le dans le coffre du capitaine (cabine), puis au receleur sur le quai" % [Treasure.name_of(id), Treasure.value_of(id)], 5.0)


# ------------------------------------------------------------------ chocs


## Hôte (ou solo) : un choc ouvre `count` voies d'eau autour de (bx, side) et prévient tout l'équipage.
func apply_hit(kind: int, bx: float, side: int, count: int) -> void:
	if _ship == null or count <= 0:
		return
	var opened := _hull.add_leaks(bx, side, count)
	_impact_cd = _hull.impact_cooldown
	_refresh_hull_visuals()
	if _net.active:
		_net.broadcast_hit(kind, bx, side, opened.size())
	else:
		hit_visual(kind, bx, side, opened.size())


## Chez tout le monde : secousse, éclats de bois, message.
func hit_visual(kind: int, bx: float, side: int, opened: int) -> void:
	if _ship == null:
		return
	_shake_t = 0.4
	var at := _ship.to_global(Vector3((bx + _ship.shift) * ShipModel.SCALE, _ship.deck_height(bx) - 0.6,
			-float(side) * _ship.half_width(bx) * ShipModel.SCALE))
	_ball_sound("hull_hit", at)   # boulet ou récif : le bois qui éclate (chez tous)
	_music_heat = minf(_music_heat + GameConfig.MUSIC_HIT_HEAT, 1.0)   # on prend des coups : la musique de combat se corse
	for k in 12:
		var chip := _make_ball(0.07, Color(0.82, 0.64, 0.40))
		(chip.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_world_fixed.add_child(chip)
		chip.global_position = at
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.6, 1.6), -float(side) * randf_range(0.2, 1.3)).normalized()
		var tw := chip.create_tween()
		tw.set_parallel(true)
		tw.tween_property(chip, "position", chip.position + dir * randf_range(1.2, 2.6) + Vector3(0, -0.9, 0), 0.7)
		tw.tween_property(chip, "scale", Vector3.ZERO, 0.7)
		tw.chain().tween_callback(chip.queue_free)
	_splash(_world_fixed.to_local(Vector3(at.x, SEA_Y + 0.05, at.z)))
	var what := {HIT_BALL: "Boulet", HIT_ROCK: "Récif", HIT_WALL: "Choc contre le quai"}.get(kind, "Choc") as String
	var where := "bâbord" if side > 0 else "tribord"
	if opened > 0:
		_say("%s ! Voie d'eau à %s — descends à la cale (E sur l'écoutille) avec une planche" % [what, where], 4.5)
	else:
		_say("%s ! La coque tient" % what, 2.5)


## Vrai si l'eau est libre en `p` (ni île, ni quai, ni récif, avec de la marge) : où un bateau ennemi peut naviguer.
func _water_free(p: Vector2) -> bool:
	if not _land.is_over_water(p) or Land.hits_land([p]):
		return false
	if _islands.island_at(p, 14.0) >= 0:
		return false
	return _rocks.hit([p]).x < 0


## Hôte : un canon ennemi tire (le boulet part chez tout le monde).
func _on_enemy_fire(id: int, idx: int, start: Vector3, vel: Vector3) -> void:
	if _net.active:
		_net.broadcast_enemy_fire(id, idx, start, vel)
	else:
		apply_enemy_fire(id, idx, start, vel)


## Chez tout le monde : le canon `idx` de l'ennemi `id` tire. Seul l'hôte décide si le boulet touche notre coque.
func apply_enemy_fire(id: int, idx: int, start: Vector3, vel: Vector3) -> void:
	_fleet.muzzle_effect(id, idx)
	_cannon_boom(_world_fixed.to_global(start))
	var ball := _make_ball(0.18, Color(0.10, 0.10, 0.14))
	_world_fixed.add_child(ball)
	ball.position = start
	_projectiles.append({"node": ball, "vel": vel, "age": 0.0, "enemy": true, "src": id})
	var puff := _make_ball(0.35, Color(0.85, 0.85, 0.88))
	var pm := puff.material_override as StandardMaterial3D
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world_fixed.add_child(puff)
	puff.position = start
	var pt := puff.create_tween()
	pt.set_parallel(true)
	pt.tween_property(puff, "scale", Vector3.ONE * 3.0, 1.0)
	pt.tween_property(pm, "albedo_color:a", 0.0, 1.0).from(0.7)
	pt.chain().tween_callback(puff.queue_free)


## Hôte : un ennemi coulé lâche son butin (il flotte, ramassable à la nage ou au grappin).
func _on_enemy_loot(kind: String, pos: Vector2, vel: Vector2) -> void:
	_loot.spawn(kind, pos, 480.0, Vector2.INF, vel)


func _on_enemy_sunk(_id: int, ship_name: String) -> void:
	for crew_id in _crew_ids():
		_give_rep(int(crew_id), int(Reputation.gain("enemy_ship")), "bateau ennemi coulé")
	_notify_all("%s coulé ! Son butin flotte à la surface : nage jusqu'à lui ou lance le grappin" % ship_name)


func fleet_net_state() -> Array:
	return _fleet.net_state()


func apply_fleet_state(s: Array) -> void:
	_fleet.apply_net(s)


## Boulet ennemi tiré vers le bateau (essai : --enemy-fire=secondes ; plus tard, les bateaux adverses).
func spawn_enemy_ball(from_side: int) -> void:
	if _ship == null:
		return
	var travel := 1.1
	var fwd := _sim.forward()
	var target := _ship.global_position + Vector3(fwd.x, 0.0, fwd.y) * _sim.speed * travel + Vector3(0, 0.1, 0)
	var side_dir := _ship.global_transform.basis * Vector3(0.0, 0.0, -float(from_side))
	var start := target + side_dir.normalized() * 24.0 + Vector3(0, 3.5, 0)
	var d := target - start
	var vel := Vector3(d.x / travel, (d.y + 8.0 * travel * travel) / travel, d.z / travel)
	var ball := _make_ball(0.16, Color(0.10, 0.10, 0.14))
	_world_fixed.add_child(ball)
	ball.global_position = start
	_projectiles.append({"node": ball, "vel": vel, "age": 0.0, "enemy": true})


## Hôte : un boulet ennemi touche-t-il la coque ? Renvoie vrai (et abîme le bateau) si oui.
func _ball_hits_hull(ball_pos: Vector3) -> bool:
	if not _is_authority():
		return false
	var loc := _ship.to_local(ball_pos)
	var bx := loc.x / ShipModel.SCALE - _ship.shift
	var by := -loc.z / ShipModel.SCALE
	if absf(bx) > _ship.length * 0.5 or absf(by) > _ship.half_width(bx) + 0.12:
		return false
	if loc.y < -1.7 or loc.y > _ship.deck_height(bx) + 0.6:
		return false
	apply_hit(HIT_BALL, bx, 1 if by >= 0.0 else -1, _hull.cannon_leaks)
	return true


## Le bateau s'arrête contre le quai ou un récif : on essaie de glisser, sinon on revient en arrière. Un choc
## assez fort ouvre des voies d'eau.
func _collide_ship_with_land(prev_pos: Vector2, prev_yaw: float) -> void:
	if _ship == null:
		return
	var touch := _touch(_sim.position, _sim.yaw)
	if touch.is_empty():
		return
	var impact_speed := absf(_sim.speed)
	if _is_authority() and _impact_cd <= 0.0:
		var count := _hull.leaks_for_speed(impact_speed)
		if count > 0:
			apply_hit(int(touch["kind"]), float(touch["bx"]), int(touch["side"]), count)
	var np := _sim.position
	var yaw := _sim.yaw
	var options: Array = [Vector2(np.x, prev_pos.y), Vector2(prev_pos.x, np.y), prev_pos]
	for o: Vector2 in options:
		if _touch(o, yaw).is_empty():
			_sim.position = o
			_sim.speed *= 0.5
			return
	if not _touch_enemy_ship(prev_pos, prev_yaw).is_empty():
		return   # on se touchait déjà (un bateau ennemi vient de nous aborder) : on peut s'en dégager au lieu de rester collé
	_sim.position = prev_pos
	_sim.yaw = prev_yaw
	_sim.speed = 0.0


## Ce que la coque touche à cette position : {} si rien, sinon {kind, bx, side}.
func _touch(pos: Vector2, yaw: float) -> Dictionary:
	if not _land.walk_rects.is_empty():
		var pts := _ship.hull_points_world(pos, yaw)
		var i := Land.hit_index(pts)
		if i >= 0:
			var info := _ship.contour_hit_info(i)
			return {"kind": HIT_WALL, "bx": info["bx"], "side": info["side"]}
	if not _islands.islands.is_empty():
		var ii := _islands.ship_hit_index(_ship.hull_points_world(pos, yaw))
		if ii >= 0:
			var iinfo := _ship.contour_hit_info(ii)
			return {"kind": HIT_WALL, "bx": iinfo["bx"], "side": iinfo["side"]}
	var enemy_touch := _touch_enemy_ship(pos, yaw)
	if not enemy_touch.is_empty():
		return enemy_touch
	if not _rocks.rocks.is_empty():
		var h := _rocks.hit(_ship.hull_points_dense(pos, yaw))
		if h.x >= 0:
			var info := _ship.dense_hit_info(h.y)
			var side := int(info["side"])
			if side == 0:
				side = 1 if (h.x % 2 == 0) else -1
			return {"kind": HIT_ROCK, "bx": info["bx"], "side": side}
	return {}


## Les bateaux ennemis sont solides : si ma coque (en `pos`, cap `yaw`) en touche un, {kind, bx, side} comme _touch, sinon {}.
## On teste mes points de contour dans leur coque, et les leurs dans la mienne (deux étraves qui se croisent).
func _touch_enemy_ship(pos: Vector2, yaw: float) -> Dictionary:
	for es: Dictionary in _fleet.ships:
		var model := es.get("model") as ShipModel
		if model == null or es["state"] == "sinking":
			continue
		var esim: ShipSim = es["sim"]
		if esim.position.distance_to(pos) > (model.length + _ship.length) * ShipModel.SCALE * 0.6:
			continue   # trop loin pour se toucher
		var mine := _ship.hull_points_world(pos, yaw)
		for i in mine.size():
			if model.contains_world(esim.position, esim.yaw, mine[i]):
				var info := _ship.contour_hit_info(i)
				return {"kind": HIT_WALL, "bx": info["bx"], "side": info["side"]}
		for p: Vector2 in model.hull_points_world(esim.position, esim.yaw):
			if _ship.contains_world(pos, yaw, p):
				var rel := p - pos
				var local := Basis(Vector3.UP, -yaw) * Vector3(rel.x, 0.0, rel.y)
				return {"kind": HIT_WALL, "bx": local.x / ShipModel.SCALE - _ship.shift, "side": 1 if local.z <= 0.0 else -1}
	return {}


## Un bateau ennemi en `pos`/`yaw` toucherait-il le mien ? (Le bateau ennemi s'arrête alors : voir EnemyFleet.blocked_by.)
func _enemy_would_hit_player(model: ShipModel, pos: Vector2, yaw: float) -> bool:
	for p: Vector2 in model.hull_points_world(pos, yaw):
		if _ship.contains_world(_sim.position, _sim.yaw, p):
			return true
	for p: Vector2 in _ship.hull_points_world(_sim.position, _sim.yaw):
		if model.contains_world(pos, yaw, p):
			return true
	return false


## Hôte : la cale est pleine, le bateau coule. Remorqué au port, remis à neuf.
func _sink_ship() -> void:
	_grap_state = 0
	_hull.reset()
	_sim.position = _spawn_pos
	_sim.yaw = _spawn_yaw
	_sim.speed = 0.0
	_sim.sail_level = 0
	_sim.sail_open = 0.0
	_sim.rudder = 0.0
	_sim.rudder_target = 0.0
	_sim.anchored = false
	_refresh_hull_visuals()
	if _net.active:
		_net.broadcast_sunk()
	else:
		sunk_visual()


## Hôte : le bateau est ramené au port (sans toucher à la coque) : quand on est vraiment coincé.
func _tow_to_port() -> void:
	_grap_state = 0
	_sim.position = _spawn_pos
	_sim.yaw = _spawn_yaw
	_sim.speed = 0.0
	_sim.change_sails(-ShipSim.SAIL_LEVELS)
	_sim.rudder = 0.0
	_sim.rudder_target = 0.0
	_sim.anchored = false
	_stuck_t = 0.0
	_notify_all("Le bateau a été ramené au port")


## Un message pour tout l'équipage (l'hôte le diffuse, les autres l'affichent).
func _notify_all(text: String) -> void:
	show_notice(text)
	if _net != null and _net.active and _net.is_host:
		_net.broadcast_notice(text)


func show_notice(text: String) -> void:
	_say(text, 4.0)


## Chez tout le monde : le bateau a coulé.
func sunk_visual() -> void:
	_say("Le bateau a coulé ! Remorqué au port, la coque est remise à neuf", 6.0)
	_shake_t = 0.6
	if _loc == Loc.HOLD:
		_leave_hold(true)


# ------------------------------------------------------------------ boucle


## Ouvre la carte des mers (sur la table de la cabine).
func _open_chart() -> void:
	_chart.discovered = _profile.discovered
	_chart.destination = _destination
	_chart.ship_pos = _sim.position
	_chart.ship_dir = Vector2(cos(_sim.yaw), -sin(_sim.yaw))
	_chart.open()


# ------------------------------------------------------------------ îles : combat, coffres, repérage

## Les joueurs à terre que les ennemis peuvent viser : [{id, pos}].
func _land_targets() -> Array:
	var out: Array = []
	if _loc == Loc.LAND and _hp > 0:
		out.append({"id": _my_id(), "pos": _lpos})
	for id in _remotes:
		var r: Dictionary = _remotes[id]
		if int(r["loc"]) == 1:
			out.append({"id": id, "pos": r["pos"]})
	return out


func _update_islands(delta: float) -> void:
	if _islands.islands.is_empty():
		return
	_atk_cd = maxf(_atk_cd - delta, 0.0)
	_inv_t = maxf(_inv_t - delta, 0.0)
	for s in BerryBook.SLOTS:
		_spell_cd[s] = maxf(_spell_cd[s] - delta, 0.0)
	_sync_outposts(delta)
	if _is_authority():
		for ev: Dictionary in _islands.step(delta, _land_targets()):
			var tid: int = ev["target"]
			if tid == _my_id():
				apply_hurt(int(ev["damage"]), ev["from"])
			elif _net.active:
				_net.send_hurt(tid, int(ev["damage"]), ev["from"])
	_islands.update_visuals(delta, _is_authority())
	if _is_authority() and not _args.has("no-gen-islands"):
		_gen_t -= delta
		if _gen_t <= 0.0:
			_gen_t = 0.4
			_islands.ensure_around(_sim.position if _loc != Loc.LAND and _loc != Loc.SWIM else _lpos)
	_check_quest_arrival()
	_islands.update_berries(delta, _lpos if _loc == Loc.LAND else Vector2(1.0e6, 1.0e6), _is_authority())
	# repérage : une île à moins de reveal_range apparaît sur la carte
	for i in _islands.island_in_sight(_sim.position):
		var isl: Dictionary = _islands.islands[i]
		if not (isl["id"] in _profile.discovered):
			_profile.discovered.append(isl["id"])
			_profile.save()
			_say("Terre en vue : %s !" % isl["name"], 4.0)
	# à bord, on se soigne peu à peu
	if _loc == Loc.SHIP and _hp < _hp_max:
		_heal_t += delta
		if _heal_t >= 3.0:
			_heal_t = 0.0
			_hp += 1
	# textes qui flottent
	var keep: Array = []
	for p: Dictionary in _popups:
		p["t"] = float(p["t"]) + delta
		var node := p["node"] as Label3D
		if float(p["t"]) >= 1.3:
			node.queue_free()
			continue
		node.position.y += delta * 0.9
		node.modulate.a = clampf(2.0 - float(p["t"]) * 1.5, 0.0, 1.0)
		keep.append(p)
	_popups = keep
	_update_island_hud(delta)


func _update_island_hud(delta: float) -> void:
	var h := _island_hud
	h.hp = _hp
	h.hp_max = _hp_max
	h.show_hearts = _loc == Loc.LAND or _loc == Loc.SWIM or _loc == Loc.RAFT or _hp < _hp_max   # la vie reste affichée à la nage et sur le radeau
	h.hearts_y = 108.0 if _loc == Loc.LAND else 108.0 + SailHud.SIZE + 40.0   # hors de la terre, le cadran du vent occupe le haut à gauche
	h.blink = _inv_t > 0.0
	h.show_spells = _loc == Loc.LAND and _profile.berry != ""
	if h.show_spells:
		h.berry_name = BerryBook.berry_name(_profile.berry)
		h.berry_color = BerryBook.color_of(_profile.berry)
		var slots: Array = []
		for s in BerryBook.SLOTS:
			var spell := BerryBook.spell(_profile.berry, s)
			var known := BerryBook.spell_key(_profile.berry, s) in _profile.known_spells
			slots.append({"label": str(spell.get("name", "?")) if known else "???", "cd": _spell_cd[s] / maxf(_spell_cd_max[s], 0.01) if _spell_cd[s] > 0.0 else 0.0})
		h.spells = slots
	h.flash = maxf(h.flash - delta * 2.5, 0.0)
	if _chart.is_open():
		_chart.ship_pos = _sim.position
		_chart.ship_dir = Vector2(cos(_sim.yaw), -sin(_sim.yaw))
		_chart.enemies = _fleet.revealed()   # lot 5 (6.7) : la même liste chez tout l'équipage (état de la flotte)
	var has_goal := _destination >= 0 and _destination < _islands.islands.size()
	h.dest_visible = has_goal and not _chart.is_open()
	# la boussole que mon pirate tient en main montre le même cap (point bleu sur l'anneau)
	var goal_vec := (_chart.shown_pos(_destination) - (_lpos if _loc == Loc.LAND else _sim.position)) if has_goal else Vector2.ZERO
	if not has_goal and _loc == Loc.LAND:
		goal_vec = _nearest_closed_chest_vec()   # sur une île sans cap choisi : la boussole désigne le coffre fermé le plus proche
	_sprite.compass_goal = goal_vec
	if h.dest_visible:
		var target := _chart.shown_pos(_destination)
		var from := _lpos if _loc == Loc.LAND else _sim.position
		var d := target - from
		h.dest_angle = atan2(d.x, -d.y)
		h.dest_dist = d.length()
		var known: bool = _islands.islands[_destination]["id"] in _profile.discovered
		h.dest_name = str(_islands.islands[_destination]["name"]) if known else "Terre inconnue"


## Une direction à terre (monde x/z) en vecteur d'écran (x à droite, y vers le bas) : la profondeur est écrasée par l'inclinaison de la caméra.
func _screen_of_face(face: Vector2) -> Vector2:
	return Vector2(face.x, face.y * sin(deg_to_rad(_elev_deg)))


## Direction (monde x/z) du coffre encore fermé le plus proche sur l'île où l'on se trouve, ou zéro s'il n'y en a plus.
func _nearest_closed_chest_vec() -> Vector2:
	var i := _islands.island_at(_lpos, 8.0)
	if i < 0:
		return Vector2.ZERO
	var best := Vector2.ZERO
	var best_d := INF
	for ch_id: int in _islands.islands[i]["chests"]:
		var ch: Dictionary = _islands.chests[ch_id]
		if ch["open"]:
			continue
		var v: Vector2 = (ch["pos"] as Vector2) - _lpos
		if v.length() < best_d:
			best_d = v.length()
			best = v
	return best


## Tourne le pirate vers le point de l'écran `click` : la direction va de ses pieds (là où il est affiché, caméra, zoom et
## secousse compris) au pointeur ; la profondeur est écrasée par l'inclinaison de la caméra, on la rétablit.
func _aim_at_click(click: Vector2) -> void:
	var origin := get_viewport().get_visible_rect().size * 0.5   # (le pirate est au centre de l'écran, à défaut de mieux)
	if _cam != null and _container != null:
		var feet := _cam.unproject_position(_land_point(_lpos, _lh))
		origin = _container.position + feet * float(_factor)
	var d := click - origin
	if d.length() > 4.0:
		_face = Vector2(d.x, d.y / sin(deg_to_rad(_elev_deg))).rotated(-_cam_yaw).normalized()   # (écran -> monde, caméra tournée comprise)


## Coup de sabre vers `_face` : le croissant s'affiche tout de suite, l'hôte décide qui est touché.
func _try_attack(secondary: bool = false) -> void:
	if _act != null:
		_cancel_action()   # frapper coupe l'action en cours
		return
	if _is_down() or _is_dead():
		return
	if _loc == Loc.SWIM and _atk_cd <= 0.0 and not _sharks.is_empty():   # lot 4 (5.7) : à la nage, un coup de sabre chasse un requin
		_atk_cd = 0.6
		if not _scare_shark():
			_splash_burst(_lpos)
		return
	if _loc != Loc.LAND or _atk_cd > 0.0 or _hp <= 0 or _dialog.is_open() or _shop_menu.is_open() or _chart.is_open() or _jump_wind > 0.0:
		return
	if _carrying:   # lot 2 (2.4) : les deux mains sont prises
		_say("Les mains prises : G pour poser ce que tu portes, puis défends-toi", 2.5)
		return
	var wid: String = _profile.secondary_weapon() if secondary else _profile.weapon   # clic gauche : arme principale ; clic droit : secondaire
	if wid != _profile.weapon:
		_hand_wid = wid   # l'arme du clic droit passe dans la main le temps de servir
		_hand_t = 2.0
		_sync_held_weapon()   # l'arme est dans la main avant que le geste commence
	if Weapons.is_gun(wid):
		_try_shoot(wid)
		return
	_atk_cd = float(_islands.player_cfg.get("swing_cooldown", 0.45))
	_sprite.play_action("slash_sabre", _screen_of_face(_face))   # le coup de sabre : bras levé, coup, retour
	_islands.spawn_slash(_lpos, _face)
	var sk := WeaponSkins.def_of("sabre", _profile.skin_of("sabre"))
	WeaponFx.slash(_world_fixed, _lpos, _face, sk, _lh + 0.95)
	_send_action("slash", _held_code(), _lpos, _face)
	if _atmo != null:
		_atmo.on_swing(_lpos, _face)   # les palmiers et buissons devant frémissent
	if _is_authority():
		_resolve_swing(_my_id(), _lpos, _face)
	else:
		_net.send_swing(_lpos, _face)


## Un tir de l'arme à feu `wid` vers là où je regarde : la munition part tout de suite, l'éclair et les traînées aussi ;
## l'hôte décide ce qui est touché.
func _try_shoot(wid: String) -> void:
	var def := Weapons.get_def(wid)
	var ammo := Weapons.ammo_of(wid)
	if not _profile.take_ammo(ammo):
		_say("Plus de %s : Magasin Général (Mère Pétronille)" % Weapons.ammo_label(ammo), 3.0)
		_atk_cd = 0.4
		return
	_atk_cd = float(def.get("cooldown", 1.0))
	var dir := _face.normalized()
	_sprite.play_action("shoot_" + wid, _screen_of_face(dir))   # le pirate épaule, tire (recul) et reprend sa garde
	_shot_fx(_lpos, dir, def, INF, WeaponSkins.def_of(wid, _profile.skin_of(wid)))
	_send_action("shot", "%s|%s" % [wid, _profile.skin_of(wid)], _lpos, dir)
	_shake_t = maxf(_shake_t, 0.1)
	if _is_authority():
		_resolve_shot(_my_id(), wid, _lpos, dir)
	else:
		_net.send_shot(wid, _lpos, dir)


## Hôte : le tir de `peer` touche-t-il quelqu'un ? Mêmes règles que le sabre pour l'or et les tonneaux.
func _resolve_shot(peer: int, wid: String, pos: Vector2, dir: Vector2) -> void:
	var def := Weapons.get_def(wid)
	if def.is_empty() or not Weapons.is_gun(wid):
		return
	for hit: Dictionary in _islands.shoot(pos, dir.normalized(), def):
		if int(hit["gold"]) > 0:
			_give_loot(peer, int(hit["gold"]), hit["at"])
		if bool(hit.get("prop", false)):
			_spawn_prop_loot(str(hit["kind"]), hit["at"])


func apply_shot(peer: int, wid: String, pos: Vector2, dir: Vector2) -> void:
	_resolve_shot(peer, wid, pos, dir)


## Je viens de faire une action visible (coup de sabre, tir, pouvoir) : les autres joueurs la voient aussi.
func _send_action(kind: String, arg: String, pos: Vector2, dir: Vector2) -> void:
	if _net != null and _net.active:
		_net.send_action(kind, arg, pos, dir)


## Une action d'un autre joueur (reçue par le réseau) : son pirate joue l'animation et l'effet apparaît chez moi.
## Les dégâts, eux, sont décidés par l'hôte (apply_swing, apply_shot, apply_cast).
func apply_action(peer: int, kind: String, arg: String, pos: Vector2, dir: Vector2) -> void:
	if peer == _my_id() or not _remotes.has(peer) or _islands == null:
		return
	var r: Dictionary = _remotes[peer]
	var sprite := r["sprite"] as PirateSprite
	var screen := _screen_of_face(dir)
	var height: float = float(r.get("lh", 0.0))
	if _args.has("log"):
		print("[action] joueur %d : %s %s vers %s" % [peer, kind, arg, dir])
	match kind:
		"ball_hit":   # l'hôte a vu un boulet toucher un ennemi (bateau ou mob) : le choc s'entend chez tous
			_ball_sound("hull_hit", _world_fixed.to_global(Vector3(pos.x, SEA_Y + 0.6, pos.y)))
		"act", "act_end":   # lot 2 : une action longue commence ou finit
			_remote_act(peer, kind, arg)
		"down", "up", "dead", "water":   # lot 4 : son état (à terre, relevé, mort, temps dans l'eau)
			_remote_state_event(peer, kind, arg)
		"slash":
			var sl := arg.split("|")
			var ssk := WeaponSkins.def_of("sabre", sl[1] if sl.size() > 1 else WeaponSkins.CLASSIC)
			sprite.play_action("slash_sabre", screen)
			_islands.spawn_slash(pos, dir)
			WeaponFx.slash(_world_fixed, pos, dir, ssk, height + 0.95)
		"shot":
			var sp := arg.split("|")
			var def := Weapons.get_def(sp[0])
			if def.is_empty():
				return
			sprite.play_action("shoot_" + sp[0], screen)
			_shot_fx(pos, dir, def, height, WeaponSkins.def_of(sp[0], sp[1] if sp.size() > 1 else WeaponSkins.CLASSIC))
		"cast":
			var parts := arg.split("|")
			if parts.size() < 2:
				return
			var spell := BerryBook.spell(parts[0], int(parts[1]))
			if spell.is_empty():
				return
			sprite.play_action("cast", screen)
			_islands.spawn_fx(spell, pos, dir, BerryBook.color_of(parts[0]))


## Éclair de bouche, traînées de plomb et fumée d'un tir. `height` : la hauteur du sol du tireur (celui qui tire, sinon moi).
func _shot_fx(origin: Vector2, dir: Vector2, def: Dictionary, height: float = INF, skin_def: Dictionary = {}) -> void:
	var y := (_lh if height == INF else height) + 0.95
	WeaponFx.shot(_world_fixed, origin, dir, int(def.get("pellets", 1)), float(def.get("range", 10.0)), float(def.get("spread", 0.0)),
			Color.html(str(def.get("color", "#ffe9a8"))), skin_def, y)


## X : l'arme suivante du sac.
func _cycle_weapon() -> void:
	_profile.set_main_weapon(Weapons.next_owned(_profile.weapon, _profile.weapons))
	_profile.save()
	_hand_wid = ""
	_say("Arme principale (clic gauche) : %s" % Weapons.weapon_name(_profile.weapon), 2.0)


# ------------------------------------------------------------------ sac du pirate

## Les lignes du sac : armes, baies gardées, provisions.
func _inventory_rows() -> Array:
	var rows: Array = [{"head": true, "label": "Armes"}]
	for id in Weapons.order():
		if not (id in _profile.weapons):
			continue
		var def := Weapons.get_def(str(id))
		var held: bool = _profile.weapon == str(id)
		var second: bool = _profile.secondary_weapon() == str(id) and not held
		var right := "principale (clic gauche)" if held else ("secondaire (clic droit)" if second else "E : principale, Q : secondaire")
		var ammo := Weapons.ammo_of(str(id))
		if ammo != "":
			right += "   (%d %s)" % [_profile.ammo_count(ammo), Weapons.ammo_label(ammo)]
		rows.append({"kind": "weapon", "id": str(id), "label": str(def.get("name", id)), "right": right, "enabled": not held,
				"desc": str(def.get("desc", ""))})
		var owned_skins := _profile.skins_for(str(id))
		if owned_skins.size() > 1:   # des skins gagnés ou achetés : une ligne pour changer l'apparence de cette arme
			var worn := _profile.skin_of(str(id))
			rows.append({"kind": "wskin", "id": str(id), "label": "      Apparence : %s" % WeaponSkins.skin_name(str(id), worn),
					"right": "%s   (E : changer)" % WeaponSkins.rarity_label(str(id), worn), "enabled": true,
					"desc": str(WeaponSkins.def_of(str(id), worn).get("desc", "L'arme d'origine."))})
	rows.append({"head": true, "label": "Baies des dieux"})
	if _profile.berries.is_empty():
		rows.append({"kind": "none", "id": "", "label": "(aucune baie dans le sac)", "right": "", "enabled": false,
				"desc": "Cueille une baie sur une île : elle reste dans ton sac, tu la manges quand tu veux. Elles sont rarissimes."})
	var berry_ids: Array = _profile.berries.keys()
	berry_ids.sort()
	for id in berry_ids:
		var held_now: String = _profile.berry
		rows.append({"kind": "berry", "id": str(id), "label": "%s  x%d" % [BerryBook.berry_name(str(id)), int(_profile.berries[id])],
				"right": "manger" + (" (remplace %s)" % BerryBook.berry_name(held_now) if held_now != "" else ""), "enabled": true,
				"desc": "Quatre pouvoirs inconnus, touches 1 à 4 à terre. Une seule baie à la fois : l'ancienne retourne dans ton sac."})
	if _profile.berry != "":
		rows.append({"kind": "none", "id": "", "label": "Pouvoir actuel : %s" % BerryBook.berry_name(_profile.berry), "right": "", "enabled": false, "desc": ""})
	rows.append({"head": true, "label": "Fabrication"})
	for cid in Crafting.order():
		var recipe := str(cid)
		var lack := Crafting.missing(_profile, recipe)
		var need := "%s  (il t'en manque %d)" % [Crafting.cost_text(recipe), int(lack.get("plank", 0))] if not lack.is_empty() \
				else "%s  (E : fabriquer)" % Crafting.cost_text(recipe)
		rows.append({"kind": "craft", "id": recipe, "label": Crafting.recipe_name(recipe), "right": need, "enabled": lack.is_empty(),
				"desc": str(Crafting.get_def(recipe).get("desc", ""))})
	rows.append({"head": true, "label": "Provisions"})
	for line: Array in [["Or", _profile.gold], ["Boulets", _profile.balls], ["Planches", _profile.planks],
			["Balles", _profile.bullets], ["Cartouches", _profile.shells]]:
		rows.append({"kind": "none", "id": "", "label": "%s : %d" % [line[0], int(line[1])], "right": "", "enabled": false, "desc": ""})
	if _carry_kind == "treasure":
		rows.append({"kind": "none", "id": "", "label": "Dans tes bras : %s (%d or)" % [Treasure.name_of(_carry_item), Treasure.value_of(_carry_item)],
				"right": "", "enabled": false, "desc": "Rapporte-le dans le coffre du capitaine (cabine), puis vends-le à Corbin."})
	return rows


func _toggle_inventory() -> void:
	if _inventory.is_open():
		_inventory.close()
	elif not (_dialog.is_open() or _shop_menu.is_open() or _chart.is_open() or _pause.is_open()) and _loc != Loc.FLIGHT:
		_inventory.open(_inventory_rows())


## Q sur une arme du sac : elle devient l'arme secondaire (clic droit).
func _on_inventory_alt(kind: String, id: String) -> void:
	if kind != "weapon" or _chest_island >= 0:
		return
	if _profile.weapons.size() < 2:
		_say("Il te faut une deuxième arme pour avoir une arme secondaire", 2.5)
		return
	_profile.set_secondary_weapon(id)
	_profile.save()
	_say("Arme secondaire (clic droit) : %s" % Weapons.weapon_name(_profile.secondary_weapon()), 2.5)
	_inventory.set_rows(_inventory_rows())


func _on_inventory_use(kind: String, id: String) -> void:
	if _chest_island >= 0:   # le panneau montre le coffre d'une cabane
		_on_chest_use(kind, id)
		return
	match kind:
		"weapon":
			_profile.set_main_weapon(id)
			_profile.save()
			_hand_wid = ""
			_say("Arme principale (clic gauche) : %s" % Weapons.weapon_name(id), 2.0)
		"wskin":
			var list := _profile.skins_for(id)
			var nxt := str(list[(list.find(_profile.skin_of(id)) + 1) % list.size()])
			_profile.skin_worn[id] = nxt
			_profile.save()
			_say("%s : %s" % [Weapons.weapon_name(id), WeaponSkins.skin_name(id, nxt)], 2.5)
		"berry":
			_eat_berry(id)
		"craft":
			_inventory.close()
			_craft(id)
			return
	_inventory.set_rows(_inventory_rows())


## Je mange la baie `id` du sac : elle prend la place de celle que je portais, qui retourne dans le sac.
func _eat_berry(id: String) -> void:
	if int(_profile.berries.get(id, 0)) <= 0 or not BerryBook.exists(id):
		return
	var old: String = _profile.berry
	_profile.add_berry(id, -1)
	if old != "" and BerryBook.exists(old):
		_profile.add_berry(old, 1)
	apply_berry_got(id)


## Hôte : le coup de `peer` touche-t-il quelqu'un ? L'or des ennemis vaincus va à celui qui frappe.
func _resolve_swing(peer: int, pos: Vector2, dir: Vector2) -> void:
	for hit: Dictionary in _islands.swing(pos, dir.normalized()):
		if int(hit["gold"]) > 0:
			_give_loot(peer, int(hit["gold"]), hit["at"])
		if bool(hit.get("prop", false)):
			_spawn_prop_loot(str(hit["kind"]), hit["at"])


## Un tonneau ou une caisse vient de casser : planches, boulets, or (et rarement un trésor) jaillissent autour.
func _spawn_prop_loot(kind: String, at: Vector2) -> void:
	for loot_kind in _islands.prop_loot(kind):
		var dest := at + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.7, 1.6)
		_loot.spawn(str(loot_kind), dest, 600.0, at)


func apply_swing(peer: int, pos: Vector2, dir: Vector2) -> void:
	_resolve_swing(peer, pos, dir)


# ------------------------------------------------------------------ baies des dieux et sorts

## Je lance le sort `slot` (0 à 3) de ma baie vers là où je regarde. Le nom du sort n'est révélé qu'à la première fois.
func _try_cast(slot: int) -> void:
	if _profile.berry == "" or _loc != Loc.LAND or _hp <= 0 or _spell_cd[slot] > 0.0 or _dialog.is_open() or _shop_menu.is_open() or _chart.is_open() or _jump_wind > 0.0:
		return
	if _carrying:   # lot 2 (2.4) : les mains prises, pas de pouvoir non plus
		_say("Les mains prises : G pour poser ce que tu portes", 2.5)
		return
	var spell := BerryBook.spell(_profile.berry, slot)
	if spell.is_empty():
		return
	_spell_cd[slot] = float(spell["cd"])
	_spell_cd_max[slot] = float(spell["cd"])
	var key := BerryBook.spell_key(_profile.berry, slot)
	if not (key in _profile.known_spells):
		_profile.known_spells.append(key)
		_profile.save()
		_say("Pouvoir révélé : %s !" % spell["name"], 3.5)
	var origin := _lpos
	_sprite.play_action("cast", _screen_of_face(_face))   # bras ramenés, levés, puis lancés vers l'avant
	_islands.spawn_fx(spell, origin, _face, BerryBook.color_of(_profile.berry))
	_send_action("cast", "%s|%d" % [_profile.berry, slot], origin, _face)
	match str(spell["kind"]):
		"heal":
			var gain := mini(int(spell["amount"]), _hp_max - _hp)
			_hp += gain
			_popup("+%d vie" % gain, _lpos, Color(0.5, 1.0, 0.55))
		"shield":
			_inv_t = maxf(_inv_t, float(spell["secs"]))
		"dash":
			_inv_t = maxf(_inv_t, 0.4)
			var dir := _face.normalized()
			var left := float(spell["dist"])
			while left > 0.0:
				var stp := minf(left, 0.5)
				var r := _land.step(_lpos, dir * stp, _lh)
				var moved := Vector2(r.x, r.y).distance_to(_lpos)
				_lpos = Vector2(r.x, r.y)
				_lh = r.z
				if moved < stp * 0.5:
					break
				left -= stp
	if int(spell.get("damage", 0)) > 0:
		if _is_authority():
			_resolve_cast(_my_id(), spell, origin, _face)
		else:
			_net.send_cast(_profile.berry, slot, origin, _face)


## Hôte : un sort lancé par `peer` touche-t-il quelqu'un ? L'or des ennemis vaincus va au lanceur.
func _resolve_cast(peer: int, spell: Dictionary, pos: Vector2, dir: Vector2) -> void:
	for hit: Dictionary in _islands.cast(spell, pos, dir):
		if int(hit["gold"]) > 0:
			_give_loot(peer, int(hit["gold"]), hit["at"])
		if bool(hit.get("prop", false)):
			_spawn_prop_loot(str(hit["kind"]), hit["at"])


func apply_cast(peer: int, berry: String, slot: int, pos: Vector2, dir: Vector2) -> void:
	var spell := BerryBook.spell(berry, slot)
	if not spell.is_empty():
		_resolve_cast(peer, spell, pos, dir)


## Je cueille la baie `k` (E).
func _pick_berry(k: int) -> void:
	if _is_authority():
		apply_berry_pick(_my_id(), k, _profile.berry, _lpos)
	else:
		_net.send_berry_pick(k, _profile.berry, _lpos)


## Hôte (ou solo) : `peer` mange la baie `spot`. Celle qu'il portait (`old`) tombe à ses pieds.
func apply_berry_pick(peer: int, spot: int, _old: String, _pos: Vector2) -> void:
	var id := _islands.take_berry(spot)
	if id == "":
		return
	_give_item(peer, "b:" + id)   # la baie va dans le sac : on la mange quand on veut (Tab)


## Je viens de manger la baie `id` : elle remplace la mienne, et ses quatre sorts sont à moi (touches 1 à 4).
func apply_berry_got(id: String) -> void:
	if not BerryBook.exists(id):
		return
	_profile.berry = id
	_profile.save()
	for s in BerryBook.SLOTS:
		_spell_cd[s] = 2.0
		_spell_cd_max[s] = 2.0
	_say("Tu manges la %s : quatre pouvoirs s'éveillent (touches 1 à 4)" % BerryBook.berry_name(id), 6.0)
	_islands.spawn_fx({"kind": "nova", "radius": 2.2}, _lpos, _face, BerryBook.color_of(id))


func _give_loot(peer: int, gold: int, at: Vector2) -> void:
	if peer == _my_id():
		apply_loot(gold, at)
	elif _net.active:
		_net.send_loot(peer, gold, at)


func apply_loot(gold: int, at: Vector2) -> void:
	_profile.gold += gold
	_profile.save()
	_popup("+%d or" % gold, at, Color(1.0, 0.85, 0.3))


## Hôte (ou solo) : `n` points de réputation pour `peer`, qui les voit s'ajouter à sa barre.
func _give_rep(peer: int, n: int, why: String) -> void:
	if n <= 0:
		return
	if peer == _my_id():
		apply_rep(n, why)
	elif _net != null and _net.active:
		_net.send_rep(peer, n, why)


## Je gagne `n` points de réputation (`why` : d'où ils viennent) : la barre se remplit en s'animant ; un nouveau rang ouvre une
## bannière qui liste les skins de bateau débloqués (à la voilerie).
func apply_rep(n: int, why: String) -> void:
	var info := _profile.add_reputation(n)
	if info.is_empty():
		return
	_rep_hud.gain(int(info["from"]), int(info["to"]), n)
	if int(info["rank_to"]) > int(info["rank_from"]):
		var unlocked: Array = []
		for r in range(int(info["rank_from"]) + 1, int(info["rank_to"]) + 1):
			for u: Dictionary in ShipSkin.unlocked_at(r):
				unlocked.append("%s (%s)" % [u["label"], ShipSkin.category_label(str(u["cat"])).to_lower()])
		_rep_hud.rank_up(Reputation.rank_name(int(info["rank_to"])), unlocked)
		_say("Nouveau rang : %s !%s" % [Reputation.rank_name(int(info["rank_to"])), "  Skins débloqués à la voilerie." if not unlocked.is_empty() else ""], 5.0)
	else:
		_say("+%d réputation (%s)" % [n, why], 2.5)


func _popup(text: String, at: Vector2, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 40
	l.pixel_size = 0.014
	l.modulate = color
	l.outline_size = 10
	l.outline_modulate = Color(0.1, 0.05, 0.02)
	l.no_depth_test = true
	l.position = Vector3(at.x, 1.9, at.y)
	_world_fixed.add_child(l)
	_popups.append({"node": l, "t": 0.0})


## Un ennemi m'a touché (venu de `from`).
func apply_hurt(damage: int, from: Vector2) -> void:
	if _inv_t > 0.0 or _hp <= 0 or _loc != Loc.LAND or _is_down() or _is_dead():
		return
	_act_hurt = true   # lot 2 : un coup reçu interrompt l'action en cours
	_hp = maxi(_hp - damage, 0)
	_inv_t = float(_islands.player_cfg.get("invulnerable_secs", 1.0))
	_island_hud.flash = 1.0
	_shake_t = 0.3
	var away := _lpos - from
	if away.length() > 0.01:
		var r := _land.step(_lpos, away.normalized() * 0.9, _lh)
		_lpos = Vector2(r.x, r.y)
		_lh = r.z
	if _hp <= 0:
		_go_down()   # lot 4 (5.1) : à terre, et non plus évanoui puis réveillé sur le bateau


## Évanoui : on se réveille sur le pont, soigné.
func _wake_on_ship() -> void:
	_loc = Loc.SHIP
	_mode = Mode.WALK
	_pz = 0.0
	_vz = 0.0
	_lh = 0.0
	var l: Array = _ship.ladders[0]
	_ppos = _ship.nearest_walkable(Vector2(float(l[0]), float(l[1])))
	_hp = _hp_max
	_inv_t = 2.0
	_snap_camera()
	_say("Tu t'es évanoui… tes camarades t'ont ramené à bord", 5.0)


func loot_net_state() -> Array:
	return _loot.net_state()


func apply_loot_state(s: Array) -> void:
	_loot.apply_net(s)


## Je ramasse (en passant dessus) ce qui traîne à portée, à terre ou à la nage : un trésor seulement si mes mains sont libres.
func _update_loot_pickup(delta: float) -> void:
	_loot_cd = maxf(_loot_cd - delta, 0.0)
	if _loot_cd > 0.0 or (_loc != Loc.LAND and _loc != Loc.SWIM) or _loot.count() == 0:
		return
	# lot 2 (2.4) : à terre, un trésor ne se ramasse plus en passant dessus mais avec E (sinon on reprendrait aussitôt celui
	# qu'on vient de poser pour se défendre) ; à la nage, il se ramasse toujours au passage
	var on_land := _loc == Loc.LAND
	var id := _loot.nearest(_lpos, WorldLoot.PICK_RANGE, func(kind: String) -> bool:
		return not kind.begins_with("t:") or (not _carrying and not on_land))
	if id < 0:
		return
	_loot_cd = 0.3
	_request("loot_take", id)


## Hôte : les ennemis des îles proches du bateau ou d'un joueur à terre (le reste reste figé chez les clients, hors de vue).
func islands_net_state() -> Array:
	var points: Array = [_sim.position]
	if _loc == Loc.LAND or _loc == Loc.SWIM:
		points.append(_lpos)
	for id in _remotes:
		var r: Dictionary = _remotes[id]
		if int(r["loc"]) == 1 or int(r["loc"]) >= 5:
			points.append(r["pos"])
	return _islands.net_dynamic(points)


## Hôte : coffres, baies, tonneaux, îles générées (change rarement).
func islands_static_state() -> Array:
	return _islands.net_static()


func apply_islands_state(s: Array) -> void:
	if not _islands.islands.is_empty():
		_islands.apply_dynamic(s)


func apply_islands_static(s: Array) -> void:
	if not _islands.islands.is_empty():
		_islands.apply_static(s)


func _process(delta_raw: float) -> void:
	var delta := minf(delta_raw, 0.05)
	if _ship == null:
		return
	_time += delta
	_hand_t = maxf(_hand_t - delta, 0.0)
	_apply_hud_scale()
	_impact_cd = maxf(_impact_cd - delta, 0.0)
	_bail_cd = maxf(_bail_cd - delta, 0.0)
	if _is_authority():
		_hull.step(delta)
		if _hull.is_sunk():
			_sink_ship()
	_sim.drag = _hull.speed_factor()
	if _is_authority() and not _args.has("no-wind-drift") and not _args.has("wind"):
		_sim.drift_wind(_time)
	_update_zoom(delta)
	_unstick_armed = maxf(_unstick_armed - delta, 0.0)
	if _sim.sail_open > 0.25 and not _sim.anchored and _sim.speed < 0.25:
		_stuck_t += delta
		if _stuck_t > 3.0 and _stuck_t - delta <= 3.0:
			_say("Le bateau semble coincé : touche T (deux fois) ou menu Échap pour le débloquer", 5.0)
	else:
		_stuck_t = 0.0
	_update_player(delta)
	_update_timed_action(delta)
	_update_lot4(delta)
	_update_remote_lot4(delta)
	if _center_label != null:
		_center_label.text = _lot4_center_text()
		var urgent := _is_dead() or (_is_down() and _downed_t < 8.0) or (_loc == Loc.SWIM and _water_t >= GameConfig.DROWN_AFTER - GameConfig.DROWN_WARNING)
		_center_label.modulate.a = (0.65 + 0.35 * sin(_time * 7.0)) if urgent and not _is_dead() else 1.0
	_update_rafts(delta)
	var prev_sim_pos := _sim.position
	var prev_sim_yaw := _sim.yaw
	_sim.step(delta)
	if _is_authority():
		_update_grapple(delta)
	_collide_ship_with_land(prev_sim_pos, prev_sim_yaw)
	_refresh_hull_visuals()
	if _net.active and not _net.is_host:
		_correct_from_host(delta)
	_update_islands(delta)
	_apply_swell(delta)
	_float_ship()
	_ship.set_sail_open(_sim.sail_open)
	_ship.set_sail_trim(_sim.sail_trim)
	_update_helm_wheel(delta)
	_update_wind_feel(delta)
	_place_pirate()
	_update_target(delta)
	_update_aim_line()
	_update_gun_aim(delta)
	_loot.step(delta, _is_authority())
	_update_loot_pickup(delta)
	_update_grapple_visual()
	_update_hook_aim()
	var watching_sails := (_loc == Loc.SHIP or _loc == Loc.CLIMB or _loc == Loc.SWIM) and not _args.has("no-fade")
	_ship.update_sail_fade(_sprite.global_position + Vector3(0.0, 1.0, 0.0), _cam.global_transform.basis.z, watching_sails, delta,
			float(_args.get("sail-fade", "0.3")))
	if _loc == Loc.SWIM:
		_swim_effects(delta)
	_update_building_fade(delta)
	_update_interior()
	_update_npcs(delta)
	_ship.update_cutaway(_loc == Loc.SHIP and _ship.inside_cabin(_ppos))
	var up_mast: bool = _loc == Loc.NEST or (_loc == Loc.CLIMB and _climb.get("kind") == "mast")
	# en haut du mât, ni le mât ni le nid ne cachent le pirate ; derrière un bâtiment rendu transparent, il est
	# dessiné par-dessus (net, pas délavé par le mélange)
	var on_raft := _loc == Loc.RAFT   # sur le radeau, la voile est devant lui : on le dessine par-dessus (voile translucide)
	_sprite.no_depth_test = up_mast or _ghosting or on_raft
	_sprite.render_priority = 5 if _sprite.no_depth_test else 0
	# passé en mélange (et non plus en découpe) pour être dessiné APRÈS le bâtiment ou la voile transparents
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED if (_ghosting or on_raft) else SpriteBase3D.ALPHA_CUT_DISCARD
	_ship.hide_sails_above(float(_ship.mast_ladder[3]) - 0.3 if up_mast and not _ship.mast_ladder.is_empty() else 1000.0)
	_update_remotes(delta)
	for i in _cannon_icons.size():
		_cannon_icons[i].visible = _cannon_loaded[i]
	if _mode == Mode.HELM and _helm_owner != 0 and _helm_owner != _my_id():
		_mode = Mode.WALK  # quelqu'un d'autre a pris la barre avant nous
	_update_projectiles(delta)
	var fwd_p := _sim.forward()
	_fleet.step(delta, _is_authority(), {"pos": _sim.position, "vel": fwd_p * _sim.speed, "alive": true, "wind": _sim.wind_dir})
	_update_camera(delta)
	_update_atmosphere(delta)
	_animate_pirates(delta)
	_update_lot2_visuals(delta)
	_sync_pirate_palette()
	_snap_sprite()
	_update_hud()
	_net.tick(delta)
	if _args.has("log"):
		_log_timer += delta
		if _log_timer >= 1.0:
			_log_timer = 0.0
			print("[pirate] lieu=%d ppos=%s lpos=%s pz=%.2f sprite=%s cam=%s vis=%s" % [_loc, _ppos, _lpos, _pz, _sprite.global_position, _cam.position, _sprite.visible])
			print("[etat] fps=%d t=%.1f pos=(%.1f, %.1f) cap=%.0f° vitesse=%.2f voiles=%.2f barre=%.2f joueur=(%.2f, %.2f) cabine=%s équipage=%d barre=%d" % [
				Engine.get_frames_per_second(), _time, _sim.position.x, _sim.position.y, rad_to_deg(_sim.yaw), _sim.speed, _sim.sail_open,
				_sim.rudder, _ppos.x, _ppos.y, str(_ship.inside_cabin(_ppos)), _remotes.size() + 1, _helm_owner])


func _axis(neg: Array, pos: Array) -> float:
	var v := 0.0
	for k: Key in pos:
		if Input.is_physical_key_pressed(k):
			v += 1.0
			break
	for k: Key in neg:
		if Input.is_physical_key_pressed(k):
			v -= 1.0
			break
	return v


func _update_player(delta: float) -> void:
	_update_jump(delta)
	if _is_down() or _is_dead():
		return   # lot 4 : à terre on ne bouge plus ; mort, on attend de réapparaître
	var move := Vector2(_axis([KEY_A, KEY_LEFT], [KEY_D, KEY_RIGHT]), _axis([KEY_W, KEY_UP], [KEY_S, KEY_DOWN]))
	if _test_move != Vector2.ZERO:
		move = _test_move
	if _chart.is_open() or _pause.is_open() or _inventory.is_open():
		return   # penché sur la carte, dans le menu Échap ou le sac : on ne bouge pas
	if _loc == Loc.CLIMB:
		_update_climb(delta)
		return
	if _loc == Loc.NEST:
		_update_nest(move, delta)
		return
	if _loc == Loc.SWIM:
		_update_swim(_screen_move(move), delta)   # (les flèches suivent l'écran, même si la caméra a tourné ; vitesse égale à l'écran)
		return
	if _loc == Loc.FLIGHT:
		_update_flight(delta, _screen_move(move))
		return
	if _loc == Loc.RAFT:
		_update_raft_pilot(move)
		return
	if _loc == Loc.SHIP and _mode == Mode.HELM:
		if move.x != _rudder_sent:
			_rudder_sent = move.x
			_request("rudder", int(move.x * 100.0))
		return
	if _loc == Loc.SHIP and _mode == Mode.SAILS:
		_update_sail_station(move, delta)
		return
	if _loc == Loc.SHIP and _mode == Mode.CANNON:
		_cannon_aim = clampf(_cannon_aim + move.x * 0.9 * delta, -0.7, 0.7)
		return
	if _station_locked():
		return   # à son poste (canon, grappin, cabestan, réparation…) : on ne bouge pas tant qu'on n'a pas lâché (R)
	# marche à pied : les flèches suivent l'écran (même caméra tournée) et la vitesse est la même à l'écran vers le haut, le bas et les côtés
	var sm := _screen_move(move)
	var walk_mul := sm.length() if sm != Vector2.ZERO else 1.0
	move = sm.normalized()
	if _loc == Loc.HOLD:
		if move != Vector2.ZERO:
			var slow := 1.0 - _hull.walk_slow_in_water * _hull.fill()   # on patauge
			_hpos = _hold_layout.move_with_slide(_hpos, move * WALK_SPEED * walk_mul * _sprint_factor() * slow * delta)
		return
	if _jump_wind > 0.0:
		return   # accroupi avant de sauter
	var airborne := _pz > 0.05 or _vz != 0.0
	var talking := (_dialog != null and _dialog.is_open()) or (_shop_menu != null and _shop_menu.is_open())
	# Lot 2 (2.2) : en l'air on garde l'élan pris au sol et on ne le corrige qu'un peu (GameConfig.AIR_CONTROL) ; avant, les
	# flèches dirigeaient le saut librement, 1,3 fois plus vite qu'à pied : on planait sur 7 m en courant.
	if airborne and (_loc == Loc.LAND or (_loc == Loc.SHIP and _walkto == Vector2.INF)):
		var wish := Vector2.ZERO if talking else move * WALK_SPEED * walk_mul
		if wish == Vector2.ZERO:
			_air_vel = _air_vel.move_toward(Vector2.ZERO, GameConfig.AIR_DRAG * delta)   # on lâche les flèches : l'élan s'use un peu
		else:
			# on infléchit la trajectoire, sans jamais aller plus vite que l'élan pris (ou que la marche, si on a sauté sur place)
			var cap := maxf(_air_vel.length(), wish.length() * GameConfig.AIR_STANDING_SPEED)
			_air_vel = _air_vel.move_toward(wish.normalized() * cap, GameConfig.AIR_CONTROL * delta)
		var v := _air_vel * delta
		if v == Vector2.ZERO:
			return
		if _loc == Loc.LAND:
			_face = v.normalized()
			# en plein saut on n'est plus tenu par le bord du quai ni de la plage : on franchit le vide, on passe au-dessus des
			# poteaux et des tonneaux (seuls les murs arrêtent)
			var before := _lpos
			_lpos = _land.air_move(_lpos, v, _pz, _lh)
			if _lpos.distance_to(before) < v.length() * 0.5:
				_air_vel *= 0.4   # contre un mur : l'élan se brise
		else:
			var before_p := _ppos
			var dir_s := _ship_dir(v)
			_pface = dir_s
			_ppos = _ship.move_air(_ppos, dir_s * (v.length() / ShipModel.SCALE), _pz)   # un saut enjambe les caisses et passe le bastingage
			if _ppos.distance_to(before_p) < v.length() / ShipModel.SCALE * 0.5:
				_air_vel *= 0.4
		return
	_ground_vel = Vector2.ZERO
	if _loc == Loc.LAND:
		if move != Vector2.ZERO and not talking:
			_face = move.normalized()
			_ground_vel = move * WALK_SPEED * walk_mul * _sprint_factor()
			var step_l := _ground_vel * delta
			var r := _land.step(_lpos, step_l, _lh)
			_lpos = Vector2(r.x, r.y)
			_lh = r.z
		return
	var step_units := WALK_SPEED * walk_mul * _sprint_factor() / ShipModel.SCALE * delta
	if _walkto != Vector2.INF:
		var d := _walkto - _ppos
		if d.length() > 0.04:
			_pface = d.normalized()
			_ppos = _ship.move_with_slide(_ppos, d.normalized() * minf(step_units, d.length()))
		return
	if move == Vector2.ZERO:
		return
	var dir_ship := _ship_dir(move)
	_pface = dir_ship
	_ground_vel = move * WALK_SPEED * walk_mul * _sprint_factor()   # (monde, m/s : l'élan que prendra un saut)
	_ppos = _ship.move_with_slide(_ppos, dir_ship * step_units)


## Flèches (écran : x vers la droite, y vers le bas) -> déplacement dans le monde, caméra tournée comprise. La longueur du
## résultat est le facteur de vitesse qui rend le pas égal À L'ÉCRAN dans toutes les directions : la caméra est inclinée, donc
## un mètre vers le haut de l'écran paraît plus court qu'un mètre de côté (il faut aller plus vite dans le monde).
func _screen_move(move: Vector2) -> Vector2:
	if move == Vector2.ZERO:
		return Vector2.ZERO
	var s := maxf(sin(deg_to_rad(ELEVATION_DEG)), 0.2)
	var m := move.normalized()
	return Vector2(m.x, m.y / s).rotated(-_cam_yaw)


## Direction d'écran (x vers la droite, y vers le bas) -> direction dans le repère du modèle du bateau.
func _ship_dir(move: Vector2) -> Vector2:
	var world_dir := Vector3(move.x, 0.0, move.y).normalized()
	var local := _ship.global_transform.basis.inverse() * world_dir
	return Vector2(local.x, -local.z).normalized()


## Direction du repère du modèle (dx, dy) -> direction d'écran.
func _screen_of_ship(d: Vector2) -> Vector2:
	var w := _ship.global_transform.basis * Vector3(d.x, 0.0, -d.y)
	return Vector2(w.x, w.z)


## Position monde (x/z) d'un point du pont.
func _ship_to_world(bp: Vector2) -> Vector2:
	var local := Vector3((bp.x + _ship.shift) * ShipModel.SCALE, 0.0, -bp.y * ShipModel.SCALE)
	var w := Basis(Vector3.UP, _sim.yaw) * local
	return _sim.position + Vector2(w.x, w.z)


## Point de la scène (repère du jeu) pour un point du pont à la hauteur h au-dessus du pont.
func _ship_point(bp: Vector2, h: float) -> Vector3:
	return _ship.to_global(_ship.to_local3(bp, h))


## Point de la scène pour une position à terre (monde x/z) à la hauteur h au-dessus du sol.
func _land_point(w: Vector2, h: float) -> Vector3:
	return Vector3(w.x - _world_origin.x, h, w.y - _world_origin.z)


## Maj maintenue : on court (marche du pont, de la cale et de la terre). Lot 2 (2.1) : 10 % moins vite qu'avant.
func _sprint_factor() -> float:
	return SPRINT_MULT * GameConfig.SPRINT_SCALE if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0


## Saut : un temps d'accroupissement, puis une parabole. Possible à terre comme sur le pont.
func _update_jump(delta: float) -> void:
	_land_t = maxf(_land_t - delta, 0.0)
	if (_dialog != null and _dialog.is_open()) or (_shop_menu != null and _shop_menu.is_open()):
		_jump_wind = 0.0
	if _notice_t > 0.0:
		_notice_t -= delta
	if _jump_wind > 0.0:
		_jump_wind -= delta
		if _jump_wind <= 0.0:
			_vz = JUMP_SPEED
			_air_vel = _ground_vel   # l'élan du sol (immobile : on saute sur place)
			_air_origin = {"loc": _loc, "ppos": _ppos, "lpos": _lpos, "lh": _lh}
			_jump_fx("jump")
			_dbg("saute depuis (%.1f, %.1f)" % [_lpos.x, _lpos.y])
	if _loc != Loc.SHIP and _loc != Loc.LAND:
		_vz = 0.0   # sur une échelle, dans le nid, à la nage ou en vol : pas de gravité de saut, la hauteur est dictée ailleurs
		return
	if _loc == Loc.SHIP and _vz == 0.0 and _pz <= 0.05 and _jump_wind <= 0.0 and not _ship.over_hull(_ppos) and _raft_deck_y(_ship_to_world(_ppos)) == INF:
		_ppos = _ship.nearest_walkable(_ppos)   # filet de sécurité : on ne tombe du bateau qu'en sautant
	var floor_h := _fall_floor()
	if _vz != 0.0 or _pz > floor_h + 0.001:
		_pz += _vz * delta
		# Lot 2 (2.2) : la descente est plus franche que la montée (on ne flotte plus en haut du saut)
		_vz -= GRAVITY * (GameConfig.FALL_GRAVITY_MULT if _vz < 0.0 else 1.0) * delta
		floor_h = _fall_floor()
		if _pz <= floor_h and _vz < 0.0:
			_touch_down(floor_h)
			if _land_t > 0.1 and (_loc == Loc.LAND or _loc == Loc.SHIP):
				_jump_fx("land")   # (à l'eau, c'est le plouf qui joue)


## Hauteur (relative au pont ou au sol où je me tiens) du plancher sous mes pieds : 0 au-dessus du pont ou de la terre,
## plus bas au-dessus de l'eau (on tombe jusqu'à la mer), ou jusqu'au quai si le saut le survole.
func _fall_floor() -> float:
	if _loc == Loc.SHIP:
		if _ship.over_hull(_ppos):
			return 0.0
		var w := _ship_to_world(_ppos)
		var deck_y := _ship.position.y + _ship.deck_height(_ppos.x)
		var rdeck := _raft_deck_y(w)
		if rdeck != INF and deck_y + _pz >= rdeck - 0.12:
			return rdeck - deck_y   # au-dessus de mon radeau : on peut se poser dessus
		var quay := _land.surface_h(w, 0.0)   # le centre suffit : on peut se réceptionner tout au bord du quai (on est ensuite recalé)
		if quay != Land.NO_SURFACE:
			return quay - deck_y
		return SEA_Y + _wave_height(w) - deck_y
	if _loc == Loc.LAND:
		# du quai, d'un ponton ou d'une plage on peut sauter sur le pont d'un bateau qui est là, dans l'eau ou au sol
		var bp := _world_to_ship(_lpos)
		if _ship.over_hull(bp):
			var deck_rel := _ship.position.y + _ship.deck_height(bp.x) - _lh
			if _pz >= deck_rel - 0.12:
				return deck_rel
		var rdeck_l := _raft_deck_y(_lpos)
		if rdeck_l != INF and _lh + _pz >= rdeck_l - 0.12:
			return rdeck_l - _lh
		var g := _land.surface_below(_lpos, _lh + _pz)   # la plus haute surface sous les pieds (estrade, plateau), pas seulement le sol de départ
		if g != Land.NO_SURFACE:
			return g - _lh
		if _land.is_over_water(_lpos):
			return SEA_Y + _wave_height(_lpos) - _lh
	return 0.0


## Vrai si, à terre, il n'y a plus rien sous `p` à la hauteur `h` : la mer (après la plage, le bout d'un ponton). Une terrasse ou un
## étage qui dépasse du sol de base compte comme du sol.
func _land_void(p: Vector2, h: float) -> bool:
	return _land.is_over_water(p) and _land.walk_height(p, h) == Land.NO_SURFACE


## Fin d'un saut : sur le pont ou la terre on se réceptionne, au-dessus de l'eau on y plonge, au-dessus du quai on atterrit dessus.
func _touch_down(floor_h: float) -> void:
	_dbg("retombe : sol %.2f, pz %.2f, loc %d, lpos (%.1f, %.1f) ppos (%.1f, %.1f), parti de %s" % [floor_h, _pz, _loc, _lpos.x, _lpos.y, _ppos.x, _ppos.y, _air_origin.get("lpos")])
	_vz = 0.0
	if _loc == Loc.SHIP:
		if _ship.over_hull(_ppos):
			var from_cabin := _ship.inside_cabin(_air_origin.get("ppos", _ppos) as Vector2) and int(_air_origin.get("loc", Loc.SHIP)) == Loc.SHIP
			var spot := _ship.landing_spot(_ppos, from_cabin)
			if spot != Vector2.INF:
				_ppos = spot
				_pz = 0.0
				_land_t = 0.14
				return
			# rien d'atteignable sur le pont sans traverser un mur (bande entre la cabine et le plat-bord) : on tombe le long de la coque
			_ppos = _ship.outside_point(_ppos)
		var w := _ship_to_world(_ppos)
		if _raft_deck_y(w) != INF and not _ship.over_hull(_ppos):
			_board_raft()   # on a sauté sur le radeau
			return
		var quay := _land.surface_h(w, 0.0)
		if quay != Land.NO_SURFACE and not _ship.over_hull(_ppos):
			if _stand_on_ground(w, quay):
				_face = _screen_of_ship(_pface)
				return
			_return_to_takeoff()   # coincé contre un mur ou un obstacle : on revient d'où l'on a sauté
			return
		_enter_swim(w)
		return
	if _loc == Loc.LAND:
		var bp := _world_to_ship(_lpos)
		if _ship.over_hull(bp) and _lh + _pz >= _ship.position.y + _ship.deck_height(bp.x) - 0.12:
			var spot := _ship.landing_spot(bp)
			if spot != Vector2.INF:   # on atterrit sur le pont du bateau
				_dbg("atterrissage sur le pont en (%.1f, %.1f)" % [spot.x, spot.y])
				_loc = Loc.SHIP
				_mode = Mode.WALK
				_ppos = spot
				_pface = _ship_dir(_face)
				_pz = 0.0
				_land_t = 0.14
				_walkto = Vector2.INF
				return
		if _raft_deck_y(_lpos) != INF and _lh + _pz >= _raft_deck_y(_lpos) - 0.12:
			_board_raft()   # on a sauté sur le radeau
			return
		var g := _land.surface_below(_lpos, _lh + _pz + 0.001)
		if g != Land.NO_SURFACE:
			if _stand_on_ground(_lpos, g):
				return
			# trop au bord de l'estrade pour y tenir : on retombe sur ce qu'il y a plus bas plutôt que de revenir au départ
			var lower := _land.surface_below(_lpos, g - _land.step_tol - 0.01)
			if lower != Land.NO_SURFACE and _stand_on_ground(_lpos, lower):
				return
			_return_to_takeoff()
			return
		if _land.is_over_water(_lpos):
			_enter_swim(_lpos)
			return
		_return_to_takeoff()


## Pose le pirate à terre en `w` (monde x/z), le sol y étant à la hauteur `g` : au point libre le plus proche si le bord, un poteau ou un
## mur l'en empêchent. Faux si aucun sol libre à moins de 1,6 m.
func _stand_on_ground(w: Vector2, g: float) -> bool:
	var q := w
	var h := _land.walk_height(q, g)
	if h == Land.NO_SURFACE:
		# d'abord une place libre tout près, à la même hauteur (bord d'une estrade : on recule un peu sur elle)
		q = _land.nearest_standable(w, g, GameConfig.LANDING_SEARCH)
		if q != Vector2.INF:
			h = _land.walk_height(q, g)
		else:
			q = _land.nearest_walkable(w, 1.6)
			h = _land.walk_height(q, g)
		if h == Land.NO_SURFACE:
			return false
	_loc = Loc.LAND
	_mode = Mode.WALK
	_lpos = q
	_lh = h
	_pz = 0.0
	_vz = 0.0
	_land_t = 0.14
	_dbg("à terre en (%.1f, %.1f), sol à %.2f" % [q.x, q.y, h])
	return true


## Un saut qui finit dans un mur : le pirate retombe à l'endroit d'où il a sauté.
func _return_to_takeoff() -> void:
	_pz = 0.0
	_vz = 0.0
	_land_t = 0.14
	if int(_air_origin.get("loc", Loc.SHIP)) == Loc.LAND:
		_loc = Loc.LAND
		_lpos = _air_origin["lpos"]
		_lh = float(_air_origin["lh"])
	else:
		_loc = Loc.SHIP
		_ppos = _ship.nearest_walkable(_air_origin.get("ppos", _ppos))


## Trace pour les essais (--log) : où le pirate atterrit, ce que fait le crochet…
func _dbg(text: String) -> void:
	if _args.has("log"):
		print("[essai t=%.2f] %s" % [_time, text])


## Plouf : le pirate tombe à l'eau en `w` (monde x/z) et se met à nager.
func _enter_swim(w: Vector2) -> void:
	_dbg("plouf en (%.1f, %.1f)" % [w.x, w.y])
	_drop_carried(true)   # un boulet ou une planche coule ; un trésor reste dans les bras
	_loc = Loc.SWIM
	_mode = Mode.WALK
	_lpos = w
	_lh = 0.0
	_pz = 0.0
	_vz = 0.0
	_swim_t = 0.0
	_swim_ring_t = 0.0
	_prev_lpos = w
	_splash(Vector3(w.x, SEA_Y + 0.05, w.y))   # (_splash et _splash_burst posent leurs nœuds dans le monde fixe : coordonnées du monde)
	_splash_burst(w)
	_say("À la nage ! E près de la coque : remonter à bord. Un quai ou une plage : nage jusqu'au bord", 5.0)


## Gerbe d'éclaboussures (gouttes qui retombent) en `w`.
func _splash_burst(w: Vector2) -> void:
	for k in 9:
		var drop := _make_ball(0.07, Color(0.8, 0.93, 1.0))
		(drop.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world_fixed.add_child(drop)
		var base := Vector3(w.x, SEA_Y + 0.1, w.y)
		drop.position = base
		var a := TAU * float(k) / 9.0 + randf() * 0.5
		var d := Vector3(cos(a), 0.0, sin(a)) * randf_range(0.5, 1.2)
		var tw := drop.create_tween()
		tw.set_parallel(true)
		tw.tween_property(drop, "position:x", base.x + d.x, 0.45)
		tw.tween_property(drop, "position:z", base.z + d.z, 0.45)
		tw.tween_property(drop, "position:y", base.y + randf_range(0.9, 1.7), 0.22).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(drop, "position:y", base.y, 0.23).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(drop.queue_free)


func _try_jump() -> void:
	if _is_down() or _is_dead():
		return
	if _loc == Loc.SWIM:
		if not _try_board_raft_from_water():
			_try_board_from_water()
		return
	if _loc == Loc.RAFT:
		_leave_raft(true)   # Espace : on plonge du radeau
		return
	if _loc == Loc.SHIP and _mode == Mode.HELM:
		_leave_helm()   # sauter lâche la barre
		return
	if _loc == Loc.SHIP and _mode == Mode.SAILS:
		_leave_sails()
		return
	if _loc == Loc.SHIP and _mode == Mode.CANNON:
		_leave_cannon(false)
		return
	if (_loc == Loc.SHIP or _loc == Loc.LAND) and _mode == Mode.WALK and _pz == 0.0 and _vz == 0.0 and _jump_wind <= 0.0:
		_jump_wind = 0.09


# ------------------------------------------------------------------ nage

## Position d'un point monde dans le repère du bateau (x vers l'étrave, y vers bâbord), inverse de _ship_to_world.
func _world_to_ship(w: Vector2) -> Vector2:
	var rel := w - _sim.position
	var local := Basis(Vector3.UP, -_sim.yaw) * Vector3(rel.x, 0.0, rel.y)
	return Vector2(local.x / ShipModel.SCALE - _ship.shift, -local.z / ShipModel.SCALE)


## Nage : les flèches nagent à vitesse égale dans toutes les directions ; sur la terre ferme (plage, quai) on prend pied ;
## on ne traverse pas la coque.
func _update_swim(move: Vector2, delta: float) -> void:
	_swim_t += delta
	if move == Vector2.ZERO:
		return
	_face = move.normalized()
	var next := _lpos + move * SWIM_SPEED * delta   # (move : déjà corrigé pour la vitesse à l'écran, voir _screen_move)
	if _land.is_walkable(next) and not _land.is_over_water(next):
		_loc = Loc.LAND
		_lpos = next
		_lh = _land.walk_height(next, 0.0) if _land.walk_height(next, 0.0) != Land.NO_SURFACE else 0.0
		_vz = 4.0   # on se hisse hors de l'eau
		_pz = 0.0
		_splash_burst(next)
		return
	var bp := _world_to_ship(next)
	if _ship.over_hull(bp):
		# la coque barre la route : on glisse le long d'elle (on est poussé vers le côté le plus proche)
		var side := 1.0 if bp.y >= 0.0 else -1.0
		bp.y = side * (_ship.half_width(bp.x) + 0.12)
		next = _ship_to_world(bp)
	_lpos = next


## E (ou Espace) à la nage : on ne remonte à bord QUE par une échelle de coque (demande 4.6, avancée au lot 1). Avant, n'importe
## quel point de la coque suffisait, et le pirate était posé au point libre du pont le plus proche… parfois dans la cabine, à travers
## son mur (le passage « du ponton à la cabine » signalé après le lot 1).
func _try_board_from_water() -> void:
	var i := _nearest_ladder_from_water()
	if i < 0:
		var bp := _world_to_ship(_lpos)
		var hw := _ship.half_width(clampf(bp.x, -_ship.length * 0.5 + 0.2, _ship.length * 0.5 - 0.2))
		var near_hull := (absf(bp.y) - hw) * ShipModel.SCALE <= BOARD_REACH and bp.x > -_ship.length * 0.5 - 1.0 and bp.x < _ship.length * 0.5 + 1.0
		_say("On ne remonte à bord que par l'échelle : nage jusqu'à elle" if near_hull else "Trop loin du bateau : nage jusqu'à l'échelle", 2.5)
		return
	if absf(_sim.speed) > 3.2:
		_say("Le bateau va trop vite pour s'y accrocher", 2.5)
		return
	var l: Array = _ship.ladders[i]
	var deck := _ship.nearest_walkable(Vector2(float(l[0]), float(l[1])))
	if not _ship.is_walkable(deck):
		_say("Pas de place pour monter ici", 2.5)
		return
	var y_from := SEA_Y - SWIM_DEPTH
	_loc = Loc.CLIMB
	_mode = Mode.WALK
	_climb = {"kind": "hull", "t": 0.0, "dur": 1.0, "from": _lpos, "to": _ship_to_world(deck), "board": true, "deck": deck,
			"y0": y_from, "y1": _ship.position.y + _ship.deck_height(deck.x)}
	_splash_burst(_lpos)


## Les rides que laisse le nageur : un anneau d'écume de temps en temps (plus souvent quand il nage).
func _swim_effects(delta: float) -> void:
	_swim_ring_t -= delta
	if _swim_ring_t <= 0.0:
		_swim_ring_t = 0.55 if _lpos.distance_to(_prev_lpos) > 0.005 else 1.1
		_splash(Vector3(_lpos.x, SEA_Y + 0.04, _lpos.y))


# ------------------------------------------------------------------ vol du canon

## Le pirate tiré du canon vole : trajectoire balistique, puis il retombe sur le pont, la terre ou à l'eau.
## Touche M (essais, demandée par Jimmy) : le pirate s'envole et survole la carte à toute vitesse (Maj : encore plus vite) ;
## M de nouveau : il se laisse tomber là où il est (sur un pont, à terre ou dans l'eau, comme un pirate tiré du canon).
func _toggle_fly() -> void:
	if _loc == Loc.FLIGHT and _flight.get("fly", false):
		_flight["fly"] = false
		_flight["vel"] = Vector2.ZERO
		_flight["vz"] = -18.0
		_say("Tu te laisses tomber", 1.5)
		return
	if _loc == Loc.HOLD or _loc == Loc.FLIGHT:
		return
	_cancel_action()
	_gun_leave()
	_hook_aim = false
	if _loc == Loc.SHIP:
		_mode = Mode.WALK
		_lpos = _ship_to_world(_ppos)
	_loc = Loc.FLIGHT
	_flight = {"vel": Vector2.ZERO, "vz": 0.0, "y": GameConfig.FLY_HEIGHT, "fly": true}
	_say("Vol libre : flèches pour aller où tu veux (Maj : plus vite), M pour redescendre", 4.0)


func _update_flight(delta: float, steer: Vector2 = Vector2.ZERO) -> void:
	if _flight.get("fly", false):
		var fast := GameConfig.FLY_FAST if Input.is_key_pressed(KEY_SHIFT) else 1.0
		_lpos += steer * GameConfig.FLY_SPEED * fast * delta
		_flight["y"] = move_toward(float(_flight["y"]), GameConfig.FLY_HEIGHT, 8.0 * delta)
		return
	var vel: Vector2 = _flight["vel"]
	_lpos += vel * delta
	var vz: float = _flight["vz"]
	var y: float = _flight["y"] + vz * delta
	vz -= 12.0 * delta
	_flight["vz"] = vz
	_flight["y"] = y
	if vz > 0.0:
		return
	# sur le pont de mon bateau ?
	var bp := _world_to_ship(_lpos)
	var deck_y := _ship.position.y + _ship.deck_height(bp.x)
	if _ship.over_hull(bp) and y <= deck_y + 0.05 and _ship.landing_spot(bp) != Vector2.INF:
		_ppos = _ship.landing_spot(bp)
		_loc = Loc.SHIP
		_mode = Mode.WALK
		_pz = 0.0
		_vz = 0.0
		_land_t = 0.3
		_flight = {}
		_say("Atterrissage sur le pont !", 2.0)
		return
	var ground := _land.walk_height(_lpos, 0.0)
	if ground != Land.NO_SURFACE and y <= ground + 0.05:
		_loc = Loc.LAND
		_lh = ground
		_pz = 0.0
		_vz = 0.0
		_land_t = 0.3
		_flight = {}
		_say("Atterrissage sur la terre ferme !", 2.0)
		return
	if y <= SEA_Y + _wave_height(_lpos) + 0.05 and not _ship.over_hull(bp):
		_flight = {}
		_enter_swim(_lpos)


## Le départ d'un pirate tiré du canon `i` selon la visée : {pos (monde x/z), vel (horizontale), y (altitude)}.
## La visée tourne dans le sens des aiguilles d'une montre à l'écran quand on appuie à droite.
func _cannon_launch(i: int) -> Dictionary:
	var c: Array = _ship.cannons[i]
	var side := float(c[2])
	var out3 := (_ship.global_transform.basis * Vector3(0.0, 0.0, -side)).normalized()
	var dir := Vector2(out3.x, out3.z).rotated(_cannon_aim)
	var start := _ship.to_global(ShipCannons.muzzle_local(_cannon_nodes[i]))
	var fwd := _sim.forward()
	return {"pos": Vector2(start.x + _world_origin.x, start.z + _world_origin.z), "vel": dir * CANNON_SPEED + fwd * _sim.speed, "y": start.y}


## La trajectoire prévue quand je suis dans un canon : une ligne de tirets jaunes jusqu'à l'eau, et un cercle à l'arrivée.
func _update_aim_line() -> void:
	var active := _loc == Loc.SHIP and _mode == Mode.CANNON and _cannon_in >= 0
	if _aim_line == null:
		_aim_line = MeshInstance3D.new()
		_aim_line.mesh = ImmediateMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.86, 0.2)
		mat.no_depth_test = true
		mat.render_priority = 6
		_aim_line.material_override = mat
		_aim_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_aim_line.extra_cull_margin = 80.0
		_world.add_child(_aim_line)
	_aim_line.visible = active
	if not active:
		return
	var launch := _cannon_launch(_cannon_in)
	var barrel := (_cannon_nodes[_cannon_in]["barrel"] as Node3D)
	barrel.rotation.y = -_cannon_aim
	var p: Vector2 = launch["pos"]
	var v: Vector2 = launch["vel"]
	var y: float = launch["y"]
	var vz := CANNON_LIFT
	var pts: Array[Vector3] = []
	for k in 60:
		pts.append(_land_point(p, y))
		p += v * 0.05
		y += vz * 0.05
		vz -= 12.0 * 0.05
		if y <= SEA_Y and vz < 0.0:
			break
	pts.append(_land_point(p, SEA_Y + 0.05))
	var im := _aim_line.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for k in range(0, pts.size() - 1, 2):
		im.surface_add_vertex(pts[k])
		im.surface_add_vertex(pts[k + 1])
	var end := pts[pts.size() - 1]
	for k in 16:
		var a0 := TAU * float(k) / 16.0
		var a1 := TAU * float(k + 1) / 16.0
		im.surface_add_vertex(end + Vector3(cos(a0), 0.0, sin(a0)) * 1.1)
		im.surface_add_vertex(end + Vector3(cos(a1), 0.0, sin(a1)) * 1.1)
	im.surface_end()


# --- viser et tirer au canon, à la souris ---

const GUN_ARC := PI              ## rad : visée libre sur 360° (le tube suit le curseur, d'où qu'il soit)
const GUN_RELOAD := 0.7          ## s : délai entre deux tirs au même canon

var _gun_i := -1                 ## le canon que je vise à la souris (-1 : aucun)
var _gun_cd := 0.0
var _gun_line: MeshInstance3D


## E au canon `i` : on le prend en main pour viser à la souris.
func _gun_enter(i: int) -> void:
	_gun_i = i
	_cannon_aim = 0.0
	# on se met à son poste : juste derrière la culasse, face à la mer, et on n'en bouge plus tant qu'on vise
	var c: Array = _ship.cannons[i]
	var side := float(c[2])
	var spot := Vector2(float(c[0]), float(c[1]))
	while not _ship.is_walkable(spot) and absf(spot.y - float(c[1])) < 2.0:
		spot.y -= side * 0.02
	_ppos = spot
	_walkto = Vector2.INF
	_pface = Vector2(0.0, side)


## On lâche le canon : le tube reprend sa place.
func _gun_leave() -> void:
	if _gun_i >= 0 and _gun_i < _cannon_nodes.size():
		(_cannon_nodes[_gun_i]["barrel"] as Node3D).rotation.y = 0.0
	_gun_i = -1
	_cannon_aim = 0.0


## La sortie du canon `i` dans le monde (x/z, unitaire) : perpendiculaire au bord.
func _gun_out(i: int) -> Vector2:
	var side := float((_ship.cannons[i] as Array)[2])
	var out3 := (_ship.global_transform.basis * Vector3(0.0, 0.0, -side)).normalized()
	return Vector2(out3.x, out3.z).normalized()


## Chaque image : le tube suit le pointeur (dans l'arc permis) et le tracé du boulet montre où il tombera (vert : il toucherait un ennemi).
func _update_gun_aim(delta: float) -> void:
	_gun_cd = maxf(_gun_cd - delta, 0.0)
	if _gun_line == null:
		_gun_line = MeshInstance3D.new()
		_gun_line.mesh = ImmediateMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.no_depth_test = true
		mat.render_priority = 6
		_gun_line.material_override = mat
		_gun_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_gun_line.extra_cull_margin = 80.0
		_world.add_child(_gun_line)
	if _gun_i >= 0:
		var busy := _dialog.is_open() or _shop_menu.is_open() or _chart.is_open() or _pause.is_open() or _inventory.is_open()
		var cpos := Vector2.INF
		if _gun_i < _ship.cannons.size():
			cpos = Vector2(float((_ship.cannons[_gun_i] as Array)[0]), float((_ship.cannons[_gun_i] as Array)[1]))
		if busy or _loc != Loc.SHIP or _mode != Mode.WALK or cpos == Vector2.INF or _ppos.distance_to(cpos) > 3.2:
			_gun_leave()   # on s'est éloigné du canon, ou autre chose prend la main
	_gun_line.visible = _gun_i >= 0
	if _gun_i < 0:
		return
	var muzzle := _ship.to_global(ShipCannons.muzzle_local(_cannon_nodes[_gun_i]))
	var out2 := _gun_out(_gun_i)
	var hit3 := _mouse_ground_point(muzzle.y)
	if hit3 != Vector3.INF:
		var to := Vector2(hit3.x - muzzle.x, hit3.z - muzzle.z)
		if to.length() > 0.5:
			_cannon_aim = clampf(out2.angle_to(to), -GUN_ARC, GUN_ARC)
	(_cannon_nodes[_gun_i]["barrel"] as Node3D).rotation.y = -_cannon_aim
	# trajectoire prévue : mêmes lois que le boulet (voir fire_visual et _update_projectiles)
	var dir := out2.rotated(_cannon_aim)
	var fwd := _sim.forward()
	var vel := Vector3(dir.x, 0.0, dir.y) * 28.0 + Vector3.UP * 5.0 + Vector3(fwd.x, 0.0, fwd.y) * _sim.speed
	var pos := muzzle
	var pts: Array[Vector3] = [pos]
	var hits := false
	for k in 70:
		vel.y -= 16.0 * 0.04
		pos += vel * 0.04
		pts.append(pos)
		if _fleet.ball_hit(pos) >= 0:
			hits = true
			break
		if pos.y < SEA_Y:
			break
	var col := Color(0.45, 1.0, 0.5) if hits else (Color(1.0, 0.86, 0.2) if _cannon_loaded[_gun_i] else Color(1.0, 0.45, 0.35))
	var im := _gun_line.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(col)
	for k in range(0, pts.size() - 1, 2):
		im.surface_add_vertex(pts[k])
		im.surface_add_vertex(pts[k + 1])
	var end := pts[pts.size() - 1]
	for k in 16:
		var a0 := TAU * float(k) / 16.0
		var a1 := TAU * float(k + 1) / 16.0
		im.surface_add_vertex(end + Vector3(cos(a0), 0.0, sin(a0)) * 1.1)
		im.surface_add_vertex(end + Vector3(cos(a1), 0.0, sin(a1)) * 1.1)
	im.surface_end()


## Clic gauche pendant qu'on vise : tire (ou recharge depuis la caisse si le canon est vide).
func _gun_fire() -> void:
	if _gun_i < 0 or _gun_cd > 0.0:
		return
	var i := _gun_i
	if not _cannon_loaded[i]:
		if _carry_kind == "ball":
			_drop_carried()
		elif _carrying or not _profile.take_supply("ball"):
			_say("Pas de boulet : prends-en un à la caisse ou au tonneau" if not _carrying else "Tes mains sont prises", 2.5)
			return
		_request("load", i)
		_cannon_loaded[i] = true
		_gun_cd = GUN_RELOAD
		return
	var deg := clampi(roundi(rad_to_deg(_cannon_aim)), -180, 180)
	_request("aim_fire", i + 100 * (deg + 180))
	_cannon_loaded[i] = false   # affichage immédiat ; l'hôte confirme
	_gun_cd = GUN_RELOAD


## Un pirate glissé dans le canon `i` : Q/D pour viser, E pour partir, R/Espace pour ressortir.
func _enter_cannon(i: int) -> void:
	_cannon_in = i
	_cannon_aim = 0.0
	_mode = Mode.CANNON
	_sprite.scale = Vector3.ONE * 0.001
	_walkto = Vector2.INF
	var c: Array = _ship.cannons[i]
	_ppos = Vector2(float(c[0]), float(c[1]) - float(c[2]) * 0.0)


func _leave_cannon(fire: bool) -> void:
	var i := _cannon_in
	_cannon_in = -1
	_mode = Mode.WALK
	_sprite.scale = Vector3.ONE   # (le sprite se remet à visible tout seul : on le cache en le réduisant à rien)
	if i >= 0 and i < _cannon_nodes.size():
		(_cannon_nodes[i]["barrel"] as Node3D).rotation.y = 0.0
	if i < 0:
		return
	var c: Array = _ship.cannons[i]
	var inward := Vector2(float(c[0]), float(c[1]) - float(c[2]) * 0.9)
	_ppos = _ship.nearest_walkable(inward)
	if not fire:
		_pface = Vector2(0.0, float(c[2]))
		return
	var launch := _cannon_launch(i)
	_loc = Loc.FLIGHT
	_lpos = launch["pos"]
	_flight = {"vel": launch["vel"], "vz": CANNON_LIFT, "y": launch["y"]}
	_pz = 0.0
	_vz = 0.0
	_prev_lpos = _lpos
	_request("human_fire", i)
	_shake_t = 0.25


# ------------------------------------------------------------------ vergues

## Debout au mât : A/D tournent les vergues, W/S hissent ou affalent, E lâche le mât.
func _update_sail_station(move: Vector2, delta: float) -> void:
	var sent := int(move.x * 100.0)
	if sent != _trim_sent:
		_trim_sent = sent
		_request("trim", sent)
	_sail_cd = maxf(_sail_cd - delta, 0.0)
	if move.y != 0.0 and _sail_cd <= 0.0:
		_sail_cd = 0.7
		_request("sail", 1 if move.y < 0.0 else -1)


func _enter_sails(it: Dictionary) -> void:
	_mode = Mode.SAILS
	_sail_station = it["pos"]
	_pface = ((it["pos"] as Vector2) - _ppos).normalized() if _ppos.distance_to(it["pos"] as Vector2) > 0.05 else _pface
	_trim_sent = 0
	_walkto = Vector2.INF


func _leave_sails() -> void:
	_mode = Mode.WALK
	_trim_sent = 0
	_request("trim", 0)


func _say(text: String, seconds: float = 2.5) -> void:
	_notice = text
	_notice_t = seconds


## Hauteur du plancher du nid de pie au-dessus du pont (m).
func _nest_height() -> float:
	if _ship.nests.is_empty() or _ship.mast_ladder.is_empty():
		return 0.0
	var nx := float(_ship.mast_ladder[0]) + 0.62
	return (float(_ship.mast_ladder[3]) + 0.06) * ShipModel.SCALE - _ship.deck_height(nx)


## Le nid de pie du mât qui porte l'échelle.
func _mast_nest() -> Array:
	for n: Array in _ship.nests:
		if absf(float(n[0]) - (float(_ship.mast_ladder[0]) + 0.62)) < 0.05:
			return n
	return []


## Monte (up) ou descend l'échelle du mât le plus haut.
func _start_mast_climb(up: bool) -> void:
	if _ship.mast_ladder.is_empty():
		return
	_loc = Loc.CLIMB
	_climb = {"kind": "mast", "t": 0.0 if up else 1.0, "up": up}
	_ppos = Vector2(float(_ship.mast_ladder[0]) + 0.3, float(_ship.mast_ladder[1]))
	_mode = Mode.WALK


func _update_climb(delta: float) -> void:
	if _climb.get("kind") == "mast":
		var top := maxf(_nest_height(), 0.5)
		var t: float = _climb["t"] + (1.0 if _climb["up"] else -1.0) * CLIMB_SPEED * delta / top
		_climb["t"] = clampf(t, 0.0, 1.0)
		_pz = top * float(_climb["t"])
		if t >= 1.0:
			_loc = Loc.NEST
			_pz = top
			var nest := _mast_nest()
			if not nest.is_empty():
				_ppos = Vector2(float(nest[0]), float(nest[1]) + NEST_RADIUS.y * 0.9)
		elif t <= 0.0:
			_loc = Loc.SHIP
			_pz = 0.0
			_ppos = _ship.nearest_walkable(Vector2(float(_ship.mast_ladder[0]) - 0.1, 0.0))
		return
	# échelle de coque : on passe par-dessus le plat-bord, en un petit arc, du pont au quai (ou l'inverse) ; depuis l'eau
	# (y0, y1) on monte du niveau de la mer au pont
	var dur: float = _climb["dur"]
	_climb["t"] = minf(float(_climb["t"]) + delta / dur, 1.0)
	var t2: float = _climb["t"]
	_lpos = (_climb["from"] as Vector2).lerp(_climb["to"], t2)
	_pz = sin(PI * t2) * 0.55
	if _climb.has("y0"):
		_pz += lerpf(float(_climb["y0"]), float(_climb["y1"]), smoothstep(0.0, 1.0, t2))
	if t2 >= 1.0:
		_pz = 0.0
		if _climb["board"]:
			_loc = Loc.SHIP
			_ppos = _climb["deck"]
		else:
			_loc = Loc.LAND
			_lpos = _climb["to"]
		_climb = {}


func _update_nest(move: Vector2, delta: float) -> void:
	var nest := _mast_nest()
	if nest.is_empty():
		return
	var c := Vector2(float(nest[0]), float(nest[1]))
	var p := _ppos
	if move != Vector2.ZERO:
		p += _ship_dir(move) * (WALK_SPEED * 0.55 / ShipModel.SCALE * delta)
	var d := p - c
	var dist := clampf(d.length(), NEST_RADIUS.x, NEST_RADIUS.y)
	_ppos = c + (d.normalized() if d.length() > 0.001 else Vector2(-1, 0)) * dist


## Descend par l'échelle de coque `i` : de l'autre côté du plat-bord il y a le quai.
func _try_disembark(i: int) -> void:
	_lh = 0.0
	var l: Array = _ship.ladders[i]
	var side := float(l[2])
	var outside := _ship_to_world(Vector2(float(l[0]), float(l[3]) + side * 0.9))
	var target := _land.nearest_walkable(outside, LADDER_REACH)
	if not _land.is_walkable(target) or target.distance_to(outside) > LADDER_REACH:
		_say("Pas de quai à portée de l'échelle")
		return
	if absf(_sim.speed) > 1.5:
		_say("Le bateau va trop vite")
		return
	_loc = Loc.CLIMB
	_climb = {"kind": "hull", "t": 0.0, "dur": 1.1, "from": _ship_to_world(_ppos), "to": target, "board": false}
	_lpos = _climb["from"]
	_mode = Mode.WALK


## L'échelle de coque au pied de laquelle nage le pirate (à moins de GameConfig.LADDER_SWIM_REACH m), ou -1.
func _nearest_ladder_from_water() -> int:
	var best := -1
	var best_d := GameConfig.LADDER_SWIM_REACH
	for i in _ship.ladders.size():
		var l: Array = _ship.ladders[i]
		var foot := _ship_to_world(Vector2(float(l[0]), float(l[3]) + float(l[2]) * 0.3))   # le bas de l'échelle, contre la coque
		var d := _lpos.distance_to(foot)
		if d < best_d:
			best_d = d
			best = i
	return best


func _nearest_ship_ladder_from_land() -> int:
	var best := -1
	var best_d := LADDER_REACH
	for i in _ship.ladders.size():
		var l: Array = _ship.ladders[i]
		var out := _ship_to_world(Vector2(float(l[0]), float(l[3]) + float(l[2]) * 0.9))
		var d := _lpos.distance_to(out)
		if d < best_d:
			best_d = d
			best = i
	return best


func _try_board() -> void:
	var i := _nearest_ship_ladder_from_land()
	if i < 0:
		_say("Aucune échelle à portée")
		return
	if absf(_sim.speed) > 1.5:
		_say("Le bateau va trop vite")
		return
	var l: Array = _ship.ladders[i]
	var deck := _ship.nearest_walkable(Vector2(float(l[0]), float(l[1])))
	_loc = Loc.CLIMB
	_climb = {"kind": "hull", "t": 0.0, "dur": 1.1, "from": _lpos, "to": _ship_to_world(deck), "board": true, "deck": deck}
	_mode = Mode.WALK


## Place mon pirate et son ombre dans la scène selon l'endroit où il se trouve.
func _place_pirate() -> void:
	var gp: Vector3
	var ground: Vector3
	var shadow := true
	match _loc:
		Loc.LAND:
			gp = _land_point(_lpos, 0.02 + _lh + _pz)
			ground = _land_point(_lpos, 0.04 + _lh)
		Loc.CLIMB:
			if _climb.get("kind") == "mast":
				gp = _ship_point(_ppos, 0.02 + _pz)
				ground = gp
				shadow = false
			else:
				gp = _land_point(_lpos, 0.02 + _pz)
				ground = _land_point(_lpos, 0.04)
		Loc.NEST:
			gp = _ship_point(_ppos, 0.02 + _pz)
			ground = _ship_point(_ppos, 0.06 + _pz)
		Loc.HOLD:
			gp = _hold.point(_hpos, 0.02)
			ground = _hold.point(_hpos, 0.07)
		Loc.SWIM:
			# les pieds sous la surface : l'eau opaque cache le bas du corps, on ne voit que buste et tête
			var wl := SEA_Y + _wave_height(_lpos)
			gp = _land_point(_lpos, wl - SWIM_DEPTH + sin(_swim_t * 3.4) * 0.05)
			ground = _land_point(_lpos, wl + 0.03)
			shadow = false
		Loc.FLIGHT:
			gp = _land_point(_lpos, float(_flight.get("y", 0.0)))
			ground = _land_point(_lpos, SEA_Y + 0.04)
		Loc.RAFT:
			var deck := (_raft.position.y + Raft.TOP) if _raft != null else SEA_Y
			gp = _land_point(_lpos, deck + 0.02)
			ground = _land_point(_lpos, deck + 0.04)
			shadow = false
		_:
			gp = _ship_point(_ppos, 0.02 + _pz)
			ground = _ship_point(_ppos, 0.04)
	_sprite.global_position = gp
	_blob.global_position = ground
	_blob.visible = shadow and not (_loc == Loc.SHIP and _mode == Mode.CANNON)
	var air := _pz if (_loc == Loc.SHIP or _loc == Loc.LAND) else 0.0
	if _loc == Loc.FLIGHT:
		air = clampf((float(_flight.get("y", 0.0)) - SEA_Y) * 0.5, 0.0, 3.0)
	var k := maxf(0.55, 1.0 - air * 0.35)
	_blob.scale = Vector3(k, 1.0, 0.7 * k)


## Cale les sprites (le mien et ceux de l'équipage) sur la grille de pixels de l'écran : sinon
## leurs pixels « vibrent » quand ils bougent.
func _snap_sprite() -> void:
	# à terre et dans la cale, le sprite est avancé vers la caméra (sans changer sa place à l'écran) : sinon le bas
	# du corps s'enfonce dans les marches, les terrasses et le sol qui sont à ses pieds
	var ashore := _loc == Loc.LAND or _loc == Loc.HOLD
	_snap_node(_sprite, (SPRITE_DEPTH_BIAS + (_slope_bias(_lpos) if _loc == Loc.LAND else 0.0)) if ashore else 0.0)
	for id in _remotes:
		var rl: int = _remotes[id]["loc"]
		_snap_node(_remotes[id]["sprite"], SPRITE_DEPTH_BIAS if (rl == 1 or rl == 4) else 0.0)
	for npc: TownNpc in _npcs:
		if npc.sprite.visible:
			_snap_node(npc.sprite, SPRITE_DEPTH_BIAS)


## Avance de plus le pirate vers la caméra quand le sol monte devant lui (côté caméra, ou sur les côtés : rampe des
## plateaux des îles) : sinon la pente lui mange les jambes. Même place à l'écran, mais devant le relief.
func _slope_bias(p: Vector2) -> float:
	if _islands.islands.is_empty() or _islands.island_at(p, 0.0) < 0:
		return 0.0
	var h0 := _islands.ground_h(p)
	var rise := 0.0
	for dx in [-0.6, 0.0, 0.6]:
		for dz in [0.3, 0.8, 1.4]:
			rise = maxf(rise, _islands.ground_h(p + Vector2(dx, dz)) - h0)
	return clampf(rise * 1.6, 0.0, 1.8)


func _snap_node(node: Node3D, depth_bias: float = 0.0) -> void:
	var basis := _cam.global_transform.basis
	var right := basis.x
	var up := basis.y
	var g := node.global_position
	var d := g - _cam.global_position
	var dr := d.dot(right)
	var du := d.dot(up)
	var ppm := _ppm()
	g += right * (roundf(dr * ppm) / ppm - dr)
	g += up * (roundf(du * ppm) / ppm - du)
	g += basis.z * depth_bias   # vers la caméra : même place à l'écran (caméra orthogonale), mais devant le sol
	node.global_position = g


# ------------------------------------------------------------------ réseau : interface avec SailingNet


func local_player_state() -> Dictionary:
	var on_land: bool = _loc == Loc.LAND or (_loc == Loc.CLIMB and _climb.get("kind") == "hull")
	var code := 1 if on_land else (2 if _loc == Loc.CLIMB else (3 if _loc == Loc.NEST else (4 if _loc == Loc.HOLD else 0)))
	if _loc == Loc.SWIM:
		code = 5
	elif _loc == Loc.FLIGHT:
		code = 6
	elif _loc == Loc.RAFT:
		code = 7
	if _loc == Loc.CLIMB and _climb.get("kind") == "hull":
		code = 8   # lot 2 (4.4) : sur l'échelle de coque (les autres voient le pirate grimper, et non sauter)
	var pos := _hpos if _loc == Loc.HOLD else (_lpos if (on_land or code >= 5) else _ppos)
	var pz := float(_flight.get("y", 0.0)) if _loc == Loc.FLIGHT else _pz
	return {"pos": pos, "carry": _carry_code(), "loc": code, "pz": pz, "lh": _lh}


## Hôte : état du bateau diffusé aux clients.
func ship_state() -> Array:
	var mask := 0
	for i in _cannon_loaded.size():
		if _cannon_loaded[i]:
			mask |= 1 << i
	return [_sim.position.x, _sim.position.y, _sim.yaw, _sim.speed, _sim.rudder, _sim.rudder_target,
			_sim.sail_level, _sim.sail_open, 1 if _sim.anchored else 0, mask, _helm_owner, _time,
			_hull.leaks, _hull.patched, _hull.water, _sim.sail_trim, _sim.wind_angle, _sim.sail_trim_target, _stash.duplicate(),
			_grap_state, _grap_hook.x, _grap_hook.y, _grap_target.x, _grap_target.y, Hook.kind_code(_grap_kind), _grap_owner]


## Client : reçoit l'état du bateau de l'hôte. La position et le cap servent de cible (recalage en
## douceur dans _correct_from_host) ; le reste est appliqué tel quel.
func apply_ship_state(s: Array) -> void:
	if _ship == null or s.size() < 26:
		return
	_stash = (s[18] as Array).duplicate()
	if _grap_state == 0 and int(s[19]) != 0:   # le crochet vient de partir : son lancer sert à tracer l'arc
		_grap_total = maxf(Vector2(float(s[19 + 1]), float(s[19 + 2])).distance_to(Vector2(float(s[22]), float(s[23]))), 1.0)
	_grap_state = int(s[19])
	_grap_hook = Vector2(float(s[20]), float(s[21]))
	_grap_target = Vector2(float(s[22]), float(s[23]))
	_grap_kind = Hook.kind_of_code(int(s[24]))
	_grap_owner = int(s[25])
	_hull.apply_state(int(s[12]), int(s[13]), float(s[14]))
	_sim.sail_trim = float(s[15])
	_sim.wind_angle = float(s[16])
	_sim.wind_dir = Vector2.from_angle(_sim.wind_angle)
	_sim.sail_trim_target = float(s[17])
	_net_target = {"pos": Vector2(float(s[0]), float(s[1])), "yaw": float(s[2]), "age": 0.0}
	_sim.speed = float(s[3])
	_sim.rudder = float(s[4])
	_sim.rudder_target = float(s[5])
	_sim.sail_level = int(s[6])
	_sim.sail_open = float(s[7])
	_sim.anchored = int(s[8]) == 1
	var mask := int(s[9])
	for i in _cannon_loaded.size():
		_cannon_loaded[i] = ((mask >> i) & 1) == 1
	_helm_owner = int(s[10])
	var offset := float(s[11]) - _time
	_time_offset = offset if absf(offset - _time_offset) > 1.0 else lerpf(_time_offset, offset, 0.1)


## Client : rapproche en douceur le bateau prédit localement de l'état de l'hôte (extrapolé depuis
## sa réception). Un grand écart (plusieurs mètres) est corrigé d'un coup.
func _correct_from_host(delta: float) -> void:
	if _net_target.is_empty():
		return
	_net_target["age"] = float(_net_target["age"]) + delta
	var yaw: float = _net_target["yaw"]
	var target: Vector2 = _net_target["pos"] + Vector2(cos(yaw), -sin(yaw)) * _sim.speed * _sim.screen_comp() * float(_net_target["age"])
	if _sim.position.distance_to(target) > 6.0:
		_sim.position = target
		_sim.yaw = yaw
		return
	var k := 1.0 - exp(-delta * 6.0)
	_sim.position = _sim.position.lerp(target, k)
	_sim.yaw = lerp_angle(_sim.yaw, yaw, k)


func apply_remote_player(id: int, pos: Vector2, carry: String, loc: int, pz: float, lh: float = 0.0) -> void:
	if _ship == null:
		return
	if not _remotes.has(id):
		_add_remote(id, pos)
	var r: Dictionary = _remotes[id]
	if int(r["loc"]) != loc:
		r["loc"] = loc
		r["pos"] = pos
		r["prev"] = pos
		var holder: Node3D = _hold if loc == 4 else _ship
		for key in ["sprite", "blob"]:
			var n := r[key] as Node3D
			if n.get_parent() != holder:
				n.reparent(holder, false)
	r["target"] = pos
	# lot 2 (2.3) : il saute ou se réceptionne : même petit écrasement, même son que chez lui
	var was_up := float(r.get("pz", 0.0)) > 0.05
	var up := pz > 0.05 and (loc == 0 or loc == 1)
	if up and not was_up:
		_squash_sprite(r["sprite"], "jump")
		_sfx.play_at(Synth.jump(), (r["sprite"] as Node3D).global_position, 0.5)
	elif was_up and not up and (loc == 0 or loc == 1):
		_squash_sprite(r["sprite"], "land")
		r["land_t"] = 0.14
		_sfx.play_at(Synth.land(loc == 0), (r["sprite"] as Node3D).global_position, 0.6)
	r["pz"] = pz
	r["lh"] = lh
	# lot 2 (2.4) : ce qu'il porte, entre ses mains, tel qu'il l'a (boulet, planche ou le trésor lui-même)
	(r["ball"] as MeshInstance3D).visible = false
	(r["plank"] as MeshInstance3D).visible = false
	_set_remote_carry(id, carry)


## Le pseudo en petit, au-dessus de la tête d'un pirate : toujours de face, visible même derrière un décor, vide = rien.
func _make_name_tag(text: String) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.visible = text != ""
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 32
	l.pixel_size = 0.0075
	l.modulate = Color(1.0, 0.96, 0.85)
	l.outline_size = 8
	l.outline_modulate = Color(0.08, 0.04, 0.02)
	l.no_depth_test = true
	l.position = Vector3(0.0, 2.35, 0.0)
	return l


func _set_name_tag(tag: Label3D, text: String) -> void:
	if tag != null and tag.text != text:
		tag.text = text
		tag.visible = text != ""


func _add_remote(id: int, pos: Vector2) -> void:
	var sprite := PirateSprite.new()
	_ship.add_child(sprite)   # d'abord dans la scène : set_look peut finir tout de suite (feuille déjà en cache) et la boussole a besoin de la transformation globale
	sprite.enable_actions()   # on doit voir ses tirs, ses pouvoirs et ses coups de sabre
	sprite.set_look(_remote_looks.get(id, PirateLook.random_look(id)))
	_apply_held(sprite, str(_remote_held.get(id, "")))
	var tag := _make_name_tag(str(_remote_names.get(id, "")))
	tag.name = "NameTag"
	sprite.add_child(tag)
	var ball := _make_ball(0.14, Color(0.12, 0.12, 0.16))
	ball.visible = false
	sprite.add_child(ball)
	ball.position = Vector3(0.0, 2.2, 0.0)
	var plank := _plank_icon.duplicate() as MeshInstance3D
	plank.visible = false
	sprite.add_child(plank)
	var blob := _blob.duplicate() as MeshInstance3D
	_ship.add_child(blob)
	_remotes[id] = {"sprite": sprite, "blob": blob, "ball": ball, "plank": plank, "pos": pos, "target": pos, "prev": pos, "loc": 0, "pz": 0.0}


func _update_remotes(delta: float) -> void:
	var k := 1.0 - exp(-delta * 12.0)
	for id in _remotes:
		var r: Dictionary = _remotes[id]
		var p: Vector2 = (r["pos"] as Vector2).lerp(r["target"], k)
		r["pos"] = p
		var pz: float = r["pz"]
		var sprite := r["sprite"] as Node3D
		var blob := r["blob"] as MeshInstance3D
		if int(r["loc"]) == 4:
			sprite.global_position = _hold.point(p, 0.02)
			blob.global_position = _hold.point(p, 0.07)
		elif int(r["loc"]) == 1 or int(r["loc"]) == 8:   # (8 : sur l'échelle de coque, position comme à terre)
			var rlh: float = r.get("lh", 0.0)
			sprite.global_position = _land_point(p, 0.02 + pz + rlh)
			blob.global_position = _land_point(p, 0.04 + rlh)
		elif int(r["loc"]) == 5:   # à la nage : buste hors de l'eau
			var wl := SEA_Y + _wave_height(p)
			sprite.global_position = _land_point(p, wl - SWIM_DEPTH + sin(_time * 3.4 + float(id)) * 0.05)
			blob.global_position = _land_point(p, wl + 0.03)
		elif int(r["loc"]) == 6:   # tiré du canon : pz porte l'altitude
			sprite.global_position = _land_point(p, pz)
			blob.global_position = _land_point(p, SEA_Y + 0.04)
		elif int(r["loc"]) == 7:   # sur son radeau : p est l'endroit où il se tient
			var rdeck := SEA_Y + _wave_height(p) * 0.9 + Raft.TOP
			sprite.global_position = _land_point(p, rdeck + 0.02)
			blob.global_position = _land_point(p, rdeck + 0.04)
		else:
			var up := pz if int(r["loc"]) == 3 else 0.0
			sprite.global_position = _ship_point(p, 0.02 + pz)
			blob.global_position = _ship_point(p, 0.04 + up)
		blob.visible = int(r["loc"]) != 2 and int(r["loc"]) != 5 and int(r["loc"]) != 7 and int(r["loc"]) != 8


## Mon apparence : celle de l'éditeur (sauvegardée), sinon celle par défaut.
func _local_look() -> Dictionary:
	if _my_look.is_empty():
		_my_look = PirateLook.load_saved()
		if _args.has("look-seed"):   # essai : --look-seed=42 donne au pirate un look reconnaissable (sans toucher à celui sauvegardé)
			_my_look = PirateLook.random_look(int(_args["look-seed"]))
	return _my_look


## Vrai si je suis un client d'une partie en ligne (le bateau n'est pas le mien).
func _is_client() -> bool:
	return _net != null and _net.active and not _net.is_host


## Les couleurs du bateau, à envoyer à l'équipage (hôte).
func skin_json() -> String:
	return JSON.stringify(_ship_skin if not _ship_skin.is_empty() else ShipSkin.sanitize(_profile.ship_skin))


## Client : reçoit les couleurs du bateau de l'hôte (avant ou après l'arrivée à bord).
func apply_ship_skin_json(json: String) -> void:
	var parsed: Variant = JSON.parse_string(json)
	if not (parsed is Dictionary):
		return
	_ship_skin = ShipSkin.sanitize(parsed)
	if _ship != null:
		ShipSkin.apply(_ship, _ship_skin)


## « arme|skin » de ce que je tiens en main : envoyé aux autres joueurs avec mon apparence.
func _held_code() -> String:
	var w := _shown_weapon()
	return "%s|%s" % [w, _profile.skin_of(w)]


## L'arme visible dans la main : la principale, ou la secondaire pendant quelques secondes après un clic droit.
func _shown_weapon() -> String:
	if _hand_wid != "" and _hand_t > 0.0 and _profile.weapons.has(_hand_wid):
		return _hand_wid
	return _profile.weapon


## Met dans la main d'un sprite l'arme décrite par « arme|skin » (vide : rien).
func _apply_held(sprite: PirateSprite, code: String) -> void:
	var p := code.split("|")
	if p.size() == 2 and Weapons.exists(p[0]) and WeaponSkins.exists(p[0], p[1]):
		sprite.set_weapon(p[0], p[1])


## Chaque image : l'arme en main (et son skin) se voit sur mon pirate ; si elle change, les autres joueurs la voient aussi.
func _sync_held_weapon() -> void:
	if _sprite == null:
		return
	_set_name_tag(_name_tag, PlayerName.value)
	var shown := _shown_weapon()
	_sprite.set_weapon(shown, _profile.skin_of(shown))
	var code := _held_code()
	if code != _held_sent:
		_held_sent = code
		if _net != null and _net.active:
			_net.broadcast_look()


## Mon apparence, à envoyer aux autres joueurs.
func local_look_json() -> String:
	var d: Dictionary = (_local_look() as Dictionary).duplicate(true)
	d["held"] = _held_code()
	d["name"] = PlayerName.value
	return JSON.stringify(d, "", true)


## Reçoit l'apparence d'un autre joueur.
func apply_remote_look(id: int, json: String) -> void:
	var parsed: Variant = JSON.parse_string(json)
	if not (parsed is Dictionary):
		return
	var look := PirateLook.sanitize(parsed)
	_remote_looks[id] = look
	_remote_held[id] = str((parsed as Dictionary).get("held", ""))
	_remote_names[id] = PlayerName.clean(str((parsed as Dictionary).get("name", "")))   # (nettoyé : ce qui vient du réseau n'est pas sûr)
	if _is_authority():
		_crew_roster()      # lot 8 (11.1) : il fait partie de l'équipage (même quand il sera absent)
		_pay_pending(id)    # … et touche les parts gagnées pendant son absence
	if _remotes.has(id):
		_set_name_tag(_remotes[id]["sprite"].get_node_or_null("NameTag") as Label3D, str(_remote_names[id]))
		var rs := _remotes[id]["sprite"] as PirateSprite
		rs.set_look(look)
		_apply_held(rs, _remote_held[id])


## Donne au filtre « palette » les couleurs des pirates (elles changent quand l'apparence change).
func _sync_pirate_palette() -> void:
	if _post_mat == null:
		return
	PirateSprite.refresh_palette()   # refaite à partir des pirates affichés (mon pirate d'abord), pas seulement allongée
	if _palette_version == PirateSprite.palette_version:
		return
	_palette_version = PirateSprite.palette_version
	_post_mat.set_shader_parameter("char_palette", PirateSprite.palette_texture())
	_post_mat.set_shader_parameter("char_count", PirateSprite.palette_colors.size())


func _animate_pirates(delta: float) -> void:
	if _prev_ppos == Vector2.INF:
		_prev_ppos = _ppos
	var on_land: bool = _loc == Loc.LAND or _loc == Loc.SWIM or _loc == Loc.FLIGHT or (_loc == Loc.CLIMB and _climb.get("kind") == "hull")
	var was_land: bool = _prev_loc == Loc.LAND or _prev_loc == Loc.SWIM or _prev_loc == Loc.FLIGHT or (_prev_loc == Loc.CLIMB and _prev_land_climb)
	var in_hold: bool = _loc == Loc.HOLD
	var move := Vector2.ZERO
	if in_hold and _prev_hold:
		move = _hpos - _prev_hpos
	elif _loc == Loc.RAFT or _prev_loc == Loc.RAFT:
		move = Vector2.ZERO   # le radeau porte le pirate : il ne marche pas
	elif on_land and was_land:
		move = _lpos - _prev_lpos
	elif not on_land and not was_land and not in_hold and not _prev_hold:
		move = _screen_of_ship(_ppos - _prev_ppos)
	var helm_dir := _screen_of_ship(Vector2(1.0, 0.0))
	var air := 0
	if _jump_wind > 0.0:
		air = 3
	elif _pz > 0.03 and (_loc == Loc.SHIP or _loc == Loc.LAND):
		air = 1
	elif _land_t > 0.0:
		air = 2
	if _loc == Loc.FLIGHT:
		air = 1
	var climbing: bool = _loc == Loc.CLIMB
	# lot 2 (4.4) : sur l'échelle de coque aussi on grimpe (avant : un petit saut en arc), face à la coque
	var climb_face := helm_dir
	if _loc == Loc.CLIMB and _climb.get("kind") == "hull":
		climb_face = (_climb["to"] as Vector2) - (_climb["from"] as Vector2)
		if not bool(_climb.get("board", false)):
			climb_face = -climb_face   # en descendant vers le quai, on reste face au bateau
	_sprite.drive(delta, move, _carrying, _loc == Loc.SHIP and _mode == Mode.HELM, helm_dir, air, climbing, climb_face)
	_prev_ppos = _ppos
	_prev_lpos = _lpos
	_prev_hpos = _hpos
	_prev_hold = in_hold
	_prev_loc = _loc
	_prev_land_climb = on_land and _loc == Loc.CLIMB
	for id in _remotes:
		var r: Dictionary = _remotes[id]
		var p: Vector2 = r["pos"]
		var loc: int = r["loc"]
		var d := p - (r["prev"] as Vector2)
		var m := Vector2.ZERO if loc == 7 else (d if (loc == 1 or loc == 4 or loc >= 5) else _screen_of_ship(d))
		var rair := 1 if ((float(r["pz"]) > 0.05 and (loc == 0 or loc == 1)) or loc == 6) else 0
		r["land_t"] = maxf(float(r.get("land_t", 0.0)) - delta, 0.0)
		if rair == 0 and float(r["land_t"]) > 0.0:
			rair = 2   # lot 2 (2.3) : sa réception aussi
		var r_carry: bool = str(_remote_carry.get(id, "")) != ""
		var r_face := helm_dir if loc != 8 else (d if d.length() > 0.001 else Vector2(0, -1))
		(r["sprite"] as PirateSprite).drive(delta, m if loc != 8 else Vector2.ZERO, r_carry,
				loc == 0 and _helm_owner == id, helm_dir, rair, loc == 2 or loc == 8, r_face)
		r["prev"] = p


## Un joueur est parti : son pirate disparaît, et la barre se libère s'il la tenait.
func on_peer_left(id: int) -> void:
	_set_remote_water(id, 0)
	_remote_water.erase(id)
	_remote_downed.erase(id)
	_remote_dead.erase(id)
	_end_remote_act(id)
	_set_remote_carry(id, "")
	_remote_carry.erase(id)
	if _remotes.has(id):
		for key in ["sprite", "blob"]:
			(_remotes[id][key] as Node).queue_free()
		_remotes.erase(id)
	if _remote_rafts.has(id):
		(_remote_rafts[id] as Node).queue_free()
		_remote_rafts.erase(id)
	if _helm_owner == id:
		_helm_owner = 0
		_sim.rudder_target = 0.0
	_sim.trim_input = 0.0   # (si l'ami partant tenait les vergues)


## L'hôte est parti : on continue seul sur le bateau.
func on_host_left() -> void:
	for id in _remotes.keys():
		on_peer_left(id)
	_helm_owner = _my_id() if _mode == Mode.HELM else 0
	_net_target = {}


func on_peers_changed() -> void:
	pass


func _player_world() -> Vector3:
	if _loc == Loc.HOLD:
		return _hold.point(_hpos, 0.9)
	if _loc == Loc.SWIM:
		return _land_point(_lpos, SEA_Y + 0.9)
	if _loc == Loc.RAFT and _raft != null:
		return _land_point(_lpos, _raft.position.y + Raft.TOP + 0.9)
	if _loc == Loc.FLIGHT:
		return _land_point(_lpos, 0.9)
	if _loc == Loc.LAND or (_loc == Loc.CLIMB and _climb.get("kind") == "hull"):
		return _land_point(_lpos, 0.9 + (_lh if _loc == Loc.LAND else 0.0))
	return _ship_point(_ppos, 0.9)


## Ouvre le journal de quêtes (J) : les quêtes en cours, à rendre et terminées, avec le nom des îles connues.
func _open_quests() -> void:
	if _quest_panel.is_open() or _dialog.is_open() or _shop_menu.is_open() or _chart.is_open():
		return
	_quest_panel.open(_quests, func(island_id: String) -> String:
		for isl: Dictionary in _islands.islands:
			if str(isl["id"]) == island_id:
				var known := not bool(isl.get("proc", false)) or island_id in _profile.discovered
				return str(isl["name"]) if known else "une terre inconnue"
		return "une île inconnue")


## Ciel, météo, sons et vie des îles : on décrit la situation du joueur (où il est, s'il marche) et l'ambiance suit.
func _update_atmosphere(delta: float) -> void:
	if _atmo == null:
		return
	var where := "ship"
	var pos := _sim.position
	var kind := "ship"
	match _loc:
		Loc.LAND:
			where = "land"
			pos = _lpos
			kind = "land"
		Loc.SWIM, Loc.RAFT:
			where = "swim"
			pos = _lpos
			kind = "swim"
		Loc.HOLD:
			where = "hold"
		Loc.FLIGHT, Loc.CLIMB, Loc.NEST:
			where = "other"
	var moved := 0.0
	var walk_pos := pos
	if _loc == Loc.SHIP and _mode == Mode.WALK:
		walk_pos = _ppos * ShipModel.SCALE
	if (_loc == Loc.LAND or (_loc == Loc.SHIP and _mode == Mode.WALK)) and kind == _atmo_prev_kind and _pz <= 0.05:
		moved = walk_pos.distance_to(_atmo_prev)
		if moved > 1.5:
			moved = 0.0   # un saut de position (téléportation, changement de lieu) : pas des pas
	_atmo_prev = walk_pos
	_atmo_prev_kind = kind
	# l'ennemi est là : un bateau ennemi en chasse à moins de 120 m, ou un ennemi d'île éveillé tout près
	var battle := false
	var heat := 0.0   # l'ardeur du combat, pour la musique en couches : un navire compte selon son rang, un mob 0,15
	for es: Dictionary in _fleet.ships:
		if es["state"] == "chase" and (es["sim"] as ShipSim).position.distance_to(_sim.position) < 120.0:
			battle = true
			heat += 0.12 * float(es.get("rank", 1)) + 0.1
	if _loc == Loc.LAND:
		for en: IslandEnemy in _islands.enemies:
			if en.state != IslandEnemy.State.IDLE and en.state != IslandEnemy.State.DEAD and en.pos.distance_to(_lpos) < 12.0:
				battle = true
				heat += 0.15
	_music_heat = maxf(_music_heat - delta / GameConfig.MUSIC_HEAT_DECAY, 0.0)   # les coups reçus réchauffent, puis ça retombe
	_atmo.update(delta, {"pos": pos, "where": where, "speed": _sim.speed / maxf(_sim.max_speed, 0.1) * 8.0, "moved": moved,
			"face": _face, "focus": _cam_focus, "paused": _pause.is_open(), "battle": battle,
			"intensity": clampf(heat + _music_heat, 0.0, 1.0), "ground": _ground_kind(),
			"town": 1.0 - smoothstep(GameConfig.TOWN_SOUND_NEAR, GameConfig.TOWN_SOUND_FAR, pos.distance_to(GameConfig.TOWN_CENTER))})
	_apply_grade()
	_spawn_castaways()


## Sur quoi je marche, pour le bruit des pas (comme les jeux qui étiquettent leurs sols) : 0 sable, 1 herbe, 2 bois, 3 eau peu
## profonde, 4 pierre ; -1 : laisser l'ambiance décider (en mer, sur le radeau…). Au port : les pontons et les planchers des
## maisons sont en bois, le reste du quai et de la ville en pavés. Sur une île : sable près du rivage, herbe à l'intérieur.
func _ground_kind() -> int:
	if _loc == Loc.SHIP or _loc == Loc.HOLD:
		return 2
	if _loc != Loc.LAND:
		return -1
	var ii := _islands.island_at(_lpos)
	if ii >= 0:
		var s: float = _islands.sdf(ii, _lpos)
		if s < 0.2:
			return 3
		var tone := str((_islands.islands[ii] as Dictionary).get("tone", "lush"))
		return 0 if (s < GameConfig.SAND_BAND or tone == "dead") else 1
	if _land.interior_at(_lpos) >= 0:
		return 2
	var m := Vector2(_lpos.x, -_lpos.y)   # (repère du fichier du port)
	for k in range(1, _land.walk_rects.size()):   # le premier rectangle est le quai et la ville ; les suivants, les pontons
		var r: Array = _land.walk_rects[k]
		if m.x >= float(r[0]) and m.x <= float(r[2]) and m.y >= float(r[1]) and m.y <= float(r[3]):
			return 2
	return 4


## Envoie l'étalonnage du ciel (heure, météo) au filtre d'image ; dans la cale, l'image reste neutre.
func _apply_grade() -> void:
	if _post_mat == null:
		return
	var g: Dictionary = _atmo.sky.grade
	if g.is_empty() or _loc == Loc.HOLD or not _atmo.sky.enabled:
		g = {"tint": Vector3.ONE, "shadow": Vector3.ZERO, "high": Vector3.ZERO, "sat": 1.0, "contrast": 1.0,
				"vignette": 0.12, "haze_color": Vector3(0.8, 0.8, 0.8), "haze": 0.0}
	_post_mat.set_shader_parameter("grade_tint", g["tint"])
	_post_mat.set_shader_parameter("grade_shadow", g["shadow"])
	_post_mat.set_shader_parameter("grade_high", g["high"])
	_post_mat.set_shader_parameter("grade_sat", g["sat"])
	_post_mat.set_shader_parameter("grade_contrast", g["contrast"])
	_post_mat.set_shader_parameter("vignette", g["vignette"])
	_post_mat.set_shader_parameter("haze_color", g["haze_color"])
	_post_mat.set_shader_parameter("haze_amount", g["haze"])
	_post_mat.set_shader_parameter("flash", _atmo.sky.flash)


## Les naufragés des îles (camps tirés avec l'île) : leur PNJ naît quand l'île est posée dans le monde.
func _spawn_castaways() -> void:
	for i in _islands.islands.size():
		var isl: Dictionary = _islands.islands[i]
		if isl["node"] == null:
			continue
		for it: Dictionary in isl["lore_items"]:
			if it["kind"] != "castaway" or _castaways_made.has(int(it["seed"])):
				continue
			_castaways_made[int(it["seed"])] = true
			var info := IslandLore.castaway(int(it["seed"]))
			var yaw: float = it["yaw"]
			var p: Vector2 = it["pos"] + Vector2(sin(yaw), cos(yaw)) * 1.5   # devant son abri
			var d := {"id": "naufrage_%d" % int(it["seed"]), "name": info["name"], "role": "naufragé", "pos": [p.x, -p.y],
					"h": _islands.height(i, p), "facing": 0, "seed": int(it["seed"]), "parts": info["parts"], "lines": info["lines"]}
			var npc := TownNpc.from_data(d, false)
			_world_fixed.add_child(npc.sprite)
			npc.blob = _blob.duplicate() as MeshInstance3D
			_world_fixed.add_child(npc.blob)
			_quests.names[npc.id] = npc.display_name
			_npcs.append(npc)


## On ramasse une bouteille ou un journal : on lit le message, un peu d'or parfois, et un message « carte » révèle une île.
func _read_lore(it: Dictionary) -> void:
	var seed_value := int(it["seed"])
	var target := -1
	var target_name := ""
	if it["kind"] == "bottle":
		var here := _islands.island_at(_lpos, 2.0)
		var options: Array = []
		for j in _islands.islands.size():
			if j != here and _islands.chests_left(j) > 0 and not (_islands.islands[j]["id"] in _profile.discovered):
				options.append(j)
		if not options.is_empty():
			target = int(options[absi(hash(seed_value)) % options.size()])
			target_name = str(_islands.islands[target]["name"])
	var info := IslandLore.bottle(seed_value, target_name) if it["kind"] == "bottle" else IslandLore.journal(seed_value)
	_atmo.life.take_lore(it)
	_atmo.audio.play_chime()
	_dialog.start(str(info["title"]), info["lines"], false)
	if bool(info["map"]) and target >= 0:
		_profile.discovered.append(_islands.islands[target]["id"])
		_chart.discovered = _profile.discovered
		_destination = target
		_say("Nouvelle île sur ta carte : %s (cap fixé)" % target_name, 5.0)
	var gold := int(info["gold"])
	if gold > 0:
		_profile.gold += gold
		_say("+%d or" % gold, 3.0)
	_profile.save()


func _update_camera(delta: float) -> void:
	# La caméra suit le bateau (fixe à l'origine) plus le décalage du pirate sur le pont, en douceur.
	# Caméra au sous-pixel : la 3D est rendue avec une caméra calée sur la grille de pixels (donc pas
	# de scintillement), puis l'image finale est décalée de la fraction de pixel restante, à
	# l'échelle de l'écran. Les déplacements paraissent continus au lieu d'avancer par sauts de
	# 2 ou 3 pixels d'écran.
	_cam_offset = _cam_offset.lerp(_camera_target(), 1.0 - exp(-delta * 6.0))
	_elev_deg = lerpf(_elev_deg, SHOULDER_ELEV_DEG if _shoulder_active() else _elev_user, 1.0 - exp(-delta * 4.0))
	_cam.rotation = Vector3(-deg_to_rad(_elev_deg), _cam_yaw, 0.0)   # (_cam_yaw : cap de la caméra, tourné avec la molette)
	PirateSprite.view_yaw = _cam_yaw
	var el := deg_to_rad(_elev_deg)
	var focus_exact := Vector3(_ship.position.x, 1.2, _ship.position.z) + _cam_offset + _cam_sway
	if _args.has("cam-world"):  # diagnostic : regarder un point précis du monde (ex. la ville)
		var parts := str(_args["cam-world"]).split(",")
		focus_exact = Vector3(float(parts[0]) - _world_origin.x, 1.2, float(parts[1]) - _world_origin.z)
	var focus := _snap_ground(focus_exact)
	_cam_focus = focus
	_cam.position = focus + Basis(Vector3.UP, _cam_yaw) * Vector3(0, sin(el), cos(el)) * 60.0
	var off_xz := Vector2(focus_exact.x - focus.x, focus_exact.z - focus.z)
	var frac_px := Vector2(off_xz.dot(Vector2(cos(_cam_yaw), -sin(_cam_yaw))) * _ppm(),
			off_xz.dot(Vector2(sin(_cam_yaw), cos(_cam_yaw))) * sin(el) * _ppm())
	var shake := Vector2.ZERO
	if _shake_t > 0.0:   # secousse d'un choc : quelques pixels, qui s'éteignent
		_shake_t -= delta
		shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 5.0 * clampf(_shake_t / 0.4, 0.0, 1.0)
	_container.position = Vector2(-_factor, -_factor) - frac_px * float(_factor) + shake
	_sea.position = Vector3(snappedf(_world_origin.x + focus.x, 1.0), SEA_Y, snappedf(_world_origin.z + focus.z, 1.0))


## Où la caméra veut regarder : (x, hauteur, z) relatif au bateau, qui reste à l'origine. Dans la cale, c'est
## le pirate lui-même (la cale est posée loin au-dessus du monde).
func _camera_target() -> Vector3:
	if _loc == Loc.HOLD:
		var hp := _player_world()
		return Vector3(hp.x * 0.25, hp.y - 1.2, hp.z * 0.3 + 0.4)   # cadrage : la cale entière, qui suit un peu le pirate
	var rel := _player_world() - _ship.position
	# en haut du mât (échelle, nid de pie), la caméra monte avec le pirate ; pour un saut elle ne bouge pas
	var cam_h := _pz if (_loc == Loc.NEST or (_loc == Loc.CLIMB and _climb.get("kind") == "mast")) else 0.0
	if _loc == Loc.LAND:
		cam_h = _lh   # la caméra monte avec le pirate (terrasse, escalier, étage)
	return Vector3(rel.x, cam_h, rel.z)


## Place la caméra d'un coup sur sa cible (changement d'étage : pas de glissement de 40 m).
func _snap_camera() -> void:
	_cam_offset = _camera_target()


## Cale une position au sol sur la grille de pixels de l'écran (x : 1 px ; z : 1 px vertical).
func _snap_ground(v: Vector3) -> Vector3:
	var grid_x := 1.0 / _ppm()
	var grid_z := 1.0 / (_ppm() * sin(deg_to_rad(_elev_deg)))
	# la grille suit la caméra (qui peut avoir tourné) : on cale la position dans ses axes (droite, bas de l'écran)
	var right := Vector2(cos(_cam_yaw), -sin(_cam_yaw))
	var down := Vector2(sin(_cam_yaw), cos(_cam_yaw))
	var g := Vector2(v.x, v.z)
	var u := snappedf(g.dot(right), grid_x)
	var w := snappedf(g.dot(down), grid_z)
	var snapped_xz := right * u + down * w
	return Vector3(snapped_xz.x, v.y, snapped_xz.y)


# ------------------------------------------------------------------ interactions


## Portée (unités du modèle), cône de vue (cosinus de l'angle maxi entre mon regard et la direction de l'objet) et
## hauteur de la flèche par poste : on n'actionne un poste que de près ET en lui faisant face, pour que deux postes
## voisins (la barre et un canon, par exemple) ne se marchent jamais dessus.
const INTERACT_PARAMS := {
	"helm": {"reach": 1.55, "cone": 0.45, "h": 2.0},
	"mast": {"reach": 1.15, "cone": 0.6, "h": 2.1},
	"cannon": {"reach": 1.15, "cone": 0.7, "h": 1.7},
	"crate": {"reach": 1.25, "cone": 0.6, "h": 1.6},
	"stash": {"reach": 1.3, "cone": 0.6, "h": 1.5},
	"grapple": {"reach": 2.2, "cone": 0.0, "h": 1.7, "bias": 0.8},   # large et sans cône : pas besoin de viser le canon pour le prendre
	"ammo": {"reach": 1.15, "cone": 0.65, "h": 1.5},
	"anchor": {"reach": 1.3, "cone": 0.65, "h": 1.5},
	"ladder": {"reach": 1.15, "cone": 0.6, "h": 1.7},
	"mastladder": {"reach": 1.0, "cone": 0.6, "h": 2.0},
	"hatch": {"reach": 1.1, "cone": 0.0, "h": 1.2},
	"chart": {"reach": 1.4, "cone": 0.3, "h": 1.7},
}
const INTERACT_DEFAULT := {"reach": 1.2, "cone": 0.6, "h": 1.6}
const TARGET_FACING_WEIGHT := 9.0   ## poids de l'angle de visée dans le choix du poste (la distance seule ne suffit pas)
const TARGET_STICKY := 1.35         ## le poste visé ne change que si un autre est nettement meilleur (évite le va-et-vient)


## Le poste du pont que E actionnerait : à portée ET devant moi (voir INTERACT_PARAMS), le mieux placé si plusieurs.
func _compute_target() -> Dictionary:
	if _loc != Loc.SHIP or _mode != Mode.WALK or _pz > 0.05 or _jump_wind > 0.0:
		return {}
	return pick_target(_interactables, _ppos, _pface, _target)


## Choisit parmi `posts` le poste que E actionnerait depuis `pos` en regardant vers `face` : à portée, dans le
## cône de vue, le mieux placé ; `current` (le poste déjà visé) est gardé tant qu'un autre n'est pas nettement meilleur.
static func pick_target(posts: Array, pos: Vector2, face: Vector2, current: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score := INF
	var kept_score := INF   # le score du poste déjà visé, s'il est toujours valide
	for it: Dictionary in posts:
		var p: Dictionary = INTERACT_PARAMS.get(it["kind"], INTERACT_DEFAULT)
		var to: Vector2 = (it["pos"] as Vector2) - pos
		var d := to.length()
		if d > float(p["reach"]):
			continue
		var dot := 1.0 if d < 0.2 else face.dot(to / d)
		if dot < float(p["cone"]):
			continue
		var score := d * (1.0 + TARGET_FACING_WEIGHT * (1.0 - dot)) * float(p.get("bias", 1.0))
		if it == current:
			kept_score = score
		if score < best_score:
			best_score = score
			best = it
	# stabilité : tant que le poste visé reste valide, un autre ne le remplace que s'il est nettement meilleur
	if not current.is_empty() and kept_score < INF and kept_score <= best_score * TARGET_STICKY:
		return current
	return best


func _nearest_interactable() -> Dictionary:
	return _target


## Un anneau doré posé sur le pont à chaque poste (coffre, barre, caisse, échelle…) : on les repère de loin, et celui qui est
## visé s'élargit et brille. Les anneaux sont créés au fil de l'eau (certains postes s'ajoutent après la construction).
func _update_post_rings() -> void:
	if _ship == null:
		return
	if _ring_mat == null:
		_ring_mat = _ring_material(Color(1.0, 0.82, 0.3, 0.5))
		_ring_mat_hot = _ring_material(Color(1.0, 0.95, 0.55, 0.95))
	while _post_rings.size() < _interactables.size():
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.34
		torus.outer_radius = 0.44
		torus.rings = 24
		torus.ring_segments = 6
		ring.mesh = torus
		ring.scale = Vector3(1.0, 0.2, 1.0)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ship.add_child(ring)
		_post_rings.append(ring)
	var show := _loc == Loc.SHIP and _mode == Mode.WALK
	var pulse := 0.5 + 0.5 * sin(_time * 3.2)
	_ring_mat.albedo_color.a = 0.35 + 0.25 * pulse
	for i in _post_rings.size():
		var ring := _post_rings[i] as MeshInstance3D
		if i >= _interactables.size():
			ring.visible = false   # (le bateau a changé : il y a moins de postes qu'avant)
			continue
		var it: Dictionary = _interactables[i]
		var pos: Vector2 = it["pos"]
		var near := show and pos.distance_to(_ppos) < 6.0
		ring.visible = near
		if not near:
			continue
		var hot: bool = not _target.is_empty() and _target.get("pos") == pos and _target.get("kind") == it["kind"]
		ring.material_override = _ring_mat_hot if hot else _ring_mat
		var s := (1.35 + 0.15 * pulse) if hot else 1.0
		ring.scale = Vector3(s, 0.2, s)
		ring.position = _ship.to_local3(pos, 0.06)


func _ring_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.render_priority = 2
	return m


## Désigne l'objet visé par la flèche jaune.
func _update_target(delta: float) -> void:
	var blocked := _chart.is_open() or _pause.is_open() or _dialog.is_open() or _shop_menu.is_open() or _inventory.is_open() or _quest_panel.is_open()
	_target = {} if blocked else _compute_target()
	_update_post_rings()
	if _target_marker == null:
		return
	_target_marker.visible = not _target.is_empty()
	if _target.is_empty():
		return
	var p: Dictionary = INTERACT_PARAMS.get(_target["kind"], INTERACT_DEFAULT)
	var spot: Vector3 = _ship.to_local3(_target["pos"] as Vector2, float(p["h"]))
	if _target["kind"] == "cannon":
		spot = (_cannon_nodes[int(_target["index"])]["root"] as Node3D).position + Vector3(0.0, float(p["h"]) - 0.1, 0.0)
	_target_marker.position = spot + Vector3(0.0, 0.09 * sin(_time * 6.0), 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if _ship == null:
		return
	# molette enfoncée + souris : gauche/droite fait tourner la caméra autour du pirate, haut/bas l'incline (vue plus plongeante ou
	# plus rasante, entre CAM_ELEV_MIN et CAM_ELEV_MAX). TROIS clics rapides sur la molette remettent la vue de base (12/11 : un
	# simple clic le faisait, et on se retrouvait « perdu » en cliquant par mégarde).
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_MIDDLE:
		_cam_drag = (event as InputEventMouseButton).pressed
		if _cam_drag:
			_cam_drag_moved = 0.0
		elif _cam_drag_moved < 4.0:
			var now := Time.get_ticks_msec() / 1000.0
			_mid_clicks = (_mid_clicks + 1) if now - _mid_click_t < GameConfig.CAM_RESET_CLICK_GAP else 1
			_mid_click_t = now
			if _mid_clicks >= 3:
				_mid_clicks = 0
				_cam_yaw = 0.0
				_elev_user = ELEVATION_DEG
				_say("Vue de base", 1.5)
		return
	if event is InputEventMouseMotion and _cam_drag:
		var rel := (event as InputEventMouseMotion).relative
		_cam_drag_moved += absf(rel.x) + absf(rel.y)
		_cam_yaw = wrapf(_cam_yaw - rel.x * 0.008, -PI, PI)
		_elev_user = clampf(_elev_user + rel.y * 0.15, GameConfig.CAM_ELEV_MIN, GameConfig.CAM_ELEV_MAX)
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		# le grappin en main : le clic gauche lance le crochet vers le pointeur
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _hook_aim and _hook_can_aim():
			_hook_fire()
		# au canon : clic gauche tire, clic droit lâche le canon
		elif mb.pressed and _gun_i >= 0 and mb.button_index == MOUSE_BUTTON_LEFT:
			_gun_fire()
		elif mb.pressed and _gun_i >= 0 and mb.button_index == MOUSE_BUTTON_RIGHT:
			_gun_leave()
		# le grappin en main : le clic droit le range ; accroché : clic gauche = haler / ramener, clic droit = décrocher
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT and _hook_aim:
			_hook_aim = false
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT) and _grap_state != 0 \
				and _loc == Loc.SHIP and _mode == Mode.WALK and _ppos.distance_to(_grapple_mount()) < 3.6:
			_hook_interact(mb.button_index == MOUSE_BUTTON_RIGHT)
		# à terre, le clic gauche frappe vers le pointeur (l'écran est centré sur le pirate)
		# à terre, le clic droit frappe ou tire avec l'arme secondaire (vers le pointeur aussi)
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT) and _loc == Loc.LAND:
			_aim_at_click(mb.position)   # le coup ou le tir part vers l'endroit cliqué
			_try_attack(mb.button_index == MOUSE_BUTTON_RIGHT)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_user = clampf(_zoom_user * 1.12, 0.55, 1.9)   # molette : on se rapproche
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_user = clampf(_zoom_user / 1.12, 0.55, 1.9)   # on s'éloigne
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if _quest_panel.is_open():   # le journal de quêtes : J ou Échap le referme
		DisplaySettings.window_scale_key(key.physical_keycode)
		if key.physical_keycode == KEY_ESCAPE or key.physical_keycode == KEY_J:
			_quest_panel.close()
		return
	if _pause.is_open():   # le menu Échap : Échap le referme, le reste attend les clics
		if key.physical_keycode == KEY_ESCAPE:
			_pause.close()
		return
	if _inventory.is_open():   # le sac ouvert prend les touches
		_inventory.key(key.physical_keycode)
		return
	if _chart.is_open():   # la carte déployée prend les touches
		_chart.key(key.physical_keycode)
		return
	if _shop_menu.is_open():   # chez un boutiquier : le menu prend toutes les touches
		_shop_menu.key(key.physical_keycode)
		return
	if _dialog.is_open():   # pendant un dialogue : E continue, R refuse, le reste attend
		if key.physical_keycode == KEY_E:
			_dialog.confirm()
		elif key.physical_keycode == KEY_R:
			_dialog.refuse()
		return
	# une action longue en cours : une touche d'action la coupe (et ne fait rien d'autre cette fois)
	if _act != null and key.physical_keycode in [KEY_E, KEY_R, KEY_F, KEY_SPACE, KEY_G, KEY_1, KEY_2, KEY_3, KEY_4]:
		_cancel_action()
		return
	if key.physical_keycode == KEY_ESCAPE:
		_toggle_pause()
	elif key.physical_keycode == KEY_G:
		_drop_to_ground()   # lot 2 (2.4) : poser au sol ce que je porte
	elif key.physical_keycode == KEY_J:
		_open_quests()
	elif key.physical_keycode == KEY_TAB:
		_toggle_inventory()
	elif key.physical_keycode == KEY_X:
		_cycle_weapon()
	elif key.physical_keycode == KEY_T:
		_try_unstick()
	elif key.physical_keycode == KEY_V:
		_shoulder = not _shoulder
		_say("Vue épaule : V pour revenir à la vue normale" if _shoulder else "Vue normale", 2.0)
	elif key.physical_keycode == KEY_M and key.shift_pressed and _atmo != null:   # (12/11 : M seul sert au vol d'essai)
		_say("Son coupé : Maj+M pour le remettre" if _atmo.toggle_mute() else "Son remis", 2.0)
	elif key.physical_keycode == KEY_M:
		_toggle_fly()
	elif key.physical_keycode == KEY_B:
		_toggle_compass()
	elif key.physical_keycode == KEY_I:
		_toggle_invite()
	elif key.physical_keycode == KEY_E:
		_interact(false)
	elif key.physical_keycode == KEY_R:
		_interact(true)
	elif key.physical_keycode == KEY_SPACE:
		_try_jump()
	elif key.physical_keycode == KEY_F:
		if _loc == Loc.LAND:
			_aim_at_click(get_viewport().get_mouse_position())   # comme au clic : vers le pointeur
		_try_attack()
	elif key.physical_keycode >= KEY_1 and key.physical_keycode <= KEY_4:
		_try_cast(key.physical_keycode - KEY_1)


## L'objet de la cale le plus proche : échelle, étagère, seau, ou voie d'eau ouverte.
func _hold_nearest() -> Dictionary:
	var best: Dictionary = {}
	var best_d := INTERACT_RANGE
	for it: Dictionary in _hold_items:
		if it["kind"] == "hole" and not _hull.has_leak(int(it["slot"])):
			continue
		var d := _hpos.distance_to(it["pos"] as Vector2)
		if d < best_d:
			best_d = d
			best = it
	return best


func _interact_hold(secondary: bool) -> void:
	var it := _hold_nearest()
	_dbg("cale : E près de %s (eau %.2f)" % [str(it.get("kind", "rien")), _hull.water])
	if it.is_empty():
		return
	if secondary and it["kind"] != "rack":
		return
	match it["kind"]:
		"ladder":
			_leave_hold()
		"rack":
			_interact_rack(secondary)
		"bucket":
			if _hull.water > 0.0:
				_start_action("bail", "Écoper")   # lot 2 (4.3) : remplir le seau, puis le vider ; l'eau baisse à la fin
			else:
				_say("La cale est sèche", 2.0)
		"hole":
			if _carry_kind == "plank":
				_start_action("repair", "Clouer la planche", int(it["slot"]))   # lot 2 (4.2) : la voie d'eau est bouchée à la fin
			else:
				_say("Il te faut une planche : l'étagère est au fond, à l'arrière")


## L'étagère de la cale : E prend une planche, R prend un boulet ; avec une planche ou un boulet en main, E ou R le range.
## (Les mêmes réserves que la caisse du pont : on prend et on dépose en haut comme en bas.)
func _interact_rack(secondary: bool) -> void:
	if _carry_kind == "ball" or _carry_kind == "plank":
		_say("Rangé sur l'étagère : %s" % ("un boulet" if _carry_kind == "ball" else "une planche"), 2.0)
		_put_supply(_carry_kind)
		_drop_carried()
		return
	if _carrying:
		_say("L'étagère ne prend que des boulets et des planches", 3.0)
		return
	var kind := "ball" if secondary else "plank"
	if _profile.take_supply(kind):
		_start_carry(kind)
	else:
		_say("Plus de %s : rachètes-en au Magasin Général" % ("boulets" if secondary else "planches"), 3.5)


## Éclaboussure dans la cale quand on écope.
func _splash_bucket() -> void:
	var drop := _make_ball(0.09, Color(0.7, 0.88, 1.0))
	(drop.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hold.add_child(drop)
	drop.global_position = _hold.point(_hpos, 1.4)
	var tw := drop.create_tween()
	tw.set_parallel(true)
	tw.tween_property(drop, "global_position", _hold.point(_hpos + Vector2(0.0, -1.0), 2.2), 0.35)
	tw.tween_property(drop, "scale", Vector3.ZERO, 0.35)
	tw.chain().tween_callback(drop.queue_free)


func _interact(secondary: bool) -> void:
	if _loc == Loc.CLIMB or _loc == Loc.FLIGHT or _is_down() or _is_dead():
		return
	if not secondary and _loc == Loc.SWIM and _try_siren():
		return   # lot 4 (5.6) : la sirène me ramène à bord
	if not secondary and (_loc == Loc.LAND or (_loc == Loc.SHIP and _mode == Mode.WALK)):
		var downed := _revive_candidate()
		if downed != 0:   # lot 4 (5.2) : relever un camarade à terre
			_start_action("revive", "Relever %s" % _remote_label(downed), downed)
			return
	if _hook_interact(secondary):
		return   # le grappin en main (ou accroché) a la priorité : E lance ou s'attire, R range ou décroche
	if _gun_i >= 0:   # on vise au canon : E tire, R lâche
		if secondary:
			_gun_leave()
		else:
			_gun_fire()
		return
	if _loc == Loc.RAFT:
		if not secondary:
			_leave_raft(false)
		return
	if _loc == Loc.SWIM:
		if not secondary:
			if not _try_board_raft_from_water():
				_try_board_from_water()
		return
	if _loc == Loc.HOLD:
		_interact_hold(secondary)
		return
	if _loc == Loc.NEST:
		if not secondary:
			_start_mast_climb(false)
		return
	if _loc == Loc.LAND:
		var npc := _nearest_npc()
		if npc != null:
			if npc.id == "corbin":
				_talk_fence(npc)
			else:
				_talk(npc)
		elif not secondary and _pick_up_ground_treasure():
			pass   # lot 2 (2.4) : on reprend le trésor posé à ses pieds
		elif not secondary:
			var chest := _islands.nearest_chest(_lpos)
			var berry := _islands.nearest_berry(_lpos)
			var lore: Dictionary = _atmo.life.nearest_lore(_lpos) if _atmo != null else {}
			if chest >= 0:
				if _carrying:
					_say("Tes mains sont prises : dépose d'abord ce que tu portes (coffre du capitaine, caisse)", 3.5)
				else:
					_request("chest", chest)
			elif not lore.is_empty():
				_read_lore(lore)
			elif berry >= 0:
				_pick_berry(berry)
			elif _outpost_interact():
				pass
			elif not _try_board_raft_from_land():
				_try_board()
		return
	if _mode == Mode.HELM:
		if not secondary:
			_leave_helm()
		return
	if _mode == Mode.SAILS:
		if secondary:
			_request("sail", -1)
		else:
			_leave_sails()
		return
	if _mode == Mode.CANNON:
		_leave_cannon(not secondary)
		return
	var swimmer := _hoist_candidate()
	if swimmer != 0 and not secondary:   # lot 2 (4.5) : un camarade à l'eau, à portée de bras : on le hisse
		_start_action("hoist", "Hisser %s" % _remote_label(swimmer), swimmer)
		return
	var it := _nearest_interactable()
	if it.is_empty():
		return
	match it["kind"]:
		"chart":
			if not secondary:
				_open_chart()
		"ladder":
			if not secondary:
				_try_disembark(int(it["index"]))
		"mastladder":
			if not secondary:
				_start_mast_climb(true)
		"helm":
			if not secondary and (_helm_owner == 0 or _helm_owner == _my_id()):
				_request("helm_take", 0)
				_enter_helm()
		"mast":
			if secondary:
				_request("sail", -1)
			else:
				_enter_sails(it)
		"anchor":
			if not secondary:
				_start_action("anchor", "Lever l'ancre" if _sim.anchored else "Jeter l'ancre")   # lot 2 (4.1) : au cabestan
		"hatch":
			if not secondary:
				_enter_hold()
		"ammo":
			_interact_crate(secondary, "ball")    # le tonneau de boulets : des boulets seulement
		"crate":
			_interact_crate(secondary, "plank")   # la caisse du pont : des planches seulement
		"stash":
			_interact_stash(secondary)
		"grapple":
			if not secondary:
				_hook_toggle()   # E au canon à grappin : prendre le grappin en main pour viser
		"cannon":
			var i: int = it["index"]
			if _cannon_loaded[i]:
				if not secondary:
					_gun_enter(i)   # E : on vise à la souris, clic gauche pour tirer
			elif _carry_kind == "ball" and not secondary:
				_request("load", i)
				_cannon_loaded[i] = true  # affichage immédiat ; l'hôte confirme dans son état
				_drop_carried()
				_gun_enter(i)
			elif not secondary:
				_gun_enter(i)   # vide, mains libres : on vise quand même (un clic le recharge depuis la caisse)
			elif secondary and not _carrying:
				_enter_cannon(i)   # R : on se glisse dans le canon, pour être tiré au loin


const SUPPLY_MAX := 99          ## boulets ou planches que la caisse peut contenir
const FENCE_RANGE := 36.0       ## m : le bateau doit être à quai à cette distance du receleur pour qu'il achète le coffre

## La caisse de provisions du pont : E prend un boulet (ou range ce qu'on porte), R prend une planche.
## Le tonneau de boulets ne donne et ne reprend que des boulets ; la caisse du pont, que des planches (12/11 : un tonneau de
## boulets qui donnait aussi des planches, ce n'était pas logique). `only` : "ball" ou "plank".
func _interact_crate(_secondary: bool, only: String = "plank") -> void:
	var what := "un boulet" if only == "ball" else "une planche"
	var where := "le tonneau de boulets" if only == "ball" else "la caisse à planches"
	if _carrying:
		if _carry_kind == only:
			_put_supply(_carry_kind)
			_say("Rangé dans %s : %s" % [where, what], 2.0)
			_drop_carried()
		elif _carry_kind == "ball" or _carry_kind == "plank":
			_say("Ça va dans %s" % ("le tonneau de boulets" if _carry_kind == "ball" else "la caisse à planches"), 3.0)
		else:
			_say("Les trésors vont dans le coffre du capitaine (cabine)", 4.0)
		return
	if _profile.take_supply(only):
		_start_carry(only)
	else:
		_say("Plus de %s : rachètes-en au Magasin Général ou casse des tonneaux sur les îles" % ("boulets" if only == "ball" else "planches"), 4.0)


## Range un boulet ou une planche dans les réserves (la caisse).
func _put_supply(kind: String) -> void:
	if kind == "ball":
		_profile.balls = mini(_profile.balls + 1, SUPPLY_MAX)
	elif kind == "plank":
		_profile.planks = mini(_profile.planks + 1, SUPPLY_MAX)
	_profile.save()


## Le coffre du capitaine : E dépose le trésor qu'on porte, ou en ressort un quand on a les mains libres.
func _interact_stash(secondary: bool) -> void:
	if secondary:
		return
	if _carry_kind == "treasure":
		_request("stash_put", Treasure.index_of(_carry_item))
		_say("%s déposé dans le coffre du capitaine" % Treasure.name_of(_carry_item), 3.0)
		_drop_carried()
	elif _carrying:
		_say("Pose d'abord ce que tu portes", 2.5)
	elif _stash.is_empty():
		_say("Le coffre du capitaine est vide : rapporte-lui des trésors", 3.0)
	else:
		_request("stash_take", 0)


func _stash_text() -> String:
	if _stash.is_empty():
		return "Coffre du capitaine : vide"
	return "Coffre du capitaine : %d trésor(s), %d or au total" % [_stash.size(), Treasure.total_value(_stash)]


## Un trésor ou un objet qu'on me donne (butin, coffre du capitaine…) : « t:<id> », « ball », « plank » ou « g:<or> ».
func _give_item(peer: int, kind: String) -> void:
	if peer == _my_id():
		apply_item_got(kind)
	elif _net != null and _net.active:
		_net.send_item(peer, kind)


## J'ai reçu un objet : un trésor va dans mes bras (ou se change en or si je ne peux pas le porter), les boulets et
## planches vont dans la caisse, l'or dans ma bourse.
func apply_item_got(kind: String) -> void:
	var here := _my_world_pos()
	if kind.begins_with("t:"):
		var id := kind.substr(2)
		if not Treasure.exists(id):
			return
		if _carrying:
			var v := int(Treasure.value_of(id) * 0.5)
			_profile.gold += v
			_profile.save()
			_popup("+%d or (%s, mains prises)" % [v, Treasure.name_of(id)], here, Color(1.0, 0.85, 0.3))
		else:
			_pick_up_treasure(id)
	elif kind.begins_with("b:"):
		var bid := kind.substr(2)
		if BerryBook.exists(bid):
			_profile.add_berry(bid, 1)
			_popup("+1 %s" % BerryBook.berry_name(bid), here, BerryBook.color_of(bid))
			_say("%s ramassée : elle est dans ton sac (Tab), mange-la quand tu veux" % BerryBook.berry_name(bid), 5.0)
	elif kind == "ball" or kind == "plank":
		_put_supply(kind)
		_popup("+1 %s" % ("boulet" if kind == "ball" else "planche"), here, Color(0.85, 0.85, 0.95))
	elif kind.begins_with("g:"):
		var n := int(kind.substr(2))
		_profile.gold += n
		_profile.save()
		_popup("+%d or" % n, here, Color(1.0, 0.85, 0.3))
	elif kind.begins_with("n:"):   # sorti du coffre d'une cabane : « n:plank:5 »
		var parts := kind.split(":")
		if parts.size() == 3:
			_receive_supply(parts[1], int(parts[2]))
	_refresh_chest_ui()


## Où je suis dans le monde (x, z), quel que soit l'endroit.
func _my_world_pos() -> Vector2:
	if _loc == Loc.SHIP or _loc == Loc.NEST:
		return _ship_to_world(_ppos)
	if _loc == Loc.HOLD:
		return _sim.position
	return _lpos


## Parler au receleur : il rachète le trésor qu'on porte, ou tout le coffre du capitaine quand le bateau est à quai.
func _talk_fence(npc: TownNpc) -> void:
	npc.sprite.direction = PirateSprite.direction_of(_lpos - npc.pos)
	var lines: Array = []
	var offer := false
	var carried := Treasure.value_of(_carry_item) if _carry_kind == "treasure" else 0
	var ship_near := _sim.position.distance_to(npc.pos) <= FENCE_RANGE
	var stash_value := Treasure.total_value(_stash)
	if carried > 0:
		lines = ["%s ! Voilà qui brille. Je t'en offre %d pièces d'or, tout de suite." % [Treasure.name_of(_carry_item), carried]]
		offer = true
	elif stash_value > 0 and ship_near:
		lines = ["Ton coffre de capitaine déborde, matelot : %d trésor(s). Je prends tout pour %d pièces d'or, à partager avec ton équipage." % [_stash.size(), stash_value]]
		offer = true
	elif stash_value > 0:
		lines = ["Des trésors dans ta cabine ? Amarre-toi près du quai et reviens : je ne marche pas jusqu'au large."]
	else:
		lines = npc.lines
	_dialog_ctx = {"npc": npc, "offer": "", "turn_in": "", "sell": offer}
	_dialog.start(npc.display_name, lines, offer, "E : vendre     R : garder")


## J'ai accepté l'offre du receleur.
func _sell_to_fence() -> void:
	if _carry_kind == "treasure":
		# lot 8 (11.1) : même un trésor vendu depuis les bras se partage entre tout l'équipage (l'hôte fait le partage)
		var v := Treasure.value_of(_carry_item)
		_say("Vendu : %s, %d pièces d'or (partagées avec l'équipage)" % [Treasure.name_of(_carry_item), v], 4.0)
		_request("sell_hand", Treasure.index_of(_carry_item))
		_drop_carried()
	else:
		_request("sell_stash", 0)


## Hôte (lot 8, 11.1) : partage `total` pièces entre tout l'équipage : les présents reçoivent leur part tout de suite ; celle des
## absents (connus par leur pseudo : ils ont déjà navigué avec cet hôte) est mise de côté et versée à leur retour.
func _share_gold(total: int, seller: int, at: Vector2, why: String) -> void:
	var present := _crew_ids()
	var names := _crew_roster().keys()
	var absent: Array = []
	for n: String in names:
		var here := false
		for id in present:
			if _peer_name(int(id)) == n:
				here = true
		if not here:
			absent.append(n)
	var count := maxi(present.size() + absent.size(), 1)
	var share := int(total / count)
	var left := total - share * count
	for id in present:
		var amount := share + (left if int(id) == seller else 0)
		_give_loot(int(id), amount, at)
		_tell(int(id), "%s : ta part, %d pièces d'or" % [why, amount])
	if not absent.is_empty():
		var pending := _pending_shares()
		for n: String in absent:
			pending[n] = int(pending.get(n, 0)) + share
		_save_pending(pending)


## Le pseudo d'un joueur (moi compris).
func _peer_name(id: int) -> String:
	return PlayerName.value if id == _my_id() else str(_remote_names.get(id, ""))


## Hôte : les pseudos de tous ceux qui ont navigué dans cette partie (même partis depuis). En solo : moi seul.
func _crew_roster() -> Dictionary:
	if PlayerName.value != "":
		_roster[PlayerName.value] = true
	if _net == null or not _net.active:
		return {PlayerName.value: true}
	for id in _remotes:
		var n := _peer_name(int(id))
		if n != "":
			_roster[n] = true
	return _roster


func _pending_shares() -> Dictionary:
	return _pending


func _save_pending(d: Dictionary) -> void:
	_pending = d


## Hôte : un joueur (re)vient, son pseudo est connu : on lui verse les parts gagnées pendant son absence, et on le lui dit.
func _pay_pending(id: int) -> void:
	if not _is_authority():
		return
	var n := _peer_name(id)
	var pending := _pending_shares()
	var amount := int(pending.get(n, 0))
	if n == "" or amount <= 0:
		return
	pending.erase(n)
	_save_pending(pending)
	_give_loot(id, amount, _sim.position)
	_tell(id, "Pendant ton absence, l'équipage a vendu des trésors : ta part, %d pièces d'or" % amount)


## Un message à un seul joueur (moi : directement).
func _tell(id: int, text: String) -> void:
	if id == _my_id():
		_say(text, 5.0)
	elif _net != null and _net.active:
		_net.send_tell(id, text)


## Hôte : vend tout le coffre du capitaine si le bateau est à quai près du receleur ; l'or se partage entre l'équipage.
func _sell_stash(seller: int) -> void:
	var fence: TownNpc = null
	for n: TownNpc in _npcs:
		if n.id == "corbin":
			fence = n
	if fence == null or _stash.is_empty() or _sim.position.distance_to(fence.pos) > FENCE_RANGE + 6.0:
		return
	var total := Treasure.total_value(_stash)
	var crew := _crew_ids()
	_share_gold(total, seller, fence.pos, "Coffre vendu")   # lot 8 (11.1) : absents compris
	for id in crew:
		_give_rep(int(id), int(float(total) * Reputation.gain("treasure_per_gold")), "trésors vendus")   # chacun gagne autant que ce que le coffre valait
	_stash.clear()
	_notify_all("Coffre vendu : %d pièces d'or partagées avec tout l'équipage" % total)


## Envoie une action d'équipage : appliquée directement en solo ou chez l'hôte, demandée à
## l'hôte pour un client.
func _request(kind: String, value: int) -> void:
	if _net.active and not _net.is_host:
		_net.send_request(kind, value)
	else:
		apply_request(_my_id(), kind, value)


## Hôte (ou solo) : vérifie et applique une action d'un membre d'équipage. L'hôte fait autorité.
func apply_request(peer: int, kind: String, value: int) -> void:
	if _ship == null:
		return
	match kind:
		"chest":
			var gold := _islands.open_chest(value)
			if gold > 0:
				_give_loot(peer, gold, (_islands.chests[value] as Dictionary)["pos"])
				_give_rep(peer, int(Reputation.gain("chest")), "coffre ouvert")
				# et un trésor à rapporter : plus le coffre est gardé (gros magot), plus il peut être rare
				_give_item(peer, "t:" + Treasure.roll(_rng, maxf(float(gold) / 45.0, 0.6)))
		"helm_take":
			if _helm_owner == 0 or _helm_owner == peer:
				_helm_owner = peer
		"helm_leave":
			if _helm_owner == peer:
				_helm_owner = 0
				_sim.rudder_target = 0.0
		"rudder":
			if _helm_owner == peer:
				_sim.rudder_target = clampf(value / 100.0, -1.0, 1.0)
		"sail":
			_sim.change_sails(signi(value))
		"trim":
			_sim.trim_input = clampf(value / 100.0, -1.0, 1.0)
		"grapple":
			_grapple_fire(peer, value)
		"grapple_release":
			if _grap_owner == peer or _grap_owner == 0 or not (_remotes.has(_grap_owner) or _grap_owner == _my_id()):
				_grapple_release()
		"grapple_reel":   # ramener le butin accroché
			if _grap_state == 5 and _grap_kind == "loot":
				_grap_state = 2
		"grapple_haul":   # haler le bateau jusqu'à ce que le crochet tient (point fixe ou bateau ennemi)
			if _grap_state == 5 and (_grap_kind == "land" or _grap_kind == "enemy"):
				_grap_state = 3
				_notify_all("Le bateau est halé vers le crochet (E : arrêter, R : décrocher)")
		"grapple_pause":   # arrêter de haler : le crochet reste accroché, le bateau s'arrête
			if _grap_state == 3:
				_grap_state = 5
				_sim.speed = 0.0
		"loot_take":
			var taken := _loot.take(value)
			if taken != "":
				_give_item(peer, taken)
		"stash_put":
			var tid := Treasure.id_at(value)
			if tid != "":
				_stash.append(tid)
		"stash_take":
			if not _stash.is_empty():
				_give_item(peer, "t:" + str(_stash.pop_back()))
		"sell_stash":
			_sell_stash(peer)
		"sell_hand":   # lot 8 (11.1) : un trésor vendu depuis les bras, partagé comme le coffre
			var tid2 := Treasure.id_at(value)
			if tid2 != "":
				_share_gold(Treasure.value_of(tid2), peer, _sim.position, "Trésor vendu")
		"unstick":
			if _unstick_ship():
				_notify_all("Le bateau a été remis à l'eau libre")
			else:
				_notify_all("Aucune eau libre à proximité : « Ramener au port » dans le menu Échap")
		"tow":
			_tow_to_port()
		"human_fire":
			if value >= 0 and value < _cannon_nodes.size():
				if _net.active:
					_net.broadcast_fire(value, true)
				else:
					fire_visual(value, true)
		"anchor":
			_sim.anchored = not _sim.anchored
		"drop":   # lot 2 (2.4) : poser au sol ce qu'on porte (valeur : indice du trésor, -1 boulet, -2 planche)
			var dkind := "ball" if value == -1 else ("plank" if value == -2 else "t:" + Treasure.id_at(value))
			var dpos := Vector2.INF
			if peer == _my_id():
				dpos = _lpos if _loc == Loc.LAND else Vector2.INF
			elif _remotes.has(peer) and int(_remotes[peer]["loc"]) == 1:
				dpos = _remotes[peer]["target"]
			if dpos != Vector2.INF and dkind != "t:":
				_loot.spawn(dkind, dpos, GameConfig.DROPPED_TTL)
		"revive":   # lot 4 (5.2) : `peer` relève le camarade `value`
			if value == _my_id() and _is_down():
				_do_revive(value)
			elif value != _my_id() and _remotes.has(value):
				_do_revive(value)
		"hoist":   # lot 2 (4.5) : `peer` hisse le camarade `value` hors de l'eau
			var swimming := false
			if value == _my_id():
				swimming = _loc == Loc.SWIM
			elif _remotes.has(value):
				swimming = int(_remotes[value]["loc"]) == 5
			if swimming:
				_do_hoist(value)
		"patch":
			if _hull.patch(value):
				_refresh_hull_visuals()
		"bail":
			_hull.bail()
		"load":
			if value >= 0 and value < _cannon_loaded.size():
				_cannon_loaded[value] = true
		"fire":
			if value >= 0 and value < _cannon_loaded.size() and _cannon_loaded[value]:
				_cannon_loaded[value] = false
				if _net.active:
					_net.broadcast_fire(value)
				else:
					fire_visual(value)
		"aim_fire":   # tir visé : valeur = canon + 100 x (angle en degrés + 180)
			var gi := value % 100
			var aim := deg_to_rad(float(clampi(value / 100 - 180, -180, 180)))
			if gi >= 0 and gi < _cannon_loaded.size() and _cannon_loaded[gi]:
				_cannon_loaded[gi] = false
				if _net.active:
					_net.broadcast_fire(gi, false, aim)
				else:
					fire_visual(gi, false, aim)


func _my_id() -> int:
	return multiplayer.get_unique_id() if _net != null and _net.active else 1


## Tous les joueurs (moi compris), triés : la place dans cette liste donne la couleur du pirate.
func _crew_ids() -> Array:
	var ids: Array = [_my_id()]
	if _net != null and _net.active and multiplayer.multiplayer_peer != null:
		for p in multiplayer.get_peers():
			ids.append(p)
	ids.sort()
	return ids


func _enter_helm() -> void:
	var helm: Array = _ship.meta.get("helm", [0.0, 0.0])
	_mode = Mode.HELM
	_ppos = Vector2(float(helm[0]) - 0.55, float(helm[1]))
	_pface = Vector2(1.0, 0.0)
	_walkto = Vector2.INF


# ------------------------------------------------------------------ grappin

## Le grappin du bateau (canon à grappin de l'étrave : E pour le prendre en main). On VISE à la souris, dans toutes les directions (tirets
## et cercle : vert si le crochet saisirait quelque chose, rouge sinon), on LANCE (clic ou E) : le crochet file en ligne droite et
## s'accroche à la PREMIÈRE chose qu'il touche (voir Hook) — rivage, rocher, mur, tonneau, butin, bateau ennemi. Puis on CHOISIT : E
## haler le bateau jusqu'au crochet (ou ramener un butin), E de nouveau pour arrêter de haler, R décrocher. Rien ne se fait tout seul.

const GRAPPLE_MAX_ROPE := Hook.RANGE * 1.7   ## m : au-delà, la corde casse

var _grap_state := 0            ## 0 rangé, 1 en vol, 2 ramène un butin, 3 hale le bateau, 4 retour, 5 accroché (attend le choix de l'équipage)
var _grap_hook := Vector2.ZERO  ## position monde du crochet
var _grap_target := Vector2.ZERO
var _grap_total := 1.0          ## distance du lancer (pour l'arc du vol)
var _grap_kind := ""            ## ce que le crochet tient : « land » (point fixe), « loot », « ship », « enemy », « » (rien)
var _grap_loot := -1
var _grap_owner := 0            ## le pirate qui tient le grappin
var _grap_bp := Vector2.ZERO    ## hôte : le point d'accroche sur le bateau des joueurs (repère du bateau)
var _grap_enemy := -1           ## hôte : le bateau ennemi accroché
var _grap_off := Vector2.ZERO   ## hôte : le crochet par rapport au centre de ce bateau ennemi
var _rope: MeshInstance3D
var _hook_node: Node3D
var _hook_aim := false          ## le grappin est en main : je vise
var _hook_dir := Vector2.RIGHT  ## direction de visée (monde x/z)
var _hook_hit: Dictionary = {}  ## ce que le crochet saisirait dans cette direction (Hook.trace)
var _hook_line: MeshInstance3D
var _hook_assist_src := Vector2.ZERO   ## direction du pointeur quand l'aide à la visée a cherché pour la dernière fois
var _hook_assist_dir := Vector2.ZERO   ## direction trouvée par l'aide à la visée (zéro : aucune cible dans le cône)
var _hook_assist_t := -10.0
var _hook_mouse := Vector2.INF
var _hook_mouse_used := false
var _hk_water := false          ## sondage en cours : le tir a-t-il déjà survolé l'eau ?


## Où se tient le grappin (repère du bateau) : à l'avant, au dernier endroit où l'on peut encore se tenir debout.
func _grapple_mount() -> Vector2:
	var x := _ship.bow_x
	while x > 0.0 and not _ship.is_walkable(Vector2(x, 0.0)):
		x -= 0.15
	return Vector2(x + 0.4, 0.0)


## Le canon à grappin : un pied de bois, un tube de fonte pointé vers l'avant, un crochet de laiton à la bouche.
func _build_grapple_mount() -> void:
	var m := _grapple_mount()
	_interactables.append({"kind": "grapple", "pos": m})
	var root := Node3D.new()
	root.position = _ship.to_local3(m, 0.0)
	_ship.add_child(root)
	ShipCannons._box(root, Vector3(0.55, 0.5, 0.55), Vector3(-0.1, 0.25, 0.0), ShipCannons.CARRIAGE_D)
	ShipCannons._box(root, Vector3(0.4, 0.12, 0.7), Vector3(-0.1, 0.56, 0.0), ShipCannons.CARRIAGE)
	ShipCannons._cyl(root, 0.17, 0.2, 0.9, Vector3(0.28, 0.72, 0.0), "x", ShipCannons.IRON)
	ShipCannons._cyl(root, 0.23, 0.23, 0.08, Vector3(0.72, 0.72, 0.0), "x", ShipCannons.BRASS)
	var hook := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.15
	hm.height = 0.3
	hook.mesh = hm
	var hook_mat := StandardMaterial3D.new()
	hook_mat.albedo_color = ShipCannons.BRASS
	hook.material_override = hook_mat
	hook.position = Vector3(0.82, 0.72, 0.0)
	root.add_child(hook)


# --- sondes du tir : ce que le crochet peut saisir (voir Hook.trace) ---

func _hook_probes() -> Dictionary:
	_hk_water = true   # le crochet part de la bouche du canon, au-dessus de l'eau : la première terre rencontrée est un rivage
	return {"loot": _probe_loot, "enemy": _probe_enemy, "solid": _probe_solid}


func _probe_loot(p: Vector2) -> Dictionary:
	var id := _loot.nearest(p, 0.9)
	return {} if id < 0 else {"id": id, "pos": _loot.pos_of(id)}


func _probe_enemy(p: Vector2) -> Dictionary:
	for s: Dictionary in _fleet.ships:
		var model := s.get("model") as ShipModel
		if model == null or s["state"] == "sinking":
			continue
		var sim: ShipSim = s["sim"]
		var rel := p - sim.position
		var local := Basis(Vector3.UP, -sim.yaw) * Vector3(rel.x, 0.0, rel.y)
		if model.over_hull(Vector2(local.x / ShipModel.SCALE - model.shift, -local.z / ShipModel.SCALE)):
			return {"id": int(s["id"])}
	return {}


func _probe_solid(p: Vector2) -> String:
	for r: Array in _rocks.rocks:
		if p.distance_squared_to(Vector2(float(r[0]), float(r[1]))) < pow(float(r[2]) * 0.95, 2.0):
			return "rocher"
	if _land.is_over_water(p):
		_hk_water = true
		return ""
	var b := _land.blocker_at(p)
	if b != "":
		return b
	return "terre" if _hk_water else ""   # (le pirate à terre ne saisit pas le sol sous ses pieds, seulement ce qui se dresse)


## Hauteur (scène) du bout du crochet selon ce qu'il tient.
func _hook_end_y(kind: String, pos: Vector2) -> float:
	match kind:
		"loot":
			return SEA_Y + 0.45 if _land.is_over_water(pos) else _islands.ground_h(pos) + 0.35
		"ship":
			return _ship_point(_world_to_ship(pos), 0.8).y
		"enemy":
			return SEA_Y + 1.1
		"land":
			return SEA_Y + 0.7 if _land.is_over_water(pos) else maxf(_islands.ground_h(pos), 0.0) + 0.8
	return SEA_Y + 0.15


# --- côté joueur : viser, lancer, choisir ---

## Où part le crochet dans le monde (x/z) : la bouche du canon à grappin, à l'étrave.
func _hook_origin() -> Vector2:
	return _ship_to_world(_grapple_mount()) + _sim.forward() * 0.9


## Où part le crochet dans la scène (x, hauteur, z).
func _hook_muzzle() -> Vector3:
	return _ship.to_global(_ship.to_local3(_grapple_mount(), 0.0) + Vector3(0.82, 0.72, 0.0))


## On manie le grappin depuis son canon, à l'étrave.
func _hook_can_aim() -> bool:
	if _dialog.is_open() or _shop_menu.is_open() or _chart.is_open() or _pause.is_open() or _inventory.is_open():
		return false
	return _loc == Loc.SHIP and _mode == Mode.WALK and _ppos.distance_to(_grapple_mount()) < 3.6


## E au canon à grappin : on le prend en main pour viser (R : le ranger).
func _hook_toggle() -> void:
	if _hook_aim:
		_hook_aim = false
		return
	_hook_aim = true
	_hook_mouse_used = false
	_hook_mouse = get_viewport().get_mouse_position()


## Un point de la scène sur le plan horizontal de hauteur `height`, sous le pointeur de la souris.
func _mouse_ground_point(height: float) -> Vector3:
	var sv := (get_viewport().get_mouse_position() - _container.position) / float(_factor)
	var o := _cam.project_ray_origin(sv)
	var n := _cam.project_ray_normal(sv)
	if absf(n.y) < 0.001:
		return Vector3.INF
	return o + n * ((height - o.y) / n.y)


## Chaque image : la visée (direction à la souris, ce que le crochet saisirait) et son tracé.
func _update_hook_aim() -> void:
	if _hook_aim and (not _hook_can_aim() or _grap_state != 0):
		_hook_aim = false
	if _hook_line == null:
		_hook_line = MeshInstance3D.new()
		_hook_line.mesh = ImmediateMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.no_depth_test = true
		mat.render_priority = 6
		_hook_line.material_override = mat
		_hook_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hook_line.extra_cull_margin = 80.0
		_world.add_child(_hook_line)
	_hook_line.visible = _hook_aim
	if not _hook_aim:
		return
	var origin := _hook_origin()
	var a := _hook_muzzle()
	var mouse := get_viewport().get_mouse_position()
	if mouse.distance_to(_hook_mouse) > 2.0:
		_hook_mouse_used = true
	_hook_mouse = mouse
	if _args.has("aim"):   # essai : --aim=degrés impose la visée (0 = vers +x, 90 = vers le bas de l'écran)
		_hook_dir = Vector2.from_angle(deg_to_rad(float(_args["aim"])))
	elif _hook_mouse_used:
		var hit3 := _mouse_ground_point(a.y)
		if hit3 != Vector3.INF and Vector2(hit3.x - a.x, hit3.z - a.z).length() > 0.3:
			_hook_dir = Vector2(hit3.x - a.x, hit3.z - a.z).normalized()
	else:
		_hook_dir = _sim.forward()
	_hook_hit = Hook.trace(origin, _hook_dir, _hook_probes())
	if str(_hook_hit["kind"]) == "" and not _args.has("aim"):
		_hook_assist(origin)   # aide à la visée : si le pointeur est à côté d'une cible, le crochet s'en approche
	var found: bool = str(_hook_hit["kind"]) != ""
	var col := Color(0.45, 1.0, 0.5) if found else Color(1.0, 0.45, 0.35)
	var end2: Vector2 = _hook_hit["pos"]
	var b := _land_point(end2, _hook_end_y(str(_hook_hit["kind"]), end2))
	var im := _hook_line.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	im.surface_set_color(col)
	var total := a.distance_to(b)
	var dashes := int(total / 0.9)
	for k in dashes:   # des tirets épais (rubans à plat), bien visibles à l'écran
		_hook_strip(im, a.lerp(b, float(k) / float(maxi(dashes, 1))), a.lerp(b, (float(k) + 0.55) / float(maxi(dashes, 1))), 0.07)
	for ring_r in [0.6, 0.95]:
		for k in 20:
			var a0 := TAU * float(k) / 20.0
			var a1 := TAU * float(k + 1) / 20.0
			_hook_strip(im, b + Vector3(cos(a0), 0.0, sin(a0)) * ring_r, b + Vector3(cos(a1), 0.0, sin(a1)) * ring_r, 0.06)
	if found:   # une croix au centre : le crochet mord
		_hook_strip(im, b + Vector3(-0.35, 0.0, 0.0), b + Vector3(0.35, 0.0, 0.0), 0.06)
		_hook_strip(im, b + Vector3(0.0, 0.0, -0.35), b + Vector3(0.0, 0.0, 0.35), 0.06)
	im.surface_end()


const HOOK_ASSIST_DEG := 36.0   ## ° : jusqu'où de part et d'autre du pointeur le crochet cherche une cible
const HOOK_ASSIST_STEP := 3.0    ## ° : pas de la recherche

## Aide à la visée : la direction du pointeur ne saisit rien, on cherche la cible la plus proche de cette direction, dans un
## cône de HOOK_ASSIST_DEG de chaque côté, et on y vise. Le résultat est gardé 0,25 s tant que le pointeur ne bouge pas
## (la recherche coûte une vingtaine de tirs d'essai).
func _hook_assist(origin: Vector2) -> void:
	if _hook_assist_src.dot(_hook_dir) > cos(deg_to_rad(1.5)) and _time - _hook_assist_t < 0.25:
		if _hook_assist_dir != Vector2.ZERO:
			_hook_dir = _hook_assist_dir
			_hook_hit = Hook.trace(origin, _hook_dir, _hook_probes())
		return
	_hook_assist_src = _hook_dir
	_hook_assist_t = _time
	_hook_assist_dir = Vector2.ZERO
	var steps := int(HOOK_ASSIST_DEG / HOOK_ASSIST_STEP)
	for k in range(1, steps + 1):
		for sgn in [1.0, -1.0]:
			var d := _hook_dir.rotated(deg_to_rad(HOOK_ASSIST_STEP * float(k)) * sgn)
			var hit := Hook.trace(origin, d, _hook_probes())
			if str(hit["kind"]) != "":
				_hook_assist_dir = d
				_hook_dir = d
				_hook_hit = hit
				return


## Un ruban à plat, large de 2 x `half_w`, de `p0` à `p1` (scène) : deux triangles.
func _hook_strip(im: ImmediateMesh, p0: Vector3, p1: Vector3, half_w: float) -> void:
	var d := p1 - p0
	var side := Vector3(-d.z, 0.0, d.x)
	if side.length() < 0.0001:
		return
	side = side.normalized() * half_w
	for v: Vector3 in [p0 - side, p0 + side, p1 + side, p0 - side, p1 + side, p1 - side]:
		im.surface_add_vertex(v)


## Lancer le crochet dans la direction visée.
func _hook_fire() -> void:
	if _grap_state != 0:
		return
	if str(_hook_hit.get("kind", "")) == "":
		_say("Rien à saisir par là : vise le rivage, un rocher, un mur, un tonneau, un bateau ou du butin", 3.0)
		return
	_request("grapple", Hook.dir_code(_hook_dir))
	_hook_aim = false


## Le choix, une fois le crochet accroché : haler le bateau jusqu'à lui (ou ramener un butin), ou arrêter de haler.
func _hook_choose() -> void:
	match _grap_state:
		5:
			_request("grapple_reel" if _grap_kind == "loot" else "grapple_haul", 0)
		3:
			_request("grapple_pause", 0)


## E / R quand on vise ou quand le crochet est accroché et qu'on est à l'étrave. Renvoie vrai si la touche a servi.
func _hook_interact(secondary: bool) -> bool:
	if _hook_aim:
		if secondary:
			_hook_aim = false
		else:
			_hook_fire()
		return true
	if _grap_state != 0 and _loc == Loc.SHIP and _mode == Mode.WALK and _ppos.distance_to(_grapple_mount()) < 3.6:
		if secondary:
			_request("grapple_release", 0)
		else:
			_hook_choose()
		return true
	return false


## Hauteur du sol à terre en `p`, ou Land.NO_SURFACE.
func _ground_at(p: Vector2) -> float:
	var h := _land.walk_height(p, 0.0)
	if h == Land.NO_SURFACE:
		h = _land.walk_height(p, _islands.ground_h(p))
	return h


## Vrai si un pirate peut se tenir debout à terre en `p`.
func _can_stand_at(p: Vector2) -> bool:
	return _land.is_walkable(p) and _ground_at(p) != Land.NO_SURFACE


# --- côté hôte : le crochet vit et l'accroche suit ce qu'elle tient ---

## Hôte : le pirate `peer` lance le crochet du bateau dans la direction `code` (dixièmes de degré).
func _grapple_fire(peer: int, code: int) -> void:
	if _grap_state != 0 or code < 0 or code >= 3600:
		return
	var origin := _hook_origin()
	var hit := Hook.trace(origin, Hook.code_dir(code), _hook_probes())
	_grap_owner = peer
	_grap_hook = origin
	_grap_loot = -1
	_grap_enemy = -1
	_grap_kind = str(hit["kind"])
	_grap_target = hit["pos"]
	match _grap_kind:
		"loot":
			_grap_loot = int(hit["id"])
		"enemy":
			_grap_enemy = int(hit["id"])
			var ei := _fleet.find(_grap_enemy)
			_grap_off = _grap_target - (_fleet.ships[ei]["sim"] as ShipSim).position if ei >= 0 else Vector2.ZERO
	_grap_total = maxf(_grap_hook.distance_to(_grap_target), 1.0)
	_grap_state = 1
	_dbg("crochet lancé par %d : %s en (%.1f, %.1f)" % [peer, _grap_kind if _grap_kind != "" else "rien", _grap_target.x, _grap_target.y])


## Hôte : décrocher le crochet (il revient à bord).
func _grapple_release() -> void:
	if _grap_state == 0:
		return
	_grap_state = 4
	_grap_loot = -1
	_grap_kind = ""


## Hôte : un butin ramené arrive à bord. Un trésor va dans le coffre du capitaine, le reste à celui qui a lancé le crochet.
func _collect_hauled(id: int) -> void:
	var kind := _loot.take(id)
	if kind == "":
		return
	if kind.begins_with("t:"):
		_stash.append(kind.substr(2))
		_notify_all("%s hissé à bord : dans le coffre du capitaine" % Treasure.name_of(kind.substr(2)))
	else:
		_give_item(_grap_owner, kind)


## Hôte : fait vivre le grappin (vol, accroche, butin ramené, bateau halé, retour).
## États : 1 en vol, 5 accroché (on attend le choix de l'équipage), 2 ramène un butin, 3 hale le bateau, 4 retour.
func _update_grapple(delta: float) -> void:
	if _grap_state == 0:
		return
	var bow := _hook_origin()
	# l'accroche suit ce qu'elle tient
	if _grap_state != 4:
		match _grap_kind:
			"enemy":
				var ei := _fleet.find(_grap_enemy)
				if ei < 0 or _fleet.ships[ei]["state"] == "sinking":
					_grapple_release()
					return
				_grap_target = (_fleet.ships[ei]["sim"] as ShipSim).position + _grap_off
			"loot":
				if _grap_state == 1 or _grap_state == 5:
					var lp := _loot.pos_of(_grap_loot)
					if lp == Vector2.INF:
						_grapple_release()
						return
					_grap_target = lp   # le butin dérive : on vise où il est
	match _grap_state:
		1:
			var to := _grap_target - _grap_hook
			var step := Hook.SPEED * delta
			if to.length() <= step:
				_grap_hook = _grap_target
				_grap_state = 5 if _grap_kind != "" else 4
			else:
				_grap_hook += to.normalized() * step
		2:
			var lp2 := _loot.pos_of(_grap_loot)
			if lp2 == Vector2.INF:
				_grapple_release()
				return
			var to2 := bow - lp2
			if to2.length() < 3.0:
				_collect_hauled(_grap_loot)
				_grapple_release()
			else:
				var np := lp2 + to2.normalized() * minf(Hook.REEL * delta, to2.length())
				_loot.move_to(_grap_loot, np)
				_grap_hook = np
		3:
			var to3 := _grap_target - bow
			var dist := to3.length()
			if dist > GRAPPLE_MAX_ROPE:
				_notify_all("La corde du grappin a cassé")
				_grapple_release()
			elif dist > 3.3:
				_sim.position += to3.normalized() * clampf((dist - 3.3) * 1.5, 0.0, 4.5) * delta
				_sim.speed *= exp(-delta * 2.5)
			else:
				_sim.speed = 0.0   # amarré
		4:
			var to4 := bow - _grap_hook
			var step4 := Hook.SPEED * 1.3 * delta
			if to4.length() <= step4:
				_grap_state = 0
				_grap_kind = ""
				_grap_owner = 0
			else:
				_grap_hook += to4.normalized() * step4
		5:
			if bow.distance_to(_grap_target) > GRAPPLE_MAX_ROPE:
				_notify_all("La corde du grappin a cassé")
				_grapple_release()


## Chez tout le monde : la corde et le crochet (positions reçues de l'hôte), de la bouche du canon à grappin.
func _update_grapple_visual() -> void:
	if _rope == null:
		_rope = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.055
		cm.bottom_radius = 0.055
		cm.height = 1.0
		cm.radial_segments = 4
		cm.rings = 1
		_rope.mesh = cm
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(0.78, 0.62, 0.36)
		_rope.material_override = rm
		_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(_rope)
		_hook_node = Node3D.new()
		ShipCannons._box(_hook_node, Vector3(0.16, 0.16, 0.42), Vector3.ZERO, ShipCannons.IRON)
		ShipCannons._box(_hook_node, Vector3(0.5, 0.07, 0.09), Vector3(0.0, 0.0, 0.2), ShipCannons.IRON_L)
		ShipCannons._cyl(_hook_node, 0.08, 0.08, 0.1, Vector3(0.0, 0.0, -0.22), "z", ShipCannons.BRASS)
		_world.add_child(_hook_node)
	var on := _grap_state != 0 and _ship != null
	_rope.visible = on
	_hook_node.visible = on
	if not on:
		return
	var a := _hook_muzzle()
	var end_y := _hook_end_y(_grap_kind, _grap_hook)
	var k := 1.0 - clampf(_grap_hook.distance_to(_grap_target) / _grap_total, 0.0, 1.0)
	var y := end_y
	var arc := 0.0
	if _grap_state == 1:
		y = lerpf(a.y, end_y, k)
		arc = 1.4 * sin(PI * k)
	elif _grap_state == 4:
		var home := Vector2(a.x + _world_origin.x, a.z + _world_origin.z)
		var back := clampf(home.distance_to(_grap_hook) / maxf(_grap_total, 1.0), 0.0, 1.0)
		y = lerpf(a.y, end_y, back)
		arc = 0.8 * sin(PI * back)
	var b := _land_point(_grap_hook, y + arc)
	var seg := b - a
	var seg_len := maxf(seg.length(), 0.05)
	var yv := seg / seg_len
	var xv := yv.cross(Vector3.UP if absf(yv.y) < 0.98 else Vector3.RIGHT).normalized()
	var zv := xv.cross(yv)
	_rope.global_transform = Transform3D(Basis(xv, yv * seg_len, zv), (a + b) * 0.5)
	_hook_node.global_position = b
	if seg_len > 0.1 and absf(yv.y) < 0.98:
		_hook_node.look_at(a, Vector3.UP)


## Ce que dit la ligne du bas quand on tient le grappin ou qu'il est lancé, à l'étrave. Vide ailleurs.
func _hook_prompt() -> String:
	if _hook_aim:
		var kind := str(_hook_hit.get("kind", ""))
		if kind == "":
			return "Grappin — rien à saisir par là (portée %d m)   R ou clic droit : ranger" % int(Hook.RANGE)
		return "Grappin — clic gauche ou E : lancer sur %s (%d m)   R ou clic droit : ranger" % [str(_hook_hit["name"]), int(_hook_hit["dist"])]
	if _grap_state == 0 or _loc != Loc.SHIP or _ppos.distance_to(_grapple_mount()) >= 3.6:
		return ""
	match _grap_state:
		1:
			return "Le crochet file…"
		5:
			if _grap_kind == "loot":
				return "Crochet sur du butin — E ou clic gauche : le ramener   R ou clic droit : décrocher"
			return "Crochet accroché sur %s — E : haler le bateau jusqu'à lui   R ou clic droit : décrocher (le bateau ne bouge pas)" % str(Hook.NAMES.get(_grap_kind, "?"))
		2:
			return "Le butin arrive…   R : décrocher"
		3:
			return "Le bateau est halé vers le crochet — E : arrêter de haler   R : décrocher"
	return ""


# ------------------------------------------------------------------ bateau bloqué : le remettre à l'eau

## Hôte : une position libre pour le bateau à l'eau la plus proche (cap inchangé), ou Vector2.INF. Libre = la coque ne
## touche ni île, ni quai, ni récif, et il reste de la marge tout autour pour repartir.
func _free_water_near(from: Vector2) -> Vector2:
	var d := 3.0
	while d <= 120.0:
		for k in 24:
			var p := from + Vector2.from_angle(TAU * float(k) / 24.0 + d * 0.37) * d
			if _ship_spot_free(p, _sim.yaw):
				return p
		d += 3.0
	return Vector2.INF


func _ship_spot_free(p: Vector2, yaw: float) -> bool:
	if not _touch(p, yaw).is_empty():
		return false
	for off: Vector2 in [Vector2(4.0, 0.0), Vector2(-4.0, 0.0), Vector2(0.0, 4.0), Vector2(0.0, -4.0)]:
		if not _touch(p + off, yaw).is_empty():
			return false
	return true


## Hôte : remet le bateau sur l'eau libre la plus proche. Renvoie faux s'il n'y en a pas à moins de 120 m.
func _unstick_ship() -> bool:
	_grapple_release()
	var spot := _free_water_near(_sim.position)
	if spot == Vector2.INF:
		return false
	_sim.position = spot
	_sim.speed = 0.0
	_stuck_t = 0.0
	return true


## T : débloquer le bateau (deux fois de suite, pour qu'on ne le fasse jamais sans le vouloir).
func _try_unstick() -> void:
	if _unstick_armed > 0.0:
		_unstick_armed = 0.0
		_request("unstick", 0)
	else:
		_unstick_armed = 2.5
		_say("Bateau coincé ? Appuie encore sur T pour le remettre à l'eau libre", 2.5)


func _leave_helm() -> void:
	_mode = Mode.WALK
	_rudder_sent = 0.0
	_ppos = _ship.nearest_walkable(_ppos)   # derrière la roue on est coincé dans l'obstacle : on se dégage
	_request("helm_leave", 0)


## Fait partir le boulet du canon `i` (éclair, boulet, éclaboussure). Appelé chez tout le monde.
var _wind_streaks: WindStreaks
var _sail_fill_prev := 0.0


## Le vent qu'on voit et qu'on entend (12/11/2026, à la manière de Sea of Thieves) : traînées dans le sens du vent, voiles qui se
## gonflent (et un « vlouf » de toile quand elles prennent le vent) ou qui battent en claquant quand il les prend mal.
## Tout se déduit de l'état du bateau que l'hôte envoie (vent, cap, vergues, voiles) : chacun voit et entend la même chose.
func _update_wind_feel(delta: float) -> void:
	if _ship == null:
		return
	if _wind_streaks == null:
		_wind_streaks = WindStreaks.new()
		_world.add_child(_wind_streaks)
	var hoisted := _sim.sail_open
	var pull := clampf(_sim.wind_factor() * _sim.trim_efficiency(), 0.0, 1.0)   # le vent pris par la toile, 0…1
	var fill := pull * smoothstep(0.05, 0.4, hoisted)
	var luff := hoisted * clampf((GameConfig.SAIL_LUFF_AT - pull) / GameConfig.SAIL_LUFF_AT, 0.0, 1.0)
	_ship.set_sail_wind(fill, luff, delta)
	var center := _ship.global_position
	_wind_streaks.update(center, _sim.wind_dir, fill, _loc != Loc.LAND and _loc != Loc.HOLD and _atmo.sky.enabled)
	var mast_at := center + Vector3(0.0, 5.0, 0.0)
	if not _ship.masts.is_empty():
		mast_at = _ship.to_global(_ship.to_local3(Vector2(float((_ship.masts[0] as Array)[0]), 0.0), 5.0))
	if _sail_fill_prev < GameConfig.SAIL_FILL_SOUND_AT and fill >= GameConfig.SAIL_FILL_SOUND_AT:
		_sfx.play_at(Synth.recorded("sail_fill"), mast_at, 0.9)   # la toile se tend d'un coup
	_sail_fill_prev = fill
	if luff > 0.08:
		_sfx.loop_at("sail_luff", Synth.recorded("sail_luff", true), mast_at, luff * 0.85)
	else:
		_sfx.stop_loop("sail_luff")


## Coup de canon (nous ou un ennemi) en `at` (coordonnées de la scène) : détonation + grondement, entendus de loin.
func _cannon_boom(at: Vector3) -> void:
	_sfx.play_at(Synth.recorded("cannon_fire"), at, GameConfig.CANNON_BLAST_VOL, 1.0, true)
	_sfx.play_at(Synth.recorded("cannon_tail"), at, GameConfig.CANNON_TAIL_VOL, 1.0, true)
	if _atmo != null and _sfx.get_parent() != null and at.distance_to(_my_scene_pos()) < GameConfig.SFX_FAR_RANGE * 0.5:
		_atmo.music.punch()   # proche : la musique se creuse un instant pour laisser éclater le coup


## Un boulet qui arrive : `what` = "hull_hit" (dans une coque, un mob, un récif) ou "ball_splash" (à l'eau).
func _ball_sound(what: String, at: Vector3) -> void:
	_sfx.play_at(Synth.recorded(what), at, 1.0 if what == "hull_hit" else 0.7, 1.0, true)


func fire_visual(i: int, human: bool = false, aim: float = 0.0) -> void:
	if _ship == null or i < 0 or i >= _ship.cannons.size() or i >= _cannon_nodes.size():
		return
	_cannon_loaded[i] = false
	var c: Array = _ship.cannons[i]
	var side := float(c[2])
	var out_local := Vector3(0.0, 0.0, -side)
	var muzzle := _ship.to_global(ShipCannons.muzzle_local(_cannon_nodes[i]))
	var dir := (_ship.global_transform.basis * out_local).normalized()
	if aim != 0.0:   # tir visé : la sortie tournée de `aim` (même sens que _cannon_launch)
		var d2 := Vector2(dir.x, dir.z).rotated(aim)
		dir = Vector3(d2.x, 0.0, d2.y)
	var fwd := _sim.forward()
	ShipCannons.kick(_cannon_nodes[i])
	_cannon_boom(muzzle)
	if not human:   # un pirate tiré du canon part seul : pas de boulet avec lui
		var vel := dir * 28.0 + Vector3.UP * 5.0 + Vector3(fwd.x, 0.0, fwd.y) * _sim.speed
		var ball := _make_ball(0.16, Color(0.10, 0.10, 0.14))
		_world_fixed.add_child(ball)
		ball.global_position = muzzle
		_projectiles.append({"node": ball, "vel": vel, "age": 0.0, "player": true})
	# éclair de bouche
	var flash := _make_ball(0.42, Color(1.0, 0.7, 0.3))
	(flash.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(flash)
	flash.global_position = muzzle
	var tw := flash.create_tween()
	tw.tween_property(flash, "scale", Vector3.ZERO, 0.2)
	tw.tween_callback(flash.queue_free)
	# fumée : quelques bouffées grises qui gonflent en dérivant, puis disparaissent
	for k in 6:
		var puff := _make_ball(0.3, Color(0.78, 0.78, 0.8))
		var pm := puff.material_override as StandardMaterial3D
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(puff)
		puff.global_position = muzzle + dir * (0.2 * k) + Vector3(0.0, 0.1 * k, 0.0)
		puff.scale = Vector3.ONE * 0.5
		var spread := Vector3(randf_range(-0.6, 0.6), randf_range(0.3, 1.1), randf_range(-0.6, 0.6)) + dir * 1.4
		var pt := puff.create_tween()
		pt.set_parallel(true)
		pt.tween_property(puff, "global_position", puff.global_position + spread, 1.1)
		pt.tween_property(puff, "scale", Vector3.ONE * (1.9 + 0.2 * k), 1.1)
		pt.tween_property(pm, "albedo_color:a", 0.0, 1.1).from(0.75)
		pt.chain().tween_callback(puff.queue_free)


func _update_projectiles(delta: float) -> void:
	for i in range(_projectiles.size() - 1, -1, -1):
		var p: Dictionary = _projectiles[i]
		var node: MeshInstance3D = p["node"]
		var vel: Vector3 = p["vel"]
		vel.y -= 16.0 * delta
		p["vel"] = vel
		p["age"] = float(p["age"]) + delta
		var prev_ball := node.position
		node.position += vel * delta
		if p.get("enemy", false) and _ball_hits_hull(node.global_position):
			if _is_authority() and int(p.get("src", -1)) >= 0:
				_fleet.reveal(int(p["src"]))   # lot 5 (6.7) : il nous a touchés : il apparaît sur la carte de tout l'équipage
			_splash(Vector3(node.position.x, SEA_Y + 0.05, node.position.z))   # (le son du choc : hit_visual, chez tous)
			node.queue_free()
			_projectiles.remove_at(i)
			continue
		if p.get("player", false) and _is_authority() and node.position.y < 6.0:
			# lot 5 (6.8) : un boulet qui frappe un ennemi d'île le blesse et le sonne
			var mob_hits := _islands.cannonball(Vector2(node.position.x, node.position.z), node.position.y)
			if not mob_hits.is_empty():
				for hit: Dictionary in mob_hits:
					if int(hit["gold"]) > 0:
						_give_loot(_my_id(), int(hit["gold"]), hit["at"])
				_ball_sound("hull_hit", node.global_position)
				_send_action("ball_hit", "", Vector2(node.position.x, node.position.z), Vector2.ZERO)
				_splash(Vector3(node.position.x, node.position.y, node.position.z))
				node.queue_free()
				_projectiles.remove_at(i)
				continue
		if p.get("player", false) and _is_authority():
			var eid := -1   # on teste tout le trajet de l'image (un boulet rapide ne « saute » pas par-dessus une coque)
			var travel := prev_ball.distance_to(node.position)
			var steps := maxi(int(travel / 0.3), 1)
			for k in range(1, steps + 1):
				eid = _fleet.ball_hit(prev_ball.lerp(node.position, float(k) / float(steps)))
				if eid >= 0:
					break
			if eid >= 0:
				_fleet.hurt(eid, 18.0)   # un boulet de joueur touche un bateau ennemi
				_ball_sound("hull_hit", node.global_position)
				_send_action("ball_hit", "", Vector2(node.position.x, node.position.z), Vector2.ZERO)
				_splash(Vector3(node.position.x, SEA_Y + 0.05, node.position.z))
				node.queue_free()
				_projectiles.remove_at(i)
				continue
		if node.position.y < SEA_Y or float(p["age"]) > 8.0:
			if node.position.y < SEA_Y:
				_ball_sound("ball_splash", node.global_position)
			_splash(Vector3(node.position.x, SEA_Y + 0.05, node.position.z))
			node.queue_free()
			_projectiles.remove_at(i)


func _splash(at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.4
	cyl.bottom_radius = 0.4
	cyl.height = 0.05
	ring.mesh = cyl
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.92, 0.95, 1.0, 0.9)
	ring.material_override = m
	_world_fixed.add_child(ring)
	ring.position = at
	ring.scale = Vector3(0.3, 1.0, 0.3)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(3.2, 1.0, 3.2), 0.7)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.7)
	tw.chain().tween_callback(ring.queue_free)


# ------------------------------------------------------------------ interface


## Ce que dit la ligne du bas dans la cale, selon l'objet à portée.
func _hold_prompt() -> String:
	var it := _hold_nearest()
	if it.is_empty():
		if _hull.leak_count() > 0:
			return "Une planche (étagère au fond), puis E devant la voie d'eau pour la boucher"
		return "Cale en ordre" + (" — E au seau pour écoper" if _hull.water > 0.0 else "")
	match it["kind"]:
		"ladder":
			return "E : remonter sur le pont"
		"rack":
			if _carry_kind == "ball" or _carry_kind == "plank":
				return "E : ranger sur l'étagère   (planches %d, boulets %d)" % [_profile.planks, _profile.balls]
			return "Tu as les mains prises" if _carrying else "E : prendre une planche (%d)   R : prendre un boulet (%d)" % [_profile.planks, _profile.balls]
		"bucket":
			return "E : écoper (%d %% d'eau)" % int(_hull.fill() * 100.0) if _hull.water > 0.0 else "La cale est sèche"
		"hole":
			return "E : boucher la voie d'eau" if _carry_kind == "plank" else "Il te faut une planche (étagère au fond)"
	return ""


## Jauge de la cale en haut à gauche : visible dès qu'il y a une voie d'eau ou de l'eau.
func _update_gauge() -> void:
	var leaks := _hull.leak_count()
	var show := leaks > 0 or _hull.water > 0.002
	_gauge_back.visible = show
	_gauge_label.visible = show
	if not show:
		return
	var f := _hull.fill()
	_gauge_fill.size.x = (_gauge_back.size.x - 4.0) * f
	_gauge_fill.color = Color(0.25, 0.6, 0.85) if f < 0.5 else (Color(0.95, 0.65, 0.2) if f < 0.8 else Color(0.9, 0.2, 0.15))
	_gauge_label.text = "Cale %d %%   Voies d'eau : %d" % [int(f * 100.0), leaks]


func _update_hud() -> void:
	var a := _sim.wind_alignment()
	var wind := "vent arrière" if a > 0.55 else ("vent de travers" if a > -0.25 else ("vent debout" if a < -0.75 else "vent de face"))
	_hud.text = "Vitesse %.1f nœuds   Voiles %d/%d   Ancre : %s   Barre %+.1f   %s (rendement %d %%)" % [
		_sim.speed * 1.944, _sim.sail_level, ShipSim.SAIL_LEVELS, "jetée" if _sim.anchored else "levée",
		_sim.rudder, wind, int(_sim.wind_factor() * 100.0)]
	if _atmo != null:   # lot 6 (8.1) : le moment de la journée (et la houle forte, quand il y en a)
		_hud.text += "   %s%s" % [_atmo.sky.moment(), "   Houle forte" if _atmo.sky.swell > 0.45 else ""]
	if _net.active:
		_hud.text += "\nÉquipage : %d / %d%s" % [_remotes.size() + 1, SailingNet.MAX_PLAYERS,
				"   (barre tenue par un ami)" if _helm_owner != 0 and _helm_owner != _my_id() else ""]
	_update_gauge()
	_sail_hud.visible = _loc != Loc.LAND and _loc != Loc.HOLD and not _chart.is_open()
	var hs: ShipSim = _raft.sim if (_loc == Loc.RAFT and _raft != null) else _sim   # sur le radeau, le cadran suit le radeau
	_sail_hud.set_state(hs.wind_relative(), hs.sail_trim, hs.optimal_trim(), hs.trim_efficiency(), hs.sail_level > 0, _mode == Mode.SAILS)
	if hs != _sim:
		_hud.text = "Radeau — vitesse %.1f nœuds   Voile : %s   %s" % [hs.speed * 1.944, "hissée" if hs.sail_level > 0 else "affalée", wind]
	_gold_label.text = "Or : %d\nBoulets : %d   Planches : %d" % [_profile.gold, _profile.balls, _profile.planks]
	if not _stash.is_empty():
		_gold_label.text += "\nCoffre : %d trésor(s), %d or" % [_stash.size(), Treasure.total_value(_stash)]
	if _carry_kind == "treasure":
		_gold_label.text += "\nTu portes : %s (%d or)" % [Treasure.name_of(_carry_item), Treasure.value_of(_carry_item)]
	_sync_held_weapon()
	_weapon_label.visible = _loc == Loc.LAND
	if _weapon_label.visible:
		var parts: Array = []
		for slot: Array in [["clic gauche", _profile.weapon], ["clic droit", _profile.secondary_weapon()]]:
			var wid: String = slot[1]
			var ammo := Weapons.ammo_of(wid)
			parts.append("[%s] %s%s" % [slot[0], Weapons.weapon_name(wid),
					" (%d %s)" % [_profile.ammo_count(ammo), Weapons.ammo_label(ammo)] if ammo != "" else ""])
		_weapon_label.text = "%s\n[X] changer   [Tab] sac" % "   ".join(parts)
	if _stash_glow != null:
		_stash_glow.visible = not _stash.is_empty()
		_stash_glow.position.y = _ship.to_local3(_ship.stash_pos, 1.0 + 0.06 * sin(_time * 3.0)).y
	_quest_label.text = _quests.tracker_text()
	if _dialog.is_open() or _shop_menu.is_open():
		_prompt.text = ""
		return
	if _notice_t > 0.0:
		_prompt.text = _notice
		return
	var hook_text := _hook_prompt()
	if hook_text != "":
		_prompt.text = hook_text
		return
	if _loc == Loc.RAFT:
		_prompt.text = _raft_prompt()
		return
	if _loc == Loc.HOLD:
		_prompt.text = _hold_prompt()
		return
	if _loc == Loc.NEST:
		_prompt.text = "Dans le nid de pie — E : redescendre"
		return
	if _loc == Loc.CLIMB or _loc == Loc.FLIGHT:
		_prompt.text = ""
		return
	if _loc == Loc.SWIM:
		var bp := _world_to_ship(_lpos)
		var hw := _ship.half_width(clampf(bp.x, -_ship.length * 0.5 + 0.2, _ship.length * 0.5 - 0.2))
		var near_hull := (absf(bp.y) - hw) * ShipModel.SCALE <= BOARD_REACH and bp.x > -_ship.length * 0.5 - 1.0 and bp.x < _ship.length * 0.5 + 1.0
		var near_raft := _raft != null and Raft.covers(_raft.sim.position, _raft.sim.yaw, _lpos, 1.6)
		var at_ladder := _nearest_ladder_from_water() >= 0
		if near_raft:
			_prompt.text = "À la nage — E : monter sur ton radeau"
		elif at_ladder:
			_prompt.text = "À la nage — E : monter à l'échelle"
		elif near_hull:
			_prompt.text = "À la nage — rejoins l'échelle pour remonter à bord"
		else:
			_prompt.text = "À la nage — rejoins l'échelle du bateau, une plage ou un quai"
		return
	if _loc == Loc.SHIP and _mode == Mode.SAILS:
		_prompt.text = "Au mât — Q/D : orienter les voiles   Z/S : hisser / affaler   E : lâcher"
		return
	if _loc == Loc.SHIP and _mode == Mode.CANNON:
		_prompt.text = "Dans le canon — Q/D : viser   E : partir !   R : ressortir"
		return
	if _loc == Loc.LAND:
		var near := _nearest_npc()
		if near != null:
			_prompt.text = "E : parler à %s" % near.display_name
		elif _islands.nearest_chest(_lpos) >= 0:
			_prompt.text = "E : ouvrir le coffre   F / clic : frapper"
		elif _atmo != null and not _atmo.life.nearest_lore(_lpos).is_empty():
			var found: Dictionary = _atmo.life.nearest_lore(_lpos)
			_prompt.text = "E : ramasser la bouteille" if found["kind"] == "bottle" else "E : lire le journal abandonné"
		elif _islands.nearest_berry(_lpos) >= 0:
			var spot: Dictionary = _islands.berry_spots[_islands.nearest_berry(_lpos)]
			_prompt.text = "E : cueillir la %s (elle va dans ton sac : Tab pour la manger)" % BerryBook.berry_name(str(spot["berry"]))
		elif _outpost_prompt() != "":
			_prompt.text = _outpost_prompt()
		else:
			var base := "E : monter à bord   Espace : sauter" if _nearest_ship_ladder_from_land() >= 0 else "Espace : sauter"
			_prompt.text = base + ("   F / clic : frapper" if _islands.island_at(_lpos, 2.0) >= 0 else "")
		return
	if _mode == Mode.HELM:
		_prompt.text = "À la barre : Q/D pour virer — E ou Espace : lâcher la barre"
		return
	var it := _nearest_interactable()
	if it.is_empty():
		_prompt.text = ""
		return
	match it["kind"]:
		"chart":
			_prompt.text = "E : consulter la carte des mers"
		"hatch":
			var n := _hull.leak_count()
			_prompt.text = "E : descendre dans la cale" + ("   (%d voie(s) d'eau !)" % n if n > 0 else "")
		"ladder":
			_prompt.text = "E : descendre sur le quai (échelle)"
		"mastladder":
			_prompt.text = "E : grimper au nid de pie"
		"helm":
			_prompt.text = "E : prendre la barre"
		"mast":
			_prompt.text = "E : régler les voiles (orienter, hisser)   R : affaler   (voiles %d/%d)" % [_sim.sail_level, ShipSim.SAIL_LEVELS]
		"crate":
			if _carry_kind == "plank":
				_prompt.text = "E : ranger la planche dans la caisse   (planches %d)" % _profile.planks
			elif _carrying:
				_prompt.text = "La caisse ne prend que des planches"
			else:
				_prompt.text = "Caisse à planches : E : prendre une planche (%d)" % _profile.planks
		"grapple":
			_prompt.text = "E ou R : décrocher le grappin" if _grap_state != 0 else "E : prendre le grappin en main — on vise à la souris, tout autour du bateau"
		"stash":
			if _carry_kind == "treasure":
				_prompt.text = "E : déposer le trésor dans le coffre du capitaine   —   %s" % _stash_text()
			elif _stash.is_empty():
				_prompt.text = _stash_text()
			else:
				_prompt.text = "E : reprendre un trésor (pour le vendre à la main)   —   %s" % _stash_text()
		"anchor":
			_prompt.text = "E : lever l'ancre" if _sim.anchored else "E : jeter l'ancre"
		"ammo":
			if _carry_kind == "ball":
				_prompt.text = "E : remettre le boulet dans le tonneau   (boulets %d)" % _profile.balls
			elif _carrying:
				_prompt.text = "Le tonneau ne prend que des boulets"
			else:
				_prompt.text = "Tonneau de boulets : E : prendre un boulet (%d)" % _profile.balls
		"cannon":
			var i: int = it["index"]
			if _gun_i == i:
				_prompt.text = "Canon — vise à la souris, clic gauche : tirer   clic droit ou R : lâcher" if _cannon_loaded[i] else "Canon vide — clic gauche : le recharger (boulets : %d)   clic droit ou R : lâcher" % _profile.balls
			elif _cannon_loaded[i]:
				_prompt.text = "E : viser à la souris (clic gauche : tirer)"
			elif _carrying:
				_prompt.text = "E : charger le canon"
			else:
				_prompt.text = "E : viser (et recharger au clic)   R : se glisser dans le canon (être tiré au loin)"


# ------------------------------------------------------------------ fabrication et radeau

var _raft: Raft                       ## mon radeau (un seul à la fois)
var _remote_rafts: Dictionary = {}    ## id du joueur -> son radeau vu de loin (position, cap et voile reçus du réseau)


## Fabrique `id` (voir data/crafting.json) avec ce qu'il y a dans le sac. Le radeau se pose sur l'eau libre la plus proche.
func _craft(id: String) -> void:
	if Crafting.get_def(id).is_empty():
		return
	if id == "cabin":
		_craft_cabin()
		return
	if id != "raft":
		return
	if _raft != null:
		_say("Tu as déjà un radeau, à %d m d'ici" % int(_raft.sim.position.distance_to(_my_world_pos())), 3.5)
		return
	if _loc != Loc.LAND:
		_say("Le radeau se fabrique à terre, au bord de l'eau", 3.5)
		return
	if not Crafting.can_afford(_profile, id):
		var lack := Crafting.missing(_profile, id)
		_say("Il te manque %d planche(s) pour le radeau (%s en tout) : casse des tonneaux et des caisses" % [int(lack.get("plank", 0)), Crafting.cost_text(id)], 5.0)
		return
	var spot := _raft_spot_near(_lpos)
	if spot.is_empty():
		_say("Pas d'eau libre assez près : approche-toi du rivage (pas contre un rocher ni contre le bateau)", 4.5)
		return
	Crafting.pay(_profile, id)
	_spawn_raft(spot["pos"], spot["yaw"])
	_dbg("radeau fabriqué en (%.1f, %.1f), cap %.0f°, planches restantes %d" % [spot["pos"].x, spot["pos"].y, rad_to_deg(spot["yaw"]), _profile.planks])
	_splash_burst(spot["pos"])
	_say("Radeau fabriqué ! Monte dessus : E ou saute (Espace). A/D : barrer   W/S : hisser / affaler la voile", 7.0)


# ------------------------------------------------------------------ îles capturées et cabanes (voir Outpost)
# L'état (îles capturées, cabanes, contenu des coffres) vit chez l'hôte (son profil) ; les invités en reçoivent une copie
# (`_client_outposts`) et lui demandent tout par `apply_cabin`. Le coffre d'une cabane est donc partagé par tout l'équipage.

var _outpost_nodes: Dictionary = {}   ## id d'île -> {"flag": Node3D, "flag_captured": bool, "cabin": Node3D}
var _outpost_t := 0.0                 ## s avant la prochaine mise à jour des drapeaux et cabanes
var _client_outposts := _outposts_holder()   ## chez un invité : la copie de l'état de l'hôte (jamais enregistrée)
var _chest_island := -1               ## indice de l'île dont le coffre est ouvert dans le panneau (-1 : c'est le sac habituel)


static func _outposts_holder() -> Profile:
	var p := Profile.new()
	p.persistent = false
	return p


## Le profil qui fait foi pour les îles capturées et les cabanes : le mien si je suis l'hôte (ou seul), sinon la copie reçue.
func _op() -> Profile:
	return _profile if _is_authority() else _client_outposts


## Hôte -> invités : l'état des îles capturées et des cabanes.
func outposts_net_state() -> Dictionary:
	return Outpost.export_state(_profile)


func apply_outposts_state(s: Dictionary) -> void:
	Outpost.import_state(_client_outposts, s)
	_outpost_t = 0.0
	_refresh_chest_ui()


## Toutes les demi-secondes : les îles capturées ne se repeuplent plus, et chaque île vaincue ou capturée montre son
## drapeau (blanc, puis noir) ; chaque cabane bâtie est posée (et bloque le passage) dès que son île existe.
func _sync_outposts(delta: float) -> void:
	_outpost_t -= delta
	if _outpost_t > 0.0:
		return
	_outpost_t = 0.5
	var op := _op()
	for cid: Variant in op.captured:
		_islands.held[str(cid)] = true
	for i in _islands.islands.size():
		var isl: Dictionary = _islands.islands[i]
		if isl["node"] == null:
			continue
		var id := str(isl["id"])
		var captured := Outpost.is_captured(op, id)
		var rec: Dictionary = _outpost_nodes.get(id, {})
		var show_flag := captured or _islands.is_cleared(i)
		var flag: Node3D = rec.get("flag", null)
		if flag != null and (not show_flag or bool(rec.get("flag_captured", false)) != captured):
			flag.queue_free()
			flag = null
		if flag == null and show_flag:
			var fp := Outpost.flag_pos(_islands, i)
			flag = Outpost.make_flag(_world_fixed, fp, _islands.ground_h(fp), captured)
		rec["flag"] = flag
		rec["flag_captured"] = captured
		if Outpost.has_cabin(op, id) and rec.get("cabin", null) == null:
			var cp := Outpost.cabin_pos(op, id)
			if cp != Vector2.INF:
				rec["cabin"] = Outpost.make_cabin(_world_fixed, cp, _islands.ground_h(cp))
				var h := Outpost.CABIN_HALF
				_land.obstacles.append([cp.x - h, -(cp.y + h), cp.x + h, -(cp.y - h)])
		_outpost_nodes[id] = rec


## E à terre près d'une cabane (ouvrir son coffre) ou d'un drapeau (capturer l'île). Faux s'il n'y a rien à portée.
func _outpost_interact() -> bool:
	var ci := Outpost.cabin_near(_islands, _op(), _lpos)
	if ci >= 0:
		_open_cabin_chest(ci)
		return true
	var fi := Outpost.flag_near(_islands, _op(), _lpos)
	if fi >= 0:
		_interact_flag(fi)
		return true
	return false


func _interact_flag(i: int) -> void:
	var id := str((_islands.islands[i] as Dictionary)["id"])
	if Outpost.is_captured(_op(), id):
		_say("Cette île est à vous. Fabrique-y une cabane pour ranger vos affaires (Tab, Fabrication : %s)" % Crafting.cost_text("cabin"), 5.0)
		return
	_cabin_send("capture", i, "", 0, Vector2.ZERO)


## Une action sur les îles capturées : chez l'hôte on l'applique, chez un invité on la lui demande.
func _cabin_send(op: String, island: int, kind: String, n: int, pos: Vector2) -> void:
	if _is_authority():
		apply_cabin(_my_id(), op, island, kind, n, pos)
	elif _net != null and _net.active:
		_net.send_cabin(op, island, kind, n, pos)


## Hôte (ou solo) : applique l'action de `peer` sur l'île `island` : « capture » (drapeau hissé), « build » (cabane posée en
## `pos`), « put » (range `n` de `kind` : l'invité les a déjà sortis de son sac) ou « take » (en sort jusqu'à `n` et les lui donne).
func apply_cabin(peer: int, op: String, island: int, kind: String, n: int, pos: Vector2) -> void:
	if not _is_authority() or island < 0 or island >= _islands.islands.size():
		return
	var isl: Dictionary = _islands.islands[island]
	var id := str(isl["id"])
	match op:
		"capture":
			if Outpost.is_captured(_profile, id) or not _islands.is_cleared(island):
				return
			Outpost.capture(_profile, id)
			_islands.held[id] = true
			var reward := Outpost.capture_reward(_islands, island)
			_give_loot(peer, reward, Outpost.flag_pos(_islands, island))
			for crew_id in _crew_ids():
				_give_rep(int(crew_id), int(float(reward) * Reputation.gain("capture_per_gold")), "île capturée")
			_announce("%s est capturée ! Plus rien n'y reviendra. Fabriquez-y une cabane (Tab) pour ranger vos affaires" % str(isl["name"]))
		"build":
			if not Outpost.is_captured(_profile, id) or Outpost.has_cabin(_profile, id) or pos == Vector2.INF:
				return
			if _islands.sdf(island, pos) < Outpost.CABIN_HALF + 0.6:
				return
			Outpost.build_cabin(_profile, id, pos)
			_announce("Une cabane est bâtie sur %s : son coffre est à tout l'équipage" % str(isl["name"]))
		"put":
			Outpost.deposit(_profile, id, kind, n)
		"take":
			var got := Outpost.withdraw(_profile, id, kind, n)
			if got > 0:
				if kind.begins_with("t:") or kind.begins_with("b:"):
					for k in got:
						_give_item(peer, kind)
				else:
					_give_item(peer, "n:%s:%d" % [kind, got])
		_:
			return
	_outpost_t = 0.0
	if _net != null and _net.active:
		_net.broadcast_outposts()
	_refresh_chest_ui()


## Un message pour tout l'équipage (et pour moi).
func _announce(text: String) -> void:
	_say(text, 6.0)
	if _net != null and _net.active and _net.is_host:
		_net.broadcast_notice(text)


## Le texte d'invite près d'un drapeau ou d'une cabane, ou "" s'il n'y en a pas à portée.
func _outpost_prompt() -> String:
	var op := _op()
	var ci := Outpost.cabin_near(_islands, op, _lpos)
	if ci >= 0:
		return "E : ouvrir le coffre de la cabane (partagé)   —   %s" % Outpost.stash_text(op, str((_islands.islands[ci] as Dictionary)["id"]))
	var fi := Outpost.flag_near(_islands, op, _lpos)
	if fi >= 0:
		var fid := str((_islands.islands[fi] as Dictionary)["id"])
		if Outpost.is_captured(op, fid):
			return "Votre île — Tab, Fabrication : bâtir une cabane (%s)" % Crafting.cost_text("cabin")
		return "E : hisser le drapeau et capturer l'île (+%d or)" % Outpost.capture_reward(_islands, fi)
	return ""


## Bâtit la cabane de l'île où l'on se tient (capturée, assez de planches, un emplacement plat) un peu devant soi.
func _craft_cabin() -> void:
	if _loc != Loc.LAND:
		_say("La cabane se bâtit à terre, sur une île capturée", 3.5)
		return
	var op := _op()
	var i := _islands.island_at(_lpos)
	var id := str((_islands.islands[i] as Dictionary)["id"]) if i >= 0 else ""
	if i < 0 or not Outpost.is_captured(op, id):
		_say("Une cabane ne se bâtit que sur une île capturée : bats tous ses ennemis, ouvre ses coffres, puis hisse le drapeau", 5.5)
		return
	if Outpost.has_cabin(op, id):
		_say("Il y a déjà une cabane sur cette île", 3.0)
		return
	if not Crafting.can_afford(_profile, "cabin"):
		var lack := Crafting.missing(_profile, "cabin")
		_say("Il te manque %d planche(s) pour la cabane (%s en tout)" % [int(lack.get("plank", 0)), Crafting.cost_text("cabin")], 5.0)
		return
	var spot := Outpost.cabin_spot(_islands, i, _lpos)
	if spot == Vector2.INF:
		_say("Pas assez de place ici : cherche un coin plat et dégagé de l'île", 4.5)
		return
	Crafting.pay(_profile, "cabin")
	_cabin_send("build", i, "", 0, spot)


# --- le coffre partagé : le panneau du sac, rempli avec ce qu'on peut ranger et ce que le coffre contient

func _open_cabin_chest(island: int) -> void:
	if _inventory.is_open() or _dialog.is_open() or _shop_menu.is_open() or _chart.is_open() or _pause.is_open():
		return
	_chest_island = island
	_inventory.set_texts("Coffre de la cabane — à tout l'équipage", "Haut/Bas : choisir     E : ranger / reprendre     R / Échap : fermer")
	_inventory.open(_chest_rows())


func _on_inventory_closed() -> void:
	_chest_island = -1
	_inventory.set_texts()


func _refresh_chest_ui() -> void:
	if _chest_island >= 0 and _inventory.is_open():
		_inventory.set_rows(_chest_rows())


## Combien j'ai de `kind` sur moi (les trésors : celui que je porte ; les baies : celles du sac).
func _have_of(kind: String) -> int:
	if kind.begins_with("t:"):
		return 1 if _carry_kind == "treasure" and _carry_item == kind.substr(2) else 0
	if kind.begins_with("b:"):
		return int(_profile.berries.get(kind.substr(2), 0))
	match kind:
		"plank":
			return _profile.planks
		"ball":
			return _profile.balls
		"bullets":
			return _profile.bullets
		"shells":
			return _profile.shells
		"gold":
			return _profile.gold
	return 0


## Combien de `kind` je peux encore recevoir (la caisse est limitée ; les trésors ont besoin de mains libres).
func _room_for(kind: String) -> int:
	if kind.begins_with("t:"):
		return 0 if _carrying else 1
	if kind == "plank":
		return SUPPLY_MAX - _profile.planks
	if kind == "ball":
		return SUPPLY_MAX - _profile.balls
	return 1000000


## Retire `n` de `kind` de mes affaires (ils partent dans le coffre).
func _remove_have(kind: String, n: int) -> void:
	if kind.begins_with("t:"):
		_drop_carried()
		return
	if kind.begins_with("b:"):
		_profile.add_berry(kind.substr(2), -n)
		return
	match kind:
		"plank":
			_profile.planks -= n
		"ball":
			_profile.balls -= n
		"bullets":
			_profile.bullets -= n
		"shells":
			_profile.shells -= n
		"gold":
			_profile.gold -= n
	_profile.save()


func _chest_rows() -> Array:
	var rows: Array = []
	if _chest_island < 0 or _chest_island >= _islands.islands.size():
		return rows
	var op := _op()
	var id := str((_islands.islands[_chest_island] as Dictionary)["id"])
	rows.append({"head": true, "label": "Dans ton sac — E : ranger"})
	var mine: Array = []
	if _carry_kind == "treasure":
		mine.append("t:" + _carry_item)
	var berry_ids: Array = _profile.berries.keys()
	berry_ids.sort()
	for bid in berry_ids:
		mine.append("b:" + str(bid))
	mine.append_array(Outpost.SUPPLY_KINDS)
	var any := false
	for kind: String in mine:
		var have := _have_of(kind)
		if have <= 0:
			continue
		any = true
		var n := mini(Outpost.step_of(kind), have)
		rows.append({"kind": "cab_put", "id": kind, "label": "%s  x%d" % [Outpost.kind_name(kind), have], "right": "ranger %d" % n,
				"enabled": true, "desc": "Le coffre est à tout l'équipage : chacun peut y ranger et y reprendre ce qu'il veut."})
	if not any:
		rows.append({"kind": "none", "id": "", "label": "(rien à ranger)", "right": "", "enabled": false, "desc": ""})
	rows.append({"head": true, "label": "Dans le coffre — E : reprendre"})
	var items := Outpost.items_of(op, id)
	var kinds: Array = items.keys()
	kinds.sort()
	if kinds.is_empty():
		rows.append({"kind": "none", "id": "", "label": "(le coffre est vide)", "right": "", "enabled": false, "desc": ""})
	for kind: String in kinds:
		var inside := int(items[kind])
		var take := mini(mini(Outpost.step_of(kind), inside), _room_for(kind))
		rows.append({"kind": "cab_take", "id": kind, "label": "%s  x%d" % [Outpost.kind_name(kind), inside],
				"right": "reprendre %d" % take if take > 0 else ("mains prises" if kind.begins_with("t:") else "sac plein"),
				"enabled": take > 0, "desc": "Les trésors se reprennent un par un, à mains libres."})
	return rows


func _on_chest_use(kind: String, item: String) -> void:
	if _chest_island < 0:
		return
	var id := str((_islands.islands[_chest_island] as Dictionary)["id"])
	if kind == "cab_put":
		var n := mini(Outpost.step_of(item), _have_of(item))
		if n > 0 and Outpost.valid_kind(item):
			_remove_have(item, n)
			_cabin_send("put", _chest_island, item, n, Vector2.ZERO)
	elif kind == "cab_take":
		var n2 := mini(mini(Outpost.step_of(item), Outpost.count_of(_op(), id, item)), _room_for(item))
		if n2 > 0:
			_cabin_send("take", _chest_island, item, n2, Vector2.ZERO)
	_refresh_chest_ui()


## Je reçois `n` de `what` (« plank », « ball », « bullets », « shells », « gold ») sorti du coffre.
func _receive_supply(what: String, n: int) -> void:
	match what:
		"plank":
			_profile.planks = mini(_profile.planks + n, SUPPLY_MAX)
		"ball":
			_profile.balls = mini(_profile.balls + n, SUPPLY_MAX)
		"bullets":
			_profile.bullets += n
		"shells":
			_profile.shells += n
		"gold":
			_profile.gold += n
		_:
			return
	_profile.save()
	_popup("+%d %s" % [n, Outpost.kind_name(what).to_lower()], _my_world_pos(), Color(0.85, 0.85, 0.95))


## Un emplacement d'eau libre pour un radeau près de `from` : {pos, yaw} (l'étrave vers le large), ou {}.
func _raft_spot_near(from: Vector2) -> Dictionary:
	var d := 2.4
	while d <= 16.0:
		for k in 24:
			var dir := Vector2.from_angle(TAU * float(k) / 24.0 + d * 0.31)
			var p := from + dir * d
			var yaw := atan2(-dir.y, dir.x)
			if not _raft_touches(p, yaw):
				return {"pos": p, "yaw": yaw}
		d += 0.8
	return {}


## Vrai si un radeau en `p` (monde x/z), cap `yaw`, toucherait la terre, un quai, un récif ou le bateau des joueurs.
func _raft_touches(p: Vector2, yaw: float) -> bool:
	var pts := Raft.hull_points(p, yaw)
	for q: Vector2 in pts:
		if not _land.is_over_water(q) or _ship.over_hull(_world_to_ship(q)):
			return true
	if Land.hits_land(pts):
		return true
	if not _islands.islands.is_empty() and _islands.ship_hit_index(pts) >= 0:
		return true
	return _rocks.hit(pts).x >= 0


func _spawn_raft(pos: Vector2, yaw: float) -> void:
	_raft = Raft.new()
	_raft.owner_id = _my_id()
	_raft.sim.position = pos
	_raft.sim.yaw = yaw
	_raft.sim.wind_dir = _sim.wind_dir
	_raft.sim.wind_angle = _sim.wind_angle
	_world_fixed.add_child(_raft)
	_raft.float_on(pos, _wave_height, SEA_Y)


## Chaque image : mon radeau navigue (ou reste ancré si je ne suis pas dessus), ceux des autres suivent le réseau.
func _update_rafts(delta: float) -> void:
	if _raft != null:
		var r := _raft
		var riding := _loc == Loc.RAFT
		r.sim.wind_dir = _sim.wind_dir
		r.sim.wind_angle = _sim.wind_angle
		if riding:
			r.sim.anchored = false
			r.sim.sail_trim_target = r.sim.optimal_trim()   # la voile se règle toute seule
		else:
			r.sim.anchored = true
			r.sim.sail_level = 0
			r.sim.rudder_target = 0.0
		var prev_pos := r.sim.position
		var prev_yaw := r.sim.yaw
		r.sim.step(delta)
		if _raft_touches(r.sim.position, r.sim.yaw):
			_raft_bump(prev_pos, prev_yaw)
		r.float_on(r.sim.position, _wave_height, SEA_Y)
		r.update_visual(delta)
		r.set_sail_alpha(0.45 if riding else 1.0)
		if riding:
			_lpos = Raft.stand_world(r.sim.position, r.sim.yaw)
			_sprite.direction = PirateSprite.direction_of(Vector2(cos(r.sim.yaw), -sin(r.sim.yaw)))
	for id in _remote_rafts:
		var rr: Raft = _remote_rafts[id]
		rr.sim.position = rr.sim.position.lerp(rr.get_meta("target", rr.sim.position), 1.0 - exp(-delta * 10.0))
		rr.float_on(rr.sim.position, _wave_height, SEA_Y)
		var ridden := false
		for rid in _remotes:
			if int(_remotes[rid]["loc"]) == 7 and (_remotes[rid]["pos"] as Vector2).distance_to(rr.sim.position) < 2.5:
				ridden = true
		rr.set_sail_alpha(0.38 if ridden else 1.0)
		rr.update_visual(delta)


## Le radeau a touché quelque chose : il glisse le long de l'obstacle s'il peut, sinon il s'arrête.
func _raft_bump(prev_pos: Vector2, prev_yaw: float) -> void:
	var r := _raft
	var np := r.sim.position
	if _raft_touches(prev_pos, prev_yaw):
		return   # il était déjà coincé (le bateau lui est tombé dessus) : on le laisse sortir
	for o: Vector2 in [Vector2(np.x, prev_pos.y), Vector2(prev_pos.x, np.y), prev_pos]:
		if not _raft_touches(o, r.sim.yaw):
			r.sim.position = o
			r.sim.speed *= 0.5
			return
	r.sim.position = prev_pos
	r.sim.yaw = prev_yaw
	r.sim.speed = 0.0


## Barrer (A/D) et régler la voilure (W hisse, S affale) quand je suis sur le radeau.
func _update_raft_pilot(move: Vector2) -> void:
	if _raft == null:
		_loc = Loc.SWIM
		return
	_raft.sim.rudder_target = clampf(move.x, -1.0, 1.0)
	if move.y < -0.5:
		_raft.sim.sail_level = ShipSim.SAIL_LEVELS
	elif move.y > 0.5:
		_raft.sim.sail_level = 0


## Hauteur (scène) du pont de mon radeau si le point monde `w` est dessus, sinon INF.
func _raft_deck_y(w: Vector2) -> float:
	if _raft != null and Raft.covers(_raft.sim.position, _raft.sim.yaw, w):
		return _raft.position.y + Raft.TOP
	return INF


## Je monte sur mon radeau : je me tiens au pied du mât, la voile se hisse.
func _board_raft() -> void:
	if _raft == null:
		return
	_loc = Loc.RAFT
	_mode = Mode.WALK
	_pz = 0.0
	_vz = 0.0
	_flight = {}
	_walkto = Vector2.INF
	_raft.sim.anchored = false
	_dbg("à bord du radeau")
	if _raft.sim.sail_level == 0:
		_raft.sim.sail_level = ShipSim.SAIL_LEVELS
		_raft.sim.sail_trim_target = _raft.sim.optimal_trim()
	_lpos = Raft.stand_world(_raft.sim.position, _raft.sim.yaw)
	_prev_lpos = _lpos
	_splash_burst(_lpos)


## E dans l'eau, tout contre le radeau : on s'y hisse.
func _try_board_raft_from_water() -> bool:
	if _raft != null and Raft.covers(_raft.sim.position, _raft.sim.yaw, _lpos, 1.6):
		_board_raft()
		return true
	return false


## E à terre, au bord de l'eau, près du radeau : on met le pied dessus.
func _try_board_raft_from_land() -> bool:
	if _raft != null and Raft.covers(_raft.sim.position, _raft.sim.yaw, _lpos, 3.0):
		_board_raft()
		return true
	return false


## Quitter le radeau. `jump` (Espace) : on plonge ; sinon (E) on pose le pied sur la terre ou le pont du bateau le plus proche à portée.
func _leave_raft(jump: bool) -> void:
	if _raft == null:
		_loc = Loc.SWIM
		return
	var center := _raft.sim.position
	if not jump:
		var d := 1.8
		while d <= 4.6:
			for k in 24:
				var q := center + Vector2.from_angle(TAU * float(k) / 24.0 + d) * d
				var bp := _world_to_ship(q)
				if _ship.is_walkable(bp):
					_loc = Loc.SHIP
					_mode = Mode.WALK
					_ppos = bp
					_pz = 0.0
					_vz = 0.0
					_land_t = 0.2
					_splash_burst(_lpos)
					return
				if _can_stand_at(q):
					_flight = {}
					if _stand_on_ground(q, _ground_at(q)):
						_splash_burst(_lpos)
						return
			d += 0.4
		_say("Pas de terre ni de bateau à portée : Espace pour plonger", 3.0)
		return
	var side := Vector2(-sin(_raft.sim.yaw), -cos(_raft.sim.yaw)) * (Raft.HALF.y + 0.5)
	_enter_swim(center + side)


## Mon radeau pour les autres : [x, z, cap, ouverture de la voile, orientation de la voile], ou vide si je n'en ai pas.
func raft_net_state() -> Array:
	if _raft == null:
		return []
	return [_raft.sim.position.x, _raft.sim.position.y, _raft.sim.yaw, _raft.sim.sail_open, _raft.sim.sail_trim]


## Le radeau du joueur `id`, reçu du réseau : il glisse vers sa position, ou disparaît (état vide).
func apply_remote_raft(id: int, s: Array) -> void:
	if s.size() < 5:
		if _remote_rafts.has(id):
			(_remote_rafts[id] as Node).queue_free()
			_remote_rafts.erase(id)
		return
	if _world_fixed == null:
		return
	var rr: Raft
	if _remote_rafts.has(id):
		rr = _remote_rafts[id]
	else:
		rr = Raft.new()
		rr.owner_id = id
		_world_fixed.add_child(rr)
		_remote_rafts[id] = rr
		rr.sim.position = Vector2(float(s[0]), float(s[1]))
		_dbg("radeau de %d vu à distance en (%.1f, %.1f)" % [id, float(s[0]), float(s[1])])
	rr.set_meta("target", Vector2(float(s[0]), float(s[1])))
	rr.apply_pose(float(s[2]), float(s[3]), float(s[4]))


# ================================================================== lot 2 : actions longues, saut, port d'objet, échelle

## Où je suis dans le repère de mon lieu (pont, cale, terre, eau) : sert à savoir si je bouge pendant une action.
func _act_pos() -> Vector2:
	if _loc == Loc.HOLD:
		return _hpos
	if _loc == Loc.SHIP:
		return _ppos
	return _lpos


## Le point de la scène où je me tiens (pour y placer un son ou une gerbe).
func _my_scene_pos() -> Vector3:
	return _sprite.global_position if _sprite != null else Vector3.ZERO


## Règle commune (12/11, retour de Jimmy) : pendant qu'on manœuvre quelque chose, on reste sur place. Avant, bouger coupait
## l'ancre en cours (« je me déplace et hop, l'ancre s'arrête ») ou laissait partir en visant au grappin ou au canon.
## On lâche avec une touche d'action (R, E, Espace…) : c'est un choix, plus un accident.
func _station_locked() -> bool:
	return _gun_i >= 0 or _hook_aim or _act != null \
			or (_grap_state != 0 and _grap_state != 4 and _grap_owner == _my_id())


## Commence une action longue (règle commune du lot 2). Sans effet si une autre est en cours.
func _start_action(kind: String, label: String, arg: int = 0) -> void:
	if _act != null:
		return
	_act = TimedAction.create(kind, label + "   (R : arrêter)", TimedAction.duration_of(kind), _act_pos(), arg)
	_act_loc = _loc
	_act_hurt = false
	_act_prev_t = -0.001
	_make_act_prop(_sprite, kind)
	_send_action("act", "%s|%.2f|%d" % [kind, _act.duration, arg], _my_world_pos(), _face)
	_dbg("action %s commencée (%.1f s)" % [kind, _act.duration])


## Chaque image : l'action avance, s'interrompt (je bouge, je saute, je change de lieu, je prends un coup) ou se termine.
func _update_timed_action(delta: float) -> void:
	if _act == null:
		return
	# (les flèches ne coupent plus l'action : on est bloqué à son poste, voir _station_locked ; un saut ou un changement de lieu,
	# si, et une touche d'action aussi)
	var moving := _jump_wind > 0.0 or _pz > 0.05 or _loc != _act_loc
	var finished := _act.step(delta, _act_pos(), moving, _act_hurt)
	_act_hurt = false
	if _act.cancelled:
		_end_action(false)
		return
	_act_gauge.show_progress(_act.label, _act.progress())
	_work_fx(_act.kind, _act_prev_t, _act.t, _act.duration, _my_scene_pos(), "me")
	_act_prev_t = _act.t
	if finished:
		_apply_action_effect(_act)
		_end_action(true)


## Coupe l'action en cours (une autre touche d'action, un coup reçu…).
func _cancel_action() -> void:
	if _act != null:
		_act.cancelled = true
		_end_action(false)


func _end_action(ok: bool) -> void:
	if _act == null:
		return
	_dbg("action %s %s" % [_act.kind, "terminée" if ok else "interrompue"])
	_act = null
	if ok:
		_act_gauge.finish()
	else:
		_act_gauge.interrupt()
	_sfx.stop_loop("me")
	_clear_act_prop(_sprite)
	_send_action("act_end", "1" if ok else "0", _my_world_pos(), _face)


## L'effet d'une action menée à son terme : on le demande à l'hôte, qui fait autorité.
func _apply_action_effect(a: TimedAction) -> void:
	match a.kind:
		"anchor":
			_request("anchor", 0)
			_say("L'ancre est jetée" if not _sim.anchored else "L'ancre est levée", 2.0)
		"repair":
			if _carry_kind == "plank":
				_request("patch", a.arg)
				_drop_carried()
				_say("Voie d'eau bouchée", 2.0)
		"bail":
			_request("bail", 0)
		"hoist":
			_request("hoist", a.arg)
		"revive":
			_request("revive", a.arg)


## Les sons et effets d'une action à l'instant t (de t0 à t1 pendant cette image), à l'endroit `at` (scène). `key` : de qui c'est
## (« me » ou « p<id> ») pour les sons qui durent. Joué chez tout le monde, pour soi comme pour les autres.
func _work_fx(kind: String, t0: float, t1: float, dur: float, at: Vector3, key: String) -> void:
	match kind:
		"anchor":
			_sfx.loop_at(key, Synth.capstan(), at, 0.8, 0.95 + 0.1 * sin(t1 * 2.0))
		"repair":
			var n0 := floori(maxf(t0, 0.0) / GameConfig.HAMMER_EVERY)
			var n1 := floori(t1 / GameConfig.HAMMER_EVERY)
			if t0 < 0.0 or n1 > n0:
				_sfx.play_at(Synth.hammer(n1 % 3), at + Vector3(0.0, 0.6, 0.0), 0.9)
				_chips(at + Vector3(0.0, 0.7, 0.0), Color(0.72, 0.52, 0.3))
		"bail":
			var cut := dur * GameConfig.BAIL_FILL_SHARE
			if t0 < 0.0:
				_sfx.play_at(Synth.bucket_fill(), at, 0.8)
			if t0 < cut and t1 >= cut:
				_sfx.play_at(Synth.bucket_pour(), at + Vector3(0.0, 1.2, 0.0), 0.85)
				_chips(at + Vector3(0.0, 1.3, 0.0), Color(0.7, 0.88, 1.0), 9, 1.3)
		"hoist":
			if t0 < 0.0:
				_sfx.play_at(Synth.rope(), at, 0.8)
		"revive":
			pass


## Petite gerbe (copeaux de bois, eau) en `at` (scène).
func _chips(at: Vector3, color: Color, count: int = 5, lift: float = 0.5) -> void:
	for k in count:
		var drop := _make_ball(0.04, color)
		(drop.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(drop)
		drop.global_position = at
		var a := TAU * float(k) / float(count) + randf() * 0.7
		var d := Vector3(cos(a), 0.0, sin(a)) * randf_range(0.15, 0.4)
		var tw := drop.create_tween()
		tw.set_parallel(true)
		tw.tween_property(drop, "global_position:x", at.x + d.x, 0.35)
		tw.tween_property(drop, "global_position:z", at.z + d.z, 0.35)
		tw.tween_property(drop, "global_position:y", at.y + randf_range(0.15, lift), 0.15).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(drop, "global_position:y", at.y - 0.5, 0.2).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(drop.queue_free)


## L'accessoire tenu pendant une action (le pixel art n'a pas d'images pour ces gestes) : un seau pour écoper, un marteau pour
## clouer. PROVISOIRE : à remplacer par de vraies animations du pirate quand elles seront dessinées.
func _make_act_prop(sprite: PirateSprite, kind: String) -> void:
	_clear_act_prop(sprite)
	var prop: Node3D = null
	match kind:
		"bail":
			var mi := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.16
			cyl.bottom_radius = 0.12
			cyl.height = 0.26
			mi.mesh = cyl
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.55, 0.36, 0.2)
			mi.material_override = m
			prop = mi
		"repair":
			var mh := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.08, 0.32, 0.08)
			mh.mesh = bm
			var mm := StandardMaterial3D.new()
			mm.albedo_color = Color(0.45, 0.3, 0.18)
			mh.material_override = mm
			var head := MeshInstance3D.new()
			var hb := BoxMesh.new()
			hb.size = Vector3(0.18, 0.08, 0.08)
			head.mesh = hb
			var hm := StandardMaterial3D.new()
			hm.albedo_color = Color(0.5, 0.52, 0.56)
			hm.metallic = 0.6
			head.material_override = hm
			head.position = Vector3(0.0, 0.16, 0.0)
			mh.add_child(head)
			prop = mh
	if prop == null:
		return
	prop.name = "ActProp"
	sprite.add_child(prop)


func _clear_act_prop(sprite: PirateSprite) -> void:
	if sprite == null:
		return
	var old := sprite.get_node_or_null("ActProp")
	if old != null:
		old.queue_free()
		sprite.remove_child(old)


## Le geste d'une action, sur le sprite (balancement, coup de marteau, seau qui plonge puis se lève) et son accessoire.
## Renvoie l'écrasement à appliquer au sprite (voir _update_lot2_visuals) : positif, le pirate se tasse ; négatif, il s'étire.
func _work_pose(sprite: PirateSprite, kind: String, t: float, dur: float) -> float:
	var prop := sprite.get_node_or_null("ActProp") as Node3D
	var to_cam := _cam.global_transform.basis.z
	var base := sprite.global_position
	match kind:
		"anchor":   # on pousse sur les barres du cabestan : un balancement lent
			return 0.05 * sin(t * TAU * 0.9)
		"repair":   # coups de marteau
			var ph := fmod(t, GameConfig.HAMMER_EVERY) / GameConfig.HAMMER_EVERY
			if prop != null:
				prop.global_position = base + Vector3(0.0, 0.75 + 0.35 * (1.0 - ph), 0.0) + to_cam * 0.4
				prop.rotation = Vector3(0.0, 0.0, -1.2 * (1.0 - ph))
			return 0.06 * (1.0 - ph)   # tassé au moment du coup
		"bail":   # le seau plonge (remplir), puis monte au-dessus de la tête (vider)
			var k := clampf(t / maxf(dur, 0.01), 0.0, 1.0)
			var h := 0.25 if k < GameConfig.BAIL_FILL_SHARE else lerpf(0.4, 1.8, smoothstep(GameConfig.BAIL_FILL_SHARE, 1.0, k))
			if prop != null:
				prop.global_position = base + Vector3(0.0, h, 0.0) + to_cam * 0.35
				prop.rotation = Vector3(0.0, 0.0, 0.0 if k < 0.8 else -2.0 * (k - 0.8) / 0.2)
			return 0.08 if k < GameConfig.BAIL_FILL_SHARE else -0.04   # accroupi pour remplir, dressé pour vider
		"hoist", "revive":   # on se penche et on tire
			return 0.07 * (0.5 + 0.5 * sin(t * TAU * 1.2))
	return 0.0


## Saut (lot 2, 2.3) : à l'appel et à la réception, un petit écrasement du sprite, un son, et de la poussière à la réception.
func _jump_fx(kind: String) -> void:
	_squash_sprite(_sprite, kind)
	var at := _my_scene_pos()
	if kind == "jump":
		_sfx.play_at(Synth.jump(), at, 0.6)
	else:
		var on_wood := _loc == Loc.SHIP or (_loc == Loc.LAND and _lh > 0.1)
		_sfx.play_at(Synth.land(on_wood), at, 0.75)
		_chips(at + Vector3(0.0, 0.05, 0.0), Color(0.78, 0.7, 0.58, 1.0), 6, 0.25)


func _squash_sprite(sprite: Node3D, kind: String) -> void:
	if sprite != null:
		_squash[sprite.get_instance_id()] = {"t": 0.0, "kind": kind, "node": sprite}


## Chaque image : écrasements de saut et gestes d'action (les miens et ceux des autres), objets portés entre les mains, oreille.
func _update_lot2_visuals(delta: float) -> void:
	_sfx.set_listener(_my_scene_pos() + Vector3(0.0, 1.0, 0.0))
	var poses: Dictionary = {}   # id d'instance -> écrasement de geste
	if _act != null:
		poses[_sprite.get_instance_id()] = _work_pose(_sprite, _act.kind, _act.t, _act.duration)
	# lot 4 : à terre, le pirate est affalé (PROVISOIRE : très tassé, faute d'image « au sol » dans le pixel art) ; mort, il disparaît
	var hidden: Dictionary = {}
	if _is_down():
		poses[_sprite.get_instance_id()] = GameConfig.DOWNED_SQUASH
	if _is_dead():
		hidden[_sprite.get_instance_id()] = true
	for id: int in _remote_downed:
		if _remotes.has(id):
			poses[(_remotes[id]["sprite"] as Node).get_instance_id()] = GameConfig.DOWNED_SQUASH
	for id: int in _remote_dead:
		if _remotes.has(id):
			hidden[(_remotes[id]["sprite"] as Node).get_instance_id()] = true
	for id: int in _remote_acts.keys():
		if not _remotes.has(id):
			_remote_acts.erase(id)
			continue
		var ra: Dictionary = _remote_acts[id]
		var rs := _remotes[id]["sprite"] as PirateSprite
		var t0 := float(ra["t"])
		ra["t"] = t0 + delta
		_work_fx(str(ra["kind"]), t0 if t0 > 0.0 else -0.001, float(ra["t"]), float(ra["dur"]), rs.global_position, "p%d" % id)
		poses[rs.get_instance_id()] = _work_pose(rs, str(ra["kind"]), float(ra["t"]), float(ra["dur"]))
		if float(ra["t"]) > float(ra["dur"]) + 2.0:   # (le message de fin s'est perdu : on arrête de l'animer)
			_end_remote_act(id)
	# écrasements de saut : vite écrasé, puis retour (étiré un instant à l'appel)
	var squash: Dictionary = {}
	for key: int in _squash.keys():
		var s: Dictionary = _squash[key]
		if not is_instance_valid(s["node"]):
			_squash.erase(key)
			continue
		s["t"] = float(s["t"]) + delta
		var k := float(s["t"]) / GameConfig.JUMP_SQUASH_TIME
		if k >= 2.0:
			_squash.erase(key)
			continue
		var amt := GameConfig.JUMP_SQUASH * (sin(PI * minf(k, 1.0)) if k < 1.0 else 0.0)
		squash[key] = amt if str(s["kind"]) == "land" else -amt * 0.6 + (GameConfig.JUMP_SQUASH * 0.5 * sin(PI * (k - 1.0)) if k >= 1.0 else 0.0)
	for sprite: PirateSprite in _all_sprites():
		var key := sprite.get_instance_id()
		var sq := float(squash.get(key, 0.0)) + float(poses.get(key, 0.0))
		# sq > 0 : écrasé (plus large, moins haut) ; sq < 0 : étiré. (Glissé dans un canon, mon pirate est caché en étant réduit
		# à rien : on n'y touche pas.)
		if sprite == _sprite and _mode == Mode.CANNON:
			continue
		if hidden.has(key):
			sprite.scale = Vector3.ONE * 0.001
			continue
		sprite.scale = Vector3(1.0 + sq * 0.6, 1.0 - sq, 1.0)
	# ce que chacun porte, entre les mains (et non plus au-dessus de la tête), visible par tous
	var to_cam := _cam.global_transform.basis.z
	var mine: Node3D = _treasure_icon if _treasure_icon != null else (_ball_icon if _ball_icon.visible else (_plank_icon if _plank_icon.visible else null))
	for n: Node3D in [_treasure_icon, _ball_icon, _plank_icon]:
		if n != null and n == mine:
			n.global_position = _sprite.global_position + Vector3(0.0, GameConfig.CARRY_HANDS_HEIGHT, 0.0) + to_cam * GameConfig.CARRY_TOWARD_CAMERA
	for id: int in _carry_nodes:
		var cn := _carry_nodes[id] as Node3D
		if is_instance_valid(cn) and _remotes.has(id):
			cn.global_position = (_remotes[id]["sprite"] as Node3D).global_position + Vector3(0.0, GameConfig.CARRY_HANDS_HEIGHT, 0.0) + to_cam * GameConfig.CARRY_TOWARD_CAMERA
	# l'échelle : des pas sur le bois pendant qu'on grimpe (coque et mât)
	if _loc == Loc.CLIMB:
		_ladder_step_t -= delta
		if _ladder_step_t <= 0.0:
			_ladder_step_t = GameConfig.LADDER_STEP_EVERY
			_sfx.play_at(Synth.step(2, randi() % 3), _my_scene_pos(), 0.55)
	else:
		_ladder_step_t = 0.0


func _all_sprites() -> Array:
	var out: Array = [_sprite]
	for id in _remotes:
		out.append(_remotes[id]["sprite"])
	return out


## Un autre joueur commence ou finit une action longue (reçu par le réseau) : je joue chez moi son geste et ses sons.
func _remote_act(peer: int, kind: String, arg: String) -> void:
	if not _remotes.has(peer):
		return
	var rs := _remotes[peer]["sprite"] as PirateSprite
	if kind == "act":
		var p := arg.split("|")
		var target := int(p[2]) if p.size() > 2 else 0
		_remote_acts[peer] = {"kind": p[0], "t": 0.0, "dur": float(p[1]) if p.size() > 1 else 1.0, "target": target}
		_make_act_prop(rs, p[0])
		if p[0] == "revive" and target == _my_id():
			_revivers[peer] = true   # lot 4 (5.2) : on me relève, mon compte à rebours s'arrête
	else:
		_end_remote_act(peer)


func _end_remote_act(peer: int) -> void:
	_remote_acts.erase(peer)
	_revivers.erase(peer)   # (s'il me relevait : interrompu, mon compte à rebours reprend)
	_sfx.stop_loop("p%d" % peer)
	if _remotes.has(peer):
		_clear_act_prop(_remotes[peer]["sprite"] as PirateSprite)


# ------------------------------------------------------------------ porter (2.4)

## Ce que je porte, à envoyer aux autres : "" (rien), "ball", "plank" ou "t:<trésor>".
func _carry_code() -> String:
	if not _carrying:
		return ""
	if _carry_kind == "treasure":
		return "t:" + _carry_item
	return _carry_kind


## L'objet porté par un autre joueur, tel qu'il le tient (reçu avec sa position) : on refait sa maquette quand il change.
func _set_remote_carry(id: int, code: String) -> void:
	if str(_remote_carry.get(id, "")) == code:
		return
	_remote_carry[id] = code
	if _carry_nodes.has(id) and is_instance_valid(_carry_nodes[id]):
		(_carry_nodes[id] as Node).queue_free()
	_carry_nodes.erase(id)
	if code == "" or not _remotes.has(id):
		return
	var node: Node3D = null
	if code.begins_with("t:") and Treasure.exists(code.substr(2)):
		node = Treasure.make_icon(code.substr(2))
		node.scale = Vector3.ONE * GameConfig.CARRY_TREASURE_SCALE
	elif code == "ball":
		node = _make_ball(0.14, Color(0.12, 0.12, 0.16))
	elif code == "plank":
		node = _plank_icon.duplicate() as Node3D
		node.visible = true
	if node == null:
		return
	(_remotes[id]["sprite"] as Node3D).add_child(node)
	_carry_nodes[id] = node


## G : poser au sol ce que je porte (pour avoir les mains libres et me défendre). On le reprend avec E.
func _drop_to_ground() -> void:
	if not _carrying:
		return
	if _loc != Loc.LAND or _pz > 0.05:
		_say("Pose-le à terre : sur le bateau, range-le (coffre du capitaine, caisse, étagère de la cale)", 3.5)
		return
	var value := -1 if _carry_kind == "ball" else (-2 if _carry_kind == "plank" else Treasure.index_of(_carry_item))
	if _carry_kind == "treasure" and value < 0:
		return
	_request("drop", value)
	_sfx.play_at(Synth.thump(), _my_scene_pos(), 0.8)
	_drop_carried()
	_loot_cd = 0.6
	_say("Posé au sol : E pour le reprendre", 2.5)


## E à terre, mains libres : je reprends un trésor posé (ou échoué) à mes pieds. Vrai si j'en ai pris un.
func _pick_up_ground_treasure() -> bool:
	if _carrying or _loot.count() == 0:
		return false
	var id := _loot.nearest(_lpos, WorldLoot.PICK_RANGE, func(kind: String) -> bool: return kind.begins_with("t:"))
	if id < 0:
		return false
	_request("loot_take", id)
	_sfx.play_at(Synth.thump(), _my_scene_pos(), 0.6, 1.15)
	return true


# ------------------------------------------------------------------ hisser un camarade (4.5)

## Le nom d'un autre joueur (son pseudo, sinon « ton camarade »).
func _remote_label(id: int) -> String:
	var n := str(_remote_names.get(id, ""))
	return n if n != "" else "ton camarade"


## Un camarade qui nage assez près de moi pour que je l'attrape (je suis sur le pont, au bord ou en haut d'une échelle) : son id, ou 0.
func _hoist_candidate() -> int:
	if _loc != Loc.SHIP or _mode != Mode.WALK or _carrying:
		return 0
	var me := _ship_to_world(_ppos)
	var best := 0
	var best_d := GameConfig.HOIST_REACH
	for id in _remotes:
		var r: Dictionary = _remotes[id]
		if int(r["loc"]) != 5:
			continue
		var d := me.distance_to(r["pos"] as Vector2)
		if d < best_d:
			best_d = d
			best = id
	return best


## Hôte : un camarade est hissé à bord. Il remonte par l'échelle la plus proche (montée normale de l'échelle).
func _do_hoist(target: int) -> void:
	if target == _my_id():
		apply_hoisted()
	elif _net != null and _net.active:
		_net.send_hoist(target)


## On me hisse hors de l'eau (un camarade m'a attrapé) : je remonte par l'échelle la plus proche.
func apply_hoisted() -> void:
	if _loc != Loc.SWIM:
		return
	var best := 0
	var best_d := INF
	for i in _ship.ladders.size():
		var l: Array = _ship.ladders[i]
		var d := _lpos.distance_to(_ship_to_world(Vector2(float(l[0]), float(l[3]))))
		if d < best_d:
			best_d = d
			best = i
	var l2: Array = _ship.ladders[best]
	var deck := _ship.nearest_walkable(Vector2(float(l2[0]), float(l2[1])))
	_cancel_action()
	_loc = Loc.CLIMB
	_mode = Mode.WALK
	_climb = {"kind": "hull", "t": 0.0, "dur": 1.0, "from": _lpos, "to": _ship_to_world(deck), "board": true, "deck": deck,
			"y0": SEA_Y - SWIM_DEPTH, "y1": _ship.position.y + _ship.deck_height(deck.x)}
	_splash_burst(_lpos)
	_sfx.play_at(Synth.rope(), _my_scene_pos(), 0.8)
	_say("Un camarade t'a hissé à bord !", 2.5)


# ================================================================== lot 4 : à terre, mort, réapparition, eau

func _is_down() -> bool:
	return _downed_t >= 0.0


func _is_dead() -> bool:
	return _dead_t >= 0.0


## 5.1 À 0 PV on ne meurt pas : on tombe à terre, immobile, avec un compte à rebours (visible par l'équipage).
func _go_down() -> void:
	if _is_down() or _is_dead():
		return
	_cancel_action()
	_downed_t = GameConfig.DOWNED_TIME
	_revivers.clear()
	_vz = 0.0
	_pz = 0.0
	_jump_wind = 0.0
	_sfx.play_at(Synth.thump(), _my_scene_pos(), 1.0, 0.7)
	_send_action("down", "%.1f" % _downed_t, _my_world_pos(), _face)
	_dbg("à terre (%.0f s)" % _downed_t)


## 5.2 Relevé par un camarade : quelques cœurs, un instant d'invulnérabilité.
func apply_revived() -> void:
	if not _is_down():
		return
	_downed_t = -1.0
	_hp = mini(GameConfig.REVIVED_HP, _hp_max)
	_inv_t = 2.0
	_revivers.clear()
	_send_action("up", "", _my_world_pos(), _face)
	_say("Un camarade t'a relevé !", 3.0)
	_atmo.audio.play_chime()
	_dbg("relevé")


## 5.3, 5.4, 5.8 : la mort. On perd ce qu'on a dans les mains (planche, boulet, trésor : il disparaît) et le pouvoir de sa baie ;
## on réapparaît sur le bateau après GameConfig.RESPAWN_TIME secondes (5.5).
func _die(why: String) -> void:
	if _is_dead():
		return
	_cancel_action()
	_downed_t = -1.0
	_drop_carried()
	var lost_berry := _profile.berry
	if lost_berry != "":
		_profile.berry = ""
		_profile.save()
	_dead_t = GameConfig.RESPAWN_TIME
	_dead_why = why
	_clear_water_threats()
	_sfx.play_at(Synth.death_sting(), _my_scene_pos(), 1.0)
	_send_action("dead", why, _my_world_pos(), _face)
	_dbg("mort (%s)%s" % [why, (", baie perdue : " + lost_berry) if lost_berry != "" else ""])


## 5.5 Réapparition sur son bateau.
func _respawn() -> void:
	_dead_t = -1.0
	_wake_on_ship()
	_inv_t = GameConfig.RESPAWN_INVULNERABLE
	_water_t = 0.0
	_send_action("up", "", _my_world_pos(), _face)
	_say("De retour à bord. Tu as perdu ce que tu portais%s." % (" et le pouvoir de ta baie" if _dead_why != "" else ""), 5.0)


## Chaque image : comptes à rebours (à terre, mort), temps passé dans l'eau (sirène, requins, noyade).
func _update_lot4(delta: float) -> void:
	if _is_dead():
		_dead_t -= delta
		if _dead_t <= 0.0:
			_respawn()
		return
	if _is_down():
		if _revivers.is_empty():   # 5.2 : pendant qu'un camarade me relève, le compte à rebours s'arrête
			_downed_t -= delta
		if _downed_t <= 0.0:
			_die("à terre")
		return
	_update_water(delta)


## 5.6 à 5.9 : le temps passé dans l'eau. Sirène, puis requins qui rôdent et mordent, puis noyade ; tout s'efface dès qu'on
## remonte à bord (échelle, hissé par un camarade, radeau) ou qu'on prend pied.
func _update_water(delta: float) -> void:
	if _loc != Loc.SWIM:
		if _water_t > 0.0:
			_water_t = 0.0
			_clear_water_threats()
		return
	_water_t += delta
	var stage := 0
	if _water_t >= GameConfig.SIREN_AFTER:
		stage = 1
	if _water_t >= GameConfig.SHARKS_AFTER:
		stage = 2
	if _water_t >= GameConfig.SHARK_ATTACK_AFTER:
		stage = 3
	if stage != _water_stage:
		_water_stage = stage
		_send_action("water", str(stage), _lpos, _face)
		if stage == 1:
			_say("Une sirène s'approche : nage jusqu'à elle et appuie sur E, elle te ramènera à ton bateau", 5.0)
		elif stage == 2:
			_say("Des ailerons tournent autour de toi… remonte vite à bord !", 4.0)
			_sfx.play_at(Synth.shark_alert(), _my_scene_pos(), 1.0)
	if stage >= 1 and _siren == null:
		_siren = _make_siren()
		_siren_pos = _lpos + Vector2.from_angle(randf() * TAU) * GameConfig.SIREN_DISTANCE
	if stage >= 2 and _sharks.is_empty():
		for k in GameConfig.SHARK_COUNT:
			_sharks.append({"node": _make_fin(), "a": TAU * float(k) / float(GameConfig.SHARK_COUNT), "scared": 0.0})
	if stage >= 3:
		_shark_bite_t -= delta
		if _shark_bite_t <= 0.0:
			_shark_bite_t = GameConfig.SHARK_BITE_EVERY
			_shark_bite()
	if _water_t >= GameConfig.DROWN_AFTER:
		_die("noyade")
	_place_water_threats(_lpos, _siren, _siren_pos, _sharks, delta, _water_t)


## Un requin mord (sauf s'ils ont tous fui) : un cœur en moins ; à 0, mort directe (dans l'eau, pas d'état à terre).
func _shark_bite() -> void:
	var any_hunting := false
	for s: Dictionary in _sharks:
		if float(s["scared"]) <= 0.0:
			any_hunting = true
	if not any_hunting:
		return
	_hp = maxi(_hp - GameConfig.SHARK_BITE_DAMAGE, 0)
	_island_hud.flash = 1.0
	_shake_t = 0.3
	_splash_burst(_lpos)
	_sfx.play_at(Synth.splash(), _my_scene_pos(), 1.0, 0.7)
	_say("Un requin t'a mordu !", 2.0)
	if _hp <= 0:
		_die("requins")


## Un coup de sabre à la nage : le requin le plus proche devant moi prend peur et s'éloigne un moment.
func _scare_shark() -> bool:
	for s: Dictionary in _sharks:
		var n := s["node"] as Node3D
		if n == null:
			continue
		var p := Vector2(n.position.x, n.position.z)   # (les ailerons sont dans le monde fixe : coordonnées du monde)
		if p.distance_to(_lpos) < 3.2:
			s["scared"] = GameConfig.SHARK_SCARED
			_shark_bite_t = maxf(_shark_bite_t, 2.0)
			_splash_burst(p)
			_say("Le requin s'éloigne !", 1.5)
			return true
	return false


func _clear_water_threats() -> void:
	if _siren != null:
		_siren.queue_free()
		_siren = null
	for s: Dictionary in _sharks:
		if is_instance_valid(s["node"]):
			(s["node"] as Node).queue_free()
	_sharks.clear()
	_water_stage = 0
	_shark_bite_t = 0.0


## Place la sirène (qui ondule, et s'approche un peu) et les ailerons (qui tournent autour du nageur, se resserrent quand ils
## chassent, s'écartent quand ils ont peur). Sert pour moi et, chez moi, pour un camarade qui nage (mêmes règles, d'après son étape).
func _place_water_threats(center: Vector2, siren: Node3D, siren_pos: Vector2, sharks: Array, delta: float, t: float) -> void:
	if siren != null:
		var sy := SEA_Y + _wave_height(siren_pos) - 0.25 + sin(t * 2.2) * 0.12
		siren.position = Vector3(siren_pos.x, sy, siren_pos.y)
		siren.rotation.y = atan2(center.x - siren_pos.x, center.y - siren_pos.y)
	for s: Dictionary in sharks:
		var n := s["node"] as Node3D
		if not is_instance_valid(n):
			continue
		s["scared"] = maxf(float(s["scared"]) - delta, 0.0)
		var hunting := float(s["scared"]) <= 0.0
		var r := (2.6 if hunting else 6.5) + 0.6 * sin(t * 0.7 + float(s["a"]))
		s["a"] = float(s["a"]) + delta * (0.9 if hunting else 0.4)
		var a := float(s["a"])
		var p := center + Vector2(cos(a), sin(a)) * r
		n.position = Vector3(p.x, SEA_Y + _wave_height(p) + 0.05, p.y)
		n.rotation.y = -a   # l'aileron file dans le sens du cercle


## La sirène (PROVISOIRE : maquette simple, à remplacer par un vrai modèle) : buste, chevelure, queue turquoise, halo.
func _make_siren() -> Node3D:
	var root := Node3D.new()
	var body := _make_ball(0.28, Color(0.95, 0.78, 0.66))
	body.position = Vector3(0, 0.55, 0)
	body.scale = Vector3(0.9, 1.3, 0.8)
	root.add_child(body)
	var head := _make_ball(0.2, Color(0.95, 0.78, 0.66))
	head.position = Vector3(0, 1.05, 0)
	root.add_child(head)
	var hair := _make_ball(0.25, Color(0.85, 0.25, 0.3))
	hair.position = Vector3(0, 1.1, -0.06)
	hair.scale = Vector3(1.0, 1.15, 1.0)
	root.add_child(hair)
	var tail := _make_ball(0.3, Color(0.15, 0.75, 0.7))
	tail.position = Vector3(0, 0.05, 0.2)
	tail.scale = Vector3(0.8, 0.6, 1.6)
	root.add_child(tail)
	var halo := _make_ball(0.6, Color(0.6, 1.0, 0.95))
	var hm := halo.material_override as StandardMaterial3D
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.albedo_color = Color(0.6, 1.0, 0.95, 0.18)
	halo.position = Vector3(0, 0.6, 0)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	_world_fixed.add_child(root)
	_sfx.play_at(Synth.chime(), root.global_position, 0.8, 0.8)
	return root


## Un aileron de requin (PROVISOIRE) : un triangle gris sombre qui fend l'eau, et son sillage d'écume.
func _make_fin() -> Node3D:
	var root := Node3D.new()
	var fin := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.5, 0.55, 0.08)
	pm.left_to_right = 0.15
	fin.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.28, 0.31, 0.36)
	fin.material_override = m
	fin.position = Vector3(0, 0.25, 0)
	root.add_child(fin)
	var foam := _make_ball(0.18, Color(0.9, 0.97, 1.0))
	(foam.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam.scale = Vector3(2.2, 0.2, 0.8)
	root.add_child(foam)
	_world_fixed.add_child(root)
	return root


## 5.6 E près de la sirène : elle me ramène sur mon bateau.
func _try_siren() -> bool:
	if _siren == null or _lpos.distance_to(_siren_pos) > GameConfig.SIREN_REACH:
		return false
	_sfx.play_at(Synth.chime(), _my_scene_pos(), 1.0, 1.2)
	_transition(func() -> void:
		_wake_on_ship()
		_hp = maxi(_hp, 1)
		_say("La sirène t'a ramené à ton bateau", 3.5), false)
	return true


## Un camarade à terre, à portée pour le relever : son id, ou 0.
func _revive_candidate() -> int:
	if _carrying or _is_down() or _is_dead():
		return 0
	var me := _my_world_pos()
	for id: int in _remote_downed:
		if not _remotes.has(id):
			continue
		var r: Dictionary = _remotes[id]
		var p: Vector2 = r["pos"]
		if int(r["loc"]) == 0:
			p = _ship_to_world(p)
		elif int(r["loc"]) != 1:
			continue
		if me.distance_to(p) <= GameConfig.REVIVE_REACH:
			return id
	return 0


## Hôte : `target` est relevé (par celui qui a mené l'action jusqu'au bout).
func _do_revive(target: int) -> void:
	if target == _my_id():
		apply_revived()
	elif _net != null and _net.active:
		_net.send_revive(target)


## Événements de l'état d'un camarade (reçus par le réseau) : à terre, relevé, mort, temps dans l'eau.
func _remote_state_event(peer: int, kind: String, arg: String) -> void:
	if kind == "up" or kind == "dead":   # plus à terre : son nom revient au-dessus de sa tête
		if _remotes.has(peer):
			_set_name_tag((_remotes[peer]["sprite"] as Node).get_node_or_null("NameTag") as Label3D, str(_remote_names.get(peer, "")))
	match kind:
		"down":
			_remote_downed[peer] = {"t": float(arg)}
		"up":
			_remote_downed.erase(peer)
			_remote_dead.erase(peer)
			_set_remote_water(peer, 0)
		"dead":
			_remote_downed.erase(peer)
			_remote_dead[peer] = true
			_set_remote_water(peer, 0)
		"water":
			_set_remote_water(peer, int(arg))


## Ce qui menace un camarade dans l'eau, vu de chez moi (sirène, ailerons), d'après l'étape qu'il annonce.
func _set_remote_water(peer: int, stage: int) -> void:
	var w: Dictionary = _remote_water.get(peer, {"stage": 0, "siren": null, "sharks": [], "t": 0.0, "siren_pos": Vector2.ZERO})
	w["stage"] = stage
	if stage < 1 and w["siren"] != null:
		(w["siren"] as Node).queue_free()
		w["siren"] = null
	if stage < 2:
		for s: Dictionary in w["sharks"]:
			if is_instance_valid(s["node"]):
				(s["node"] as Node).queue_free()
		w["sharks"] = []
	if stage >= 1 and w["siren"] == null and _remotes.has(peer):
		w["siren"] = _make_siren()
		w["siren_pos"] = (_remotes[peer]["pos"] as Vector2) + Vector2(GameConfig.SIREN_DISTANCE, 0.0)
	if stage >= 2 and (w["sharks"] as Array).is_empty():
		var arr: Array = []
		for k in GameConfig.SHARK_COUNT:
			arr.append({"node": _make_fin(), "a": TAU * float(k) / float(GameConfig.SHARK_COUNT), "scared": 0.0})
		w["sharks"] = arr
	_remote_water[peer] = w


## Chaque image (lot 4) : comptes à rebours des camarades à terre (affichés au-dessus d'eux), menaces dans l'eau des camarades.
func _update_remote_lot4(delta: float) -> void:
	for id: int in _remote_downed.keys():
		var d: Dictionary = _remote_downed[id]
		var reviving := false
		for rid: int in _remote_acts:
			var ra: Dictionary = _remote_acts[rid]
			if str(ra["kind"]) == "revive" and int(ra.get("target", 0)) == id:
				reviving = true
		if _act != null and _act.kind == "revive" and _act.arg == id:
			reviving = true
		if not reviving:
			d["t"] = maxf(float(d["t"]) - delta, 0.0)
		d["reviving"] = reviving
		if _remotes.has(id):   # son compte à rebours, au-dessus de lui, pour tout l'équipage
			var tag := (_remotes[id]["sprite"] as Node).get_node_or_null("NameTag") as Label3D
			_set_name_tag(tag, "%s — À TERRE %d s%s" % [_remote_label(id), ceili(float(d["t"])), " (on le relève…)" if reviving else " — E : relever"])
	for id: int in _remote_water.keys():
		var w: Dictionary = _remote_water[id]
		if not _remotes.has(id) or int(w["stage"]) == 0:
			continue
		w["t"] = float(w["t"]) + delta
		_place_water_threats(_remotes[id]["pos"], w["siren"], w["siren_pos"], w["sharks"], delta, float(w["t"]))


## Le texte au centre de l'écran (lot 4) : à terre, mort, noyade qui approche ; et au-dessus des camarades à terre.
func _lot4_center_text() -> String:
	if _is_dead():
		var why := {"à terre": "Personne ne t'a relevé…", "noyade": "Tu t'es noyé…", "requins": "Les requins ont eu raison de toi…"}
		return "%s\nRéapparition sur ton bateau dans %d s" % [str(why.get(_dead_why, "Tu es mort…")), ceili(_dead_t)]
	if _is_down():
		return "À TERRE — %d s\n%s" % [ceili(_downed_t), "Un camarade te relève…" if not _revivers.is_empty() else "Un camarade peut te relever (E près de toi)"]
	if _loc == Loc.SWIM and _water_t >= GameConfig.DROWN_AFTER - GameConfig.DROWN_WARNING:
		return "Tu te noies ! %d s — remonte à bord, ou rejoins la sirène" % ceili(GameConfig.DROWN_AFTER - _water_t)
	return ""


## Invite de la ligne du bas sur le radeau.
func _raft_prompt() -> String:
	var kts := _raft.sim.speed * 1.944 if _raft != null else 0.0
	var sail := "voile hissée" if _raft != null and _raft.sim.sail_level > 0 else "voile affalée"
	return "Radeau (%.1f nœuds, %s) — A/D : barrer   W/S : hisser / affaler   E : débarquer   Espace : plonger" % [kts, sail]

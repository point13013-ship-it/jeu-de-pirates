class_name UiTheme
extends RefCounted
## Le style commun des écrans (12/11/2026, refonte demandée par Jimmy : « les menus sont trop moches »). Inspiré des jeux de
## pirates actuels (Sea of Thieves : bois sombre, laiton, parchemin, encre) et des règles d'interface courantes :
## - grands contrastes (texte clair sur bois sombre, encre sur parchemin), contour ou ombre sous tout texte posé sur le jeu ;
## - tailles minimales à 1080p : 16 px pour le texte courant, 20-24 pour les titres de section, 40+ pour un titre d'écran ;
## - cases d'inventaire de 64 px, 6 px d'écart, icône au centre, nombre en bas à droite ;
## - animations d'interface courtes (0,12 à 0,2 s), survol visible (bordure laiton, léger agrandissement).
## Tout est fabriqué en code (StyleBoxFlat), sans fichier : rien à importer.

const WOOD := Color("2e1d12")         ## bois sombre (fonds des panneaux)
const WOOD_MID := Color("4a2f1c")
const WOOD_LIGHT := Color("6b4428")
const BRASS := Color("d9a441")        ## laiton (bordures, titres)
const BRASS_DARK := Color("8a6526")
const PARCHMENT := Color("ead9b0")    ## parchemin (cases, fiches)
const PARCHMENT_DARK := Color("c9b183")
const INK := Color("2a1b12")          ## encre (texte sur parchemin)
const CREAM := Color("fff1d6")        ## texte sur bois
const MUTED := Color("b8a58a")
const RED := Color("c4553f")          ## manque, danger
const GREEN := Color("7fb069")        ## possible, prêt
const SEA := Color("2d6f7a")

const ANIM := 0.15                    ## s : durée des petites animations d'interface

## Polices libres (OFL, Google Fonts, licences dans assets/fonts) : Pirata One pour les titres (≥ TITLE_FROM px),
## IM Fell English (caractères d'imprimerie du XVIIe) pour les boutons et le texte. Sans le fichier, police par défaut.
const TITLE_FONT_PATH := "res://assets/fonts/PirataOne-Regular.ttf"
const TEXT_FONT_PATH := "res://assets/fonts/IMFellEnglish-Regular.ttf"
const TITLE_FROM := 26
const TEXT_FROM := 16

static var _fonts := {}


static func _font(path: String) -> Font:
	if not _fonts.has(path):
		_fonts[path] = load(path) if ResourceLoader.exists(path) else null
	return _fonts[path]


static func title_font() -> Font:
	return _font(TITLE_FONT_PATH)


static func text_font() -> Font:
	return _font(TEXT_FONT_PATH)


## Pose la bonne police sur un contrôle selon la taille du texte (titre ou texte courant).
## Sous TEXT_FROM px (touches, quantités, aides), on garde la police par défaut, plus lisible en petit.
static func apply_font(c: Control, font_size: int) -> void:
	if font_size < TEXT_FROM:
		return
	var f := title_font() if font_size >= TITLE_FROM else text_font()
	if f != null:
		c.add_theme_font_override("font", f)


## Panneau de bois à bordure de laiton (fenêtres : sac, menu pause, coffre).
static func panel(alpha: float = 0.96) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(WOOD, alpha)
	sb.border_color = BRASS_DARK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 14
	sb.set_content_margin_all(18)
	return sb


## Encart de parchemin (description d'un objet, fiche de recette).
static func parchment() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCHMENT
	sb.border_color = PARCHMENT_DARK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	return sb


## Une case d'inventaire : sombre et creusée ; sélectionnée, bordure laiton épaisse ; vide, plus pâle.
static func slot(selected: bool, empty: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(WOOD_MID, 0.55 if empty else 0.95)
	sb.border_color = BRASS if selected else Color(BRASS_DARK, 0.7)
	sb.set_border_width_all(3 if selected else 2)
	sb.set_corner_radius_all(6)
	if selected:
		sb.shadow_color = Color(BRASS, 0.35)
		sb.shadow_size = 6
	return sb


## Les styles d'un bouton (bois, bordure laiton au survol, enfoncé plus clair).
static func style_button(b: Button, font_size: int = 18) -> void:
	var states := {"normal": WOOD_MID, "hover": WOOD_LIGHT, "pressed": Color("8a5a2a"), "focus": WOOD_MID, "disabled": Color(WOOD, 0.7)}
	for state: String in states:
		var sb := StyleBoxFlat.new()
		sb.bg_color = states[state]
		sb.set_corner_radius_all(7)
		sb.set_border_width_all(2)
		sb.border_color = BRASS if state in ["hover", "pressed", "focus"] else BRASS_DARK
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_font_size_override("font_size", font_size)
	apply_font(b, font_size)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	b.add_theme_constant_override("outline_size", 3)
	# survol : le bouton grossit à peine (retour immédiat, comme les jeux actuels)
	b.mouse_entered.connect(func() -> void: _pop(b, 1.04))
	b.mouse_exited.connect(func() -> void: _pop(b, 1.0))
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)


static func _pop(c: Control, s: float) -> void:
	if not c.is_inside_tree():
		return
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * s, ANIM).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Un texte : taille, couleur, contour (pour rester lisible sur le jeu).
static func label(text: String, font_size: int, color: Color = CREAM, outline: int = 4) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	apply_font(l, font_size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 0.9))
		l.add_theme_constant_override("outline_size", outline)
	return l


## Titre de section (laiton, avec un trait dessous).
static func section(text: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.add_child(label(text.to_upper(), 15, BRASS, 3))
	var line := ColorRect.new()
	line.color = Color(BRASS_DARK, 0.8)
	line.custom_minimum_size = Vector2(0, 2)
	box.add_child(line)
	return box


## Fait apparaître un panneau (fondu et léger zoom), comme une fenêtre qu'on ouvre.
static func appear(c: Control) -> void:
	c.modulate.a = 0.0
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2.ONE * 0.96
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, ANIM)
	tw.tween_property(c, "scale", Vector2.ONE, ANIM * 1.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ curseur (13/11/2026)
# Un curseur dessiné dans le style du jeu : une pointe de sabre en laiton, cernée de sombre, avec un reflet clair. Sur un bouton
# (main), la même pointe en or vif. Fabriqué par le code (pixel art agrandi sans lissage), posé une fois au lancement.
const _CURSOR_ROWS := [
	"X...............",
	"XX..............",
	"XoX.............",
	"XooX............",
	"XoooX...........",
	"XolooX..........",
	"XoloooX.........",
	"XollooooX.......",
	"XolloooooX......",
	"XollooooooX.....",
	"XolooooXXXXX....",
	"XooXooX.........",
	"XoX.XooX........",
	"XX..XooX........",
	"X....XooX.......",
	".....XooX.......",
	"......XX........",
]


static func _cursor_texture(fill: Color, light: Color, scale: int) -> ImageTexture:
	var w := 16
	var h := _CURSOR_ROWS.size()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var row: String = _CURSOR_ROWS[y]
		for x in mini(row.length(), w):
			match row[x]:
				"X":
					img.set_pixel(x, y, Color("1C1726"))
				"o":
					img.set_pixel(x, y, fill)
				"l":
					img.set_pixel(x, y, light)
	img.resize(w * scale, h * scale, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


## Pose le curseur du jeu (flèche, et sa variante sur les boutons).
static func apply_cursor() -> void:
	Input.set_custom_mouse_cursor(_cursor_texture(Color("DCAE5C"), Color("FFE2A0"), 2), Input.CURSOR_ARROW, Vector2(1, 1))
	Input.set_custom_mouse_cursor(_cursor_texture(Color("FFD23F"), Color("FFFFFF"), 2), Input.CURSOR_POINTING_HAND, Vector2(1, 1))

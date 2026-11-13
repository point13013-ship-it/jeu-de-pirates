class_name Synth
extends RefCounted
## Les sons du jeu, fabriqués par le code (aucun fichier audio) : bruit filtré, enveloppes et quelques sinusoïdes, mixés
## en 16 bits mono. Les sons d'ambiance sont des boucles sans raccord (fin fondue dans le début) ; les autres, des sons
## brefs. Tout est déterministe (graine fixe) et mis en cache : un son n'est fabriqué qu'une fois.

const RATE := 22050
static var _cache: Dictionary = {}


# ------------------------------------------------------------------ outils

static func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


## Bruit blanc de `n` échantillons (-1…1).
static func _noise(n: int, seed_value: int) -> PackedFloat32Array:
	var r := _rng(seed_value)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = r.randf() * 2.0 - 1.0
	return out


## Filtre passe-bas à un pôle (fréquence de coupure `hz`).
static func _lowpass(x: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * hz / RATE)
	var y := 0.0
	var out := PackedFloat32Array()
	out.resize(x.size())
	for i in x.size():
		y += a * (x[i] - y)
		out[i] = y
	return out


## Passe-haut : le signal moins son passe-bas.
static func _highpass(x: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	var lp := _lowpass(x, hz)
	var out := PackedFloat32Array()
	out.resize(x.size())
	for i in x.size():
		out[i] = x[i] - lp[i]
	return out


static func _normalize(x: PackedFloat32Array, peak: float = 0.9) -> PackedFloat32Array:
	var m := 0.0001
	for v in x:
		m = maxf(m, absf(v))
	var k := peak / m
	for i in x.size():
		x[i] *= k
	return x


## Fond la fin dans le début sur `fade` échantillons, pour que la boucle ne claque pas au raccord.
static func _loopify(x: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var n := x.size() - fade
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = x[i]
	for i in fade:
		var k := float(i) / float(fade)
		out[i] = x[i] * k + x[n + i] * (1.0 - k)
	return out


static func _to_stream(x: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(x.size() * 2)
	for i in x.size():
		data.encode_s16(i * 2, int(clampf(x[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = x.size()
	return w


static func _cached(key: String, builder: Callable) -> AudioStreamWAV:
	if not _cache.has(key):
		_cache[key] = builder.call()
	return _cache[key]


# ------------------------------------------------------------------ boucles d'ambiance

## La mer qui vient mourir sur le rivage : un grondement qui monte et redescend, un chuintement d'écume au sommet.
static func waves() -> AudioStreamWAV:
	return _cached("waves", func() -> AudioStreamWAV:
		var secs := 9.0
		var n := int(secs * RATE)
		var rumble := _lowpass(_noise(n + 4000, 11), 380.0)
		var hiss := _highpass(_lowpass(_noise(n + 4000, 12), 4200.0), 1400.0)
		var out := PackedFloat32Array()
		out.resize(n + 4000)
		for i in out.size():
			var t := float(i) / RATE
			var swell := 0.5 + 0.5 * sin(TAU * t / 9.0 - 1.2)   # une grosse vague par boucle
			var swell2 := 0.5 + 0.5 * sin(TAU * t / 4.5 + 0.7)
			var env := 0.25 + 0.75 * pow(swell * 0.75 + swell2 * 0.25, 1.6)
			out[i] = rumble[i] * 2.6 * env + hiss[i] * 1.6 * pow(env, 3.0)
		return _to_stream(_loopify(_normalize(out, 0.8), 4000), true))


## Le vent : un souffle grave qui enfle et retombe, avec un léger sifflement.
static func wind() -> AudioStreamWAV:
	return _cached("wind", func() -> AudioStreamWAV:
		var n := int(7.0 * RATE)
		var low := _lowpass(_noise(n + 4000, 21), 260.0)
		var mid := _highpass(_lowpass(_noise(n + 4000, 22), 1100.0), 500.0)
		var out := PackedFloat32Array()
		out.resize(n + 4000)
		for i in out.size():
			var t := float(i) / RATE
			var gust := 0.45 + 0.35 * sin(TAU * t / 7.0) + 0.2 * sin(TAU * t / 3.5 + 1.3)
			out[i] = low[i] * 3.0 * gust + mid[i] * 1.2 * gust * gust
		return _to_stream(_loopify(_normalize(out, 0.7), 4000), true))


## La coque qui fend les vagues : un chuintement d'eau qui frotte le bois (bruit filtré) et des claques de vague sourdes qui
## reviennent irrégulièrement. Le jeu règle son volume et sa hauteur d'après la vitesse du bateau.
static func hull() -> AudioStreamWAV:
	return _cached("hull", func() -> AudioStreamWAV:
		var n := int(6.0 * RATE)
		var rub := _highpass(_lowpass(_noise(n + 4000, 31), 2600.0), 380.0)   # le frottement
		var slap := _lowpass(_noise(n + 4000, 32), 260.0)                      # les claques de vague
		var out := PackedFloat32Array()
		out.resize(n + 4000)
		for i in out.size():
			var t := float(i) / RATE
			var flow := 0.55 + 0.25 * sin(TAU * t / 6.0 + 0.4) + 0.2 * sin(TAU * t / 2.0 + 1.9)
			var hit := pow(maxf(0.0, sin(TAU * t / 1.5 + 0.6) * sin(TAU * t / 2.4 + 2.1)), 2.0)   # une claque de temps en temps
			out[i] = rub[i] * 2.2 * flow + slap[i] * 3.2 * (0.25 + 1.6 * hit)
		return _to_stream(_loopify(_normalize(out, 0.75), 4000), true))


## Un feu de camp : un ronflement sourd et des craquements au hasard.
static func fire() -> AudioStreamWAV:
	return _cached("fire", func() -> AudioStreamWAV:
		var n := int(4.0 * RATE)
		var out := _lowpass(_noise(n + 4000, 31), 180.0)
		for i in out.size():
			out[i] *= 2.2
		var r := _rng(32)
		for k in 52:   # une cinquantaine de craquements sur 4 s
			var at := r.randi_range(0, n + 3000)
			var amp := r.randf_range(0.15, 0.9)
			var len := r.randi_range(120, 900)
			var tone := r.randf_range(0.3, 0.95)
			var prev := 0.0
			for j in len:
				if at + j >= out.size():
					break
				var e := exp(-float(j) / (len * 0.28))
				var nz := r.randf() * 2.0 - 1.0
				prev += tone * (nz - prev)
				out[at + j] += (nz - prev) * amp * e
		return _to_stream(_loopify(_normalize(out, 0.7), 4000), true))


## La pluie : un grésillement constant.
static func rain() -> AudioStreamWAV:
	return _cached("rain", func() -> AudioStreamWAV:
		var n := int(3.0 * RATE)
		var hi := _highpass(_noise(n + 3000, 41), 1800.0)
		var out := PackedFloat32Array()
		out.resize(n + 3000)
		for i in out.size():
			out[i] = hi[i] * (0.8 + 0.2 * sin(TAU * float(i) / RATE * 1.7))
		return _to_stream(_loopify(_normalize(out, 0.6), 3000), true))


## Les insectes d'une île verte : des trilles aigus par groupes.
static func insects() -> AudioStreamWAV:
	return _cached("insects", func() -> AudioStreamWAV:
		var n := int(5.0 * RATE)
		var out := PackedFloat32Array()
		out.resize(n + 3000)
		var r := _rng(51)
		for k in 9:
			var at := r.randi_range(0, n - 1000)
			var f := r.randf_range(3800.0, 5200.0)
			var pulses := r.randi_range(3, 7)
			var gap := r.randf_range(0.045, 0.07)
			for p in pulses:
				var start := at + int(p * gap * RATE)
				var len := int(0.03 * RATE)
				for j in len:
					if start + j >= out.size():
						break
					out[start + j] += sin(TAU * f * float(j) / RATE) * sin(PI * float(j) / len) * 0.5
		return _to_stream(_loopify(_normalize(out, 0.45), 3000), true))


# ------------------------------------------------------------------ sons brefs

## Chant d'oiseau (3 variantes) : de petits sifflets qui montent et descendent.
static func bird(variant: int) -> AudioStreamWAV:
	return _cached("bird%d" % variant, func() -> AudioStreamWAV:
		var r := _rng(60 + variant)
		var out := PackedFloat32Array()
		var notes := 3 + variant * 2
		var base := 2200.0 + 500.0 * variant
		for k in notes:
			var len := int(r.randf_range(0.05, 0.11) * RATE)
			var f0 := base * r.randf_range(0.8, 1.5)
			var f1 := f0 * r.randf_range(0.6, 1.7)
			var ph := 0.0
			var seg := PackedFloat32Array()
			seg.resize(len)
			for j in len:
				var u := float(j) / len
				ph += TAU * lerpf(f0, f1, u) / RATE
				seg[j] = sin(ph) * sin(PI * u) * 0.6
			out.append_array(seg)
			var gap := PackedFloat32Array()
			gap.resize(int(r.randf_range(0.02, 0.07) * RATE))
			out.append_array(gap)
		return _to_stream(_normalize(out, 0.5), false))


## Cri de mouette : deux notes plaintives, voix un peu rauque.
static func gull() -> AudioStreamWAV:
	return _cached("gull", func() -> AudioStreamWAV:
		var out := PackedFloat32Array()
		for note in 3:
			var len := int((0.28 if note < 2 else 0.5) * RATE)
			var f0 := 1500.0 + note * 150.0
			var ph := 0.0
			var seg := PackedFloat32Array()
			seg.resize(len)
			for j in len:
				var u := float(j) / len
				var f := f0 * (1.0 + 0.45 * sin(PI * u) - 0.25 * u) * (1.0 + 0.03 * sin(TAU * 28.0 * u))
				ph += TAU * f / RATE
				var s := sin(ph) + 0.5 * sin(2.0 * ph) + 0.3 * sin(3.0 * ph)
				seg[j] = s * sin(PI * u) * 0.45
			out.append_array(seg)
			var gap := PackedFloat32Array()
			gap.resize(int(0.07 * RATE))
			out.append_array(gap)
		return _to_stream(_normalize(out, 0.55), false))


## Un pas : 0 sable, 1 herbe, 2 bois (pont, ponton, plancher), 3 eau peu profonde, 4 pierre (pavés) (variantes 0…2).
static func step(kind: int, variant: int) -> AudioStream:
	var rec := recorded(["step_sand", "step_grass", "step_wood", "step_water", "step_stone"][clampi(kind, 0, 4)])
	if kind == 4 and rec == null:
		kind = 0   # (pas de prise « pierre » : le son fabriqué le plus proche est le sable)
	if rec != null:
		return rec   # (les prises enregistrées varient d'elles-mêmes : `variant` ne sert plus qu'au son fabriqué)
	return _cached("step%d_%d" % [kind, variant], func() -> AudioStreamWAV:
		var r := _rng(100 + kind * 10 + variant)
		var len := int(0.16 * RATE)
		var nz := PackedFloat32Array()
		nz.resize(len)
		for i in len:
			nz[i] = r.randf() * 2.0 - 1.0
		var out := PackedFloat32Array()
		out.resize(len)
		match kind:
			0:   # sable : un frottement sourd
				var lp := _lowpass(nz, 1300.0 + variant * 150.0)
				for i in len:
					out[i] = lp[i] * exp(-float(i) / (len * 0.35)) * 1.6
			1:   # herbe : un froissement plus aigu
				var bp := _highpass(_lowpass(nz, 4200.0), 1100.0)
				for i in len:
					out[i] = bp[i] * exp(-float(i) / (len * 0.45)) * (0.7 + 0.3 * sin(float(i) * 0.02 + variant)) * 1.5
			2:   # bois : un toc grave et un claquement
				var lp2 := _lowpass(nz, 2400.0)
				var f := 95.0 + variant * 14.0
				for i in len:
					var e := exp(-float(i) / (len * 0.22))
					out[i] = (sin(TAU * f * float(i) / RATE) * 0.9 + lp2[i] * 0.45) * e
			_:   # eau peu profonde : un clapotis
				var hp := _highpass(_lowpass(nz, 5200.0), 800.0)
				for i in len:
					out[i] = hp[i] * exp(-float(i) / (len * 0.55)) * (0.8 + 0.4 * sin(float(i) * 0.05 + variant))
		return _to_stream(_normalize(out, 0.55), false))


## Une éclaboussure : plus longue et plus grasse qu'un pas dans l'eau.
static func splash() -> AudioStreamWAV:
	return _cached("splash", func() -> AudioStreamWAV:
		var len := int(0.45 * RATE)
		var hp := _highpass(_lowpass(_noise(len, 71), 6000.0), 500.0)
		var out := PackedFloat32Array()
		out.resize(len)
		for i in len:
			var u := float(i) / len
			out[i] = hp[i] * pow(1.0 - u, 2.0) * (1.0 + 0.5 * sin(u * 40.0))
		return _to_stream(_normalize(out, 0.6), false))


## Des feuilles qu'on froisse (on secoue un palmier, on traverse un buisson).
static func rustle() -> AudioStreamWAV:
	return _cached("rustle", func() -> AudioStreamWAV:
		var len := int(0.5 * RATE)
		var hp := _highpass(_lowpass(_noise(len, 81), 7000.0), 2500.0)
		var out := PackedFloat32Array()
		out.resize(len)
		for i in len:
			var u := float(i) / len
			out[i] = hp[i] * sin(PI * pow(u, 0.6)) * (0.6 + 0.4 * sin(u * 60.0))
		return _to_stream(_normalize(out, 0.5), false))


## Petit carillon : on ramasse ou on trouve quelque chose.
static func chime() -> AudioStreamWAV:
	return _cached("chime", func() -> AudioStreamWAV:
		var len := int(0.7 * RATE)
		var out := PackedFloat32Array()
		out.resize(len)
		for i in len:
			var t := float(i) / RATE
			out[i] = (sin(TAU * 880.0 * t) + 0.6 * sin(TAU * 1320.0 * t) + 0.3 * sin(TAU * 1760.0 * t)) * exp(-t * 6.0)
		return _to_stream(_normalize(out, 0.5), false))


## Un grincement de bois (île de morts) : une note qui glisse, avec ses harmoniques.
static func creak() -> AudioStreamWAV:
	return _cached("creak", func() -> AudioStreamWAV:
		var len := int(1.1 * RATE)
		var out := PackedFloat32Array()
		out.resize(len)
		var ph := 0.0
		for i in len:
			var u := float(i) / len
			var f := lerpf(210.0, 150.0, u) * (1.0 + 0.06 * sin(TAU * 11.0 * u))
			ph += TAU * f / RATE
			out[i] = (sin(ph) + 0.55 * sin(2.0 * ph) + 0.4 * sin(3.0 * ph + 1.0)) * sin(PI * u) * (0.6 + 0.4 * sin(TAU * 23.0 * u))
		return _to_stream(_normalize(out, 0.45), false))


# ------------------------------------------------------------------ vrais enregistrements (Epidemic Sound)
# Les fichiers res://assets/audio/sfx/<nom>_1.ogg, <nom>_2.ogg… remplacent le son fabriqué du même nom. Coupés et normalisés
# à -16 LUFS (ffmpeg) depuis les téléchargements.
# Pratique courante du son de jeu (Wwise « Random Container » en mode shuffle, AudioStreamRandomizer de Godot) : plusieurs
# prises du même bruit, tirées au hasard SANS rejouer la même deux fois de suite, avec une petite variation de hauteur et de
# volume à chaque lecture (GameConfig.SFX_PITCH_VAR / SFX_VOL_VAR_DB) : l'oreille n'entend plus « le même son collé ».
# Un fichier « <nom>_rare_1.ogg » est une variante rare (poids GameConfig.SFX_RARE_WEIGHT au lieu de 1).

const SFX_DIR := "res://assets/audio/sfx/"
static var _recorded: Dictionary = {}   ## clé -> AudioStreamRandomizer, ou null s'il n'y a pas de fichier


## Le son enregistré pour ce nom (un AudioStreamRandomizer : chaque lecture tire une prise), ou null s'il n'y en a pas.
## Toujours le même objet pour un nom donné (une boucle ne redémarre pas à chaque appel). `looped` : cabestan, roue ; la
## hauteur d'une boucle est réglée par le jeu, sans variation au hasard.
static func recorded(sfx_name: String, looped: bool = false) -> AudioStream:
	var key := sfx_name + ("@loop" if looped else "")
	if _recorded.has(key):
		return _recorded[key]
	var rnd := AudioStreamRandomizer.new()
	rnd.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	rnd.random_pitch = 1.0 if looped else GameConfig.SFX_PITCH_VAR
	rnd.random_volume_offset_db = 0.0 if looped else GameConfig.SFX_VOL_VAR_DB
	for kind: String in ["", "rare_"]:
		for k in range(1, 9):
			var path := "%s%s_%s%d.ogg" % [SFX_DIR, sfx_name, kind, k]
			if not ResourceLoader.exists(path):
				break
			var s := load(path) as AudioStreamOggVorbis
			if s == null:
				continue
			if looped:
				s = s.duplicate() as AudioStreamOggVorbis
				s.loop = true
			rnd.add_stream(-1, s, GameConfig.SFX_RARE_WEIGHT if kind == "rare_" else 1.0)
	_recorded[key] = rnd if rnd.streams_count > 0 else null
	return _recorded[key]


# ------------------------------------------------------------------ lot 2 : bruitages d'actions (PROVISOIRES)
# Fabriqués par le code faute de fichiers : à remplacer par de vrais enregistrements (Epidemic Sound), voir la liste des assets
# du lot 2. Chacun garde le même nom de fonction : il suffira de charger le fichier à la place.

## PROVISOIRE — un cliquet de cabestan qui tourne : une série de « clac » de bois et de fer, avec un grincement dessous.
static func capstan() -> AudioStream:
	var rec := recorded("capstan", true)
	if rec != null:
		return rec
	return _cached("capstan", func() -> AudioStreamWAV:
		var len := int(1.2 * RATE)
		var nz := _lowpass(_noise(len, 501), 3200.0)
		var out := PackedFloat32Array()
		out.resize(len)
		var ph := 0.0
		for i in len:
			var t := float(i) / RATE
			var click := fmod(t, 0.15)
			var k := exp(-click * 70.0) * (1.0 if click < 0.05 else 0.0)
			ph += TAU * (120.0 + 15.0 * sin(t * 7.0)) / RATE
			out[i] = nz[i] * k * 1.4 + sin(TAU * 900.0 * t) * k * 0.25 + (sin(ph) + 0.5 * sin(2.0 * ph)) * 0.12
		return _to_stream(_normalize(_loopify(out, int(0.05 * RATE)), 0.6), true))


## PROVISOIRE — un coup de marteau sur un clou : un toc métallique bref, un peu de bois qui résonne.
static func hammer(variant: int = 0) -> AudioStream:
	var rec := recorded("hammer")
	if rec != null:
		return rec
	return _cached("hammer%d" % variant, func() -> AudioStreamWAV:
		var len := int(0.22 * RATE)
		var nz := _highpass(_noise(len, 520 + variant), 900.0)
		var out := PackedFloat32Array()
		out.resize(len)
		var f := 1650.0 + variant * 140.0
		for i in len:
			var t := float(i) / RATE
			out[i] = (sin(TAU * f * t) * 0.6 + sin(TAU * 230.0 * t) * 0.7) * exp(-t * 32.0) + nz[i] * exp(-t * 90.0) * 0.8
		return _to_stream(_normalize(out, 0.6), false))


## PROVISOIRE — le seau qu'on plonge et qui se remplit : un glouglou.
static func bucket_fill() -> AudioStream:
	var rec := recorded("bucket_fill")
	if rec != null:
		return rec
	return _cached("bucket_fill", func() -> AudioStreamWAV:
		var len := int(0.7 * RATE)
		var hp := _highpass(_lowpass(_noise(len, 541), 2600.0), 300.0)
		var out := PackedFloat32Array()
		out.resize(len)
		for i in len:
			var u := float(i) / len
			out[i] = hp[i] * sin(PI * u) * (0.6 + 0.4 * sin(u * 70.0 + sin(u * 13.0) * 2.0))
		return _to_stream(_normalize(out, 0.5), false))


## PROVISOIRE — le seau vidé par-dessus bord : une gerbe qui tombe.
static func bucket_pour() -> AudioStream:
	var rec := recorded("bucket_pour")
	if rec != null:
		return rec
	return _cached("bucket_pour", func() -> AudioStreamWAV:
		var len := int(0.8 * RATE)
		var hp := _highpass(_lowpass(_noise(len, 561), 5200.0), 450.0)
		var out := PackedFloat32Array()
		out.resize(len)
		for i in len:
			var u := float(i) / len
			out[i] = hp[i] * pow(sin(PI * minf(u * 1.4, 1.0)), 0.7) * (1.0 - u * 0.5)
		return _to_stream(_normalize(out, 0.55), false))


## PROVISOIRE — l'élan d'un saut : un froissement de tissu.
static func jump() -> AudioStream:
	var rec := recorded("jump")
	if rec != null:
		return rec
	return _cached("jump", func() -> AudioStreamWAV:
		var len := int(0.18 * RATE)
		var hp := _highpass(_lowpass(_noise(len, 581), 4000.0), 1200.0)
		var out := PackedFloat32Array()
		out.resize(len)
		for i in len:
			var u := float(i) / len
			out[i] = hp[i] * sin(PI * u)
		return _to_stream(_normalize(out, 0.35), false))


## PROVISOIRE — la réception d'un saut : un choc sourd (bois ou sol).
static func land(on_wood: bool) -> AudioStream:
	var rec := recorded("land_wood" if on_wood else "land")
	if rec != null:
		return rec
	return _cached("land%d" % int(on_wood), func() -> AudioStreamWAV:
		var len := int(0.2 * RATE)
		var lp := _lowpass(_noise(len, 601), 900.0 if on_wood else 600.0)
		var out := PackedFloat32Array()
		out.resize(len)
		for i in len:
			var t := float(i) / RATE
			out[i] = lp[i] * exp(-t * 25.0) * 1.5 + (sin(TAU * 85.0 * t) * exp(-t * 30.0) * 0.8 if on_wood else 0.0)
		return _to_stream(_normalize(out, 0.55), false))


## PROVISOIRE — on pose (ou ramasse) un objet lourd : un « tomp » de bois.
static func thump() -> AudioStream:
	var rec := recorded("thump")
	if rec != null:
		return rec
	return _cached("thump", func() -> AudioStreamWAV:
		var len := int(0.25 * RATE)
		var lp := _lowpass(_noise(len, 621), 1400.0)
		var out := PackedFloat32Array()
		out.resize(len)
		for i in len:
			var t := float(i) / RATE
			out[i] = (sin(TAU * 140.0 * t) * 0.9 + lp[i] * 0.6) * exp(-t * 18.0)
		return _to_stream(_normalize(out, 0.55), false))


## PROVISOIRE — une corde qu'on tire (hisser un camarade) : un frottement qui grince.
static func rope() -> AudioStream:
	var rec := recorded("rope")
	if rec != null:
		return rec
	return _cached("rope", func() -> AudioStreamWAV:
		var len := int(0.9 * RATE)
		var bp := _highpass(_lowpass(_noise(len, 641), 3000.0), 600.0)
		var out := PackedFloat32Array()
		out.resize(len)
		var ph := 0.0
		for i in len:
			var u := float(i) / len
			ph += TAU * lerpf(260.0, 190.0, u) / RATE
			out[i] = (bp[i] * 0.8 + sin(ph) * 0.25 * (0.5 + 0.5 * sin(u * 40.0))) * sin(PI * u)
		return _to_stream(_normalize(out, 0.5), false))


## 13/11 (2.3) — l'alerte au combat : la cloche du bord sonnée trois fois, de plus en plus fort, sur trois coups de tambour
## graves. Elle se joue à l'instant où un navire ennemi nous prend en chasse (personne ne remarquait la musique seule).
static func aggro_sting() -> AudioStream:
	return _cached("aggro_sting", func() -> AudioStreamWAV:
		var len := int(2.6 * RATE)
		var rumble := _lowpass(_noise(len, 4107), 140.0)
		var out := PackedFloat32Array()
		out.resize(len)
		for i in len:
			var t := float(i) / RATE
			var v := 0.0
			for k in 3:
				var t0 := 0.02 + 0.42 * k
				if t < t0:
					continue
				var u := t - t0
				var gain := 0.55 + 0.22 * k
				# la cloche : partiels inharmoniques, attaque franche, longue queue
				v += gain * exp(-u * 2.6) * (sin(TAU * 587.0 * u) * 0.55 + sin(TAU * 587.0 * 2.76 * u) * 0.28 * exp(-u * 3.0)
						+ sin(TAU * 587.0 * 5.4 * u) * 0.16 * exp(-u * 7.0) + sin(TAU * 587.0 * 0.5 * u) * 0.22)
				# le tambour : un coup grave qui descend, et son souffle
				v += gain * exp(-u * 9.0) * (sin(TAU * (88.0 - 30.0 * minf(u * 6.0, 1.0)) * u) * 1.1 + rumble[i] * 2.0)
			out[i] = v
		return _to_stream(_normalize(out, 0.85), false))


## PROVISOIRE (lot 4) — l'alerte des requins : deux notes graves qui reviennent, et un frisson d'eau.
static func shark_alert() -> AudioStream:
	var rec := recorded("shark_alert")
	if rec != null:
		return rec
	return _cached("shark_alert", func() -> AudioStreamWAV:
		var len := int(2.0 * RATE)
		var hp := _highpass(_lowpass(_noise(len, 681), 1800.0), 200.0)
		var out := PackedFloat32Array()
		out.resize(len)
		for i in len:
			var t := float(i) / RATE
			var f := 82.0 if fmod(t, 0.5) < 0.25 else 87.0
			var env := exp(-fmod(t, 0.25) * 6.0)
			out[i] = (sin(TAU * f * t) + 0.4 * sin(TAU * 2.0 * f * t)) * env * 0.8 + hp[i] * 0.15 * sin(PI * t / 2.0)
		return _to_stream(_normalize(out, 0.7), false))


## PROVISOIRE (lot 4) — la mort : un accord grave qui descend.
static func death_sting() -> AudioStream:
	var rec := recorded("death_sting")
	if rec != null:
		return rec
	return _cached("death_sting", func() -> AudioStreamWAV:
		var len := int(1.8 * RATE)
		var out := PackedFloat32Array()
		out.resize(len)
		var ph := PackedFloat32Array([0.0, 0.0, 0.0])
		var notes := PackedFloat32Array([196.0, 233.0, 294.0])
		for i in len:
			var u := float(i) / len
			var v := 0.0
			for k in 3:
				var f: float = notes[k] * (1.0 - 0.25 * u)
				ph[k] = ph[k] + TAU * f / RATE
				v += sin(ph[k])
			out[i] = v * pow(1.0 - u, 1.5) * minf(u * 40.0, 1.0)
		return _to_stream(_normalize(out, 0.55), false))


## PROVISOIRE (lot 3) — la roue du gouvernail qui tourne : bois et mécanisme qui grincent (boucle ; volume et hauteur réglés
## par le jeu selon la vitesse de rotation).
static func wheel_creak() -> AudioStream:
	var rec := recorded("wheel_creak", true)
	if rec != null:
		return rec
	return _cached("wheel_creak", func() -> AudioStreamWAV:
		var len := int(1.6 * RATE)
		var nz := _highpass(_lowpass(_noise(len, 661), 2500.0), 400.0)
		var out := PackedFloat32Array()
		out.resize(len)
		var ph := 0.0
		for i in len:
			var u := float(i) / len
			ph += TAU * (170.0 + 40.0 * sin(TAU * 3.0 * u) + 25.0 * sin(TAU * 7.0 * u)) / RATE
			var tick := exp(-fmod(u * 1.6, 0.11) * 60.0)   # les crans du mécanisme
			out[i] = (sin(ph) + 0.5 * sin(2.0 * ph + 0.7)) * 0.3 * (0.6 + 0.4 * sin(TAU * 5.0 * u)) + nz[i] * 0.35 + nz[i] * tick * 0.6
		return _to_stream(_normalize(_loopify(out, int(0.1 * RATE)), 0.5), true))


## Le tonnerre : un grondement qui roule.
static func thunder() -> AudioStreamWAV:
	return _cached("thunder", func() -> AudioStreamWAV:
		var len := int(3.2 * RATE)
		var lp := _lowpass(_noise(len, 91), 170.0)
		var out := PackedFloat32Array()
		out.resize(len)
		for i in len:
			var u := float(i) / len
			out[i] = lp[i] * (pow(1.0 - u, 1.6) * (0.5 + 0.5 * sin(u * 30.0 + sin(u * 9.0) * 3.0)) + (0.9 if u < 0.04 else 0.0))
		return _to_stream(_normalize(out, 0.85), false))

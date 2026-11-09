class_name MusicSynth
extends RefCounted
## La musique du jeu, composée et jouée par le code : trois airs de marins (accordéon, violon, basse, tambour) sans aucun
## fichier audio. « Mer » : une valse lente en la mineur pour naviguer ; « Escale » : une gigue en mi mineur pour les îles et le
## port ; « Combat » : un air martelé quand l'ennemi est là. Chaque morceau est une boucle sans raccord (les queues de notes
## et d'écho se rebouclent au début). La fabrication prend quelques secondes : le jeu la lance dans un fil à part.
## Les mélodies sont des listes [note MIDI, durée] (note 0 = silence) ; la durée est en temps (valse, combat) ou en croches (gigue).

const RATE := 22050
const TABLE := 2048
const IDS := ["mer", "escale", "combat"]

static var _tables: Dictionary = {}

## Instruments : table d'ondes, attaque, relâchement (s), décroissance (par s), vibrato, désaccord, filtre (0-1).
static var _accordion := {"table": "acc", "attack": 0.05, "release": 0.12, "decay": 0.0, "vib": 0.0015, "detune": 0.007, "lp": 0.55}
static var _fiddle := {"table": "saw", "attack": 0.05, "release": 0.14, "decay": 0.0, "vib": 0.005, "detune": 0.0, "lp": 0.3}
static var _bass := {"table": "bass", "attack": 0.01, "release": 0.12, "decay": 2.2, "vib": 0.0, "detune": 0.0, "lp": 0.6}
static var _pad := {"table": "acc", "attack": 0.35, "release": 0.6, "decay": 0.0, "vib": 0.002, "detune": 0.009, "lp": 0.25}


static func build(id: String) -> AudioStreamWAV:
	var buf: PackedFloat32Array
	match id:
		"mer":
			buf = _sea()
		"escale":
			buf = _jig()
		_:
			buf = _battle()
	buf = _room(buf)
	var peak := 0.0001
	for v in buf:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	var k := 0.8 / peak
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i] * k, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = buf.size()
	return w


# ------------------------------------------------------------------ les trois airs

## Valse lente : la mineur, 84 à la noire, 16 mesures.
static func _sea() -> PackedFloat32Array:
	var beat := 60.0 / 84.0
	var bars := 16
	var buf := _blank(bars * 3 * beat)
	var prog := ["Am", "Am", "G", "G", "F", "F", "E", "E", "Am", "Am", "G", "G", "F", "E", "Am", "Am"]
	for b in bars:
		var t := b * 3.0 * beat
		var ch: Dictionary = _chord(prog[b])
		_voice(buf, t, beat * 1.2, ch["root"], 0.55, _bass)
		_kick(buf, t, 0.32)
		_voice(buf, t, beat * 3.0, ch["tri"][0] - 12, 0.05, _pad)
		_voice(buf, t, beat * 3.0, ch["tri"][2] - 12, 0.04, _pad)
		for p in [1, 2]:   # pa-pa
			for m: int in ch["tri"]:
				_voice(buf, t + p * beat, beat * 0.55, m, 0.16, _accordion)
			_shaker(buf, t + p * beat, 0.12)
			_shaker(buf, t + p * beat + beat * 0.5, 0.06)
	# mélodie (violon, doublée très doucement à l'accordéon)
	var tune := [
		[76, 1.5], [74, 0.5], [72, 1.0],  [71, 2.0], [69, 1.0],
		[71, 1.5], [69, 0.5], [67, 1.0],  [67, 2.0], [74, 1.0],
		[72, 1.5], [69, 0.5], [65, 1.0],  [69, 2.0], [72, 1.0],
		[71, 1.5], [68, 0.5], [64, 1.0],  [68, 2.0], [71, 1.0],
		[76, 1.0], [74, 1.0], [72, 1.0],  [74, 1.5], [72, 0.5], [69, 1.0],
		[71, 1.0], [74, 1.0], [79, 1.0],  [76, 1.5], [74, 0.5], [71, 1.0],
		[72, 1.5], [69, 0.5], [65, 1.0],  [68, 1.0], [71, 1.0], [76, 1.0],
		[72, 1.0], [71, 1.0], [69, 1.0],  [69, 3.0]]
	_melody(buf, tune, beat, 0.0, 0.34, 0.1)
	return buf


## Gigue : mi mineur, croche à 0,18 s (6/8), 16 mesures jouées deux fois (la seconde, plus fournie).
static func _jig() -> PackedFloat32Array:
	var e := 60.0 / 110.0 / 3.0
	var bars := 32
	var buf := _blank(bars * 6 * e)
	var prog := ["Em", "Em", "D", "D", "C", "D", "Em", "B7", "Em", "Em", "D", "D", "C", "D", "Em", "Em"]
	var a_tune := [
		[64, 1], [67, 1], [71, 1], [76, 1], [74, 1], [71, 1],
		[72, 1], [71, 1], [69, 1], [71, 1], [67, 1], [64, 1],
		[66, 1], [69, 1], [74, 1], [78, 1], [76, 1], [74, 1],
		[74, 1], [69, 1], [66, 1], [69, 1], [66, 1], [62, 1],
		[72, 1], [67, 1], [64, 1], [67, 1], [72, 1], [76, 1],
		[74, 1], [69, 1], [66, 1], [69, 1], [74, 1], [78, 1],
		[76, 1], [71, 1], [67, 1], [71, 1], [76, 1], [79, 1],
		[75, 1], [78, 1], [71, 1], [76, 3]]
	var b_tune := []
	for i in a_tune.size():
		var n: Array = (a_tune[i] as Array).duplicate()
		if i < 24 and int(n[0]) > 0:
			n[0] = int(n[0]) + 12
		b_tune.append(n)
	b_tune = b_tune.slice(0, b_tune.size() - 4)   # dernière mesure : arpège final
	b_tune.append([71, 2])
	b_tune.append([64, 2])
	b_tune.append([76, 2])
	for pass_i in 2:
		for b in 16:
			var bar := pass_i * 16 + b
			var t := bar * 6.0 * e
			var ch: Dictionary = _chord(prog[b])
			_voice(buf, t, e * 1.6, ch["root"], 0.5, _bass)
			_voice(buf, t + 3.0 * e, e * 1.6, ch["root"] + 7, 0.42, _bass)
			_kick(buf, t, 0.34)
			_snare(buf, t + 3.0 * e, 0.2)
			for p in [1, 2, 4, 5]:
				for m: int in ch["tri"]:
					_voice(buf, t + p * e, e * 0.8, m, 0.12, _accordion)
			for p in 6:
				_shaker(buf, t + p * e, 0.08 if p % 3 == 0 else 0.045)
			if pass_i == 1:
				_tambourine(buf, t + 3.0 * e, 0.16)
				_tambourine(buf, t, 0.1)
				_voice(buf, t, e * 5.5, ch["tri"][0] - 12, 0.07, _pad)
		_melody(buf, a_tune if pass_i == 0 else b_tune, e, pass_i * 16 * 6.0 * e, 0.3, 0.1 if pass_i == 0 else 0.22)
	return buf


## Combat : 150 à la noire, 4/4, 16 mesures (deux passes de huit), tambour et riff de violon.
static func _battle() -> PackedFloat32Array:
	var beat := 60.0 / 150.0
	var bars := 16
	var buf := _blank(bars * 4 * beat)
	var prog := ["Am", "Am", "G", "G", "F", "F", "E", "E"]
	for pass_i in 2:
		for b in 8:
			var bar := pass_i * 8 + b
			var t := bar * 4.0 * beat
			var ch: Dictionary = _chord(prog[b])
			var root: int = ch["root"]
			for q in 4:
				_voice(buf, t + q * beat, beat * 0.9, root + (12 if q % 2 == 1 else 0), 0.5, _bass)
				_shaker(buf, t + q * beat + beat * 0.5, 0.12)
			_kick(buf, t, 0.55)
			_kick(buf, t + 2.0 * beat, 0.5)
			_kick(buf, t + 2.5 * beat, 0.3)
			_snare(buf, t + beat, 0.36)
			_snare(buf, t + 3.0 * beat, 0.36)
			_tambourine(buf, t + beat * 1.5, 0.12)
			_tambourine(buf, t + beat * 3.5, 0.12)
			for m: int in ch["tri"]:   # accords sur les temps 1 et 3, secs
				_voice(buf, t, beat * 0.35, m, 0.17, _accordion)
				_voice(buf, t + 2.0 * beat, beat * 0.35, m, 0.17, _accordion)
			# riff de croches au violon : racine, quinte, octave
			var tri: Array = ch["tri"]
			var riff := [tri[0] + 12, tri[2] + 12, tri[1] + 12, tri[2] + 12, tri[0] + 12, tri[2] + 12, tri[1] + 12, tri[2] + 12]
			for k in 8:
				_voice(buf, t + k * beat * 0.5, beat * 0.42, riff[k], 0.17, _fiddle)
		if pass_i == 1:   # seconde passe : un chant par-dessus
			var tune := [
				[81, 1.0], [84, 1.0], [88, 2.0],  [86, 1.0], [84, 1.0], [83, 2.0],
				[79, 1.0], [83, 1.0], [86, 2.0],  [83, 1.0], [79, 1.0], [74, 2.0],
				[77, 1.0], [81, 1.0], [84, 2.0],  [81, 1.0], [77, 1.0], [72, 2.0],
				[80, 1.0], [83, 1.0], [88, 2.0],  [83, 4.0]]
			_melody(buf, tune, beat, 8.0 * 4.0 * beat, 0.26, 0.0)
	return buf


# ------------------------------------------------------------------ outils

static func _blank(seconds: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * RATE))
	return buf


## Accords : racine (grave) et triade (milieu du clavier) par nom.
static func _chord(name: String) -> Dictionary:
	match name:
		"Am":
			return {"root": 45, "tri": [57, 60, 64]}
		"G":
			return {"root": 43, "tri": [55, 59, 62]}
		"F":
			return {"root": 41, "tri": [53, 57, 60]}
		"E":
			return {"root": 40, "tri": [52, 56, 59]}
		"Em":
			return {"root": 40, "tri": [52, 55, 59]}
		"D":
			return {"root": 38, "tri": [50, 54, 57]}
		"C":
			return {"root": 36, "tri": [48, 52, 55]}
		_:   # B7
			return {"root": 35, "tri": [47, 51, 54]}


## Joue une mélodie de [note, durée] : violon, doublé à l'accordéon (`double` : volume du doublage).
static func _melody(buf: PackedFloat32Array, notes: Array, unit: float, start: float, vol: float, double: float) -> void:
	var t := start
	for n: Array in notes:
		var m := int(n[0])
		var d := float(n[1]) * unit
		if m > 0:
			_voice(buf, t, d * 0.94, m, vol, _fiddle)
			if double > 0.0:
				_voice(buf, t, d * 0.94, m, double, _accordion)
		t += d


static func _table(name: String) -> PackedFloat32Array:
	if _tables.has(name):
		return _tables[name]
	var h: Array
	match name:
		"acc":   # anche : harmoniques riches, un peu nasales
			h = [1.0, 0.55, 0.7, 0.35, 0.4, 0.2, 0.22, 0.1]
		"saw":    # archet : dent de scie adoucie
			h = [1.0, 0.5, 0.33, 0.25, 0.2, 0.16, 0.14, 0.12, 0.1, 0.09, 0.08, 0.07]
		_:       # basse : ronde
			h = [1.0, 0.4, 0.12]
	var tb := PackedFloat32Array()
	tb.resize(TABLE)
	var peak := 0.0001
	for i in TABLE:
		var s := 0.0
		for k in h.size():
			s += float(h[k]) * sin(TAU * float(i) * float(k + 1) / TABLE)
		tb[i] = s
		peak = maxf(peak, absf(s))
	for i in TABLE:
		tb[i] /= peak
	_tables[name] = tb
	return tb


## Une note : table d'ondes, enveloppe, vibrato, désaccord et filtre ; écrite en rebouclant si elle dépasse la fin.
static func _voice(buf: PackedFloat32Array, start: float, dur: float, midi: int, vol: float, inst: Dictionary) -> void:
	var tb := _table(str(inst["table"]))
	var f := 440.0 * pow(2.0, (float(midi) - 69.0) / 12.0)
	var attack := float(inst["attack"])
	var release := float(inst["release"])
	var decay := float(inst["decay"])
	var vib := float(inst["vib"])
	var detune := float(inst["detune"])
	var lp := float(inst["lp"])
	var n := int((dur + release) * RATE)
	var i0 := int(start * RATE)
	var size := buf.size()
	var ph := 0.0
	var ph2 := 0.37
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := 1.0
		if t < attack:
			env = t / attack
		if decay > 0.0:
			env *= exp(-decay * t)
		if t > dur:
			env *= maxf(0.0, 1.0 - (t - dur) / release)
		var fv := f * (1.0 + vib * sin(TAU * 5.4 * t))
		ph += fv / RATE
		var s := tb[int((ph - floorf(ph)) * TABLE) % TABLE]
		if detune > 0.0:
			ph2 += fv * (1.0 + detune) / RATE
			s = (s + tb[int((ph2 - floorf(ph2)) * TABLE) % TABLE]) * 0.5
		y += lp * (s - y)
		buf[(i0 + i) % size] += y * env * vol


static func _kick(buf: PackedFloat32Array, start: float, vol: float) -> void:
	var n := int(0.28 * RATE)
	var i0 := int(start * RATE)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += (48.0 + 90.0 * exp(-t * 22.0)) / RATE
		buf[(i0 + i) % buf.size()] += sin(TAU * ph) * exp(-t * 11.0) * vol


static func _snare(buf: PackedFloat32Array, start: float, vol: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(start * 1000.0) + 5
	var n := int(0.2 * RATE)
	var i0 := int(start * RATE)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		var nz := r.randf() * 2.0 - 1.0
		y += 0.55 * (nz - y)
		buf[(i0 + i) % buf.size()] += ((nz - y) * 0.9 + sin(TAU * 190.0 * t) * 0.4) * exp(-t * 20.0) * vol


static func _shaker(buf: PackedFloat32Array, start: float, vol: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(start * 1000.0) + 9
	var n := int(0.07 * RATE)
	var i0 := int(start * RATE)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		var nz := r.randf() * 2.0 - 1.0
		y += 0.7 * (nz - y)
		buf[(i0 + i) % buf.size()] += (nz - y) * exp(-t * 55.0) * vol


static func _tambourine(buf: PackedFloat32Array, start: float, vol: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(start * 1000.0) + 13
	var n := int(0.16 * RATE)
	var i0 := int(start * RATE)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		var nz := r.randf() * 2.0 - 1.0
		y += 0.8 * (nz - y)
		var jingle := sin(TAU * 6200.0 * t) * 0.4 + sin(TAU * 8100.0 * t) * 0.3
		buf[(i0 + i) % buf.size()] += ((nz - y) * 0.6 + jingle) * exp(-t * 26.0) * vol


## Une petite salle : trois échos très courts, mélangés au son sec (se rebouclent aussi).
static func _room(buf: PackedFloat32Array) -> PackedFloat32Array:
	var n := buf.size()
	var out := PackedFloat32Array()
	out.resize(n)
	var taps := [[int(0.067 * RATE), 0.26], [int(0.121 * RATE), 0.18], [int(0.197 * RATE), 0.12], [int(0.283 * RATE), 0.07]]
	for i in n:
		var s := buf[i]
		for tp: Array in taps:
			s += buf[(i - int(tp[0]) + n) % n] * float(tp[1])
		out[i] = s
	return out

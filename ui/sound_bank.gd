class_name SoundBank
extends Node
## Звук стола: диегетические шумы (роторы «Фиалки», телетайп, бумага, штамп, катушка) и фон
## комнаты. Шины Master / SFX / Ambient, громкость из настроек.
##
## Пока своих записей нет, звуки синтезируются процедурно (шум и щелчки — без генеративного ИИ).
## Чтобы заменить звук, положите файл assets/sfx/<имя>.ogg или .wav — он возьмётся вместо
## заглушки. Имена и что где звучит — в docs/assets.md.

const RATE := 22050
const NAMES := ["click", "paper", "stamp", "rotor", "teletype", "reel", "pencil", "tunnel"]
const BUSES := ["SFX", "Ambient"]

var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _ambient: AudioStreamPlayer
var _tunnel: AudioStreamPlayer


func _ready() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = "Ambient"
	add_child(_ambient)
	_tunnel = AudioStreamPlayer.new()
	_tunnel.bus = "Ambient"
	_tunnel.volume_db = -14.0
	add_child(_tunnel)


## Громкость шины 0–100 (0 — без звука).
func set_volume(bus: String, percent: int) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, percent <= 0)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(percent, 1) / 100.0))


func play(name: String, pitch := 1.0) -> void:
	var s := stream(name)
	if s == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = s
			p.pitch_scale = pitch
			p.play()
			return
	_players[0].stream = s
	_players[0].play()


func start_ambient() -> void:
	if _ambient.playing:
		return
	_ambient.stream = stream("room")
	_ambient.play()


## Низкий гул «работ под зданием» (до раскрытия «Монополии»).
func set_tunnel(on: bool) -> void:
	if on and not _tunnel.playing:
		_tunnel.stream = stream("tunnel")
		_tunnel.play()
	elif not on and _tunnel.playing:
		_tunnel.stop()


## Поток по имени: свой файл из assets/sfx или процедурная заглушка (кэшируется).
func stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var s: AudioStream = null
	for ext in ["ogg", "wav"]:
		var path := "res://assets/sfx/%s.%s" % [name, ext]
		if ResourceLoader.exists(path):
			s = load(path)
			break
	if s == null:
		s = synth(name)
	_cache[name] = s
	return s


# ——— Процедурные заглушки ———

static func synth(name: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var out := PackedFloat32Array()
	match name:
		"click":
			out = _clicks(rng, [0.0], 0.06, 2200.0, 0.5)
		"pencil":
			out = _noise(rng, 0.25, 0.25, 0.6, 8.0)
		"paper":
			out = _noise(rng, 0.35, 0.45, 0.15, 5.0)
		"stamp":
			out = _thump(rng, 0.3)
		"rotor":
			var t := []
			for i in 10:
				t.append(i * 0.07 + rng.randf() * 0.01)
			out = _clicks(rng, t, 0.9, 1400.0, 0.8)
		"teletype":
			var t := []
			var x := 0.0
			while x < 1.5:
				t.append(x)
				x += 0.045 + rng.randf() * 0.03
			out = _clicks(rng, t, 1.6, 3000.0, 0.45)
		"reel":
			out = _hum(rng, 1.0, 50.0, 0.18)
		"room":
			out = _room(rng, 6.0)
		"tunnel":
			out = _hum(rng, 4.0, 31.0, 0.22)
		_:
			out = _clicks(rng, [0.0], 0.05, 2000.0, 0.3)
	return _wav(out, name == "room" or name == "tunnel")


## Сухие механические щелчки в моменты t (секунды).
static func _clicks(rng: RandomNumberGenerator, times: Array, length: float, tone: float, amp: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for t0 in times:
		var start := int(float(t0) * RATE)
		var dur := int(0.018 * RATE)
		var a := amp * (0.7 + rng.randf() * 0.3)
		for i in dur:
			var k := start + i
			if k >= n:
				break
			var env := exp(-float(i) / (dur * 0.25))
			out[k] += a * env * (rng.randf_range(-1, 1) * 0.6 + sin(TAU * tone * i / RATE) * 0.4)
	return out


## Шорох бумаги или карандаша: шум с огибающей и грубым фильтром.
static func _noise(rng: RandomNumberGenerator, length: float, amp: float, smooth: float, shape: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var x := float(i) / n
		var env := sin(PI * x) * (1.0 - exp(-x * shape))
		y = lerpf(y, rng.randf_range(-1, 1), 1.0 - smooth)
		out[i] = y * env * amp
	return out


## Удар штампа: низкий тон с быстрым затуханием плюс щелчок.
static func _thump(rng: RandomNumberGenerator, length: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = 0.8 * exp(-t * 18.0) * sin(TAU * (90.0 - 40.0 * t) * t) + 0.25 * exp(-t * 120.0) * rng.randf_range(-1, 1)
	return out


## Гул мотора магнитофона.
static func _hum(rng: RandomNumberGenerator, length: float, freq: float, amp: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t * 8.0) * minf(1.0, (length - t) * 8.0)
		out[i] = amp * env * (sin(TAU * freq * t) * 0.6 + sin(TAU * freq * 2.0 * t) * 0.3 + rng.randf_range(-1, 1) * 0.1)
	return out


## Тон комнаты: тихий «коричневый» шум и далёкий гул улицы; бесшовная петля.
static func _room(rng: RandomNumberGenerator, length: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		y = clampf(y + rng.randf_range(-1, 1) * 0.02, -1.0, 1.0) * 0.998
		var t := float(i) / RATE
		out[i] = y * 0.5 + 0.05 * sin(TAU * 60.0 * t) + 0.03 * sin(TAU * 0.25 * t) * rng.randf_range(-1, 1)
	# Сшиваем концы петли.
	var fade := int(0.5 * RATE)
	for i in fade:
		var k := float(i) / fade
		out[i] = out[i] * k + out[n - fade + i] * (1.0 - k)
	return out


static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w

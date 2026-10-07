class_name Sfx
extends RefCounted
## Every sound in the game, synthesised in code. There are no audio files.

const RATE: int = 22050

static var _cache: Dictionary = {}


## Plays a flat (non-positional) sound as a child of node.
static func play_ui(node: Node, sound: String) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream(sound)
	node.add_child(player)
	player.play()
	_free_after(player, player.stream.get_length())


## Plays a sound in the world at pos, as a child of node.
static func play_at(node: Node3D, sound: String, pos: Vector3) -> void:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream(sound)
	player.unit_size = 8.0
	player.max_distance = 140.0
	node.add_child(player)
	player.global_position = pos
	player.play()
	_free_after(player, player.stream.get_length())


static func stream(sound: String) -> AudioStreamWAV:
	if not _cache.has(sound):
		_cache[sound] = _to_wav(_synth(sound))
	return _cache[sound]


static func _free_after(player: Node, seconds: float) -> void:
	player.get_tree().create_timer(seconds + 0.1).timeout.connect(player.queue_free)


static func _synth(sound: String) -> PackedFloat32Array:
	match sound:
		"shot":
			return _mix(_noise(0.16, 0.8, 30.0), _tone(160, 50, 0.12, false, 0.6))
		"alarm":
			return _chain([_tone(880, 880, 0.15, true, 0.35), _tone(660, 660, 0.15, true, 0.35), _tone(880, 880, 0.15, true, 0.35), _tone(660, 660, 0.15, true, 0.35)])
		"drill":
			return _mix(_tone(140, 170, 0.5, true, 0.25), _noise(0.5, 0.2, 2.0))
		"jam":
			return _mix(_tone(220, 70, 0.4, true, 0.4), _noise(0.4, 0.3, 6.0))
		"door":
			return _mix(_tone(160, 90, 0.15, false, 0.6), _noise(0.12, 0.3, 25.0))
		"cash":
			return _chain([_tone(1320, 1320, 0.07, false, 0.4), _tone(1760, 1760, 0.12, false, 0.4)])
		"bag":
			return _noise(0.25, 0.4, 10.0)
		"throw":
			return _mix(_noise(0.18, 0.3, 8.0), _tone(200, 500, 0.18, false, 0.2))
		"deliver":
			return _chain([_tone(660, 660, 0.08, false, 0.4), _tone(880, 880, 0.08, false, 0.4), _tone(1320, 1320, 0.16, false, 0.4)])
		"hurt":
			return _tone(220, 110, 0.12, true, 0.4)
		"down":
			return _tone(440, 110, 0.6, false, 0.5)
		"revive":
			return _tone(330, 880, 0.4, false, 0.45)
		"busted":
			return _chain([_tone(330, 330, 0.2, true, 0.35), _tone(262, 262, 0.2, true, 0.35), _tone(196, 196, 0.4, true, 0.35)])
		"star_up":
			return _chain([_tone(600, 900, 0.12, true, 0.3), _tone(600, 900, 0.12, true, 0.3)])
		"star_down":
			return _tone(900, 500, 0.25, false, 0.35)
		"click":
			return _tone(1000, 1000, 0.03, false, 0.3)
		"buy":
			return _chain([_tone(990, 990, 0.06, false, 0.4), _tone(1480, 1480, 0.1, false, 0.4)])
		"spin":
			return _chain([_tone(700, 700, 0.02, true, 0.25), _silence(0.05), _tone(700, 700, 0.02, true, 0.25), _silence(0.05), _tone(700, 700, 0.02, true, 0.25)])
		"win":
			return _chain([_tone(523, 523, 0.1, false, 0.4), _tone(659, 659, 0.1, false, 0.4), _tone(784, 784, 0.1, false, 0.4), _tone(1046, 1046, 0.25, false, 0.4)])
		"lose":
			return _tone(300, 150, 0.3, true, 0.3)
		"mask":
			return _mix(_noise(0.08, 0.3, 30.0), _tone(300, 200, 0.1, false, 0.3))
		"notify":
			return _tone(880, 880, 0.06, false, 0.3)
	assert(false, "Unknown sound '%s'" % sound)
	return PackedFloat32Array()


## A tone sliding from one pitch to another, sine or square, with a short fade in and out.
static func _tone(from_hz: float, to_hz: float, seconds: float, square: bool, volume: float) -> PackedFloat32Array:
	var count: int = int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase: float = 0.0
	for i: int in range(count):
		var t: float = float(i) / count
		phase += lerpf(from_hz, to_hz, t) / RATE
		var wave: float = sin(phase * TAU)
		if square:
			wave = signf(wave) * 0.6
		var envelope: float = minf(1.0, (1.0 - t) * 6.0) * minf(1.0, t * 60.0)
		out[i] = wave * envelope * volume
	return out


## White noise with an exponential decay.
static func _noise(seconds: float, volume: float, decay: float) -> PackedFloat32Array:
	var count: int = int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	for i: int in range(count):
		var t: float = float(i) / RATE
		out[i] = randf_range(-1.0, 1.0) * exp(-t * decay) * volume
	return out


static func _silence(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	return out


static func _chain(parts: Array[PackedFloat32Array]) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for part: PackedFloat32Array in parts:
		out.append_array(part)
	return out


static func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(maxi(a.size(), b.size()))
	for i: int in range(out.size()):
		var sample: float = 0.0
		if i < a.size():
			sample += a[i]
		if i < b.size():
			sample += b[i]
		out[i] = sample
	return out


static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in range(samples.size()):
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav

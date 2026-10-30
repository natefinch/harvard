extends Node

const SETTINGS_PATH := "user://settings.cfg"
const CHANNELS := ["Music", "SFX"]

var volumes := {"Music": 1.0, "SFX": 1.0}
var muted := {"Music": false, "SFX": false}
var _music: Array[AudioStreamPlayer] = []
var _cur := 0
var current := ""
var _sfx: Array[AudioStreamPlayer] = []
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for channel in CHANNELS:
		if AudioServer.get_bus_index(channel) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, channel)
	load_settings()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80
		add_child(p)
		_music.append(p)
	for i in 8:
		var s := AudioStreamPlayer.new()
		s.bus = "SFX"
		add_child(s)
		_sfx.append(s)


func set_volume(channel: String, value: float) -> void:
	volumes[channel] = clampf(value, 0.0, 1.0)
	_apply_settings(channel)


func set_muted(channel: String, value: bool) -> void:
	muted[channel] = value
	_apply_settings(channel)


# Loudness is perceived logarithmically, so slider position maps linearly to
# decibels over a 40 dB range (75% = -10 dB, 50% = -20 dB) rather than to amplitude.
const MIN_DB := -40.0


func slider_to_db(position: float) -> float:
	if position <= 0.0:
		return -80.0
	return lerpf(MIN_DB, 0.0, clampf(position, 0.0, 1.0))


func _apply_settings(channel: String) -> void:
	var bus := AudioServer.get_bus_index(channel)
	AudioServer.set_bus_volume_db(bus, slider_to_db(volumes[channel]))
	AudioServer.set_bus_mute(bus, muted[channel] or volumes[channel] == 0)


func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_error("Could not load audio settings: %s" % error_string(err))
	for channel in CHANNELS:
		var volume: Variant = config.get_value(channel, "volume", 1.0)
		var mute: Variant = config.get_value(channel, "muted", false)
		if (typeof(volume) != TYPE_FLOAT and typeof(volume) != TYPE_INT) or typeof(mute) != TYPE_BOOL:
			push_error("Invalid audio settings for %s; using defaults." % channel)
			volume = 1.0
			mute = false
		elif not is_finite(volume):
			push_error("Invalid audio volume for %s; using default." % channel)
			volume = 1.0
		set_volume(channel, volume)
		set_muted(channel, mute)


func save_settings() -> Error:
	var config := ConfigFile.new()
	for channel in CHANNELS:
		config.set_value(channel, "volume", volumes[channel])
		config.set_value(channel, "muted", muted[channel])
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_error("Could not save audio settings: %s" % error_string(err))
	return err


func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var st: AudioStream = null
	if ResourceLoader.exists(path):
		st = load(path)
	_cache[path] = st
	return st


func play_music(name: String, loop := true, fade := 0.8) -> void:
	if name == current and loop:
		return
	var st := _load("res://assets/music/%s.ogg" % name)
	current = name if loop else ""
	var old := _music[_cur]
	_cur = 1 - _cur
	var nw := _music[_cur]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(old, "volume_db", -80.0, fade)
	if st == null:
		return
	if st is AudioStreamOggVorbis:
		st.loop = loop
	nw.stream = st
	nw.volume_db = -30
	nw.play()
	tw.tween_property(nw, "volume_db", -6.0, fade)


func stop_music(fade := 0.8) -> void:
	current = ""
	var tw := create_tween()
	tw.tween_property(_music[_cur], "volume_db", -80.0, fade)


func sfx(name: String, pitch := 1.0, vol := 0.0) -> void:
	var st := _load("res://assets/sfx/%s.wav" % name)
	if st == null:
		return
	for s in _sfx:
		if not s.playing:
			s.stream = st
			s.pitch_scale = pitch
			s.volume_db = vol
			s.play()
			return

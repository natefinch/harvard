extends Node

var _music: Array[AudioStreamPlayer] = []
var _cur := 0
var current := ""
var _sfx: Array[AudioStreamPlayer] = []
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80
		add_child(p)
		_music.append(p)
	for i in 8:
		var s := AudioStreamPlayer.new()
		add_child(s)
		_sfx.append(s)


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

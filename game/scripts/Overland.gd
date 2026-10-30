class_name Overland
extends Node2D

const ZOOM := 0.85
var title := "Harvard"
var map: Sprite2D
var mask: Image
var ms := 4
var size := Vector2.ZERO
var marks := {}
var player: Actor
var cam: Camera2D
var tint: CanvasModulate
var foes: Array[Actor] = []
var prompt: Label
var near := ""
var _spawn_t := 0.0
var _start := ""


func _init(at: String) -> void:
	_start = at


func is_field() -> bool:
	return true


func _ready() -> void:
	var meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map/overland.json"))
	marks = meta.landmarks
	ms = int(meta.mask_scale)
	size = Vector2(meta.size[0], meta.size[1])
	map = Sprite2D.new()
	map.texture = load("res://assets/map/overland.png")
	map.scale = size / map.texture.get_size()
	map.centered = false
	map.z_index = -10
	add_child(map)
	mask = load("res://assets/map/overland_mask.png").get_image()
	if mask.is_compressed():
		mask.decompress()
	y_sort_enabled = true
	var lm := Node2D.new()
	lm.z_index = -5
	lm.draw.connect(_draw_marks.bind(lm))
	add_child(lm)
	for k in marks:
		var info: Dictionary = Data.LANDMARKS.get(k, {})
		var l := UI.label(info.get("name", k), UI.f_type, 22, Color(1, 0.95, 0.8) if info.has("loc") else Color(0.85, 0.85, 0.85))
		l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
		l.add_theme_constant_override("outline_size", 7)
		l.position = Vector2(marks[k][0] - 150, marks[k][1] + 14)
		l.size = Vector2(300, 30)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.z_index = 5
		add_child(l)
	player = Actor.new("sam", 58)
	var p: Array = marks.get(_start, marks["dillard_farm"])
	player.position = Vector2(p[0], p[1] + 34)
	add_child(player)
	cam = Camera2D.new()
	cam.zoom = Vector2(ZOOM, ZOOM)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(size.x)
	cam.limit_bottom = int(size.y)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8
	player.add_child(cam)
	cam.make_current()
	tint = CanvasModulate.new()
	add_child(tint)
	var layer := CanvasLayer.new()
	add_child(layer)
	prompt = UI.label("", UI.f_type, 26, Color(1, 0.95, 0.75))
	prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt.add_theme_constant_override("outline_size", 8)
	prompt.position = Vector2(0, 620)
	prompt.size = Vector2(1280, 40)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(prompt)
	apply_time()
	cam.reset_smoothing.call_deferred()


func _draw_marks(n: Node2D) -> void:
	for k in marks:
		var info: Dictionary = Data.LANDMARKS.get(k, {})
		var c := Vector2(marks[k][0], marks[k][1])
		var col := Color(1, 0.8, 0.25) if info.has("loc") else Color(0.7, 0.72, 0.78)
		n.draw_circle(c, 13, Color(0.1, 0.05, 0.02))
		n.draw_circle(c, 10, col)
		n.draw_circle(c, 4, Color(0.1, 0.05, 0.02))


func resume_music() -> void:
	Audio.play_music("night" if Game.time == "night" else "overland")


func apply_time() -> void:
	tint.color = Data.TIMES[Game.time]
	resume_music()


func refresh_party() -> void:
	pass


func _px(p: Vector2) -> Color:
	var x := int(p.x / ms)
	var y := int(p.y / ms)
	if x < 0 or y < 0 or x >= mask.get_width() or y >= mask.get_height():
		return Color(0, 0, 1)
	return mask.get_pixel(x, y)


func can_stand(p: Vector2) -> bool:
	var c := _px(p)
	return c.r < 0.5 and c.b < 0.5


func _physics_process(delta: float) -> void:
	var v := Vector2.ZERO
	if not Game.busy():
		v = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var moved := false
	if v != Vector2.ZERO:
		player.face(v)
		var speed := 230.0 * (1.4 if _px(player.position).g > 0.5 else 1.0)
		var step := v * speed * delta
		var p := player.position
		if can_stand(p + step):
			p += step
		elif can_stand(p + Vector2(step.x, 0)):
			p.x += step.x
		elif can_stand(p + Vector2(0, step.y)):
			p.y += step.y
		moved = p != player.position
		player.position = p
	player.moving = moved
	_update_near()
	_update_foes(delta)
	if Game.busy():
		return
	if Input.is_action_just_pressed("accept") and near != "":
		_enter(near)


func _update_near() -> void:
	near = ""
	var best := 75.0
	for k in marks:
		var dd := player.position.distance_to(Vector2(marks[k][0], marks[k][1]))
		if dd < best:
			best = dd
			near = k
	if near == "" or Game.busy():
		prompt.text = ""
	else:
		var info: Dictionary = Data.LANDMARKS.get(near, {})
		var key := "A" if UI.touch_ui else "Z"
		prompt.text = (key + ": Go to " if info.has("loc") else key + ": Look at ") + info.get("name", near)


func _enter(k: String) -> void:
	var info: Dictionary = Data.LANDMARKS.get(k, {})
	if info.has("loc"):
		Game.goto(info.loc, info.spawn)
	else:
		Game.cutscene += 1
		await UI.say("", info.get("locked", "Nothing here."))
		await Story.run("look_" + k)
		Game.cutscene -= 1


func _foe_kinds() -> Array:
	if Game.time == "night":
		return ["hollow", "wisp", "wisp", "cyclist"]
	if Game.time == "dusk":
		return ["raccoon", "goose", "hollow", "scarecrow"]
	return ["raccoon", "goose", "goose", "scarecrow"]


func _update_foes(delta: float) -> void:
	if Game.busy():
		for f in foes:
			f.moving = false
		return
	_spawn_t -= delta
	if _spawn_t <= 0 and foes.size() < 6 and Game.flag("lane_done"):
		_spawn_t = 2.5
		var a := Vector2.from_angle(randf() * TAU) * randf_range(700, 1000)
		var p := player.position + a
		if can_stand(p):
			var kind: String = _foe_kinds().pick_random()
			var f := Actor.new(kind, 52 * Data.ENEMIES[kind].get("scale", 1.0))
			f.position = p
			f.set_meta("kind", kind)
			f.set_meta("wander", Vector2.ZERO)
			if Data.ENEMIES[kind].get("ghost", false):
				f.modulate = Color(0.8, 0.9, 1.0, 0.75)
			add_child(f)
			foes.append(f)
	for f in foes.duplicate():
		var to_p: Vector2 = player.position - f.position
		if to_p.length() > 1500:
			foes.erase(f)
			f.queue_free()
			continue
		var dir := Vector2.ZERO
		if to_p.length() < 320:
			dir = to_p.normalized() * 0.75
		else:
			var w: Vector2 = f.get_meta("wander")
			if randf() < delta * 0.6:
				w = Vector2.from_angle(randf() * TAU) * 0.4
				f.set_meta("wander", w)
			dir = w
		var np: Vector2 = f.position + dir * 200 * delta
		if can_stand(np):
			f.position = np
		f.moving = dir != Vector2.ZERO
		if dir.x != 0:
			f.spr.flip_h = dir.x < 0
		if to_p.length() < 30:
			_fight(f)
			return


func _fight(f: Actor) -> void:
	var kind: String = f.get_meta("kind")
	foes.erase(f)
	f.queue_free()
	Audio.sfx("encounter")
	var result: String = await Game.battle(Game.make_group(kind))
	if result == "lose":
		Game.lose()

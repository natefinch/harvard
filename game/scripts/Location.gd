class_name Location
extends Node2D

var id := ""
var d: Dictionary
var title := ""
var S := 1.0
var H := 72.0
var stage: Node2D
var bg: Sprite2D
var cam: Camera2D
var tint: CanvasModulate
var light: PointLight2D
var player: Actor
var followers: Array[Actor] = []
var npcs := {}
var foes: Array = []
var walk: Array[PackedVector2Array] = []
var block_p: Array[PackedVector2Array] = []
var trail: Array[Vector2] = []
var world_size := Vector2.ZERO
var _spawn := ""
var _exit_armed := false
var dbg: Node2D


func _init(loc_id: String, spawn_id: String) -> void:
	id = loc_id
	_spawn = spawn_id
	d = Locs.L[loc_id]
	title = d.title
	S = d.scale
	H = d.h


func is_field() -> bool:
	return true


func _ready() -> void:
	stage = Node2D.new()
	stage.scale = Vector2(S, S)
	stage.y_sort_enabled = true
	add_child(stage)
	bg = Sprite2D.new()
	bg.texture = load("res://assets/bg/%s.png" % d.bg)
	bg.centered = false
	bg.z_index = -10
	stage.add_child(bg)
	world_size = bg.texture.get_size() * S
	for p in d.walk:
		walk.append(_poly(p))
	for p in d.get("block_p", []):
		block_p.append(_poly(p))
	dbg = Node2D.new()
	dbg.z_index = 100
	dbg.draw.connect(_draw_debug)
	stage.add_child(dbg)
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	tint = CanvasModulate.new()
	add_child(tint)
	var sp: Array = d.spawns.get(_spawn, d.spawns.values()[0])
	player = Actor.new("sam", H)
	player.position = Vector2(sp[0], sp[1])
	player.face(_dir(sp[2]))
	stage.add_child(player)
	refresh_party()
	refresh_npcs()
	_make_light()
	apply_time()
	resume_music()
	_update_cam()
	_exit_armed = false
	Story.on_enter.call_deferred(id)


func _poly(p: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, p.size(), 2):
		out.append(Vector2(p[i], p[i + 1]))
	return out


func _dir(s: String) -> Vector2:
	match s:
		"up": return Vector2.UP
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
	return Vector2.DOWN


func resume_music() -> void:
	var m: String = d.music
	if Game.time == "night" and not d.get("interior", false):
		m = "night"
	Audio.play_music(m)


func _make_light() -> void:
	light = PointLight2D.new()
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1, 0.5)
	g.width = 256
	g.height = 256
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 0.95, 0.8, 1))
	gr.set_color(1, Color(1, 0.95, 0.8, 0))
	g.gradient = gr
	light.texture = g
	light.texture_scale = 3.0
	light.energy = 1.1
	add_child(light)


func apply_time() -> void:
	var interior: bool = d.get("interior", false)
	var c: Color = Data.TIMES[Game.time]
	if interior:
		c = Color(1, 1, 1) if Game.time != "night" else Color(0.85, 0.82, 0.78)
	elif d.get("night_art", false):
		c = Color(0.85, 0.85, 0.95) if Game.time == "night" else Color(0.75, 0.75, 0.85)
	tint.color = c
	light.enabled = Game.time == "night" and not interior and not d.get("night_art", false)
	resume_music()


func refresh_party() -> void:
	for f in followers:
		f.queue_free()
	followers.clear()
	trail.clear()
	for i in range(1, Game.party.size()):
		var a := Actor.new(Game.party[i].id, H)
		a.position = player.position + Vector2(0, 2 * i)
		a.face(player.facing)
		stage.add_child(a)
		followers.append(a)
	for i in 200:
		trail.append(player.position)


func refresh_npcs() -> void:
	for n in d.get("npcs", []):
		var show := Game.cond(n.get("cond", ""))
		if show and not npcs.has(n.id):
			add_npc(n.id, n.sprite, Vector2(n.pos[0], n.pos[1]), n.ev, _dir(n.get("face", "down")))
		elif not show and npcs.has(n.id):
			remove_npc(n.id)
	for f in foes:
		f.queue_free()
	foes.clear()
	var fl: Array = d.get("foes", [])
	for i in fl.size():
		var key := "%s_%d" % [id, i]
		if Game.defeated.get(key, 0.0) > Time.get_ticks_msec() / 1000.0 - 90.0:
			continue
		if not Game.cond(fl[i].cond):
			continue
		var a := Actor.new(fl[i].kind, H * Data.ENEMIES[fl[i].kind].get("scale", 1.0))
		a.position = Vector2(fl[i].pos[0], fl[i].pos[1])
		a.set_meta("kind", fl[i].kind)
		a.set_meta("key", key)
		a.set_meta("home", a.position)
		a.set_meta("wander", Vector2.ZERO)
		if Data.ENEMIES[fl[i].kind].get("ghost", false):
			a.modulate = Color(0.8, 0.9, 1.0, 0.75)
		stage.add_child(a)
		foes.append(a)


func add_npc(nid: String, sprite: String, pos: Vector2, ev := "", facing := Vector2.DOWN) -> Actor:
	var a := Actor.new(sprite, H)
	a.position = pos
	a.ev = ev
	a.face(facing)
	stage.add_child(a)
	npcs[nid] = a
	return a


func remove_npc(nid: String) -> void:
	if npcs.has(nid):
		npcs[nid].queue_free()
		npcs.erase(nid)


func npc(nid: String) -> Actor:
	return npcs.get(nid)


func can_stand(p: Vector2, who: Actor = null) -> bool:
	var ok := false
	for w in walk:
		if Geometry2D.is_point_in_polygon(p, w):
			ok = true
			break
	if not ok:
		return false
	for r in d.block_r:
		if p.x > r[0] and p.x < r[2] and p.y > r[1] and p.y < r[3]:
			return false
	for c in d.block_c:
		if p.distance_to(Vector2(c[0], c[1])) < c[2]:
			return false
	for bp in block_p:
		if Geometry2D.is_point_in_polygon(p, bp):
			return false
	for k in npcs:
		var n: Actor = npcs[k]
		if n != who and p.distance_to(n.position) < n.radius * 1.6:
			return false
	return true


func _persp(y: float) -> float:
	var pr: Array = d.persp
	if pr[1] <= pr[0]:
		return 1.0
	return lerp(0.82, 1.08, clamp((y - pr[0]) / float(pr[1] - pr[0]), 0.0, 1.0))


func _physics_process(delta: float) -> void:
	var v := Vector2.ZERO
	if not Game.busy():
		v = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var moved := false
	if v != Vector2.ZERO:
		var speed := 250.0 / S
		var step := v * speed * delta
		player.face(v)
		var p := player.position
		if can_stand(p + step):
			p += step
		elif can_stand(p + Vector2(step.x, 0)):
			p.x += step.x
		elif can_stand(p + Vector2(0, step.y)):
			p.y += step.y
		if p != player.position:
			player.position = p
			moved = true
	var travelled := player.position.distance_to(trail[0]) > 3.0
	if travelled:
		trail.push_front(player.position)
		trail.pop_back()
	if not Game.busy():
		player.moving = moved
	_update_followers(moved or travelled)
	_update_foes(delta)
	player.set_persp(_persp(player.position.y))
	for k in npcs:
		npcs[k].set_persp(_persp(npcs[k].position.y))
	_update_cam()
	light.position = player.position * S + player.facing * 40 + Vector2(0, -H * S * 0.5)
	if Game.busy():
		return
	_check_exits()
	if Input.is_action_just_pressed("accept"):
		_interact()


func _update_followers(moved: bool) -> void:
	var gap := int(H * 0.5 / 3.0)
	for i in followers.size():
		var f := followers[i]
		var idx: int = min((i + 1) * gap, trail.size() - 1)
		var target := trail[idx]
		var dv := target - f.position
		f.moving = moved and dv.length() > 0.5
		if dv.length() > 0.5:
			f.face(dv.normalized())
		f.position = target
		f.set_persp(_persp(f.position.y))


func _update_foes(delta: float) -> void:
	if Game.busy():
		for f in foes:
			f.moving = false
		return
	for f in foes.duplicate():
		var to_p: Vector2 = player.position - f.position
		var dir := Vector2.ZERO
		if to_p.length() < 260.0:
			dir = to_p.normalized()
		else:
			var w: Vector2 = f.get_meta("wander")
			if randf() < delta * 0.7:
				w = Vector2.from_angle(randf() * TAU) if randf() < 0.7 else Vector2.ZERO
				f.set_meta("wander", w)
			var home: Vector2 = f.get_meta("home")
			if f.position.distance_to(home) > 200:
				w = (home - f.position).normalized()
			dir = w * 0.5
		var sp := 120.0 / S
		var np: Vector2 = f.position + dir * sp * delta
		if can_stand(np):
			f.position = np
		f.moving = dir != Vector2.ZERO
		if dir.x != 0:
			f.spr.flip_h = dir.x < 0
		f.set_persp(_persp(f.position.y))
		if to_p.length() < H * 0.35:
			_fight(f)
			return


func _fight(f: Actor) -> void:
	var kind: String = f.get_meta("kind")
	foes.erase(f)
	Audio.sfx("encounter")
	var result: String = await Game.battle(Game.make_group(kind))
	Game.defeated[f.get_meta("key")] = Time.get_ticks_msec() / 1000.0
	f.queue_free()
	if result == "lose":
		Game.lose()


func _update_cam() -> void:
	var pp := player.position * S
	var c := Vector2.ZERO
	c.x = clamp(pp.x, 640, world_size.x - 640) if world_size.x >= 1280 else world_size.x / 2.0
	c.y = clamp(pp.y - 30, 360, world_size.y - 360) if world_size.y >= 720 else world_size.y / 2.0
	cam.position = c


func _in_rect(p: Vector2, r: Array, pad := 0.0) -> bool:
	return p.x >= r[0] - pad and p.x <= r[2] + pad and p.y >= r[1] - pad and p.y <= r[3] + pad


func _check_exits() -> void:
	var inside := false
	for e in d.exits:
		if _in_rect(player.position, e.r, 2.0):
			inside = true
			if _exit_armed and Game.cond(e.get("cond", "")):
				_exit_armed = false
				_leave(e)
				return
	if not inside:
		_exit_armed = true


func _leave(e: Dictionary) -> void:
	if e.has("block_ev"):
		await Story.run(e.block_ev)
		return
	if e.to != "overland":
		Audio.sfx("door")
	Game.goto(e.to, e.spawn)


func _interact() -> void:
	var probe := player.position + player.facing * H * 0.45
	var best: Actor = null
	var bd := H * 0.9
	for k in npcs:
		var n: Actor = npcs[k]
		var dd := probe.distance_to(n.position)
		if dd < bd and n.ev != "":
			bd = dd
			best = n
	if best:
		best.face(player.position - best.position)
		await Story.run(best.ev)
		return
	for h in d.hot:
		if (_in_rect(probe, h.r, H * 0.15) or _in_rect(player.position, h.r, H * 0.1)) and Game.cond(h.get("cond", "")):
			await Story.run(h.ev)
			return


func walk_to(a: Actor, target: Vector2, speed := 0.0) -> void:
	if speed <= 0:
		speed = 160.0 / S
	if not is_instance_valid(a):
		return
	a.moving = true
	while is_instance_valid(a) and a.position.distance_to(target) > 2.0:
		var dir := (target - a.position).normalized()
		a.face(dir)
		a.position = a.position.move_toward(target, speed * get_physics_process_delta_time())
		a.set_persp(_persp(a.position.y))
		await get_tree().physics_frame
	if is_instance_valid(a):
		a.moving = false


func warp_player(pos: Vector2, facing := Vector2.DOWN) -> void:
	player.position = pos
	player.face(facing)
	refresh_party()
	_update_cam()


func _process(_delta: float) -> void:
	if Game.debug:
		dbg.queue_redraw()


func _draw_debug() -> void:
	if not Game.debug:
		return
	for w in walk:
		var pts := w.duplicate()
		pts.append(w[0])
		dbg.draw_polyline(pts, Color(0, 1, 0), 3)
	for r in d.block_r:
		dbg.draw_rect(Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1]), Color(1, 0, 0, 0.35))
	for c in d.block_c:
		dbg.draw_circle(Vector2(c[0], c[1]), c[2], Color(1, 0, 0, 0.35))
	for bp in block_p:
		dbg.draw_colored_polygon(bp, Color(1, 0, 0, 0.35))
	for e in d.exits:
		dbg.draw_rect(Rect2(e.r[0], e.r[1], e.r[2] - e.r[0], e.r[3] - e.r[1]), Color(0, 0.5, 1, 0.5))
	for h in d.hot:
		dbg.draw_rect(Rect2(h.r[0], h.r[1], h.r[2] - h.r[0], h.r[3] - h.r[1]), Color(1, 1, 0, 0.35))
	dbg.draw_circle(player.position, 4, Color.MAGENTA)

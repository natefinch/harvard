extends Node

var _frame := 0
var mash := true
var errors := []


func _process(_d: float) -> void:
	_frame += 1
	if mash and _frame % 3 == 0:
		var e := InputEventAction.new()
		e.action = "accept"
		e.pressed = true
		Input.parse_input_event(e)
	elif mash and _frame % 3 == 1:
		var e := InputEventAction.new()
		e.action = "accept"
		e.pressed = false
		Input.parse_input_event(e)


func _ready() -> void:
	_go.call_deferred()


func check_spawns() -> void:
	for id in Locs.L:
		var spawns: Dictionary = Locs.L[id].spawns
		var first: String = spawns.keys()[0]
		var l := Location.new(id, first)
		Game.main.add_child(l)
		await get_tree().process_frame
		await get_tree().process_frame
		for s in spawns:
			var p: Array = spawns[s]
			if not l.can_stand(Vector2(p[0], p[1]), l.player):
				print("BAD SPAWN ", id, " ", s)
		var step := 8.0
		var seen := {}
		var q: Array[Vector2] = []
		for s in spawns:
			var p: Array = spawns[s]
			var v := (Vector2(p[0], p[1]) / step).round()
			if l.can_stand(v * step, l.player) and not seen.has(v):
				seen[v] = true
				q.append(v)
		while q.size() > 0:
			var v: Vector2 = q.pop_back()
			for dv in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				var nv: Vector2 = v + dv
				if not seen.has(nv) and l.can_stand(nv * step, l.player):
					seen[nv] = true
					q.append(nv)
		var pts: Array = seen.keys().map(func(v): return v * step)
		var d: Dictionary = Locs.L[id]
		for e in d.exits:
			if not pts.any(func(p): return l._in_rect(p, e.r, 2.0)):
				print("UNREACHABLE EXIT ", id, " -> ", e.to)
		for h in d.hot:
			if not pts.any(func(p): return l._in_rect(p, h.r, l.H * 0.3)):
				print("UNREACHABLE HOT ", id, " ", h.ev)
		for k in l.npcs:
			var n: Actor = l.npcs[k]
			if not pts.any(func(p): return p.distance_to(n.position) < n.radius * 1.6 + l.H * 0.35):
				print("UNREACHABLE NPC ", id, " ", k)
		print("checked ", id, " cells=", pts.size())
		l.queue_free()
		await get_tree().process_frame


func ev(loc: String, spawn: String, name: String) -> void:
	if Game.location != loc:
		await Game.goto(loc, spawn)
		await get_tree().create_timer(0.3).timeout
	while Game.cutscene > 0:
		await get_tree().process_frame
	print("-- ", name, " @", loc, " time=", Game.time, " party=", Game.party.map(func(m): return "%s L%d %d/%d" % [m.id, m.lvl, m.hp, m.max_hp]))
	await Story.run(name)


func _go() -> void:
	Story.quiet = true
	for f in ["intro_done", "met_chief", "lane_done", "crypt_done"]:
		Game.setf(f)
	await check_spawns()
	Game.flags = {}
	Story.quiet = false
	if OS.get_cmdline_user_args().has("reach"):
		get_tree().quit()
		return
	Game.new_game()
	await Story.intro()
	for m in Game.party:
		m.atk += 10
		m.max_hp += 200
		m.hp = m.max_hp
	await ev("common", "west", "chief")
	assert(Game.flag("met_chief"))
	await ev("store", "door", "coffee_pot")
	await ev("lovers_lane", "south", "culvert")
	print("lane_done=", Game.flag("lane_done"), " party=", Game.party.size())
	await ev("lovers_lane", "south", "cellar_hole")
	await ev("library", "door", "mary")
	await ev("library", "door", "microfiche")
	await ev("library", "door", "mary")
	await ev("library", "door", "mary")
	await ev("cemetery", "gate", "kit_cemetery")
	await ev("cemetery", "gate", "crypt")
	await ev("cemetery", "gate", "patty")
	for m in Game.party:
		m.atk += 10
		m.max_hp += 200
		m.hp = m.max_hp
	await ev("bellview", "gate", "vault")
	print("bellview_done=", Game.flag("bellview_done"), " items=", Game.items)
	await ev("fruitvale", "path", "lark")
	await ev("fruitvale", "path", "lark")
	await ev("beach", "path", "sand")
	await ev("beach", "path", "dock_end")
	await get_tree().create_timer(1.0).timeout
	print("ch1_done=", Game.flag("ch1_done"), " loc=", Game.location)
	await ev("library", "door", "mary")
	print("knacks=", Game.member("sam").knacks)
	await Game.goto("overland", "common")
	await get_tree().create_timer(1.0).timeout
	print("overland ok; journal entries=", Game.journal.size())
	print("TEST DONE")
	get_tree().quit()

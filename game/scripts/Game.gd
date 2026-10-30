extends Node

const SAVE_PATH := "user://save.json"

var main: Node
var flags := {}
var party: Array = []
var items := {}
var money := 0
var time := "day"
var location := "farm"
var spawn := "porch"
var objective := ""
var journal: Array = []
var defeated := {}
var cutscene := 0
var cooldown := 0.0
var battling := false
var debug := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind("move_up", [KEY_UP, KEY_W])
	_bind("move_down", [KEY_DOWN, KEY_S])
	_bind("move_left", [KEY_LEFT, KEY_A])
	_bind("move_right", [KEY_RIGHT, KEY_D])
	_bind("accept", [KEY_Z, KEY_ENTER, KEY_SPACE, KEY_E, KEY_KP_ENTER])
	_bind("cancel", [KEY_X, KEY_ESCAPE, KEY_BACKSPACE])
	_bind("menu", [KEY_TAB, KEY_M, KEY_ESCAPE])
	_bind("debug", [KEY_F3])
	_bind("shot", [KEY_F12])


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _process(delta: float) -> void:
	cooldown = max(0.0, cooldown - delta)
	if Input.is_action_just_pressed("debug"):
		debug = not debug
		if main and main.world:
			main.world.queue_redraw()
	if Input.is_action_just_pressed("shot"):
		screenshot("user://shot_%d.png" % Time.get_ticks_msec())


func screenshot(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func busy() -> bool:
	return cutscene > 0 or battling or cooldown > 0.0 or UI.is_busy()


# ---------------------------------------------------------------- state

func new_game() -> void:
	flags = {}
	party = [make_member("sam")]
	items = {"coffee": 2}
	money = 12
	time = "day"
	objective = ""
	journal = []
	defeated = {}


func flag(name: String) -> bool:
	return flags.get(name, false)


func setf(name: String, v = true) -> void:
	flags[name] = v


func is_time(t: String) -> bool:
	return time == t


func set_time(t: String) -> void:
	time = t
	if main and main.world and main.world.has_method("apply_time"):
		main.world.apply_time()


func set_objective(text: String) -> void:
	objective = text
	note("GOAL: " + text)
	UI.update_hud()
	UI.toast("New goal: " + text)


func note(text: String) -> void:
	if journal.has(text):
		return
	journal.append(text)


func add_item(id: String, n := 1) -> void:
	items[id] = items.get(id, 0) + n


func has_item(id: String) -> bool:
	return items.get(id, 0) > 0


func remove_item(id: String, n := 1) -> void:
	items[id] = items.get(id, 0) - n
	if items[id] <= 0:
		items.erase(id)


func curio_count() -> int:
	var c := 0
	for id in items:
		if Data.ITEMS[id].get("curio", false):
			c += 1
	return c


func make_member(id: String) -> Dictionary:
	var b: Dictionary = Data.MEMBERS[id]
	return {"id": id, "name": b.name, "lvl": 1, "exp": 0,
		"max_hp": b.hp, "hp": b.hp, "max_nerve": b.nerve, "nerve": b.nerve,
		"atk": b.atk, "def": b.def, "spd": b.spd, "knacks": b.knacks.duplicate()}


func has_member(id: String) -> bool:
	for m in party:
		if m.id == id:
			return true
	return false


func member(id: String) -> Dictionary:
	for m in party:
		if m.id == id:
			return m
	return {}


func add_member(id: String) -> void:
	if has_member(id):
		return
	var m := make_member(id)
	var target: int = party[0].lvl
	while m.lvl < target:
		level_up(m)
	m.hp = m.max_hp
	m.nerve = m.max_nerve
	party.append(m)
	if main and main.world and main.world.has_method("refresh_party"):
		main.world.refresh_party()


func party_level() -> int:
	return party[0].lvl


func exp_to_next(lvl: int) -> int:
	return int(16 * pow(lvl, 1.75))


func level_up(m: Dictionary) -> String:
	m.lvl += 1
	var dhp := randi_range(5, 8)
	var dnv := randi_range(1, 3)
	m.max_hp += dhp
	m.max_nerve += dnv
	m.atk += randi_range(1, 3)
	m.def += randi_range(1, 2)
	m.spd += randi_range(0, 2)
	m.hp += dhp
	m.nerve += dnv
	var extra := ""
	if m.id == "kit" and m.lvl >= 4 and not m.knacks.has("rocket"):
		m.knacks.append("rocket")
		extra = " Kit learned Bottle Rocket!"
	return "%s is now level %d! (+%d HP, +%d Nerve)%s" % [m.name, m.lvl, dhp, dnv, extra]


func gain_exp(m: Dictionary, n: int) -> Array:
	var out := []
	m.exp += n
	while m.exp >= exp_to_next(m.lvl):
		m.exp -= exp_to_next(m.lvl)
		out.append(level_up(m))
	return out


func heal_all() -> void:
	for m in party:
		m.hp = m.max_hp
		m.nerve = m.max_nerve


func cond(expr: String) -> bool:
	if expr == "":
		return true
	var e := Expression.new()
	if e.parse(expr) != OK:
		push_error("bad cond: " + expr)
		return false
	var r = e.execute([], self)
	if e.has_execute_failed():
		push_error("cond failed: " + expr)
		return false
	return bool(r)


# ---------------------------------------------------------------- save/load

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save() -> void:
	var d := {"flags": flags, "party": party, "items": items, "money": money, "time": time,
		"location": location, "spawn": spawn, "objective": objective, "journal": journal}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "  "))


func load_game() -> bool:
	if not has_save():
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return false
	flags = d.flags
	party = d.party
	for m in party:
		for k in ["lvl", "exp", "max_hp", "hp", "max_nerve", "nerve", "atk", "def", "spd"]:
			m[k] = int(m[k])
	items = {}
	for k in d.items:
		items[k] = int(d.items[k])
	money = int(d.money)
	time = d.time
	location = d.location
	spawn = d.spawn
	objective = d.objective
	journal = d.journal
	defeated = {}
	return true


# ---------------------------------------------------------------- scene flow

func goto(loc_id: String, spawn_id: String) -> void:
	cutscene += 1
	await UI.fade_out()
	location = loc_id
	spawn = spawn_id
	if loc_id == "overland":
		main.set_world(Overland.new(spawn_id))
	else:
		main.set_world(Location.new(loc_id, spawn_id))
	UI.update_hud()
	await UI.fade_in()
	cutscene -= 1


func battle(enemies: Array, opts := {}) -> String:
	battling = true
	if main.world:
		main.world.process_mode = Node.PROCESS_MODE_DISABLED
	var b := Battle.new(enemies, opts)
	main.add_child(b)
	var result: String = await b.finished
	b.queue_free()
	if main.world:
		main.world.process_mode = Node.PROCESS_MODE_INHERIT
		if main.world.has_method("resume_music"):
			main.world.resume_music()
	battling = false
	cooldown = 0.3
	return result


func lose() -> void:
	cutscene += 1
	Audio.play_music("gameover", false)
	await UI.fade_out(1.0)
	await UI.card("Everything goes dark.", "You wake up on Grandma's couch under an afghan that smells like woodsmoke.")
	money = money / 2
	heal_all()
	cutscene -= 1
	await goto("farm", "porch")
	UI.toast("You lost half your cash. Grandma left you a cider donut.")
	add_item("donut")


func make_group(kind: String) -> Array:
	var counts := {"raccoon": [1, 3], "goose": [1, 2], "cyclist": [1, 2], "hollow": [1, 2],
		"wisp": [2, 3], "scarecrow": [1, 2], "coveralls": [1, 2]}
	var r: Array = counts.get(kind, [1, 1])
	var n := randi_range(r[0], r[1])
	var g := []
	for i in n:
		g.append(kind)
	if kind == "hollow" and randf() < 0.4:
		g.append("wisp")
	return g

class_name Battle
extends CanvasLayer

signal finished(result: String)

var opts: Dictionary
var foes: Array = []      # {id, name, hp, max_hp, atk, def, spd, ghost, boss, stun, node, data}
var members: Array = []   # party dicts from Game.party
var disp := {}            # member id -> displayed hp (float)
var panels := {}          # member id -> {panel, hp, nv, name}
var stun := {}            # member id -> turns
var guard := {}
var msg_label: RichTextLabel
var root: Control
var enemy_row: HBoxContainer
var over := false


func _init(enemy_ids: Array, o := {}) -> void:
	opts = o
	layer = 5
	var counts := {}
	for e in enemy_ids:
		counts[e] = counts.get(e, 0) + 1
	var seen := {}
	for e in enemy_ids:
		var dd: Dictionary = Data.ENEMIES[e]
		var nm: String = dd.name
		if counts[e] > 1:
			seen[e] = seen.get(e, 0) + 1
			nm += " " + "ABCD"[seen[e] - 1]
		foes.append({"id": e, "name": nm, "hp": dd.hp, "max_hp": dd.hp, "atk": dd.atk, "def": dd.def,
			"spd": dd.spd, "ghost": dd.get("ghost", false), "boss": dd.get("boss", false), "stun": 0, "data": dd})


func _ready() -> void:
	members = Game.party
	UI.show_hud(false)
	var boss := false
	for f in foes:
		boss = boss or f.boss
	Audio.play_music(opts.get("music", "boss" if boss else "battle"), true, 0.2)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/battle_bg.gdshader")
	var ghost := false
	for f in foes:
		ghost = ghost or f.ghost
	if boss:
		mat.set_shader_parameter("c1", Color(0.25, 0.03, 0.05))
		mat.set_shader_parameter("c2", Color(0.05, 0.02, 0.08))
		mat.set_shader_parameter("c3", Color(0.55, 0.35, 0.05))
		mat.set_shader_parameter("speed", 1.4)
	elif ghost:
		mat.set_shader_parameter("c1", Color(0.02, 0.1, 0.18))
		mat.set_shader_parameter("c2", Color(0.1, 0.35, 0.4))
		mat.set_shader_parameter("c3", Color(0.3, 0.1, 0.35))
	else:
		mat.set_shader_parameter("c1", Color(0.3, 0.12, 0.03))
		mat.set_shader_parameter("c2", Color(0.12, 0.25, 0.08))
		mat.set_shader_parameter("c3", Color(0.45, 0.3, 0.1))
	bg.material = mat
	root.add_child(bg)
	enemy_row = HBoxContainer.new()
	enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_row.add_theme_constant_override("separation", 30)
	enemy_row.position = Vector2(0, 110)
	enemy_row.size = Vector2(1280, 420)
	root.add_child(enemy_row)
	for f in foes:
		var t := TextureRect.new()
		t.texture = load("res://assets/enemies/%s.png" % f.id)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var h: float = (380.0 if f.boss else 270.0) * f.data.get("scale", 1.0)
		if foes.size() >= 3:
			h *= 0.82
		h = min(h, 420.0)
		var w: float = h * t.texture.get_width() / t.texture.get_height()
		t.custom_minimum_size = Vector2(w, h)
		t.size_flags_vertical = Control.SIZE_SHRINK_END
		t.pivot_offset = Vector2(w / 2, h)
		if f.ghost:
			t.modulate = Color(0.85, 0.95, 1.0, 0.85)
		enemy_row.add_child(t)
		f.node = t
	var mb := PanelContainer.new()
	mb.add_theme_stylebox_override("panel", UI.box_style())
	mb.position = Vector2(40, 16)
	mb.size = Vector2(1200, 84)
	msg_label = RichTextLabel.new()
	msg_label.bbcode_enabled = true
	msg_label.custom_minimum_size = Vector2(1170, 54)
	msg_label.add_theme_font_override("normal_font", UI.f_body)
	msg_label.add_theme_font_size_override("normal_font_size", 23)
	mb.add_child(msg_label)
	root.add_child(mb)
	var prow := HBoxContainer.new()
	prow.alignment = BoxContainer.ALIGNMENT_CENTER
	prow.add_theme_constant_override("separation", 14)
	prow.position = Vector2(0, 560)
	prow.size = Vector2(1280, 140)
	root.add_child(prow)
	for m in members:
		disp[m.id] = float(m.hp)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.box_style())
		p.custom_minimum_size = Vector2(230, 130)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -4)
		p.add_child(v)
		var nm := UI.label(m.name, UI.f_type, 24, Color(1, 0.88, 0.55))
		v.add_child(nm)
		var hp := UI.label("", UI.f_hud, 34)
		v.add_child(hp)
		var nv := UI.label("", UI.f_hud, 28, Color(0.7, 0.85, 1))
		v.add_child(nv)
		prow.add_child(p)
		panels[m.id] = {"panel": p, "hp": hp, "nv": nv, "name": nm}
	_run.call_deferred()


func _process(delta: float) -> void:
	for m in members:
		var dv: float = disp[m.id]
		var target := float(m.hp)
		if dv > target:
			dv = max(target, dv - delta * max(14.0, (dv - target) * 0.6))
		elif dv < target:
			dv = min(target, dv + delta * 40.0)
		disp[m.id] = dv
		var pn: Dictionary = panels[m.id]
		pn.hp.text = "HP %03d" % int(ceil(dv))
		pn.nv.text = "NV %02d" % m.nerve
		var ko := alive_m(m) == false
		pn.panel.modulate = Color(0.45, 0.45, 0.5) if ko else Color.WHITE
		pn.hp.add_theme_color_override("font_color", Color(1, 0.4, 0.35) if dv < m.max_hp * 0.25 else Color(0.95, 0.95, 0.9))


func alive_m(m: Dictionary) -> bool:
	return ceil(disp[m.id]) > 0


func alive_foes() -> Array:
	return foes.filter(func(f): return f.hp > 0)


func alive_members() -> Array:
	return members.filter(func(m): return alive_m(m))


func msg(text: String, hold := 0.75) -> void:
	msg_label.text = text
	msg_label.visible_characters = 0
	var total := msg_label.get_total_character_count()
	var shown := 0.0
	while shown < total:
		await get_tree().process_frame
		shown += get_process_delta_time() * 90.0
		if Input.is_action_just_pressed("accept"):
			shown = total
		msg_label.visible_characters = int(shown)
	msg_label.visible_characters = -1
	var t := 0.0
	while t < hold:
		await get_tree().process_frame
		t += get_process_delta_time()
		if Input.is_action_just_pressed("accept"):
			break


func _run() -> void:
	var names := []
	for f in foes:
		names.append(f.name)
	var intro: String = opts.get("intro", "")
	if intro == "":
		intro = ("You confront %s!" if foes.size() == 1 else "You confront %s!") % _join(names)
	await msg(intro, 1.0)
	while not over:
		var plan := await _choose_actions()
		if plan.has("run_away"):
			await msg("You got away!", 0.6)
			_end("run")
			return
		await _do_round(plan.actions)
		if over:
			return


func _join(a: Array) -> String:
	if a.size() == 1:
		return a[0]
	return ", ".join(a.slice(0, a.size() - 1)) + " and " + a[-1]


func _choose_actions() -> Dictionary:
	var actions := []
	var i := 0
	var acting := alive_members()
	while i < acting.size():
		var m: Dictionary = acting[i]
		if stun.get(m.id, 0) > 0:
			i += 1
			continue
		msg_label.text = "What will %s do?" % m.name
		msg_label.visible_characters = -1
		_highlight(m.id)
		var cmds := ["Bash", "Knack", "Goods", "Guard", "Run" if i == 0 else "Back"]
		var lb := ListBox.new(cmds, i > 0, 1)
		lb.position = Vector2(40, 330)
		root.add_child(lb)
		var r: int = await lb.run()
		lb.queue_free()
		if r == -1 or (r == 4 and i > 0):
			if actions.size() > 0:
				actions.pop_back()
			i = max(0, i - 1)
			while i > 0 and stun.get(acting[i].id, 0) > 0:
				i -= 1
			continue
		var act := {}
		match r:
			0:
				var t = await _pick_foe()
				if t == null:
					continue
				act = {"who": m, "kind": "bash", "target": t}
			1:
				act = await _pick_knack(m)
				if act.is_empty():
					continue
			2:
				var id: String = await UI.goods_menu(true)
				if id == "":
					continue
				var it: Dictionary = Data.ITEMS[id]
				var target = null
				if it.use == "ghost":
					target = await _pick_foe()
					if target == null:
						continue
				elif it.use == "heal" or it.use == "nerve" or it.use == "revive":
					var w := await UI.pick_member("Use %s on whom?" % it.name)
					if w < 0:
						continue
					target = members[w]
				act = {"who": m, "kind": "item", "item": id, "target": target}
			3:
				act = {"who": m, "kind": "guard"}
			4:
				if opts.get("no_run", false) or _has_boss():
					await msg("There's no running from this one!", 0.5)
					continue
				var chance: float = 0.55 + (m.spd - _avg_foe_spd()) * 0.04
				if randf() < chance:
					_highlight("")
					return {"run_away": true}
				await msg("You couldn't get away!", 0.5)
				_highlight("")
				return {"actions": []}
		actions.append(act)
		i += 1
	_highlight("")
	return {"actions": actions}


func _has_boss() -> bool:
	for f in foes:
		if f.boss:
			return true
	return false


func _avg_foe_spd() -> float:
	var s := 0.0
	var a := alive_foes()
	for f in a:
		s += f.spd
	return s / max(1, a.size())


func _highlight(id: String) -> void:
	for k in panels:
		var p: PanelContainer = panels[k].panel
		p.position.y = -14 if k == id else 0


func _pick_foe():
	var a := alive_foes()
	if a.size() == 1:
		return a[0]
	var names := []
	for f in a:
		names.append(f.name)
	var lb := ListBox.new(names, true, 1)
	lb.position = Vector2(40, 330)
	var blink := func(i):
		for f in a:
			f.node.self_modulate = Color.WHITE
		a[i].node.self_modulate = Color(1.4, 1.4, 0.8)
	lb.changed.connect(blink)
	root.add_child(lb)
	var r: int = await lb.run()
	lb.queue_free()
	for f in a:
		f.node.self_modulate = Color.WHITE
	return a[r] if r >= 0 else null


func _pick_knack(m: Dictionary) -> Dictionary:
	var names := []
	var dis := []
	for k in m.knacks:
		var kd: Dictionary = Data.KNACKS[k]
		names.append("%s (%d NV)" % [kd.name, kd.cost])
		dis.append(m.nerve < kd.cost)
	var lb := ListBox.new(names, true, 1, dis)
	lb.position = Vector2(40, 300)
	root.add_child(lb)
	var r: int = await lb.run()
	lb.queue_free()
	if r < 0:
		return {}
	var k: String = m.knacks[r]
	var kd: Dictionary = Data.KNACKS[k]
	var target = null
	match kd.type:
		"dmg", "weaken":
			target = await _pick_foe()
			if target == null:
				return {}
		"heal":
			if kd.get("self", false):
				target = m
			else:
				var w := await UI.pick_member("Pep talk whom?")
				if w < 0:
					return {}
				target = members[w]
	return {"who": m, "kind": "knack", "knack": k, "target": target}


func _do_round(actions: Array) -> void:
	var order := []
	for a in actions:
		order.append({"spd": a.who.spd * randf_range(0.8, 1.2), "a": a, "foe": null})
	for f in alive_foes():
		order.append({"spd": f.spd * randf_range(0.8, 1.2), "a": null, "foe": f})
	order.sort_custom(func(x, y): return x.spd > y.spd)
	guard.clear()
	for a in actions:
		if a.kind == "guard":
			guard[a.who.id] = true
	for o in order:
		if over:
			return
		if o.a != null:
			var m: Dictionary = o.a.who
			if not alive_m(m):
				continue
			await _member_act(o.a)
		else:
			var f: Dictionary = o.foe
			if f.hp <= 0:
				continue
			if f.stun > 0:
				f.stun -= 1
				await msg("%s is frozen in place!" % f.name, 0.5)
				continue
			await _foe_act(f)
		if alive_foes().is_empty():
			await _victory()
			return
		if alive_members().is_empty():
			await _defeat()
			return
	for k in stun.keys():
		stun[k] = max(0, stun[k] - 1)
	# give the odometer a moment, then check for KO
	if alive_members().is_empty():
		await _defeat()


func _retarget(t):
	if t == null or t.hp > 0:
		return t
	var a := alive_foes()
	return a[0] if a.size() > 0 else null


func _member_act(a: Dictionary) -> void:
	var m: Dictionary = a.who
	match a.kind:
		"guard":
			m.nerve = min(m.max_nerve, m.nerve + 1)
			await msg("%s braces for trouble." % m.name, 0.4)
		"bash":
			var t = _retarget(a.target)
			if t == null:
				return
			await msg("%s %s %s!" % [m.name, Data.MEMBERS[m.id].bash, t.name], 0.25)
			if randf() < 0.07:
				Audio.sfx("miss")
				await msg("Just missed!", 0.4)
				return
			var dmg := _calc(m.atk, t.def, 1.0)
			var crit := randf() < 1.0 / 16.0
			if crit:
				dmg = dmg * 2 + 4
				Audio.sfx("crit")
				await msg("[color=yellow]SMAAAASH!![/color]", 0.2)
			await _hurt_foe(t, dmg)
		"knack":
			await _knack(m, a.knack, a.target)
		"item":
			await _item(m, a.item, a.target)


func _calc(atk: float, def: float, power: float) -> int:
	return max(1, int(round((atk * 2.0 - def) * power * randf_range(0.85, 1.15))))


func _knack(m: Dictionary, k: String, target) -> void:
	var kd: Dictionary = Data.KNACKS[k]
	if m.nerve < kd.cost:
		await msg("%s doesn't have the nerve!" % m.name, 0.5)
		return
	m.nerve -= kd.cost
	match kd.type:
		"dmg":
			var t = _retarget(target)
			if t == null:
				return
			await msg(kd.text % [m.name, t.name] if kd.text.count("%s") == 2 else kd.text % m.name, 0.3)
			var power: float = kd.power + m.atk * 0.9
			if t.ghost:
				power *= kd.get("ghost", 1.0)
				if kd.get("ghost", 1.0) < 1.0:
					await msg("It passes right through %s!" % t.name, 0.3)
			var dmg: int = max(1, int(power * randf_range(0.9, 1.1) - t.def * 0.5))
			await _hurt_foe(t, dmg)
			if t.hp > 0 and randf() < kd.get("stun", 0.0):
				t.stun = 1
				await msg("%s is dazzled!" % t.name, 0.4)
		"dmg_all":
			await msg(kd.text % m.name, 0.3)
			for t in alive_foes():
				var power: float = kd.power + m.atk * 0.6
				if t.ghost:
					power *= kd.get("ghost", 1.0)
				await _hurt_foe(t, max(1, int(power * randf_range(0.9, 1.1) - t.def * 0.4)))
		"stun_all":
			await msg(kd.text % m.name, 0.3)
			var any := false
			for t in alive_foes():
				if kd.get("living_only", false) and t.ghost:
					continue
				if randf() < kd.stun:
					t.stun = 1
					any = true
					await msg("%s freezes!" % t.name, 0.3)
			if not any:
				await msg("Nobody seems impressed.", 0.4)
		"heal":
			var t: Dictionary = target
			if not alive_m(t):
				await msg("%s can't hear anything right now." % t.name, 0.4)
				return
			await msg(kd.text % [m.name, t.name] if kd.text.count("%s") == 2 else kd.text % m.name, 0.3)
			var n: int = min(kd.power + m.lvl * 2, t.max_hp - t.hp)
			t.hp += n
			Audio.sfx("heal")
			await msg("%s recovered %d HP!" % [t.name, n], 0.4)
		"fetch":
			await msg(kd.text % m.name, 0.5)
			var roll := randf()
			if roll < 0.25:
				await msg("Dusty came back with a stick. Good boy.", 0.5)
			else:
				var id: String = ["coffee", "donut", "rock_salt", "batteries", "cider"].pick_random()
				Game.add_item(id)
				Audio.sfx("pickup")
				await msg("Dusty came back with %s!" % Data.ITEMS[id].name, 0.5)
		"weaken":
			var t = _retarget(target)
			if t == null:
				return
			await msg(kd.text % [m.name, t.name], 0.3)
			t.atk = max(1, int(t.atk * 0.75))
			await msg("%s looks less sure of itself." % t.name, 0.4)


func _item(m: Dictionary, id: String, target) -> void:
	if not Game.has_item(id):
		await msg("%s fumbles... it's gone!" % m.name, 0.4)
		return
	var it: Dictionary = Data.ITEMS[id]
	match it.use:
		"heal", "nerve", "revive":
			var t: Dictionary = target
			if it.use == "revive":
				if alive_m(t):
					await msg("%s is already awake." % t.name, 0.4)
					return
				t.hp = it.power
				disp[t.id] = float(it.power)
				Game.remove_item(id)
				Audio.sfx("heal")
				await msg("%s waves the smelling salts. %s came to!" % [m.name, t.name], 0.5)
				return
			if not alive_m(t):
				await msg("%s is out cold." % t.name, 0.4)
				return
			await msg("%s uses the %s." % [m.name, it.name], 0.2)
			await msg(UI.use_item_on(id, t), 0.4)
		"ghost":
			var t = _retarget(target)
			if t == null:
				return
			Game.remove_item(id)
			await msg("%s hurls a fistful of %s at %s!" % [m.name, it.name, t.name], 0.3)
			var p: float = it.power * (1.0 if t.ghost else 0.4)
			await _hurt_foe(t, int(p * randf_range(0.9, 1.1)))
		"all":
			Game.remove_item(id)
			await msg("%s lights a %s! FWEEEE-POP!" % [m.name, it.name], 0.3)
			for t in alive_foes():
				await _hurt_foe(t, int(it.power * randf_range(0.9, 1.1)))


func _hurt_foe(t: Dictionary, dmg: int) -> void:
	t.hp = max(0, t.hp - dmg)
	Audio.sfx("hit")
	var n: TextureRect = t.node
	var tw := create_tween()
	tw.tween_property(n, "self_modulate", Color(3, 1.2, 1.2), 0.05)
	tw.tween_property(n, "self_modulate", Color.WHITE, 0.15)
	var px := n.position.x
	var tw2 := create_tween()
	for i in 4:
		tw2.tween_property(n, "position:x", px + (8 if i % 2 == 0 else -8), 0.04)
	tw2.tween_property(n, "position:x", px, 0.04)
	await msg("%d damage to %s!" % [dmg, t.name], 0.35)
	if t.hp <= 0:
		Audio.sfx("enemy_die")
		var tw3 := create_tween()
		tw3.tween_property(n, "modulate:a", 0.0, 0.5)
		await msg(t.data.defeat % t.name, 0.5)


func _foe_act(f: Dictionary) -> void:
	var moves: Array = f.data.moves
	var mv: Array = moves.pick_random()
	var targets := alive_members()
	if targets.is_empty():
		return
	var t: Dictionary = targets.pick_random()
	var text: String = mv[0]
	text = text % [f.name, t.name] if text.count("%s") == 2 else text % f.name
	var tw := create_tween()
	tw.tween_property(f.node, "scale", Vector2(1.08, 1.08), 0.1)
	tw.tween_property(f.node, "scale", Vector2.ONE, 0.15)
	await msg(text, 0.3)
	match mv[1]:
		"hit":
			await _hurt_member(t, _calc(f.atk, t.def, mv[2]))
		"hit_all":
			for m in alive_members():
				await _hurt_member(m, _calc(f.atk, m.def, mv[2]))
		"nerve":
			var n: int = min(t.nerve, int(mv[2]))
			t.nerve -= n
			Audio.sfx("hum" if f.ghost else "miss", 1.3, -6)
			await msg("%s lost %d Nerve!" % [t.name, n] if n > 0 else "%s holds it together." % t.name, 0.4)
		"stun":
			if randf() < 0.6:
				stun[t.id] = 1
				await msg("%s can't move!" % t.name, 0.4)
			else:
				await msg("%s shakes it off!" % t.name, 0.4)
		_:
			pass


func _hurt_member(m: Dictionary, dmg: int) -> void:
	if guard.get(m.id, false):
		dmg = max(1, dmg / 2)
	m.hp = max(0, m.hp - dmg)
	Audio.sfx("hit", 0.8)
	var p: PanelContainer = panels[m.id].panel
	var tw := create_tween()
	tw.tween_property(p, "modulate", Color(1.6, 0.5, 0.5), 0.05)
	tw.tween_property(p, "modulate", Color.WHITE, 0.2)
	await msg("%s takes %d damage!" % [m.name, dmg], 0.35)
	if m.hp <= 0:
		await msg("[color=#ff8080]%s's HP is rolling toward zero! Heal quickly![/color]" % m.name, 0.4)


func _victory() -> void:
	over = true
	Audio.play_music("victory", false, 0.1)
	var exp := 0
	var cash := 0
	for f in foes:
		exp += f.data.exp
		cash += f.data.money
	await msg("You won!", 0.8)
	for m in members:
		m.hp = max(m.hp, int(ceil(disp[m.id])))
		disp[m.id] = float(m.hp)
	var alive := alive_members()
	await msg("Everyone gained %d EXP." % exp if alive.size() > 1 else "%s gained %d EXP." % [alive[0].name, exp], 0.6)
	for m in alive:
		for line in Game.gain_exp(m, exp):
			Audio.sfx("save")
			await msg(line, 1.0)
	if cash > 0:
		Game.money += cash
		await msg("Found $%d." % cash, 0.6)
	for m in members:
		if m.hp <= 0:
			m.hp = 1
	_end("win")


func _defeat() -> void:
	over = true
	await msg("Everyone has lost their nerve...", 1.4)
	_end("lose")


func _end(result: String) -> void:
	over = true
	if result != "lose":
		for m in members:
			m.hp = max(m.hp, int(ceil(disp[m.id])))
	await UI.fade_out(0.3)
	UI.fade_in(0.3)
	UI.update_hud()
	finished.emit(result)

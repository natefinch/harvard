extends CanvasLayer

var f_body: Font
var f_title: Font
var f_type: Font
var f_hud: Font
var f_old: Font

var root: Control
var hud: Control
var hud_goal: Label
var hud_info: Label
var fader: ColorRect
var toast_box: VBoxContainer

var _dialog := false
var _menu := false
var _portraits := {}


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	f_body = load("res://assets/fonts/CourierPrime-Bold.ttf")
	f_title = load("res://assets/fonts/IMFellEnglishSC-Regular.ttf")
	f_type = load("res://assets/fonts/SpecialElite-Regular.ttf")
	f_hud = load("res://assets/fonts/VT323-Regular.ttf")
	f_old = load("res://assets/fonts/IMFellEnglish-Italic.ttf")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_hud()
	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(340, 70)
	toast_box.size = Vector2(600, 10)
	root.add_child(toast_box)
	var fl := CanvasLayer.new()
	fl.layer = 50
	add_child(fl)
	fader = ColorRect.new()
	fader.color = Color.BLACK
	fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fader.modulate.a = 0.0
	fl.add_child(fader)


func _process(_d: float) -> void:
	if Input.is_action_just_pressed("menu") and not Game.busy() and Game.main and Game.main.world \
			and Game.main.world.has_method("is_field"):
		field_menu()


func is_busy() -> bool:
	return _dialog or _menu


static func box_style(alpha := 0.94) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.07, 0.13, alpha)
	s.border_color = Color(0.93, 0.9, 0.8)
	s.set_border_width_all(3)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(14)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 6
	return s


func label(text: String, font: Font, size: int, color := Color(0.95, 0.93, 0.88)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	root.add_child(hud)
	hud_goal = label("", f_hud, 24, Color(1, 0.95, 0.7))
	hud_goal.position = Vector2(16, 8)
	hud_goal.add_theme_color_override("font_outline_color", Color.BLACK)
	hud_goal.add_theme_constant_override("outline_size", 6)
	hud.add_child(hud_goal)
	hud_info = label("", f_hud, 24)
	hud_info.position = Vector2(1000, 8)
	hud_info.size = Vector2(264, 30)
	hud_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_info.add_theme_color_override("font_outline_color", Color.BLACK)
	hud_info.add_theme_constant_override("outline_size", 6)
	hud.add_child(hud_info)
	var hint := label("Z/Enter: talk · Tab: menu", f_hud, 18, Color(1, 1, 1, 0.6))
	hint.position = Vector2(16, 690)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 5)
	hud.add_child(hint)


func update_hud() -> void:
	var w = Game.main.world if Game.main else null
	hud.visible = w != null and w.has_method("is_field") and not Game.battling
	hud_goal.text = ("» " + Game.objective) if Game.objective != "" else ""
	var place := ""
	if w and "title" in w:
		place = w.title + "  "
	hud_info.text = "%s%s  $%d" % [place, Game.time.to_upper(), Game.money]


func show_hud(v: bool) -> void:
	hud.visible = v


# ---------------------------------------------------------------- fades / cards / toasts

func fade_out(t := 0.35) -> void:
	var tw := create_tween()
	tw.tween_property(fader, "modulate:a", 1.0, t)
	await tw.finished


func fade_in(t := 0.35) -> void:
	var tw := create_tween()
	tw.tween_property(fader, "modulate:a", 0.0, t)
	await tw.finished


func flash(c := Color.WHITE, t := 0.25) -> void:
	var r := ColorRect.new()
	r.color = c
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "modulate:a", 0.0, t)
	await tw.finished
	r.queue_free()


func toast(text: String) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box_style(0.85))
	var l := label(text, f_body, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 560
	p.add_child(l)
	toast_box.add_child(p)
	var tw := create_tween()
	tw.tween_interval(2.8)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func wait_accept() -> void:
	await get_tree().process_frame
	while not Input.is_action_just_pressed("accept"):
		await get_tree().process_frame


func card(title: String, body := "", wait := true) -> void:
	_dialog = true
	var c := ColorRect.new()
	c.color = Color(0.02, 0.02, 0.04)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 24)
	c.add_child(v)
	var t := label(title, f_title, 46, Color(0.95, 0.88, 0.7))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if body != "":
		var b := label(body, f_type, 24)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.x = 900
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(b)
	c.modulate.a = 0
	var fl := fader.get_parent()
	fl.add_child(c)
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.6)
	await tw.finished
	if wait:
		await wait_accept()
	else:
		await get_tree().create_timer(2.0).timeout
	tw = create_tween()
	tw.tween_property(c, "modulate:a", 0.0, 0.5)
	await tw.finished
	c.queue_free()
	_dialog = false


# ---------------------------------------------------------------- dialogue

func portrait(id: String) -> Texture2D:
	if not _portraits.has(id):
		var p := "res://assets/portraits/%s.png" % id
		_portraits[id] = load(p) if ResourceLoader.exists(p) else null
	return _portraits[id]


func _dialog_box(id: String) -> Array:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", box_style())
	box.position = Vector2(40, 500)
	box.size = Vector2(1200, 196)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	box.add_child(h)
	var tex := portrait(id)
	if tex:
		var pr := TextureRect.new()
		pr.texture = tex
		pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pr.custom_minimum_size = Vector2(190, 166)
		h.add_child(pr)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	if id != "":
		v.add_child(label(Data.NAMES.get(id, id.capitalize()), f_type, 24, Color(1, 0.85, 0.5)))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_override("normal_font", f_body)
	rt.add_theme_font_override("italics_font", f_old)
	rt.add_theme_font_size_override("normal_font_size", 23)
	rt.add_theme_font_size_override("italics_font_size", 25)
	rt.add_theme_color_override("default_color", Color(0.95, 0.94, 0.9))
	v.add_child(rt)
	root.add_child(box)
	return [box, rt]


func say(id: String, text: String) -> void:
	_dialog = true
	var parts := _dialog_box(id)
	var box: Control = parts[0]
	var rt: RichTextLabel = parts[1]
	if id == "":
		rt.text = "[i]" + text + "[/i]" if not text.begins_with("*") else text
	else:
		rt.text = text
	rt.visible_characters = 0
	await get_tree().process_frame
	var total := rt.get_total_character_count()
	var shown := 0.0
	var pitch := 0.9 + float(abs(id.hash()) % 40) / 100.0
	while shown < total:
		await get_tree().process_frame
		if Input.is_action_just_pressed("accept"):
			shown = total
		else:
			var prev := int(shown)
			shown += get_process_delta_time() * 70.0
			if int(shown) / 3 != prev / 3:
				Audio.sfx("blip", pitch, -12)
		rt.visible_characters = int(shown)
	rt.visible_characters = -1
	var arrow := label("▼", f_body, 20, Color(1, 0.9, 0.6))
	arrow.position = Vector2(1160, 160)
	box.add_child(arrow)
	await wait_accept()
	box.queue_free()
	_dialog = false
	Game.cooldown = 0.15


func talk(lines: Array) -> void:
	for l in lines:
		await say(l[0], l[1])


func choose(prompt_id: String, prompt: String, opts: Array, can_cancel := false) -> int:
	_dialog = true
	var box: Control = null
	if prompt != "":
		var parts := _dialog_box(prompt_id)
		box = parts[0]
		parts[1].text = prompt
	var lb := ListBox.new(opts, can_cancel)
	lb.position = Vector2(860, 480 - 46 * opts.size()) if box else Vector2(860, 300)
	root.add_child(lb)
	var r: int = await lb.run()
	lb.queue_free()
	if box:
		box.queue_free()
	_dialog = false
	Game.cooldown = 0.15
	return r


func confirm(id: String, prompt: String) -> bool:
	return await choose(id, prompt, ["Yes", "No"]) == 0


# ---------------------------------------------------------------- menus

func _side_panel(pos: Vector2, size: Vector2) -> Array:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box_style())
	p.position = pos
	p.size = size
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.custom_minimum_size = size - Vector2(28, 28)
	rt.add_theme_font_override("normal_font", f_body)
	rt.add_theme_font_override("bold_font", f_type)
	rt.add_theme_font_override("italics_font", f_old)
	rt.add_theme_font_size_override("normal_font_size", 20)
	rt.add_theme_font_size_override("bold_font_size", 22)
	rt.add_theme_font_size_override("italics_font_size", 22)
	p.add_child(rt)
	root.add_child(p)
	return [p, rt]


func field_menu() -> void:
	_menu = true
	get_tree().paused = true
	Audio.sfx("select")
	while true:
		var lb := ListBox.new(["Goods", "Status", "Journal", "Settings", "Quit Game"])
		lb.position = Vector2(40, 50)
		root.add_child(lb)
		var money := _side_panel(Vector2(40, 280), Vector2(190, 60))
		money[1].text = "Cash: $%d" % Game.money
		var r: int = await lb.run()
		lb.queue_free()
		money[0].queue_free()
		match r:
			0: await goods_menu()
			1: await status_screen()
			2: await journal_screen()
			3: await settings_menu()
			4:
				get_tree().paused = false
				_menu = false
				if await confirm("", "Quit to the title screen? (Unsaved progress will be lost. Save at a payphone.)"):
					get_tree().paused = false
					title_screen()
					return
				_menu = true
				get_tree().paused = true
			_: break
	get_tree().paused = false
	_menu = false
	Game.cooldown = 0.2


func settings_menu() -> void:
	var panel := SettingsMenu.new()
	root.add_child(panel)
	await panel.run()
	panel.queue_free()
	if Audio.save_settings() != OK:
		toast("Couldn't save audio settings. Check available disk space and folder permissions.")
	Game.cooldown = 0.2


func goods_menu(in_battle := false) -> String:
	var ids: Array = Game.items.keys()
	if ids.is_empty():
		toast("Your pockets are empty.")
		return ""
	var names := []
	var dis := []
	for id in ids:
		var it: Dictionary = Data.ITEMS[id]
		names.append("%s ×%d" % [it.name, Game.items[id]] if not it.get("key", false) else it.name)
		var u: String = it.get("use", "")
		dis.append(u == "" or (not in_battle and (u == "ghost" or u == "all")))
	var lb := ListBox.new(names, true, 1, dis)
	lb.position = Vector2(250, 50)
	var desc := _side_panel(Vector2(250, 520), Vector2(990, 120))
	lb.changed.connect(func(i): desc[1].text = Data.ITEMS[ids[i]].desc)
	root.add_child(lb)
	var r: int = await lb.run()
	lb.queue_free()
	desc[0].queue_free()
	if r < 0:
		return ""
	var id: String = ids[r]
	if in_battle:
		return id
	var it: Dictionary = Data.ITEMS[id]
	var who := await pick_member("Use on whom?")
	if who < 0:
		return ""
	var m: Dictionary = Game.party[who]
	var msg := use_item_on(id, m)
	toast(msg)
	return id


func use_item_on(id: String, m: Dictionary) -> String:
	var it: Dictionary = Data.ITEMS[id]
	var msg := ""
	match it.use:
		"heal":
			if m.hp <= 0:
				return "%s is knocked out. Try smelling salts." % m.name
			var n: int = min(it.power, m.max_hp - m.hp)
			m.hp += n
			msg = "%s recovered %d HP." % [m.name, n]
		"nerve":
			var n: int = min(it.power, m.max_nerve - m.nerve)
			m.nerve += n
			msg = "%s recovered %d Nerve." % [m.name, n]
		"revive":
			if m.hp > 0:
				return "%s is already awake." % m.name
			m.hp = it.power
			msg = "%s came to!" % m.name
	Game.remove_item(id)
	Audio.sfx("heal")
	return msg


func pick_member(prompt: String) -> int:
	var names := []
	for m in Game.party:
		names.append("%s  %d/%d HP  %d/%d NV" % [m.name, m.hp, m.max_hp, m.nerve, m.max_nerve])
	var lb := ListBox.new(names)
	lb.position = Vector2(560, 200)
	var p := label(prompt, f_type, 22, Color(1, 0.9, 0.6))
	p.position = Vector2(560, 160)
	p.add_theme_color_override("font_outline_color", Color.BLACK)
	p.add_theme_constant_override("outline_size", 6)
	root.add_child(p)
	root.add_child(lb)
	var r: int = await lb.run()
	lb.queue_free()
	p.queue_free()
	return r


func status_screen() -> void:
	var s := _side_panel(Vector2(250, 50), Vector2(990, 600))
	var t := ""
	for m in Game.party:
		t += "[b]%s[/b]   Level %d    EXP to next: %d\n" % [m.name, m.lvl, Game.exp_to_next(m.lvl) - m.exp]
		t += "HP %d/%d   Nerve %d/%d   Guts %d   Grit %d   Speed %d\n" % [m.hp, m.max_hp, m.nerve, m.max_nerve, m.atk, m.def, m.spd]
		var ks := []
		for k in m.knacks:
			ks.append(Data.KNACKS[k].name)
		t += "Knacks: " + ", ".join(ks) + "\n\n"
	s[1].text = t
	await wait_accept_or_cancel()
	s[0].queue_free()


func journal_screen() -> void:
	var s := _side_panel(Vector2(250, 50), Vector2(990, 600))
	s[1].scroll_following = true
	var t := "[b]Current goal:[/b] %s\n\n" % (Game.objective if Game.objective != "" else "Look around.")
	var recent: Array = Game.journal.slice(max(0, Game.journal.size() - 18))
	for j in recent:
		if not j.begins_with("GOAL:"):
			t += "• " + j + "\n"
	s[1].text = t
	await wait_accept_or_cancel()
	s[0].queue_free()


func wait_accept_or_cancel() -> void:
	await get_tree().process_frame
	while not (Input.is_action_just_pressed("accept") or Input.is_action_just_pressed("cancel")):
		await get_tree().process_frame
	Audio.sfx("cancel")


func shop() -> void:
	_menu = true
	while true:
		var names := []
		for id in Data.SHOP:
			names.append("%-16s $%d" % [Data.ITEMS[id].name, Data.ITEMS[id].price])
		names.append("Done")
		var lb := ListBox.new(names)
		lb.position = Vector2(40, 50)
		var desc := _side_panel(Vector2(40, 520), Vector2(1200, 120))
		var cash := _side_panel(Vector2(1000, 50), Vector2(240, 60))
		cash[1].text = "Cash: $%d" % Game.money
		lb.changed.connect(func(i): desc[1].text = Data.ITEMS[Data.SHOP[i]].desc if i < Data.SHOP.size() else "Nell: \"Come back anytime, hon.\"")
		root.add_child(lb)
		var r: int = await lb.run()
		lb.queue_free()
		desc[0].queue_free()
		cash[0].queue_free()
		if r < 0 or r >= Data.SHOP.size():
			break
		var id: String = Data.SHOP[r]
		var price: int = Data.ITEMS[id].price
		if Game.money < price:
			Audio.sfx("cancel")
			toast("Not enough cash.")
			continue
		Game.money -= price
		Game.add_item(id)
		Audio.sfx("pickup")
		toast("Bought %s." % Data.ITEMS[id].name)
	_menu = false
	update_hud()
	Game.cooldown = 0.2


# ---------------------------------------------------------------- title

func title_screen() -> void:
	for c in root.get_children():
		if c is ListBox:
			c.queue_free()
	if Game.main.world:
		Game.main.world.queue_free()
		Game.main.world = null
	hud.visible = false
	fader.modulate.a = 0
	Audio.play_music("title")
	var t := Control.new()
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(t)
	var bg := TextureRect.new()
	var art := "res://assets/ui/title.png"
	bg.texture = load(art) if ResourceLoader.exists(art) else load("res://assets/map/overland.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0.05, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.add_child(shade)
	var title_l := label("NOWHERE NEAR CAMBRIDGE", f_title, 64, Color(0.97, 0.9, 0.72))
	title_l.position = Vector2(0, 70)
	title_l.size = Vector2(1280, 80)
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	title_l.add_theme_constant_override("outline_size", 14)
	t.add_child(title_l)
	var sub := label("Harvard, Massachusetts · October 1995", f_type, 26, Color(0.9, 0.9, 0.85))
	sub.position = Vector2(0, 150)
	sub.size = Vector2(1280, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_outline_color", Color.BLACK)
	sub.add_theme_constant_override("outline_size", 8)
	t.add_child(sub)
	var opts := ["New Game"]
	if Game.has_save():
		opts.insert(0, "Continue")
	opts.append_array(["Settings", "Quit"])
	var pick := ""
	while true:
		var lb := ListBox.new(opts, false)
		lb.position = Vector2(540, 470)
		lb.custom_minimum_size.x = 200
		t.add_child(lb)
		var r: int = await lb.run()
		pick = opts[r]
		lb.queue_free()
		if pick != "Settings":
			break
		await settings_menu()
	await fade_out(0.6)
	t.queue_free()
	match pick:
		"Continue":
			Game.load_game()
			fader.modulate.a = 1
			await Game.goto(Game.location, Game.spawn)
			toast("Welcome back.")
		"New Game":
			Game.new_game()
			fader.modulate.a = 0
			await Story.intro()
		_:
			get_tree().quit()

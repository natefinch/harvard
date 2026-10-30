class_name SettingsMenu
extends PanelContainer

signal closed

var _controls: Array[Control] = []
var _active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = Vector2(220, 110) if UI.touch_ui else Vector2(280, 190)
	custom_minimum_size = Vector2(840, 500) if UI.touch_ui else Vector2(720, 340)
	add_theme_stylebox_override("panel", UI.box_style())
	theme = Theme.new()
	theme.default_font = UI.f_body
	theme.default_font_size = 30 if UI.touch_ui else 22
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color(1, 0.93, 0.6)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(4)
	add_theme_stylebox_override("focus", focus)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 20)
	add_child(layout)
	layout.add_child(UI.label("Settings", UI.f_title, 42 if UI.touch_ui else 36))
	for channel in Audio.CHANNELS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		layout.add_child(row)
		var title := UI.label("Music" if channel == "Music" else "Sound effects", UI.f_body, 30 if UI.touch_ui else 22)
		title.custom_minimum_size.x = 230 if UI.touch_ui else 170
		row.add_child(title)
		var slider := HSlider.new()
		slider.name = channel + "Volume"
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.value = Audio.volumes[channel] * 100
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size = Vector2(220, UI.touch_row_height() if UI.touch_ui else 44)
		slider.add_theme_stylebox_override("focus", focus)
		row.add_child(slider)
		_controls.append(slider)
		var percent := UI.label("%d%%" % roundi(slider.value), UI.f_body, 30 if UI.touch_ui else 22)
		percent.custom_minimum_size.x = 90 if UI.touch_ui else 64
		percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(percent)
		var mute := Button.new()
		mute.name = channel + "Mute"
		mute.toggle_mode = true
		mute.button_pressed = Audio.muted[channel]
		mute.text = "Muted" if mute.button_pressed else "Mute"
		mute.custom_minimum_size = Vector2(125, UI.touch_row_height() if UI.touch_ui else 44)
		mute.add_theme_stylebox_override("focus", focus)
		mute.tooltip_text = "Mute %s without changing its volume" % title.text.to_lower()
		row.add_child(mute)
		_controls.append(mute)
		slider.value_changed.connect(func(value: float):
			Audio.set_volume(channel, value / 100.0)
			percent.text = "%d%%" % roundi(value))
		slider.drag_ended.connect(func(changed: bool):
			if changed and channel == "SFX":
				Audio.sfx("select"))
		mute.toggled.connect(func(value: bool):
			Audio.set_muted(channel, value)
			mute.text = "Muted" if value else "Mute"
			Audio.sfx("select"))
	var back := Button.new()
	back.name = "Back"
	back.text = "Back"
	back.custom_minimum_size = Vector2(150, UI.touch_row_height()) if UI.touch_ui else Vector2(120, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.add_theme_stylebox_override("focus", focus)
	back.pressed.connect(_close)
	layout.add_child(back)
	_controls.append(back)
	var hint := "Drag a slider; tap Mute or Back." if UI.touch_ui else "Up/Down: select   Left/Right: volume   Z/Enter: choose   Esc: back"
	layout.add_child(UI.label(hint, UI.f_hud, 26 if UI.touch_ui else 20))


func run() -> void:
	await get_tree().process_frame
	_controls[0].grab_focus()
	_active = true
	await closed


func _input(event: InputEvent) -> void:
	if not _active:
		return
	var current := get_viewport().gui_get_focus_owner()
	var index := _controls.find(current)
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_close()
	elif event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		var direction := 1 if event.is_action_pressed("move_down") else -1
		_controls[wrapi(index + direction, 0, _controls.size())].grab_focus()
		Audio.sfx("cursor")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_left", true) or event.is_action_pressed("move_right", true):
		if current is HSlider:
			current.value += 5 if event.is_action_pressed("move_right", true) else -5
			if current.name == "SFXVolume":
				Audio.sfx("cursor")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("accept"):
		get_viewport().set_input_as_handled()
		if current is Button:
			if current.toggle_mode:
				current.button_pressed = not current.button_pressed
			else:
				current.pressed.emit()


func _close() -> void:
	if not _active:
		return
	_active = false
	Audio.sfx("cancel")
	closed.emit()

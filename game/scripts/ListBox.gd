class_name ListBox
extends PanelContainer

signal changed(idx: int)

var options: Array = []
var disabled: Array = []
var index := 0
var cancelable := true
var columns := 1
var _labels: Array[Label] = []
var _grid: GridContainer
var _scroll: ScrollContainer
var _running := false
var _tap_index := -1
var _tap_down_index := -1
var _tap_down_position := Vector2.ZERO


func _init(opts: Array, can_cancel := true, cols := 1, dis: Array = []) -> void:
	options = opts
	cancelable = can_cancel
	columns = cols
	disabled = dis
	add_theme_stylebox_override("panel", UI.box_style())
	_grid = GridContainer.new()
	_grid.columns = cols
	_grid.add_theme_constant_override("h_separation", 28)
	_grid.add_theme_constant_override("v_separation", 2)
	var font_size := 30 if UI.touch_ui else 22
	var row_height := UI.touch_row_height() if UI.touch_ui else 0.0
	if UI.touch_ui:
		_scroll = ScrollContainer.new()
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		var rows := ceili(float(options.size()) / columns)
		_scroll.custom_minimum_size.y = minf(rows * (row_height + 2.0), 400.0)
		var widest := 0.0
		for option in options:
			widest = maxf(widest, UI.f_body.get_string_size("> " + str(option), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		_scroll.custom_minimum_size.x = minf(1100.0, widest * columns + 28.0 * (columns - 1) + 24.0)
		add_child(_scroll)
		_scroll.add_child(_grid)
	else:
		add_child(_grid)
	for i in options.size():
		var l := Label.new()
		l.add_theme_font_override("font", UI.f_body)
		l.add_theme_font_size_override("font_size", font_size)
		if UI.touch_ui:
			l.custom_minimum_size.y = row_height
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.mouse_filter = Control.MOUSE_FILTER_PASS
			l.gui_input.connect(_option_input.bind(i))
		_grid.add_child(l)
		_labels.append(l)
	_refresh()


func _ready() -> void:
	if UI.touch_ui:
		call_deferred("_clamp_to_screen")


func _clamp_to_screen() -> void:
	position.x = clampf(position.x, 0.0, maxf(0.0, 1280.0 - size.x))
	position.y = clampf(position.y, 0.0, maxf(0.0, 704.0 - size.y))


func _option_input(event: InputEvent, option: int) -> void:
	if not _running or not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_tap_down_index = option
		_tap_down_position = event.global_position
	elif _tap_down_index == option:
		if event.global_position.distance_to(_tap_down_position) < 12.0:
			_tap_index = option
		_tap_down_index = -1


func _refresh() -> void:
	for i in _labels.size():
		var pre := "> " if i == index else "  "
		_labels[i].text = pre + str(options[i])
		var c := Color(1, 0.93, 0.6) if i == index else Color(0.93, 0.92, 0.88)
		if disabled.size() > i and disabled[i]:
			c = Color(0.5, 0.5, 0.5) if i != index else Color(0.75, 0.7, 0.45)
		_labels[i].add_theme_color_override("font_color", c)


func _move(d: int) -> void:
	if options.is_empty():
		return
	index = wrapi(index + d, 0, options.size())
	Audio.sfx("cursor")
	_refresh()
	changed.emit(index)
	if _scroll:
		_scroll.ensure_control_visible.call_deferred(_labels[index])


func run() -> int:
	changed.emit(index)
	await get_tree().process_frame
	_running = true
	while true:
		await get_tree().process_frame
		if not is_inside_tree():
			_running = false
			return -1
		if _tap_index >= 0:
			index = _tap_index
			_tap_index = -1
			_refresh()
			changed.emit(index)
			if disabled.size() > index and disabled[index]:
				Audio.sfx("cancel")
				continue
			_running = false
			Audio.sfx("select")
			return index
		elif Input.is_action_just_pressed("move_down"):
			_move(columns)
		elif Input.is_action_just_pressed("move_up"):
			_move(-columns)
		elif columns > 1 and Input.is_action_just_pressed("move_right"):
			_move(1)
		elif columns > 1 and Input.is_action_just_pressed("move_left"):
			_move(-1)
		elif Input.is_action_just_pressed("accept") and not options.is_empty():
			if disabled.size() > index and disabled[index]:
				Audio.sfx("cancel")
				continue
			_running = false
			Audio.sfx("select")
			return index
		elif cancelable and Input.is_action_just_pressed("cancel"):
			_running = false
			Audio.sfx("cancel")
			return -1
	return -1

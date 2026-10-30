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
	add_child(_grid)
	for i in options.size():
		var l := Label.new()
		l.add_theme_font_override("font", UI.f_body)
		l.add_theme_font_size_override("font_size", 22)
		_grid.add_child(l)
		_labels.append(l)
	_refresh()


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


func run() -> int:
	changed.emit(index)
	await get_tree().process_frame
	while true:
		await get_tree().process_frame
		if not is_inside_tree():
			return -1
		if Input.is_action_just_pressed("move_down"):
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
			Audio.sfx("select")
			return index
		elif cancelable and Input.is_action_just_pressed("cancel"):
			Audio.sfx("cancel")
			return -1
	return -1

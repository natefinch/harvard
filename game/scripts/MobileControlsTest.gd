extends Node

var failures := 0
var selection := -2
var choice := -2
var speech_finished := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func frames(count := 3) -> void:
	for i in count:
		await get_tree().process_frame


func click(control: Control, fraction := Vector2(0.5, 0.5)) -> void:
	var pos := control.global_position + control.size * fraction
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	get_viewport().push_input(motion, true)
	await frames()
	var event := InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event, true)
	await frames()
	event = InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	get_viewport().push_input(event, true)
	await frames()


func run_list(list: ListBox) -> void:
	selection = await list.run()


func run_choice() -> void:
	choice = await UI.choose("", "Which way?", ["First", "Second"])


func run_speech() -> void:
	await UI.say("", "A message you can tap to continue.")
	speech_finished = true


func run_long_speech() -> void:
	await UI.say("", "For a moment you can see straight down through the water.\n\nA road. Stone walls. Twelve houses with lamps in every window. People sitting at their tables in their Sunday clothes, faces turned up toward you, waiting.\n\nAnd on the road, on a red bicycle, Rowan Fitch is pedaling slowly toward the dam.")
	speech_finished = true


func find_list(node: Node) -> ListBox:
	for child in node.get_children():
		if child is ListBox and not child.is_queued_for_deletion():
			return child
		var found := find_list(child)
		if found:
			return found
	return null


func find_settings() -> SettingsMenu:
	for child in UI.root.get_children():
		if child is SettingsMenu and not child.is_queued_for_deletion():
			return child
	return null


func find_dialog() -> PanelContainer:
	for child in UI.root.get_children():
		if child is PanelContainer and not child.is_queued_for_deletion():
			return child
	return null


func _run() -> void:
	if not OS.get_user_data_dir().begins_with(OS.get_environment("HOME") + "/") or FileAccess.file_exists(Audio.SETTINGS_PATH):
		push_error("Mobile controls test requires a fresh temporary HOME.")
		get_tree().quit(1)
		return
	check(UI.touch_ui, "Mobile controls test needs --touch-ui")
	Game.new_game()
	Story.quiet = true

	var list := ListBox.new(["Disabled", "First", "Second"], true, 1, [true, false, false])
	list.position = Vector2(300, 40)
	UI.root.add_child(list)
	run_list.call_deferred(list)
	await frames(5)
	check(list._labels[0].size.y >= 72.0, "Touch menu rows are enlarged")
	await click(list._labels[0])
	check(selection == -2, "Tapping a disabled option does not choose it")
	await click(list._labels[2])
	check(selection == 2, "Tapping an enabled menu option chooses it")
	list.queue_free()
	await frames()

	var many := ListBox.new(["One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight"])
	many.position = Vector2(40, 50)
	UI.root.add_child(many)
	await frames(5)
	check(many.size.y <= 440.0, "Long touch menus stay within the screen")
	many._move(7)
	await frames(5)
	check(many._scroll.scroll_vertical > 0, "Keyboard navigation scrolls to the selected option")
	many.queue_free()
	await frames()

	run_choice.call_deferred()
	await frames(5)
	list = find_list(UI.root)
	check(list != null, "Dialogue choice appears")
	if list:
		await click(list._labels[1])
		check(choice == 1, "Tapping a dialogue choice selects it")
	await frames()

	run_speech.call_deferred()
	await frames(5)
	var dialog := find_dialog()
	check(dialog != null, "Touch dialogue appears")
	if dialog:
		await click(dialog, Vector2(0.8, 0.65))
		await frames(5)
		if not speech_finished:
			await click(dialog, Vector2(0.8, 0.65))
		check(speech_finished, "Tapping dialogue advances it")
	await frames()

	speech_finished = false
	run_long_speech.call_deferred()
	await frames(5)
	dialog = find_dialog()
	check(dialog != null, "Long touch dialogue appears")
	if dialog:
		check(dialog.position.y + dialog.size.y <= 720.0, "Long dialogue stays within the screen")
		await click(dialog, Vector2(0.8, 0.65))
		await frames(5)
		if not speech_finished:
			await click(dialog, Vector2(0.8, 0.65))
		check(speech_finished, "Long dialogue can be advanced")
	await frames()

	UI.settings_menu()
	await frames(5)
	var panel := find_settings()
	check(panel != null, "Touch settings appear")
	if panel:
		var mute: Button = panel.find_child("MusicMute", true, false)
		await click(mute)
		check(Audio.muted.Music, "Touch settings can toggle mute")
		await click(panel.find_child("Back", true, false))
		check(find_settings() == null, "Touch settings Back closes the panel")

	var overland := Overland.new("dillard_farm")
	Game.main.set_world(overland)
	await frames(5)
	var rendered_size := overland.map.texture.get_size() * overland.map.scale
	check(rendered_size.is_equal_approx(overland.size), "Overland art retains the map's world coordinates")
	Game.cooldown = 0.0
	var before := overland.player.position
	var key := InputEventKey.new()
	key.physical_keycode = KEY_RIGHT
	key.pressed = true
	Input.parse_input_event(key)
	for i in 5:
		await get_tree().physics_frame
	key = InputEventKey.new()
	key.physical_keycode = KEY_RIGHT
	key.pressed = false
	Input.parse_input_event(key)
	check(overland.player.position.x > before.x, "The virtual pad's keyboard input moves the player")
	await frames()
	await get_tree().physics_frame
	var stopped := overland.player.position
	for i in 5:
		await get_tree().physics_frame
	check(overland.player.position.is_equal_approx(stopped), "Releasing the pad's key stops movement")

	overland.queue_free()
	Game.main.world = null
	await frames()
	for player in Audio._music + Audio._sfx:
		player.stop()
		player.stream = null
	Audio._cache.clear()
	await get_tree().create_timer(0.1).timeout
	print("MOBILE CONTROLS TEST: %d failures" % failures)
	get_tree().quit(1 if failures else 0)

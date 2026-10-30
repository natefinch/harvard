extends Node

var failures := 0


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


func key(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await frames()
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await frames()


func click(control: Control, fraction := Vector2(0.5, 0.5)) -> void:
	var pos := control.global_position + control.size * fraction
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	get_viewport().push_input(motion, true)
	await frames()
	var event := InputEventMouseButton.new()
	event.position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event, true)
	await frames()
	event = InputEventMouseButton.new()
	event.position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	get_viewport().push_input(event, true)
	await frames()


func menu() -> SettingsMenu:
	for child in UI.root.get_children():
		if child is SettingsMenu and not child.is_queued_for_deletion():
			return child
	return null


func list_box(node: Node) -> ListBox:
	for child in node.get_children():
		if child is ListBox and not child.is_queued_for_deletion():
			return child
		var found := list_box(child)
		if found:
			return found
	return null


func _run() -> void:
	# Run with an isolated user-data directory: menu saves must not affect a player's settings.
	if not OS.get_user_data_dir().begins_with(OS.get_environment("HOME") + "/") or FileAccess.file_exists(Audio.SETTINGS_PATH):
		push_error("Audio settings test requires a fresh temporary HOME.")
		get_tree().quit(1)
		return
	var old_volume: Dictionary = Audio.volumes.duplicate()
	var old_muted: Dictionary = Audio.muted.duplicate()
	Audio.set_volume("Music", 0.35)
	Audio.set_volume("SFX", 0.65)
	Audio.set_muted("Music", true)
	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	check(AudioServer.is_bus_mute(music_bus), "Music mute reaches bus")
	check(not AudioServer.is_bus_mute(sfx_bus), "Music mute leaves SFX audible")
	check(is_equal_approx(AudioServer.get_bus_volume_db(sfx_bus), -14.0), "SFX level reaches bus as dB curve")
	check(is_equal_approx(Audio.slider_to_db(0.75), -10.0), "75% slider is -10 dB")
	check(is_equal_approx(Audio.slider_to_db(0.5), -20.0), "50% slider is -20 dB")
	check(is_equal_approx(Audio.slider_to_db(1.0), 0.0), "100% slider is 0 dB")
	check(Audio.slider_to_db(0.0) <= -80.0, "0% slider is silent")
	Audio.play_music("town", true, 0.01)
	Audio.sfx("hit")
	await get_tree().create_timer(0.05).timeout
	for player in Audio._music:
		check(player.bus == "Music", "Crossfade players use music bus")
	for player in Audio._sfx:
		check(player.bus == "SFX", "All effects use SFX bus")
	check(AudioServer.is_bus_mute(music_bus), "Crossfading preserves music mute")
	check(Audio.save_settings() == OK, "Save audio settings")
	Audio.set_volume("Music", 1.0)
	Audio.set_volume("SFX", 1.0)
	Audio.set_muted("Music", false)
	Audio.load_settings()
	check(is_equal_approx(Audio.volumes.Music, 0.35) and Audio.muted.Music, "Restore music level and mute")
	check(is_equal_approx(Audio.volumes.SFX, 0.65), "Restore SFX level")
	Audio.set_volume("SFX", 0.0)
	check(AudioServer.is_bus_mute(sfx_bus), "Zero slider silences bus")
	check(not Audio.muted.SFX, "Zero slider doesn't overwrite mute toggle")
	Audio.set_volume("SFX", 0.65)
	check(not AudioServer.is_bus_mute(sfx_bus), "Raising slider restores unmuted audio")

	Game.new_game()
	Game.location = "farm"
	Game.spawn = "porch"
	Game.save()
	Story.quiet = true
	UI.title_screen()
	await frames()
	var title_list := list_box(UI.root)
	check(title_list != null and title_list.options.has("Settings"), "Title offers Settings")
	if title_list == null:
		get_tree().quit(1)
		return
	title_list.index = title_list.options.find("Settings")
	await key("accept")
	var panel := menu()
	check(panel != null, "Title Settings opens")
	if panel == null:
		get_tree().quit(1)
		return
	var music_slider: HSlider = panel.find_child("MusicVolume", true, false)
	await key("move_left")
	check(is_equal_approx(Audio.volumes.Music, 0.30), "Keyboard changes focused music slider")
	await key("move_down")
	await key("accept")
	check(not Audio.muted.Music and is_equal_approx(Audio.volumes.Music, 0.30), "Unmute preserves slider")
	var sfx_slider: HSlider = panel.find_child("SFXVolume", true, false)
	await click(sfx_slider, Vector2(0.25, 0.5))
	check(Audio.volumes.SFX > 0.1 and Audio.volumes.SFX < 0.4, "Mouse adjusts SFX slider")
	var mute: Button = panel.find_child("SFXMute", true, false)
	await click(mute)
	check(Audio.muted.SFX and mute.text == "Muted", "Mouse toggles SFX mute")
	if OS.get_cmdline_user_args().has("shots"):
		await RenderingServer.frame_post_draw
		Game.screenshot("user://audio-settings.png")
	await key("cancel")
	check(menu() == null and list_box(UI.root) != null, "Escape returns to title menu")
	Audio.load_settings()
	check(Audio.muted.SFX and is_equal_approx(Audio.volumes.Music, 0.30), "Closing persists both channels")
	title_list = list_box(UI.root)
	title_list.index = title_list.options.find("Continue")
	await key("accept")
	await get_tree().create_timer(1.8).timeout
	check(Game.main.world != null and Game.cutscene == 0, "Continue still loads gameplay after Settings")
	Game.cooldown = 0
	await key("menu")
	var field_list := list_box(UI.root)
	check(field_list != null and field_list.options.has("Settings"), "Field menu offers Settings")
	if field_list == null:
		get_tree().quit(1)
		return
	field_list.index = field_list.options.find("Settings")
	await key("accept")
	panel = menu()
	check(panel != null and get_tree().paused, "Field Settings opens while game stays paused")
	if panel != null:
		music_slider = panel.find_child("MusicVolume", true, false)
		var initial := music_slider.value
		await key("move_right")
		check(music_slider.value == initial + 5, "Settings work while game is paused")
		await click(panel.find_child("Back", true, false))
	check(menu() == null and get_tree().paused, "Back returns to paused field menu")
	await key("cancel")
	check(not get_tree().paused and not UI.is_busy(), "Escape resumes gameplay")
	for channel in Audio.CHANNELS:
		Audio.set_volume(channel, old_volume[channel])
		Audio.set_muted(channel, old_muted[channel])
	Audio.save_settings()
	for player in Audio._music + Audio._sfx:
		player.stop()
		player.stream = null
	Audio._cache.clear()
	await get_tree().create_timer(0.1).timeout
	print("AUDIO SETTINGS TEST: %d failures" % failures)
	get_tree().quit(1 if failures else 0)

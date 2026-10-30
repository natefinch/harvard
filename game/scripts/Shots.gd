extends Node

const STOPS = [["farm","road","day"],["common","west","day"],["common","west","night"],["store","door","day"],["lovers_lane","south","dusk"],["library","door","day"],["cemetery","gate","dusk"],["bellview","gate","night"],["fruitvale","path","day"],["beach","path","night"],["overland","common","day"]]

func _ready() -> void:
	_go.call_deferred()

func _go() -> void:
	if OS.get_cmdline_user_args().has("title"):
		UI.title_screen()
		await get_tree().create_timer(1.5).timeout
		get_viewport().get_texture().get_image().save_png("/tmp/shots/title.png")
		get_tree().quit()
		return
	Game.new_game()
	Story.quiet = true
	Game.debug = OS.get_cmdline_user_args().has("dbg")
	for f in ["intro_done","met_chief","lane_done","crypt_done"]:
		Game.setf(f)
	Game.add_member("dani"); Game.add_member("kit")
	for s in STOPS:
		Game.time = s[2]
		await Game.goto(s[0], s[1])
		await get_tree().create_timer(1.2).timeout
		get_viewport().get_texture().get_image().save_png("/tmp/shots/%s_%s.png" % [s[0], s[2]])
	Game.battle(["hollow","raccoon"], {})
	await get_tree().create_timer(2.5).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/shots/battle.png")
	get_tree().quit()

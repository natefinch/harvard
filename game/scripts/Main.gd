extends Node

var world: Node


func _ready() -> void:
	Game.main = self
	randomize()
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "--shots":
		add_child(load("res://scripts/Shots.gd").new())
		return
	if args.size() > 0 and args[0] == "--test":
		var t = load("res://scripts/Test.gd").new()
		add_child(t)
		return
	UI.title_screen()


func set_world(w: Node) -> void:
	if world:
		world.queue_free()
	world = w
	add_child(w)
	move_child(w, 0)

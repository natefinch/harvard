class_name Actor
extends Node2D

var id := ""
var tex := {}
var spr: Sprite2D
var height := 70.0
var facing := Vector2.DOWN
var moving := false
var _t := 0.0
var persp := 1.0
var radius := 14.0
var ev := ""
var wobble := 0.0


func _init(sprite_id: String, h: float) -> void:
	id = sprite_id
	height = h
	radius = h * 0.2
	for d in ["down", "up", "side"]:
		var p := "res://assets/sprites/%s_%s.png" % [sprite_id, d]
		if ResourceLoader.exists(p):
			tex[d] = load(p)
	if tex.is_empty():
		var p := "res://assets/sprites/%s.png" % sprite_id
		if not ResourceLoader.exists(p):
			p = "res://assets/enemies/%s.png" % sprite_id
		tex["down"] = load(p)
	spr = Sprite2D.new()
	spr.centered = false
	add_child(spr)
	_apply()


func _draw() -> void:
	var w := height * 0.28 * persp
	if id == "dusty" and abs(facing.x) > abs(facing.y):
		w *= 1.6
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.32))
	draw_circle(Vector2.ZERO, w, Color(0, 0, 0, 0.32))


func face(d: Vector2) -> void:
	if d == Vector2.ZERO:
		return
	facing = d
	_apply()


func _apply() -> void:
	var key := "down"
	var flip := false
	if tex.size() > 1:
		if abs(facing.x) > abs(facing.y) * 0.9:
			key = "side"
			flip = facing.x < 0
		elif facing.y < 0:
			key = "up"
	var t: Texture2D = tex.get(key, tex["down"])
	spr.texture = t
	spr.flip_h = flip
	var hh := height
	if id == "dusty":
		hh = height * 0.62
	elif id == "girl" or id == "kit":
		hh = height * 0.86
	var s := hh / t.get_height() * persp
	spr.scale = Vector2(s, s)
	spr.position = Vector2(-t.get_width() * s / 2.0, -t.get_height() * s)
	queue_redraw()


func set_persp(p: float) -> void:
	if abs(p - persp) > 0.005:
		persp = p
		_apply()


func _process(delta: float) -> void:
	if moving:
		_t += delta * 11.0
		var b: float = abs(sin(_t)) * height * 0.035 * persp
		spr.position.y = -spr.texture.get_height() * spr.scale.y - b
		spr.rotation = sin(_t) * 0.025
	else:
		_t = 0.0
		spr.rotation = 0.0
		spr.position.y = -spr.texture.get_height() * spr.scale.y
		if wobble > 0:
			spr.rotation = sin(Time.get_ticks_msec() / 400.0 + position.x) * wobble

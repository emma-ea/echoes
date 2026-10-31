extends Node2D
## A ghost NPC: a translucent figure that hovers, flickers, glows faintly in the dark and
## turns to watch the explorer. Brighter while talking. Origin is on the floor line.

const Lighting := preload("res://scripts/world/lighting.gd")

var npc_id := ""
var placement: Dictionary = {}
var look := "porter"
var color := Color("a8d8ff")
var watch_x := 0.0  # the explorer's x, set by the world each frame
var talking := false

var _time := 0.0
var _facing := 1.0
var _glow: PointLight2D


func setup(p_placement: Dictionary, npc: Dictionary, floor_y: float) -> void:
	placement = p_placement
	npc_id = placement.get("id", "")
	look = npc.get("look", "porter")
	if Color.html_is_valid(str(npc.get("color", ""))):
		color = Color.html(npc.color)
	position = Vector2(float(placement.get("x", 0)), floor_y)
	watch_x = position.x - 1.0
	_time = randf() * 10.0
	var height: float = ContentDB.NPC_LOOKS.get(look, 185.0)
	_glow = Lighting.make_light(color, height * 1.4, 0.55)
	_glow.position = Vector2(0, -height * 0.6)
	add_child(_glow)


func _process(delta: float) -> void:
	_time += delta
	if absf(watch_x - position.x) > 8.0:
		_facing = signf(watch_x - position.x)
	var target := (0.95 if talking else 0.55) + sin(_time * 5.0) * 0.06
	_glow.energy = lerpf(_glow.energy, target, delta * 3.0)
	queue_redraw()


func _draw() -> void:
	# A faint glow on the floor beneath, then the figure hovering above it.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.2))
	draw_circle(Vector2.ZERO, 26.0, Color(color, 0.15))
	var hover := -10.0 + sin(_time * 1.6) * 5.0
	var flicker := 0.85 + 0.15 * sin(_time * 7.0) * sin(_time * 2.3)
	var alpha := (0.8 if talking else 0.55) * flicker
	draw_set_transform(Vector2(0, hover), 0.0, Vector2(_facing, 1.0))
	if look == "child":
		_draw_child(alpha)
	else:
		_draw_porter(alpha)


# A robe that fades out toward the floor, so the figure has no feet.
func _draw_robe(top_y: float, top_half_width: float, bottom_half_width: float, alpha: float) -> void:
	var solid := Color(color, alpha)
	var faded := Color(color, 0.0)
	draw_polygon(
		PackedVector2Array([Vector2(-top_half_width, top_y), Vector2(top_half_width, top_y),
			Vector2(bottom_half_width, 0), Vector2(-bottom_half_width, 0)]),
		PackedColorArray([solid, solid, faded, faded]))


func _draw_porter(alpha: float) -> void:
	var dark := Color(color.darkened(0.35), alpha)
	_draw_robe(-132, 17, 28, alpha)
	draw_line(Vector2(1, -128), Vector2(3, -50), Color(dark, alpha * 0.6), 2.0)
	# Head, porter's cap and a hollow eye.
	draw_circle(Vector2(2, -146), 13, Color(color.lightened(0.25), alpha))
	draw_rect(Rect2(-11, -163, 25, 10), dark)
	draw_rect(Rect2(-4, -155, 22, 4), dark)
	draw_circle(Vector2(8, -146), 2.6, Color(0.02, 0.03, 0.08, alpha))
	# Arm holding the ring of night-door keys.
	draw_line(Vector2(4, -124), Vector2(17, -94), Color(color, alpha), 6.0)
	draw_arc(Vector2(19, -86), 6.0, 0, TAU, 14, Color(Color("e0c070"), alpha), 2.0)
	draw_line(Vector2(21, -82), Vector2(24, -70), Color(Color("e0c070"), alpha), 2.0)


func _draw_child(alpha: float) -> void:
	var dark := Color(color.darkened(0.3), alpha)
	_draw_robe(-80, 11, 19, alpha)
	# Hair behind, then face, pigtail and a hollow eye.
	draw_circle(Vector2(-2, -95), 12, dark)
	draw_line(Vector2(-10, -93), Vector2(-17, -78), dark, 4.0)
	draw_circle(Vector2(4, -92), 9, Color(color.lightened(0.25), alpha))
	draw_circle(Vector2(8, -93), 2.2, Color(0.02, 0.03, 0.08, alpha))
	# Arm with a stub of chalk.
	draw_line(Vector2(3, -72), Vector2(13, -56), Color(color, alpha), 4.0)
	draw_rect(Rect2(11, -56, 6, 4), Color(1, 1, 1, alpha))

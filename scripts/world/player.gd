extends Node2D
## The explorer: a hooded figure with a lantern. Origin is at the feet, on the floor line.
## Walks toward a tap target (walk_to) or by keys (manual_axis, set by the world each frame).

signal arrived

const Lighting := preload("res://scripts/world/lighting.gd")

const SPEED := 280.0
const COAT := Color("2f5560")
const COAT_DARK := Color("223f47")
const TROUSERS := Color("2a2a32")
const BOOT := Color("1a1614")
const SKIN := Color("d9b38c")
const SCARF := Color("c9893b")
const METAL := Color("6b5a3c")
const FLAME := Color("ffd27a")

var min_x := 0.0
var max_x := 1280.0
var manual_axis := 0.0
var facing := 1.0

var _target_x := 0.0
var _moving := false
var _walk_phase := 0.0
var _walk_amount := 0.0  # 0 = idle, 1 = full stride; eased so starts and stops look smooth
var _time := 0.0
var _lantern: PointLight2D


func _ready() -> void:
	_lantern = Lighting.make_light(FLAME, 280.0, 1.1)
	add_child(_lantern)


func walk_to(x: float) -> void:
	_target_x = clampf(x, min_x, max_x)
	_moving = true


func stop() -> void:
	_moving = false


func face_toward(x: float) -> void:
	if absf(x - position.x) > 4.0:
		facing = signf(x - position.x)


func _process(delta: float) -> void:
	_time += delta
	var start_x := position.x
	if manual_axis != 0.0:
		_moving = false
		position.x += manual_axis * SPEED * delta
	elif _moving:
		var dx := _target_x - position.x
		if absf(dx) <= SPEED * delta:
			position.x = _target_x
			_moving = false
			arrived.emit()
		else:
			position.x += signf(dx) * SPEED * delta
	position.x = clampf(position.x, min_x, max_x)

	var moved := position.x - start_x
	if absf(moved) > 0.01:
		facing = signf(moved)
		_walk_phase += delta * 10.0
	_walk_amount = move_toward(_walk_amount, 1.0 if absf(moved) > 0.01 else 0.0, delta * 6.0)

	_lantern.position = Vector2(28 * facing, -60)
	_lantern.energy = 1.1 + sin(_time * 7.3) * 0.05 + sin(_time * 3.1) * 0.04
	queue_redraw()


func _draw() -> void:
	var step := sin(_walk_phase) * _walk_amount
	var bob := absf(sin(_walk_phase)) * 4.0 * _walk_amount + sin(_time * 2.0) * 0.8 * (1.0 - _walk_amount)

	# Shadow on the floor.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 30.0, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1.0))

	var hip := Vector2(0, -56 - bob)
	for side in [-1.0, 1.0]:
		var angle: float = step * 0.5 * side
		var foot := hip + Vector2(sin(angle), cos(angle)) * 56.0
		var knee := hip.lerp(foot, 0.5) + Vector2(4, 0)
		draw_polyline(PackedVector2Array([hip, knee, foot]), TROUSERS, 9.0)
		draw_line(foot + Vector2(-3, -2), foot + Vector2(11, -2), BOOT, 7.0)

	# Back arm, then the coat over it.
	var shoulder := Vector2(4, -104 - bob)
	draw_line(shoulder, shoulder + Vector2(-14 - step * 8.0, 30), COAT_DARK, 8.0)
	var sway := step * 4.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -114 - bob), Vector2(14, -114 - bob),
		Vector2(22, -40 - bob), Vector2(-26 - sway, -34 - bob),
	]), COAT)
	draw_line(Vector2(-1, -110 - bob), Vector2(2, -44 - bob), COAT_DARK, 2.0)

	# Scarf, its tail trailing behind.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -116 - bob), Vector2(13, -116 - bob), Vector2(11, -106 - bob), Vector2(-9, -106 - bob),
	]), SCARF)
	draw_line(Vector2(-9, -110 - bob), Vector2(-24 - sway * 1.5, -92 - bob), SCARF, 5.0)

	# Hooded head.
	var head := Vector2(3, -130 - bob)
	draw_circle(head + Vector2(-3, -2), 16, COAT_DARK)
	draw_circle(head + Vector2(3, 1), 11, SKIN)
	draw_circle(head + Vector2(8, -1), 1.8, BOOT)

	# Front arm holding the lantern.
	var hand := Vector2(24, -76 - bob + step * 2.0)
	draw_line(shoulder, hand, COAT, 8.0)
	var lantern_top := hand + Vector2(4, 6)
	draw_line(hand, lantern_top, METAL, 2.0)
	draw_circle(lantern_top + Vector2(0, 8), 20, Color(FLAME, 0.15))
	draw_rect(Rect2(lantern_top + Vector2(-6, 0), Vector2(12, 16)), METAL)
	draw_rect(Rect2(lantern_top + Vector2(-4, 2), Vector2(8, 12)), FLAME)

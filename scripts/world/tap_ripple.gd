extends Node2D
## A short ring on the floor where the player tapped, so taps feel acknowledged.

const SECONDS := 0.45

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= SECONDS:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / SECONDS, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
	draw_arc(Vector2.ZERO, 8.0 + 30.0 * k, 0, TAU, 32, Color(1, 0.9, 0.7, 0.7 * (1.0 - k)), 3.0)

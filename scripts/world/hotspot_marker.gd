extends Node2D
## Floating marker above a hotspot. Pulses gently, dims once used, and shows its name
## when the explorer is in range.

const WARM := Color("ffcf7a")

var hotspot: Dictionary = {}
var seen := false
var near := false:
	set(value):
		near = value
		if _label:
			_label.visible = value

var _label: Label
var _time := 0.0


func setup(p_hotspot: Dictionary) -> void:
	hotspot = p_hotspot
	var rect: Array = hotspot.get("rect", [0, 0, 0, 0])
	position = Vector2(rect[0] + rect[2] / 2.0, rect[1] - 16)
	_time = randf() * TAU

	_label = Label.new()
	_label.text = hotspot.get("label", "")
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_constant_override("outline_size", 8)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.size = Vector2(320, 32)
	# Labels go above the marker, or below it for hotspots near the top of the screen.
	_label.position = Vector2(-160, 20 if position.y < 120 else -56)
	_label.visible = false
	add_child(_label)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	var alpha := 1.0 if near else (0.35 if seen else 0.75) * (0.6 + 0.4 * pulse)
	var s := 7.0 + pulse * 2.0
	draw_colored_polygon(PackedVector2Array([Vector2(0, -s), Vector2(s * 0.7, 0), Vector2(0, s), Vector2(-s * 0.7, 0)]), Color(WARM, alpha))
	if near:
		draw_arc(Vector2.ZERO, 16 + pulse * 3, 0, TAU, 28, Color(WARM, 0.7), 2)

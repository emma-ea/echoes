extends Node2D
## A distant backdrop layer for outdoor scenes: either a row of rooftops or the night sky
## (stars and moon). Rooms move layers for parallax via `depth`; the title screen uses them as-is.

var kind := "buildings"  # "buildings" or "sky"
var from_x := -800.0
var to_x := 2400.0
var base_y := 600.0       # the horizon: building bottoms sit here
var min_height := 120.0
var max_height := 320.0
var color := Color("0c0f18")
var seed_value := 1
var depth := 0.4          # 0 = fixed to the screen, 1 = moves with the world


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if kind == "sky":
		_draw_sky(rng)
	else:
		_draw_buildings(rng)


func _draw_sky(rng: RandomNumberGenerator) -> void:
	for _i in int((to_x - from_x) / 9.0):
		var star := Vector2(rng.randf_range(from_x, to_x), rng.randf_range(-200, base_y * 0.6))
		draw_circle(star, rng.randf_range(0.6, 1.7), Color(1, 1, 1, rng.randf_range(0.15, 0.7)))
	# A pale moon with a soft halo.
	var moon := Vector2(from_x + (to_x - from_x) * 0.62, base_y * 0.22)
	for k in 6:
		draw_circle(moon, 40.0 + k * 22.0, Color(0.75, 0.8, 1.0, 0.025))
	draw_circle(moon, 34.0, Color("d8dcef"))
	draw_circle(moon + Vector2(11, -6), 30.0, Color("c3c8de"))


func _draw_buildings(rng: RandomNumberGenerator) -> void:
	var window := color.lightened(0.07)
	var x := from_x
	while x < to_x:
		var w := rng.randf_range(60.0, 160.0)
		var h := rng.randf_range(min_height, max_height)
		var top := base_y - h
		draw_rect(Rect2(x, top, w, h), color)
		match rng.randi() % 5:
			0:  # pitched roof
				draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + w / 2, top - w * 0.35), Vector2(x + w, top)]), color)
			1:  # spire
				draw_colored_polygon(PackedVector2Array([Vector2(x + w * 0.4, top), Vector2(x + w * 0.5, top - h * 0.45), Vector2(x + w * 0.6, top)]), color)
			2:  # dome
				draw_circle(Vector2(x + w / 2, top), w * 0.3, color)
			3:  # chimneys
				draw_rect(Rect2(x + w * 0.2, top - 26, 12, 26), color)
				draw_rect(Rect2(x + w * 0.65, top - 18, 10, 18), color)
		# Dead windows, just lighter than the wall.
		var row_y := top + 18
		while row_y < base_y - 20:
			var col_x := x + 10
			while col_x < x + w - 14:
				if rng.randf() < 0.35:
					draw_rect(Rect2(col_x, row_y, 7, 10), window)
				col_x += 18
			row_y += 24
		x += w + rng.randf_range(-8.0, 18.0)

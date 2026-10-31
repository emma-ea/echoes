extends Node2D
## One walkable side-view room built from scenes.json: a procedural wall and floor, props with
## their lights, and drifting dust. Rebuilt on scene change; refresh_state() handles flag changes.

const Prop := preload("res://scripts/world/prop.gd")
const Ghost := preload("res://scripts/world/ghost.gd")
const Skyline := preload("res://scripts/world/skyline.gd")

const ROOM_HEIGHT := 720.0
const LIGHT_FADE_SECONDS := 2.5

var scene_id := ""
var data: Dictionary = {}
var width := 1600.0
var floor_y := 600.0
var walk_min := 80.0
var walk_max := 1520.0
var spawn_x := 80.0
var style := "interior"

var ghosts: Array = []

var _props: Array = []
var _backdrop_layers: Array = []
var _wall := Color("5b5262")
var _trim := Color("6b5a5e")
var _floor := Color("3b3230")


func setup(p_scene_id: String) -> void:
	scene_id = p_scene_id
	data = ContentDB.scenes[scene_id]
	width = float(data.get("width", 1600))
	floor_y = float(data.get("floor_y", 600))
	var walk: Array = data.get("walk", [80, width - 80])
	walk_min = float(walk[0])
	walk_max = float(walk[1])
	spawn_x = float(data.get("spawn_x", walk_min))
	style = data.get("style", "interior")
	var palette: Dictionary = data.get("palette", {})
	_wall = _color(palette.get("wall"), _wall)
	_trim = _color(palette.get("trim"), _trim)
	_floor = _color(palette.get("floor"), _floor)

	if style == "street":
		_add_backdrop()
	for prop_data in data.get("props", []):
		var prop := Prop.new()
		prop.setup(prop_data)
		add_child(prop)
		_props.append(prop)
	for placement in data.get("npcs", []):
		var ghost := Ghost.new()
		ghost.setup(placement, ContentDB.npcs.get(placement.get("id", ""), {}), floor_y)
		ghost.z_index = 1  # behind the explorer
		add_child(ghost)
		ghosts.append(ghost)
	_add_dust()
	refresh_state(true)
	queue_redraw()


# Outdoors: sky, far rooftops and near rooftops, each scrolling slower than the street.
func _add_backdrop() -> void:
	var layers := [
		{"kind": "sky", "depth": 0.05, "seed": 11},
		{"kind": "buildings", "depth": 0.2, "seed": 12, "color": Color("161a2a"), "min": 160.0, "max": 380.0},
		{"kind": "buildings", "depth": 0.45, "seed": 13, "color": Color("0d1019"), "min": 90.0, "max": 260.0},
	]
	for spec in layers:
		var layer := Skyline.new()
		layer.kind = spec.kind
		layer.depth = spec.depth
		layer.seed_value = spec.seed
		layer.base_y = floor_y
		layer.from_x = -800.0
		layer.to_x = width * spec.depth + 800.0
		if spec.has("color"):
			layer.color = spec.color
			layer.min_height = spec.min
			layer.max_height = spec.max
		add_child(layer)
		_backdrop_layers.append(layer)


func _process(_delta: float) -> void:
	if _backdrop_layers.is_empty():
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var center_x := camera.get_screen_center_position().x
	for layer in _backdrop_layers:
		layer.position.x = center_x * (1.0 - layer.depth)


func refresh_state(instant: bool = false) -> void:
	for ghost in ghosts:
		ghost.visible = GameState.check(ghost.placement.get("visible_if", ""))
	for prop in _props:
		prop.visible = GameState.check(prop.data.get("visible_if", ""))
		if prop.data.has("lit_if"):
			var target := 1.0 if GameState.check(prop.data.get("lit_if", "")) else 0.0
			if instant:
				prop.lit = target
			elif not is_equal_approx(prop.lit, target):
				create_tween().tween_property(prop, "lit", target, LIGHT_FADE_SECONDS)


## The first "ambient" entry whose condition passes tints the whole room.
func ambient_color() -> Color:
	for entry in data.get("ambient", []):
		if GameState.check(entry.get("if", "")):
			return _color(entry.get("color"), Color.WHITE)
	return Color.WHITE


static func _color(value, fallback: Color) -> Color:
	if typeof(value) == TYPE_STRING and Color.html_is_valid(value):
		return Color.html(value)
	return fallback


func _add_dust() -> void:
	var dust := CPUParticles2D.new()
	dust.amount = int(width / 25.0)
	dust.lifetime = 10.0
	dust.preprocess = 10.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(width / 2.0, floor_y / 2.0)
	dust.position = Vector2(width / 2.0, floor_y / 2.0)
	dust.direction = Vector2(1, -0.2)
	dust.spread = 180.0
	dust.gravity = Vector2(0, 2)
	dust.initial_velocity_min = 2.0
	dust.initial_velocity_max = 10.0
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 3.5
	dust.color = Color(1, 0.95, 0.85, 0.3)
	dust.z_index = 6
	add_child(dust)


# Drawn wider and taller than the room so wide or tall screens never see past the edges.
func _draw() -> void:
	if style == "street":
		_draw_street()
	else:
		_draw_interior()


func _draw_street() -> void:
	var left := -400.0
	var full := width + 800.0
	Prop.draw_gradient_rect(self, Rect2(left, -400, full, floor_y + 400), Color("04060d"), Color("23213a"))
	# Cobblestones, rows getting taller toward the viewer.
	draw_rect(Rect2(left, floor_y, full, ROOM_HEIGHT - floor_y + 400), _floor.darkened(0.35))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(scene_id)
	var y := floor_y + 4
	var row_h := 12.0
	while y < ROOM_HEIGHT + 40:
		var x := left - rng.randf_range(0, 30)
		while x < left + full:
			var w := rng.randf_range(1.6, 2.6) * row_h
			draw_rect(Rect2(x + 2, y + 2, w - 4, row_h - 3), _floor.darkened(rng.randf_range(0.0, 0.25)))
			x += w
		y += row_h
		row_h *= 1.3
	# Kerb along the street's edge.
	draw_rect(Rect2(left, floor_y - 6, full, 10), _floor.lightened(0.1))


func _draw_interior() -> void:
	var left := -400.0
	var full := width + 800.0
	Prop.draw_gradient_rect(self, Rect2(left, -400, full, floor_y + 400), _wall.darkened(0.55), _wall)

	# Brick courses.
	var mortar := _wall.darkened(0.2)
	var y := 40.0
	var row := 0
	while y < floor_y - 120:
		draw_line(Vector2(left, y), Vector2(left + full, y), mortar, 2)
		var x := left + (row % 2) * 60.0
		while x < left + full:
			draw_line(Vector2(x, y), Vector2(x, y + 44), mortar, 2)
			x += 120.0
		y += 44.0
		row += 1

	# Damp stains and cracks, the same every visit.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(scene_id)
	for _i in int(width / 300.0):
		var stain := Vector2(rng.randf_range(0, width), rng.randf_range(60, floor_y - 160))
		var radius := rng.randf_range(40, 120)
		for k in 5:  # stacked faint circles give a soft edge
			draw_circle(stain, radius * (1.0 - k * 0.18), Color(0, 0, 0, 0.018))
	for _i in int(width / 500.0):
		var crack := PackedVector2Array([Vector2(rng.randf_range(0, width), rng.randf_range(40, 200))])
		for k in 6:
			crack.append(crack[k] + Vector2(rng.randf_range(-14, 14), rng.randf_range(12, 30)))
		draw_polyline(crack, _wall.darkened(0.5), 2)

	# Ceiling beam.
	draw_rect(Rect2(left, -400, full, 436), _trim.darkened(0.45))

	# Wainscot panels.
	var wainscot_top := floor_y - 110
	draw_rect(Rect2(left, wainscot_top, full, 110), _trim)
	draw_rect(Rect2(left, wainscot_top, full, 8), _trim.lightened(0.15))
	var px := 0.0
	while px < width:
		draw_rect(Rect2(px + 14, wainscot_top + 22, 112, 70), _trim.darkened(0.15), false, 2)
		px += 140.0

	# Floorboards, spaced wider toward the viewer for a hint of depth.
	draw_rect(Rect2(left, floor_y, full, ROOM_HEIGHT - floor_y + 400), _floor)
	draw_line(Vector2(left, floor_y), Vector2(left + full, floor_y), _floor.lightened(0.2), 3)
	var board_y := floor_y
	var gap := 14.0
	var seam_row := 0
	while board_y < ROOM_HEIGHT + 60:
		board_y += gap
		draw_line(Vector2(left, board_y), Vector2(left + full, board_y), _floor.darkened(0.3), 2)
		var sx := fmod(seam_row * 97.0, 260.0)
		while sx < width:
			draw_line(Vector2(sx, board_y - gap), Vector2(sx, board_y), _floor.darkened(0.3), 2)
			sx += 260.0
		gap *= 1.35
		seam_row += 1

extends Node2D
## The title screen's scene: a dead city under the stars, one lit window high in the guildhall
## where someone is waiting, and the explorer with a lantern on the street. Fits any screen size.

const Skyline := preload("res://scripts/world/skyline.gd")
const Player := preload("res://scripts/world/player.gd")
const Prop := preload("res://scripts/world/prop.gd")
const Lighting := preload("res://scripts/world/lighting.gd")

const WARM := Color("ffcf7a")

var _layers: Array = []
var _tower: Node2D
var _window_light: PointLight2D
var _player: Node2D
var _dust: CPUParticles2D
var _ground_y := 600.0
var _time := 0.0


func _ready() -> void:
	var darkness := CanvasModulate.new()
	darkness.color = Color("7f88ac")
	add_child(darkness)

	var specs := [
		{"kind": "sky", "seed": 21},
		{"kind": "buildings", "seed": 22, "color": Color("161a2a"), "min": 200.0, "max": 420.0},
		{"kind": "buildings", "seed": 23, "color": Color("0d1019"), "min": 100.0, "max": 280.0},
	]
	for spec in specs:
		var layer := Skyline.new()
		layer.kind = spec.kind
		layer.seed_value = spec.seed
		if spec.has("color"):
			layer.color = spec.color
			layer.min_height = spec.min
			layer.max_height = spec.max
		add_child(layer)
		_layers.append(layer)

	_tower = Node2D.new()
	_tower.draw.connect(_draw_tower)
	add_child(_tower)
	_window_light = Lighting.make_light(WARM, 160.0, 1.2)
	_tower.add_child(_window_light)

	_player = Player.new()
	add_child(_player)

	_dust = CPUParticles2D.new()
	_dust.amount = 70
	_dust.lifetime = 12.0
	_dust.preprocess = 12.0
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.direction = Vector2(1, -0.1)
	_dust.spread = 180.0
	_dust.gravity = Vector2(0, 1)
	_dust.initial_velocity_min = 3.0
	_dust.initial_velocity_max = 12.0
	_dust.scale_amount_min = 1.5
	_dust.scale_amount_max = 3.0
	_dust.color = Color(1, 0.95, 0.85, 0.3)
	add_child(_dust)

	get_viewport().size_changed.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	_time += delta
	_window_light.energy = 1.2 + sin(_time * 2.1) * 0.15 + sin(_time * 5.3) * 0.05


func _layout() -> void:
	var size := get_viewport_rect().size
	_ground_y = size.y - 120.0
	for layer in _layers:
		layer.from_x = -60.0
		layer.to_x = size.x + 60.0
		layer.base_y = _ground_y
		layer.queue_redraw()
	# Tower on the right, clear of the menu; the explorer stands looking up at it.
	_tower.position = Vector2(size.x * 0.84, _ground_y)
	_window_light.position = Vector2(0, -372)
	_player.position = Vector2(size.x * 0.64, _ground_y + 70.0)
	_player.min_x = _player.position.x
	_player.max_x = _player.position.x
	_player.face_toward(_tower.position.x)
	_dust.position = Vector2(size.x / 2.0, size.y / 2.0)
	_dust.emission_rect_extents = size / 2.0
	queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	Prop.draw_gradient_rect(self, Rect2(0, 0, size.x, _ground_y), Color("04060d"), Color("23213a"))
	draw_rect(Rect2(0, _ground_y, size.x, size.y - _ground_y), Color("1e1e26"))
	var row_y := _ground_y + 4.0
	var row_h := 12.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	while row_y < size.y:
		var x := -rng.randf_range(0, 30)
		while x < size.x:
			var w := rng.randf_range(1.6, 2.6) * row_h
			draw_rect(Rect2(x + 2, row_y + 2, w - 4, row_h - 3), Color("2a2a34").darkened(rng.randf_range(0.0, 0.3)))
			x += w
		row_y += row_h
		row_h *= 1.3


# The guildhall's bell tower, darker than the rooftops, with the one window still lit.
func _draw_tower() -> void:
	var dark := Color("07090f")
	_tower.draw_rect(Rect2(-70, -300, 140, 300), dark)
	_tower.draw_rect(Rect2(-48, -420, 96, 130), dark)
	_tower.draw_colored_polygon(PackedVector2Array([Vector2(-60, -420), Vector2(0, -520), Vector2(60, -420)]), dark)
	_tower.draw_rect(Rect2(-130, -160, 260, 160), dark)
	for k in 4:
		_tower.draw_circle(Vector2(0, -372), 14.0 + k * 10.0, Color(WARM, 0.05))
	_tower.draw_rect(Rect2(-9, -388, 18, 30), WARM)

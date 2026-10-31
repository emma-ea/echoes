extends Node2D
## The playable world: the current room, the explorer, the camera, ambient light and hotspot markers.
## Tap or click to walk; tap an object to walk over and use it. Keys: A/D or arrows, E or Space.

signal interact_requested(hotspot: Dictionary)

const Room := preload("res://scripts/world/room.gd")
const Player := preload("res://scripts/world/player.gd")
const HotspotMarker := preload("res://scripts/world/hotspot_marker.gd")
const TapRipple := preload("res://scripts/world/tap_ripple.gd")

const INTERACT_RANGE := 120.0
const NPC_TALK_DISTANCE := 95.0
const AMBIENT_FADE_SECONDS := 2.5

var input_enabled := true
var room: Room
var player: Player
var current_scene_id := ""

var _camera: Camera2D
var _ambient: CanvasModulate
var _marker_layer: CanvasLayer
var _markers: Array = []
var _pending: Dictionary = {}  # hotspot to use when the explorer arrives


func _ready() -> void:
	_ensure_input_actions()
	_ambient = CanvasModulate.new()
	add_child(_ambient)

	player = Player.new()
	player.z_index = 2
	player.arrived.connect(_on_player_arrived)
	add_child(player)

	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 5.0
	player.add_child(_camera)
	_camera.make_current()

	# Markers live on their own layer that follows the camera, so the room's darkness doesn't dim them.
	_marker_layer = CanvasLayer.new()
	_marker_layer.layer = 1
	_marker_layer.follow_viewport_enabled = true
	add_child(_marker_layer)


## arrive_x < 0 means "use the room's spawn_x".
func load_room(scene_id: String, arrive_x: float = -1.0) -> void:
	if room:
		remove_child(room)
		room.queue_free()
	for marker in _markers:
		marker.queue_free()
	_markers.clear()

	current_scene_id = scene_id
	room = Room.new()
	add_child(room)
	move_child(room, 0)
	room.setup(scene_id)

	player.min_x = room.walk_min
	player.max_x = room.walk_max
	player.position = Vector2(arrive_x if arrive_x >= 0.0 else room.spawn_x, room.floor_y)
	player.stop()
	_pending = {}

	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(room.width)
	_camera.limit_bottom = int(Room.ROOM_HEIGHT)
	_camera.force_update_scroll()
	_camera.reset_smoothing()

	for hotspot in room.data.get("hotspots", []):
		var marker := HotspotMarker.new()
		marker.setup(hotspot)
		_marker_layer.add_child(marker)
		_markers.append(marker)

	_ambient.color = room.ambient_color()
	refresh_state()


## Re-applies flags and progress to the current room without rebuilding it.
func refresh_state() -> void:
	if room == null:
		return
	room.refresh_state()
	for marker in _markers:
		var hotspot: Dictionary = marker.hotspot
		marker.visible = GameState.check(hotspot.get("visible_if", ""))
		marker.seen = _is_done(hotspot)
	var target := room.ambient_color()
	if not _ambient.color.is_equal_approx(target):
		create_tween().tween_property(_ambient, "color", target, AMBIENT_FADE_SECONDS)


func walk_to_hotspot(hotspot: Dictionary) -> void:
	_pending = hotspot
	player.walk_to(stand_x(hotspot))


## Where the explorer stands to use a hotspot: its "stand_x", else the middle of its rect.
## For NPCs: a step away from them, on whichever side the explorer is coming from.
func stand_x(hotspot: Dictionary) -> float:
	if hotspot.has("npc_x"):
		var npc_x := float(hotspot.npc_x)
		var side := 1.0 if player.position.x > npc_x else -1.0
		return clampf(npc_x + side * NPC_TALK_DISTANCE, room.walk_min, room.walk_max)
	var rect: Array = hotspot.get("rect", [0, 0, 0, 0])
	var x := float(hotspot.get("stand_x", rect[0] + rect[2] / 2.0))
	return clampf(x, room.walk_min, room.walk_max)


func _process(_delta: float) -> void:
	if room == null:
		return
	var axis := Input.get_axis("move_left", "move_right") if input_enabled else 0.0
	player.manual_axis = axis
	if axis != 0.0:
		_pending = {}
	for ghost in room.ghosts:
		ghost.watch_x = player.position.x
	_check_triggers()
	var nearest = _nearest_marker()
	for marker in _markers:
		marker.near = input_enabled and marker == nearest  # no labels behind open dialogs


# Walking into a trigger's x range sets its flags (e.g. the tutorial's "you've walked the street").
func _check_triggers() -> void:
	for trigger in room.data.get("triggers", []):
		var span: Array = trigger.get("x", [0, 0])
		if player.position.x < float(span[0]) or player.position.x > float(span[1]):
			continue
		var to_set: Array = trigger.get("set_flags", [])
		if not to_set.all(func(flag): return GameState.flags.has(flag)):
			GameState.set_flags(to_set)


## Brightens (or dims) the NPC while a conversation with them is open.
func set_talking(npc_id: String, value: bool) -> void:
	if room == null:
		return
	for ghost in room.ghosts:
		if ghost.npc_id == npc_id:
			ghost.talking = value


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or room == null:
		return
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_tap(get_global_mouse_position())
	elif event.is_action_pressed("interact"):
		var marker = _nearest_marker()
		if marker:
			get_viewport().set_input_as_handled()
			_interact_now(marker.hotspot)


func _tap(point: Vector2) -> void:
	var marker = _marker_at(point)
	var target_x: float = stand_x(marker.hotspot) if marker else clampf(point.x, room.walk_min, room.walk_max)
	var ripple := TapRipple.new()
	ripple.position = Vector2(target_x, room.floor_y)
	_marker_layer.add_child(ripple)
	if marker:
		walk_to_hotspot(marker.hotspot)
	else:
		_pending = {}
		player.walk_to(target_x)


func _on_player_arrived() -> void:
	if not _pending.is_empty():
		_interact_now(_pending)


func _interact_now(hotspot: Dictionary) -> void:
	_pending = {}
	player.stop()
	var rect: Array = hotspot.get("rect", [0, 0, 0, 0])
	player.face_toward(rect[0] + rect[2] / 2.0)
	interact_requested.emit(hotspot)


# Smallest visible hotspot under the point, so a small object in front of a big one wins.
func _marker_at(point: Vector2):
	var best = null
	var best_area := INF
	for marker in _markers:
		if not marker.visible:
			continue
		var r: Array = marker.hotspot.get("rect", [0, 0, 0, 0])
		var rect := Rect2(r[0], r[1], r[2], r[3])
		if rect.has_point(point) and rect.get_area() < best_area:
			best = marker
			best_area = rect.get_area()
	return best


func _nearest_marker():
	var best = null
	var best_distance := INTERACT_RANGE
	for marker in _markers:
		if not marker.visible:
			continue
		var distance := absf(stand_x(marker.hotspot) - player.position.x)
		if distance < best_distance:
			best = marker
			best_distance = distance
	return best


func _is_done(hotspot: Dictionary) -> bool:
	match hotspot.get("action", ""):
		"echo": return GameState.has_echo(hotspot.get("echo", ""))
		"puzzle": return GameState.is_puzzle_solved(hotspot.get("puzzle", ""))
	return false


static func _ensure_input_actions() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E, KEY_SPACE, KEY_ENTER],
	}
	for action in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

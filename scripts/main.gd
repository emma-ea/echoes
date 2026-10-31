extends Node
## Root of the game: the walkable world, plus a UI layer with the HUD, modal overlays,
## a toast for short messages and a fade for room transitions.
## Routes interactions to the right overlay; all game rules live in GameState.

const World := preload("res://scripts/world/world.gd")
const EchoPopup := preload("res://scripts/ui/echo_popup.gd")
const ChronicleBoard := preload("res://scripts/ui/chronicle_board.gd")
const DialogueBox := preload("res://scripts/ui/dialogue_box.gd")
const PUZZLE_SCREENS := {
	"dial_code": preload("res://scripts/ui/dial_puzzle.gd"),
}

const TOAST_SECONDS := 3.5
const FADE_SECONDS := 0.3

var world: World

var _ui: Control
var _location_label: Label
var _chronicle_button: Button
var _music_button: Button
var _overlays: Control
var _toast: Label
var _toast_tween: Tween
var _fade: ColorRect
var _transitioning := false
var _arrival_x := -1.0


func _ready() -> void:
	get_tree().set_quit_on_go_back(false)

	world = World.new()
	world.interact_requested.connect(_interact)
	add_child(world)

	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.theme = Theme.new()
	_ui.theme.default_font_size = 26
	ui_layer.add_child(_ui)

	_build_hud()

	_overlays = Control.new()
	_overlays.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_overlays)

	_build_toast()

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_fade)

	GameState.changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	world.input_enabled = _overlays.get_child_count() == 0 and not _transitioning


func _refresh() -> void:
	if world.current_scene_id != GameState.current_scene:
		world.load_room(GameState.current_scene, _arrival_x)
		_arrival_x = -1.0
	else:
		world.refresh_state()
	_location_label.text = ContentDB.scenes.get(GameState.current_scene, {}).get("name", "")
	_chronicle_button.text = "Chronicle (%d)" % GameState.echoes.size()


## Called when the explorer reaches a hotspot (or presses interact next to one).
func _interact(hotspot: Dictionary) -> void:
	if not GameState.check(hotspot.get("requires", "")):
		show_toast(GameState.format_text(hotspot.get("locked_text", "Not yet.")))
		return
	match hotspot.get("action", ""):
		"echo":
			var echo_id: String = hotspot.get("echo", "")
			var is_new: bool = GameState.collect_echo(echo_id)
			_open_echo(echo_id, is_new)
		"goto":
			_go_through(hotspot)
		"puzzle":
			var puzzle_id: String = hotspot.get("puzzle", "")
			var puzzle: Dictionary = ContentDB.puzzles[puzzle_id]
			if GameState.is_puzzle_solved(puzzle_id):
				show_toast(GameState.format_text(puzzle.get("solved_text", "")))
			else:
				var screen = PUZZLE_SCREENS[puzzle.get("type", "")].new()
				_open_modal(screen)
				screen.setup(puzzle_id)
		"examine":
			show_toast(GameState.format_text(hotspot.get("text", "")))
		"talk":
			_open_dialogue(hotspot.get("npc", ""))


func _go_through(hotspot: Dictionary) -> void:
	if _transitioning:
		return
	_transitioning = true
	_arrival_x = float(hotspot.get("arrive_x", -1.0))
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_SECONDS)
	tween.tween_callback(GameState.go_to.bind(str(hotspot.get("target", ""))))
	tween.tween_property(_fade, "color:a", 0.0, FADE_SECONDS)
	tween.tween_callback(_end_transition)


func _end_transition() -> void:
	_transitioning = false


func _open_echo(echo_id: String, is_new: bool) -> void:
	var popup := EchoPopup.new()
	_open_modal(popup)
	popup.setup(echo_id, is_new)


func _open_dialogue(npc_id: String) -> void:
	var box := DialogueBox.new()
	_open_modal(box)
	world.set_talking(npc_id, true)
	box.tree_exiting.connect(world.set_talking.bind(npc_id, false))
	box.setup(npc_id)


func _open_chronicle() -> void:
	var board := ChronicleBoard.new()
	board.echo_requested.connect(_open_echo.bind(false))
	_open_modal(board)


func _open_modal(modal: Control) -> void:
	_overlays.add_child(modal)


func _close_all_modals() -> void:
	for child in _overlays.get_children():
		_overlays.remove_child(child)
		child.queue_free()


func _start_new_run() -> void:
	_close_all_modals()
	world.current_scene_id = ""  # force the room (and the explorer) to reset
	GameState.new_game()
	show_toast("A new run begins. The mystery's details have changed.")


func show_toast(text: String) -> void:
	if text.is_empty():
		return
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast.show()
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(_toast.hide)


func _build_hud() -> void:
	var bar := MarginContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top"]:
		bar.add_theme_constant_override("margin_" + side, 24)
	_ui.add_child(bar)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	bar.add_child(row)

	_location_label = Label.new()
	_location_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_location_label.add_theme_constant_override("outline_size", 8)
	_location_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	row.add_child(_location_label)

	# Buttons don't take keyboard focus, so Space/Enter stay free for interacting.
	_chronicle_button = Button.new()
	_chronicle_button.custom_minimum_size = Vector2(240, 64)
	_chronicle_button.focus_mode = Control.FOCUS_NONE
	_chronicle_button.pressed.connect(_open_chronicle)
	row.add_child(_chronicle_button)

	# Playtest helper: rerolls the run seed so you can see the randomised details change.
	var new_run := Button.new()
	new_run.text = "New run"
	new_run.custom_minimum_size = Vector2(160, 64)
	new_run.focus_mode = Control.FOCUS_NONE
	new_run.pressed.connect(_start_new_run)
	row.add_child(new_run)

	_music_button = Button.new()
	_music_button.custom_minimum_size = Vector2(200, 64)
	_music_button.focus_mode = Control.FOCUS_NONE
	_music_button.pressed.connect(_toggle_music)
	row.add_child(_music_button)
	_update_music_button()


func _toggle_music() -> void:
	Music.set_enabled(not Music.enabled)
	_update_music_button()


func _update_music_button() -> void:
	_music_button.text = "Music: On" if Music.enabled else "Music: Off"


func _build_toast() -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	holder.offset_top = -220
	holder.offset_bottom = -24
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(holder)

	_toast = Label.new()
	_toast.custom_minimum_size = Vector2(900, 0)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.set_content_margin_all(20)
	style.set_corner_radius_all(12)
	_toast.add_theme_stylebox_override("normal", style)
	_toast.hide()
	holder.add_child(_toast)

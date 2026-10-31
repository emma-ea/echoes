extends Node
## Root of the game: the walkable world, plus a UI layer with the HUD (location, current objective,
## tutorial tips), modal overlays, a toast for short messages and a fade for room transitions.
## Routes interactions to the right overlay; all game rules live in GameState.

const World := preload("res://scripts/world/world.gd")
const EchoPopup := preload("res://scripts/ui/echo_popup.gd")
const ChronicleBoard := preload("res://scripts/ui/chronicle_board.gd")
const DialogueBox := preload("res://scripts/ui/dialogue_box.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const Fonts := preload("res://scripts/ui/fonts.gd")
const PUZZLE_SCREENS := {
	"dial_code": preload("res://scripts/ui/dial_puzzle.gd"),
}

const TOAST_SECONDS := 3.5
const FADE_SECONDS := 0.3
const OBJECTIVE_COLOR := Color(1.0, 0.85, 0.55)

var world: World

var _ui: Control
var _location_label: Label
var _objective_label: Label
var _chronicle_button: Button
var _tip_card: PanelContainer
var _tip_label: Label
var _overlays: Control
var _toast: Label
var _toast_tween: Tween
var _fade: ColorRect
var _transitioning := false
var _arrival_x := -1.0
var _step_id := ""
var _tip_dismissed := false
var _highlight_chronicle := false
var _time := 0.0


func _ready() -> void:
	get_tree().set_quit_on_go_back(false)
	Music.set_override("")

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
	_build_tip_card()

	_overlays = Control.new()
	_overlays.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_overlays)

	_build_toast()

	# Starts black and fades in, so arriving from the title or the intro is smooth.
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.8)

	GameState.changed.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	_time += delta
	world.input_enabled = _overlays.get_child_count() == 0 and not _transitioning
	# Gently pulse the Chronicle button while the tutorial is pointing at it.
	var pulse := 0.5 + 0.5 * sin(_time * 4.0) if _highlight_chronicle else 0.0
	_chronicle_button.modulate = Color.WHITE.lerp(Color(1.5, 1.25, 0.7), pulse)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _overlays.get_child_count() == 0 and not _transitioning:
		get_viewport().set_input_as_handled()
		_open_pause()


func _notification(what: int) -> void:
	# Android back with nothing open pauses; open dialogs close themselves instead.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _overlays and _overlays.get_child_count() == 0:
		call_deferred("_open_pause")


func _refresh() -> void:
	if world.current_scene_id != GameState.current_scene:
		world.load_room(GameState.current_scene, _arrival_x)
		_arrival_x = -1.0
	else:
		world.refresh_state()
	_location_label.text = ContentDB.scenes.get(GameState.current_scene, {}).get("name", "")
	_chronicle_button.text = "Chronicle (%d)" % GameState.echoes.size()
	_update_objective()


func _update_objective() -> void:
	var step := GameState.current_step()
	var step_id: String = step.get("id", "")
	_objective_label.text = step.get("objective", "")
	if step_id != _step_id:
		var first := _step_id.is_empty()
		_step_id = step_id
		_tip_dismissed = false
		if not first:  # a new objective: flash it so the player notices
			_objective_label.modulate = Color(2.2, 2.0, 1.4)
			create_tween().tween_property(_objective_label, "modulate", OBJECTIVE_COLOR, 1.2)
	var tip: String = step.get("tip", "")
	_tip_label.text = tip
	_tip_card.visible = not tip.is_empty() and not _tip_dismissed
	_highlight_chronicle = step.get("highlight", "") == "chronicle"


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
	GameState.set_flags(["opened_chronicle"])
	var board := ChronicleBoard.new()
	board.echo_requested.connect(_open_echo.bind(false))
	_open_modal(board)


func _open_pause() -> void:
	if _overlays.get_child_count() == 0:
		_open_modal(PauseMenu.new())


func _open_modal(modal: Control) -> void:
	_overlays.add_child(modal)


func _close_all_modals() -> void:
	for child in _overlays.get_children():
		_overlays.remove_child(child)
		child.queue_free()


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

	var left := VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 2)
	row.add_child(left)
	_location_label = _outlined_label(28)
	_location_label.add_theme_font_override("font", Fonts.DISPLAY)
	left.add_child(_location_label)
	_objective_label = _outlined_label(22)
	_objective_label.modulate = OBJECTIVE_COLOR
	left.add_child(_objective_label)

	# Buttons don't take keyboard focus, so Space/Enter stay free for interacting.
	_chronicle_button = Button.new()
	_chronicle_button.custom_minimum_size = Vector2(240, 64)
	_chronicle_button.focus_mode = Control.FOCUS_NONE
	_chronicle_button.pressed.connect(_open_chronicle)
	row.add_child(_chronicle_button)

	var menu := Button.new()
	menu.text = "Menu"
	menu.custom_minimum_size = Vector2(140, 64)
	menu.focus_mode = Control.FOCUS_NONE
	menu.pressed.connect(_open_pause)
	row.add_child(menu)


func _outlined_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	return label


func _build_tip_card() -> void:
	_tip_card = PanelContainer.new()
	_tip_card.position = Vector2(24, 128)
	_tip_card.custom_minimum_size = Vector2(500, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.1, 0.88)
	style.border_color = Color(1.0, 0.85, 0.55, 0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(18)
	_tip_card.add_theme_stylebox_override("panel", style)
	_ui.add_child(_tip_card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_tip_card.add_child(box)
	var heading := Label.new()
	heading.text = "TIP"
	heading.add_theme_font_size_override("font_size", 16)
	heading.modulate = OBJECTIVE_COLOR
	box.add_child(heading)
	_tip_label = Label.new()
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.add_theme_font_size_override("font_size", 23)
	box.add_child(_tip_label)
	var got_it := Button.new()
	got_it.text = "Got it"
	got_it.focus_mode = Control.FOCUS_NONE
	got_it.size_flags_horizontal = Control.SIZE_SHRINK_END
	got_it.add_theme_font_size_override("font_size", 20)
	got_it.pressed.connect(func():
		_tip_dismissed = true
		_tip_card.hide()
	)
	box.add_child(got_it)


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

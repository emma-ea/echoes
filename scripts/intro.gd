extends Control
## The opening narration before a new game: lines fade in one at a time on black.
## Tap (or Space/Enter) to continue, Skip or Esc to jump straight into the game.

signal finished

const GAME_SCENE := "res://scenes/main.tscn"
const FADE_IN_SECONDS := 1.2
const Fonts := preload("res://scripts/ui/fonts.gd")

var change_scene_on_finish := true  # the smoke test turns this off

var _lines: Array = []
var _index := -1
var _label: Label
var _tween: Tween
var _done := false


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	theme = Theme.new()
	theme.default_font_size = 26

	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(PRESET_FULL_RECT)
	black.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(black)

	_label = Label.new()
	_label.set_anchors_preset(PRESET_FULL_RECT)
	_label.offset_left = 180
	_label.offset_right = -180
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 40)
	_label.add_theme_font_override("font", Fonts.DISPLAY_ITALIC)
	_label.add_theme_color_override("font_color", Color("e2dccd"))
	add_child(_label)

	var hint := Label.new()
	hint.text = "Tap to continue"
	hint.add_theme_font_size_override("font_size", 18)
	hint.modulate = Color(1, 1, 1, 0.4)
	hint.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	hint.position -= Vector2(40, 32)
	hint.grow_horizontal = GROW_DIRECTION_BEGIN
	add_child(hint)

	var skip := Button.new()
	skip.text = "Skip"
	skip.focus_mode = FOCUS_NONE
	skip.custom_minimum_size = Vector2(120, 56)
	skip.set_anchors_preset(PRESET_TOP_RIGHT)
	skip.position = Vector2(-150, 24)
	skip.pressed.connect(finish)
	add_child(skip)

	_lines = ContentDB.intro
	advance()


## Shows the current line in full if it's still fading in, else moves to the next line.
func advance() -> void:
	if _done:
		return
	if _tween and _tween.is_running():
		_tween.kill()
		_label.modulate.a = 1.0
		return
	_index += 1
	if _index >= _lines.size():
		finish()
		return
	_label.text = str(_lines[_index])
	_label.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 1.0, FADE_IN_SECONDS)


func finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	if change_scene_on_finish:
		var tween := create_tween()
		tween.tween_property(_label, "modulate:a", 0.0, 0.6)
		tween.tween_callback(get_tree().change_scene_to_file.bind(GAME_SCENE))


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		advance()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		advance()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		finish()

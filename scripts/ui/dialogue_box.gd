extends Control
## A conversation with an NPC. Lines type out one at a time (tap, E or Space to continue),
## then the player's choices appear. Branching and effects come from GameState.
## Sits at the top of the screen so the explorer and the NPC stay visible below.

signal closed

const CHARS_PER_SECOND := 50.0

var _dialogue_id := ""
var _node: Dictionary = {}
var _line_index := 0
var _typing := false
var _tween: Tween

var _panel: PanelContainer
var _name_label: Label
var _text_label: Label
var _choices: VBoxContainer
var _continue_hint: Label


func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(PRESET_TOP_WIDE)
	_panel.offset_left = 120
	_panel.offset_right = -120
	_panel.offset_top = 104
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.92)
	style.border_color = Color(0.6, 0.75, 0.9, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	box.add_child(_name_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(0, 100)
	box.add_child(_text_label)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 10)
	box.add_child(_choices)

	_continue_hint = Label.new()
	_continue_hint.text = "Tap to continue"
	_continue_hint.add_theme_font_size_override("font_size", 18)
	_continue_hint.modulate = Color(1, 1, 1, 0.55)
	_continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_continue_hint)


func setup(npc_id: String) -> void:
	var npc: Dictionary = ContentDB.npcs.get(npc_id, {})
	_dialogue_id = npc.get("dialogue", "")
	_name_label.text = npc.get("name", npc_id)
	if Color.html_is_valid(str(npc.get("color", ""))):
		_name_label.add_theme_color_override("font_color", Color.html(npc.color))
	_go_to("start")


func close() -> void:
	closed.emit()
	queue_free()


func is_showing_choices() -> bool:
	return _choices.get_child_count() > 0


## Tap / E / Space: finish the current line, else move to the next line or node.
func advance() -> void:
	if _typing:
		if _tween:
			_tween.kill()
		_line_finished()
		return
	if is_showing_choices():
		return
	var lines: Array = _node.get("lines", [])
	if _line_index < lines.size() - 1:
		_line_index += 1
		_show_line()
	else:
		_go_to(str(_node.get("next", "")))


func choose(index: int) -> void:
	var choices: Array = GameState.available_choices(_node)
	if index >= 0 and index < choices.size():
		_go_to(str(choices[index].get("goto", "")))


func _go_to(node_id: String) -> void:
	_node = GameState.resolve_dialogue(_dialogue_id, node_id)
	if _node.is_empty():
		close()
		return
	GameState.enter_dialogue_node(_node)
	_line_index = 0
	_show_line()


func _show_line() -> void:
	_clear_choices()
	var lines: Array = _node.get("lines", [])
	if lines.is_empty():
		_line_finished()  # a choices-only node keeps the previous line on screen
		return
	_text_label.text = GameState.format_text(str(lines[_line_index]))
	_text_label.visible_ratio = 0.0
	_continue_hint.visible = false
	_typing = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_text_label, "visible_ratio", 1.0, _text_label.text.length() / CHARS_PER_SECOND)
	_tween.tween_callback(_line_finished)


func _line_finished() -> void:
	_typing = false
	_text_label.visible_ratio = 1.0
	var lines: Array = _node.get("lines", [])
	var choices: Array = GameState.available_choices(_node)
	if _line_index >= lines.size() - 1 and not choices.is_empty():
		_continue_hint.visible = false
		for i in choices.size():
			var button := Button.new()
			button.text = choices[i].get("text", "")
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size = Vector2(0, 60)
			button.pressed.connect(choose.bind(i))
			_choices.add_child(button)
		call_deferred("_focus_first_choice")
	else:
		_continue_hint.visible = true
	# Collapse the height so the panel shrinks to fit (containers only ever grow on their own).
	_panel.set_deferred("offset_bottom", _panel.offset_top)


# Deferred so the buttons exist; skipped if a choice was already made in the meantime.
func _focus_first_choice() -> void:
	if is_showing_choices() and _choices.get_child(0).is_inside_tree():
		_choices.get_child(0).grab_focus()


func _clear_choices() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		advance()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		advance()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and get_index() == get_parent().get_child_count() - 1:
		close()

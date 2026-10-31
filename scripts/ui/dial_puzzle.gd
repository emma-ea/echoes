extends "res://scripts/ui/modal.gd"
## A row of number dials. The answer comes from a run variable, so it differs between runs.

var _puzzle_id := ""
var _min := 0
var _max := 9
var _values: Array[int] = []
var _value_labels: Array[Label] = []
var _feedback: Label


func setup(puzzle_id: String) -> void:
	_puzzle_id = puzzle_id
	var puzzle: Dictionary = ContentDB.puzzles[puzzle_id]
	_min = int(puzzle.get("min", 0))
	_max = int(puzzle.get("max", 9))
	panel.custom_minimum_size = Vector2(760, 0)

	add_label(puzzle.get("title", ""), 34)
	add_label(GameState.format_text(puzzle.get("prompt", "")))

	var dials := HBoxContainer.new()
	dials.alignment = BoxContainer.ALIGNMENT_CENTER
	dials.add_theme_constant_override("separation", 24)
	content.add_child(dials)
	for i in int(puzzle.get("dials", 4)):
		_values.append(_min)
		var column := VBoxContainer.new()
		var up := add_button("+", _turn.bind(i, 1), column)
		up.custom_minimum_size = Vector2(96, 72)
		var value := make_label(str(_min), 48)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		column.add_child(value)
		_value_labels.append(value)
		var down := add_button("-", _turn.bind(i, -1), column)
		down.custom_minimum_size = Vector2(96, 72)
		dials.add_child(column)

	_feedback = add_label("", 20)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	content.add_child(buttons)
	var turn := add_button("Turn the wheel", _try, buttons)
	turn.size_flags_horizontal = SIZE_EXPAND_FILL
	var leave := add_button("Step back", close, buttons)
	leave.size_flags_horizontal = SIZE_EXPAND_FILL


func _turn(index: int, delta: int) -> void:
	_values[index] = wrapi(_values[index] + delta, _min, _max + 1)
	_value_labels[index].text = str(_values[index])
	_feedback.text = ""


func _try() -> void:
	var answer := ""
	for value in _values:
		answer += str(value)
	var puzzle: Dictionary = ContentDB.puzzles[_puzzle_id]
	if not GameState.try_puzzle(_puzzle_id, answer):
		_feedback.text = GameState.format_text(puzzle.get("fail_text", "Nothing happens."))
		return
	clear_content()
	add_label(puzzle.get("title", ""), 34)
	add_label(GameState.format_text(puzzle.get("solved_text", "")))
	add_button("Continue", close)

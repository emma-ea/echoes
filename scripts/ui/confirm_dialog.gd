extends "res://scripts/ui/modal.gd"
## "Are you sure?" with a confirm and a cancel button. Works while the game is paused.
## Closing it another way (Esc, Android back) calls neither callback.

var _on_confirm: Callable
var _on_cancel: Callable


func setup(message: String, confirm_text: String, on_confirm: Callable, cancel_text := "Cancel", on_cancel := Callable()) -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_on_confirm = on_confirm
	_on_cancel = on_cancel
	panel.custom_minimum_size = Vector2(620, 0)
	add_label(message)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	content.add_child(row)
	var cancel := add_button(cancel_text, _cancel, row)
	cancel.size_flags_horizontal = SIZE_EXPAND_FILL
	var confirm := add_button(confirm_text, _confirm, row)
	confirm.size_flags_horizontal = SIZE_EXPAND_FILL


func _confirm() -> void:
	close()
	_on_confirm.call()


func _cancel() -> void:
	close()
	if _on_cancel.is_valid():
		_on_cancel.call()

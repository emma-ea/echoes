extends Control
## Full-screen dimmed overlay with a centred panel. Subclasses fill `content`.
## Blocks input to the scene underneath; Escape / Android back closes it.

signal closed

const Fonts := preload("res://scripts/ui/fonts.gd")
## Text this size or larger is a heading and uses the display face.
const HEADING_SIZE := 28

var panel: PanelContainer
var content: VBoxContainer


func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)

	panel = PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	panel.add_child(margin)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _notification(what: int) -> void:
	# Android back button: close only the top-most modal.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and get_index() == get_parent().get_child_count() - 1:
		close()


func close() -> void:
	closed.emit()
	queue_free()


func clear_content() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()


static func make_label(text: String, font_size: int = 0) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	if font_size >= HEADING_SIZE:
		label.add_theme_font_override("font", Fonts.DISPLAY)
	return label


func add_label(text: String, font_size: int = 0) -> Label:
	var label := make_label(text, font_size)
	content.add_child(label)
	return label


func add_button(text: String, on_pressed: Callable, parent: Control = null) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 72)
	button.pressed.connect(on_pressed)
	(parent if parent else content).add_child(button)
	return button

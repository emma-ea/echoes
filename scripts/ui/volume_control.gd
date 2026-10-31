extends HBoxContainer
## Music volume, 1 to 5: tap - / + or tap a bar to jump to that level. Saves as it changes.

const BAR_ON := Color(1.0, 0.85, 0.55)
const BAR_OFF := Color(1, 1, 1, 0.18)

var _bars: Array[Button] = []
var _value_label: Label
var _style_on := _bar_style(BAR_ON)
var _style_off := _bar_style(BAR_OFF)


func _init() -> void:
	add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = "Music volume"
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(label)

	_add_step_button("-", -1)
	# Bars grow taller with each level, like a phone's volume indicator.
	for level in range(Music.MIN_VOLUME, Music.MAX_VOLUME + 1):
		var bar := Button.new()
		bar.custom_minimum_size = Vector2(24, 14 + level * 8)
		bar.size_flags_vertical = SIZE_SHRINK_END
		bar.focus_mode = FOCUS_NONE
		bar.tooltip_text = "Volume %d" % level
		bar.pressed.connect(_set_volume.bind(level))
		add_child(bar)
		_bars.append(bar)
	_add_step_button("+", 1)

	_value_label = Label.new()
	_value_label.custom_minimum_size = Vector2(24, 0)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_value_label)
	_refresh()


func _add_step_button(text: String, delta: int) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(56, 56)
	button.pressed.connect(func(): _set_volume(Music.volume + delta))
	add_child(button)


func _set_volume(level: int) -> void:
	Music.set_volume(level)
	_refresh()


func _refresh() -> void:
	for i in _bars.size():
		var style := _style_on if i < Music.volume else _style_off
		for state in ["normal", "hover", "pressed", "focus"]:
			_bars[i].add_theme_stylebox_override(state, style)
	_value_label.text = str(Music.volume)


static func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	return style

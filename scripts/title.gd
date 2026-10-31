extends Node
## Title screen and main menu: Continue (when there's a saved run), New Game, Music, Quit.

const TitleBackdrop := preload("res://scripts/title_backdrop.gd")
const ConfirmDialog := preload("res://scripts/ui/confirm_dialog.gd")
const BuildInfo := preload("res://scripts/ui/build_info.gd")
const Fonts := preload("res://scripts/ui/fonts.gd")
const GAME_SCENE := "res://scenes/main.tscn"
const INTRO_SCENE := "res://scenes/intro.tscn"

var _ui: Control
var _menu: VBoxContainer
var _music_button: Button
var _dialog: Control


func _ready() -> void:
	get_tree().set_quit_on_go_back(false)
	Music.set_override(ContentDB.title_music)
	add_child(TitleBackdrop.new())

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.theme = Theme.new()
	_ui.theme.default_font_size = 26
	layer.add_child(_ui)

	var column := VBoxContainer.new()
	column.position = Vector2(96, 96)
	column.add_theme_constant_override("separation", 10)
	_ui.add_child(column)

	var title := Label.new()
	title.text = ContentDB.title
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_font_override("font", Fonts.DISPLAY)
	title.add_theme_color_override("font_color", Color("ebe5d6"))
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = ContentDB.subtitle
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_font_override("font", Fonts.DISPLAY_ITALIC)
	subtitle.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	column.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 36)
	column.add_child(spacer)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	column.add_child(_menu)
	if GameState.has_saved_game:
		_add_menu_button("Continue", _continue)
	_add_menu_button("New Game", _new_game)
	_music_button = _add_menu_button("", _toggle_music)
	_update_music_button()
	if not OS.has_feature("mobile"):
		_add_menu_button("Quit", _quit)
	_menu.get_child(0).call_deferred("grab_focus")

	# Which build this is, so playtest feedback can say.
	var build := Label.new()
	build.text = BuildInfo.label()
	build.add_theme_font_size_override("font_size", 18)
	build.modulate = Color(1, 1, 1, 0.45)
	build.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	build.offset_left = -24
	build.offset_right = -24
	build.offset_top = -16
	build.offset_bottom = -16
	build.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	build.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ui.add_child(build)

	_ui.modulate.a = 0.0
	create_tween().tween_property(_ui, "modulate:a", 1.0, 1.5)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not is_instance_valid(_dialog):
		_quit()


func _add_menu_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(340, 62)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN  # don't stretch to the title's width
	button.pressed.connect(on_pressed)
	_menu.add_child(button)
	return button


func _continue() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _new_game() -> void:
	if not GameState.has_saved_game:
		_start_new_game()
		return
	_dialog = ConfirmDialog.new()
	_ui.add_child(_dialog)
	_dialog.setup("Start a new game? Your current progress will be lost.", "Start over", _start_new_game)


func _start_new_game() -> void:
	GameState.new_game()
	get_tree().change_scene_to_file(INTRO_SCENE)


func _toggle_music() -> void:
	Music.set_enabled(not Music.enabled)
	_update_music_button()


func _update_music_button() -> void:
	_music_button.text = "Music: On" if Music.enabled else "Music: Off"


func _quit() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)

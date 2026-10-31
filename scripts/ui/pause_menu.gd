extends "res://scripts/ui/modal.gd"
## In-game menu. Pauses the world while open; Resume, Esc or Android back closes it.

const ConfirmDialog := preload("res://scripts/ui/confirm_dialog.gd")
const VolumeControl := preload("res://scripts/ui/volume_control.gd")
const TITLE_SCENE := "res://scenes/title.tscn"
const INTRO_SCENE := "res://scenes/intro.tscn"

var _music_button: Button


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	get_tree().paused = true
	panel.custom_minimum_size = Vector2(560, 0)
	add_label("Paused", 40)
	var step := GameState.current_step()
	if not step.is_empty():
		var objective := add_label("Objective: " + str(step.get("objective", "")), 22)
		objective.modulate = Color(1.0, 0.85, 0.55)
	add_button("Resume", close)
	_music_button = add_button("", _toggle_music)
	_update_music_button()
	content.add_child(VolumeControl.new())
	add_button("Restart from the beginning", _confirm_restart)
	add_button("Main menu", _to_title)
	if not OS.has_feature("mobile"):
		add_button("Quit game", _quit)
	var saved := add_label("Your progress is saved automatically.", 18)
	saved.modulate = Color(1, 1, 1, 0.5)


func _exit_tree() -> void:
	get_tree().paused = false


func _toggle_music() -> void:
	Music.set_enabled(not Music.enabled)
	_update_music_button()


func _update_music_button() -> void:
	_music_button.text = "Music: On" if Music.enabled else "Music: Off"


func _confirm_restart() -> void:
	var dialog := ConfirmDialog.new()
	get_parent().add_child(dialog)
	dialog.setup("Start over from the very beginning? Your current progress will be lost.", "Start over", func():
		get_tree().paused = false
		GameState.new_game()
		get_tree().change_scene_to_file(INTRO_SCENE)
	)


func _to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


func _quit() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)

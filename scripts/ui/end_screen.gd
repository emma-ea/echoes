extends "res://scripts/ui/modal.gd"
## "End of the demo": shown once when the chapter is finished (world.json "demo_end").
## Players can keep exploring the relit city, leave feedback, or return to the main menu.

const BuildInfo := preload("res://scripts/ui/build_info.gd")
const TITLE_SCENE := "res://scenes/title.tscn"


func _ready() -> void:
	var info: Dictionary = ContentDB.demo_end
	panel.custom_minimum_size = Vector2(760, 0)
	add_label(info.get("title", ""), 44)
	add_label(GameState.format_text(info.get("text", "")))
	var url := str(info.get("feedback_url", ""))
	if not url.is_empty():
		add_button("Share your feedback", func():
			Analytics.track("demo_end:feedback")
			OS.shell_open(url))
	add_button("Keep exploring", func():
		Analytics.track("demo_end:keep_exploring")
		close())
	add_button("Main menu", func():
		Analytics.track("demo_end:main_menu")
		get_tree().change_scene_to_file(TITLE_SCENE))
	var build := add_label(ContentDB.title + "  ·  " + BuildInfo.label(), 18)
	build.modulate = Color(1, 1, 1, 0.5)

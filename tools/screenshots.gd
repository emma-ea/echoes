extends Node
## Renders key moments of the game to PNGs (useful for checking visuals and for store shots).
## Run:  godot --path . res://tools/screenshots.tscn -- --out=/some/folder
## Needs a real window (not --headless). Uses a throwaway save file.

var _out_dir := OS.get_user_data_dir()


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	GameState.save_path = "user://screenshot_save.json"
	GameState.new_game(7)

	var title: Node = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await _shoot("01_title", 120)
	title.queue_free()

	var intro: Node = load("res://scenes/intro.tscn").instantiate()
	intro.change_scene_on_finish = false
	add_child(intro)
	intro.advance()
	intro.advance()  # second line, fully shown
	await _shoot("02_intro")
	intro.queue_free()

	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var world = main.world
	await _shoot("03_street_start", 60)
	world.load_room("street", 1500.0)
	await _shoot("04_street_guildhall")

	GameState.set_flags(["walked_street"])
	GameState.collect_echo("echo_notice")
	GameState.set_flags(["opened_chronicle"])
	main._open_chronicle()
	await _shoot("05_chronicle_summons")
	main._close_all_modals()

	GameState.place_term("the_summons", "who", "pell")
	GameState.place_term("the_summons", "where", "guildhall")
	GameState.try_resolve("the_summons")
	main._arrival_x = 120.0
	GameState.go_to("foyer")
	await _shoot("06_foyer_meet_pell")

	main._open_dialogue("pell")
	main._overlays.get_child(0).advance()
	await _shoot("07_talking_to_pell")
	main._close_all_modals()

	main._open_pause()
	await _shoot("08_pause_menu")
	main._close_all_modals()

	main._arrival_x = 1250.0
	GameState.go_to("watch_office")
	await _shoot("09_watch_office_wren")

	for slot in ["who", "what", "when"]:
		GameState.place_term("lamps_out", slot, ContentDB.events.lamps_out.slots[slot])
	GameState.try_resolve("lamps_out")
	GameState.try_puzzle("valve_dials", GameState.vars.valve_code)
	main._arrival_x = 1000.0
	GameState.go_to("valve_room")
	await _shoot("10_valve_room_lit", 180)
	main._arrival_x = 1500.0
	GameState.go_to("street")
	await _shoot("11_street_lit", 180)

	DirAccess.remove_absolute(GameState.save_path)
	await Music.shut_down()
	get_tree().quit()


func _shoot(shot_name: String, frames: int = 30) -> void:
	for _i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := _out_dir.path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)

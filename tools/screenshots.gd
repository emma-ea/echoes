extends Node
## Renders a few key moments of the slice to PNGs (useful for checking visuals and for store shots).
## Run:  godot --path . res://tools/screenshots.tscn -- --out=/some/folder
## Needs a real window (not --headless). Uses a throwaway save file.

var _out_dir := OS.get_user_data_dir()


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	GameState.save_path = "user://screenshot_save.json"
	GameState.new_game(7)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var world = main.world

	await _shoot("1_foyer_start")
	main._open_dialogue("pell")
	var box = main._overlays.get_child(0)
	box.advance()  # finish typing the first line
	await _shoot("1b_talking_to_pell")
	for _i in 6:
		box.advance()
	await _shoot("1c_pell_choices")
	main._close_all_modals()
	main._arrival_x = 1250.0
	GameState.go_to("watch_office")
	await _shoot("1d_watch_office_wren")
	world.player.position.x = 1480.0
	world.load_room("foyer", 1480.0)  # same room, so just reposition the explorer
	await _shoot("2_foyer_chalk")
	GameState.go_to("valve_room")
	await _shoot("3_valve_room_dark")

	for slot in ["who", "what", "when"]:
		GameState.place_term("lamps_out", slot, ContentDB.events.lamps_out.slots[slot])
	GameState.try_resolve("lamps_out")
	GameState.try_puzzle("valve_dials", GameState.vars.valve_code)
	world.load_room("valve_room", 1000.0)
	await _shoot("4_valve_room_lit")
	main._arrival_x = 1150.0
	GameState.go_to("foyer")
	await _shoot("5_foyer_lit")

	DirAccess.remove_absolute(GameState.save_path)
	await Music.shut_down()
	get_tree().quit()


func _shoot(shot_name: String) -> void:
	for _i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := _out_dir.path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)

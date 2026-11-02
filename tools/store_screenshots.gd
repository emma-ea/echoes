extends Node
## Google Play phone screenshots: eight moments of real gameplay, 1920x1080, into res://store/screenshots
## (or --out=folder). Tutorial tips and the end-of-demo screen are hidden; everything else is the game.
## Run:  godot --path . --resolution 1920x1080 res://tools/store_screenshots.tscn
## Needs a window (not --headless) on a screen big enough for 1920x1080. Uses a throwaway save.

const SIZE := Vector2i(1920, 1080)

var main: Node
var world: Node
var _out_dir := ProjectSettings.globalize_path("res://store/screenshots")


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	if get_window().size != SIZE:
		push_warning("Window is %s, not %s: pass --resolution 1920x1080" % [get_window().size, SIZE])

	GameState.save_path = "user://store_screenshot_save.json"
	GameState.new_game(7)
	GameState.set_flags(["seen_demo_end"])  # the shots below finish the chapter; no end screen over them
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	world = main.world
	main._tip_card.modulate.a = 0.0

	# 1. The dark street, walking up to the notice board.
	world.load_room("street", 560.0)
	await _shoot("1_dark_street", 1.5)

	# 2. Reading an Echo.
	GameState.set_flags(["walked_street"])
	main._interact({"action": "echo", "echo": "echo_notice"})
	await _shoot("2_echo", 1.0)
	main._close_all_modals()

	# 3. Pell, in the guildhall foyer.
	GameState.set_flags(["opened_chronicle"])
	GameState.place_term("the_summons", "who", "pell")
	GameState.place_term("the_summons", "where", "guildhall")
	GameState.try_resolve("the_summons")
	await _go("foyer", 300.0)
	world.player.face_toward(430)
	main._open_dialogue("pell")
	await _shoot("3_pell", 2.5)
	main._close_all_modals()

	# 4. Wren, in the Watch Office.
	for echo_id in ["echo_letter", "echo_drawing"]:
		GameState.collect_echo(echo_id)
	await _go("watch_office", 1180.0)
	main._open_dialogue("wren")
	await _shoot("4_wren", 2.5)
	main._close_all_modals()

	# 5. The Chronicle, the main deduction filled in but not yet confirmed.
	GameState.collect_echo("echo_logbook")
	for slot in ["who", "what", "when"]:
		GameState.place_term("lamps_out", slot, ContentDB.events.lamps_out.slots[slot])
	main._open_chronicle()
	await _shoot("5_chronicle", 1.0)
	main._close_all_modals()

	# 6. The valve puzzle, dials part-way turned (not to the answer).
	GameState.try_resolve("lamps_out")
	await _go("valve_room", 820.0)
	main._interact({"action": "puzzle", "puzzle": "valve_dials"})
	var dials: Node = main._overlays.get_child(0)
	var shown := [3, 1, 5, 2]
	if "".join(shown.map(str)) == str(GameState.vars.valve_code):
		shown = [2, 6, 4, 1]
	for i in shown.size():
		dials._values[i] = shown[i]
		dials._value_labels[i].text = str(shown[i])
	await _shoot("6_valve_puzzle", 1.0)
	main._close_all_modals()

	# 7. The valve turned: the lamps come back.
	GameState.try_puzzle("valve_dials", GameState.vars.valve_code)
	world.player.walk_to(700)  # beside the wheel, not in front of it
	await _shoot("7_lamps_lit", 4.0)

	# 8. The street, relit.
	await _go("street", 1760.0)
	await _shoot("8_city_relit", 4.0)

	DirAccess.remove_absolute(GameState.save_path)
	await Music.shut_down()
	get_tree().quit()


func _go(scene_id: String, x: float) -> void:
	main._arrival_x = x
	GameState.go_to(scene_id)
	await get_tree().create_timer(0.5).timeout


func _shoot(shot_name: String, settle_seconds: float) -> void:
	await get_tree().create_timer(settle_seconds).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)  # Play rejects screenshots with alpha
	var path := _out_dir.path_join(shot_name + ".png")
	image.save_png(path)
	print("saved ", path, " ", image.get_size())

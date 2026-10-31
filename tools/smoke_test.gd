extends Node
## Headless check of content, the full slice playthrough, and walking around the world.
## Run:  godot --headless --path . res://tools/smoke_test.tscn
## Exits 0 on success, 1 on any failure.

var _failures: Array[String] = []


func _ready() -> void:
	GameState.save_path = "user://smoke_test_save.json"

	_test_content_is_valid()
	_test_seed_is_deterministic()
	_test_playthrough()
	_test_save_round_trip()
	_test_dialogue()
	_test_music()
	await _test_world_and_ui()

	DirAccess.remove_absolute(GameState.save_path)
	await Music.shut_down()
	if _failures.is_empty():
		print("SMOKE TEST PASSED")
		get_tree().quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _test_content_is_valid() -> void:
	var problems: Array[String] = ContentDB.validate()
	for problem in problems:
		_failures.append("content: " + problem)


func _test_seed_is_deterministic() -> void:
	GameState.new_game(12345)
	var first: Dictionary = GameState.vars.duplicate()
	GameState.new_game(12345)
	_expect(GameState.vars == first, "same seed should roll the same variables")
	var code := str(GameState.vars.get("valve_code", ""))
	_expect(code.length() == 4, "valve_code should be 4 digits, got '%s'" % code)
	for digit in code:
		_expect(int(digit) >= 1 and int(digit) <= 6, "valve_code digit out of range: '%s'" % code)


func _test_playthrough() -> void:
	GameState.new_game(777)
	_expect(GameState.current_scene == ContentDB.start_scene, "new game starts in start_scene")
	_expect(not GameState.check("discovery:lamps_out"), "no discovery at start")

	for echo_id in ["echo_letter", "echo_logbook", "echo_drawing"]:
		_expect(GameState.collect_echo(echo_id), "%s should be new" % echo_id)
	_expect(not GameState.collect_echo("echo_letter"), "collecting twice is not new")
	_expect(GameState.known_terms("who") == ["ilsa", "orren"], "known who terms: %s" % [GameState.known_terms("who")])

	GameState.place_term("lamps_out", "who", "orren")
	GameState.place_term("lamps_out", "what", "shut_valve")
	_expect(not GameState.is_event_filled("lamps_out"), "event with 2 of 3 slots is not filled")
	_expect(not GameState.try_resolve("lamps_out"), "partial event must not resolve")
	GameState.place_term("lamps_out", "when", "third_bell")
	_expect(not GameState.try_resolve("lamps_out"), "wrong 'who' must not resolve")
	GameState.place_term("lamps_out", "who", "ilsa")
	_expect(GameState.try_resolve("lamps_out"), "correct event should resolve")
	_expect(GameState.check("discovery:lamps_out"), "discovery recorded")

	_expect(not GameState.try_puzzle("valve_dials", "0000"), "wrong code must fail")
	_expect(not GameState.check("flag:valve_opened"), "flag not set before solving")
	_expect(GameState.try_puzzle("valve_dials", GameState.vars.valve_code), "rolled code should solve the puzzle")
	_expect(GameState.check("flag:valve_opened"), "solving sets valve_opened")
	_expect(GameState.check("!flag:never_set"), "negated condition works")


func _test_save_round_trip() -> void:
	var before := {
		"seed": GameState.run_seed, "vars": GameState.vars.duplicate(), "flags": GameState.flags.duplicate(),
		"echoes": GameState.echoes.duplicate(), "discoveries": GameState.discoveries.duplicate(),
		"puzzles": GameState.solved_puzzles.duplicate(), "scene": GameState.current_scene,
	}
	GameState.save_game()
	# Scramble memory directly; new_game() would also overwrite the save file.
	GameState.run_seed = 1
	GameState.vars = {}
	GameState.flags = {}
	GameState.echoes = []
	GameState.discoveries = []
	GameState.solved_puzzles = []
	GameState.current_scene = ""
	_expect(GameState.load_game(), "save should load")
	_expect(GameState.current_scene == before.scene, "scene survives save/load")
	_expect(GameState.run_seed == before.seed, "seed survives save/load")
	_expect(GameState.vars == before.vars, "vars survive save/load")
	_expect(GameState.flags == before.flags, "flags survive save/load")
	_expect(GameState.echoes == before.echoes, "echoes survive save/load")
	_expect(GameState.discoveries == before.discoveries, "discoveries survive save/load")
	_expect(GameState.solved_puzzles == before.puzzles, "puzzles survive save/load")


func _test_dialogue() -> void:
	GameState.new_game(5)
	var node: Dictionary = GameState.resolve_dialogue("pell", "start")
	_expect(node.get("id") == "first_meeting", "first talk with Pell is the introduction")
	GameState.enter_dialogue_node(node)
	_expect(GameState.check("flag:met_pell"), "meeting Pell sets met_pell")
	_expect(GameState.resolve_dialogue("pell", "start").get("id") == "greeting", "later talks start with a greeting")
	var menu: Dictionary = GameState.resolve_dialogue("pell", "menu")
	_expect(GameState.available_choices(menu).size() == 3, "Ilsa question is hidden before reading the letter")

	# Pell's guidance follows the player's progress.
	_expect(GameState.resolve_dialogue("pell", "guide").get("id") == "hint_letter", "guide: letter first")
	GameState.collect_echo("echo_letter")
	_expect(GameState.available_choices(menu).size() == 4, "Ilsa question appears after the letter")
	_expect(GameState.resolve_dialogue("pell", "guide").get("id") == "hint_drawing", "guide: then the drawing")
	GameState.collect_echo("echo_drawing")
	_expect(GameState.resolve_dialogue("pell", "guide").get("id") == "hint_logbook", "guide: then the logbook")
	GameState.collect_echo("echo_logbook")
	_expect(GameState.resolve_dialogue("pell", "guide").get("id") == "hint_chronicle", "guide: then the Chronicle")
	for slot in ["who", "what", "when"]:
		GameState.place_term("lamps_out", slot, ContentDB.events.lamps_out.slots[slot])
	GameState.try_resolve("lamps_out")
	_expect(GameState.resolve_dialogue("pell", "guide").get("id") == "hint_valve", "guide: then the valve")
	GameState.try_puzzle("valve_dials", GameState.vars.valve_code)
	_expect(GameState.resolve_dialogue("pell", "guide").get("id") == "hint_done", "guide: done")
	_expect(GameState.resolve_dialogue("pell", "start").get("id") == "after_lamps", "Pell reacts to the lamps")
	_expect(GameState.resolve_dialogue("wren", "start").get("id") == "lit", "Wren reacts to the lamps")
	_expect(GameState.resolve_dialogue("pell", "").is_empty(), "an empty target ends the conversation")


func _test_music() -> void:
	Music.enabled = true  # ignore the player's saved preference for this test
	GameState.new_game(6)
	_expect(Music.current_track.ends_with("forgotten_city.ogg"), "dark theme plays at the start, got '%s'" % Music.current_track)
	for slot in ["who", "what", "when"]:
		GameState.place_term("lamps_out", slot, ContentDB.events.lamps_out.slots[slot])
	GameState.try_resolve("lamps_out")
	GameState.try_puzzle("valve_dials", GameState.vars.valve_code)
	_expect(Music.current_track.ends_with("lamps_lit.ogg"), "music changes once the lamps are lit, got '%s'" % Music.current_track)


func _test_world_and_ui() -> void:
	Engine.time_scale = 8.0  # walk faster so the test doesn't take long
	GameState.new_game(42)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var world = main.world
	_expect(world.current_scene_id == ContentDB.start_scene, "world loads the start room")
	_expect(is_equal_approx(world.player.position.x, world.room.spawn_x), "explorer starts at spawn_x")

	# Walk up to Pell; arriving opens the conversation and makes him glow.
	var pell := _find_hotspot("foyer", "talk", "pell")
	world.walk_to_hotspot(pell)
	await _wait_until(func(): return main._overlays.get_child_count() == 1, 3000)
	var ghost = world.room.ghosts[0]
	_expect(main._overlays.get_child_count() == 1 and main._overlays.get_child(0).has_method("advance"), "talking to Pell opens a dialogue")
	_expect(ghost.talking, "Pell glows while talking")
	var box = main._overlays.get_child(0)
	for _i in 12:
		if box.is_showing_choices():
			break
		box.advance()
	_expect(box.is_showing_choices(), "tapping through Pell's introduction reaches the choices")
	box.choose(0)  # "Where should I look next?"
	_expect("reception desk" in box._text_label.text, "Pell points to the reception desk first")
	main._close_all_modals()
	await get_tree().process_frame
	_expect(not ghost.talking, "Pell stops glowing when the conversation closes")

	# Walk to the desk as if it were tapped; arriving should open the letter.
	var desk := _find_hotspot("foyer", "echo", "echo_letter")
	world.walk_to_hotspot(desk)
	await _wait_until(func(): return GameState.has_echo("echo_letter"), 3000)
	_expect(GameState.has_echo("echo_letter"), "walking to the desk collects the letter")
	_expect(absf(world.player.position.x - world.stand_x(desk)) < 1.0, "explorer stops at the desk")
	_expect(main._overlays.get_child_count() == 1, "letter popup opens on arrival")
	main._close_all_modals()

	# Walk through a door: fade out, change room, arrive at the door's arrive_x.
	var door := _find_hotspot("foyer", "goto", "watch_office")
	world.walk_to_hotspot(door)
	await _wait_until(func(): return GameState.current_scene == "watch_office" and not main._transitioning, 3000)
	_expect(GameState.current_scene == "watch_office", "the door leads to the watch office")
	_expect(is_equal_approx(world.player.position.x, float(door.arrive_x)), "explorer arrives at arrive_x")
	Engine.time_scale = 1.0

	# Use every other hotspot in every room, before and after the mystery is solved.
	for pass_index in 2:
		for scene_id in ContentDB.scenes:
			GameState.go_to(scene_id)
			await get_tree().process_frame
			for hotspot in ContentDB.scenes[scene_id].get("hotspots", []):
				if hotspot.get("action", "") != "goto":
					main._interact(hotspot)
					await get_tree().process_frame
					main._close_all_modals()
		if pass_index == 0:
			for slot in ["who", "what", "when"]:
				GameState.place_term("lamps_out", slot, ContentDB.events.lamps_out.slots[slot])
			GameState.try_resolve("lamps_out")
			GameState.try_puzzle("valve_dials", GameState.vars.valve_code)
	_expect(world.room.ambient_color() == Color.html("#e4d6bc"), "valve room ambient switches once lit")

	main._open_chronicle()
	await get_tree().process_frame
	_expect(main._overlays.get_child_count() == 1, "chronicle opens as a modal")
	main._close_all_modals()
	main._start_new_run()
	await get_tree().process_frame
	_expect(GameState.echoes.is_empty(), "new run clears echoes")
	_expect(world.current_scene_id == ContentDB.start_scene, "new run returns to the start room")
	main.queue_free()


func _find_hotspot(scene_id: String, action: String, value: String) -> Dictionary:
	for hotspot in ContentDB.scenes[scene_id].get("hotspots", []):
		if hotspot.get("action", "") == action and value in [hotspot.get("echo"), hotspot.get("target"), hotspot.get("puzzle"), hotspot.get("npc")]:
			return hotspot
	_failures.append("no %s hotspot for '%s' in %s" % [action, value, scene_id])
	return {"rect": [0, 0, 0, 0]}


func _wait_until(condition: Callable, max_frames: int) -> void:
	for _i in max_frames:
		if condition.call():
			return
		await get_tree().process_frame

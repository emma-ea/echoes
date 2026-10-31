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
	_test_quest_steps()
	await _test_world_and_ui()
	await _test_title_and_intro()

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
	_expect(GameState.visited == [ContentDB.start_scene], "visited rooms survive save/load")


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

	# Volume 1-5: each level louder than the last, the default unchanged, out-of-range clamped, saved.
	var saved_volume: int = Music.volume
	var levels: Array = []
	for level in range(1, 6):
		Music.set_volume(level)
		levels.append(Music.target_db())
	_expect(levels[0] < levels[1] and levels[1] < levels[2] and levels[2] < levels[3] and levels[3] < levels[4], "each volume level is louder: %s" % [levels])
	_expect(is_equal_approx(levels[2], Music.BASE_VOLUME_DB), "volume 3 keeps the original loudness")
	Music.set_volume(9)
	_expect(Music.volume == 5, "volume is capped at 5")
	Music.set_volume(0)
	_expect(Music.volume == 1, "volume never goes below 1")
	var settings := ConfigFile.new()
	settings.load(Music.SETTINGS_PATH)
	_expect(settings.get_value("audio", "music_volume") == 1, "volume is saved to settings")
	Music.set_volume(saved_volume)


func _test_quest_steps() -> void:
	GameState.new_game(8)
	var expected := ["walk", "notice", "chronicle", "summons", "enter", "meet", "search", "deduce", "valve", "end"]
	var seen: Array = [GameState.current_step().get("id")]
	_expect(GameState.has_echo("echo_summons"), "you arrive carrying the letter")
	_expect(not GameState.is_event_visible("lamps_out"), "the main mystery is hidden during the prelude")
	GameState.set_flags(["walked_street"])
	seen.append(GameState.current_step().get("id"))
	GameState.collect_echo("echo_notice")
	seen.append(GameState.current_step().get("id"))
	GameState.set_flags(["opened_chronicle"])
	seen.append(GameState.current_step().get("id"))
	GameState.place_term("the_summons", "who", "pell")
	GameState.place_term("the_summons", "where", "guildhall")
	_expect(GameState.try_resolve("the_summons"), "the summons resolves with Pell + Guildhall")
	seen.append(GameState.current_step().get("id"))
	GameState.go_to("foyer")
	seen.append(GameState.current_step().get("id"))
	GameState.enter_dialogue_node(GameState.resolve_dialogue("pell", "start"))
	seen.append(GameState.current_step().get("id"))
	_expect(GameState.is_event_visible("lamps_out"), "the main mystery appears after meeting Pell")
	for echo_id in ["echo_letter", "echo_drawing", "echo_logbook"]:
		GameState.collect_echo(echo_id)
	seen.append(GameState.current_step().get("id"))
	for slot in ["who", "what", "when"]:
		GameState.place_term("lamps_out", slot, ContentDB.events.lamps_out.slots[slot])
	GameState.try_resolve("lamps_out")
	seen.append(GameState.current_step().get("id"))
	GameState.try_puzzle("valve_dials", GameState.vars.valve_code)
	seen.append(GameState.current_step().get("id"))
	_expect(seen == expected, "objectives advance in order: %s" % [seen])


func _test_world_and_ui() -> void:
	Engine.time_scale = 8.0  # walk faster so the test doesn't take long
	GameState.new_game(42)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var world = main.world
	_expect(world.current_scene_id == "street", "a new game starts on the street")
	_expect(is_equal_approx(world.player.position.x, world.room.spawn_x), "explorer starts at spawn_x")
	_expect(main._step_id == "walk" and main._tip_card.visible, "first objective and tip are shown")

	# Prelude: walking to the notice board passes the trigger and reads the notice on arrival.
	world.walk_to_hotspot(_find_hotspot("street", "echo", "echo_notice"))
	await _wait_until(func(): return GameState.has_echo("echo_notice"), 3000)
	_expect(GameState.check("flag:walked_street"), "walking up the street completes the first step")
	_expect(GameState.has_echo("echo_notice") and main._overlays.get_child_count() == 1, "the notice opens on arrival")
	_expect(main._step_id == "chronicle" and main._highlight_chronicle, "next: open the Chronicle (button pulses)")
	main._close_all_modals()
	main._open_chronicle()
	await get_tree().process_frame
	_expect(main._step_id == "summons", "opening the Chronicle completes that step")
	main._close_all_modals()

	# The night door turns you away until the summons is worked out.
	var night_door := _find_hotspot("street", "goto", "foyer")
	main._interact(night_door)
	await get_tree().process_frame
	_expect(GameState.current_scene == "street" and main._toast.visible, "the locked night door explains itself")
	GameState.place_term("the_summons", "who", "pell")
	GameState.place_term("the_summons", "where", "guildhall")
	GameState.try_resolve("the_summons")
	world.walk_to_hotspot(night_door)
	await _wait_until(func(): return GameState.current_scene == "foyer" and not main._transitioning, 3000)
	_expect(GameState.current_scene == "foyer", "the night door opens once you know who sent for you")
	_expect(is_equal_approx(world.player.position.x, float(night_door.arrive_x)), "explorer arrives at arrive_x")
	_expect(main._step_id == "meet", "next: find whoever is waiting")

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
	_expect(main._step_id == "search" and not main._tip_card.visible, "the prelude is over; no more tips")

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

	# Pause menu: pauses the world, and closing it resumes.
	main._open_pause()
	await get_tree().process_frame
	_expect(get_tree().paused and main._overlays.get_child_count() == 1, "the menu pauses the game")
	var saved_volume: int = Music.volume
	var volume_control = main._overlays.get_child(0).content.get_children().filter(func(c): return c.has_method("_set_volume"))
	_expect(volume_control.size() == 1, "the pause menu has a music volume control")
	if volume_control.size() == 1:
		Music.set_volume(2)
		volume_control[0]._set_volume(Music.volume + 1)
		_expect(Music.volume == 3 and volume_control[0]._value_label.text == "3", "+ raises the volume and the display follows")
	Music.set_volume(saved_volume)
	main._overlays.get_child(0).close()
	await get_tree().process_frame
	_expect(not get_tree().paused, "closing the menu resumes the game")
	main.queue_free()
	await get_tree().process_frame


func _test_title_and_intro() -> void:
	var title: Node = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	_expect(Music.current_track == ContentDB.title_music, "the title screen plays the title theme")
	var labels: Array = []
	for button in title._menu.get_children():
		labels.append(button.text)
	_expect(labels[0] == "Continue" and "New Game" in labels, "title menu offers Continue and New Game: %s" % [labels])
	title.queue_free()
	Music.set_override("")

	var intro: Node = load("res://scenes/intro.tscn").instantiate()
	intro.change_scene_on_finish = false
	var finished := [false]
	intro.finished.connect(func(): finished[0] = true)
	add_child(intro)
	for _i in ContentDB.intro.size() * 2 + 1:
		intro.advance()
	_expect(finished[0], "tapping through the intro finishes it")
	intro.queue_free()
	await get_tree().process_frame


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

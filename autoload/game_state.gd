extends Node
## Everything the player has done in the current run. Saved locally after every change.
## UI reads from here and calls the mutators below; it never edits fields directly.

signal changed
# Moments worth counting (Analytics listens). `changed` fires as well whenever state changes.
signal run_started                                            # New Game, before the first save
signal echo_collected(echo_id: String)
signal discovery_attempted(event_id: String, correct: bool)   # only fully filled-in events
signal puzzle_attempted(puzzle_id: String, correct: bool)
signal dialogue_node_entered(dialogue_id: String, node_id: String)

const SAVE_VERSION := 2

var save_path := "user://save.json"

var run_seed: int = 0
var vars: Dictionary = {}           # variable name -> rolled value (String)
var flags: Dictionary = {}          # flag name -> true
var echoes: Array = []              # collected echo ids, in the order found
var placements: Dictionary = {}     # event id -> { slot: term id }
var discoveries: Array = []         # resolved event ids
var solved_puzzles: Array = []
var current_scene: String = ""
var visited: Array = []             # scene ids the player has been to

## True once there's a run worth continuing (a save was loaded, or a new game was started).
var has_saved_game := false


func _ready() -> void:
	has_saved_game = load_game()
	if not has_saved_game:
		_reset_run(0)  # a valid empty run in memory, but nothing saved until "New Game"


func new_game(p_seed: int = 0) -> void:
	_reset_run(p_seed)
	has_saved_game = true
	run_started.emit()
	_commit()


func _reset_run(p_seed: int) -> void:
	run_seed = p_seed if p_seed != 0 else (randi() | 1)
	flags = {}
	echoes = ContentDB.start_echoes.duplicate()
	placements = {}
	discoveries = []
	solved_puzzles = []
	current_scene = ContentDB.start_scene
	visited = [current_scene]
	_roll_variables()


# --- Queries ----------------------------------------------------------------

## Conditions look like "flag:x", "echo:x", "discovery:x" or "puzzle:x"; prefix "!" to negate.
## An empty condition is always true.
func check(condition: String) -> bool:
	if condition.is_empty():
		return true
	var negate := condition.begins_with("!")
	var body := condition.trim_prefix("!")
	var id := body.get_slice(":", 1)
	var result := false
	match body.get_slice(":", 0):
		"flag": result = flags.has(id)
		"echo": result = has_echo(id)
		"discovery": result = has_discovery(id)
		"puzzle": result = is_puzzle_solved(id)
		"visited": result = id in visited
		_: push_error("Unknown condition: " + condition)
	return result != negate


## True if every condition passes. Accepts one condition string or an array of them.
func check_all(conditions) -> bool:
	if typeof(conditions) != TYPE_ARRAY:
		return check(str(conditions))
	for condition in conditions:
		if not check(str(condition)):
			return false
	return true


## The first quest step that isn't done yet (the final step has no done_if, so it stays).
func current_step() -> Dictionary:
	for step in ContentDB.quest_steps:
		if not step.has("done_if") or not check_all(step.done_if):
			return step
	return {}


func is_event_visible(event_id: String) -> bool:
	return check(ContentDB.events[event_id].get("visible_if", ""))


func has_echo(echo_id: String) -> bool:
	return echo_id in echoes


func has_discovery(event_id: String) -> bool:
	return event_id in discoveries


func is_puzzle_solved(puzzle_id: String) -> bool:
	return puzzle_id in solved_puzzles


## Term ids of the given category the player has learned, in the order they were found.
func known_terms(category: String) -> Array:
	var result: Array = []
	for echo_id in echoes:
		for term_id in ContentDB.echoes[echo_id].get("terms", []):
			if term_id not in result and ContentDB.terms[term_id].get("category", "") == category:
				result.append(term_id)
	return result


func is_event_filled(event_id: String) -> bool:
	var placed: Dictionary = placements.get(event_id, {})
	for slot in ContentDB.events[event_id].get("slots", {}):
		if str(placed.get(slot, "")).is_empty():
			return false
	return true


## Follows "branch" nodes (first option whose "if" passes) until it reaches a node with lines
## or choices. Returns that node with its "id" and "dialogue" added, or {} if the conversation ends.
func resolve_dialogue(dialogue_id: String, node_id: String) -> Dictionary:
	var nodes: Dictionary = ContentDB.dialogues.get(dialogue_id, {})
	for _hop in 32:
		if node_id.is_empty() or not nodes.has(node_id):
			return {}
		var node: Dictionary = nodes[node_id]
		if not node.has("branch"):
			return node.merged({"id": node_id, "dialogue": dialogue_id})
		node_id = ""
		for option in node.branch:
			if check(option.get("if", "")):
				node_id = option.get("goto", "")
				break
	push_error("Dialogue '%s' keeps branching in a loop" % dialogue_id)
	return {}


func available_choices(node: Dictionary) -> Array:
	return node.get("choices", []).filter(func(choice): return check(choice.get("if", "")))


## Fills {variable} placeholders in authored text with this run's rolled values.
func format_text(text: String) -> String:
	return text.format(vars)


# --- Mutators ---------------------------------------------------------------

## Returns true if this echo was new.
func collect_echo(echo_id: String) -> bool:
	if has_echo(echo_id):
		return false
	echoes.append(echo_id)
	_commit()
	echo_collected.emit(echo_id)
	return true


func place_term(event_id: String, slot: String, term_id: String) -> void:
	var placed: Dictionary = placements.get(event_id, {})
	if term_id.is_empty():
		placed.erase(slot)
	else:
		placed[slot] = term_id
	placements[event_id] = placed
	_commit()


## Confirms an event only if every slot is correct, so slots can't be brute-forced one at a time.
func try_resolve(event_id: String) -> bool:
	if has_discovery(event_id) or not is_event_filled(event_id):
		return false
	var event: Dictionary = ContentDB.events[event_id]
	var placed: Dictionary = placements[event_id]
	var slots: Dictionary = event.get("slots", {})
	for slot in slots:
		if placed.get(slot, "") != slots[slot]:
			discovery_attempted.emit(event_id, false)
			return false
	discoveries.append(event_id)
	_apply_effects(event.get("effects", {}))
	_commit()
	discovery_attempted.emit(event_id, true)
	return true


func try_puzzle(puzzle_id: String, answer: String) -> bool:
	if is_puzzle_solved(puzzle_id):
		return true
	var puzzle: Dictionary = ContentDB.puzzles[puzzle_id]
	if answer != str(vars.get(puzzle.get("solution_var", ""), "")):
		puzzle_attempted.emit(puzzle_id, false)
		return false
	solved_puzzles.append(puzzle_id)
	_apply_effects(puzzle.get("effects", {}))
	_commit()
	puzzle_attempted.emit(puzzle_id, true)
	return true


## Applies a dialogue node's effects (e.g. "met this NPC") when the player reaches it.
func enter_dialogue_node(node: Dictionary) -> void:
	dialogue_node_entered.emit(node.get("dialogue", ""), node.get("id", ""))
	var effects: Dictionary = node.get("effects", {})
	if effects.is_empty():
		return
	_apply_effects(effects)
	_commit()


func go_to(scene_id: String) -> void:
	current_scene = scene_id
	if scene_id not in visited:
		visited.append(scene_id)
	_commit()


## Sets flags that aren't set yet; saves only if something changed.
func set_flags(names: Array) -> void:
	var changed_any := false
	for flag in names:
		if not flags.has(flag):
			flags[flag] = true
			changed_any = true
	if changed_any:
		_commit()


# --- Internals --------------------------------------------------------------

# Rolled from the run seed, so the same seed always gives the same mystery details.
func _roll_variables() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	vars = {}
	var names: Array = ContentDB.variables.keys()
	names.sort()
	for var_name in names:
		var spec: Dictionary = ContentDB.variables[var_name]
		match spec.get("type", ""):
			"digits":
				var digits := ""
				for _i in int(spec.get("length", 4)):
					digits += str(rng.randi_range(int(spec.get("min", 0)), int(spec.get("max", 9))))
				vars[var_name] = digits
			"choice":
				var options: Array = spec.get("options", [])
				vars[var_name] = str(options[rng.randi_range(0, options.size() - 1)])


func _apply_effects(effects: Dictionary) -> void:
	for flag in effects.get("set_flags", []):
		flags[flag] = true


func _commit() -> void:
	save_game()
	changed.emit()


func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"run_seed": run_seed,
		"vars": vars,
		"flags": flags,
		"echoes": echoes,
		"placements": placements,
		"discoveries": discoveries,
		"solved_puzzles": solved_puzzles,
		"current_scene": current_scene,
		"visited": visited,
	}
	# Write to a temp file first so a crash mid-write can't corrupt the save.
	var temp_path := save_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var err := DirAccess.rename_absolute(temp_path, save_path)
	if err != OK:
		push_error("Could not finalise save: %s" % error_string(err))


## Returns false if there is no usable save.
func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != SAVE_VERSION:
		push_warning("Save file unreadable or from another version; starting a new run.")
		return false
	run_seed = int(data.get("run_seed", 0))
	vars = data.get("vars", {})
	flags = data.get("flags", {})
	echoes = data.get("echoes", [])
	placements = data.get("placements", {})
	discoveries = data.get("discoveries", [])
	solved_puzzles = data.get("solved_puzzles", [])
	current_scene = data.get("current_scene", "")
	visited = data.get("visited", [])
	# Drop references to content that no longer exists (e.g. after a content update).
	echoes = echoes.filter(func(id): return ContentDB.echoes.has(id))
	discoveries = discoveries.filter(func(id): return ContentDB.events.has(id))
	solved_puzzles = solved_puzzles.filter(func(id): return ContentDB.puzzles.has(id))
	if not ContentDB.scenes.has(current_scene):
		current_scene = ContentDB.start_scene
	changed.emit()
	return true

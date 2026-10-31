extends Node
## Loads all authored content from res://data and checks that it hangs together.
## Content is read-only at runtime; everything the player changes lives in GameState.

const DATA_DIR := "res://data/"
const SLOTS: Array[String] = ["who", "what", "when", "where"]
const HOTSPOT_ACTIONS: Array[String] = ["echo", "goto", "puzzle", "examine", "talk"]
const PUZZLE_TYPES: Array[String] = ["dial_code"]
const CONDITION_KINDS: Array[String] = ["flag", "echo", "discovery", "puzzle", "visited"]
const PROP_TYPES: Array[String] = [
	"window", "door", "archway", "desk", "lectern", "chandelier", "sconce", "pillar", "chalk",
	"valve", "pipes", "crate", "rubble", "banner", "shelf", "cobweb", "street_lamp", "facade",
	"notice_board", "sprite",
]
const ROOM_STYLES: Array[String] = ["interior", "street"]
# Flags set by the UI rather than by content (e.g. the tutorial's "open your Chronicle").
const UI_FLAGS: Array[String] = ["opened_chronicle", "seen_demo_end"]
const MIN_ROOM_WIDTH := 1600
# NPC looks and how tall each figure is (sizes the tap area around them).
const NPC_LOOKS := {"porter": 185.0, "child": 125.0}

var title: String = ""
var subtitle: String = ""
var intro: Array = []
var title_music: String = ""
var start_echoes: Array = []
var quest_steps: Array = []
var demo_end: Dictionary = {}
var start_scene: String = ""
var variables: Dictionary = {}
var scenes: Dictionary = {}
var echoes: Dictionary = {}
var terms: Dictionary = {}
var events: Dictionary = {}
var puzzles: Dictionary = {}
var npcs: Dictionary = {}
var dialogues: Dictionary = {}
var music: Array = []


# Loaded in _init so the data is ready before any other autoload's _ready runs.
func _init() -> void:
	var world: Dictionary = _load_json("world.json")
	title = world.get("title", "")
	subtitle = world.get("subtitle", "")
	intro = world.get("intro", [])
	title_music = world.get("title_music", "")
	start_echoes = world.get("start_echoes", [])
	demo_end = world.get("demo_end", {})
	start_scene = world.get("start_scene", "")
	variables = world.get("variables", {})
	music = world.get("music", [])
	scenes = _load_json("scenes.json")
	echoes = _load_json("echoes.json")
	var chronicle: Dictionary = _load_json("chronicle.json")
	terms = chronicle.get("terms", {})
	events = chronicle.get("events", {})
	puzzles = _load_json("puzzles.json")
	npcs = _load_json("npcs.json")
	dialogues = _load_json("dialogue.json")
	quest_steps = _load_json("quests.json").get("steps", [])
	_add_npc_hotspots()
	for problem in validate():
		push_error("Content: " + problem)


func _load_json(file_name: String) -> Dictionary:
	var path := DATA_DIR + file_name
	if not FileAccess.file_exists(path):
		push_error("Content: missing " + path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Content: %s is not a valid JSON object" % path)
		return {}
	return parsed


# Each NPC placed in a room becomes a "talk" hotspot around the figure, so tapping, walking over,
# markers and the interact key all work for NPCs exactly as they do for objects.
func _add_npc_hotspots() -> void:
	for scene_id in scenes:
		var scene: Dictionary = scenes[scene_id]
		var hotspots: Array = scene.get("hotspots", [])
		var floor_y := float(scene.get("floor_y", 600))
		for placement in scene.get("npcs", []):
			var npc_id: String = placement.get("id", "")
			var npc: Dictionary = npcs.get(npc_id, {})
			var x := float(placement.get("x", 0))
			var height: float = NPC_LOOKS.get(npc.get("look", ""), 185.0)
			hotspots.append({
				"label": npc.get("name", npc_id),
				"rect": [x - 45, floor_y - height - 10, 90, height + 10],
				"action": "talk",
				"npc": npc_id,
				"npc_x": x,
				"visible_if": placement.get("visible_if", ""),
			})
		scene["hotspots"] = hotspots


## Returns a list of human-readable problems; empty means the content is consistent.
func validate() -> Array[String]:
	var problems: Array[String] = []
	var flags_set := _flags_set_anywhere()
	var reachable_echoes := {}
	for echo_id in start_echoes:
		if echoes.has(echo_id):
			reachable_echoes[echo_id] = true
		else:
			problems.append("start_echoes: unknown echo '%s'" % echo_id)
	if intro.is_empty():
		problems.append("world.json has no intro lines")
	if not demo_end.is_empty():
		_check_condition(demo_end.get("if", ""), "demo_end", flags_set, problems)
		if str(demo_end.get("title", "")).is_empty() or str(demo_end.get("text", "")).is_empty():
			problems.append("demo_end needs a title and text")
		var url := str(demo_end.get("feedback_url", ""))
		if not url.is_empty() and not url.begins_with("https://"):
			problems.append("demo_end feedback_url should be an https:// link")
	if not ResourceLoader.exists(title_music):
		problems.append("title_music '%s' not found" % title_music)

	if not scenes.has(start_scene):
		problems.append("start_scene '%s' is not a scene" % start_scene)

	for scene_id in scenes:
		var scene: Dictionary = scenes[scene_id]
		var room_where := "scene '%s'" % scene_id
		var width := float(scene.get("width", 0))
		var floor_y := float(scene.get("floor_y", 0))
		var walk := _walk_range(scene)
		if width < MIN_ROOM_WIDTH:
			problems.append("%s: width must be at least %d so wide phones don't see past the room" % [room_where, MIN_ROOM_WIDTH])
		if floor_y < 300 or floor_y > 700:
			problems.append("%s: floor_y should be between 300 and 700" % room_where)
		if walk.x < 0 or walk.y > width or walk.x >= walk.y:
			problems.append("%s: walk must be [min_x, max_x] inside the room" % room_where)
		if scene.get("style", "interior") not in ROOM_STYLES:
			problems.append("%s: style must be one of %s" % [room_where, ROOM_STYLES])
		for trigger in scene.get("triggers", []):
			var span: Array = trigger.get("x", [])
			if span.size() != 2 or float(span[0]) > float(span[1]):
				problems.append("%s: trigger x must be [from, to]" % room_where)
			if trigger.get("set_flags", []).is_empty():
				problems.append("%s: trigger has no set_flags" % room_where)
		var spawn_x := float(scene.get("spawn_x", walk.x))
		if spawn_x < walk.x or spawn_x > walk.y:
			problems.append("%s: spawn_x is outside the walkable range" % room_where)
		for entry in scene.get("ambient", []):
			_check_condition(entry.get("if", ""), room_where + " ambient", flags_set, problems)
			if not Color.html_is_valid(str(entry.get("color", ""))):
				problems.append("%s: ambient color '%s' is not a colour" % [room_where, entry.get("color", "")])
		for placement in scene.get("npcs", []):
			var x := float(placement.get("x", -1))
			if x < walk.x or x > walk.y:
				problems.append("%s npc '%s': x is outside the walkable range" % [room_where, placement.get("id", "?")])
		for prop in scene.get("props", []):
			var where := "%s prop '%s'" % [room_where, prop.get("type", "?")]
			var prop_type: String = prop.get("type", "")
			if prop_type not in PROP_TYPES:
				problems.append("%s: unknown type (expected one of %s)" % [where, PROP_TYPES])
			elif prop_type == "sprite" and not ResourceLoader.exists(str(prop.get("texture", ""))):
				problems.append("%s: texture '%s' not found" % [where, prop.get("texture", "")])
			_check_rect(prop, where, problems)
			_check_condition(prop.get("visible_if", ""), where, flags_set, problems)
			_check_condition(prop.get("lit_if", ""), where, flags_set, problems)
		for hotspot in scene.get("hotspots", []):
			var where := "%s hotspot '%s'" % [room_where, hotspot.get("label", "?")]
			_check_rect(hotspot, where, problems)
			_check_condition(hotspot.get("visible_if", ""), where, flags_set, problems)
			_check_condition(hotspot.get("requires", ""), where, flags_set, problems)
			if hotspot.has("stand_x") and (float(hotspot.stand_x) < walk.x or float(hotspot.stand_x) > walk.y):
				problems.append("%s: stand_x is outside the walkable range" % where)
			var action: String = hotspot.get("action", "")
			match action:
				"echo":
					var echo_id: String = hotspot.get("echo", "")
					if echoes.has(echo_id):
						reachable_echoes[echo_id] = true
					else:
						problems.append("%s: unknown echo '%s'" % [where, echo_id])
				"goto":
					var target: String = hotspot.get("target", "")
					if not scenes.has(target):
						problems.append("%s: unknown target scene '%s'" % [where, target])
					elif hotspot.has("arrive_x"):
						var target_walk := _walk_range(scenes[target])
						if float(hotspot.arrive_x) < target_walk.x or float(hotspot.arrive_x) > target_walk.y:
							problems.append("%s: arrive_x is outside '%s' walkable range" % [where, target])
				"puzzle":
					if not puzzles.has(hotspot.get("puzzle", "")):
						problems.append("%s: unknown puzzle '%s'" % [where, hotspot.get("puzzle", "")])
				"examine":
					if str(hotspot.get("text", "")).is_empty():
						problems.append("%s: examine hotspot has no text" % where)
				"talk":
					if not npcs.has(hotspot.get("npc", "")):
						problems.append("%s: unknown npc '%s'" % [where, hotspot.get("npc", "")])
				_:
					problems.append("%s: unknown action '%s' (expected one of %s)" % [where, action, HOTSPOT_ACTIONS])

	var obtainable_terms := {}
	for echo_id in echoes:
		if not reachable_echoes.has(echo_id):
			problems.append("echo '%s' is not placed in any scene" % echo_id)
		for term_id in echoes[echo_id].get("terms", []):
			if terms.has(term_id):
				obtainable_terms[term_id] = true
			else:
				problems.append("echo '%s': unknown term '%s'" % [echo_id, term_id])

	for term_id in terms:
		var category: String = terms[term_id].get("category", "")
		if category not in SLOTS:
			problems.append("term '%s': category '%s' must be one of %s" % [term_id, category, SLOTS])

	for event_id in events:
		var event: Dictionary = events[event_id]
		var slots: Dictionary = event.get("slots", {})
		if slots.is_empty():
			problems.append("event '%s' has no slots" % event_id)
		for slot in slots:
			var term_id: String = slots[slot]
			if slot not in SLOTS:
				problems.append("event '%s': unknown slot '%s'" % [event_id, slot])
			elif not terms.has(term_id):
				problems.append("event '%s': unknown term '%s'" % [event_id, term_id])
			elif terms[term_id].get("category", "") != slot:
				problems.append("event '%s': term '%s' is not a '%s' term" % [event_id, term_id, slot])
			elif not obtainable_terms.has(term_id):
				problems.append("event '%s': no echo provides the answer term '%s'" % [event_id, term_id])
		if not event.has("discovery"):
			problems.append("event '%s' has no discovery" % event_id)
		_check_condition(event.get("visible_if", ""), "event '%s'" % event_id, flags_set, problems)

	var step_ids := {}
	for step in quest_steps:
		var step_id := str(step.get("id", ""))
		var where := "quest step '%s'" % step_id
		if step_id.is_empty() or step_ids.has(step_id):
			problems.append("%s: every step needs a unique id" % where)
		step_ids[step_id] = true
		if str(step.get("objective", "")).is_empty():
			problems.append("%s: has no objective text" % where)
		if step.get("highlight", "") not in ["", "chronicle"]:
			problems.append("%s: highlight can only be 'chronicle'" % where)
		var done_if = step.get("done_if", [])
		for condition in (done_if if typeof(done_if) == TYPE_ARRAY else [done_if]):
			_check_condition(str(condition), where, flags_set, problems)

	for puzzle_id in puzzles:
		var puzzle: Dictionary = puzzles[puzzle_id]
		var puzzle_type: String = puzzle.get("type", "")
		if puzzle_type not in PUZZLE_TYPES:
			problems.append("puzzle '%s': unknown type '%s'" % [puzzle_id, puzzle_type])
			continue
		var var_name: String = puzzle.get("solution_var", "")
		if not variables.has(var_name):
			problems.append("puzzle '%s': unknown solution_var '%s'" % [puzzle_id, var_name])
			continue
		var spec: Dictionary = variables[var_name]
		if puzzle_type == "dial_code":
			if spec.get("type", "") != "digits":
				problems.append("puzzle '%s': dial_code needs a 'digits' variable" % puzzle_id)
			elif int(spec.get("length", 0)) != int(puzzle.get("dials", 0)):
				problems.append("puzzle '%s': dials count doesn't match '%s' length" % [puzzle_id, var_name])
			elif int(spec.get("min", 0)) < int(puzzle.get("min", 0)) or int(spec.get("max", 9)) > int(puzzle.get("max", 9)):
				problems.append("puzzle '%s': '%s' can roll digits the dials can't show" % [puzzle_id, var_name])
			if int(puzzle.get("min", 0)) < 0 or int(puzzle.get("max", 9)) > 9:
				problems.append("puzzle '%s': dial values must be single digits" % puzzle_id)

	for npc_id in npcs:
		var npc: Dictionary = npcs[npc_id]
		if not NPC_LOOKS.has(npc.get("look", "")):
			problems.append("npc '%s': look must be one of %s" % [npc_id, NPC_LOOKS.keys()])
		if not Color.html_is_valid(str(npc.get("color", ""))):
			problems.append("npc '%s': color '%s' is not a colour" % [npc_id, npc.get("color", "")])
		if not dialogues.has(npc.get("dialogue", "")):
			problems.append("npc '%s': unknown dialogue '%s'" % [npc_id, npc.get("dialogue", "")])

	for dialogue_id in dialogues:
		_validate_dialogue(dialogue_id, flags_set, problems)

	for entry in music:
		_check_condition(entry.get("if", ""), "music", flags_set, problems)
		if not ResourceLoader.exists(str(entry.get("track", ""))):
			problems.append("music: track '%s' not found" % entry.get("track", ""))

	for var_name in variables:
		var var_type: String = variables[var_name].get("type", "")
		if var_type not in ["digits", "choice"]:
			problems.append("variable '%s': unknown type '%s'" % [var_name, var_type])
		elif var_type == "choice" and variables[var_name].get("options", []).is_empty():
			problems.append("variable '%s': choice needs options" % var_name)

	return problems


func _validate_dialogue(dialogue_id: String, flags_set: Dictionary, problems: Array[String]) -> void:
	var nodes: Dictionary = dialogues[dialogue_id]
	if not nodes.has("start"):
		problems.append("dialogue '%s' has no 'start' node" % dialogue_id)
	for node_id in nodes:
		var node: Dictionary = nodes[node_id]
		var where := "dialogue '%s' node '%s'" % [dialogue_id, node_id]
		if node.has("branch"):
			var options: Array = node.branch
			if options.is_empty() or options[-1].has("if"):
				problems.append("%s: the last branch option must have no 'if', so there's always somewhere to go" % where)
			for option in options:
				_check_condition(option.get("if", ""), where, flags_set, problems)
				_check_dialogue_target(nodes, str(option.get("goto", "")), where, problems)
			continue
		if node.get("lines", []).is_empty() and node.get("choices", []).is_empty():
			problems.append("%s: needs lines, choices or a branch" % where)
		for choice in node.get("choices", []):
			if str(choice.get("text", "")).is_empty():
				problems.append("%s: a choice has no text" % where)
			_check_condition(choice.get("if", ""), where, flags_set, problems)
			_check_dialogue_target(nodes, str(choice.get("goto", "")), where, problems)
		_check_dialogue_target(nodes, str(node.get("next", "")), where, problems)


# An empty target ends the conversation; anything else must be a node in the same dialogue.
func _check_dialogue_target(nodes: Dictionary, target: String, where: String, problems: Array[String]) -> void:
	if not target.is_empty() and not nodes.has(target):
		problems.append("%s: goes to unknown node '%s'" % [where, target])


func _flags_set_anywhere() -> Dictionary:
	var flags := {}
	for flag in UI_FLAGS:
		flags[flag] = true
	for scene in scenes.values():
		for trigger in scene.get("triggers", []):
			for flag in trigger.get("set_flags", []):
				flags[flag] = true
	var sources: Array = []
	for event_id in events:
		sources.append(events[event_id].get("effects", {}))
	for puzzle_id in puzzles:
		sources.append(puzzles[puzzle_id].get("effects", {}))
	for dialogue_id in dialogues:
		for node in dialogues[dialogue_id].values():
			sources.append(node.get("effects", {}))
	for effects in sources:
		for flag in effects.get("set_flags", []):
			flags[flag] = true
	return flags


func _check_condition(condition: String, where: String, flags_set: Dictionary, problems: Array[String]) -> void:
	if condition.is_empty():
		return
	var body := condition.trim_prefix("!")
	var kind := body.get_slice(":", 0)
	var id := body.get_slice(":", 1)
	var known := false
	match kind:
		"flag": known = flags_set.has(id)
		"echo": known = echoes.has(id)
		"discovery": known = events.has(id)
		"puzzle": known = puzzles.has(id)
		"visited": known = scenes.has(id)
		_:
			problems.append("%s: condition '%s' must start with one of %s" % [where, condition, CONDITION_KINDS])
			return
	if not known:
		problems.append("%s: condition '%s' refers to something that never exists or is never set" % [where, condition])


func _walk_range(scene: Dictionary) -> Vector2:
	var width := float(scene.get("width", 0))
	var walk: Array = scene.get("walk", [80, width - 80])
	if walk.size() != 2:
		return Vector2(0, -1)
	return Vector2(float(walk[0]), float(walk[1]))


func _check_rect(entry: Dictionary, where: String, problems: Array[String]) -> void:
	var rect = entry.get("rect")
	if typeof(rect) != TYPE_ARRAY or rect.size() != 4:
		problems.append("%s: rect must be [x, y, width, height]" % where)

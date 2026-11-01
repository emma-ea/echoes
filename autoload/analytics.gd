extends Node
## Anonymous play analytics through GameAnalytics (addons/GameAnalytics), to learn where players
## get stuck. Sends only from release builds whose res://analytics_keys.json has keys (that file
## is git-ignored; copy analytics_keys.example.json), and only while the player leaves
## "Share play data" on. Players get a random ID, not a device or advertising ID.
##
## What it sends (GameAnalytics needs nothing set up in advance for these):
##   progression  start/complete chapter_1, and start/complete chapter_1:<quest step id>;
##                fail chapter_1:<step> when a run is abandoned with New Game
##   design       step_minutes:<step>         minutes of play spent on a step (value)
##                chapter_minutes             minutes of play for the whole chapter (value)
##                echo:<echo id>              an Echo was found
##                deduction:<event id>:wrong  a wrong answer in the Chronicle
##                deduction:<event id>:solved value = wrong answers before getting it
##                puzzle:<puzzle id>:wrong / :solved   the same, for puzzles
##                talk:<dialogue id>:<node>   a line of conversation reached (e.g. Pell's hints)
##                demo_end:<button>           what players picked on the end-of-demo screen

const BuildInfo := preload("res://scripts/ui/build_info.gd")

const KEYS_PATH := "res://analytics_keys.json"
const SETTINGS_PATH := "user://settings.cfg"  # shared with Music
const STATE_PATH := "user://analytics.cfg"    # step timers for the current run
const GAME_SCENE := "res://scenes/main.tscn"
const CHAPTER := "chapter_1"
const SAVE_EVERY := 30.0  # seconds of play between saves of the timers

var share_play_data := true
var active := false  # initialised and sending

var _ga: Object      # the GameAnalytics singleton, once initialised
var _step := ""      # quest step being timed
var _step_seconds := 0.0
var _chapter_seconds := 0.0
var _wrong: Dictionary = {}  # "deduction:<id>" or "puzzle:<id>" -> wrong attempts this run
var _unsaved := 0.0


func _ready() -> void:
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		share_play_data = settings.get_value("privacy", "share_play_data", true)
	GameState.run_started.connect(_on_run_started)
	GameState.changed.connect(_on_progress)
	GameState.echo_collected.connect(func(echo_id: String): track("echo:" + echo_id))
	GameState.discovery_attempted.connect(_on_attempt.bind("deduction"))
	GameState.puzzle_attempted.connect(_on_attempt.bind("puzzle"))
	GameState.dialogue_node_entered.connect(func(dialogue_id: String, node_id: String):
		track("talk:%s:%s" % [dialogue_id, node_id]))
	if share_play_data:
		_start()


func set_share_play_data(value: bool) -> void:
	share_play_data = value
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("privacy", "share_play_data", value)
	settings.save(SETTINGS_PATH)
	if _ga:
		_ga.setEnabledEventSubmission(value)
		active = value
		if active:
			_sync_step()
	elif value:
		_start()


## A design event, optionally with a number. Ids are up to 5 parts separated by ":".
func track(event_id: String, value = null) -> void:
	if not active:
		return
	if value == null:
		_ga.addDesignEvent(event_id, {})
	else:
		_ga.addDesignEventWithValue(event_id, float(value))


func _start() -> void:
	if not Engine.has_singleton("GameAnalytics"):
		return
	var keys := _read_keys()
	if keys.is_empty() or (OS.is_debug_build() and not keys.get("send_from_debug_builds", false)):
		return
	_ga = Engine.get_singleton("GameAnalytics")
	_ga.setEnabledInfoLog(OS.is_debug_build())
	_ga.setWritablePath(OS.get_user_data_dir())  # its event queue; on desktop it'd use ~/GameAnalytics
	_ga.useRandomizedId(true)
	_ga.configureBuild(BuildInfo.label().replace(" ", "-"))
	_ga.init(keys.game_key, keys.secret_key)
	active = true
	_load_state()
	_sync_step()


func _read_keys() -> Dictionary:
	if not FileAccess.file_exists(KEYS_PATH):
		if not OS.is_debug_build():
			push_warning("Analytics: no %s in this build, so nothing is sent" % KEYS_PATH)
		return {}
	var keys = JSON.parse_string(FileAccess.get_file_as_string(KEYS_PATH))
	if not keys is Dictionary or str(keys.get("game_key", "")).is_empty() or str(keys.get("secret_key", "")).is_empty():
		push_warning("Analytics: %s needs a game_key and a secret_key" % KEYS_PATH)
		return {}
	return keys


# --- Progress ---------------------------------------------------------------

func _on_run_started() -> void:
	if not active:
		return
	if not _step.is_empty() and not _is_final(_step):
		_progression("fail", _step)  # started over before finishing
	_step = ""
	_step_seconds = 0.0
	_chapter_seconds = 0.0
	_wrong = {}
	_progression("start")
	# GameState saves next, and _on_progress starts the first step.


func _on_progress() -> void:
	if not active:
		return
	var step: Dictionary = GameState.current_step()
	var step_id: String = step.get("id", "")
	if step_id == _step:
		return
	if not _step.is_empty():
		_progression("complete", _step)
		track("step_minutes:" + _step, _step_seconds / 60.0)
	_step = step_id
	_step_seconds = 0.0
	if _is_final(step_id):
		_progression("complete")
		track("chapter_minutes", _chapter_seconds / 60.0)
	else:
		_progression("start", step_id)
	_save_state()


## After a launch or a time with sharing off: carry on from where the run is now, without
## reporting steps that happened while nothing was being sent.
func _sync_step() -> void:
	var step_id: String = GameState.current_step().get("id", "") if GameState.has_saved_game else ""
	if step_id != _step:
		_step = step_id
		_step_seconds = 0.0
		_save_state()


func _on_attempt(id: String, correct: bool, kind: String) -> void:
	if not active:
		return
	var key := "%s:%s" % [kind, id]
	if correct:
		track(key + ":solved", _wrong.get(key, 0))
	else:
		_wrong[key] = _wrong.get(key, 0) + 1
		track(key + ":wrong")
	_save_state()


func _is_final(step_id: String) -> bool:
	for step in ContentDB.quest_steps:
		if step.get("id", "") == step_id:
			return not step.has("done_if")
	return false


func _progression(status: String, step_id := "") -> void:
	if active:
		_ga.addProgressionEvent(status, CHAPTER, step_id, "", {})


# --- Timers -----------------------------------------------------------------

# Counts play time only: in the game scene, not paused (this node pauses with the game), and
# not in the background (the app doesn't run then).
func _process(delta: float) -> void:
	if not active or _step.is_empty() or _is_final(_step):
		return
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != GAME_SCENE:
		return
	_step_seconds += delta
	_chapter_seconds += delta
	_unsaved += delta
	if _unsaved >= SAVE_EVERY:
		_save_state()


func _notification(what: int) -> void:
	if not active:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_state()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_ga.onQuit()


func _load_state() -> void:
	var state := ConfigFile.new()
	if state.load(STATE_PATH) != OK:
		return
	_step = state.get_value("run", "step", "")
	_step_seconds = state.get_value("run", "step_seconds", 0.0)
	_chapter_seconds = state.get_value("run", "chapter_seconds", 0.0)
	_wrong = state.get_value("run", "wrong", {})


func _save_state() -> void:
	_unsaved = 0.0
	var state := ConfigFile.new()
	state.set_value("run", "step", _step)
	state.set_value("run", "step_seconds", _step_seconds)
	state.set_value("run", "chapter_seconds", _chapter_seconds)
	state.set_value("run", "wrong", _wrong)
	state.save(STATE_PATH)

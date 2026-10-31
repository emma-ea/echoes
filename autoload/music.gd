extends Node
## Background music. Plays the first world.json "music" entry whose "if" passes, and crossfades
## when progress changes which one that is. The on/off choice lives in user://settings.cfg,
## separate from the run save, so it survives "New run".

const SETTINGS_PATH := "user://settings.cfg"
const FADE_SECONDS := 3.0
const VOLUME_DB := -8.0
const SILENT_DB := -60.0

var enabled := true
var current_track := ""

var _players: Array[AudioStreamPlayer] = []
var _tweens: Array[Tween] = [null, null]
var _active := 0


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false  # quit via _notification, after the music has stopped
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		enabled = settings.get_value("audio", "music", true)
	GameState.changed.connect(update)
	update()


## Stops playback and lets the audio server let go of the streams, so quitting is clean.
func shut_down() -> void:
	current_track = ""
	for i in _players.size():
		if _tweens[i]:
			_tweens[i].kill()
		_players[i].stop()
		_players[i].stream = null
	await get_tree().create_timer(0.15, true, false, true).timeout  # let the audio thread catch up


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		await shut_down()
		get_tree().quit()


func set_enabled(value: bool) -> void:
	enabled = value
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("audio", "music", enabled)
	settings.save(SETTINGS_PATH)
	update()


## Switches to whichever track the current progress calls for (no-op if it's already playing).
func update() -> void:
	var track := _choose_track() if enabled else ""
	if track == current_track:
		return
	current_track = track

	_fade(_active, SILENT_DB, true)
	if track.is_empty():
		return
	_active = 1 - _active
	var stream = load(track)
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	var player := _players[_active]
	player.stream = stream
	player.volume_db = SILENT_DB
	player.play()
	_fade(_active, VOLUME_DB, false)


func _choose_track() -> String:
	for entry in ContentDB.music:
		if GameState.check(entry.get("if", "")):
			return entry.get("track", "")
	return ""


func _fade(index: int, target_db: float, stop_after: bool) -> void:
	if _tweens[index]:
		_tweens[index].kill()
	var player := _players[index]
	var tween := create_tween()
	tween.tween_property(player, "volume_db", target_db, FADE_SECONDS)
	if stop_after:
		tween.tween_callback(player.stop)
	_tweens[index] = tween

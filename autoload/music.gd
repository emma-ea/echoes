extends Node
## Background music. Plays the first world.json "music" entry whose "if" passes, and crossfades
## when progress changes which one that is. The on/off choice and volume (1-5) live in
## user://settings.cfg, separate from the run save, so they survive starting over.

const SETTINGS_PATH := "user://settings.cfg"
const FADE_SECONDS := 3.0
const BASE_VOLUME_DB := -8.0  # loudness at the default volume level
const MIN_VOLUME := 1
const MAX_VOLUME := 5
const DEFAULT_VOLUME := 3
const SILENT_DB := -60.0

var enabled := true
var volume := DEFAULT_VOLUME
var current_track := ""
var override_track := ""  # e.g. the title screen's theme; "" means follow game progress

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
		volume = clampi(int(settings.get_value("audio", "music_volume", DEFAULT_VOLUME)), MIN_VOLUME, MAX_VOLUME)
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
	_save_setting("music", enabled)
	update()


## Sets the music volume (1-5, clamped) and applies it straight away to what's playing.
func set_volume(level: int) -> void:
	volume = clampi(level, MIN_VOLUME, MAX_VOLUME)
	_save_setting("music_volume", volume)
	if not current_track.is_empty():
		_fade(_active, target_db(), false, 0.15)  # a track that's fading out keeps fading


## Each level is a proportional step in loudness; the default level plays at BASE_VOLUME_DB.
func target_db() -> float:
	return BASE_VOLUME_DB + linear_to_db(float(volume) / DEFAULT_VOLUME)


func _save_setting(key: String, value) -> void:
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("audio", key, value)
	settings.save(SETTINGS_PATH)


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
	_fade(_active, target_db(), false)


## Plays a specific track regardless of progress (title screen), or "" to go back to normal.
func set_override(track: String) -> void:
	override_track = track
	update()


func _choose_track() -> String:
	if not override_track.is_empty():
		return override_track
	for entry in ContentDB.music:
		if GameState.check(entry.get("if", "")):
			return entry.get("track", "")
	return ""


func _fade(index: int, to_db: float, stop_after: bool, seconds: float = FADE_SECONDS) -> void:
	if _tweens[index]:
		_tweens[index].kill()
	var player := _players[index]
	var tween := create_tween()
	tween.tween_property(player, "volume_db", to_db, seconds)
	if stop_after:
		tween.tween_callback(player.stop)
	_tweens[index] = tween

extends Node
## A scripted ~50 s gameplay trailer, played through the real game. Record it with Movie Maker:
##   godot --path . --write-movie /tmp/trailer/frame.png --fixed-fps 30 res://tools/trailer.tscn
## then encode with ffmpeg (see README). Uses a throwaway save; doesn't touch your settings.

const Fonts := preload("res://scripts/ui/fonts.gd")

const END_CARD_LINE := "Chapter One  ·  Playtest Welcomed"
const NIGHT := Color("070912")  # same as the boot splash background

var main: Node
var world: Node

var _black: ColorRect
var _caption: Label
var _card: Control


func _ready() -> void:
	_build_overlay()

	# Fresh run, default music volume, and no end-of-demo popup (the trailer has its own ending).
	GameState.save_path = "user://trailer_save.json"
	await Music.shut_down()
	Music.enabled = true
	Music.volume = Music.DEFAULT_VOLUME
	GameState.new_game(2026)
	GameState.set_flags(["seen_demo_end"])

	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	world = main.world
	main._bar.hide()                   # no HUD: room name, objective, buttons
	main._tip_card.modulate.a = 0.0    # and no tutorial tips

	await _play()

	DirAccess.remove_absolute(GameState.save_path)
	await Music.shut_down()
	get_tree().quit()


func _play() -> void:
	# 1. Cold open.
	await _wait(0.8)
	await _say("A hundred years ago, every lamp in the city of Veyl went out.", 2.6)

	# 2. The dark street.
	world.player.walk_to(820)
	_say("Then a letter found you.", 2.4)
	await _fade(_black, "color:a", 0.0, 1.4)
	await _wait(2.4)
	world.player.walk_to(1700)
	await _wait(3.2)

	# 3. Pell, who wrote the letter.
	await _cut_to("foyer", 260)
	world.player.face_toward(430)
	await _wait(0.6)
	main._open_dialogue("pell")
	await _wait(3.8)
	main._overlays.get_child(0).advance()
	await _wait(3.6)
	main._close_all_modals()

	# 4. Wren, in the Watch Office.
	await _cut_to("watch_office", 1320)
	world.player.walk_to(1190)
	_say("Speak with the ones who stayed.", 2.6)
	await _wait(3.6)
	main._open_dialogue("wren")
	await _wait(2.6)
	main._close_all_modals()

	# 5. The Chronicle, mid-deduction.
	for echo_id in ["echo_notice", "echo_letter", "echo_drawing", "echo_logbook"]:
		GameState.collect_echo(echo_id)
	GameState.place_term("the_summons", "who", "pell")
	GameState.place_term("the_summons", "where", "guildhall")
	GameState.try_resolve("the_summons")
	for slot in ["who", "what", "when"]:
		GameState.place_term("lamps_out", slot, ContentDB.events.lamps_out.slots[slot])
	main._open_chronicle()  # no caption here: it would sit on the Chronicle's buttons
	await _wait(3.6)
	main._close_all_modals()

	# 6. The valve: lights and music come back.
	GameState.try_resolve("lamps_out")
	await _cut_to("valve_room", 820)
	world.player.walk_to(1000)
	_say("Bring back the light.", 2.6)
	await _wait(2.6)
	GameState.try_puzzle("valve_dials", GameState.vars.valve_code)
	await _wait(4.4)

	# 7. The street, relit.
	await _cut_to("street", 1150)
	world.player.walk_to(1760)
	await _wait(3.8)

	# 8. Title card, music fading out.
	create_tween().tween_method(func(db: float): AudioServer.set_bus_volume_db(0, db), 0.0, -40.0, 4.0)
	await _fade(_card, "modulate:a", 1.0, 1.4)
	await _wait(3.6)
	AudioServer.set_bus_volume_db(0, 0.0)


func _cut_to(scene_id: String, x: float) -> void:
	await _fade(_black, "color:a", 1.0, 0.6)
	main._arrival_x = x
	GameState.go_to(scene_id)
	await _wait(0.3)
	await _fade(_black, "color:a", 0.0, 0.6)


## Fades a caption in, holds it, fades it out. Call without await to run alongside the action.
func _say(text: String, hold: float) -> void:
	_caption.text = text
	await _fade(_caption, "modulate:a", 1.0, 0.8)
	await _wait(hold)
	await _fade(_caption, "modulate:a", 0.0, 0.8)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _fade(node: Object, property: String, to, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(node, property, to, seconds)
	await tween.finished


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)

	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 1)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_black)

	_caption = Label.new()
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -150
	_caption.offset_bottom = -60
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.add_theme_font_override("font", Fonts.DISPLAY_ITALIC)
	_caption.add_theme_font_size_override("font_size", 40)
	_caption.add_theme_color_override("font_color", Color("ebe5d6"))
	_caption.add_theme_constant_override("outline_size", 12)
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_caption.modulate.a = 0.0
	layer.add_child(_caption)

	# End card: the boot splash art (lantern and name) with one line beneath.
	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.modulate.a = 0.0
	layer.add_child(_card)
	var bg := ColorRect.new()
	bg.color = NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.add_child(bg)
	var art := TextureRect.new()
	art.texture = load("res://icons/boot_splash.png")
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card.add_child(art)
	var line := Label.new()
	line.text = END_CARD_LINE
	line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	line.offset_top = -170
	line.offset_bottom = -120
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 26)
	line.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	_card.add_child(line)

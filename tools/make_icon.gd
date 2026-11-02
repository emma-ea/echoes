extends Node
## Renders the launcher icons and the boot splash from code into res://icons (or --out=folder),
## and the Google Play feature graphic into res://store (a folder Godot ignores, so it isn't exported).
## Run:  godot --path . res://tools/make_icon.tscn     (needs a window, not --headless)
##
## Art is drawn on a 1024 canvas at 2x and scaled down, so edges stay smooth at every size.
## The background layer carries the glow; the foreground (the lantern) is opaque shapes only,
## because translucent pixels in a transparent image save with dark fringes.

const Fonts := preload("res://scripts/ui/fonts.gd")

const CANVAS := 1024.0
const SPLASH_SIZE := Vector2(1280, 720)
## Must match application/boot_splash/bg_color, so the splash has no visible edge on any screen shape.
const SPLASH_BG := Color("070912")
const SUPERSAMPLE := 2
const FEATURE_SIZE := Vector2(1024, 500)  # Google Play's feature graphic: exactly this, no alpha
const FEATURE_TAGLINE := "A hundred years ago, every lamp in the city went out."

const NIGHT_TOP := Color("0b1024")
const NIGHT_BOTTOM := Color("2c2342")
const ROOFS := Color("06070d")
const GLOW := Color(1.0, 0.75, 0.38)
const METAL_DARK := Color("2e241c")
const METAL := Color("8a6a3a")
const GLASS_EDGE := Color("f2a940")
const GLASS := Color("ffd77a")
const FLAME := Color("fffbe6")

# Which layers make up each output image, its size, and whether it may be transparent.
const OUTPUTS := [
	{"file": "icon.png", "size": 1024, "art": "full"},
	{"file": "play_store_512.png", "size": 512, "art": "full"},
	{"file": "android_192.png", "size": 192, "art": "full"},
	{"file": "android_adaptive_background_432.png", "size": 432, "art": "background"},
	{"file": "android_adaptive_foreground_432.png", "size": 432, "art": "foreground", "transparent": true},
	{"file": "android_adaptive_monochrome_432.png", "size": 432, "art": "monochrome", "transparent": true},
]

var _out_dir := ProjectSettings.globalize_path("res://icons")
var _store_dir := ProjectSettings.globalize_path("res://store")


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
			_store_dir = _out_dir
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DirAccess.make_dir_recursive_absolute(_store_dir)

	var viewports := {}
	for art in ["full", "background", "foreground", "monochrome"]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i.ONE * int(CANVAS * SUPERSAMPLE)
		viewport.transparent_bg = true
		viewport.msaa_2d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var canvas := Node2D.new()
		canvas.scale = Vector2.ONE * SUPERSAMPLE
		canvas.draw.connect(_draw_art.bind(canvas, art))
		viewport.add_child(canvas)
		add_child(viewport)
		viewports[art] = viewport

	var splash := SubViewport.new()
	splash.size = Vector2i(SPLASH_SIZE * SUPERSAMPLE)
	splash.msaa_2d = Viewport.MSAA_4X
	splash.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var splash_canvas := Node2D.new()
	splash_canvas.scale = Vector2.ONE * SUPERSAMPLE
	splash_canvas.draw.connect(_draw_splash.bind(splash_canvas))
	splash.add_child(splash_canvas)
	add_child(splash)

	var feature := SubViewport.new()
	feature.size = Vector2i(FEATURE_SIZE * SUPERSAMPLE)
	feature.msaa_2d = Viewport.MSAA_4X
	feature.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var feature_canvas := Node2D.new()
	feature_canvas.scale = Vector2.ONE * SUPERSAMPLE
	feature_canvas.draw.connect(_draw_feature.bind(feature_canvas))
	feature.add_child(feature_canvas)
	add_child(feature)

	for _i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	for spec in OUTPUTS:
		var image: Image = viewports[spec.art].get_texture().get_image()
		image.resize(spec.size, spec.size, Image.INTERPOLATE_LANCZOS)
		if not spec.get("transparent", false):
			image.convert(Image.FORMAT_RGB8)  # app stores (iOS especially) reject icons with alpha
		var path: String = _out_dir.path_join(spec.file)
		image.save_png(path)
		print("saved ", path)

	var splash_image := splash.get_texture().get_image()
	splash_image.resize(int(SPLASH_SIZE.x), int(SPLASH_SIZE.y), Image.INTERPOLATE_LANCZOS)
	splash_image.convert(Image.FORMAT_RGB8)
	var splash_path := _out_dir.path_join("boot_splash.png")
	splash_image.save_png(splash_path)
	print("saved ", splash_path)

	var feature_image := feature.get_texture().get_image()
	feature_image.resize(int(FEATURE_SIZE.x), int(FEATURE_SIZE.y), Image.INTERPOLATE_LANCZOS)
	feature_image.convert(Image.FORMAT_RGB8)
	var feature_path := _store_dir.path_join("feature_graphic.png")
	feature_image.save_png(feature_path)
	print("saved ", feature_path)
	await Music.shut_down()
	get_tree().quit()


func _draw_art(c: CanvasItem, art: String) -> void:
	match art:
		"full":
			_draw_background(c)
			_draw_lantern(c, false)
		"background":
			_draw_background(c)
		"foreground":
			_draw_lantern(c, false)
		"monochrome":
			_draw_lantern(c, true)


# The boot splash: the lantern glowing on plain night, the game's name beneath it.
func _draw_splash(c: CanvasItem) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SPLASH_SIZE), SPLASH_BG)
	var center := Vector2(SPLASH_SIZE.x / 2, 280)
	for k in 60:
		c.draw_circle(center, 300.0 - k * 4.2, Color(GLOW, 0.009))
	# The lantern art is centred on (512, 476) of the icon canvas; draw it smaller, here.
	var lantern_scale := 0.62
	c.draw_set_transform(center - Vector2(512, 476) * lantern_scale, 0.0, Vector2.ONE * lantern_scale)
	_draw_lantern(c, false)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.draw_string(Fonts.DISPLAY, Vector2(0, 520), ContentDB.title, HORIZONTAL_ALIGNMENT_CENTER,
		SPLASH_SIZE.x, 32, Color("ebe5d6"))


# The Play Store banner: the title on the left; on the right the lantern over the rooftops of the
# city, a few of its windows lit again. Kept clear of the edges, which Play may cover or crop.
func _draw_feature(c: CanvasItem) -> void:
	var size := FEATURE_SIZE
	c.draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
		PackedColorArray([NIGHT_TOP, NIGHT_TOP, NIGHT_BOTTOM, NIGHT_BOTTOM]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for _i in 90:
		var star := Vector2(rng.randf_range(10, size.x - 10), rng.randf_range(10, 330))
		c.draw_circle(star, rng.randf_range(0.8, 2.2), Color(1, 1, 1, rng.randf_range(0.2, 0.8)))
	c.draw_circle(Vector2(612, 84), 24, Color("d8dcef"))
	c.draw_circle(Vector2(621, 78), 22, Color("0f1430"))
	var lantern_center := Vector2(800, 228)
	for k in 60:
		c.draw_circle(lantern_center + Vector2(0, 30), 330.0 - k * 4.6, Color(GLOW, 0.010))

	# Rooftops along the bottom; windows nearer the lantern are more likely to be lit.
	var x := -10.0
	while x < size.x + 10:
		var w := rng.randf_range(60, 130)
		var h := rng.randf_range(70, 150)
		var top := size.y - h
		c.draw_rect(Rect2(x, top, w, h), ROOFS)
		if rng.randf() < 0.5:
			c.draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + w / 2, top - w * 0.35), Vector2(x + w, top)]), ROOFS)
		var lit_chance := clampf(1.0 - absf(x + w / 2 - lantern_center.x) / 520.0, 0.04, 0.6)
		var row_y := top + 16
		while row_y < size.y - 18:
			var col_x := x + 12
			while col_x < x + w - 16:
				if rng.randf() < lit_chance * 0.5:
					for k in 6:
						c.draw_circle(Vector2(col_x + 4, row_y + 6), 6.0 + k * 2.2, Color(GLOW, 0.03))
					c.draw_rect(Rect2(col_x, row_y, 8, 12), GLASS)
				col_x += 20
			row_y += 26
		x += w - 4
	# The guildhall tower and its window.
	c.draw_rect(Rect2(642, 250, 64, 250), ROOFS)
	c.draw_colored_polygon(PackedVector2Array([Vector2(634, 250), Vector2(674, 186), Vector2(714, 250)]), ROOFS)
	for k in 12:
		c.draw_circle(Vector2(674, 292), 8.0 + k * 2.0, Color(GLOW, 0.03))
	c.draw_rect(Rect2(668, 280, 12, 22), GLASS)

	# The lantern art is centred on (512, 476) of the icon canvas.
	var lantern_scale := 0.5
	c.draw_set_transform(lantern_center - Vector2(512, 476) * lantern_scale, 0.0, Vector2.ONE * lantern_scale)
	_draw_lantern(c, false)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# The name (ContentDB.title, split over two lines) and the trailer's opening line.
	var cream := Color("ebe5d6")
	c.draw_string(Fonts.DISPLAY, Vector2(64, 150), "Echoes of the", HORIZONTAL_ALIGNMENT_LEFT, -1, 46, cream)
	c.draw_string(Fonts.DISPLAY, Vector2(60, 236), "Forgotten City", HORIZONTAL_ALIGNMENT_LEFT, -1, 84, cream)
	c.draw_string(Fonts.DISPLAY_ITALIC, Vector2(66, 292), FEATURE_TAGLINE, HORIZONTAL_ALIGNMENT_LEFT, 470, 22,
		Color(1.0, 0.85, 0.55))


func _draw_background(c: CanvasItem) -> void:
	c.draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(CANVAS, 0), Vector2(CANVAS, CANVAS), Vector2(0, CANVAS)]),
		PackedColorArray([NIGHT_TOP, NIGHT_TOP, NIGHT_BOTTOM, NIGHT_BOTTOM]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for _i in 46:
		var star := Vector2(rng.randf_range(40, 984), rng.randf_range(40, 560))
		c.draw_circle(star, rng.randf_range(2.0, 5.0), Color(1, 1, 1, rng.randf_range(0.3, 0.9)))
	# A thin crescent moon.
	c.draw_circle(Vector2(800, 190), 46, Color("d8dcef"))
	c.draw_circle(Vector2(818, 178), 42, Color("10142c"))
	# The lantern's glow, wide and soft.
	for k in 60:  # many faint layers, so the glow fades smoothly instead of in rings
		c.draw_circle(Vector2(512, 520), 480.0 - k * 6.5, Color(GLOW, 0.011))
	# Rooftops, and the guildhall tower with its one lit window.
	var x := -20.0
	while x < CANVAS + 20:
		var w := rng.randf_range(90, 170)
		var h := rng.randf_range(120, 230)
		c.draw_rect(Rect2(x, CANVAS - h, w, h), ROOFS)
		if rng.randf() < 0.5:
			c.draw_colored_polygon(PackedVector2Array([Vector2(x, CANVAS - h), Vector2(x + w / 2, CANVAS - h - w * 0.4), Vector2(x + w, CANVAS - h)]), ROOFS)
		x += w - 6
	c.draw_rect(Rect2(790, 600, 110, 424), ROOFS)
	c.draw_colored_polygon(PackedVector2Array([Vector2(780, 600), Vector2(845, 500), Vector2(910, 600)]), ROOFS)
	for k in 16:
		c.draw_circle(Vector2(845, 660), 12.0 + k * 2.5, Color(GLOW, 0.025))
	c.draw_rect(Rect2(836, 644, 18, 30), GLASS)


# The lantern, centred, sized to sit inside the adaptive icon's safe zone.
func _draw_lantern(c: CanvasItem, monochrome: bool) -> void:
	var dark := Color.WHITE if monochrome else METAL_DARK
	var metal := Color.WHITE if monochrome else METAL
	# Handle and knob.
	c.draw_arc(Vector2(512, 318), 64, PI, TAU, 40, dark, 18)
	c.draw_line(Vector2(448, 318), Vector2(448, 336), dark, 18)
	c.draw_line(Vector2(576, 318), Vector2(576, 336), dark, 18)
	c.draw_circle(Vector2(512, 322), 20, metal)
	# Cap and rim.
	c.draw_colored_polygon(PackedVector2Array([Vector2(447, 330), Vector2(577, 330), Vector2(627, 392), Vector2(397, 392)]), dark)
	c.draw_line(Vector2(452, 336), Vector2(572, 336), metal, 6)
	c.draw_rect(Rect2(385, 388, 254, 22), metal)
	# Glass: amber edge, bright middle, white-hot flame.
	var glass := PackedVector2Array([Vector2(408, 410), Vector2(616, 410), Vector2(596, 640), Vector2(428, 640)])
	c.draw_colored_polygon(glass, Color.WHITE if monochrome else GLASS_EDGE)
	if not monochrome:
		c.draw_colored_polygon(PackedVector2Array([Vector2(436, 426), Vector2(588, 426), Vector2(572, 624), Vector2(452, 624)]), GLASS)
		c.draw_circle(Vector2(512, 566), 36, Color("ffe7a3"))
		c.draw_colored_polygon(PackedVector2Array([Vector2(486, 560), Vector2(512, 470), Vector2(538, 560)]), FLAME)
		c.draw_circle(Vector2(512, 566), 27, FLAME)
		# Frame bars over the glass.
		for bar_x in [470.0, 554.0]:
			c.draw_line(Vector2(bar_x, 412), Vector2(bar_x + (8.0 if bar_x > 512 else -8.0), 638), dark, 10)
		var outline := glass.duplicate()
		outline.append(glass[0])
		c.draw_polyline(outline, dark, 14)
	# Base.
	c.draw_rect(Rect2(398, 638, 228, 22), metal)
	c.draw_colored_polygon(PackedVector2Array([Vector2(418, 658), Vector2(606, 658), Vector2(582, 702), Vector2(442, 702)]), dark)

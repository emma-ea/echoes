extends Node2D
## One drawn prop in a room. Each type is a handful of shapes so rooms read clearly before
## real art exists. The "sprite" type draws a texture instead, which is how final art gets in.
## Props with "lit_if" get a light, and `lit` (0..1) fades their glow in and out.

const Lighting := preload("res://scripts/world/lighting.gd")
const Fonts := preload("res://scripts/ui/fonts.gd")

const WARM := Color("ffcf7a")
const WOOD := Color("6b4a34")
const WOOD_DARK := Color("4a3324")
const METAL := Color("7a6a50")
const STONE := Color("6e6672")
const PAPER := Color("d8cfb8")
const CHALK := Color(0.92, 0.92, 0.86, 0.8)

# Light placement per type: [position as a fraction of the prop's size, radius, energy].
const LIGHTS := {
	"chandelier": [Vector2(0.5, 0.72), 560.0, 1.3],
	"sconce": [Vector2(0.5, 0.35), 340.0, 1.0],
	"valve": [Vector2(0.5, 0.45), 460.0, 0.9],
	"window": [Vector2(0.5, 0.5), 320.0, 0.45],
	"street_lamp": [Vector2(0.5, 0.06), 420.0, 1.1],
	"facade": [Vector2(0.5, 0.4), 420.0, 0.6],
}
const IRON := Color("2c2c34")

var data: Dictionary = {}
var size := Vector2.ZERO
var lit := 0.0:
	set(value):
		lit = value
		if _light:
			_light.energy = _light_energy * value
			_light.visible = value > 0.01
		queue_redraw()

var _light: PointLight2D
var _light_energy := 1.0
var _texture: Texture2D
var _seed := 0


func setup(p_data: Dictionary) -> void:
	data = p_data
	var rect: Array = data.get("rect", [0, 0, 0, 0])
	position = Vector2(rect[0], rect[1])
	size = Vector2(rect[2], rect[3])
	_seed = hash(str(rect))
	if data.get("front", false):
		z_index = 5
	if data.get("type", "") == "sprite":
		_texture = load(data.get("texture", ""))
	if data.has("lit_if"):
		var spec: Array = LIGHTS.get(data.get("type", ""), [Vector2(0.5, 0.5), maxf(size.x, size.y) * 1.5, 0.8])
		_light_energy = spec[2]
		_light = Lighting.make_light(WARM, spec[1], 0.0)
		_light.position = size * spec[0]
		_light.visible = false
		add_child(_light)


static func draw_gradient_rect(item: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	item.draw_polygon(
		PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _draw() -> void:
	if data.get("flip", false):
		draw_set_transform(Vector2(size.x, 0), 0.0, Vector2(-1, 1))
	match data.get("type", ""):
		"window": _draw_window()
		"door": _draw_door()
		"archway": _draw_archway()
		"desk": _draw_desk()
		"lectern": _draw_lectern()
		"chandelier": _draw_chandelier()
		"sconce": _draw_sconce()
		"pillar": _draw_pillar()
		"chalk": _draw_chalk()
		"valve": _draw_valve()
		"pipes": _draw_pipes()
		"crate": _draw_crate()
		"rubble": _draw_rubble()
		"banner": _draw_banner()
		"shelf": _draw_shelf()
		"cobweb": _draw_cobweb()
		"street_lamp": _draw_street_lamp()
		"facade": _draw_facade()
		"notice_board": _draw_notice_board()
		"sprite":
			if _texture:
				draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false)


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	return rng


func _arch_points(rect: Rect2) -> PackedVector2Array:
	var r := rect.size.x / 2.0
	var center := Vector2(rect.position.x + r, rect.position.y + r)
	var points := PackedVector2Array([Vector2(rect.position.x, rect.end.y)])
	for i in 17:
		var angle := PI + PI * i / 16.0
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	points.append(rect.end)
	return points


func _draw_window() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), WOOD_DARK)
	var glass := Rect2(Vector2(12, 12), size - Vector2(24, 24))
	draw_gradient_rect(self, glass, Color("101a30").lerp(Color("4a3048"), lit), Color("24304a").lerp(Color("a0603a"), lit))
	# City skyline; window lights are always rolled so the skyline doesn't shift when they come on.
	var rng := _rng()
	var x := glass.position.x
	while x < glass.end.x:
		var w := minf(rng.randf_range(16, 36), glass.end.x - x)
		var h := rng.randf_range(0.25, 0.65) * glass.size.y
		var building := Rect2(x, glass.end.y - h, w, h)
		draw_rect(building, Color("0a0d16"))
		for _i in 3:
			var spot := Vector2(rng.randf_range(building.position.x, building.end.x - 4), rng.randf_range(building.position.y + 4, building.end.y - 8))
			if lit > 0.0 and w > 6:
				draw_rect(Rect2(spot, Vector2(4, 5)), Color(WARM, lit))
		x += w + 3
	draw_line(Vector2(size.x / 2, 12), Vector2(size.x / 2, size.y - 12), WOOD_DARK, 6)
	draw_line(Vector2(12, size.y * 0.42), Vector2(size.x - 12, size.y * 0.42), WOOD_DARK, 6)
	draw_rect(Rect2(-10, size.y - 4, size.x + 20, 14), WOOD)


func _draw_door() -> void:
	var outer := Rect2(Vector2.ZERO, size)
	draw_colored_polygon(_arch_points(outer), WOOD_DARK)
	var inner := outer.grow(-12)
	draw_colored_polygon(_arch_points(inner), WOOD)
	for i in range(1, 3):
		var px := inner.position.x + inner.size.x * i / 3.0
		draw_line(Vector2(px, inner.position.y + inner.size.x * 0.5), Vector2(px, inner.end.y), WOOD_DARK, 3)
	for py in [0.55, 0.8]:
		draw_line(Vector2(inner.position.x, size.y * py), Vector2(inner.end.x, size.y * py), WOOD_DARK, 3)
	draw_circle(Vector2(inner.end.x - 16, size.y * 0.62), 5, METAL.lightened(0.3))
	draw_rect(Rect2(-14, size.y - 6, size.x + 28, 10), STONE.darkened(0.3))


func _draw_archway() -> void:
	var outer := Rect2(Vector2.ZERO, size)
	draw_colored_polygon(_arch_points(outer), STONE)
	var inner := outer.grow(-16)
	inner.size.y += 16
	draw_colored_polygon(_arch_points(inner), Color("07090b"))
	# Steps going down into the dark.
	for i in 5:
		var y := size.y - 8 - i * 22.0
		var inset := 10.0 + i * 8.0
		draw_line(Vector2(inner.position.x + inset, y), Vector2(inner.end.x - inset, y), Color(0.5, 0.5, 0.5, 0.35 - i * 0.06), 3)
	var c := Vector2(size.x / 2, size.x / 2)
	for i in 6:
		var angle := PI + PI * (i + 0.5) / 6.0
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(c + dir * (size.x / 2 - 16), c + dir * (size.x / 2), STONE.darkened(0.35), 2)
	draw_rect(Rect2(size.x / 2 - 14, -6, 28, 26), STONE.lightened(0.15))


func _draw_desk() -> void:
	draw_rect(Rect2(0, 16, size.x, size.y - 16), WOOD_DARK)
	var panel_w := (size.x - 28) / 3.0
	for i in 3:
		draw_rect(Rect2(14 + i * panel_w, 32, panel_w - 12, size.y - 48), WOOD, false, 3)
	draw_rect(Rect2(-12, 0, size.x + 24, 18), WOOD)
	draw_rect(Rect2(-12, 14, size.x + 24, 4), WOOD_DARK.darkened(0.3))
	# A letter and an inkwell with a quill.
	draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.22, -2), Vector2(size.x * 0.4, -8), Vector2(size.x * 0.43, 0), Vector2(size.x * 0.25, 4)]), PAPER)
	draw_rect(Rect2(size.x * 0.6, -14, 14, 14), Color("1c1c24"))
	draw_line(Vector2(size.x * 0.6 + 7, -12), Vector2(size.x * 0.6 + 24, -40), PAPER.darkened(0.2), 2)


func _draw_lectern() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(w * 0.15, h - 14, w * 0.7, 14), WOOD_DARK)
	draw_rect(Rect2(w * 0.42, h * 0.3, w * 0.16, h * 0.7), WOOD)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, h * 0.34), Vector2(w + 6, h * 0.16), Vector2(w + 6, h * 0.26), Vector2(-6, h * 0.44)]), WOOD_DARK)
	# The open logbook.
	draw_colored_polygon(PackedVector2Array([Vector2(4, h * 0.3), Vector2(w * 0.5, h * 0.21), Vector2(w * 0.5, h * 0.17), Vector2(6, h * 0.25)]), PAPER)
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.5, h * 0.21), Vector2(w - 4, h * 0.11), Vector2(w - 6, h * 0.07), Vector2(w * 0.5, h * 0.17)]), PAPER.darkened(0.1))


func _draw_chandelier() -> void:
	var w := size.x
	var h := size.y
	var center := Vector2(w / 2, h * 0.78)
	draw_line(Vector2(w / 2, 0), Vector2(w / 2, h * 0.6), METAL.darkened(0.3), 3)
	for c in [0.06, 0.28, 0.5, 0.72, 0.94]:
		var tip := Vector2(w * c, h * 0.62)
		draw_polyline(PackedVector2Array([center, Vector2(lerpf(center.x, tip.x, 0.6), center.y + 10), Vector2(tip.x, tip.y + 16)]), METAL, 4)
		draw_rect(Rect2(tip + Vector2(-4, 0), Vector2(8, 16)), PAPER)
		if lit > 0.0:
			draw_circle(tip + Vector2(0, -6), 22, Color(WARM, 0.18 * lit))
			draw_circle(tip + Vector2(0, -5), 4, Color(1, 0.92, 0.7, lit))
	draw_circle(center, 14, METAL)
	draw_circle(center + Vector2(0, 14), 6, METAL.darkened(0.2))


func _draw_sconce() -> void:
	var w := size.x
	var h := size.y
	draw_line(Vector2(w / 2, h), Vector2(w / 2, h * 0.62), METAL, 4)
	var glass := Rect2(w * 0.15, h * 0.1, w * 0.7, h * 0.52)
	if lit > 0.0:
		draw_circle(glass.get_center(), w * 1.4, Color(WARM, 0.2 * lit))
	draw_rect(glass, Color("2a2e36").lerp(WARM, lit))
	draw_rect(glass, METAL, false, 2)
	draw_rect(Rect2(w * 0.05, 0, w * 0.9, h * 0.1), METAL)
	draw_rect(Rect2(w * 0.3, h * 0.9, w * 0.4, h * 0.1), METAL)


func _draw_pillar() -> void:
	var w := size.x
	var h := size.y
	var shaft := Rect2(w * 0.1, h * 0.06, w * 0.8, h * 0.88)
	draw_polygon(
		PackedVector2Array([shaft.position, Vector2(shaft.end.x, shaft.position.y), shaft.end, Vector2(shaft.position.x, shaft.end.y)]),
		PackedColorArray([STONE.lightened(0.1), STONE.darkened(0.35), STONE.darkened(0.35), STONE.lightened(0.1)]))
	for i in range(1, 4):
		var fx := shaft.position.x + shaft.size.x * i / 4.0
		draw_line(Vector2(fx, shaft.position.y), Vector2(fx, shaft.end.y), STONE.darkened(0.45), 2)
	draw_rect(Rect2(0, 0, w, h * 0.06), STONE.lightened(0.15))
	draw_rect(Rect2(0, h * 0.94, w, h * 0.06), STONE.lightened(0.05))
	var rng := _rng()
	var crack := PackedVector2Array([Vector2(w * 0.3, h * 0.3)])
	for i in 5:
		crack.append(crack[i] + Vector2(rng.randf_range(-6, 8), rng.randf_range(14, 30)))
	draw_polyline(crack, STONE.darkened(0.6), 1.5)


func _draw_chalk() -> void:
	var w := size.x
	var h := size.y
	var hub := Vector2(w * 0.32, h * 0.42)
	var r := h * 0.3
	draw_arc(hub, r, 0, TAU, 40, CHALK, 3)
	for i in 6:
		var a := TAU * i / 6.0
		draw_line(hub, hub + Vector2(cos(a), sin(a)) * r, CHALK, 2)
	# A woman hanging from the rim, lantern in her other hand.
	var grip := hub + Vector2(r * 0.7, -r * 0.7)
	var head := grip + Vector2(14, 16)
	var hips := head + Vector2(4, 34)
	draw_arc(head, 7, 0, TAU, 16, CHALK, 2)
	draw_line(head + Vector2(1, 7), hips, CHALK, 2)
	draw_line(head + Vector2(1, 12), grip, CHALK, 2)
	draw_line(head + Vector2(2, 14), head + Vector2(22, 26), CHALK, 2)
	draw_rect(Rect2(head + Vector2(20, 26), Vector2(7, 9)), CHALK, false, 2)
	draw_line(hips, hips + Vector2(-8, 22), CHALK, 2)
	draw_line(hips, hips + Vector2(10, 20), CHALK, 2)
	# The city's lamps, drawn dark.
	var rng := _rng()
	for _i in 7:
		var lamp := Vector2(rng.randf_range(w * 0.62, w * 0.95), rng.randf_range(h * 0.1, h * 0.7))
		draw_circle(lamp, 7, Color(0.05, 0.05, 0.07, 0.9))
		draw_arc(lamp, 7, 0, TAU, 14, CHALK, 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(w * 0.04, h * 0.88), "THE VALVE LADY MADE THE NIGHT", HORIZONTAL_ALIGNMENT_LEFT, w * 0.92, 15, CHALK)
	# The rubbed-out numbers.
	draw_rect(Rect2(w * 0.3, h * 0.92, w * 0.4, h * 0.07), Color(0.9, 0.9, 0.85, 0.18))


func _draw_valve() -> void:
	var w := size.x
	var h := size.y
	var hub := Vector2(w / 2, h * 0.45)
	var r := minf(w, h) * 0.32
	draw_rect(Rect2(-60, hub.y - 26, w + 120, 52), Color("3e4a46"))
	draw_line(Vector2(-60, hub.y - 20), Vector2(w + 60, hub.y - 20), Color("5a6a64"), 3)
	for fx in [-30.0, w * 0.15, w * 0.85, w + 30.0]:
		draw_rect(Rect2(fx - 8, hub.y - 34, 16, 68), Color("4e5c57"))
	if lit > 0.0:
		draw_circle(hub, r + 50, Color(WARM, 0.12 * lit))
	var bronze := Color("8a6a3a")
	draw_arc(hub, r, 0, TAU, 48, bronze, 14)
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		draw_line(hub, hub + Vector2(cos(a), sin(a)) * r, bronze.darkened(0.2), 8)
	draw_circle(hub, 22, bronze.lightened(0.1))
	var needle_color := WARM.lerp(Color.WHITE, 0.3) if lit > 0.5 else Color("8a8a7a")
	for i in 4:
		var dial := Vector2(w * (0.2 + 0.2 * i), h * 0.88)
		draw_circle(dial, 18, Color("1c201f"))
		draw_arc(dial, 18, 0, TAU, 24, METAL, 3)
		var needle := -PI / 2 + i * 1.3
		draw_line(dial, dial + Vector2(cos(needle), sin(needle)) * 13, needle_color, 2)


func _draw_pipes() -> void:
	for i in maxi(1, int(size.y / 40.0)):
		var y := i * 40.0 + 8
		draw_rect(Rect2(0, y, size.x, 22), Color("3a4642"))
		draw_line(Vector2(0, y + 4), Vector2(size.x, y + 4), Color("56645f"), 2)
		var joint := fmod(i * 90.0, 180.0) + 60.0
		while joint < size.x:
			draw_rect(Rect2(joint - 6, y - 4, 12, 30), Color("4a5853"))
			joint += 220.0


func _draw_crate() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, WOOD)
	for i in range(1, 3):
		draw_line(Vector2(0, size.y * i / 3.0), Vector2(size.x, size.y * i / 3.0), WOOD_DARK.lightened(0.1), 2)
	draw_line(Vector2(4, 4), size - Vector2(4, 4), WOOD_DARK, 5)
	draw_rect(rect, WOOD_DARK, false, 4)


func _draw_rubble() -> void:
	var rng := _rng()
	for _i in 9:
		var c := Vector2(rng.randf_range(0, size.x), size.y - rng.randf_range(2, size.y * 0.5))
		var s := rng.randf_range(8, 22)
		var sides := rng.randi_range(4, 6)
		var points := PackedVector2Array()
		for k in sides:
			var a := TAU * k / sides + rng.randf_range(-0.3, 0.3)
			points.append(c + Vector2(cos(a), sin(a) * 0.7) * s * rng.randf_range(0.7, 1.0))
		draw_colored_polygon(points, STONE.darkened(rng.randf_range(0.1, 0.5)))


func _draw_banner() -> void:
	var w := size.x
	var h := size.y
	draw_line(Vector2(-10, 4), Vector2(w + 10, 4), METAL, 5)
	# Tattered bottom edge, traced right to left.
	var cloth := PackedVector2Array([Vector2(4, 6), Vector2(w - 4, 6)])
	var rng := _rng()
	var teeth := 6
	for i in range(teeth, -1, -1):
		var tear := rng.randf_range(0, 40) if i % 2 == 0 else rng.randf_range(30, 70)
		cloth.append(Vector2(clampf(w * i / float(teeth), 4, w - 4), h - tear))
	draw_colored_polygon(cloth, Color("6a2e2e"))
	# The guild's faded lamp emblem.
	var gold := Color("b08a4a", 0.7)
	draw_arc(Vector2(w / 2, h * 0.32), w * 0.16, 0, TAU, 24, gold, 3)
	draw_rect(Rect2(w * 0.42, h * 0.4, w * 0.16, h * 0.14), gold)


func _draw_shelf() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), WOOD_DARK)
	var rng := _rng()
	var shelves := 4
	var shelf_h := h / shelves
	var spines := [Color("5a3a3a"), Color("3a4a5a"), Color("4a5a3a"), Color("6a5a3a"), Color("4a3a5a")]
	for s in shelves:
		var base_y := (s + 1) * shelf_h - 10
		var x := 10.0
		while x < w - 20:
			var bw := rng.randf_range(10, 22)
			var bh := rng.randf_range(shelf_h * 0.5, shelf_h * 0.8)
			if rng.randf() > 0.12:
				draw_rect(Rect2(x, base_y - bh, bw - 2, bh), spines[rng.randi() % spines.size()])
			x += bw
		draw_rect(Rect2(0, base_y, w, 10), WOOD)
	draw_rect(Rect2(0, 0, w, h), WOOD, false, 6)


func _draw_cobweb() -> void:
	var web := Color(0.85, 0.85, 0.85, 0.22)
	var radius := minf(size.x, size.y)
	for i in 6:
		var a := PI * 0.5 * i / 5.0
		draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * radius, web, 1.0)
	for ring in range(1, 5):
		var points := PackedVector2Array()
		for i in 6:
			var a := PI * 0.5 * i / 5.0
			points.append(Vector2(cos(a), sin(a)) * radius * ring / 5.0 * (0.92 if i % 2 else 1.0))
		draw_polyline(points, web, 1.0)


func _draw_street_lamp() -> void:
	var cx := size.x / 2
	draw_rect(Rect2(cx - 4, 40, 8, size.y - 40), IRON)
	draw_rect(Rect2(cx - 12, size.y - 22, 24, 22), IRON)
	draw_line(Vector2(cx - 16, 48), Vector2(cx + 16, 48), IRON, 4)
	var head := PackedVector2Array([Vector2(cx - 14, 6), Vector2(cx + 14, 6), Vector2(cx + 10, 38), Vector2(cx - 10, 38)])
	if lit > 0.0:
		draw_circle(Vector2(cx, 22), 46, Color(WARM, 0.22 * lit))
	draw_colored_polygon(head, Color("1a1e26").lerp(WARM, lit))
	var outline := head.duplicate()
	outline.append(head[0])
	draw_polyline(outline, IRON, 2)
	draw_line(Vector2(cx, 6), Vector2(cx, 38), IRON, 2)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 17, 7), Vector2(cx, -9), Vector2(cx + 17, 7)]), IRON)


func _draw_notice_board() -> void:
	var w := size.x
	draw_rect(Rect2(14, 40, 10, size.y - 40), WOOD_DARK)
	draw_rect(Rect2(w - 24, 40, 10, size.y - 40), WOOD_DARK)
	draw_rect(Rect2(-8, 8, w + 16, 12), WOOD_DARK)
	draw_rect(Rect2(0, 20, w, 120), WOOD)
	draw_rect(Rect2(0, 20, w, 120), WOOD_DARK, false, 4)
	# Old papers; the big one is the notice.
	draw_colored_polygon(PackedVector2Array([Vector2(14, 34), Vector2(54, 30), Vector2(58, 84), Vector2(16, 88)]), PAPER.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(118, 36), Vector2(146, 40), Vector2(142, 100), Vector2(114, 96)]), PAPER.darkened(0.3))
	var notice := Rect2(56, 42, 64, 86)
	draw_rect(notice, PAPER)
	for i in 6:
		var line_y := notice.position.y + 12 + i * 11
		draw_line(Vector2(notice.position.x + 8, line_y), Vector2(notice.end.x - (8 if i < 5 else 20), line_y), Color(0.2, 0.18, 0.15, 0.6), 2)
	draw_line(Vector2(notice.position.x + 8, notice.end.y - 10), Vector2(notice.end.x - 14, notice.end.y - 10), Color(0.5, 0.1, 0.1, 0.8), 2)


func _draw_facade() -> void:
	var w := size.x
	var h := size.y
	var stone := Color("575160")
	draw_rect(Rect2(0, 60, w, h - 60), stone)
	var course_y := 140.0
	while course_y < h:
		draw_line(Vector2(0, course_y), Vector2(w, course_y), stone.darkened(0.2), 2)
		course_y += 42.0
	# Pediment with the guild's lamp emblem, then the cornice.
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.2, 54), Vector2(w * 0.5, 0), Vector2(w * 0.8, 54)]), stone.lightened(0.06))
	draw_arc(Vector2(w * 0.5, 34), 10, 0, TAU, 18, Color("b08a4a"), 3)
	draw_rect(Rect2(-14, 50, w + 28, 22), stone.lightened(0.15))
	# Pilasters.
	for px in [w * 0.06, w * 0.94 - 34]:
		draw_rect(Rect2(px, 72, 34, h - 72), stone.lightened(0.08))
		draw_rect(Rect2(px - 4, 72, 42, 12), stone.lightened(0.18))
	# Sign band.
	var sign := Rect2(w * 0.2, 90, w * 0.6, 34)
	draw_rect(sign, Color("1e1a20"))
	draw_string(Fonts.DISPLAY, Vector2(sign.position.x, sign.position.y + 25), "LAMPLIGHTERS' GUILD",
		HORIZONTAL_ALIGNMENT_CENTER, sign.size.x, 24, Color("b08a4a"))
	# Upper windows, warm once the city is relit.
	for wx in [w * 0.2, w * 0.68]:
		var frame := Rect2(wx, 150, 74, 120)
		draw_colored_polygon(_arch_points(frame), WOOD_DARK)
		draw_colored_polygon(_arch_points(frame.grow(-8)), Color("0c1120").lerp(WARM, lit * 0.85))
	# The night door: arched frame, door, a speaking grille and a knocker.
	draw_colored_polygon(_arch_points(Rect2(200, 320, 170, 250)), stone.darkened(0.35))
	draw_colored_polygon(_arch_points(Rect2(215, 340, 140, 230)), WOOD_DARK)
	draw_line(Vector2(285, 410), Vector2(285, 570), WOOD_DARK.darkened(0.3), 3)
	var grille := Rect2(265, 404, 40, 26)
	draw_rect(grille, Color("08090c"))
	for gx in [275, 285, 295]:
		draw_line(Vector2(gx, grille.position.y), Vector2(gx, grille.end.y), METAL, 2)
	draw_arc(Vector2(330, 480), 9, 0, TAU, 18, METAL.lightened(0.2), 3)
	draw_rect(Rect2(190, h - 10, 190, 10), stone.lightened(0.1))

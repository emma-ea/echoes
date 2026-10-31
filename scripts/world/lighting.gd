extends RefCounted
## Shared helper for soft 2D point lights (lantern, lamps, glowing windows).

static var _texture: GradientTexture2D


static func make_light(color: Color, radius: float, energy: float) -> PointLight2D:
	if _texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.35, Color(1, 1, 1, 0.5))
		_texture = GradientTexture2D.new()
		_texture.gradient = gradient
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(0.5, 0.0)
		_texture.width = 256
		_texture.height = 256
	var light := PointLight2D.new()
	light.texture = _texture
	light.texture_scale = radius * 2.0 / 256.0
	light.color = color
	light.energy = energy
	return light

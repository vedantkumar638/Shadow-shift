extends Node2D
## Procedural parallax background: gradient sky, moon, stars, three layers of
## ruined spires and drifting motes. Everything tints violet in the Shadow.

const TILE_W := 1600.0

var camera: Camera2D
var shadow_amount := 0.0

var _layers: Array = []   # Array of Dictionary {factor, base, color, shadow_color, poly}
var _stars: Array = []    # Array of Vector3 (x 0..1, y 0..1, size)
var _motes: Array = []    # Array of Dictionary {p, v, s}


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	for i in range(140):
		_stars.append(Vector3(rng.randf(), rng.randf() * 0.7, rng.randf_range(0.6, 1.8)))
	_layers.append(_make_layer(rng, 0.08, 0.62, 260.0, Color(0.07, 0.06, 0.13), Color(0.13, 0.05, 0.2)))
	_layers.append(_make_layer(rng, 0.2, 0.74, 200.0, Color(0.05, 0.04, 0.09), Color(0.09, 0.03, 0.15)))
	_layers.append(_make_layer(rng, 0.4, 0.88, 150.0, Color(0.03, 0.025, 0.05), Color(0.05, 0.015, 0.09)))
	for i in range(60):
		_motes.append({
			"p": Vector2(rng.randf_range(0, 1400), rng.randf_range(0, 800)),
			"v": Vector2(rng.randf_range(-6, 6), rng.randf_range(-18, -6)),
			"s": rng.randf_range(1.0, 2.5),
		})


func _make_layer(rng: RandomNumberGenerator, factor: float, base: float, max_h: float, col: Color, scol: Color) -> Dictionary:
	# A skyline tile: x strictly increasing, closed at the bottom.
	var pts := PackedVector2Array()
	pts.append(Vector2(0, 0))
	var x := 0.0
	while x < TILE_W - 40.0:
		var w := minf(rng.randf_range(30, 90), TILE_W - 4.0 - x)
		var h := rng.randf_range(0.25, 1.0) * max_h
		var kind := rng.randi() % 3
		if kind == 0:
			# Spire.
			pts.append(Vector2(x + 2, -h * 0.6))
			pts.append(Vector2(x + w * 0.5, -h))
			pts.append(Vector2(x + w - 2, -h * 0.6))
		elif kind == 1:
			# Block tower.
			pts.append(Vector2(x + 1, -h * 0.8))
			pts.append(Vector2(x + w - 1, -h * 0.8))
		else:
			# Low rubble.
			pts.append(Vector2(x + w * 0.5, -h * 0.3))
		x += w
		pts.append(Vector2(x, -rng.randf_range(0.05, 0.15) * max_h))
	pts.append(Vector2(TILE_W, 0))
	pts.append(Vector2(TILE_W, 900))
	pts.append(Vector2(0, 900))
	return {"factor": factor, "base": base, "color": col, "shadow_color": scol, "poly": pts}


func _process(delta: float) -> void:
	var vs := get_viewport_rect().size
	for m in _motes:
		var p: Vector2 = m["p"]
		p += (m["v"] as Vector2) * delta
		if p.y < -10:
			p.y = vs.y + 10
		m["p"] = p
	queue_redraw()


func _draw() -> void:
	var vs := get_viewport_rect().size
	var cam := Vector2.ZERO
	if camera:
		cam = camera.get_screen_center_position()
	var s := shadow_amount

	# Sky gradient.
	var top := Color(0.02, 0.02, 0.06).lerp(Color(0.06, 0.01, 0.1), s)
	var bottom := Color(0.1, 0.07, 0.17).lerp(Color(0.22, 0.05, 0.3), s)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(vs.x, 0), vs, Vector2(0, vs.y)]),
		PackedColorArray([top, top, bottom, bottom]))

	# Stars.
	for st in _stars:
		var sp := Vector2(fposmod(st.x * vs.x * 1.5 - cam.x * 0.02, vs.x), st.y * vs.y - cam.y * 0.01)
		var tw := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 700.0 + st.x * 40.0)
		draw_circle(sp, st.z * 0.6, Color(0.8, 0.8, 1.0, 0.25 + 0.35 * tw))

	# Moon (turns into an eclipse in the Shadow).
	var mp := Vector2(vs.x * 0.78 - cam.x * 0.01, vs.y * 0.2 - cam.y * 0.01)
	for i in range(4):
		draw_circle(mp, 60.0 + i * 18.0, Color(0.7, 0.75, 1.0, 0.03).lerp(Color(0.7, 0.4, 1.0, 0.04), s))
	draw_circle(mp, 42.0, Color(0.82, 0.84, 0.95).lerp(Color(0.5, 0.3, 0.8), s))
	draw_circle(mp + Vector2(-14, -6) * (1.0 - s) + Vector2(4, 2) * s, 38.0 * s, top.lerp(Color(0.02, 0, 0.04), 0.5))

	# Skyline layers.
	for layer in _layers:
		var f: float = layer["factor"]
		var col: Color = (layer["color"] as Color).lerp(layer["shadow_color"], s)
		var base_y: float = vs.y * float(layer["base"]) - clampf(cam.y - 300.0, -600.0, 600.0) * f * 0.6
		var off := -fposmod(cam.x * f, TILE_W)
		var poly: PackedVector2Array = layer["poly"]
		var x := off
		while x < vs.x:
			var moved := PackedVector2Array()
			for p in poly:
				moved.append(p + Vector2(x, base_y))
			draw_colored_polygon(moved, col)
			x += TILE_W
		# Fog band above each layer.
		var fog := Color(0.35, 0.3, 0.55, 0.05).lerp(Color(0.6, 0.25, 0.85, 0.07), s)
		draw_rect(Rect2(0, base_y - 40, vs.x, 60), fog)

	# Drifting motes.
	for m in _motes:
		var p: Vector2 = m["p"]
		var mpx := Vector2(fposmod(p.x - cam.x * 0.3, vs.x + 40) - 20, p.y)
		var mc := Color(0.7, 0.8, 1.0, 0.35).lerp(Color(0.85, 0.55, 1.0, 0.5), s)
		draw_circle(mpx, m["s"], mc)

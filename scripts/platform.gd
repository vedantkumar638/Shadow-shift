extends AnimatableBody2D
## A level platform. Three kinds:
##  SOLID  - always solid (dark stone)
##  SHADOW - solid only while the world is in the Shadow state (violet)
##  LIGHT  - solid only while the world is in the Light state (amber)
## Platforms can optionally move back and forth (move_offset / move_period).

enum Kind { SOLID, SHADOW, LIGHT }

const SHADOW_COLOR := Color(0.62, 0.36, 1.0)
const LIGHT_COLOR := Color(1.0, 0.72, 0.28)

var kind: int = Kind.SOLID
var size := Vector2(120, 24)
var move_offset := Vector2.ZERO
var move_period := 0.0

var _origin := Vector2.ZERO
var _t := 0.0
var _active := true
var _presence := 1.0 # 0..1 visual blend between "ghost" and "solid"
var _shape: CollisionShape2D
var _rocks := PackedVector2Array()


func setup(p_kind: int, rect: Rect2, p_move_offset := Vector2.ZERO, p_period := 0.0) -> void:
	kind = p_kind
	size = rect.size
	position = rect.position + rect.size / 2.0
	_origin = position
	move_offset = p_move_offset
	move_period = p_period


func _ready() -> void:
	sync_to_physics = true
	_shape = CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = size
	_shape.shape = rect_shape
	add_child(_shape)
	_build_rocks()


func _build_rocks() -> void:
	# Jagged underside for solid floating platforms, purely decorative.
	if kind != Kind.SOLID or size.y > 60:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_origin.x * 7.0 + _origin.y * 13.0)
	var half := size / 2.0
	_rocks.append(Vector2(-half.x, half.y))
	var x := -half.x
	while x < half.x - 10.0:
		x += rng.randf_range(10.0, 22.0)
		x = min(x, half.x - 4.0)
		var depth := rng.randf_range(4.0, 22.0) * (1.0 - absf(x) / (half.x + 1.0) * 0.7)
		_rocks.append(Vector2(x, half.y + depth))
	_rocks.append(Vector2(half.x, half.y))


func is_solid_in(shadow: bool) -> bool:
	match kind:
		Kind.SHADOW:
			return shadow
		Kind.LIGHT:
			return not shadow
	return true


func set_world_state(shadow: bool) -> void:
	_active = is_solid_in(shadow)
	if _shape:
		_shape.set_deferred("disabled", not _active)


func get_rect() -> Rect2:
	return Rect2(global_position - size / 2.0, size)


func _physics_process(delta: float) -> void:
	if move_period > 0.0:
		_t += delta
		var k := 0.5 - 0.5 * cos(TAU * _t / move_period)
		position = _origin + move_offset * k
	var target := 1.0 if _active else 0.0
	_presence = move_toward(_presence, target, delta * 6.0)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(-size / 2.0, size)
	match kind:
		Kind.SOLID:
			_draw_solid(r)
		Kind.SHADOW:
			_draw_phase(r, SHADOW_COLOR)
		Kind.LIGHT:
			_draw_phase(r, LIGHT_COLOR)


func _draw_solid(r: Rect2) -> void:
	if _rocks.size() > 2:
		draw_colored_polygon(_rocks, Color(0.06, 0.05, 0.09))
	var top := Color(0.16, 0.14, 0.22)
	var bottom := Color(0.07, 0.06, 0.1)
	draw_polygon(
		PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	# Mossy/pale top edge so the walkable surface reads clearly.
	draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color(0.45, 0.42, 0.6))
	draw_rect(Rect2(r.position + Vector2(0, 3), Vector2(r.size.x, 2)), Color(0.25, 0.22, 0.35))


func _draw_phase(r: Rect2, c: Color) -> void:
	var p := _presence
	# Outer glow when solid.
	if p > 0.01:
		for i in range(3):
			var g := float(i + 1) * 4.0
			draw_rect(r.grow(g), Color(c.r, c.g, c.b, 0.07 * p))
	# Body.
	var fill := Color(c.r * 0.55, c.g * 0.55, c.b * 0.55, lerpf(0.06, 0.92, p))
	draw_rect(r, fill)
	# Inner shimmer lines.
	var t := Time.get_ticks_msec() / 1000.0
	var lines := int(r.size.x / 18.0)
	for i in range(lines):
		var x := r.position.x + fmod(i * 18.0 + t * 14.0, r.size.x)
		draw_line(Vector2(x, r.position.y + 3), Vector2(x - 6, r.end.y - 3), Color(c.r, c.g, c.b, 0.25 * p), 1.0)
	# Edge: solid line when active, dashed ghost outline when not.
	if p > 0.5:
		draw_rect(r, Color(c.r, c.g, c.b, 0.95), false, 2.0)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), c.lightened(0.4))
	else:
		var gc := Color(c.r, c.g, c.b, 0.45)
		var a := r.position
		var b := Vector2(r.end.x, r.position.y)
		var cc := r.end
		var d := Vector2(r.position.x, r.end.y)
		draw_dashed_line(a, b, gc, 1.5, 6.0)
		draw_dashed_line(b, cc, gc, 1.5, 6.0)
		draw_dashed_line(cc, d, gc, 1.5, 6.0)
		draw_dashed_line(d, a, gc, 1.5, 6.0)

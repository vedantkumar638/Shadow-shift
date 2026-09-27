extends Node2D
## Spikes (always deadly) and Shadow Thorns (deadly only in the Shadow state).

enum Kind { SPIKES, SHADOW_THORNS }

var kind: int = Kind.SPIKES
var size := Vector2(60, 16)
var _shadow := false
var _presence := 1.0


func setup(p_kind: int, rect: Rect2) -> void:
	kind = p_kind
	position = rect.position
	size = rect.size


func set_world_state(shadow: bool) -> void:
	_shadow = shadow


func is_active() -> bool:
	return kind == Kind.SPIKES or _shadow


func get_hit_rect() -> Rect2:
	# Slightly forgiving hitbox: ignore the very tips.
	return Rect2(global_position + Vector2(3, size.y * 0.35), Vector2(size.x - 6, size.y * 0.65))


func _process(delta: float) -> void:
	_presence = move_toward(_presence, 1.0 if is_active() else 0.0, delta * 6.0)
	queue_redraw()


func _draw() -> void:
	var col: Color
	if kind == Kind.SPIKES:
		col = Color(0.78, 0.74, 0.82)
	else:
		col = Color(0.75, 0.45, 1.0, lerpf(0.18, 1.0, _presence))
	var w := 14.0
	var n := int(ceil(size.x / w))
	var step := size.x / n
	var t := Time.get_ticks_msec() / 1000.0
	for i in range(n):
		var x := i * step
		var tip_y := 0.0
		if kind == Kind.SHADOW_THORNS:
			tip_y = (1.0 - _presence) * size.y * 0.6 + sin(t * 3.0 + i) * 1.5
		var pts := PackedVector2Array([Vector2(x, size.y), Vector2(x + step * 0.5, tip_y), Vector2(x + step, size.y)])
		draw_colored_polygon(pts, col.darkened(0.35))
		draw_line(Vector2(x + step * 0.5, tip_y), Vector2(x + step, size.y), col, 1.5)
	if kind == Kind.SHADOW_THORNS and _presence > 0.5:
		draw_rect(Rect2(Vector2(-4, -4), size + Vector2(8, 4)), Color(0.7, 0.4, 1.0, 0.08 * _presence))

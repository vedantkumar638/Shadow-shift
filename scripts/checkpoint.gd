extends Node2D
## A lantern. Touch it to save your progress.

var active := false
var _glow := 0.0


func get_trigger_rect() -> Rect2:
	return Rect2(global_position + Vector2(-26, -90), Vector2(52, 90))


func get_spawn_point() -> Vector2:
	return global_position + Vector2(0, -21)


func activate() -> void:
	active = true


func _process(delta: float) -> void:
	_glow = move_toward(_glow, 1.0 if active else 0.0, delta * 2.0)
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	# Post.
	draw_rect(Rect2(-2, -62, 4, 62), Color(0.2, 0.18, 0.28))
	draw_line(Vector2(0, -62), Vector2(10, -62), Color(0.2, 0.18, 0.28), 3.0)
	# Lantern.
	var lp := Vector2(10, -52)
	var flame := Color(0.35, 0.3, 0.45).lerp(Color(0.6, 0.95, 1.0), _glow)
	var flicker := 1.0 + sin(t * 9.0) * 0.08 * _glow
	if _glow > 0.0:
		draw_circle(lp, 40.0 * flicker, Color(0.5, 0.85, 1.0, 0.06 * _glow))
		draw_circle(lp, 20.0 * flicker, Color(0.5, 0.85, 1.0, 0.12 * _glow))
	draw_rect(Rect2(lp + Vector2(-6, -8), Vector2(12, 16)), Color(0.1, 0.09, 0.14))
	draw_rect(Rect2(lp + Vector2(-6, -8), Vector2(12, 16)), Color(0.4, 0.36, 0.5), false, 1.5)
	draw_circle(lp, 3.5 * flicker, flame)

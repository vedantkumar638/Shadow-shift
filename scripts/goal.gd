extends Node2D
## The exit portal.

func get_trigger_rect() -> Rect2:
	return Rect2(global_position + Vector2(-28, -100), Vector2(56, 100))


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var c := Vector2(0, -52)
	# Light beam.
	draw_polygon(PackedVector2Array([c + Vector2(-26, 0), c + Vector2(26, 0), Vector2(60, -600), Vector2(-60, -600)]),
		PackedColorArray([Color(1, 0.9, 0.7, 0.12), Color(1, 0.9, 0.7, 0.12), Color(1, 0.9, 0.7, 0.0), Color(1, 0.9, 0.7, 0.0)]))
	# Glow.
	for i in range(4):
		draw_circle(c, 70.0 - i * 14.0, Color(1.0, 0.85, 0.55, 0.05 + i * 0.03))
	# Portal ellipse.
	draw_set_transform(c, 0.0, Vector2(0.6, 1.0))
	draw_circle(Vector2.ZERO, 44.0, Color(0.02, 0.01, 0.04))
	for i in range(3):
		var a := t * (1.2 + i * 0.5) + i * 2.0
		draw_arc(Vector2.ZERO, 44.0 - i * 9.0, a, a + PI * 1.3, 32, Color(1.0, 0.82 - i * 0.12, 0.5 + i * 0.2, 0.9), 3.0)
	draw_circle(Vector2.ZERO, 10.0 + sin(t * 3.0) * 2.0, Color(1, 0.95, 0.85, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Base stones.
	draw_rect(Rect2(-34, -6, 68, 6), Color(0.3, 0.27, 0.38))

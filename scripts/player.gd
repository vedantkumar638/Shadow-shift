extends CharacterBody2D
## The player: a small hooded wanderer.
## Movement has coyote time, jump buffering and variable jump height so that
## mid-air shifting feels fair rather than frustrating.

signal jumped
signal landed

const SPEED := 260.0
const ACCEL := 2200.0
const AIR_ACCEL := 1700.0
const FRICTION := 2600.0
const GRAVITY := 1500.0
const JUMP_VELOCITY := -620.0
const MAX_FALL := 950.0
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12
const JUMP_CUT := 0.45

const BODY_SIZE := Vector2(24, 40)

var controls_enabled := false
var shadow := false
var facing := 1.0

var _coyote := 0.0
var _buffer := 0.0
var _was_on_floor := true
var _anim_t := 0.0
var _squash := Vector2.ONE
var _shadow_blend := 0.0
var _ring_t := 0.0
var _denied_t := 0.0


func _ready() -> void:
	# The CollisionShape2D (24x40) is added in the editor, in game.tscn.
	floor_snap_length = 8.0
	floor_max_angle = deg_to_rad(50)


func get_body_rect() -> Rect2:
	return Rect2(global_position - BODY_SIZE / 2.0, BODY_SIZE)


func set_shadow(value: bool, instant := false) -> void:
	shadow = value
	if instant:
		_shadow_blend = 1.0 if value else 0.0
		_ring_t = 0.0
	else:
		_ring_t = 1.0


func flash_denied() -> void:
	_denied_t = 0.3


func reset_motion() -> void:
	velocity = Vector2.ZERO
	_coyote = 0.0
	_buffer = 0.0
	_squash = Vector2.ONE


func _physics_process(delta: float) -> void:
	_anim_t += delta
	_shadow_blend = move_toward(_shadow_blend, 1.0 if shadow else 0.0, delta * 5.0)
	_ring_t = max(_ring_t - delta * 2.2, 0.0)
	_denied_t = max(_denied_t - delta, 0.0)
	_squash = _squash.lerp(Vector2.ONE, min(delta * 12.0, 1.0))

	if not visible:
		return

	var on_floor := is_on_floor()
	var dir := 0.0
	if controls_enabled:
		dir = Input.get_axis("move_left", "move_right")

	# Horizontal movement.
	if dir != 0.0:
		var accel := ACCEL if on_floor else AIR_ACCEL
		velocity.x = move_toward(velocity.x, dir * SPEED, accel * delta)
		facing = sign(dir)
	else:
		var decel := FRICTION if on_floor else AIR_ACCEL * 0.6
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)

	# Gravity + coyote time.
	if on_floor:
		_coyote = COYOTE_TIME
	else:
		_coyote -= delta
		velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL)

	# Jump buffer.
	if controls_enabled and Input.is_action_just_pressed("jump"):
		_buffer = JUMP_BUFFER
	else:
		_buffer -= delta

	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
		_squash = Vector2(0.7, 1.3)
		jumped.emit()

	# Variable jump height: releasing jump early cuts the rise.
	if controls_enabled and Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT

	move_and_slide()

	var now_on_floor := is_on_floor()
	if now_on_floor and not _was_on_floor:
		_squash = Vector2(1.3, 0.75)
		landed.emit()
	_was_on_floor = now_on_floor
	queue_redraw()


func _draw() -> void:
	var sb := _shadow_blend
	var cloak := Color(0.05, 0.04, 0.08).lerp(Color(0.32, 0.12, 0.62, 0.9), sb)
	var rim := Color(0.55, 0.85, 1.0).lerp(Color(0.85, 0.6, 1.0), sb)
	var eye := Color(0.7, 0.95, 1.0).lerp(Color(1.0, 0.85, 1.0), sb)
	if _denied_t > 0.0:
		rim = rim.lerp(Color(1, 0.25, 0.3), _denied_t / 0.3)

	# Shift ring effect.
	if _ring_t > 0.0:
		var radius := (1.0 - _ring_t) * 120.0 + 10.0
		var rc := Color(0.75, 0.5, 1.0, _ring_t) if shadow else Color(1.0, 0.8, 0.45, _ring_t)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, rc, 3.0 * _ring_t + 1.0)

	# Soft aura.
	draw_circle(Vector2(0, -2), 26.0, Color(rim.r, rim.g, rim.b, 0.06 + 0.08 * sb))

	var moving: bool = abs(velocity.x) > 20.0 and is_on_floor()
	var bob := sin(_anim_t * 16.0) * 1.5 if moving else sin(_anim_t * 3.0) * 0.6
	var sway := clampf(-velocity.x / SPEED, -1.0, 1.0) * 4.0

	draw_set_transform(Vector2(0, 20), 0.0, _squash) # scale from the feet
	var h := BODY_SIZE.y
	# Cloak (trapezoid with a ragged hem).
	var cloak_pts := PackedVector2Array([
		Vector2(-6, -h + 12 + bob),
		Vector2(6, -h + 12 + bob),
		Vector2(13 + sway * 0.5, -2),
		Vector2(8 + sway, 0),
		Vector2(3 + sway, -3),
		Vector2(-2 + sway, 0),
		Vector2(-7 + sway, -3),
		Vector2(-13 + sway * 0.5, -1),
	])
	draw_colored_polygon(cloak_pts, cloak)
	var outline := cloak_pts.duplicate()
	outline.append(cloak_pts[0])
	draw_polyline(outline, Color(rim.r, rim.g, rim.b, 0.8), 1.5)
	# Hood.
	var head := Vector2(0, -h + 10 + bob)
	draw_circle(head, 10.0, cloak)
	draw_arc(head, 10.0, PI * 0.9, TAU + PI * 0.1, 20, Color(rim.r, rim.g, rim.b, 0.9), 1.5)
	# Hood tip trailing behind.
	var tip := PackedVector2Array([head + Vector2(-4 * facing, -8), head + Vector2(-16 * facing, -4 + bob), head + Vector2(-6 * facing, 2)])
	draw_colored_polygon(tip, cloak)
	# Eyes.
	var ex := 3.5 * facing
	draw_circle(head + Vector2(ex - 2.5, 1), 1.8, eye)
	draw_circle(head + Vector2(ex + 2.5, 1), 1.8, eye)
	draw_circle(head + Vector2(ex, 1), 6.0, Color(eye.r, eye.g, eye.b, 0.12))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

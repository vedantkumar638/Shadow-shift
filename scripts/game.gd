extends Node2D
## Shadow Shift - main game controller.
##
## Builds the whole level from code (no manual dragging), owns the Light/Shadow
## world state, and runs the game loop:
##   title -> play -> (die -> respawn at checkpoint)* -> reach exit -> results.
##
## Edit the LEVEL DATA section below to change the level.

const Platform := preload("res://scripts/platform.gd")
const Hazard := preload("res://scripts/hazard.gd")
const Checkpoint := preload("res://scripts/checkpoint.gd")
const Goal := preload("res://scripts/goal.gd")
const Background := preload("res://scripts/background.gd")

enum State { TITLE, PLAYING, DYING, FINISHED }

const KILL_Y := 860.0
const SHIFT_COOLDOWN := 0.12

# ---------------------------------------------------------------------------
# LEVEL DATA
# Rect2(x, y, width, height) where (x, y) is the TOP-LEFT corner.
# Screen is 1280x720; y grows downward. Player jump: ~128px up, ~215px across.
# ---------------------------------------------------------------------------
const S := 0 # Platform.Kind.SOLID
const D := 1 # Platform.Kind.SHADOW  (solid only in Shadow)
const L := 2 # Platform.Kind.LIGHT   (solid only in Light)

const PLATFORMS := [
	# kind, rect, [optional move offset, period]
	# 0. Start area + left wall
	[S, Rect2(-60, -300, 60, 1200)],
	[S, Rect2(0, 600, 600, 300)],
	# 1. Plain jumps (learn movement)
	[S, Rect2(720, 560, 160, 24)],
	[S, Rect2(960, 500, 160, 24)],
	[S, Rect2(1200, 500, 200, 24)],
	# 2. First shift: a gap too wide to jump
	[D, Rect2(1480, 480, 140, 22)],
	[S, Rect2(1700, 460, 600, 40)],
	# 3. Amber wall - only exists in Light
	[L, Rect2(2040, 250, 30, 210)],
	# 4. Alternating staircase - shift in mid-air on every jump
	[D, Rect2(2380, 420, 120, 22)],
	[L, Rect2(2580, 380, 120, 22)],
	[D, Rect2(2780, 340, 120, 22)],
	[L, Rect2(2980, 300, 120, 22)],
	[S, Rect2(3180, 300, 220, 40)],
	# 5. Thorn bridge - bridge exists in Shadow, but thorns only hurt in Shadow
	[D, Rect2(3480, 400, 560, 20)],
	[L, Rect2(3680, 300, 110, 22)],
	[S, Rect2(4120, 400, 240, 40)],
	# 6. Ride the moving shadow platform, then leap into the Light
	[D, Rect2(4440, 420, 130, 22), Vector2(320, 0), 5.0],
	[L, Rect2(4960, 340, 140, 22)],
	[S, Rect2(5180, 340, 240, 40)],
	# 7. The climb - Shadow, Light, Shadow, Light
	[D, Rect2(5480, 260, 100, 22)],
	[L, Rect2(5320, 180, 100, 22)],
	[D, Rect2(5480, 100, 100, 22)],
	[L, Rect2(5640, 20, 120, 22)],
	# 8. The exit ledge
	[S, Rect2(5840, -40, 420, 60)],
	[S, Rect2(6260, -400, 60, 460)],
]

const SPIKES := 0
const THORNS := 1
const HAZARDS := [
	[SPIKES, Rect2(2160, 444, 56, 16)],
	[THORNS, Rect2(3660, 382, 140, 18)],
]

# x, floor y (checkpoint 0 is the start)
const CHECKPOINTS := [
	Vector2(80, 600),
	Vector2(1760, 460),
	Vector2(3260, 300),
	Vector2(4200, 400),
	Vector2(5240, 340),
]

const GOAL_POS := Vector2(6150, -40)

const HINTS := [
	[Vector2(70, 440), "A / D  or  Arrows   move\nSPACE / W / Up   jump"],
	[Vector2(1150, 330), "The gap is too wide.\nPress  SHIFT  to Shadow Shift.\nViolet paths exist only in the Shadow."],
	[Vector2(1880, 160), "Amber walls exist only in the Light.\nIn the Shadow you pass straight through."],
	[Vector2(2420, 180), "What you stand on vanishes when you shift.\nJump first - then shift in mid-air."],
	[Vector2(3440, 200), "Violet thorns only wound you in the Shadow."],
	[Vector2(4400, 250), "Ride the shadow."],
	[Vector2(5160, 240), "Climb.\nShift with every leap."],
	[Vector2(6070, -200), "EXIT"],
]

# ---------------------------------------------------------------------------

var state: int = State.TITLE
var shadow := false
var deaths := 0
var run_time := 0.0
var current_checkpoint := 0

var platforms: Array = []
var hazards: Array = []
var checkpoints: Array = []
var goal: Node2D
var player: CharacterBody2D
var camera: Camera2D
var background: Node2D
var world: Node2D

var _shift_cd := 0.0
var _shake := 0.0
var _shadow_blend := 0.0
var _flash := 0.0

# UI
var _tint: ColorRect
var _flash_rect: ColorRect
var _hud: Control
var _state_label: Label
var _state_panel: PanelContainer
var _time_label: Label
var _deaths_label: Label
var _toast: Label
var _toast_t := 0.0
var _title: Control
var _press_label: Label
var _finish: Control
var _finish_stats: Label
var _pause: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	RenderingServer.set_default_clear_color(Color(0.03, 0.02, 0.06))
	_build_background()
	_build_world()
	_build_player()
	_build_fx()
	_build_ui()
	_apply_world_state(false, true)
	_respawn()
	if Engine.has_meta("skip_title") and Engine.get_meta("skip_title"):
		_start_game()
	else:
		_show_title()


# ---------------------------------------------------------------- input ----
func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT])
	_add_action("jump", [KEY_SPACE, KEY_W, KEY_UP, KEY_Z], [JOY_BUTTON_A])
	_add_action("shift", [KEY_SHIFT, KEY_K, KEY_E, KEY_X], [JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER])
	_add_action("restart", [KEY_R], [JOY_BUTTON_Y])
	_add_action("start", [KEY_ENTER, KEY_KP_ENTER], [JOY_BUTTON_START])
	_add_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_BACK])
	# Analog stick for movement.
	for pair in [["move_left", -1.0], ["move_right", 1.0]]:
		var ev := InputEventJoypadMotion.new()
		ev.axis = JOY_AXIS_LEFT_X
		ev.axis_value = pair[1]
		InputMap.action_add_event(pair[0], ev)


func _add_action(action: String, keys: Array, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.3)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)


# ---------------------------------------------------------------- build ----
func _build_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	background = Background.new()
	layer.add_child(background)


func _build_world() -> void:
	world = Node2D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)

	for hint in HINTS:
		var lbl := Label.new()
		lbl.text = hint[1]
		lbl.position = hint[0]
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color(0.72, 0.68, 0.85, 0.85))
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		lbl.add_theme_constant_override("shadow_offset_x", 2)
		lbl.add_theme_constant_override("shadow_offset_y", 2)
		if hint[1] == "EXIT":
			lbl.add_theme_font_size_override("font_size", 34)
			lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.6))
		world.add_child(lbl)

	for data in PLATFORMS:
		var p: AnimatableBody2D = Platform.new()
		if data.size() > 2:
			p.setup(data[0], data[1], data[2], data[3])
		else:
			p.setup(data[0], data[1])
		world.add_child(p)
		platforms.append(p)

	for data in HAZARDS:
		var h: Node2D = Hazard.new()
		h.setup(data[0], data[1])
		world.add_child(h)
		hazards.append(h)

	for pos in CHECKPOINTS:
		var c: Node2D = Checkpoint.new()
		c.position = pos
		world.add_child(c)
		checkpoints.append(c)
	checkpoints[0].activate()

	goal = Goal.new()
	goal.position = GOAL_POS
	world.add_child(goal)


func _build_player() -> void:
	# Player and Camera2D are real nodes in game.tscn (made in the editor).
	player = $Player
	camera = $Player/Camera2D
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	camera.make_current()
	background.camera = camera


func _build_fx() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	_tint = ColorRect.new()
	_tint.color = Color(0.45, 0.1, 0.8, 0.0)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_tint)

	var vignette := ColorRect.new()
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float strength = 0.75;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv * vec2(1.0, 0.85));
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(0.32, 0.8, d) * strength);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	vignette.material = mat
	layer.add_child(vignette)

	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_flash_rect)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 3)
	return lbl


func _make_overlay(alpha: float) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.0, 0.03, alpha)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	return root


func _place(c: Control, preset: int, left: float, top: float, right: float, bottom: float) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = left
	c.offset_top = top
	c.offset_right = right
	c.offset_bottom = bottom


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	# HUD --------------------------------------------------------------
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)

	_state_panel = PanelContainer.new()
	_state_panel.position = Vector2(24, 20)
	_hud.add_child(_state_panel)
	_state_label = _make_label("LIGHT", 22, Color.WHITE)
	_state_panel.add_child(_state_label)

	_time_label = _make_label("00:00.00", 24, Color(0.85, 0.82, 0.95))
	_place(_time_label, Control.PRESET_TOP_RIGHT, -220, 18, -24, 50)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.add_child(_time_label)

	_deaths_label = _make_label("Deaths: 0", 18, Color(0.7, 0.65, 0.8))
	_place(_deaths_label, Control.PRESET_TOP_RIGHT, -220, 52, -24, 78)
	_deaths_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.add_child(_deaths_label)

	var help := _make_label("SHIFT  shift world     R  retry     ESC  pause", 15, Color(0.6, 0.56, 0.7, 0.8))
	_place(help, Control.PRESET_BOTTOM_WIDE, 0, -36, 0, -10)
	_hud.add_child(help)

	_toast = _make_label("", 26, Color(0.6, 0.95, 1.0))
	_place(_toast, Control.PRESET_CENTER_TOP, -300, 90, 300, 130)
	_toast.modulate.a = 0.0
	_hud.add_child(_toast)

	# Title ------------------------------------------------------------
	_title = _make_overlay(0.55)
	layer.add_child(_title)
	var tb: VBoxContainer = _title.get_child(1).get_child(0)
	var t := _make_label("SHADOW SHIFT", 84, Color(0.88, 0.8, 1.0))
	t.add_theme_color_override("font_outline_color", Color(0.4, 0.15, 0.75))
	t.add_theme_constant_override("outline_size", 10)
	tb.add_child(t)
	tb.add_child(_make_label("Step between Light and Shadow to find the way out.", 22, Color(0.75, 0.7, 0.88)))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	tb.add_child(spacer)
	tb.add_child(_make_label("A / D  or  Arrows   move        SPACE / W   jump\nSHIFT  (or K / E)   shift between Light and Shadow\nR   retry from lantern        ESC   pause", 18, Color(0.65, 0.62, 0.78)))
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 24)
	tb.add_child(spacer2)
	_press_label = _make_label("Press ENTER or SPACE to begin", 26, Color(1.0, 0.85, 0.55))
	tb.add_child(_press_label)

	# Finish -----------------------------------------------------------
	_finish = _make_overlay(0.7)
	_finish.visible = false
	layer.add_child(_finish)
	var fb: VBoxContainer = _finish.get_child(1).get_child(0)
	var ft := _make_label("YOU ESCAPED THE DARK", 60, Color(1.0, 0.88, 0.62))
	ft.add_theme_color_override("font_outline_color", Color(0.55, 0.3, 0.1))
	ft.add_theme_constant_override("outline_size", 8)
	fb.add_child(ft)
	_finish_stats = _make_label("", 26, Color(0.85, 0.8, 0.95))
	fb.add_child(_finish_stats)
	fb.add_child(_make_label("Press ENTER to play again   |   ESC to quit", 20, Color(0.65, 0.62, 0.78)))

	# Pause ------------------------------------------------------------
	_pause = _make_overlay(0.6)
	_pause.visible = false
	layer.add_child(_pause)
	var pb: VBoxContainer = _pause.get_child(1).get_child(0)
	pb.add_child(_make_label("PAUSED", 60, Color(0.88, 0.8, 1.0)))
	pb.add_child(_make_label("ESC  resume      R  retry from lantern      Q  quit", 20, Color(0.65, 0.62, 0.78)))

	_update_hud()


# ------------------------------------------------------------ game flow ----
func _show_title() -> void:
	state = State.TITLE
	player.controls_enabled = false
	_title.visible = true
	_hud.visible = false


func _start_game() -> void:
	Engine.set_meta("skip_title", false)
	state = State.PLAYING
	_title.visible = false
	_hud.visible = true
	run_time = 0.0
	deaths = 0
	player.controls_enabled = true
	_show_toast("Reach the light at the end of the ruins")


func _process(delta: float) -> void:
	# Input that must work even while paused.
	match state:
		State.TITLE:
			_press_label.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 300.0)
			if Input.is_action_just_pressed("start") or Input.is_action_just_pressed("jump"):
				_start_game()
			elif Input.is_action_just_pressed("pause"):
				get_tree().quit()
		State.FINISHED:
			if Input.is_action_just_pressed("start"):
				Engine.set_meta("skip_title", true)
				get_tree().paused = false
				get_tree().reload_current_scene()
			elif Input.is_action_just_pressed("pause"):
				get_tree().quit()
		State.PLAYING, State.DYING:
			if Input.is_action_just_pressed("pause"):
				_set_paused(not get_tree().paused)
			elif get_tree().paused:
				if Input.is_action_just_pressed("restart"):
					_set_paused(false)
					_die()
				elif Input.is_key_pressed(KEY_Q):
					get_tree().quit()

	# Visual blending.
	_shadow_blend = move_toward(_shadow_blend, 1.0 if shadow else 0.0, delta * 4.0)
	background.shadow_amount = _shadow_blend
	_tint.color.a = 0.10 * _shadow_blend
	_flash = max(_flash - delta * 3.0, 0.0)
	_flash_rect.color = Color(0.8, 0.6, 1.0, _flash * 0.25) if shadow else Color(1.0, 0.85, 0.6, _flash * 0.2)

	# Camera shake.
	_shake = max(_shake - delta * 30.0, 0.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake

	# Toast.
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t, 0.0, 1.0)

	if state == State.PLAYING and not get_tree().paused:
		run_time += delta
	_update_hud()


func _physics_process(delta: float) -> void:
	if state != State.PLAYING or get_tree().paused:
		return
	_shift_cd -= delta
	if Input.is_action_just_pressed("shift"):
		_try_shift()
	if Input.is_action_just_pressed("restart"):
		_die()
		return

	var prect: Rect2 = player.get_body_rect()
	if player.global_position.y > KILL_Y:
		_die()
		return
	for h in hazards:
		if h.is_active() and h.get_hit_rect().intersects(prect):
			_die()
			return
	for i in range(checkpoints.size()):
		if i > current_checkpoint and checkpoints[i].get_trigger_rect().intersects(prect):
			current_checkpoint = i
			checkpoints[i].activate()
			_show_toast("Lantern lit")
	if goal.get_trigger_rect().intersects(prect):
		_finish_game()


func _set_paused(value: bool) -> void:
	get_tree().paused = value
	_pause.visible = value


# ---------------------------------------------------------- shadow shift ---
func _try_shift() -> void:
	if _shift_cd > 0.0:
		return
	var target := not shadow
	# Refuse to shift if a platform would materialise inside the player.
	var prect: Rect2 = player.get_body_rect().grow(-2.0)
	for p in platforms:
		if p.is_solid_in(target) and not p.is_solid_in(shadow) and p.get_rect().intersects(prect):
			player.flash_denied()
			_shake = max(_shake, 4.0)
			return
	_shift_cd = SHIFT_COOLDOWN
	_apply_world_state(target)


func _apply_world_state(value: bool, instant := false) -> void:
	shadow = value
	for p in platforms:
		p.set_world_state(value)
	for h in hazards:
		h.set_world_state(value)
	player.set_shadow(value, instant)
	if instant:
		_shadow_blend = 1.0 if value else 0.0
	else:
		_flash = 1.0


# ---------------------------------------------------------- death/finish ---
func _die() -> void:
	if state != State.PLAYING:
		return
	state = State.DYING
	deaths += 1
	_shake = 12.0
	_spawn_burst(player.global_position)
	player.visible = false
	player.controls_enabled = false
	player.reset_motion()
	await get_tree().create_timer(0.7).timeout
	_respawn()
	state = State.PLAYING
	player.controls_enabled = true


func _respawn() -> void:
	var cp: Node2D = checkpoints[current_checkpoint]
	player.global_position = cp.get_spawn_point()
	player.reset_motion()
	player.visible = true
	_apply_world_state(false, true)
	camera.reset_smoothing()


func _spawn_burst(pos: Vector2) -> void:
	var parts := CPUParticles2D.new()
	parts.position = pos
	parts.one_shot = true
	parts.amount = 36
	parts.lifetime = 0.9
	parts.explosiveness = 1.0
	parts.direction = Vector2.UP
	parts.spread = 180.0
	parts.initial_velocity_min = 120.0
	parts.initial_velocity_max = 320.0
	parts.gravity = Vector2(0, 500)
	parts.scale_amount_min = 2.0
	parts.scale_amount_max = 5.0
	parts.color = Color(0.8, 0.6, 1.0) if shadow else Color(0.6, 0.9, 1.0)
	world.add_child(parts)
	parts.emitting = true
	get_tree().create_timer(1.5).timeout.connect(parts.queue_free)


func _finish_game() -> void:
	state = State.FINISHED
	player.controls_enabled = false
	_hud.visible = false
	_finish.visible = true
	var rank := "Survivor"
	if deaths == 0:
		rank = "Unseen - a flawless escape"
	elif deaths <= 5:
		rank = "Wraith"
	_finish_stats.text = "Time  %s\nDeaths  %d\nRank  %s" % [_format_time(run_time), deaths, rank]


# ------------------------------------------------------------------ HUD ----
func _show_toast(text: String) -> void:
	_toast.text = text
	_toast_t = 2.5


func _format_time(t: float) -> String:
	var m := int(t) / 60
	var s := fmod(t, 60.0)
	return "%02d:%05.2f" % [m, s]


var _hud_shadow_shown := -1


func _update_hud() -> void:
	if _state_label == null:
		return
	_time_label.text = _format_time(run_time)
	_deaths_label.text = "Deaths: %d" % deaths
	if _hud_shadow_shown == int(shadow):
		return
	_hud_shadow_shown = int(shadow)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	if shadow:
		_state_label.text = "SHADOW"
		sb.bg_color = Color(0.35, 0.12, 0.65, 0.85)
		sb.border_color = Color(0.8, 0.6, 1.0)
	else:
		_state_label.text = "LIGHT"
		sb.bg_color = Color(0.45, 0.3, 0.08, 0.8)
		sb.border_color = Color(1.0, 0.8, 0.45)
	sb.set_border_width_all(2)
	_state_panel.add_theme_stylebox_override("panel", sb)

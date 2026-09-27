extends SceneTree
## Brute-force playtest: for every jump in the level, try many input timings
## (direction hold, jump hold, shift frame) with the real game physics and
## report how many combinations land safely on the target.

var game

# name, start(center), start_shadow, dir, target rect (top edge = floor), jump_frames, moving_t
var CASES = [
	["start->p1", Vector2(560, 579.5), false, 1, Rect2(720,560,160,24), [0], -1.0],
	["p1->p2", Vector2(860, 539.5), false, 1, Rect2(960,500,160,24), [0], -1.0],
	["p2->p3", Vector2(1100, 479.5), false, 1, Rect2(1200,500,200,24), [0], -1.0],
	["p3->shadow1", Vector2(1380, 479.5), false, 1, Rect2(1480,480,140,22), [0], -1.0],
	["shadow1->ledge", Vector2(1600, 459.5), true, 1, Rect2(1700,460,600,40), [0], -1.0],
	["wall+spikes", Vector2(1960, 439.5), true, 1, Rect2(2226,460,74,40), [0,10,15,20,25,30,35], -1.0],
	["ledge->stair1", Vector2(2280, 439.5), true, 1, Rect2(2380,420,120,22), [0], -1.0],
	["stair1->stair2", Vector2(2480, 399.5), true, 1, Rect2(2580,380,120,22), [0], -1.0],
	["stair2->stair3", Vector2(2680, 359.5), false, 1, Rect2(2780,340,120,22), [0], -1.0],
	["stair3->stair4", Vector2(2880, 319.5), true, 1, Rect2(2980,300,120,22), [0], -1.0],
	["stair4->cp2", Vector2(3080, 279.5), false, 1, Rect2(3180,300,220,40), [0], -1.0],
	["cp2->bridge", Vector2(3380, 279.5), false, 1, Rect2(3480,400,170,20), [0], -1.0],
	["bridge->lightstep", Vector2(3630, 379.5), true, 1, Rect2(3680,300,110,22), [0], -1.0],
	["lightstep->bridge", Vector2(3770, 279.5), false, 1, Rect2(3812,400,228,20), [0,4,8], -1.0],
	["bridge->cp3", Vector2(4020, 379.5), true, 1, Rect2(4120,400,240,40), [0], -1.0],
	["cp3->mover t=3.6", Vector2(4340, 379.5), true, 1, Rect2(4440,420,450,22), [0], 3.6],
	["cp3->mover t=4.0", Vector2(4340, 379.5), true, 1, Rect2(4440,420,450,22), [0], 4.0],
	["cp3->mover t=4.4", Vector2(4340, 379.5), true, 1, Rect2(4440,420,450,22), [0], 4.4],
	["cp3->mover t=4.8", Vector2(4340, 379.5), true, 1, Rect2(4440,420,450,22), [0], 4.8],
	["cp3->mover t=0.0", Vector2(4340, 379.5), true, 1, Rect2(4440,420,450,22), [0], 0.0],
	["mover->light", Vector2(4860, 399.5), true, 1, Rect2(4960,340,140,22), [0], 2.5],
	["light->cp4", Vector2(5080, 319.5), false, 1, Rect2(5180,340,240,40), [0], -1.0],
	["cp4->climb1", Vector2(5400, 319.5), true, 1, Rect2(5480,260,100,22), [0], -1.0],
	["climb1->climb2", Vector2(5500, 239.5), true, -1, Rect2(5320,180,100,22), [0], -1.0],
	["climb2->climb3", Vector2(5400, 159.5), false, 1, Rect2(5480,100,100,22), [0], -1.0],
	["climb3->climb4", Vector2(5560, 79.5), true, 1, Rect2(5640,20,120,22), [0], -1.0],
	["climb4->exit", Vector2(5740, -0.5), false, 1, Rect2(5840,-40,420,60), [0], -1.0],
]

var DIR_HOLDS = [150, 50, 40, 30, 20]
var JUMP_HOLDS = [40, 12]
var SHIFTS = [-1, 0, 4, 8, 12, 16, 20, 24, 28, 32, 38, 44]

func _initialize():
	game = load("res://game.tscn").instantiate()
	root.add_child(game)
	_run.call_deferred()

func _release_all():
	for a in ["move_left", "move_right", "jump", "shift", "restart"]:
		Input.action_release(a)

func _trial(c, jf, dh, jh, sf) -> bool:
	_release_all()
	while game.state != game.State.PLAYING:
		await physics_frame
	game.player.visible = true
	game.player.controls_enabled = true
	game.player.global_position = c[1]
	game.player.reset_motion()
	game._apply_world_state(c[2], true)
	game._shift_cd = 0.0
	if c[6] >= 0.0:
		for p in game.platforms:
			if p.move_period > 0.0:
				p._t = c[6]
				p.position = p._origin + p.move_offset * (0.5 - 0.5 * cos(TAU * p._t / p.move_period))
	for i in 4:
		await physics_frame
	var deaths0 = game.deaths
	var dir_action = "move_right" if c[3] > 0 else "move_left"
	var airborne = false
	var target: Rect2 = c[4]
	for f in 200:
		await physics_frame
		if f == 0: Input.action_press(dir_action)
		if f == dh: Input.action_release(dir_action)
		if f == jf: Input.action_press("jump")
		if f == jf + jh: Input.action_release("jump")
		if f == sf: Input.action_press("shift")
		if f == sf + 1: Input.action_release("shift")
		await process_frame
		if game.deaths != deaths0 or game.state != game.State.PLAYING:
			_release_all()
			return false
		var on_floor = game.player.is_on_floor()
		if not on_floor:
			airborne = true
		elif airborne:
			var feet = game.player.global_position.y + 20.0
			var x = game.player.global_position.x
			return absf(feet - target.position.y) < 4.0 and x >= target.position.x - 10 and x <= target.end.x + 10
	return false

func _run():
	for i in 10:
		await process_frame
	game._start_game()
	var all_ok = true
	var only = OS.get_environment("ONLY")
	for c in CASES:
		if only != "" and not c[0].begins_with(only):
			continue
		var ok = 0
		var total = 0
		var example = ""
		for jf in c[5]:
			for dh in DIR_HOLDS:
				for jh in JUMP_HOLDS:
					for sf in SHIFTS:
						total += 1
						if await _trial(c, jf, dh, jh, sf):
							ok += 1
							if example == "":
								example = "jump@%d dirhold=%d jumphold=%d shift@%d" % [jf, dh, jh, sf]
		if ok == 0:
			all_ok = false
		print("%-20s %4d/%-4d %s   e.g. %s" % [c[0], ok, total, "OK " if ok > 0 else "IMPOSSIBLE", example])
	print("ALL REACHABLE" if all_ok else "SOME JUMPS IMPOSSIBLE")
	quit()

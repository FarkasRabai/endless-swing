extends Node2D

@onready var rod: Line2D = $World/Rod
@onready var target_dot_node: Node2D = $World/TargetDot
@onready var ring: Line2D = $World/TargetDot/ToleranceRing
@onready var camera: Camera2D = $Camera2D
@onready var score_label: Label = $UI/ScoreLabel

# =========================
# TUNING (world units)
# =========================
const STICK_LEN: float = 260.0

# Hit tolerance rules:
const BASE_TOL: float = 28.0
const START_TOL: float = 44.0
const MAX_TOL: float = 60.0

# Target dot size (visual only)
const TARGET_DOT_START_R: float = 12.0
const TARGET_DOT_MIN_R: float = 8.0

# Swing speed (rad/sec)
const SPEED_START: float = 1.45
const SPEED_MAX: float = 8.5

# Difficulty: two levers
const SPEED_SMOOTH_GAIN: float = 0.02
const SPEED_PULSE_GAIN: float = 0.07
const TOL_TIGHTEN_STEP: float = 1.2
const TOL_RELAX_STEP: float = 2.0

# Track generation
const LOOKAHEAD: int = 10
const ZIG_SPREAD: float = 0.70

# Camera follow
const CAM_LERP: float = 0.10
const PIVOT_SCREEN_Y: float = 0.72

# =========================
# STATE
# =========================
var dots: Array[Vector2] = []
var pivot_index: int = 0

var angle: float = -PI * 0.25
var swing_speed: float = SPEED_START

var hit_tol: float = START_TOL
var target_dot_r: float = TARGET_DOT_START_R

var running: bool = false
var game_over: bool = false
var score: int = 0

var cam_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	randomize()
	_setup_visuals()
	reset_game()


func _setup_visuals() -> void:
	# Rod look
	rod.width = 6.0
	rod.default_color = Color(1, 1, 1, 0.95)
	rod.antialiased = true

	# Ring look
	ring.width = 3.0
	ring.default_color = Color(1.0, 0.23, 0.83, 0.35)
	ring.antialiased = true
	ring.closed = true


func reset_game() -> void:
	running = false
	game_over = false
	score = 0
	_update_score()

	dots.clear()
	pivot_index = 0
	dots.append(Vector2.ZERO)
	_generate_next_dot()
	_ensure_lookahead()

	angle = -PI * 0.25
	swing_speed = SPEED_START

	hit_tol = START_TOL
	target_dot_r = TARGET_DOT_START_R
	_update_ring(hit_tol)

	cam_pos = _camera_target_for_pivot(dots[pivot_index])
	camera.global_position = cam_pos

	_update_target_node_position()
	_update_rod()
	queue_redraw()


func _process(delta: float) -> void:
	if running:
		angle += swing_speed * delta

	# Camera LERP
	var desired: Vector2 = _camera_target_for_pivot(dots[pivot_index])
	var t: float = 1.0 - pow(1.0 - CAM_LERP, delta * 60.0)
	cam_pos = cam_pos.lerp(desired, t)
	camera.global_position = cam_pos

	_cleanup_old_dots()
	_ensure_lookahead()

	_update_target_node_position()
	_update_rod()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_handle_tap()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_tap()


func _handle_tap() -> void:
	if not running and not game_over:
		running = true
		return

	if game_over:
		reset_game()
		running = true
		return

	if not running:
		return

	var pivot: Vector2 = dots[pivot_index]
	var target: Vector2 = dots[pivot_index + 1]
	var free_end: Vector2 = _free_end(pivot, angle)

	var d: float = free_end.distance_to(target)
	if d <= hit_tol:
		var old_pivot: Vector2 = pivot
		var new_pivot: Vector2 = target

		pivot_index += 1

		# Seamless transition
		angle = atan2(old_pivot.y - new_pivot.y, old_pivot.x - new_pivot.x)

		# Reverse swing
		swing_speed *= -1.0

		score += 1
		_update_score()

		_apply_difficulty_on_hit()
		_ensure_lookahead()
	else:
		running = false
		game_over = true


func _apply_difficulty_on_hit() -> void:
	var mag: float = absf(swing_speed)
	var target_mag: float = clampf(
		SPEED_START + (float(score) * SPEED_SMOOTH_GAIN) + pow(float(score), 0.65) * 0.012,
		SPEED_START, SPEED_MAX
	)

	mag = lerpf(mag, target_mag, 0.35)

	var sgn: float = signf(swing_speed)
	if sgn == 0.0:
		sgn = 1.0
	swing_speed = sgn * mag

	if score < 6:
		hit_tol = clampf(lerpf(hit_tol, START_TOL, 0.35), BASE_TOL, MAX_TOL)
	else:
		if randf() < 0.55:
			var before: float = absf(swing_speed)
			var pulse: float = SPEED_PULSE_GAIN * (1.0 + minf(1.2, float(score) / 40.0))
			var after: float = clampf(before + pulse, 0.0, SPEED_MAX)
			swing_speed = signf(swing_speed) * after

			if (after - before) > 0.08:
				hit_tol = clampf(hit_tol + TOL_RELAX_STEP, BASE_TOL, MAX_TOL)
		else:
			hit_tol = clampf(hit_tol - TOL_TIGHTEN_STEP, BASE_TOL, MAX_TOL)

	var tt: float = clampf(float(score) / 60.0, 0.0, 1.0)
	target_dot_r = lerpf(TARGET_DOT_START_R, TARGET_DOT_MIN_R, tt)

	_update_ring(hit_tol)


func _free_end(pivot: Vector2, ang: float) -> Vector2:
	return pivot + Vector2(cos(ang), sin(ang)) * STICK_LEN


func _update_rod() -> void:
	var pivot: Vector2 = dots[pivot_index]
	var end: Vector2 = _free_end(pivot, angle)

	rod.clear_points()
	rod.add_point(pivot)
	rod.add_point(end)


func _update_target_node_position() -> void:
	if dots.size() >= pivot_index + 2:
		target_dot_node.global_position = dots[pivot_index + 1]


func _generate_next_dot() -> void:
	var prev: Vector2 = dots[dots.size() - 1]
	var max_dx: float = STICK_LEN * ZIG_SPREAD
	var dx: float = randf_range(-max_dx, max_dx)
	var dy: float = -sqrt(maxf(0.0, STICK_LEN * STICK_LEN - dx * dx))
	dots.append(prev + Vector2(dx, dy))


func _ensure_lookahead() -> void:
	while dots.size() < pivot_index + 1 + LOOKAHEAD:
		_generate_next_dot()


func _cleanup_old_dots() -> void:
	var keep_behind: int = 4
	var min_keep: int = maxi(0, pivot_index - keep_behind)
	if min_keep > 0:
		dots = dots.slice(min_keep, dots.size() - min_keep)
		pivot_index -= min_keep


func _camera_target_for_pivot(pivot: Vector2) -> Vector2:
	var vp: Vector2 = get_viewport_rect().size
	var desired_screen: Vector2 = Vector2(vp.x * 0.5, vp.y * PIVOT_SCREEN_Y)
	var vp_half: Vector2 = vp * 0.5
	return pivot + vp_half - desired_screen


func _update_score() -> void:
	score_label.text = "Score: %d" % score


func _update_ring(radius: float) -> void:
	ring.clear_points()
	var segments: int = 64
	for i in range(segments):
		var a: float = TAU * float(i) / float(segments)
		ring.add_point(Vector2(cos(a), sin(a)) * radius)


func _draw() -> void:
	if dots.is_empty():
		return

	var pivot: Vector2 = dots[pivot_index]
	var target: Vector2 = dots[pivot_index + 1]

	draw_circle(pivot, 6.0, Color(1, 1, 1, 0.95))
	draw_circle(target, target_dot_r, Color(1.0, 0.23, 0.83, 0.95))

	var max_show: int = mini(dots.size(), pivot_index + 10)
	for i in range(pivot_index + 2, max_show):
		var a: float = clampf(1.0 - float(i - pivot_index) * 0.12, 0.18, 0.6)
		draw_circle(dots[i], 3.0, Color(1, 1, 1, a))

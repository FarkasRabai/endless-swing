extends Node
class_name Game

# ====== Core modules (drag these in Inspector) ======
@export var track: Track
@export var rod_logic: SwingRod
@export var difficulty: Difficulty

# ====== Scene references (drag these in Inspector) ======
@export var rod_line: Line2D
@export var target_dot_node: Node2D
@export var tolerance_ring: Line2D
@export var camera: Camera2D
@export var score_label: Label
@export var end_screen: EndScreen   # your EndScreen (Control) with EndScreen.gd

# ====== Camera follow settings ======
@export var cam_lerp: float = 0.10
@export_range(0.5, 0.9) var pivot_screen_y: float = 0.72

# ====== Save best score ======
const SAVE_PATH := "user://save.cfg"
const SAVE_SECTION := "scores"
const SAVE_KEY := "best"

# ====== Runtime state ======
var running: bool = false
var game_over: bool = false
var score: int = 0
var cam_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	randomize()
	_assert_wiring()
	_setup_visuals()

	# End screen wiring
	if end_screen:
		end_screen.retry_pressed.connect(_on_retry_pressed)
		end_screen.quit_pressed.connect(_on_quit_pressed)
		end_screen.hide_screen()

	reset_all()


func _assert_wiring() -> void:
	# Fail fast if something isn't wired in Inspector
	assert(track != null)
	assert(rod_logic != null)
	assert(difficulty != null)
	assert(rod_line != null)
	assert(target_dot_node != null)
	assert(tolerance_ring != null)
	assert(camera != null)
	assert(score_label != null)
	# end_screen is optional but recommended


func reset_all() -> void:
	running = false
	game_over = false
	score = 0
	_update_score()

	track.reset()
	rod_logic.reset()
	difficulty.reset()

	_update_ring(difficulty.hit_tol)
	_update_target_node_position()

	# Start camera exactly on pivot target position
	cam_pos = _camera_target_for_pivot(track.pivot())
	camera.global_position = cam_pos

	_update_rod()

	if end_screen:
		end_screen.hide_screen()


func _process(delta: float) -> void:
	if running:
		rod_logic.step(delta)

	# Camera LERP follow pivot (no snap)
	var desired: Vector2 = _camera_target_for_pivot(track.pivot())
	var t: float = 1.0 - pow(1.0 - cam_lerp, delta * 60.0)
	cam_pos = cam_pos.lerp(desired, t)
	camera.global_position = cam_pos

	# Keep track healthy
	track.cleanup(4)
	track.ensure_lookahead()

	# Update visuals
	_update_target_node_position()
	_update_rod()


func _unhandled_input(event: InputEvent) -> void:
	# NOTE: EndScreen consumes input when visible, so taps won't fall through
	if event is InputEventScreenTouch and event.pressed:
		_tap()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_tap()


func _tap() -> void:
	# Start
	if not running and not game_over:
		running = true
		return

	# Restart from end screen / game over
	if game_over:
		reset_all()
		running = true
		return

	if not running:
		return

	# Hit test
	var pivot: Vector2 = track.pivot()
	var target: Vector2 = track.target()
	var end: Vector2 = rod_logic.free_end(pivot)

	if end.distance_to(target) <= difficulty.hit_tol:
		_on_hit(pivot, target)
	else:
		_on_miss()


func _on_hit(old_pivot: Vector2, new_pivot: Vector2) -> void:
	# Advance pivot first (so track.pivot() becomes new pivot)
	track.advance_pivot()

	# Seamless rod + reverse
	rod_logic.attach_seamless(old_pivot, new_pivot)
	rod_logic.reverse()

	# Score
	score += 1
	_update_score()

	# Difficulty updates speed/tolerance/dot size
	var d := difficulty.on_hit(score, rod_logic.swing_speed)
	rod_logic.swing_speed = float(d["speed"])
	_update_ring(float(d["tol"]))

	# Extend track
	track.ensure_lookahead()


func _on_miss() -> void:
	running = false
	game_over = true

	var best: int = _update_best_score(score)

	if end_screen:
		end_screen.show_game_over(score, best)
	else:
		# Fallback: at least print
		print("Game Over. Score=", score, " Best=", best)


func _on_retry_pressed() -> void:
	reset_all()
	running = true


func _on_quit_pressed() -> void:
	get_tree().quit()


# -------------------------
# Visual updates
# -------------------------
func _setup_visuals() -> void:
	rod_line.width = 6.0
	rod_line.default_color = Color(1, 1, 1, 0.95)
	rod_line.antialiased = true

	tolerance_ring.width = 3.0
	tolerance_ring.default_color = Color(1.0, 0.23, 0.83, 0.35) # neon pink
	tolerance_ring.antialiased = true
	tolerance_ring.closed = true


func _update_rod() -> void:
	var pivot: Vector2 = track.pivot()
	var end: Vector2 = rod_logic.free_end(pivot)

	rod_line.clear_points()
	rod_line.add_point(pivot)
	rod_line.add_point(end)


func _update_target_node_position() -> void:
	target_dot_node.position = track.target()
	# Keep ring perfectly centered
	tolerance_ring.position = Vector2.ZERO
	tolerance_ring.rotation = 0.0
	tolerance_ring.scale = Vector2.ONE


func _update_ring(radius: float) -> void:
	tolerance_ring.clear_points()
	var segments: int = 64
	for i in range(segments):
		var a: float = TAU * float(i) / float(segments)
		tolerance_ring.add_point(Vector2(cos(a), sin(a)) * radius)


func _update_score() -> void:
	score_label.text = "Score: %d" % score


# -------------------------
# Camera math
# -------------------------
func _camera_target_for_pivot(pivot: Vector2) -> Vector2:
	var vp: Vector2 = camera.get_viewport_rect().size
	var desired_screen := Vector2(vp.x * 0.5, vp.y * pivot_screen_y)
	var vp_half := vp * 0.5
	return pivot + vp_half - desired_screen


# -------------------------
# Best score persistence
# -------------------------
func _load_best_score() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		return int(cfg.get_value(SAVE_SECTION, SAVE_KEY, 0))
	return 0


func _save_best_score(best: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SAVE_SECTION, SAVE_KEY, best)
	cfg.save(SAVE_PATH)


func _update_best_score(current: int) -> int:
	var best := _load_best_score()
	if current > best:
		best = current
		_save_best_score(best)
	return best
extends Node
class_name Game

@export var track: Track
@export var rod_logic: SwingRod
@export var difficulty: Difficulty

@export var rod_line: Line2D
@export var target_dot_node: Node2D
@export var tolerance_ring: Line2D
@export var camera: Camera2D
@export var score_label: Label

@export var cam_lerp: float = 0.10
@export_range(0.5, 0.9) var pivot_screen_y: float = 0.72

var running: bool = false
var game_over: bool = false
var score: int = 0
var cam_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	randomize()
	_setup_visuals()
	reset_all()

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

	cam_pos = _camera_target_for_pivot(track.pivot())
	camera.global_position = cam_pos

	_update_rod()

func _process(delta: float) -> void:
	if running:
		rod_logic.step(delta)

	# Camera LERP follow pivot (no snapping)
	var desired := _camera_target_for_pivot(track.pivot())
	var t: float = 1.0 - pow(1.0 - cam_lerp, delta * 60.0)
	cam_pos = cam_pos.lerp(desired, t)
	camera.global_position = cam_pos

	track.cleanup(4)
	track.ensure_lookahead()

	_update_target_node_position()
	_update_rod()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_tap()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_tap()

func _tap() -> void:
	if not running and not game_over:
		running = true
		return
	if game_over:
		reset_all()
		running = true
		return
	if not running:
		return

	var pivot := track.pivot()
	var target := track.target()
	var end := rod_logic.free_end(pivot)

	if end.distance_to(target) <= difficulty.hit_tol:
		# HIT
		var old_pivot := pivot
		var new_pivot := target

		track.advance_pivot()

		rod_logic.attach_seamless(old_pivot, new_pivot)
		rod_logic.reverse()

		score += 1
		_update_score()

		var d := difficulty.on_hit(score, rod_logic.swing_speed)
		rod_logic.swing_speed = d["speed"]
		_update_ring(d["tol"])

		track.ensure_lookahead()
	else:
		# MISS
		running = false
		game_over = true

func _setup_visuals() -> void:
	rod_line.width = 6.0
	rod_line.default_color = Color(1, 1, 1, 0.95)
	rod_line.antialiased = true

	tolerance_ring.width = 3.0
	tolerance_ring.default_color = Color(1.0, 0.23, 0.83, 0.35)
	tolerance_ring.antialiased = true
	tolerance_ring.closed = true

func _update_rod() -> void:
	var pivot := track.pivot()
	var end := rod_logic.free_end(pivot)

	rod_line.clear_points()
	rod_line.add_point(pivot)
	rod_line.add_point(end)

func _update_target_node_position() -> void:
	target_dot_node.global_position = track.target()

func _update_ring(radius: float) -> void:
	tolerance_ring.clear_points()
	var segments := 64
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		tolerance_ring.add_point(Vector2(cos(a), sin(a)) * radius)

func _camera_target_for_pivot(pivot: Vector2) -> Vector2:
	var vp: Vector2 = camera.get_viewport_rect().size
	var desired_screen := Vector2(vp.x * 0.5, vp.y * pivot_screen_y)
	var vp_half := vp * 0.5
	return pivot + vp_half - desired_screen

func _update_score() -> void:
	if score_label:
		score_label.text = "Score: %d" % score
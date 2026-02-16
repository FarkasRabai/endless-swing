extends Node2D
class_name WorldDraw

@export var track: Track
@export var difficulty: Difficulty

@export var pivot_radius: float = 6.0
@export var future_radius: float = 3.0
@export var future_count: int = 8

func _process(_delta: float) -> void:
	# redraw every frame (simple + reliable)
	queue_redraw()

func _draw() -> void:
	if track == null or difficulty == null:
		return
	if track.dots.is_empty():
		return

	var p_i: int = track.pivot_index
	if p_i + 1 >= track.dots.size():
		return

	var pivot: Vector2 = track.dots[p_i]
	var target: Vector2 = track.dots[p_i + 1]

	# Pivot dot (white)
	draw_circle(pivot, pivot_radius, Color(1, 1, 1, 0.95))

	# Target dot (pink) – size changes with difficulty
	draw_circle(target, difficulty.target_dot_r, Color(1.0, 0.23, 0.83, 0.95))

	# Faint future dots
	var max_i := min(p_i + 2 + future_count, track.dots.size())
	for i in range(p_i + 2, max_i):
		var a := clampf(1.0 - float(i - p_i) * 0.12, 0.18, 0.6)
		draw_circle(track.dots[i], future_radius, Color(1, 1, 1, a))
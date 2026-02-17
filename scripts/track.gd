extends Node
class_name Track

@export var stick_len: float = 260.0
@export var lookahead: int = 10
@export_range(0.1, 1.0) var zig_spread: float = 0.70

var dots: Array[Vector2] = []
var pivot_index: int = 0

func reset() -> void:
	dots.clear()
	pivot_index = 0
	dots.append(Vector2.ZERO)
	_generate_next_dot()
	ensure_lookahead()

func pivot() -> Vector2:
	return dots[pivot_index]

func target() -> Vector2:
	return dots[pivot_index + 1]

func advance_pivot() -> void:
	pivot_index += 1

func ensure_lookahead() -> void:
	while dots.size() < pivot_index + 1 + lookahead:
		_generate_next_dot()

func cleanup(keep_behind: int = 4) -> void:
	var min_keep: int = maxi(0, pivot_index - keep_behind)
	if min_keep > 0:
		dots = dots.slice(min_keep, dots.size() - min_keep)
		pivot_index -= min_keep

func _generate_next_dot() -> void:
	var prev: Vector2 = dots[dots.size() - 1]
	var max_dx: float = stick_len * zig_spread
	var dx: float = randf_range(-max_dx, max_dx)
	var dy: float = -sqrt(maxf(0.0, stick_len * stick_len - dx * dx))
	dots.append(prev + Vector2(dx, dy))

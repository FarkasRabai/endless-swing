extends Node
class_name SwingRod

@export var stick_len: float = 260.0
@export var speed_start: float = 1.45

var angle: float = -PI * 0.25
var swing_speed: float = 1.45

func reset() -> void:
	angle = -PI * 0.25
	swing_speed = speed_start

func step(delta: float) -> void:
	angle += swing_speed * delta

func free_end(pivot: Vector2) -> Vector2:
	return pivot + Vector2(cos(angle), sin(angle)) * stick_len

func attach_seamless(old_pivot: Vector2, new_pivot: Vector2) -> void:
	# Keep rod visually in place by making it point back to old pivot
	angle = atan2(old_pivot.y - new_pivot.y, old_pivot.x - new_pivot.x)

func reverse() -> void:
	swing_speed *= -1.0
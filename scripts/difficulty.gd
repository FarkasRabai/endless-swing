extends Node
class_name Difficulty

@export var base_tol: float = 28.0
@export var start_tol: float = 44.0
@export var max_tol: float = 60.0

@export var speed_start: float = 1.45
@export var speed_max: float = 8.5

@export var speed_smooth_gain: float = 0.02
@export var speed_pulse_gain: float = 0.07
@export var tol_tighten_step: float = 1.2
@export var tol_relax_step: float = 2.0

@export var target_dot_start_r: float = 12.0
@export var target_dot_min_r: float = 8.0

var hit_tol: float
var target_dot_r: float

func reset() -> void:
	hit_tol = start_tol
	target_dot_r = target_dot_start_r

func on_hit(score: int, current_speed: float) -> Dictionary:
	# Returns: { "speed": float, "tol": float, "dot_r": float }
	var sgn: float = signf(current_speed)
	if sgn == 0.0: sgn = 1.0

	var mag: float = absf(current_speed)
	var target_mag: float = clampf(
		speed_start + float(score) * speed_smooth_gain + pow(float(score), 0.65) * 0.012,
		speed_start, speed_max
	)
	mag = lerpf(mag, target_mag, 0.35)
	var new_speed: float = sgn * mag

	# Early game: keep forgiving
	if score < 6:
		hit_tol = clampf(lerpf(hit_tol, start_tol, 0.35), base_tol, max_tol)
	else:
		if randf() < 0.55:
			# Speed lever
			var before: float = absf(new_speed)
			var pulse: float = speed_pulse_gain * (1.0 + minf(1.2, float(score) / 40.0))
			var after: float = clampf(before + pulse, 0.0, speed_max)
			new_speed = signf(new_speed) * after

			# If speed jumps, compensate with slightly larger tolerance
			if (after - before) > 0.08:
				hit_tol = clampf(hit_tol + tol_relax_step, base_tol, max_tol)
		else:
			# Tolerance lever (never below base)
			hit_tol = clampf(hit_tol - tol_tighten_step, base_tol, max_tol)

	# Visual target dot size
	var t: float = clampf(float(score) / 60.0, 0.0, 1.0)
	target_dot_r = lerpf(target_dot_start_r, target_dot_min_r, t)

	return { "speed": new_speed, "tol": hit_tol, "dot_r": target_dot_r }
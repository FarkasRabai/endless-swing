extends Control
class_name EndScreen

signal retry_pressed
signal quit_pressed

@onready var dim: ColorRect = $Dim
@onready var panel: Control = $Panel
@onready var title: Label = $Panel/VBox/Title
@onready var score_label: Label = $Panel/VBox/Score
@onready var best_label: Label = $Panel/VBox/Best
@onready var retry_hint: Label = $Panel/VBox/RetryHint
@onready var btn_retry: Button = $Panel/VBox/Buttons/Retry
@onready var btn_quit: Button = $Panel/VBox/Buttons/Quit

var _anim_tween: Tween

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	btn_retry.pressed.connect(func(): emit_signal("retry_pressed"))
	btn_quit.pressed.connect(func(): emit_signal("quit_pressed"))

	# Make it feel “arcade neon”
	title.text = "GAME OVER"
	retry_hint.text = "Tap anywhere or press RETRY"

func show_game_over(score: int, best: int) -> void:
	visible = true

	# Text
	score_label.text = "Score: %d" % score
	best_label.text = "Best: %d" % best

	# Styling / colors (you can move these into Theme later)
	title.add_theme_color_override("font_color", Color(1.0, 0.23, 0.83, 1.0)) # neon pink
	score_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	best_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.70))
	retry_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))

	# Start animation state
	dim.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	panel.modulate.a = 0.0

	# Kill existing tween
	if _anim_tween and _anim_tween.is_running():
		_anim_tween.kill()

	# Animate in
	_anim_tween = create_tween()
	_anim_tween.set_parallel(true)

	_anim_tween.tween_property(dim, "modulate:a", 0.65, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(panel, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(panel, "scale", Vector2(1, 1), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Subtle hint pulse
	_pulse_hint()

func hide_screen() -> void:
	visible = false

func _pulse_hint() -> void:
	# small looping pulse of the hint opacity while visible
	var t = create_tween()
	t.set_loops()
	t.tween_property(retry_hint, "modulate:a", 0.35, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(retry_hint, "modulate:a", 0.65, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _gui_input(event: InputEvent) -> void:
	# Tap anywhere to retry
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("retry_pressed")
	elif event is InputEventScreenTouch and event.pressed:
		emit_signal("retry_pressed")
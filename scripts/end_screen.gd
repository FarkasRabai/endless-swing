extends Control
class_name EndScreen

signal retry_pressed
signal quit_pressed
signal share_pressed

# Assign these in the Inspector (drag the nodes)
@export var dim_path: NodePath
@export var card_path: NodePath

@export var title_path: NodePath
@export var subtitle_path: NodePath

@export var score_value_path: NodePath
@export var best_value_path: NodePath
@export var new_best_path: NodePath

@export var retry_button_path: NodePath
@export var quit_button_path: NodePath
@export var share_button_path: NodePath

@export var hint_path: NodePath

# Optional
@export var vignette_path: NodePath

var dim: CanvasItem
var vignette: CanvasItem
var card: Control

var title: Label
var subtitle: Label
var score_value: Label
var best_value: Label
var new_best: Label
var hint: Label

var btn_retry: BaseButton
var btn_quit: BaseButton
var btn_share: BaseButton

var _tween: Tween
var _pulse_tween: Tween


func _ready() -> void:
	_cache_nodes()
	hide_screen()

	# Connect buttons if present
	if btn_retry:
		btn_retry.pressed.connect(func(): emit_signal("retry_pressed"))
	if btn_quit:
		btn_quit.pressed.connect(func(): emit_signal("quit_pressed"))
	if btn_share:
		btn_share.pressed.connect(func(): emit_signal("share_pressed"))

	# Always force this overlay to full-screen (no editor layout fighting)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)

	if dim:
		_force_full_rect(dim)
	if vignette:
		_force_full_rect(vignette)

	# Basic copy defaults
	if title:
		title.text = "GAME OVER"
	if hint:
		hint.text = "Tap anywhere to retry"
	if new_best:
		new_best.visible = false


func _cache_nodes() -> void:
	dim = _node_from_path(dim_path) as CanvasItem
	card = _node_from_path(card_path) as Control

	vignette = _node_from_path(vignette_path) as CanvasItem

	title = _node_from_path(title_path) as Label
	subtitle = _node_from_path(subtitle_path) as Label

	score_value = _node_from_path(score_value_path) as Label
	best_value = _node_from_path(best_value_path) as Label
	new_best = _node_from_path(new_best_path) as Label

	btn_retry = _node_from_path(retry_button_path) as BaseButton
	btn_quit = _node_from_path(quit_button_path) as BaseButton
	btn_share = _node_from_path(share_button_path) as BaseButton

	hint = _node_from_path(hint_path) as Label


func show_game_over(score: int, best: int) -> void:
	# Refresh cache in case you reassigned in Inspector while running
	_cache_nodes()

	if not dim or not card or not score_value or not best_value:
		push_error("EndScreen is not wired. Assign dim/card/score/best paths in the Inspector on EndScreen node.")
		return

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	dim.mouse_filter = Control.MOUSE_FILTER_STOP

	# Fill values
	score_value.text = str(score)
	best_value.text = str(best)

	var is_new_best := (score >= best and score > 0)
	if new_best:
		new_best.visible = is_new_best
		new_best.text = "NEW BEST!"
		new_best.modulate = Color(1.0, 0.23, 0.83, 1.0)

	# Nice title/subtitle if you have those labels
	if title:
		title.text = _rank_title(score, is_new_best)
		title.add_theme_color_override("font_color", Color(1.0, 0.23, 0.83, 1.0))
	if subtitle:
		subtitle.text = _subtitle(score)
		subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	if hint:
		hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))

	# Animate in
	_kill_tweens()

	dim.modulate.a = 0.0
	if vignette:
		vignette.modulate.a = 0.0

	card.modulate.a = 0.0
	card.scale = Vector2(0.92, 0.92)
	card.rotation = deg_to_rad(-2.0)

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(dim, "modulate:a", 0.68, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if vignette:
		_tween.tween_property(vignette, "modulate:a", 0.18, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_tween.tween_property(card, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(card, "scale", Vector2(1, 1), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(card, "rotation", 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_start_pulse()


func hide_screen() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dim:
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vignette:
		vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kill_tweens()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("retry_pressed")
	elif event is InputEventScreenTouch and event.pressed:
		emit_signal("retry_pressed")


func _start_pulse() -> void:
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()

	if hint:
		_pulse_tween.tween_property(hint, "modulate:a", 0.35, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pulse_tween.tween_property(hint, "modulate:a", 0.55, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _kill_tweens() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	if _pulse_tween and _pulse_tween.is_running():
		_pulse_tween.kill()


func _force_full_rect(item: CanvasItem) -> void:
	if item is Control:
		(item as Control).set_anchors_preset(Control.PRESET_FULL_RECT)
		(item as Control).set_offsets_preset(Control.PRESET_FULL_RECT)


func _node_from_path(p: NodePath) -> Node:
	if p == NodePath():
		return null
	return get_node_or_null(p)


func _rank_title(score: int, is_new_best: bool) -> String:
	if is_new_best and score >= 10: return "LEGENDARY!"
	if score >= 35: return "UNREAL!"
	if score >= 25: return "INSANE!"
	if score >= 15: return "GREAT RUN!"
	if score >= 8:  return "NICE!"
	return "GAME OVER"


func _subtitle(score: int) -> String:
	if score >= 25: return "Your timing is getting scary good."
	if score >= 15: return "That was close — you’re in the zone."
	if score >= 8:  return "Good. Now do it again."
	return "Tap a little earlier — you’ve got this."

extends Control
class_name RoundSummaryPopup
## Toast notification shown when a golfer finishes their round.
## Queues multiple notifications and shows them one at a time.

const DISPLAY_DURATION: float = 5.0
const FADE_DURATION: float = 0.5
const PANEL_WIDTH: float = 260.0
const BOTTOM_MARGIN: float = 65.0  # Above BottomBar
const RIGHT_MARGIN: float = 20.0

var _queue: Array = []
var _panel: PanelContainer = null
var _name_label: Label = null
var _score_label: Label = null
var _mood_label: Label = null
var _fee_label: Label = null
var _dismiss_timer: SceneTreeTimer = null
var _is_showing: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_panel()
	_panel.hide()

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.92)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.3, 0.3, 0.35)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	_panel.add_child(vbox)

	var header := Label.new()
	header.text = "Round Complete"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(header)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_name_label)

	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_score_label)

	_mood_label = Label.new()
	_mood_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_mood_label)

	_fee_label = Label.new()
	_fee_label.add_theme_font_size_override("font_size", 11)
	_fee_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	vbox.add_child(_fee_label)

	# Click to dismiss
	_panel.gui_input.connect(_on_panel_input)

func queue_notification(data: Dictionary) -> void:
	_queue.append(data)
	if not _is_showing:
		_show_next()

func _show_next() -> void:
	if _queue.is_empty():
		_is_showing = false
		return

	_is_showing = true
	var data = _queue.pop_front()

	# Populate labels
	_name_label.text = data.get("name", "Golfer")

	var total_strokes = data.get("total_strokes", 0)
	var total_par = data.get("total_par", 0)
	var diff = total_strokes - total_par
	var score_text: String
	if diff == 0:
		score_text = "Score: %d (Even par)" % total_strokes
	elif diff > 0:
		score_text = "Score: %d (+%d)" % [total_strokes, diff]
	else:
		score_text = "Score: %d (%d)" % [total_strokes, diff]
	_score_label.text = score_text
	_score_label.add_theme_color_override("font_color", _get_score_color(diff))

	var mood = data.get("mood", 0.5)
	_mood_label.text = "Satisfaction: %s" % _get_mood_text(mood)
	_mood_label.add_theme_color_override("font_color", _get_mood_color(mood))

	var holes = data.get("holes_played", 0)
	var fee = data.get("green_fee", 0) * holes
	_fee_label.text = "Paid: $%d (%d holes)" % [fee, holes]

	# Position bottom-right
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.show()
	_panel.modulate.a = 1.0

	await get_tree().process_frame
	var vp_size = get_viewport().get_visible_rect().size
	_panel.position = Vector2(
		vp_size.x - _panel.size.x - RIGHT_MARGIN,
		vp_size.y - _panel.size.y - BOTTOM_MARGIN
	)

	# Auto-dismiss timer
	_dismiss_timer = get_tree().create_timer(DISPLAY_DURATION)
	_dismiss_timer.timeout.connect(_dismiss_current)

func _dismiss_current() -> void:
	if not _panel.visible:
		_is_showing = false
		_show_next()
		return

	var tween = create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(func():
		_panel.hide()
		_is_showing = false
		_show_next()
	)

func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_dismiss_current()

func _get_score_color(diff: int) -> Color:
	if diff < -1: return Color(1.0, 0.85, 0.0)
	if diff == -1: return Color(0.3, 0.9, 0.3)
	if diff == 0: return Color.WHITE
	if diff == 1: return Color(0.9, 0.6, 0.3)
	return Color(0.9, 0.3, 0.3)

func _get_mood_text(mood: float) -> String:
	if mood >= 0.8: return "Very Happy"
	if mood >= 0.6: return "Satisfied"
	if mood >= 0.4: return "Neutral"
	if mood >= 0.2: return "Dissatisfied"
	return "Frustrated"

func _get_mood_color(mood: float) -> Color:
	if mood >= 0.6: return Color(0.3, 0.9, 0.3)
	if mood >= 0.4: return Color(0.9, 0.9, 0.3)
	return Color(0.9, 0.3, 0.3)

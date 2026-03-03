extends Control
class_name NotificationToast
## NotificationToast - Toast notification system for game events
##
## Listens to EventBus.ui_notification and displays queued toast messages
## in the bottom-right corner. Supports info, success, warning, and error
## types with color-coded styling. Multiple toasts stack vertically.
## Also listens to EventFeedManager.event_added for priority-aware display.

const MAX_VISIBLE: int = 4
const TOAST_WIDTH: float = 320.0
const DISPLAY_DURATION: float = 3.5
const DISPLAY_DURATION_HIGH: float = 5.0
const FADE_DURATION: float = 0.4
const BOTTOM_MARGIN: float = 65.0  # Above BottomBar
const RIGHT_MARGIN: float = 20.0
const TOAST_SPACING: float = 6.0

var _active_toasts: Array = []  # Array of PanelContainer nodes
var _queue: Array = []  # Array of {message, type, priority} dicts
var _persistent_toasts: Array = []  # Critical toasts that don't auto-dismiss

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.ui_notification.connect(_on_notification)
	# Listen to event feed for priority-aware toast display
	EventFeedManager.event_added.connect(_on_feed_event)

func _on_notification(message: String, type: String) -> void:
	# Don't show toasts during main menu
	if GameManager.current_mode == GameManager.GameMode.MAIN_MENU:
		return
	_queue.append({"message": message, "type": type, "priority": EventFeedManager.Priority.NORMAL})
	_process_queue()

func _on_feed_event(entry: EventFeedManager.EventEntry) -> void:
	if not entry:
		return
	# INFO events: suppress toasts entirely (feed only)
	if entry.priority == EventFeedManager.Priority.INFO:
		return
	# At ULTRA speed: suppress NORMAL toasts, only show HIGH and CRITICAL
	if GameManager.current_speed == GameManager.GameSpeed.ULTRA:
		if entry.priority == EventFeedManager.Priority.NORMAL:
			return
	# Map feed priority to toast type
	var type := "info"
	match entry.priority:
		EventFeedManager.Priority.CRITICAL: type = "error"
		EventFeedManager.Priority.HIGH: type = "success"
		EventFeedManager.Priority.NORMAL: type = "info"
	_queue.append({"message": entry.message, "type": type, "priority": entry.priority})
	_process_queue()

func _process_queue() -> void:
	while not _queue.is_empty() and _active_toasts.size() < MAX_VISIBLE:
		var data = _queue.pop_front()
		_show_toast(data.message, data.type, data.get("priority", EventFeedManager.Priority.NORMAL))

func _show_toast(message: String, type: String, priority: int = EventFeedManager.Priority.NORMAL) -> void:
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var is_critical = priority == EventFeedManager.Priority.CRITICAL

	var border_color = _get_type_color(type)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.92)
	style.border_color = border_color
	style.border_width_left = 3 if not is_critical else 4
	style.border_width_top = 1 if not is_critical else 2
	style.border_width_bottom = 1 if not is_critical else 2
	style.border_width_right = 1 if not is_critical else 2
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(TOAST_WIDTH, 0)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	# Type icon
	var icon = Label.new()
	icon.text = _get_type_icon(type)
	icon.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	icon.add_theme_color_override("font_color", border_color)
	hbox.add_child(icon)

	# Message
	var label = Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(TOAST_WIDTH - 60, 0)
	hbox.add_child(label)

	# Critical toasts show a dismiss hint
	if is_critical:
		var hint = Label.new()
		hint.text = "[click]"
		hint.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
		hint.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
		hbox.add_child(hint)

	# Click to dismiss
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_dismiss_toast(panel)
	)

	add_child(panel)
	_active_toasts.append(panel)
	panel.modulate.a = 0.0

	# Position will be set after layout
	await get_tree().process_frame
	_reposition_toasts()

	# Fade in
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)

	# Critical toasts persist until clicked (no auto-dismiss)
	if is_critical:
		_persistent_toasts.append(panel)
		return

	# Determine display duration based on priority
	var duration := DISPLAY_DURATION
	if priority == EventFeedManager.Priority.HIGH:
		duration = DISPLAY_DURATION_HIGH
	elif GameManager.current_speed == GameManager.GameSpeed.FAST:
		duration = 2.0  # Shortened at FAST speed

	# Auto-dismiss timer
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(func():
		if is_instance_valid(panel) and panel.is_inside_tree():
			_dismiss_toast(panel)
	)

func _dismiss_toast(panel: PanelContainer) -> void:
	if panel not in _active_toasts:
		return
	_active_toasts.erase(panel)
	_persistent_toasts.erase(panel)

	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(func():
		if is_instance_valid(panel):
			panel.queue_free()
		_reposition_toasts()
		_process_queue()
	)

func _reposition_toasts() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	var y_offset = BOTTOM_MARGIN

	# Stack from bottom up
	for i in range(_active_toasts.size() - 1, -1, -1):
		var toast = _active_toasts[i]
		if not is_instance_valid(toast):
			continue
		toast.position = Vector2(
			vp_size.x - toast.size.x - RIGHT_MARGIN,
			vp_size.y - toast.size.y - y_offset
		)
		y_offset += toast.size.y + TOAST_SPACING

func _get_type_color(type: String) -> Color:
	match type:
		"success": return UIConstants.COLOR_SUCCESS
		"warning": return UIConstants.COLOR_WARNING
		"error": return UIConstants.COLOR_DANGER
		_: return UIConstants.COLOR_INFO

func _get_type_icon(type: String) -> String:
	match type:
		"success": return "[+]"
		"warning": return "[!]"
		"error": return "[X]"
		_: return "[i]"

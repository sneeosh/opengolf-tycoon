extends PanelContainer
class_name EventFeedPanel
## EventFeedPanel - Scrollable panel showing persistent event history
##
## Displays recent game events with category icons, timestamps, and
## click-to-navigate support. Toggles via hotkey 'N' or HUD button.
## Positioned on the right side of the screen.

signal navigate_to_golfer(golfer_id: int)
signal navigate_to_hole(hole_number: int)
signal navigate_to_position(pos: Vector2i)
signal navigate_to_panel(panel_name: String)
signal close_requested

const PANEL_WIDTH: float = 340.0
const TOP_MARGIN: float = 56.0  # Below TopHUDBar
const BOTTOM_MARGIN: float = 58.0  # Above BottomBar
const RIGHT_MARGIN: float = 4.0

var _scroll: ScrollContainer = null
var _content: VBoxContainer = null
var _filter_button: Button = null
var _filter_popup: PopupMenu = null
var _rendered_event_count: int = 0
var _event_nodes: Array = []  # Track rendered entries

func _ready() -> void:
	_build_ui()
	hide()

func _build_ui() -> void:
	# Panel style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.09, 0.94)
	style.border_color = Color(0.2, 0.25, 0.2, 0.8)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_right = 1
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 4)
	add_child(main_vbox)

	# Header row
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	main_vbox.add_child(header)

	var title = Label.new()
	title.text = "Event Feed"
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_MD)
	title.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	# Filter button
	_filter_button = Button.new()
	_filter_button.text = "Filter"
	_filter_button.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	_filter_button.custom_minimum_size = Vector2(56, 24)
	_filter_button.pressed.connect(_show_filter_popup)
	header.add_child(_filter_button)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	close_btn.custom_minimum_size = Vector2(24, 24)
	close_btn.pressed.connect(func(): close_requested.emit())
	header.add_child(close_btn)

	# Separator
	main_vbox.add_child(HSeparator.new())

	# Scrollable event list
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 2)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	# Create filter popup
	_filter_popup = PopupMenu.new()
	_filter_popup.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	_filter_popup.id_pressed.connect(_on_filter_toggled)
	add_child(_filter_popup)

func _position_panel() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	var panel_height = vp_size.y - TOP_MARGIN - BOTTOM_MARGIN
	size = Vector2(PANEL_WIDTH, panel_height)
	position = Vector2(vp_size.x - PANEL_WIDTH - RIGHT_MARGIN, TOP_MARGIN)

func toggle() -> void:
	if visible:
		hide()
		EventFeedManager.on_feed_closed()
	else:
		show()
		_position_panel()
		EventFeedManager.mark_all_read()
		refresh_events()
		# Scroll to bottom (newest events)
		await get_tree().process_frame
		if _scroll:
			_scroll.scroll_vertical = _scroll.get_v_scroll_bar().max_value as int

## Full refresh of displayed events
func refresh_events() -> void:
	# Clear existing entries
	for child in _content.get_children():
		child.queue_free()
	_event_nodes.clear()
	_rendered_event_count = 0

	# Get filtered events
	var filtered = EventFeedManager.get_filtered_events()

	# Group events by day for day headers
	var current_day := -1
	for entry in filtered:
		if entry.timestamp_day != current_day:
			current_day = entry.timestamp_day
			_add_day_header(current_day)
		_add_event_entry(entry)
		_rendered_event_count += 1

	if filtered.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No events yet"
		empty_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
		empty_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(empty_label)

## Add a single new event (called when feed is open and new event arrives)
func append_event(entry: EventFeedManager.EventEntry) -> void:
	if not visible:
		return
	if not EventFeedManager.category_filters.get(entry.category, true):
		return

	# Check if we need a new day header
	var last_day := -1
	if not EventFeedManager.events.is_empty():
		for i in range(EventFeedManager.events.size() - 2, -1, -1):
			var prev = EventFeedManager.events[i]
			if EventFeedManager.category_filters.get(prev.category, true):
				last_day = prev.timestamp_day
				break
	if entry.timestamp_day != last_day:
		_add_day_header(entry.timestamp_day)

	_add_event_entry(entry)
	_rendered_event_count += 1

	# Auto-scroll to bottom if near the bottom
	await get_tree().process_frame
	if _scroll:
		var scroll_bar = _scroll.get_v_scroll_bar()
		if scroll_bar.value >= scroll_bar.max_value - _scroll.size.y - 60:
			_scroll.scroll_vertical = scroll_bar.max_value as int

func _add_day_header(day: int) -> void:
	var header = Label.new()
	header.text = "--- Day %d ---" % day
	header.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
	header.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(header)

func _add_event_entry(entry: EventFeedManager.EventEntry) -> void:
	var row = PanelContainer.new()
	var row_style = StyleBoxFlat.new()

	# Priority-based background color
	match entry.priority:
		EventFeedManager.Priority.CRITICAL:
			row_style.bg_color = Color(0.3, 0.08, 0.08, 0.6)
		EventFeedManager.Priority.HIGH:
			row_style.bg_color = Color(0.12, 0.12, 0.06, 0.4)
		_:
			row_style.bg_color = Color(0.08, 0.09, 0.1, 0.3)

	row_style.set_corner_radius_all(3)
	row_style.content_margin_left = 6
	row_style.content_margin_right = 6
	row_style.content_margin_top = 4
	row_style.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", row_style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	row.add_child(vbox)

	# Top line: time + icon + message
	var top_line = HBoxContainer.new()
	top_line.add_theme_constant_override("separation", 6)
	vbox.add_child(top_line)

	# Timestamp
	var time_label = Label.new()
	var hour_int = int(entry.timestamp_hour)
	var minute_int = int((entry.timestamp_hour - hour_int) * 60)
	var am_pm = "AM" if hour_int < 12 else "PM"
	var display_hour = hour_int % 12
	if display_hour == 0:
		display_hour = 12
	time_label.text = "%d:%02d%s" % [display_hour, minute_int, am_pm]
	time_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
	time_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
	time_label.custom_minimum_size = Vector2(52, 0)
	top_line.add_child(time_label)

	# Category icon
	var icon_label = Label.new()
	icon_label.text = "[%s]" % entry.icon
	icon_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
	icon_label.add_theme_color_override("font_color", entry.icon_color)
	icon_label.custom_minimum_size = Vector2(22, 0)
	top_line.add_child(icon_label)

	# Message
	var msg_label = Label.new()
	msg_label.text = entry.message
	msg_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	msg_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg_label.custom_minimum_size = Vector2(200, 0)
	top_line.add_child(msg_label)

	# Navigate link (if available)
	if entry.navigate_type != EventFeedManager.NavigateType.NONE:
		var nav_btn = Button.new()
		nav_btn.text = ">"
		nav_btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
		nav_btn.custom_minimum_size = Vector2(20, 18)
		nav_btn.tooltip_text = "Click to navigate"
		var nav_type = entry.navigate_type
		var nav_value = entry.navigate_value
		nav_btn.pressed.connect(func(): _navigate(nav_type, nav_value))
		top_line.add_child(nav_btn)

	_content.add_child(row)
	_event_nodes.append(row)

func _navigate(nav_type: int, nav_value: Variant) -> void:
	match nav_type:
		EventFeedManager.NavigateType.GOLFER:
			navigate_to_golfer.emit(nav_value)
		EventFeedManager.NavigateType.HOLE:
			navigate_to_hole.emit(nav_value)
		EventFeedManager.NavigateType.POSITION:
			navigate_to_position.emit(nav_value)
		EventFeedManager.NavigateType.PANEL:
			navigate_to_panel.emit(nav_value)

func _show_filter_popup() -> void:
	_filter_popup.clear()
	for cat in EventFeedManager.Category.values():
		var cat_data = EventFeedManager.CATEGORY_DATA.get(cat, {})
		var cat_name = cat_data.get("name", "Unknown")
		var is_checked = EventFeedManager.category_filters.get(cat, true)
		_filter_popup.add_check_item(cat_name, cat)
		var idx = _filter_popup.get_item_index(cat)
		_filter_popup.set_item_checked(idx, is_checked)

	var btn_rect = _filter_button.get_global_rect()
	_filter_popup.position = Vector2i(
		int(btn_rect.position.x),
		int(btn_rect.position.y + btn_rect.size.y)
	)
	_filter_popup.popup()

func _on_filter_toggled(id: int) -> void:
	var idx = _filter_popup.get_item_index(id)
	var currently_checked = _filter_popup.is_item_checked(idx)
	_filter_popup.set_item_checked(idx, not currently_checked)
	EventFeedManager.set_category_visible(id, not currently_checked)
	refresh_events()

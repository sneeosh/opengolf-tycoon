extends PanelContainer
class_name EventFeedPanel
## EventFeedPanel - Scrollable persistent event feed
##
## Right-side panel showing recent game events with category icons,
## timestamps, filtering, and click-to-navigate.

signal close_requested
signal navigate_to_hole(hole_number: int)
signal navigate_to_position(pos: Vector2i)

const PANEL_WIDTH := 320.0
const ENTRY_SEPARATION := 2
const MAX_VISIBLE_ENTRIES := 50  # Render cap for performance

var _feed_manager: EventFeedManager = null
var _scroll: ScrollContainer = null
var _content: VBoxContainer = null
var _filter_popup: PopupMenu = null
var _unread_label: Label = null
var _title_label: Label = null
var _entry_count := 0

func set_feed_manager(manager: EventFeedManager) -> void:
	_feed_manager = manager
	_feed_manager.event_added.connect(_on_event_added)
	_feed_manager.feed_cleared.connect(_on_feed_cleared)

func _ready() -> void:
	_build_ui()
	hide()

func _build_ui() -> void:
	# Panel style
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.06, 0.08, 0.94)
	panel_style.border_color = UIConstants.COLOR_BORDER
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.set_corner_radius_all(0)
	add_theme_stylebox_override("panel", panel_style)

	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	# Title row
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	vbox.add_child(title_row)

	_title_label = Label.new()
	_title_label.text = "Event Feed"
	_title_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_MD)
	_title_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title_label)

	# Filter button
	var filter_btn = Button.new()
	filter_btn.text = "Filter"
	filter_btn.custom_minimum_size = Vector2(50, 0)
	filter_btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	filter_btn.pressed.connect(_show_filter_popup)
	title_row.add_child(filter_btn)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(28, 0)
	close_btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	close_btn.pressed.connect(func(): close_requested.emit())
	title_row.add_child(close_btn)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)

	# Scrollable event list
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", ENTRY_SEPARATION)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	# Build filter popup
	_filter_popup = PopupMenu.new()
	_filter_popup.name = "FilterPopup"
	_filter_popup.id_pressed.connect(_on_filter_toggled)
	add_child(_filter_popup)

func _show_filter_popup() -> void:
	_filter_popup.clear()
	var categories = [
		EventFeedManager.CAT_RECORD,
		EventFeedManager.CAT_ECONOMY,
		EventFeedManager.CAT_GOLFER,
		EventFeedManager.CAT_WEATHER,
		EventFeedManager.CAT_TOURNAMENT,
		EventFeedManager.CAT_MILESTONE,
		EventFeedManager.CAT_COURSE,
		EventFeedManager.CAT_DAILY,
	]
	for i in range(categories.size()):
		var cat = categories[i]
		var cat_name = EventFeedManager.get_category_name(cat)
		_filter_popup.add_check_item(cat_name, i)
		_filter_popup.set_item_checked(i, _feed_manager.category_filters.get(cat, true))
		_filter_popup.set_item_metadata(i, cat)

	_filter_popup.popup(Rect2i(
		int(global_position.x + 50), int(global_position.y + 30), 0, 0
	))

func _on_filter_toggled(id: int) -> void:
	var cat = _filter_popup.get_item_metadata(id)
	var currently_checked = _filter_popup.is_item_checked(id)
	_filter_popup.set_item_checked(id, not currently_checked)
	if _feed_manager:
		_feed_manager.set_category_filter(cat, not currently_checked)
	_rebuild_entries()

## Refresh the entire event list (used after filter changes)
func _rebuild_entries() -> void:
	for child in _content.get_children():
		child.queue_free()
	_entry_count = 0

	if not _feed_manager:
		return

	var filtered = _feed_manager.get_filtered_events()
	# Show most recent events at top
	var start = max(0, filtered.size() - MAX_VISIBLE_ENTRIES)
	for i in range(filtered.size() - 1, start - 1, -1):
		_add_entry_ui(filtered[i])

## Called when the feed is shown — rebuild + mark read
func refresh() -> void:
	_rebuild_entries()
	if _feed_manager:
		_feed_manager.mark_all_read()

func _on_event_added(entry: RefCounted) -> void:
	if not visible:
		return
	# If the category is filtered out, skip
	if _feed_manager and not _feed_manager.category_filters.get(entry.category, true):
		return
	# Prepend to top (most recent first)
	var widget = _create_entry_widget(entry)
	_content.add_child(widget)
	_content.move_child(widget, 0)
	_entry_count += 1
	# Trim old entries
	while _entry_count > MAX_VISIBLE_ENTRIES:
		var last = _content.get_child(_content.get_child_count() - 1)
		_content.remove_child(last)
		last.queue_free()
		_entry_count -= 1
	# Auto-scroll to top on new event
	_scroll.scroll_vertical = 0
	# Mark as read since panel is open
	if _feed_manager:
		_feed_manager.mark_all_read()

func _on_feed_cleared() -> void:
	for child in _content.get_children():
		child.queue_free()
	_entry_count = 0

func _add_entry_ui(entry: RefCounted) -> void:
	var widget = _create_entry_widget(entry)
	_content.add_child(widget)
	_entry_count += 1

func _create_entry_widget(entry: RefCounted) -> PanelContainer:
	var panel = PanelContainer.new()

	# Style based on priority
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.8)
	if entry.priority >= EventFeedManager.PRIORITY_HIGH:
		style.border_width_left = 3
		style.border_color = entry.color
	else:
		style.border_width_left = 2
		style.border_color = Color(0.2, 0.2, 0.2, 0.5)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	panel.add_child(vbox)

	# Timestamp row
	var time_label = Label.new()
	time_label.text = entry.get_time_string()
	time_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
	time_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
	vbox.add_child(time_label)

	# Message row with icon
	var msg_row = HBoxContainer.new()
	msg_row.add_theme_constant_override("separation", 6)
	vbox.add_child(msg_row)

	var icon_label = Label.new()
	icon_label.text = entry.icon
	icon_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	icon_label.add_theme_color_override("font_color", entry.color)
	icon_label.custom_minimum_size = Vector2(24, 0)
	msg_row.add_child(icon_label)

	var msg_label = Label.new()
	msg_label.text = entry.message
	msg_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	msg_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg_label.custom_minimum_size = Vector2(PANEL_WIDTH - 80, 0)
	msg_row.add_child(msg_label)

	# Click-to-navigate link
	if entry.navigate_target != null:
		var nav_btn = Button.new()
		nav_btn.text = "-> View"
		nav_btn.flat = true
		nav_btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
		nav_btn.add_theme_color_override("font_color", UIConstants.COLOR_INFO)
		nav_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var target = entry.navigate_target
		var action = entry.detail_action
		nav_btn.pressed.connect(func(): _navigate(target, action))
		vbox.add_child(nav_btn)

	return panel

func _navigate(target: Variant, action: String) -> void:
	if target is int:
		if action == "view_hole":
			navigate_to_hole.emit(target)
		# For golfer_id navigation, we emit the same signal with the id
		# The main scene will handle looking up the golfer position
	elif target is Vector2i:
		navigate_to_position.emit(target)

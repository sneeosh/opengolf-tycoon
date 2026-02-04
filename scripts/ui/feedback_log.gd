extends PanelContainer
class_name FeedbackLog
## FeedbackLog - Scrollable log of recent golfer feedback messages

const MAX_ENTRIES: int = 50

var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _entries: Array[Dictionary] = []

func _ready() -> void:
	custom_minimum_size = Vector2(280, 200)
	visible = false  # Hidden by default

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var vbox = VBoxContainer.new()
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "Golfer Feedback"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

	EventBus.connect("golfer_feedback", _on_golfer_feedback)

func _on_golfer_feedback(_golfer_id: int, golfer_name: String, message: String, fb_type: String) -> void:
	var entry = {
		"time": GameManager.get_time_string(),
		"name": golfer_name,
		"message": message,
		"type": fb_type,
	}
	_entries.append(entry)

	# Trim to max
	while _entries.size() > MAX_ENTRIES:
		_entries.pop_front()
		if _list.get_child_count() > 0:
			_list.get_child(0).queue_free()

	_add_entry_label(entry)

	# Auto-scroll to bottom
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func _add_entry_label(entry: Dictionary) -> void:
	var label = Label.new()
	label.text = "[%s] %s: %s" % [entry["time"], entry["name"], entry["message"]]
	label.add_theme_font_size_override("font_size", 11)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	match entry["type"]:
		"positive":
			label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
		"negative":
			label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
		_:
			label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	_list.add_child(label)

func toggle() -> void:
	visible = not visible

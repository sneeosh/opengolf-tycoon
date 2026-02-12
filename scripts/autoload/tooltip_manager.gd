extends CanvasLayer
## TooltipManager - Rich tooltip system with delay and positioning

signal tooltip_shown(data: Dictionary)
signal tooltip_hidden()

# Configuration
const SHOW_DELAY: float = 0.3
const HIDE_DELAY: float = 0.1
const MOUSE_OFFSET: Vector2 = Vector2(16, 16)
const VIEWPORT_MARGIN: int = 10

# State
var _tooltip_container: PanelContainer
var _title_label: Label
var _description_label: RichTextLabel
var _footer_container: HBoxContainer
var _cost_label: Label
var _shortcut_label: Label
var _separator: HSeparator

var _show_timer: Timer
var _hide_timer: Timer
var _pending_data: Dictionary = {}
var _is_visible: bool = false
var _anchor_control: Control = null

func _ready() -> void:
	layer = 100  # Above everything
	_create_tooltip_ui()
	_create_timers()

	# Connect to EventBus if available
	if Engine.has_singleton("EventBus") or has_node("/root/EventBus"):
		var event_bus = get_node_or_null("/root/EventBus")
		if event_bus:
			if event_bus.has_signal("tooltip_requested"):
				event_bus.tooltip_requested.connect(_on_legacy_tooltip_requested)
			if event_bus.has_signal("tooltip_hidden"):
				event_bus.tooltip_hidden.connect(hide_tooltip)

func _create_tooltip_ui() -> void:
	_tooltip_container = PanelContainer.new()
	_tooltip_container.visible = false
	_tooltip_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_container.z_index = 100

	# Apply tooltip style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.07, 0.98)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.3, 1)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	_tooltip_container.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	_tooltip_container.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", Color(1, 1, 1))
	vbox.add_child(_title_label)

	# Description
	_description_label = RichTextLabel.new()
	_description_label.bbcode_enabled = true
	_description_label.fit_content = true
	_description_label.scroll_active = false
	_description_label.add_theme_font_size_override("normal_font_size", 12)
	_description_label.add_theme_color_override("default_color", Color(0.7, 0.7, 0.7))
	_description_label.custom_minimum_size = Vector2(180, 0)
	vbox.add_child(_description_label)

	# Separator
	_separator = HSeparator.new()
	_separator.visible = false
	vbox.add_child(_separator)

	# Footer
	_footer_container = HBoxContainer.new()
	_footer_container.visible = false
	vbox.add_child(_footer_container)

	_cost_label = Label.new()
	_cost_label.add_theme_font_size_override("font_size", 12)
	_cost_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.4))
	_cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer_container.add_child(_cost_label)

	_shortcut_label = Label.new()
	_shortcut_label.add_theme_font_size_override("font_size", 11)
	_shortcut_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_shortcut_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_footer_container.add_child(_shortcut_label)

	add_child(_tooltip_container)

func _create_timers() -> void:
	_show_timer = Timer.new()
	_show_timer.one_shot = true
	_show_timer.timeout.connect(_on_show_timer_timeout)
	add_child(_show_timer)

	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	_hide_timer.timeout.connect(_on_hide_timer_timeout)
	add_child(_hide_timer)

func _process(_delta: float) -> void:
	if _is_visible:
		_update_position()

func _update_position() -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var viewport_size = get_viewport().get_visible_rect().size
	var tooltip_size = _tooltip_container.size

	var pos = mouse_pos + MOUSE_OFFSET

	# Keep within viewport bounds
	if pos.x + tooltip_size.x > viewport_size.x - VIEWPORT_MARGIN:
		pos.x = mouse_pos.x - tooltip_size.x - MOUSE_OFFSET.x
	if pos.y + tooltip_size.y > viewport_size.y - VIEWPORT_MARGIN:
		pos.y = mouse_pos.y - tooltip_size.y - MOUSE_OFFSET.y

	pos.x = maxf(pos.x, VIEWPORT_MARGIN)
	pos.y = maxf(pos.y, VIEWPORT_MARGIN)

	_tooltip_container.position = pos

# =============================================================================
# PUBLIC API
# =============================================================================

## Show tooltip with rich data
## data keys: title, description, cost, maintenance, shortcut
func show_tooltip(data: Dictionary, anchor: Control = null) -> void:
	_pending_data = data
	_anchor_control = anchor
	_hide_timer.stop()
	_show_timer.start(SHOW_DELAY)

## Show tooltip immediately at position
func show_tooltip_at(data: Dictionary, position: Vector2) -> void:
	_pending_data = data
	_anchor_control = null
	_hide_timer.stop()
	_display_tooltip()
	_tooltip_container.position = position

## Hide tooltip with delay
func hide_tooltip() -> void:
	_show_timer.stop()
	if _is_visible:
		_hide_timer.start(HIDE_DELAY)

## Hide tooltip immediately
func hide_tooltip_immediate() -> void:
	_show_timer.stop()
	_hide_timer.stop()
	_tooltip_container.visible = false
	_is_visible = false
	_pending_data = {}
	tooltip_hidden.emit()

## Create a simple tooltip data dictionary
static func make_tooltip(title: String, description: String = "", cost: int = 0, maintenance: int = 0, shortcut: String = "") -> Dictionary:
	return {
		"title": title,
		"description": description,
		"cost": cost,
		"maintenance": maintenance,
		"shortcut": shortcut
	}

# =============================================================================
# INTERNAL
# =============================================================================

func _on_show_timer_timeout() -> void:
	_display_tooltip()

func _on_hide_timer_timeout() -> void:
	hide_tooltip_immediate()

func _display_tooltip() -> void:
	if _pending_data.is_empty():
		return

	var data = _pending_data

	# Title
	_title_label.text = data.get("title", "")
	_title_label.visible = not _title_label.text.is_empty()

	# Description
	var desc = data.get("description", "")
	_description_label.text = desc
	_description_label.visible = not desc.is_empty()

	# Footer (cost and shortcut)
	var cost = data.get("cost", 0)
	var maintenance = data.get("maintenance", 0)
	var shortcut = data.get("shortcut", "")

	var has_footer = cost > 0 or maintenance > 0 or not shortcut.is_empty()
	_separator.visible = has_footer and (_title_label.visible or _description_label.visible)
	_footer_container.visible = has_footer

	if has_footer:
		var cost_text = ""
		if cost > 0:
			cost_text = "Cost: $%d" % cost
		if maintenance > 0:
			if cost_text.is_empty():
				cost_text = "Maint: $%d/day" % maintenance
			else:
				cost_text += " | Maint: $%d/day" % maintenance
		_cost_label.text = cost_text
		_cost_label.visible = not cost_text.is_empty()

		if not shortcut.is_empty():
			_shortcut_label.text = "[%s]" % shortcut
			_shortcut_label.visible = true
		else:
			_shortcut_label.visible = false

	_tooltip_container.visible = true
	_is_visible = true

	# Force size recalculation
	_tooltip_container.reset_size()

	# Position after making visible
	await get_tree().process_frame
	_update_position()

	tooltip_shown.emit(data)

func _on_legacy_tooltip_requested(text: String, position: Vector2) -> void:
	# Support legacy EventBus tooltip_requested signal
	show_tooltip_at({"title": "", "description": text}, position)

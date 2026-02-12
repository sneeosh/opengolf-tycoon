extends Button
class_name ToolButton
## ToolButton - Icon + label + hotkey button with rich tooltip support

signal tool_pressed(tool_type)

# Configuration
@export var tool_type: Variant  # Can be int (TerrainType) or String (special tools)
@export var tool_name: String = ""
@export var tool_icon: String = ""
@export var hotkey: String = ""
@export var tool_description: String = ""
@export var cost: int = 0
@export var maintenance: int = 0

# Visual state
var _is_selected: bool = false

# Style cache
var _style_normal: StyleBoxFlat
var _style_hover: StyleBoxFlat
var _style_pressed: StyleBoxFlat
var _style_selected: StyleBoxFlat

func _ready() -> void:
	_create_styles()
	_update_button()
	_connect_signals()

func _create_styles() -> void:
	# Normal state
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = UIConstants.COLOR_BG_BUTTON
	_style_normal.corner_radius_top_left = 4
	_style_normal.corner_radius_top_right = 4
	_style_normal.corner_radius_bottom_right = 4
	_style_normal.corner_radius_bottom_left = 4
	_style_normal.content_margin_left = 8
	_style_normal.content_margin_right = 8
	_style_normal.content_margin_top = 6
	_style_normal.content_margin_bottom = 6
	_style_normal.border_width_left = 1
	_style_normal.border_width_top = 1
	_style_normal.border_width_right = 1
	_style_normal.border_width_bottom = 1
	_style_normal.border_color = UIConstants.COLOR_BORDER

	# Hover state
	_style_hover = StyleBoxFlat.new()
	_style_hover.bg_color = UIConstants.COLOR_PRIMARY_HOVER
	_style_hover.corner_radius_top_left = 4
	_style_hover.corner_radius_top_right = 4
	_style_hover.corner_radius_bottom_right = 4
	_style_hover.corner_radius_bottom_left = 4
	_style_hover.content_margin_left = 8
	_style_hover.content_margin_right = 8
	_style_hover.content_margin_top = 6
	_style_hover.content_margin_bottom = 6
	_style_hover.border_width_left = 1
	_style_hover.border_width_top = 1
	_style_hover.border_width_right = 1
	_style_hover.border_width_bottom = 1
	_style_hover.border_color = UIConstants.COLOR_PRIMARY

	# Pressed state
	_style_pressed = StyleBoxFlat.new()
	_style_pressed.bg_color = UIConstants.COLOR_PRIMARY_PRESSED
	_style_pressed.corner_radius_top_left = 4
	_style_pressed.corner_radius_top_right = 4
	_style_pressed.corner_radius_bottom_right = 4
	_style_pressed.corner_radius_bottom_left = 4
	_style_pressed.content_margin_left = 8
	_style_pressed.content_margin_right = 8
	_style_pressed.content_margin_top = 6
	_style_pressed.content_margin_bottom = 6
	_style_pressed.border_width_left = 1
	_style_pressed.border_width_top = 1
	_style_pressed.border_width_right = 1
	_style_pressed.border_width_bottom = 1
	_style_pressed.border_color = UIConstants.COLOR_PRIMARY

	# Selected state
	_style_selected = StyleBoxFlat.new()
	_style_selected.bg_color = UIConstants.COLOR_PRIMARY
	_style_selected.corner_radius_top_left = 4
	_style_selected.corner_radius_top_right = 4
	_style_selected.corner_radius_bottom_right = 4
	_style_selected.corner_radius_bottom_left = 4
	_style_selected.content_margin_left = 8
	_style_selected.content_margin_right = 8
	_style_selected.content_margin_top = 6
	_style_selected.content_margin_bottom = 6
	_style_selected.border_width_left = 2
	_style_selected.border_width_top = 2
	_style_selected.border_width_right = 2
	_style_selected.border_width_bottom = 2
	_style_selected.border_color = UIConstants.COLOR_SUCCESS

	_apply_styles()

func _apply_styles() -> void:
	if _is_selected:
		add_theme_stylebox_override("normal", _style_selected)
		add_theme_stylebox_override("hover", _style_selected)
		add_theme_stylebox_override("pressed", _style_selected)
	else:
		add_theme_stylebox_override("normal", _style_normal)
		add_theme_stylebox_override("hover", _style_hover)
		add_theme_stylebox_override("pressed", _style_pressed)

func _update_button() -> void:
	# Build button text: Name [hotkey]
	text = tool_name

	if not hotkey.is_empty():
		text += "  [%s]" % hotkey

	# Set size - expand to fill available width
	custom_minimum_size = Vector2(0, 36)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alignment = HORIZONTAL_ALIGNMENT_LEFT

	# Font size
	add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)

func _connect_signals() -> void:
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_pressed() -> void:
	tool_pressed.emit(tool_type)

func _on_mouse_entered() -> void:
	if not has_node("/root/TooltipManager"):
		return

	var tm = get_node("/root/TooltipManager")
	var data = {
		"title": tool_name,
		"description": tool_description,
		"cost": cost,
		"maintenance": maintenance,
		"shortcut": hotkey
	}
	tm.show_tooltip(data, self)

func _on_mouse_exited() -> void:
	if not has_node("/root/TooltipManager"):
		return

	var tm = get_node("/root/TooltipManager")
	tm.hide_tooltip()

# =============================================================================
# PUBLIC API
# =============================================================================

func set_selected(selected: bool) -> void:
	_is_selected = selected
	_apply_styles()

func is_selected() -> bool:
	return _is_selected

func configure(p_tool_type: Variant, p_name: String, p_icon: String = "", p_hotkey: String = "", p_description: String = "", p_cost: int = 0, p_maintenance: int = 0) -> void:
	tool_type = p_tool_type
	tool_name = p_name
	tool_icon = p_icon
	hotkey = p_hotkey
	tool_description = p_description
	cost = p_cost
	maintenance = p_maintenance
	_update_button()

static func create(p_tool_type: Variant, p_name: String, p_icon: String = "", p_hotkey: String = "", p_description: String = "", p_cost: int = 0, p_maintenance: int = 0) -> ToolButton:
	var btn = ToolButton.new()
	btn.configure(p_tool_type, p_name, p_icon, p_hotkey, p_description, p_cost, p_maintenance)
	return btn

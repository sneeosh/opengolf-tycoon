extends PanelContainer
class_name TerrainToolbar
## TerrainToolbar - Redesigned build tools panel with icon+label buttons and rich tooltips

signal tool_selected(tool_type: int)
signal create_hole_pressed
signal tree_placement_pressed
signal rock_placement_pressed
signal flower_bed_pressed
signal building_placement_pressed
signal raise_elevation_pressed
signal lower_elevation_pressed
signal bulldozer_pressed
signal staff_pressed
signal brush_size_changed(new_size: int)

var _current_tool: int = TerrainTypes.Type.FAIRWAY
var _tool_buttons: Dictionary = {}  # tool_type -> ToolButton
var _sections: Dictionary = {}  # section_name -> { header: Button, content: VBoxContainer }
var _scroll_container: ScrollContainer
var _content_vbox: VBoxContainer
var _brush_size: int = 1
var _brush_label: Label = null
const BRUSH_SIZES = [1, 3, 5]

const TOOL_SECTIONS = {
	"Course Terrain": {
		"icon": "[=]",
		"tools": [
			{"type": TerrainTypes.Type.FAIRWAY, "name": "Fairway", "icon": "[=]", "hotkey": "1", "desc": "Mowed playing surface for approach shots"},
			{"type": TerrainTypes.Type.ROUGH, "name": "Rough", "icon": "[~]", "hotkey": "2", "desc": "Longer grass bordering fairways"},
			{"type": TerrainTypes.Type.GREEN, "name": "Green", "icon": "[O]", "hotkey": "3", "desc": "Putting surface around the hole"},
			{"type": TerrainTypes.Type.TEE_BOX, "name": "Tee Box", "icon": "[T]", "hotkey": "4", "desc": "Starting area for each hole"},
		]
	},
	"Hazards": {
		"icon": "[!]",
		"tools": [
			{"type": TerrainTypes.Type.BUNKER, "name": "Bunker", "icon": "[:]", "hotkey": "5", "desc": "Sand trap hazard"},
			{"type": TerrainTypes.Type.WATER, "name": "Water", "icon": "[w]", "hotkey": "6", "desc": "Water hazard with penalty"},
			{"type": TerrainTypes.Type.OUT_OF_BOUNDS, "name": "Out of Bounds", "icon": "[X]", "hotkey": "7", "desc": "Boundary area with stroke penalty"},
		]
	},
	"Objects & Decor": {
		"icon": "[.]",
		"tools": [
			{"type": TerrainTypes.Type.PATH, "name": "Path", "icon": "[.]", "hotkey": "8", "desc": "Walking path for golfers"},
			{"type": "tree", "name": "Trees", "icon": "[^]", "hotkey": "T", "desc": "Adds beauty and obstacles"},
			{"type": "rock", "name": "Rocks", "icon": "[*]", "hotkey": "R", "desc": "Decorative rock formations"},
			{"type": "flower", "name": "Flower Bed", "icon": "[f]", "hotkey": "F", "desc": "Colorful landscaping"},
			{"type": "building", "name": "Buildings", "icon": "[B]", "hotkey": "B", "desc": "Place amenity buildings"},
			{"type": "bulldozer", "name": "Bulldozer", "icon": "[D]", "hotkey": "X", "desc": "Removes trees, rocks, flowers"},
		]
	},
	"Elevation": {
		"icon": "[+]",
		"tools": [
			{"type": "raise", "name": "Raise", "icon": "[+]", "hotkey": "+", "desc": "Raise terrain elevation"},
			{"type": "lower", "name": "Lower", "icon": "[-]", "hotkey": "-", "desc": "Lower terrain elevation"},
		]
	},
	"Course": {
		"icon": "[H]",
		"tools": [
			{"type": "create_hole", "name": "Create Hole", "icon": "[H]", "hotkey": "H", "desc": "Define tee box, green, and flag"},
			{"type": "staff", "name": "Staff", "icon": "[P]", "hotkey": "P", "desc": "Manage course maintenance staff"},
		]
	},
}

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Apply panel style
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = UIConstants.COLOR_BG_PANEL
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.content_margin_left = 8
	panel_style.content_margin_right = 8
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = UIConstants.COLOR_BORDER
	add_theme_stylebox_override("panel", panel_style)

	# Wider panel for better readability
	custom_minimum_size = Vector2(260, 500)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Main container
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", UIConstants.SEPARATION_SM)
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(main_vbox)

	# Title
	var title = Label.new()
	title.text = "Build Tools"
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_LG)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	# Subtitle hint
	var subtitle = Label.new()
	subtitle.text = "Click headers to expand | F1 for help"
	subtitle.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	subtitle.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(subtitle)

	# Brush size control
	var brush_row = HBoxContainer.new()
	brush_row.alignment = BoxContainer.ALIGNMENT_CENTER
	brush_row.add_theme_constant_override("separation", 6)

	var brush_title = Label.new()
	brush_title.text = "Brush:"
	brush_title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	brush_title.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	brush_row.add_child(brush_title)

	var brush_decrease = Button.new()
	brush_decrease.text = "-"
	brush_decrease.custom_minimum_size = Vector2(26, 26)
	brush_decrease.pressed.connect(_on_brush_decrease)
	brush_row.add_child(brush_decrease)

	_brush_label = Label.new()
	_brush_label.text = "1x1"
	_brush_label.custom_minimum_size = Vector2(36, 0)
	_brush_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_brush_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	_brush_label.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	brush_row.add_child(_brush_label)

	var brush_increase = Button.new()
	brush_increase.text = "+"
	brush_increase.custom_minimum_size = Vector2(26, 26)
	brush_increase.pressed.connect(_on_brush_increase)
	brush_row.add_child(brush_increase)

	main_vbox.add_child(brush_row)

	main_vbox.add_child(HSeparator.new())

	# Scroll container for tools
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(_scroll_container)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", UIConstants.SEPARATION_MD)
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.add_child(_content_vbox)

	# Create each section (collapsed by default)
	for section_name in TOOL_SECTIONS.keys():
		_create_section(section_name, TOOL_SECTIONS[section_name], true)

func _create_section(section_name: String, section_data: Dictionary, start_collapsed: bool = false) -> void:
	var section_vbox = VBoxContainer.new()
	section_vbox.add_theme_constant_override("separation", UIConstants.SEPARATION_SM)
	_content_vbox.add_child(section_vbox)

	# Section header (clickable to expand/collapse)
	var header_btn = Button.new()
	var icon = section_data.get("icon", "")
	var prefix = "> " if start_collapsed else "v "
	header_btn.text = "%s%s  %s" % [prefix, icon, section_name]
	header_btn.flat = true
	header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header_btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_MD)
	header_btn.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	header_btn.custom_minimum_size = Vector2(0, 32)
	section_vbox.add_child(header_btn)

	# Section content container
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", UIConstants.SEPARATION_SM)
	content.visible = not start_collapsed  # Start collapsed if specified
	section_vbox.add_child(content)

	# Store references
	_sections[section_name] = {
		"header": header_btn,
		"content": content,
		"collapsed": start_collapsed
	}

	# Connect header click to toggle
	header_btn.pressed.connect(_toggle_section.bind(section_name))

	# Create tool buttons
	for tool_data in section_data["tools"]:
		_create_tool_button(content, tool_data)

func _create_tool_button(parent: VBoxContainer, tool_data: Dictionary) -> void:
	var tool_type = tool_data["type"]
	var tool_name = tool_data["name"]
	var tool_icon = tool_data.get("icon", "")
	var hotkey = tool_data.get("hotkey", "")
	var description = tool_data.get("desc", "")

	# Get cost and maintenance
	var cost = 0
	var maintenance = 0
	if tool_type is int:
		cost = TerrainTypes.get_placement_cost(tool_type)
		maintenance = TerrainTypes.get_maintenance_cost(tool_type)
	else:
		var costs = _get_special_tool_costs(tool_type)
		cost = costs.get("cost", 0)
		maintenance = costs.get("maintenance", 0)

	# Create ToolButton
	var btn = ToolButton.create(tool_type, tool_name, tool_icon, hotkey, description, cost, maintenance)
	btn.tool_pressed.connect(_on_tool_button_pressed)
	parent.add_child(btn)

	# Store reference for highlighting
	_tool_buttons[tool_type] = btn

func _get_special_tool_costs(tool_type: String) -> Dictionary:
	match tool_type:
		"tree":
			return {"cost": 20, "maintenance": 0}
		"rock":
			return {"cost": 15, "maintenance": 0}
		"flower":
			return {"cost": 35, "maintenance": 2}
		"bulldozer":
			return {"cost": 5, "maintenance": 0}
		"building":
			return {"cost": 0, "maintenance": 0}  # Varies by building
		"create_hole":
			return {"cost": 0, "maintenance": 0}
		"staff":
			return {"cost": 0, "maintenance": 0}
		"raise", "lower":
			return {"cost": 0, "maintenance": 0}
	return {"cost": 0, "maintenance": 0}

func _toggle_section(section_name: String) -> void:
	var section = _sections.get(section_name)
	if not section:
		return

	section["collapsed"] = not section["collapsed"]
	section["content"].visible = not section["collapsed"]

	# Update header text
	var section_data = TOOL_SECTIONS.get(section_name, {})
	var icon = section_data.get("icon", "")
	var prefix = "> " if section["collapsed"] else "v "
	section["header"].text = "%s%s  %s" % [prefix, icon, section_name]

func _expand_section(section_name: String) -> void:
	var section = _sections.get(section_name)
	if not section or not section["collapsed"]:
		return

	section["collapsed"] = false
	section["content"].visible = true

	# Update header text
	var section_data = TOOL_SECTIONS.get(section_name, {})
	var icon = section_data.get("icon", "")
	section["header"].text = "v %s  %s" % [icon, section_name]

func _on_tool_button_pressed(tool_type) -> void:
	if tool_type is int:
		_current_tool = tool_type
		_update_selection_highlight()
		tool_selected.emit(tool_type)
	else:
		# Handle special tool types
		match tool_type:
			"tree":
				tree_placement_pressed.emit()
			"rock":
				rock_placement_pressed.emit()
			"flower":
				flower_bed_pressed.emit()
			"building":
				building_placement_pressed.emit()
			"create_hole":
				create_hole_pressed.emit()
			"raise":
				raise_elevation_pressed.emit()
			"lower":
				lower_elevation_pressed.emit()
			"bulldozer":
				bulldozer_pressed.emit()
			"staff":
				staff_pressed.emit()

func _update_selection_highlight() -> void:
	# Reset all buttons
	for tool_type in _tool_buttons.keys():
		var btn = _tool_buttons[tool_type]
		if btn is ToolButton:
			btn.set_selected(false)

	# Highlight current tool
	if _current_tool in _tool_buttons:
		var btn = _tool_buttons[_current_tool]
		if btn is ToolButton:
			btn.set_selected(true)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	# Don't process any gameplay hotkeys while in main menu
	if GameManager.current_mode == GameManager.GameMode.MAIN_MENU:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# Don't process if Ctrl/Cmd is held (those are for undo/save)
		if event.is_command_or_control_pressed():
			return

		# Don't process hotkeys if a text input has focus
		var focused = get_viewport().gui_get_focus_owner()
		if focused is LineEdit or focused is TextEdit:
			return

		# Check for section toggle hotkeys (with shift for symbols)
		if event.shift_pressed:
			match event.keycode:
				KEY_1:  # Shift+1 = !
					_toggle_section("Hazards")
					get_viewport().set_input_as_handled()
					return
				KEY_EQUAL:  # Shift+= = +
					_on_tool_button_pressed("raise")
					get_viewport().set_input_as_handled()
					return
				KEY_MINUS:  # Shift+- = _
					_on_tool_button_pressed("lower")
					get_viewport().set_input_as_handled()
					return

		# Check for tool hotkeys
		match event.keycode:
			KEY_EQUAL:  # = for Course Terrain
				_toggle_section("Course Terrain")
			KEY_PERIOD:  # . for Objects & Decor
				_toggle_section("Objects & Decor")
			KEY_MINUS:  # - for lower elevation
				_on_tool_button_pressed("lower")
			KEY_1:
				_on_tool_button_pressed(TerrainTypes.Type.FAIRWAY)
			KEY_2:
				_on_tool_button_pressed(TerrainTypes.Type.ROUGH)
			KEY_3:
				_on_tool_button_pressed(TerrainTypes.Type.GREEN)
			KEY_4:
				_on_tool_button_pressed(TerrainTypes.Type.TEE_BOX)
			KEY_5:
				_on_tool_button_pressed(TerrainTypes.Type.BUNKER)
			KEY_6:
				_on_tool_button_pressed(TerrainTypes.Type.WATER)
			KEY_7:
				_on_tool_button_pressed(TerrainTypes.Type.OUT_OF_BOUNDS)
			KEY_8:
				_on_tool_button_pressed(TerrainTypes.Type.PATH)
			KEY_T:
				_on_tool_button_pressed("tree")
			KEY_R:
				_on_tool_button_pressed("rock")
			KEY_F:
				_on_tool_button_pressed("flower")
			KEY_B:
				_on_tool_button_pressed("building")
			KEY_H:
				_expand_section("Course")
				_on_tool_button_pressed("create_hole")
			KEY_X:
				_on_tool_button_pressed("bulldozer")
			KEY_P:
				_on_tool_button_pressed("staff")

func set_current_tool(tool_type: int) -> void:
	_current_tool = tool_type
	_update_selection_highlight()

func get_current_tool() -> int:
	return _current_tool

func clear_selection() -> void:
	"""Clear all button selections (null selector state)"""
	_current_tool = -1  # Invalid tool type indicates no selection
	_update_selection_highlight()

func has_selection() -> bool:
	"""Check if any terrain tool is currently selected"""
	return _current_tool >= 0 and _current_tool in _tool_buttons

func get_brush_size() -> int:
	return _brush_size

func _on_brush_decrease() -> void:
	var idx = BRUSH_SIZES.find(_brush_size)
	if idx > 0:
		_brush_size = BRUSH_SIZES[idx - 1]
		_update_brush_label()
		brush_size_changed.emit(_brush_size)

func _on_brush_increase() -> void:
	var idx = BRUSH_SIZES.find(_brush_size)
	if idx < BRUSH_SIZES.size() - 1:
		_brush_size = BRUSH_SIZES[idx + 1]
		_update_brush_label()
		brush_size_changed.emit(_brush_size)

func _update_brush_label() -> void:
	if _brush_label:
		_brush_label.text = "%dx%d" % [_brush_size, _brush_size]

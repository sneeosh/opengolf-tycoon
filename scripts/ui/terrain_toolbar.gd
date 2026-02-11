extends VBoxContainer
class_name TerrainToolbar
## TerrainToolbar - Organized toolbar with collapsible sections and hotkeys

signal tool_selected(tool_type: int)
signal create_hole_pressed
signal tree_placement_pressed
signal rock_placement_pressed
signal flower_bed_pressed
signal building_placement_pressed
signal raise_elevation_pressed
signal lower_elevation_pressed

var _current_tool: int = TerrainTypes.Type.FAIRWAY
var _tool_buttons: Dictionary = {}  # tool_type -> Button
var _sections: Dictionary = {}  # section_name -> { header: Button, content: VBoxContainer }

const TOOL_SECTIONS = {
	"Course Terrain": {
		"tools": [
			{"type": TerrainTypes.Type.FAIRWAY, "name": "Fairway", "hotkey": "1"},
			{"type": TerrainTypes.Type.ROUGH, "name": "Rough", "hotkey": "2"},
			{"type": TerrainTypes.Type.GREEN, "name": "Green", "hotkey": "3"},
			{"type": TerrainTypes.Type.TEE_BOX, "name": "Tee Box", "hotkey": "4"},
		]
	},
	"Hazards": {
		"tools": [
			{"type": TerrainTypes.Type.BUNKER, "name": "Bunker", "hotkey": "5"},
			{"type": TerrainTypes.Type.WATER, "name": "Water", "hotkey": "6"},
			{"type": TerrainTypes.Type.OUT_OF_BOUNDS, "name": "Out of Bounds", "hotkey": "7"},
		]
	},
	"Paths & Decor": {
		"tools": [
			{"type": TerrainTypes.Type.PATH, "name": "Path", "hotkey": "8"},
			{"type": "tree", "name": "Trees", "hotkey": "T"},
			{"type": "rock", "name": "Rocks", "hotkey": "R"},
			{"type": "flower", "name": "Flower Bed", "hotkey": ""},
		]
	},
	"Elevation": {
		"tools": [
			{"type": "raise", "name": "Raise +", "hotkey": "+"},
			{"type": "lower", "name": "Lower -", "hotkey": "-"},
		]
	},
	"Structures": {
		"tools": [
			{"type": "building", "name": "Buildings", "hotkey": "B"},
		]
	},
	"Hole Tools": {
		"tools": [
			{"type": "create_hole", "name": "Create Hole", "hotkey": "H"},
		]
	},
}

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Clear existing children
	for child in get_children():
		child.queue_free()

	add_theme_constant_override("separation", 4)

	# Title
	var title = Label.new()
	title.text = "Build Tools"
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	add_child(HSeparator.new())

	# Create each section
	for section_name in TOOL_SECTIONS.keys():
		_create_section(section_name, TOOL_SECTIONS[section_name])

func _create_section(section_name: String, section_data: Dictionary) -> void:
	# Section header (clickable to collapse)
	var header_btn = Button.new()
	header_btn.text = "v " + section_name
	header_btn.flat = true
	header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header_btn.add_theme_font_size_override("font_size", 13)
	header_btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	add_child(header_btn)

	# Section content container
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	add_child(content)

	# Store references
	_sections[section_name] = {
		"header": header_btn,
		"content": content,
		"collapsed": false
	}

	# Connect header click to toggle
	header_btn.pressed.connect(_toggle_section.bind(section_name))

	# Create tool buttons
	for tool_data in section_data["tools"]:
		_create_tool_button(content, tool_data)

func _create_tool_button(parent: VBoxContainer, tool_data: Dictionary) -> void:
	var btn = Button.new()
	var tool_type = tool_data["type"]
	var tool_name = tool_data["name"]
	var hotkey = tool_data.get("hotkey", "")

	# Build button text with hotkey hint
	if hotkey != "":
		btn.text = "%s [%s]" % [tool_name, hotkey]
	else:
		btn.text = tool_name

	btn.custom_minimum_size = Vector2(180, 28)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	# Add tooltip with cost and maintenance info
	var tooltip = _get_tool_tooltip(tool_type, tool_name)
	btn.tooltip_text = tooltip

	# Connect button press
	btn.pressed.connect(_on_tool_button_pressed.bind(tool_type))

	parent.add_child(btn)

	# Store reference for highlighting
	_tool_buttons[tool_type] = btn

func _get_tool_tooltip(tool_type, tool_name: String) -> String:
	if tool_type is int:
		var cost = TerrainTypes.get_placement_cost(tool_type)
		var maintenance = TerrainTypes.get_maintenance_cost(tool_type)
		var tooltip = tool_name
		if cost > 0:
			tooltip += "\nCost: $%d per tile" % cost
		if maintenance > 0:
			tooltip += "\nMaintenance: $%d/day" % maintenance
		return tooltip
	else:
		# Special tools
		match tool_type:
			"tree":
				return "Trees\nCost: $18-25 per tree\nAdds beauty to course"
			"rock":
				return "Rocks\nCost: $10-20 per rock\nDecorative hazard"
			"flower":
				return "Flower Bed\nCost: $30 per tile\nBoosts aesthetics"
			"building":
				return "Buildings\nVarious costs\nAdd amenities"
			"create_hole":
				return "Create Hole\nPlace tee, then green\nDefines playable hole"
			"raise":
				return "Raise Elevation\nNo cost\nAffects ball physics"
			"lower":
				return "Lower Elevation\nNo cost\nAffects ball physics"
		return tool_name

func _toggle_section(section_name: String) -> void:
	var section = _sections.get(section_name)
	if not section:
		return

	section["collapsed"] = not section["collapsed"]
	section["content"].visible = not section["collapsed"]

	# Update header text
	var prefix = "> " if section["collapsed"] else "v "
	section["header"].text = prefix + section_name

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

func _update_selection_highlight() -> void:
	# Reset all buttons
	for tool_type in _tool_buttons.keys():
		var btn = _tool_buttons[tool_type]
		btn.modulate = Color(1, 1, 1, 1)

	# Highlight current tool
	if _current_tool in _tool_buttons:
		_tool_buttons[_current_tool].modulate = Color(0.5, 1.0, 0.5, 1)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# Don't process if Ctrl/Cmd is held (those are for undo/save)
		if event.is_command_or_control_pressed():
			return

		# Check for tool hotkeys
		match event.keycode:
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
			KEY_B:
				_on_tool_button_pressed("building")
			KEY_H:
				_on_tool_button_pressed("create_hole")
			KEY_EQUAL, KEY_KP_ADD:  # + key
				_on_tool_button_pressed("raise")
			KEY_MINUS, KEY_KP_SUBTRACT:  # - key
				_on_tool_button_pressed("lower")

func set_current_tool(tool_type: int) -> void:
	_current_tool = tool_type
	_update_selection_highlight()

func get_current_tool() -> int:
	return _current_tool

extends CenteredPanel
class_name HotkeyPanel
## HotkeyPanel - Shows all keyboard shortcuts grouped by category

func _build_ui() -> void:
	custom_minimum_size = Vector2(480, 520)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(main_vbox)

	# Title
	var title = Label.new()
	title.text = "Keyboard Shortcuts"
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XL)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Press F1 to toggle this panel"
	subtitle.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	subtitle.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(subtitle)

	main_vbox.add_child(HSeparator.new())

	# Scrollable content
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Two-column layout using GridContainer per section
	_add_section(vbox, "Terrain Tools", [
		["1", "Fairway"],
		["2", "Rough"],
		["3", "Green"],
		["4", "Tee Box"],
		["5", "Bunker"],
		["6", "Water"],
		["7", "Out of Bounds"],
		["8", "Path"],
	])

	_add_section(vbox, "Objects & Placement", [
		["T", "Trees"],
		["R", "Rocks"],
		["F", "Flower Bed"],
		["B", "Buildings"],
		["H", "Create Hole"],
		["X", "Bulldozer"],
	])

	_add_section(vbox, "Elevation", [
		["Shift+=", "Raise terrain"],
		["Shift+-", "Lower terrain"],
	])

	_add_section(vbox, "Management Panels", [
		["P", "Staff"],
		["U", "Tournaments"],
		["L", "Land"],
		["M", "Marketing"],
		["Z", "Analytics"],
		["G", "Milestones"],
		["C", "Calendar"],
	])

	_add_section(vbox, "Camera & View", [
		["WASD", "Pan camera"],
		["Scroll", "Zoom in/out"],
		["Q", "Rotate camera"],
		["Tab", "Toggle minimap"],
		["V", "Shot heatmap"],
		["Shift+V", "Cycle heatmap mode"],
		["F3", "Debug overlay"],
	])

	_add_section(vbox, "General", [
		["Ctrl+S", "Quick save"],
		["Ctrl+Z", "Undo"],
		["Ctrl+Shift+Z", "Redo"],
		["Esc", "Cancel / Deselect tool"],
		["F1", "This help panel"],
		["F2", "Weather debug"],
		["F4", "Season debug"],
	])

	# Close button
	main_vbox.add_child(HSeparator.new())
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 35)
	close_btn.pressed.connect(func(): hide())
	main_vbox.add_child(close_btn)

func _add_section(parent: VBoxContainer, section_name: String, shortcuts: Array) -> void:
	var header = Label.new()
	header.text = section_name
	header.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_MD)
	header.add_theme_color_override("font_color", UIConstants.COLOR_SUCCESS)
	parent.add_child(header)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 2)
	parent.add_child(grid)

	for shortcut in shortcuts:
		var key_label = Label.new()
		key_label.text = shortcut[0]
		key_label.custom_minimum_size = Vector2(110, 0)
		key_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
		key_label.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
		grid.add_child(key_label)

		var desc_label = Label.new()
		desc_label.text = shortcut[1]
		desc_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
		desc_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
		grid.add_child(desc_label)

	# Small spacer after section
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	parent.add_child(spacer)

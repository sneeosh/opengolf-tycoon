extends PanelContainer
class_name HoleContextMenu
## HoleContextMenu - Popup context menu for hole management actions.
## Created dynamically when clicking a hole's tee, green, or flag.

var hole_data: GameManager.HoleData
var terrain_grid: TerrainGrid
var _just_opened: bool = true

signal move_pin_requested(hole_number: int)
signal move_tee_requested(hole_number: int)
signal move_green_requested(hole_number: int)
signal toggle_hole_requested(hole_number: int)
signal view_stats_requested(hole_number: int)
signal menu_closed()

func _init(p_hole_data: GameManager.HoleData, p_terrain_grid: TerrainGrid) -> void:
	hole_data = p_hole_data
	terrain_grid = p_terrain_grid
	_build_ui()

func _ready() -> void:
	# Style the panel background
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = UIConstants.COLOR_BG_PANEL
	panel_style.set_border_width_all(1)
	panel_style.border_color = UIConstants.COLOR_BORDER
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", panel_style)

	# Clear the just_opened flag after one frame so clicks can close the menu
	await get_tree().process_frame
	_just_opened = false

func _input(event: InputEvent) -> void:
	if _just_opened:
		return

	# Close on Escape
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
		return

	# Close on click outside
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local = get_local_mouse_position()
		if not Rect2(Vector2.ZERO, size).has_point(local):
			_close()
			get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Header: "Hole N — Par P"
	var header = Label.new()
	header.text = "Hole %d — Par %d" % [hole_data.hole_number, hole_data.par]
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# Orphan warnings
	var tee_orphaned = terrain_grid.get_tile(hole_data.tee_position) != TerrainTypes.Type.TEE_BOX
	var green_orphaned = terrain_grid.get_tile(hole_data.green_position) != TerrainTypes.Type.GREEN
	if tee_orphaned or green_orphaned:
		var warn_label = Label.new()
		warn_label.text = "Warning: Missing %s" % ("tee & green" if tee_orphaned and green_orphaned else ("tee" if tee_orphaned else "green"))
		warn_label.add_theme_font_size_override("font_size", 11)
		warn_label.add_theme_color_override("font_color", UIConstants.COLOR_WARNING)
		warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(warn_label)

	vbox.add_child(_create_separator())

	# Move Pin button
	var pin_btn = _create_menu_button("Move Pin Position")
	pin_btn.pressed.connect(func(): move_pin_requested.emit(hole_data.hole_number); _close())
	vbox.add_child(pin_btn)

	# Move Tee button
	var tee_label = "Place Tee" if tee_orphaned else "Move Tee"
	var tee_btn = _create_menu_button(tee_label)
	if tee_orphaned:
		tee_btn.add_theme_color_override("font_color", UIConstants.COLOR_WARNING)
	tee_btn.pressed.connect(func(): move_tee_requested.emit(hole_data.hole_number); _close())
	vbox.add_child(tee_btn)

	# Move Green button
	var green_label = "Place Green" if green_orphaned else "Move Green"
	var green_btn = _create_menu_button(green_label)
	if green_orphaned:
		green_btn.add_theme_color_override("font_color", UIConstants.COLOR_WARNING)
	green_btn.pressed.connect(func(): move_green_requested.emit(hole_data.hole_number); _close())
	vbox.add_child(green_btn)

	# Open/Close toggle
	var toggle_label = "Close Hole" if hole_data.is_open else "Open Hole"
	var toggle_btn = _create_menu_button(toggle_label)
	if hole_data.is_open:
		toggle_btn.add_theme_color_override("font_color", UIConstants.COLOR_DANGER)
	else:
		toggle_btn.add_theme_color_override("font_color", UIConstants.COLOR_SUCCESS)
	toggle_btn.pressed.connect(func(): toggle_hole_requested.emit(hole_data.hole_number); _close())
	vbox.add_child(toggle_btn)

	vbox.add_child(_create_separator())

	# Rating info row
	var rating_hbox = HBoxContainer.new()
	var rating_label = Label.new()
	rating_label.text = "Rating: "
	rating_label.add_theme_font_size_override("font_size", 12)
	rating_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	rating_hbox.add_child(rating_label)

	var rating_value = Label.new()
	rating_value.text = "%.1f" % hole_data.difficulty_rating
	rating_value.add_theme_font_size_override("font_size", 12)
	if hole_data.difficulty_rating < 4.0:
		rating_value.add_theme_color_override("font_color", UIConstants.COLOR_SUCCESS)
	elif hole_data.difficulty_rating < 7.0:
		rating_value.add_theme_color_override("font_color", UIConstants.COLOR_WARNING)
	else:
		rating_value.add_theme_color_override("font_color", UIConstants.COLOR_DANGER)
	rating_hbox.add_child(rating_value)
	vbox.add_child(rating_hbox)

	# Revenue info row
	var rev_hbox = HBoxContainer.new()
	var rev_label = Label.new()
	rev_label.text = "Revenue: "
	rev_label.add_theme_font_size_override("font_size", 12)
	rev_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	rev_hbox.add_child(rev_label)

	var rev_value = Label.new()
	if hole_data.total_revenue > 0:
		rev_value.text = "$%s" % _format_number(hole_data.total_revenue)
		rev_value.add_theme_color_override("font_color", UIConstants.COLOR_SUCCESS)
	else:
		rev_value.text = "No revenue yet"
		rev_value.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
	rev_value.add_theme_font_size_override("font_size", 12)
	rev_hbox.add_child(rev_value)
	vbox.add_child(rev_hbox)

	# Distance info
	var dist_hbox = HBoxContainer.new()
	var dist_label = Label.new()
	dist_label.text = "%d yards  •  Diff: %.1f" % [hole_data.distance_yards, hole_data.difficulty_rating]
	dist_label.add_theme_font_size_override("font_size", 11)
	dist_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
	dist_hbox.add_child(dist_label)
	vbox.add_child(dist_hbox)

	vbox.add_child(_create_separator())

	# View Statistics button
	var stats_btn = _create_menu_button("View Statistics")
	stats_btn.pressed.connect(func(): view_stats_requested.emit(hole_data.hole_number); _close())
	vbox.add_child(stats_btn)

func _create_menu_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.flat = true
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", UIConstants.COLOR_PRIMARY_HOVER)
	btn.custom_minimum_size.x = 180
	return btn

func _create_separator() -> HSeparator:
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	return sep

func _format_number(n: int) -> String:
	var s = str(n)
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result

func _close() -> void:
	menu_closed.emit()
	queue_free()

func position_at(screen_pos: Vector2) -> void:
	# Position near click, clamped to viewport bounds
	position = screen_pos + Vector2(10, 10)
	# Defer clamping until layout is done
	await get_tree().process_frame
	var viewport_size = get_viewport().get_visible_rect().size
	if position.x + size.x > viewport_size.x:
		position.x = viewport_size.x - size.x - 5
	if position.y + size.y > viewport_size.y:
		position.y = viewport_size.y - size.y - 5
	if position.x < 0:
		position.x = 5
	if position.y < 0:
		position.y = 5

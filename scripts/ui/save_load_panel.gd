extends CenteredPanel
class_name SaveLoadPanel
## SaveLoadPanel - Simple save/load UI overlay

signal panel_closed
signal quit_to_menu_requested

var _save_list_container: VBoxContainer = null
var _save_name_input: LineEdit = null

func _ready() -> void:
	super._ready()
	_refresh_save_list()
	# Show centered immediately (this panel auto-shows on creation)
	show_centered()

func _build_ui() -> void:
	custom_minimum_size = Vector2(400, 350)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox = VBoxContainer.new()
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Save / Load Game"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Save name input + save button
	var save_row = HBoxContainer.new()
	vbox.add_child(save_row)

	_save_name_input = LineEdit.new()
	_save_name_input.placeholder_text = "Save name..."
	_save_name_input.text = SaveManager.current_save_name if SaveManager.current_save_name != "" else "slot_1"
	_save_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(_save_name_input)

	var save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(70, 0)
	save_btn.pressed.connect(_on_save_pressed)
	save_row.add_child(save_btn)

	# Separator
	vbox.add_child(HSeparator.new())

	# Saves list header
	var list_label = Label.new()
	list_label.text = "Saved Games:"
	vbox.add_child(list_label)

	# Scrollable save list
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 160)
	vbox.add_child(scroll)

	_save_list_container = VBoxContainer.new()
	_save_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_save_list_container)

	# Button row
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(_on_close_pressed)
	btn_row.add_child(close_btn)

	# Quit to Menu button
	var quit_btn = Button.new()
	quit_btn.text = "Quit to Menu"
	quit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit_btn.pressed.connect(_on_quit_to_menu_pressed)
	btn_row.add_child(quit_btn)

func _refresh_save_list() -> void:
	for child in _save_list_container.get_children():
		child.queue_free()

	var saves = SaveManager.get_save_list()
	if saves.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No saves found."
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_save_list_container.add_child(empty_label)
		return

	for save_info in saves:
		var row = HBoxContainer.new()

		var info_label = Label.new()
		var day_text = "Day %d" % save_info.get("day", 0) if save_info.get("day", 0) > 0 else ""
		info_label.text = "%s  %s  %s" % [
			save_info.get("name", "???"),
			save_info.get("course_name", ""),
			day_text,
		]
		info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_label)

		var load_btn = Button.new()
		load_btn.text = "Load"
		load_btn.custom_minimum_size = Vector2(60, 0)
		load_btn.pressed.connect(_on_load_pressed.bind(save_info.get("name", "")))
		row.add_child(load_btn)

		var del_btn = Button.new()
		del_btn.text = "X"
		del_btn.custom_minimum_size = Vector2(30, 0)
		del_btn.pressed.connect(_on_delete_pressed.bind(save_info.get("name", "")))
		row.add_child(del_btn)

		_save_list_container.add_child(row)

func _on_save_pressed() -> void:
	var save_name = _save_name_input.text.strip_edges()
	if save_name.is_empty():
		save_name = "slot_1"
	SaveManager.save_game(save_name)
	_refresh_save_list()

func _on_load_pressed(save_name: String) -> void:
	SaveManager.load_game(save_name)
	_on_close_pressed()

func _on_delete_pressed(save_name: String) -> void:
	SaveManager.delete_save(save_name)
	_refresh_save_list()

func _on_close_pressed() -> void:
	panel_closed.emit()
	queue_free()

func _on_quit_to_menu_pressed() -> void:
	quit_to_menu_requested.emit()
	queue_free()

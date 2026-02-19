extends Control
class_name PauseMenu
## PauseMenu - Full-screen pause overlay with game options
##
## Triggered by Escape key. Provides Resume, Save, Load, Quit to Menu, and
## Quit to Desktop options. Dims the game behind it.

signal resume_requested
signal save_requested
signal load_requested
signal settings_requested
signal quit_to_menu_requested
signal quit_to_desktop_requested

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	# Semi-transparent dark overlay
	var bg = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Center container for the menu panel
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Menu panel
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.1, 0.95)
	style.border_color = UIConstants.COLOR_PRIMARY
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Game Paused"
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XL)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 0.75))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Separator
	vbox.add_child(HSeparator.new())

	# Course info
	var info_label = Label.new()
	info_label.text = "%s - Day %d" % [GameManager.course_name, GameManager.current_day]
	info_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	info_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	# Menu buttons
	_add_menu_button(vbox, "Resume", _on_resume_pressed)
	_add_menu_button(vbox, "Save Game", _on_save_pressed)
	_add_menu_button(vbox, "Load Game", _on_load_pressed)
	_add_menu_button(vbox, "Settings", _on_settings_pressed)

	# Separator before destructive actions
	vbox.add_child(HSeparator.new())

	_add_menu_button(vbox, "Quit to Menu", _on_quit_to_menu_pressed, UIConstants.COLOR_WARNING)
	_add_menu_button(vbox, "Quit to Desktop", _on_quit_to_desktop_pressed, UIConstants.COLOR_DANGER)

	# Hint at bottom
	var hint = Label.new()
	hint.text = "Press Escape to resume"
	hint.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
	hint.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

func _add_menu_button(parent: VBoxContainer, text: String, callback: Callable, text_color: Color = Color.WHITE) -> void:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(260, 40)
	btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_MD)
	if text_color != Color.WHITE:
		btn.add_theme_color_override("font_color", text_color)
	btn.pressed.connect(callback)
	parent.add_child(btn)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_resume_pressed()
			get_viewport().set_input_as_handled()

func _on_resume_pressed() -> void:
	resume_requested.emit()

func _on_save_pressed() -> void:
	save_requested.emit()

func _on_load_pressed() -> void:
	load_requested.emit()

func _on_settings_pressed() -> void:
	settings_requested.emit()

func _on_quit_to_menu_pressed() -> void:
	quit_to_menu_requested.emit()

func _on_quit_to_desktop_pressed() -> void:
	quit_to_desktop_requested.emit()

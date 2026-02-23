extends Control
class_name SettingsMenu
## SettingsMenu - Game settings with Audio, Display, and Gameplay tabs
##
## Accessible from the main menu and pause menu. Settings are persisted
## to user://settings.cfg via SaveManager.

signal close_requested

var _tab_container: TabContainer = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	# Semi-transparent overlay
	var bg = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.5)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.1, 0.95)
	style.border_color = UIConstants.COLOR_PRIMARY
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(500, 400)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XL)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 0.75))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Tab container
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tab_container)

	_build_audio_tab()
	_build_display_tab()
	_build_gameplay_tab()
	_build_controls_tab()

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(200, 36)
	close_btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	close_btn.pressed.connect(_on_close)
	var btn_center = CenterContainer.new()
	btn_center.add_child(close_btn)
	vbox.add_child(btn_center)

func _build_audio_tab() -> void:
	var audio_tab = VBoxContainer.new()
	audio_tab.name = "Audio"
	audio_tab.add_theme_constant_override("separation", 12)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 16)

	# Master volume
	_add_volume_slider(inner, "Master Volume", SoundManager.master_volume, func(val: float):
		SoundManager.set_master_volume(val)
	)

	# SFX volume
	_add_volume_slider(inner, "SFX Volume", SoundManager.sfx_volume, func(val: float):
		SoundManager.sfx_volume = clampf(val, 0.0, 1.0)
		SoundManager._save_settings()
	)

	# Ambient volume
	_add_volume_slider(inner, "Ambient Volume", SoundManager.ambient_volume, func(val: float):
		SoundManager.ambient_volume = clampf(val, 0.0, 1.0)
		SoundManager._update_ambient_volumes()
		SoundManager._save_settings()
	)

	# Mute toggle
	var mute_row = HBoxContainer.new()
	mute_row.add_theme_constant_override("separation", 12)
	var mute_label = Label.new()
	mute_label.text = "Mute All Audio"
	mute_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	mute_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mute_row.add_child(mute_label)
	var mute_check = CheckButton.new()
	mute_check.button_pressed = SoundManager.is_muted
	mute_check.toggled.connect(func(toggled: bool): SoundManager.set_muted(toggled))
	mute_row.add_child(mute_check)
	inner.add_child(mute_row)

	margin.add_child(inner)
	audio_tab.add_child(margin)
	_tab_container.add_child(audio_tab)

func _build_display_tab() -> void:
	var display_tab = VBoxContainer.new()
	display_tab.name = "Display"
	display_tab.add_theme_constant_override("separation", 12)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 16)

	# Window mode
	var mode_row = HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 12)
	var mode_label = Label.new()
	mode_label.text = "Window Mode"
	mode_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_row.add_child(mode_label)

	var mode_options = OptionButton.new()
	mode_options.add_item("Windowed", 0)
	mode_options.add_item("Borderless Fullscreen", 1)
	mode_options.add_item("Fullscreen", 2)
	mode_options.custom_minimum_size = Vector2(200, 0)

	# Set current mode
	var current_mode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		mode_options.selected = 2
	elif current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		mode_options.selected = 2
	else:
		# Check borderless
		var borderless = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
		mode_options.selected = 1 if borderless else 0

	mode_options.item_selected.connect(func(index: int):
		match index:
			0:
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			1:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
				# Maximize to fill screen
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
			2:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_save_display_settings()
	)
	mode_row.add_child(mode_options)
	inner.add_child(mode_row)

	# VSync toggle
	var vsync_row = HBoxContainer.new()
	vsync_row.add_theme_constant_override("separation", 12)
	var vsync_label = Label.new()
	vsync_label.text = "VSync"
	vsync_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	vsync_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vsync_row.add_child(vsync_label)
	var vsync_check = CheckButton.new()
	vsync_check.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	vsync_check.toggled.connect(func(toggled: bool):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if toggled else DisplayServer.VSYNC_DISABLED)
		_save_display_settings()
	)
	vsync_row.add_child(vsync_check)
	inner.add_child(vsync_row)

	# UI Scale slider
	var ui_scale_row = HBoxContainer.new()
	ui_scale_row.add_theme_constant_override("separation", 12)
	var ui_scale_label = Label.new()
	ui_scale_label.text = "UI Scale"
	ui_scale_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	ui_scale_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_scale_row.add_child(ui_scale_label)

	var ui_scale_slider = HSlider.new()
	ui_scale_slider.min_value = 0.8
	ui_scale_slider.max_value = 1.5
	ui_scale_slider.step = 0.1
	ui_scale_slider.value = _load_ui_scale()
	ui_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_scale_slider.custom_minimum_size = Vector2(150, 0)
	ui_scale_row.add_child(ui_scale_slider)

	var ui_scale_value = Label.new()
	ui_scale_value.text = "%d%%" % int(ui_scale_slider.value * 100)
	ui_scale_value.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	ui_scale_value.custom_minimum_size = Vector2(40, 0)
	ui_scale_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui_scale_row.add_child(ui_scale_value)

	ui_scale_slider.value_changed.connect(func(val: float):
		ui_scale_value.text = "%d%%" % int(val * 100)
		get_tree().root.content_scale_factor = val
		_save_display_settings()
	)
	inner.add_child(ui_scale_row)

	# Colorblind mode
	var cb_row = HBoxContainer.new()
	cb_row.add_theme_constant_override("separation", 12)
	var cb_label = Label.new()
	cb_label.text = "Colorblind Mode"
	cb_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	cb_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cb_row.add_child(cb_label)

	var cb_options = OptionButton.new()
	for mode in ColorblindMode.get_all_modes():
		cb_options.add_item(ColorblindMode.get_mode_name(mode), mode)
	cb_options.custom_minimum_size = Vector2(220, 0)
	cb_options.selected = GameManager.colorblind_mode
	cb_options.item_selected.connect(func(index: int):
		GameManager.set_colorblind_mode(index)
		_save_display_settings()
	)
	cb_row.add_child(cb_options)
	inner.add_child(cb_row)

	margin.add_child(inner)
	display_tab.add_child(margin)
	_tab_container.add_child(display_tab)

func _build_gameplay_tab() -> void:
	var gameplay_tab = VBoxContainer.new()
	gameplay_tab.name = "Gameplay"
	gameplay_tab.add_theme_constant_override("separation", 12)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 16)

	# Auto-save toggle
	var autosave_row = HBoxContainer.new()
	autosave_row.add_theme_constant_override("separation", 12)
	var autosave_label = Label.new()
	autosave_label.text = "Auto-save at End of Day"
	autosave_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	autosave_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	autosave_row.add_child(autosave_label)
	var autosave_check = CheckButton.new()
	autosave_check.button_pressed = true
	autosave_check.tooltip_text = "Automatically saves your game at the end of each day"
	autosave_row.add_child(autosave_check)
	inner.add_child(autosave_row)

	# Default game speed
	var speed_row = HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 12)
	var speed_label = Label.new()
	speed_label.text = "Default Game Speed"
	speed_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	speed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_row.add_child(speed_label)
	var speed_options = OptionButton.new()
	speed_options.add_item("Normal (1x)", 0)
	speed_options.add_item("Fast (2x)", 1)
	speed_options.custom_minimum_size = Vector2(150, 0)
	speed_options.selected = 0
	speed_row.add_child(speed_options)
	inner.add_child(speed_row)

	# Info text
	var info = Label.new()
	info.text = "More gameplay options coming soon."
	info.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	info.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
	inner.add_child(info)

	margin.add_child(inner)
	gameplay_tab.add_child(margin)
	_tab_container.add_child(gameplay_tab)

func _build_controls_tab() -> void:
	var controls_tab = VBoxContainer.new()
	controls_tab.name = "Controls"
	controls_tab.add_theme_constant_override("separation", 8)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)

	# Invert scroll zoom toggle
	var invert_row = HBoxContainer.new()
	invert_row.add_theme_constant_override("separation", 12)
	var invert_label = Label.new()
	invert_label.text = "Invert Scroll Zoom"
	invert_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	invert_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	invert_row.add_child(invert_label)
	var invert_check = CheckButton.new()
	invert_check.button_pressed = GameManager.invert_zoom_scroll
	invert_check.tooltip_text = "Reverse the scroll wheel zoom direction"
	invert_check.toggled.connect(func(toggled: bool):
		GameManager.invert_zoom_scroll = toggled
		_save_controls_settings()
	)
	invert_row.add_child(invert_check)
	inner.add_child(invert_row)

	var sep = HSeparator.new()
	inner.add_child(sep)

	var header = Label.new()
	header.text = "Keyboard Shortcuts"
	header.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_MD)
	header.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	inner.add_child(header)

	# Key bindings (display only)
	var bindings = [
		["Escape", "Pause Menu"],
		["Space / ||", "Pause/Resume"],
		["F1", "Help / Hotkey Reference"],
		["Ctrl+S", "Quick Save"],
		["Ctrl+Z", "Undo"],
		["Ctrl+Shift+Z", "Redo"],
		["H", "Create Hole"],
		["T", "Place Tree"],
		["R", "Place Rock"],
		["B", "Place Building"],
		["L", "Land Purchase"],
		["M", "Marketing"],
		["U", "Tournaments"],
		["Z", "Analytics"],
		["WASD", "Pan Camera"],
		["Q", "Rotate Camera"],
		["Scroll", "Zoom In/Out"],
	]

	for binding in bindings:
		_add_keybinding_row(inner, binding[0], binding[1])

	var note = Label.new()
	note.text = "Key rebinding coming in a future update."
	note.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
	note.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
	inner.add_child(note)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)

	margin.add_child(scroll)
	controls_tab.add_child(margin)
	_tab_container.add_child(controls_tab)

func _add_volume_slider(parent: VBoxContainer, label_text: String, initial_value: float, on_change: Callable) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)

	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(150, 0)
	row.add_child(slider)

	var value_label = Label.new()
	value_label.text = "%d%%" % int(initial_value * 100)
	value_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	value_label.custom_minimum_size = Vector2(40, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	slider.value_changed.connect(func(val: float):
		on_change.call(val)
		value_label.text = "%d%%" % int(val * 100)
	)

	parent.add_child(row)

func _add_keybinding_row(parent: VBoxContainer, key: String, action: String) -> void:
	var row = HBoxContainer.new()

	var key_label = Label.new()
	key_label.text = key
	key_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	key_label.add_theme_color_override("font_color", UIConstants.COLOR_INFO)
	key_label.custom_minimum_size = Vector2(140, 0)
	row.add_child(key_label)

	var action_label = Label.new()
	action_label.text = action
	action_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	action_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	row.add_child(action_label)

	parent.add_child(row)

func _load_ui_scale() -> float:
	"""Load UI scale from settings file, default 1.0."""
	var config := ConfigFile.new()
	if config.load(SaveManager.SETTINGS_PATH) == OK:
		return config.get_value("display", "ui_scale", 1.0)
	return 1.0

func _save_controls_settings() -> void:
	"""Persist controls settings to user settings file."""
	var config := ConfigFile.new()
	config.load(SaveManager.SETTINGS_PATH)
	config.set_value("controls", "invert_zoom_scroll", GameManager.invert_zoom_scroll)
	config.save(SaveManager.SETTINGS_PATH)

func _save_display_settings() -> void:
	"""Persist display settings to user settings file."""
	var config := ConfigFile.new()
	config.load(SaveManager.SETTINGS_PATH)
	config.set_value("display", "window_mode", DisplayServer.window_get_mode())
	config.set_value("display", "borderless", DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS))
	config.set_value("display", "vsync", DisplayServer.window_get_vsync_mode())
	config.set_value("display", "ui_scale", get_tree().root.content_scale_factor)
	config.set_value("display", "colorblind_mode", ColorblindMode.to_string_name(GameManager.colorblind_mode))
	config.save(SaveManager.SETTINGS_PATH)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_close()
			get_viewport().set_input_as_handled()

func _on_close() -> void:
	close_requested.emit()
	queue_free()

extends Control
class_name CreditsScreen
## CreditsScreen - Simple credits/about screen for the main menu

signal close_requested

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _build_ui() -> void:
	# Semi-transparent overlay
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Panel
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.1, 0.95)
	style.border_color = UIConstants.COLOR_PRIMARY
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "OpenGolf Tycoon"
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XL)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 0.75))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Version
	var version := Label.new()
	version.text = "v0.1.0 Alpha"
	version.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	version.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(version)

	vbox.add_child(HSeparator.new())

	# Credits entries
	_add_credit_section(vbox, "Design & Development", ["sneeosh"])
	_add_credit_section(vbox, "Engine", ["Godot 4.6 (MIT License)"])
	_add_credit_section(vbox, "Inspired By", ["SimGolf (2002) by Maxis / Firaxis"])
	_add_credit_section(vbox, "License", ["MIT - Open Source"])

	vbox.add_child(HSeparator.new())

	# Description
	var desc := Label.new()
	desc.text = "A spiritual successor to SimGolf.\nDesign courses, manage operations, and host tournaments."
	desc.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	desc.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)

	# Close button
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(200, 36)
	close_btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	close_btn.pressed.connect(_on_close)
	var btn_center := CenterContainer.new()
	btn_center.add_child(close_btn)
	vbox.add_child(btn_center)

func _add_credit_section(parent: VBoxContainer, header_text: String, names: Array) -> void:
	var header := Label.new()
	header.text = header_text
	header.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_MD)
	header.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(header)

	for entry in names:
		var name_label := Label.new()
		name_label.text = entry
		name_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
		name_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		parent.add_child(name_label)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_close()
			get_viewport().set_input_as_handled()

func _on_close() -> void:
	close_requested.emit()
	queue_free()

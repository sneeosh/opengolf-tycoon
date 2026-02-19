extends Control
class_name ConfirmDialog
## ConfirmDialog - Modal confirmation dialog for destructive actions
##
## Shows a message with Confirm and Cancel buttons. Used for quit
## confirmations and other actions that could lose progress.

signal confirmed
signal cancelled

var _message_text: String = ""
var _confirm_text: String = "Confirm"
var _cancel_text: String = "Cancel"
var _confirm_color: Color = UIConstants.COLOR_DANGER

func _init(message: String = "", confirm_text: String = "Confirm", cancel_text: String = "Cancel", confirm_color: Color = UIConstants.COLOR_DANGER) -> void:
	_message_text = message
	_confirm_text = confirm_text
	_cancel_text = cancel_text
	_confirm_color = confirm_color

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
	style.bg_color = Color(0.12, 0.12, 0.14, 0.98)
	style.border_color = UIConstants.COLOR_WARNING
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(380, 0)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# Warning icon + title
	var title = Label.new()
	title.text = "Are you sure?"
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_LG)
	title.add_theme_color_override("font_color", UIConstants.COLOR_WARNING)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Message
	var message = Label.new()
	message.text = _message_text
	message.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	message.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD
	message.custom_minimum_size = Vector2(340, 0)
	vbox.add_child(message)

	# Button row
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var cancel_btn = Button.new()
	cancel_btn.text = _cancel_text
	cancel_btn.custom_minimum_size = Vector2(140, 38)
	cancel_btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	cancel_btn.pressed.connect(_on_cancel)
	btn_row.add_child(cancel_btn)

	var confirm_btn = Button.new()
	confirm_btn.text = _confirm_text
	confirm_btn.custom_minimum_size = Vector2(140, 38)
	confirm_btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_BASE)
	confirm_btn.add_theme_color_override("font_color", _confirm_color)
	confirm_btn.pressed.connect(_on_confirm)
	btn_row.add_child(confirm_btn)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_on_cancel()
			get_viewport().set_input_as_handled()

func _on_confirm() -> void:
	confirmed.emit()
	queue_free()

func _on_cancel() -> void:
	cancelled.emit()
	queue_free()

extends Control
class_name AutosaveIndicator
## AutosaveIndicator - Brief visual indicator shown when auto-saving
##
## Shows a small "Saving..." label in the top-right corner that fades out
## after the save completes.

const FADE_IN_DURATION: float = 0.15
const DISPLAY_DURATION: float = 1.5
const FADE_OUT_DURATION: float = 0.5
const RIGHT_MARGIN: float = 20.0
const TOP_MARGIN: float = 56.0  # Below TopHUDBar

var _label: Label = null
var _panel: PanelContainer = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_panel.modulate.a = 0.0
	_panel.hide()
	EventBus.save_completed.connect(_on_save_completed)

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.15, 0.1, 0.85)
	style.border_color = UIConstants.COLOR_SUCCESS_DIM
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_label = Label.new()
	_label.text = "Saved"
	_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	_label.add_theme_color_override("font_color", UIConstants.COLOR_SUCCESS_DIM)
	_panel.add_child(_label)

func _on_save_completed(success: bool) -> void:
	if not success:
		return
	_show_indicator()

func _show_indicator() -> void:
	_label.text = "Saved"

	# Position top-right
	_panel.show()
	await get_tree().process_frame
	var vp_size = get_viewport().get_visible_rect().size
	_panel.position = Vector2(vp_size.x - _panel.size.x - RIGHT_MARGIN, TOP_MARGIN)

	# Fade in
	var tween = create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, FADE_IN_DURATION)
	tween.tween_interval(DISPLAY_DURATION)
	tween.tween_property(_panel, "modulate:a", 0.0, FADE_OUT_DURATION)
	tween.tween_callback(func(): _panel.hide())

extends HBoxContainer
class_name AudioControls
## Volume control widget for the bottom bar.
## Mute toggle button + volume slider.

var _mute_btn: Button
var _volume_slider: HSlider

func _ready() -> void:
	_build_ui()
	_sync_from_sound_manager()
	if SoundManager:
		SoundManager.mute_state_changed.connect(_on_mute_state_changed)

func _build_ui() -> void:
	# Mute toggle button
	_mute_btn = Button.new()
	_mute_btn.text = "Sound"
	_mute_btn.toggle_mode = true
	_mute_btn.tooltip_text = "Toggle sound on/off"
	_mute_btn.custom_minimum_size = Vector2(60, 0)
	_mute_btn.add_theme_font_size_override("font_size", 11)
	_mute_btn.toggled.connect(_on_mute_toggled)
	add_child(_mute_btn)

	# Volume slider
	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.05
	_volume_slider.custom_minimum_size = Vector2(80, 0)
	_volume_slider.tooltip_text = "Master volume"
	_volume_slider.value_changed.connect(_on_volume_changed)
	add_child(_volume_slider)

func _sync_from_sound_manager() -> void:
	if not SoundManager:
		return
	_mute_btn.button_pressed = SoundManager.is_muted
	_mute_btn.text = "Muted" if SoundManager.is_muted else "Sound"
	_volume_slider.value = SoundManager.master_volume
	_volume_slider.editable = not SoundManager.is_muted

func _on_mute_toggled(toggled_on: bool) -> void:
	SoundManager.set_muted(toggled_on)
	_mute_btn.text = "Muted" if toggled_on else "Sound"
	_volume_slider.editable = not toggled_on

func _on_volume_changed(value: float) -> void:
	SoundManager.set_master_volume(value)

func _on_mute_state_changed(_muted: bool) -> void:
	_sync_from_sound_manager()

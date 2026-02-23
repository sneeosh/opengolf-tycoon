extends PanelContainer
class_name ScenarioObjectivesHUD
## ScenarioObjectivesHUD - Small in-game overlay showing current scenario objectives

var _scenario_system: ScenarioSystem = null
var _vbox: VBoxContainer = null
var _time_label: Label = null
var _objective_labels: Array = []

func setup(system: ScenarioSystem) -> void:
	_scenario_system = system
	if _scenario_system:
		_scenario_system.progress_updated.connect(_refresh)
		_scenario_system.scenario_won.connect(_on_scenario_won)
		_scenario_system.scenario_failed.connect(_on_scenario_failed)
	_build_ui()
	visible = false

func _build_ui() -> void:
	# Compact panel in top-right area
	custom_minimum_size = Vector2(220, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	style.border_color = Color(0.3, 0.3, 0.4, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 3)
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vbox)

	# Title
	var title = Label.new()
	title.text = "Scenario"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(title)

	# Time remaining
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 10)
	_time_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_time_label)

func show_objectives() -> void:
	if not _scenario_system or not _scenario_system.is_scenario_active:
		visible = false
		return

	visible = true
	_refresh()

func _refresh() -> void:
	if not _scenario_system or not _scenario_system.is_scenario_active:
		visible = false
		return

	# Clear old objective labels
	for lbl in _objective_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	_objective_labels.clear()

	# Update time
	var remaining = _scenario_system.get_time_remaining()
	if remaining >= 0:
		_time_label.text = "Days left: %d" % remaining
		if remaining <= 7:
			_time_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		else:
			_time_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		_time_label.visible = true
	else:
		_time_label.visible = false

	# Show objectives
	var objectives = _scenario_system.get_objectives_display()
	for obj in objectives:
		var lbl = Label.new()
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if obj["met"]:
			lbl.text = "[x] %s" % obj["label"]
			lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
		else:
			lbl.text = "[ ] %s (%d/%d)" % [obj["label"], obj["progress"], obj["target"]]
			lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

		_vbox.add_child(lbl)
		_objective_labels.append(lbl)

func _on_scenario_won(_scenario_id: String, _stars: int) -> void:
	visible = false

func _on_scenario_failed(_scenario_id: String, _reason: String) -> void:
	visible = false

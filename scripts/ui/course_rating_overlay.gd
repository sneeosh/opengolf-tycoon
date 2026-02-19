extends Control
class_name CourseRatingOverlay
## CourseRatingOverlay - Shows live course rating in the bottom-left during build mode
##
## Displays overall star rating and category breakdown so the player gets
## real-time feedback while designing their course. Hides during simulation
## and main menu. Updates on terrain changes and hole creation/deletion.

const PANEL_WIDTH := 200.0
const UPDATE_INTERVAL := 1.0  # Seconds between recalculations

var _panel: PanelContainer = null
var _overall_label: Label = null
var _condition_label: Label = null
var _design_label: Label = null
var _value_label: Label = null
var _difficulty_label: Label = null
var _update_timer: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()

	EventBus.game_mode_changed.connect(_on_mode_changed)
	EventBus.hole_created.connect(func(_h, _p, _d): _update_rating())
	EventBus.hole_deleted.connect(func(_h): _update_rating())
	EventBus.terrain_tile_changed.connect(func(_p, _o, _n): _schedule_update())

	# Initial state
	visible = GameManager.current_mode == GameManager.GameMode.BUILDING

func _build_ui() -> void:
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.06, 0.88)
	style.border_color = UIConstants.COLOR_PRIMARY
	style.border_width_left = 2
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Course Rating"
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	title.add_theme_color_override("font_color", UIConstants.COLOR_GOLD)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	_overall_label = _add_row(vbox, "Overall:", "---")
	_condition_label = _add_row(vbox, "Condition:", "---")
	_design_label = _add_row(vbox, "Design:", "---")
	_value_label = _add_row(vbox, "Value:", "---")
	_difficulty_label = _add_row(vbox, "Difficulty:", "---")

func _add_row(parent: VBoxContainer, label_text: String, initial_value: String) -> Label:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
	lbl.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	var val := Label.new()
	val.text = initial_value
	val.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
	val.add_theme_color_override("font_color", UIConstants.COLOR_TEXT)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(val)

	parent.add_child(row)
	return val

func _schedule_update() -> void:
	_update_timer = UPDATE_INTERVAL  # Will recalculate on next _process tick

func _process(delta: float) -> void:
	if not visible:
		return
	if _update_timer > 0:
		_update_timer -= delta
		if _update_timer <= 0:
			_update_rating()

func _update_rating() -> void:
	if not GameManager.current_course or not GameManager.terrain_grid:
		return

	var rating := CourseRatingSystem.calculate_rating(
		GameManager.terrain_grid,
		GameManager.current_course,
		GameManager.daily_stats,
		GameManager.green_fee,
		GameManager.reputation
	)

	var stars := rating.get("overall", 3.0)
	_overall_label.text = "%s (%.1f)" % [CourseRatingSystem.get_star_display(stars), stars]
	_overall_label.add_theme_color_override("font_color", _star_color(stars))

	_condition_label.text = "%.1f" % rating.get("condition", 0.0)
	_design_label.text = "%.1f" % rating.get("design", 0.0)
	_value_label.text = "%.1f" % rating.get("value", 0.0)

	var diff: float = rating.get("difficulty", 5.0)
	_difficulty_label.text = "%s (%.1f)" % [CourseRatingSystem.get_difficulty_text(diff), diff]

func _star_color(stars: float) -> Color:
	if stars >= 4.0:
		return UIConstants.COLOR_GOLD
	elif stars >= 3.0:
		return UIConstants.COLOR_SUCCESS
	elif stars >= 2.0:
		return UIConstants.COLOR_WARNING
	return UIConstants.COLOR_DANGER

func _on_mode_changed(_old: int, new_mode: int) -> void:
	visible = new_mode == GameManager.GameMode.BUILDING
	if visible:
		_update_rating()

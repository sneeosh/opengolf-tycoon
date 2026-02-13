extends CanvasLayer
class_name GolfHUD
## GolfHUD - UI overlay for player golf mode
##
## Shows club selection, power meter, wind info, scorecard, and aim indicator.

signal exit_player_mode()

var _controller: PlayerGolferController = null
var _golfer: Golfer = null

# UI elements
var _club_bar: HBoxContainer = null
var _club_buttons: Array[Button] = []
var _power_bar: ProgressBar = null
var _power_label: Label = null
var _wind_label: Label = null
var _hole_info_label: Label = null
var _score_label: Label = null
var _distance_label: Label = null
var _exit_btn: Button = null
var _instruction_label: Label = null

func setup(controller: PlayerGolferController, golfer: Golfer) -> void:
	_controller = controller
	_golfer = golfer
	_controller.club_changed.connect(_on_club_changed)
	_controller.power_changed.connect(_on_power_changed)
	_controller.aim_updated.connect(_on_aim_updated)

func _ready() -> void:
	layer = 10  # Above game content

	var panel = PanelContainer.new()
	panel.name = "GolfHUDPanel"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.1, 0.05, 0.85)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	# Anchor to bottom center
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -120
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Top row: hole info + wind + score
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 20)
	vbox.add_child(top_row)

	_hole_info_label = Label.new()
	_hole_info_label.text = "Hole 1 - Par 4 - 350 yds"
	_hole_info_label.add_theme_font_size_override("font_size", 14)
	_hole_info_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7))
	top_row.add_child(_hole_info_label)

	var spacer1 = Control.new()
	spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer1)

	_wind_label = Label.new()
	_wind_label.text = "Wind: 5 mph NE"
	_wind_label.add_theme_font_size_override("font_size", 13)
	_wind_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	top_row.add_child(_wind_label)

	var spacer2 = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer2)

	_score_label = Label.new()
	_score_label.text = "Score: E"
	_score_label.add_theme_font_size_override("font_size", 14)
	_score_label.add_theme_color_override("font_color", Color.WHITE)
	top_row.add_child(_score_label)

	# Middle row: club selection bar
	_club_bar = HBoxContainer.new()
	_club_bar.add_theme_constant_override("separation", 4)
	_club_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_club_bar)

	var clubs = [
		{"name": "Driver", "key": "1", "club": Golfer.Club.DRIVER},
		{"name": "3-Wood", "key": "2", "club": Golfer.Club.FAIRWAY_WOOD},
		{"name": "Iron", "key": "3", "club": Golfer.Club.IRON},
		{"name": "Wedge", "key": "4", "club": Golfer.Club.WEDGE},
		{"name": "Putter", "key": "5", "club": Golfer.Club.PUTTER},
	]

	for club_data in clubs:
		var btn = Button.new()
		btn.text = "[%s] %s" % [club_data.key, club_data.name]
		btn.custom_minimum_size = Vector2(100, 30)
		btn.pressed.connect(_on_club_button_pressed.bind(club_data.club))
		_club_bar.add_child(btn)
		_club_buttons.append(btn)

	# Bottom row: power meter + distance + instructions
	var bottom_row = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 12)
	vbox.add_child(bottom_row)

	var power_container = VBoxContainer.new()
	power_container.add_theme_constant_override("separation", 2)
	bottom_row.add_child(power_container)

	_power_label = Label.new()
	_power_label.text = "Power: 100%"
	_power_label.add_theme_font_size_override("font_size", 12)
	_power_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	power_container.add_child(_power_label)

	_power_bar = ProgressBar.new()
	_power_bar.custom_minimum_size = Vector2(200, 16)
	_power_bar.min_value = 0.0
	_power_bar.max_value = 1.0
	_power_bar.value = 1.0
	_power_bar.show_percentage = false
	power_container.add_child(_power_bar)

	var spacer3 = Control.new()
	spacer3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(spacer3)

	_distance_label = Label.new()
	_distance_label.text = "Distance: 250 yds"
	_distance_label.add_theme_font_size_override("font_size", 13)
	_distance_label.add_theme_color_override("font_color", Color.WHITE)
	bottom_row.add_child(_distance_label)

	var spacer4 = Control.new()
	spacer4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(spacer4)

	_instruction_label = Label.new()
	_instruction_label.text = "Aim with mouse | Space/Click = Power meter | 1-5 = Clubs"
	_instruction_label.add_theme_font_size_override("font_size", 11)
	_instruction_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	bottom_row.add_child(_instruction_label)

	# Exit button (top-right)
	_exit_btn = Button.new()
	_exit_btn.text = "Exit Player Mode"
	_exit_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_exit_btn.offset_left = -140
	_exit_btn.offset_right = -10
	_exit_btn.offset_top = 10
	_exit_btn.offset_bottom = 40
	_exit_btn.pressed.connect(_on_exit_pressed)
	add_child(_exit_btn)

func _process(_delta: float) -> void:
	if not _golfer:
		return
	_update_hole_info()
	_update_score()
	_update_wind()

func _update_hole_info() -> void:
	var course_data = GameManager.course_data
	if not course_data or _golfer.current_hole >= course_data.holes.size():
		return
	var hole = course_data.holes[_golfer.current_hole]
	_hole_info_label.text = "Hole %d - Par %d - %d yds | Stroke %d" % [
		hole.hole_number, hole.par, hole.distance_yards, _golfer.current_strokes + 1
	]

func _update_score() -> void:
	var diff = _golfer.total_strokes - _golfer.total_par
	var score_text: String
	if diff == 0:
		score_text = "E"
	elif diff > 0:
		score_text = "+%d" % diff
	else:
		score_text = "%d" % diff
	_score_label.text = "Score: %s (Thru %d)" % [score_text, _golfer.current_hole]

func _update_wind() -> void:
	if GameManager.wind_system:
		var speed = GameManager.wind_system.wind_speed
		var dir = GameManager.wind_system.wind_direction
		var degrees = fmod(rad_to_deg(dir) + 360.0, 360.0)
		var dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
		var dir_name = dirs[int(round(degrees / 45.0)) % 8]
		_wind_label.text = "Wind: %d mph %s" % [int(speed), dir_name]

func _on_club_changed(club: int) -> void:
	# Highlight selected club button
	for i in range(_club_buttons.size()):
		if i == club:
			_club_buttons[i].modulate = Color(1.0, 1.0, 0.6)
		else:
			_club_buttons[i].modulate = Color.WHITE

func _on_power_changed(power: float) -> void:
	_power_bar.value = power
	_power_label.text = "Power: %d%%" % int(power * 100)

	# Color the power bar
	if power < 0.3:
		_power_bar.modulate = Color(0.5, 0.8, 1.0)  # Blue = soft
	elif power < 0.7:
		_power_bar.modulate = Color(0.5, 1.0, 0.5)  # Green = good
	elif power < 0.9:
		_power_bar.modulate = Color(1.0, 0.9, 0.3)  # Yellow = strong
	else:
		_power_bar.modulate = Color(1.0, 0.4, 0.3)  # Red = max

func _on_aim_updated(_direction: Vector2, distance: float) -> void:
	if _controller:
		_distance_label.text = "%s: %d yds" % [_controller.get_club_name(), _controller.get_shot_distance_yards()]

func _on_club_button_pressed(club: int) -> void:
	if _controller:
		_controller._set_club(club)

func _on_exit_pressed() -> void:
	exit_player_mode.emit()

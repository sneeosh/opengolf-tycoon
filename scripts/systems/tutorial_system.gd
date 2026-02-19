extends Node
class_name TutorialSystem
## TutorialSystem - Step-by-step guided onboarding for new players
##
## Guides the player through their first course setup: terrain painting,
## hole creation, building placement, and starting simulation.
## Tutorial state persists via SaveManager settings.

signal tutorial_completed
signal step_changed(step_index: int)

enum Step {
	WELCOME,
	PAINT_TERRAIN,
	CREATE_HOLE,
	PLACE_BUILDING,
	START_SIMULATION,
	ADJUST_FEES,
	COMPLETED,
}

const STEP_DATA = {
	Step.WELCOME: {
		"title": "Welcome to OpenGolf Tycoon!",
		"message": "You'll design a golf course, attract golfers, and grow your business.\n\nLet's get started with the basics.",
		"action": "Click 'Next' to continue",
		"requires_action": false,
	},
	Step.PAINT_TERRAIN: {
		"title": "Step 1: Paint Your Course",
		"message": "Use the terrain tools on the left to paint fairways, greens, and hazards.\n\nClick on a terrain type in the toolbar, then click and drag on the map to paint.",
		"action": "Paint some terrain to continue",
		"requires_action": true,
		"signal": "terrain_tile_changed",
	},
	Step.CREATE_HOLE: {
		"title": "Step 2: Create a Hole",
		"message": "Press H or click 'Create Hole' in the toolbar.\n\n1. Click to place the tee box\n2. Click to place the green\n3. Click to place the flag",
		"action": "Create your first hole to continue",
		"requires_action": true,
		"signal": "hole_created",
	},
	Step.PLACE_BUILDING: {
		"title": "Step 3: Place a Building",
		"message": "Press B to open the building menu.\n\nBuildings like the Clubhouse and Pro Shop generate extra revenue from golfers.",
		"action": "Place a building to continue (or skip)",
		"requires_action": true,
		"signal": "building_placed",
		"skippable": true,
	},
	Step.START_SIMULATION: {
		"title": "Step 4: Open Your Course",
		"message": "Click the Play button at the bottom to start the simulation.\n\nGolfers will begin arriving to play your course!",
		"action": "Press Play to start the simulation",
		"requires_action": true,
		"signal": "game_mode_changed",
	},
	Step.ADJUST_FEES: {
		"title": "Step 5: Manage Your Business",
		"message": "Click the money display at the top to open the Financial Panel.\n\nAdjust your green fee to balance revenue vs. golfer volume.\n\nTip: Press G for milestones, C for calendar, F1 for all hotkeys.",
		"action": "Open the Financial Panel or skip",
		"requires_action": true,
		"signal": "green_fee_changed",
		"skippable": true,
	},
	Step.COMPLETED: {
		"title": "Tutorial Complete!",
		"message": "You've learned the basics. Here are some tips:\n\n- More holes = more golfers = more revenue\n- Watch the course rating for feedback\n- Build amenities near the course for extra income\n- Check milestones (G) for goals and rewards\n\nGood luck!",
		"action": "",
		"requires_action": false,
	},
}

var current_step: int = Step.WELCOME
var is_active: bool = false
var _overlay: Control = null
var _panel: PanelContainer = null
var _message_label: Label = null
var _action_label: Label = null
var _next_btn: Button = null
var _skip_btn: Button = null

func start_tutorial() -> void:
	if is_active:
		return
	is_active = true
	current_step = Step.WELCOME
	_create_ui()
	_update_display()
	_connect_step_signals()

func _create_ui() -> void:
	_overlay = Control.new()
	_overlay.name = "TutorialOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.08, 0.95)
	style.border_color = Color(0.4, 0.8, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(420, 0)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	# Step indicator
	var step_label = Label.new()
	step_label.name = "StepLabel"
	step_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
	step_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
	vbox.add_child(step_label)

	# Title
	var title = Label.new()
	title.name = "TitleLabel"
	title.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_MD)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 0.75))
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Message
	_message_label = Label.new()
	_message_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	_message_label.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_DIM)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_message_label.custom_minimum_size = Vector2(380, 0)
	vbox.add_child(_message_label)

	# Action hint
	_action_label = Label.new()
	_action_label.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	_action_label.add_theme_color_override("font_color", UIConstants.COLOR_SUCCESS_DIM)
	vbox.add_child(_action_label)

	# Buttons
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)

	_skip_btn = Button.new()
	_skip_btn.text = "Skip"
	_skip_btn.custom_minimum_size = Vector2(80, 30)
	_skip_btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	_skip_btn.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
	_skip_btn.pressed.connect(_on_skip)
	btn_row.add_child(_skip_btn)

	_next_btn = Button.new()
	_next_btn.text = "Next"
	_next_btn.custom_minimum_size = Vector2(100, 30)
	_next_btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_SM)
	_next_btn.pressed.connect(_on_next)
	btn_row.add_child(_next_btn)

	# Dismiss tutorial button
	var dismiss_btn = Button.new()
	dismiss_btn.text = "Skip Tutorial"
	dismiss_btn.custom_minimum_size = Vector2(110, 30)
	dismiss_btn.add_theme_font_size_override("font_size", UIConstants.FONT_SIZE_XS)
	dismiss_btn.add_theme_color_override("font_color", UIConstants.COLOR_TEXT_MUTED)
	dismiss_btn.pressed.connect(_finish_tutorial)
	btn_row.add_child(dismiss_btn)

	_overlay.add_child(_panel)
	# Position at top-center
	_panel.position = Vector2(590, 55)

func _update_display() -> void:
	if not _panel:
		return

	var data = STEP_DATA.get(current_step, {})

	var step_label = _panel.find_child("StepLabel", true, false)
	if step_label:
		if current_step < Step.COMPLETED:
			step_label.text = "Tutorial (%d / %d)" % [current_step + 1, Step.COMPLETED]
		else:
			step_label.text = "Tutorial"

	var title_label = _panel.find_child("TitleLabel", true, false)
	if title_label:
		title_label.text = data.get("title", "")

	_message_label.text = data.get("message", "")
	_action_label.text = data.get("action", "")

	var requires_action = data.get("requires_action", false)
	var skippable = data.get("skippable", false)

	# Show next button only for non-action steps
	_next_btn.visible = not requires_action or current_step == Step.COMPLETED
	if current_step == Step.COMPLETED:
		_next_btn.text = "Finish"

	# Show skip for skippable action steps
	_skip_btn.visible = skippable

	step_changed.emit(current_step)

func _on_next() -> void:
	if current_step == Step.COMPLETED:
		_finish_tutorial()
		return
	_advance_step()

func _on_skip() -> void:
	_advance_step()

func _advance_step() -> void:
	_disconnect_step_signals()
	current_step += 1
	if current_step > Step.COMPLETED:
		current_step = Step.COMPLETED
	_update_display()
	_connect_step_signals()

func _finish_tutorial() -> void:
	is_active = false
	_disconnect_step_signals()
	if _overlay and _overlay.is_inside_tree():
		_overlay.queue_free()
	_overlay = null
	_panel = null
	_save_tutorial_completed()
	tutorial_completed.emit()

func _connect_step_signals() -> void:
	var data = STEP_DATA.get(current_step, {})
	var signal_name = data.get("signal", "")
	if signal_name == "":
		return

	match signal_name:
		"terrain_tile_changed":
			if not EventBus.terrain_tile_changed.is_connected(_on_tutorial_signal):
				EventBus.terrain_tile_changed.connect(_on_tutorial_signal)
		"hole_created":
			if not EventBus.hole_created.is_connected(_on_tutorial_hole_created):
				EventBus.hole_created.connect(_on_tutorial_hole_created)
		"building_placed":
			if not EventBus.building_placed.is_connected(_on_tutorial_building_placed):
				EventBus.building_placed.connect(_on_tutorial_building_placed)
		"game_mode_changed":
			if not EventBus.game_mode_changed.is_connected(_on_tutorial_mode_changed):
				EventBus.game_mode_changed.connect(_on_tutorial_mode_changed)
		"green_fee_changed":
			if not EventBus.green_fee_changed.is_connected(_on_tutorial_fee_changed):
				EventBus.green_fee_changed.connect(_on_tutorial_fee_changed)

func _disconnect_step_signals() -> void:
	if EventBus.terrain_tile_changed.is_connected(_on_tutorial_signal):
		EventBus.terrain_tile_changed.disconnect(_on_tutorial_signal)
	if EventBus.hole_created.is_connected(_on_tutorial_hole_created):
		EventBus.hole_created.disconnect(_on_tutorial_hole_created)
	if EventBus.building_placed.is_connected(_on_tutorial_building_placed):
		EventBus.building_placed.disconnect(_on_tutorial_building_placed)
	if EventBus.game_mode_changed.is_connected(_on_tutorial_mode_changed):
		EventBus.game_mode_changed.disconnect(_on_tutorial_mode_changed)
	if EventBus.green_fee_changed.is_connected(_on_tutorial_fee_changed):
		EventBus.green_fee_changed.disconnect(_on_tutorial_fee_changed)

func _on_tutorial_signal(_a = null, _b = null, _c = null) -> void:
	_advance_step()

func _on_tutorial_hole_created(_hole: int, _par: int, _dist: int) -> void:
	_advance_step()

func _on_tutorial_building_placed(_type: String, _pos: Vector2i) -> void:
	_advance_step()

func _on_tutorial_mode_changed(_old: int, new_mode: int) -> void:
	if new_mode == GameManager.GameMode.SIMULATING:
		_advance_step()

func _on_tutorial_fee_changed(_old: int, _new: int) -> void:
	_advance_step()

## Get the overlay node to add to the UI tree
func get_overlay() -> Control:
	return _overlay

## Check if tutorial has been completed before
static func is_tutorial_completed() -> bool:
	var config = ConfigFile.new()
	if config.load(SaveManager.SETTINGS_PATH) != OK:
		return false
	return config.get_value("tutorial", "completed", false)

func _save_tutorial_completed() -> void:
	var config = ConfigFile.new()
	config.load(SaveManager.SETTINGS_PATH)
	config.set_value("tutorial", "completed", true)
	config.save(SaveManager.SETTINGS_PATH)

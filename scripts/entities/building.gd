extends Node2D
class_name Building
## Building - Represents a building entity on the course

var building_type: String = "clubhouse"
var grid_position: Vector2i = Vector2i(0, 0)
var width: int = 4
var height: int = 4
var upgrade_level: int = 1  # Current upgrade level (1-3 for clubhouse)
var total_revenue: int = 0  # Lifetime revenue collected by this building

var terrain_grid: TerrainGrid
var building_data: Dictionary = {}

## Shadow references for updates when sun changes
var _shadow_refs: Dictionary = {}
var _shadow_config: ShadowRenderer.ShadowConfig = null
var _custom_shadow: Polygon2D = null  # Building-specific shadow shape

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D if has_node("Area2D/CollisionShape2D") else null

signal building_selected(building: Building)
signal building_destroyed(building: Building)

func _ready() -> void:
	add_to_group("buildings")

	# Load building data if not already set
	if building_data.is_empty():
		var buildings_json = FileAccess.open("res://data/buildings.json", FileAccess.READ)
		if buildings_json:
			var data = JSON.parse_string(buildings_json.get_as_text())
			if data and data.has("buildings") and data["buildings"].has(building_type):
				building_data = data["buildings"][building_type]

	# Update size from building data if available
	if building_data.has("size"):
		var size = building_data["size"]
		width = size[0]
		height = size[1]

	_update_visuals()

	# Connect to sun direction changes if ShadowSystem is available
	if has_node("/root/ShadowSystem"):
		var shadow_system = get_node("/root/ShadowSystem")
		if shadow_system.has_signal("sun_direction_changed"):
			shadow_system.sun_direction_changed.connect(_on_sun_direction_changed)

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		building_selected.emit(self)

func set_terrain_grid(grid: TerrainGrid) -> void:
	terrain_grid = grid

func set_position_in_grid(pos: Vector2i) -> void:
	grid_position = pos
	# Calculate world position from grid position
	if terrain_grid:
		var world_pos = terrain_grid.grid_to_screen(pos)
		global_position = world_pos

func get_footprint() -> Array:
	"""Returns array of grid positions occupied by this building"""
	var footprint: Array = []
	for x in range(width):
		for y in range(height):
			footprint.append(grid_position + Vector2i(x, y))
	return footprint

## Check if this building can be upgraded
func can_upgrade() -> bool:
	if not building_data.get("upgradeable", false):
		return false
	var upgrades = building_data.get("upgrades", [])
	return upgrade_level < upgrades.size()

## Get cost of next upgrade (returns 0 if can't upgrade)
func get_upgrade_cost() -> int:
	if not can_upgrade():
		return 0
	var upgrades = building_data.get("upgrades", [])
	if upgrade_level < upgrades.size():
		return upgrades[upgrade_level].get("upgrade_cost", 0)
	return 0

## Get current upgrade data
func get_current_upgrade_data() -> Dictionary:
	var upgrades = building_data.get("upgrades", [])
	if upgrade_level > 0 and upgrade_level <= upgrades.size():
		return upgrades[upgrade_level - 1]
	return {}

## Get next upgrade data (for preview)
func get_next_upgrade_data() -> Dictionary:
	var upgrades = building_data.get("upgrades", [])
	if upgrade_level < upgrades.size():
		return upgrades[upgrade_level]
	return {}

## Upgrade to next level
func upgrade() -> bool:
	if not can_upgrade():
		return false

	var cost = get_upgrade_cost()
	if not GameManager.can_afford(cost):
		if GameManager.is_bankrupt():
			EventBus.notify("Spending blocked! Balance below -$1,000", "error")
		else:
			EventBus.notify("Cannot afford upgrade ($%d)" % cost, "error")
		return false

	GameManager.modify_money(-cost)
	EventBus.log_transaction("Upgraded %s" % building_type, -cost)

	upgrade_level += 1

	# Refresh visuals - use call_deferred to avoid race with queue_free
	for child in get_children():
		if child.name == "Visual":
			child.queue_free()
	call_deferred("_update_visuals")

	EventBus.building_upgraded.emit(self, upgrade_level)
	return true

## Get display name based on upgrade level
func get_display_name() -> String:
	var upgrade_data = get_current_upgrade_data()
	if upgrade_data.has("name"):
		return upgrade_data["name"]
	return building_data.get("name", building_type.capitalize())

## Get income per golfer based on upgrade level
func get_income_per_golfer() -> int:
	var upgrade_data = get_current_upgrade_data()
	if upgrade_data.has("income_per_golfer"):
		return upgrade_data["income_per_golfer"]
	return building_data.get("income_per_golfer", 0)

## Get satisfaction bonus based on upgrade level
func get_satisfaction_bonus() -> float:
	var upgrade_data = get_current_upgrade_data()
	if upgrade_data.has("satisfaction_bonus"):
		return upgrade_data["satisfaction_bonus"]
	return 0.0

## Get daily operating cost from building data
func get_operating_cost() -> int:
	return building_data.get("operating_cost", 0)

func destroy() -> void:
	building_destroyed.emit(self)
	queue_free()

func _update_visuals() -> void:
	"""Create visual representation for the building with shadows"""
	# Create a Node2D to hold the visual
	var visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)

	# Define colors and styles for each building type
	var tile_w = 64
	var tile_h = 32

	var size_x = width * tile_w
	var size_y = height * tile_h

	# Configure shadow based on building size
	var visual_height = size_y * 0.6  # Buildings are taller than their footprint
	_shadow_config = ShadowRenderer.ShadowConfig.new(visual_height, size_x * 0.8)
	_shadow_config.base_offset = Vector2(size_x * 0.5, size_y + 2)

	# Get shadow system for consistent colors
	var shadow_system: Node = null
	if has_node("/root/ShadowSystem"):
		shadow_system = get_node("/root/ShadowSystem")

	# Add contact shadow (AO) at building base
	if _shadow_config.cast_contact_shadow:
		var contact = ShadowRenderer.create_contact_shadow_polygon(_shadow_config, shadow_system)
		contact.z_index = -2
		visual.add_child(contact)
		_shadow_refs["contact"] = contact

	# Draw based on building type (each draws its own drop shadow)
	match building_type:
		"clubhouse":
			_draw_clubhouse(visual, size_x, size_y)
		"pro_shop":
			_draw_pro_shop(visual, size_x, size_y)
		"restaurant":
			_draw_restaurant(visual, size_x, size_y)
		"snack_bar":
			_draw_snack_bar(visual, size_x, size_y)
		"driving_range":
			_draw_driving_range(visual, size_x, size_y)
		"cart_shed":
			_draw_cart_shed(visual, size_x, size_y)
		"restroom":
			_draw_restroom(visual, size_x, size_y)
		"bench":
			_draw_bench(visual, size_x, size_y)
		_:
			_draw_generic(visual, size_x, size_y)

	# Add isometric side wall strip for 3D depth (skip bench — it's open)
	if building_type != "bench":
		_add_isometric_depth(visual, size_x, size_y)

	# Add click detection area
	var click_area = Area2D.new()
	click_area.name = "ClickArea"
	click_area.input_pickable = true
	add_child(click_area)

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(size_x, size_y)
	collision.shape = shape
	collision.position = Vector2(size_x / 2, size_y / 2)
	click_area.add_child(collision)

	# Connect click detection
	click_area.input_event.connect(_on_click_area_input_event)

func _add_isometric_depth(visual: Node2D, width_px: int, height_px: int) -> void:
	"""Add a side wall strip and roof overhang shadow for isometric 3D depth"""
	var depth = 6  # Pixel width of the side face

	# Side wall strip — darker version of the building, on the right edge
	var side_wall = Polygon2D.new()
	side_wall.name = "SideWall"
	side_wall.color = Color(0, 0, 0, 0.18)  # Dark overlay on right edge
	side_wall.polygon = PackedVector2Array([
		Vector2(width_px, height_px * 0.18),
		Vector2(width_px + depth, height_px * 0.18 + depth * 0.5),
		Vector2(width_px + depth, height_px + depth * 0.5),
		Vector2(width_px, height_px)
	])
	visual.add_child(side_wall)

	# Roof overhang shadow on the front face — subtle darkening along the roofline
	var roof_shadow = Polygon2D.new()
	roof_shadow.name = "RoofOverhangShadow"
	roof_shadow.color = Color(0, 0, 0, 0.08)
	roof_shadow.polygon = PackedVector2Array([
		Vector2(0, height_px * 0.18),
		Vector2(width_px, height_px * 0.18),
		Vector2(width_px, height_px * 0.28),
		Vector2(0, height_px * 0.28)
	])
	visual.add_child(roof_shadow)

func _draw_clubhouse(visual: Node2D, width_px: int, height_px: int) -> void:
	"""Draw clubhouse - appearance varies by upgrade level"""
	# Ground shadow (custom shape for building)
	var shadow = Polygon2D.new()
	shadow.name = "DropShadow"
	shadow.color = _get_shadow_color()
	shadow.polygon = PackedVector2Array([
		Vector2(6, height_px + 2),
		Vector2(width_px + 10, height_px + 2),
		Vector2(width_px + 14, height_px + 8),
		Vector2(10, height_px + 8)
	])
	shadow.z_index = -1
	visual.add_child(shadow)
	_custom_shadow = shadow

	# Foundation/base strip
	var foundation = Polygon2D.new()
	foundation.color = Color(0.45, 0.42, 0.38)
	foundation.polygon = PackedVector2Array([
		Vector2(-2, height_px - 6),
		Vector2(width_px + 2, height_px - 6),
		Vector2(width_px + 2, height_px + 2),
		Vector2(-2, height_px + 2)
	])
	visual.add_child(foundation)

	# Wall colors by upgrade level
	var wall_colors = [
		Color(0.96, 0.94, 0.88),  # Level 1: Warm cream
		Color(0.92, 0.87, 0.78),  # Level 2: Soft tan
		Color(0.88, 0.82, 0.72),  # Level 3: Rich beige
	]
	var wall_color = wall_colors[min(upgrade_level - 1, 2)]

	# Main wall with subtle texture lines
	var main_wall = Polygon2D.new()
	main_wall.color = wall_color
	main_wall.polygon = PackedVector2Array([
		Vector2(0, height_px * 0.18),
		Vector2(width_px, height_px * 0.18),
		Vector2(width_px, height_px - 6),
		Vector2(0, height_px - 6)
	])
	visual.add_child(main_wall)

	# Horizontal siding lines for texture
	for i in range(4):
		var line_y = height_px * (0.32 + i * 0.15)
		var siding = Polygon2D.new()
		siding.color = wall_color.darkened(0.08)
		siding.polygon = PackedVector2Array([
			Vector2(2, line_y),
			Vector2(width_px - 2, line_y),
			Vector2(width_px - 2, line_y + 2),
			Vector2(2, line_y + 2)
		])
		visual.add_child(siding)

	# Trim under roof
	var trim = Polygon2D.new()
	trim.color = Color(0.98, 0.98, 0.96)
	trim.polygon = PackedVector2Array([
		Vector2(-3, height_px * 0.15),
		Vector2(width_px + 3, height_px * 0.15),
		Vector2(width_px + 3, height_px * 0.21),
		Vector2(-3, height_px * 0.21)
	])
	visual.add_child(trim)

	# Roof colors by upgrade level
	var roof_colors = [
		Color(0.52, 0.32, 0.26),  # Level 1: Terra cotta
		Color(0.42, 0.24, 0.20),  # Level 2: Deep brown
		Color(0.28, 0.22, 0.24),  # Level 3: Charcoal slate
	]
	var roof_color = roof_colors[min(upgrade_level - 1, 2)]

	# Main roof
	var roof = Polygon2D.new()
	roof.color = roof_color
	roof.polygon = PackedVector2Array([
		Vector2(-6, height_px * 0.16),
		Vector2(width_px * 0.5, -height_px * 0.22),
		Vector2(width_px + 6, height_px * 0.16)
	])
	visual.add_child(roof)

	# Roof left slope highlight
	var roof_highlight = Polygon2D.new()
	roof_highlight.color = roof_color.lightened(0.18)
	roof_highlight.polygon = PackedVector2Array([
		Vector2(-6, height_px * 0.16),
		Vector2(width_px * 0.5, -height_px * 0.22),
		Vector2(width_px * 0.5, -height_px * 0.14),
		Vector2(0, height_px * 0.14)
	])
	visual.add_child(roof_highlight)

	# Roof edge trim
	var roof_edge = Polygon2D.new()
	roof_edge.color = roof_color.darkened(0.2)
	roof_edge.polygon = PackedVector2Array([
		Vector2(-6, height_px * 0.16),
		Vector2(width_px + 6, height_px * 0.16),
		Vector2(width_px + 6, height_px * 0.19),
		Vector2(-6, height_px * 0.19)
	])
	visual.add_child(roof_edge)

	# Chimney for level 2+
	if upgrade_level >= 2:
		var chimney_shadow = Polygon2D.new()
		chimney_shadow.color = Color(0, 0, 0, 0.15)
		chimney_shadow.polygon = PackedVector2Array([
			Vector2(width_px * 0.72, -height_px * 0.08),
			Vector2(width_px * 0.82, -height_px * 0.08),
			Vector2(width_px * 0.82, height_px * 0.02),
			Vector2(width_px * 0.72, height_px * 0.02)
		])
		visual.add_child(chimney_shadow)

		var chimney = Polygon2D.new()
		chimney.color = Color(0.6, 0.38, 0.32)
		chimney.polygon = PackedVector2Array([
			Vector2(width_px * 0.7, -height_px * 0.1),
			Vector2(width_px * 0.8, -height_px * 0.1),
			Vector2(width_px * 0.8, height_px * 0.0),
			Vector2(width_px * 0.7, height_px * 0.0)
		])
		visual.add_child(chimney)

		var chimney_cap = Polygon2D.new()
		chimney_cap.color = Color(0.5, 0.3, 0.25)
		chimney_cap.polygon = PackedVector2Array([
			Vector2(width_px * 0.68, -height_px * 0.1),
			Vector2(width_px * 0.82, -height_px * 0.1),
			Vector2(width_px * 0.82, -height_px * 0.08),
			Vector2(width_px * 0.68, -height_px * 0.08)
		])
		visual.add_child(chimney_cap)

	# Windows - positioned to avoid door (left and right sides only)
	var window_positions = []
	if upgrade_level == 1:
		window_positions = [0.18, 0.78]  # One on each side
	elif upgrade_level == 2:
		window_positions = [0.14, 0.28, 0.72, 0.86]  # Two on each side
	else:
		window_positions = [0.12, 0.26, 0.74, 0.88]  # Two on each side, spaced

	for x_ratio in window_positions:
		var x_pos = width_px * x_ratio
		_draw_window(visual, x_pos, height_px * 0.34, 22, 28, upgrade_level >= 2)

	# Door area
	var door_x = width_px * 0.5
	var door_width = width_px * 0.22
	var door_top = height_px * 0.42

	# Door frame/surround
	var door_surround = Polygon2D.new()
	door_surround.color = Color(0.35, 0.22, 0.15)
	door_surround.polygon = PackedVector2Array([
		Vector2(door_x - door_width/2 - 4, door_top - 4),
		Vector2(door_x + door_width/2 + 4, door_top - 4),
		Vector2(door_x + door_width/2 + 4, height_px - 6),
		Vector2(door_x - door_width/2 - 4, height_px - 6)
	])
	visual.add_child(door_surround)

	# Main door
	var door = Polygon2D.new()
	door.color = Color(0.48, 0.3, 0.18)
	door.polygon = PackedVector2Array([
		Vector2(door_x - door_width/2, door_top),
		Vector2(door_x + door_width/2, door_top),
		Vector2(door_x + door_width/2, height_px - 8),
		Vector2(door_x - door_width/2, height_px - 8)
	])
	visual.add_child(door)

	# Door panels for detail
	var panel_inset = 3
	var panel_color = Color(0.42, 0.26, 0.15)
	# Top panel
	var top_panel = Polygon2D.new()
	top_panel.color = panel_color
	top_panel.polygon = PackedVector2Array([
		Vector2(door_x - door_width/2 + panel_inset, door_top + 4),
		Vector2(door_x + door_width/2 - panel_inset, door_top + 4),
		Vector2(door_x + door_width/2 - panel_inset, height_px * 0.58),
		Vector2(door_x - door_width/2 + panel_inset, height_px * 0.58)
	])
	visual.add_child(top_panel)
	# Bottom panel
	var bottom_panel = Polygon2D.new()
	bottom_panel.color = panel_color
	bottom_panel.polygon = PackedVector2Array([
		Vector2(door_x - door_width/2 + panel_inset, height_px * 0.62),
		Vector2(door_x + door_width/2 - panel_inset, height_px * 0.62),
		Vector2(door_x + door_width/2 - panel_inset, height_px - 14),
		Vector2(door_x - door_width/2 + panel_inset, height_px - 14)
	])
	visual.add_child(bottom_panel)

	# Door handle
	var handle = Polygon2D.new()
	handle.color = Color(0.82, 0.68, 0.32)
	handle.polygon = PackedVector2Array([
		Vector2(door_x + door_width/2 - 8, height_px * 0.68),
		Vector2(door_x + door_width/2 - 5, height_px * 0.68),
		Vector2(door_x + door_width/2 - 5, height_px * 0.74),
		Vector2(door_x + door_width/2 - 8, height_px * 0.74)
	])
	visual.add_child(handle)

	# Awning over door for level 2+
	if upgrade_level >= 2:
		var awning_color = Color(0.65, 0.18, 0.15)
		# Awning support brackets
		var bracket_l = Polygon2D.new()
		bracket_l.color = Color(0.3, 0.2, 0.15)
		bracket_l.polygon = PackedVector2Array([
			Vector2(door_x - door_width/2 - 2, door_top - 6),
			Vector2(door_x - door_width/2 + 2, door_top - 6),
			Vector2(door_x - door_width/2 + 2, door_top - 2),
			Vector2(door_x - door_width/2 - 6, door_top - 2)
		])
		visual.add_child(bracket_l)
		var bracket_r = Polygon2D.new()
		bracket_r.color = Color(0.3, 0.2, 0.15)
		bracket_r.polygon = PackedVector2Array([
			Vector2(door_x + door_width/2 - 2, door_top - 6),
			Vector2(door_x + door_width/2 + 2, door_top - 6),
			Vector2(door_x + door_width/2 + 6, door_top - 2),
			Vector2(door_x + door_width/2 - 2, door_top - 2)
		])
		visual.add_child(bracket_r)
		# Awning
		var awning = Polygon2D.new()
		awning.color = awning_color
		awning.polygon = PackedVector2Array([
			Vector2(door_x - door_width/2 - 8, door_top - 8),
			Vector2(door_x + door_width/2 + 8, door_top - 8),
			Vector2(door_x + door_width/2 + 12, door_top + 2),
			Vector2(door_x - door_width/2 - 12, door_top + 2)
		])
		visual.add_child(awning)
		# Awning stripes
		for i in range(3):
			var stripe = Polygon2D.new()
			stripe.color = Color(0.95, 0.92, 0.88)
			var stripe_x = door_x - door_width/2 + 4 + i * (door_width / 2.5)
			stripe.polygon = PackedVector2Array([
				Vector2(stripe_x, door_top - 6),
				Vector2(stripe_x + 6, door_top - 6),
				Vector2(stripe_x + 8, door_top + 1),
				Vector2(stripe_x + 2, door_top + 1)
			])
			visual.add_child(stripe)

	# Decorative flower boxes under windows for level 3
	if upgrade_level >= 3:
		for x_ratio in window_positions:
			var x_pos = width_px * x_ratio
			_draw_flower_box(visual, x_pos, height_px * 0.66)

	# Sign above door for level 2+
	if upgrade_level >= 2:
		var sign_bg = Polygon2D.new()
		sign_bg.color = Color(0.22, 0.35, 0.22)
		sign_bg.polygon = PackedVector2Array([
			Vector2(door_x - 20, height_px * 0.26),
			Vector2(door_x + 20, height_px * 0.26),
			Vector2(door_x + 20, height_px * 0.36),
			Vector2(door_x - 20, height_px * 0.36)
		])
		visual.add_child(sign_bg)
		var sign_border = Polygon2D.new()
		sign_border.color = Color(0.8, 0.7, 0.4)
		sign_border.polygon = PackedVector2Array([
			Vector2(door_x - 21, height_px * 0.255),
			Vector2(door_x + 21, height_px * 0.255),
			Vector2(door_x + 21, height_px * 0.265),
			Vector2(door_x - 21, height_px * 0.265)
		])
		visual.add_child(sign_border)
		var sign_border2 = Polygon2D.new()
		sign_border2.color = Color(0.8, 0.7, 0.4)
		sign_border2.polygon = PackedVector2Array([
			Vector2(door_x - 21, height_px * 0.355),
			Vector2(door_x + 21, height_px * 0.355),
			Vector2(door_x + 21, height_px * 0.365),
			Vector2(door_x - 21, height_px * 0.365)
		])
		visual.add_child(sign_border2)

	# Flagpole for level 3
	if upgrade_level >= 3:
		var pole_x = width_px * 0.08
		var flagpole = Polygon2D.new()
		flagpole.color = Color(0.75, 0.75, 0.75)
		flagpole.polygon = PackedVector2Array([
			Vector2(pole_x - 1, -height_px * 0.5),
			Vector2(pole_x + 1, -height_px * 0.5),
			Vector2(pole_x + 2, height_px + 2),
			Vector2(pole_x - 2, height_px + 2)
		])
		visual.add_child(flagpole)
		# Pole ball top
		var pole_ball = Polygon2D.new()
		pole_ball.color = Color(0.85, 0.75, 0.35)
		pole_ball.polygon = PackedVector2Array([
			Vector2(pole_x - 3, -height_px * 0.52),
			Vector2(pole_x + 3, -height_px * 0.52),
			Vector2(pole_x + 3, -height_px * 0.48),
			Vector2(pole_x - 3, -height_px * 0.48)
		])
		visual.add_child(pole_ball)
		# Flag
		var flag = Polygon2D.new()
		flag.color = Color(0.2, 0.45, 0.25)
		flag.polygon = PackedVector2Array([
			Vector2(pole_x + 1, -height_px * 0.48),
			Vector2(pole_x + 22, -height_px * 0.4),
			Vector2(pole_x + 1, -height_px * 0.32)
		])
		visual.add_child(flag)


func _draw_window(visual: Node2D, x: float, y: float, w: float, h: float, has_shutters: bool) -> void:
	"""Helper to draw a window with frame and optional shutters"""
	# Window shadow/depth
	var shadow = Polygon2D.new()
	shadow.color = Color(0, 0, 0, 0.15)
	shadow.polygon = PackedVector2Array([
		Vector2(x - w/2 + 2, y + 2),
		Vector2(x + w/2 + 2, y + 2),
		Vector2(x + w/2 + 2, y + h + 2),
		Vector2(x - w/2 + 2, y + h + 2)
	])
	visual.add_child(shadow)

	# Outer frame
	var frame = Polygon2D.new()
	frame.color = Color(0.96, 0.96, 0.94)
	frame.polygon = PackedVector2Array([
		Vector2(x - w/2, y),
		Vector2(x + w/2, y),
		Vector2(x + w/2, y + h),
		Vector2(x - w/2, y + h)
	])
	visual.add_child(frame)

	# Glass
	var glass = Polygon2D.new()
	glass.color = Color(0.6, 0.78, 0.88)
	glass.polygon = PackedVector2Array([
		Vector2(x - w/2 + 3, y + 3),
		Vector2(x + w/2 - 3, y + 3),
		Vector2(x + w/2 - 3, y + h - 3),
		Vector2(x - w/2 + 3, y + h - 3)
	])
	visual.add_child(glass)

	# Glass reflection highlight
	var reflection = Polygon2D.new()
	reflection.color = Color(0.85, 0.92, 0.98, 0.5)
	reflection.polygon = PackedVector2Array([
		Vector2(x - w/2 + 4, y + 4),
		Vector2(x - w/2 + 8, y + 4),
		Vector2(x - w/2 + 6, y + h/2),
		Vector2(x - w/2 + 4, y + h/2)
	])
	visual.add_child(reflection)

	# Window cross dividers
	var divider_v = Polygon2D.new()
	divider_v.color = Color(0.94, 0.94, 0.92)
	divider_v.polygon = PackedVector2Array([
		Vector2(x - 1, y + 3),
		Vector2(x + 1, y + 3),
		Vector2(x + 1, y + h - 3),
		Vector2(x - 1, y + h - 3)
	])
	visual.add_child(divider_v)

	var divider_h = Polygon2D.new()
	divider_h.color = Color(0.94, 0.94, 0.92)
	divider_h.polygon = PackedVector2Array([
		Vector2(x - w/2 + 3, y + h/2 - 1),
		Vector2(x + w/2 - 3, y + h/2 - 1),
		Vector2(x + w/2 - 3, y + h/2 + 1),
		Vector2(x - w/2 + 3, y + h/2 + 1)
	])
	visual.add_child(divider_h)

	# Sill
	var sill = Polygon2D.new()
	sill.color = Color(0.92, 0.92, 0.9)
	sill.polygon = PackedVector2Array([
		Vector2(x - w/2 - 2, y + h),
		Vector2(x + w/2 + 2, y + h),
		Vector2(x + w/2 + 2, y + h + 4),
		Vector2(x - w/2 - 2, y + h + 4)
	])
	visual.add_child(sill)

	# Optional shutters
	if has_shutters:
		var shutter_color = Color(0.25, 0.38, 0.28)
		# Left shutter
		var shutter_l = Polygon2D.new()
		shutter_l.color = shutter_color
		shutter_l.polygon = PackedVector2Array([
			Vector2(x - w/2 - 6, y),
			Vector2(x - w/2 - 1, y),
			Vector2(x - w/2 - 1, y + h),
			Vector2(x - w/2 - 6, y + h)
		])
		visual.add_child(shutter_l)
		# Right shutter
		var shutter_r = Polygon2D.new()
		shutter_r.color = shutter_color
		shutter_r.polygon = PackedVector2Array([
			Vector2(x + w/2 + 1, y),
			Vector2(x + w/2 + 6, y),
			Vector2(x + w/2 + 6, y + h),
			Vector2(x + w/2 + 1, y + h)
		])
		visual.add_child(shutter_r)


func _draw_flower_box(visual: Node2D, x: float, y: float) -> void:
	"""Helper to draw a decorative flower box"""
	# Box
	var box = Polygon2D.new()
	box.color = Color(0.5, 0.35, 0.25)
	box.polygon = PackedVector2Array([
		Vector2(x - 14, y),
		Vector2(x + 14, y),
		Vector2(x + 12, y + 8),
		Vector2(x - 12, y + 8)
	])
	visual.add_child(box)

	# Soil
	var soil = Polygon2D.new()
	soil.color = Color(0.35, 0.25, 0.18)
	soil.polygon = PackedVector2Array([
		Vector2(x - 12, y + 1),
		Vector2(x + 12, y + 1),
		Vector2(x + 11, y + 4),
		Vector2(x - 11, y + 4)
	])
	visual.add_child(soil)

	# Flowers - simple colored dots
	var flower_colors = [Color(0.9, 0.3, 0.35), Color(0.95, 0.85, 0.3), Color(0.9, 0.5, 0.6)]
	for i in range(5):
		var flower = Polygon2D.new()
		flower.color = flower_colors[i % 3]
		var fx = x - 10 + i * 5
		flower.polygon = PackedVector2Array([
			Vector2(fx - 2, y - 3),
			Vector2(fx + 2, y - 3),
			Vector2(fx + 2, y + 1),
			Vector2(fx - 2, y + 1)
		])
		visual.add_child(flower)

func _draw_pro_shop(visual: Node2D, width_px: int, height_px: int) -> void:
	"""Draw pro shop - golf equipment store"""
	# Shadow
	var shadow = Polygon2D.new()
	shadow.name = "DropShadow"
	shadow.color = _get_shadow_color()
	shadow.polygon = PackedVector2Array([
		Vector2(3, height_px * 0.5), Vector2(width_px + 5, height_px * 0.5),
		Vector2(width_px + 7, height_px + 3), Vector2(5, height_px + 3)
	])
	shadow.z_index = -1
	visual.add_child(shadow)
	_custom_shadow = shadow

	# Main building - white/cream with green accents
	var shop = Polygon2D.new()
	shop.color = Color(0.95, 0.95, 0.92)
	shop.polygon = PackedVector2Array([
		Vector2(0, height_px * 0.15), Vector2(width_px, height_px * 0.15),
		Vector2(width_px, height_px), Vector2(0, height_px)
	])
	visual.add_child(shop)

	# Roof - green awning style
	var roof = Polygon2D.new()
	roof.color = Color(0.2, 0.5, 0.3)
	roof.polygon = PackedVector2Array([
		Vector2(-3, height_px * 0.12), Vector2(width_px + 3, height_px * 0.12),
		Vector2(width_px + 5, height_px * 0.2), Vector2(-5, height_px * 0.2)
	])
	visual.add_child(roof)

	# Large storefront window
	var window_frame = Polygon2D.new()
	window_frame.color = Color(0.25, 0.45, 0.35)
	window_frame.polygon = PackedVector2Array([
		Vector2(width_px * 0.1, height_px * 0.3), Vector2(width_px * 0.65, height_px * 0.3),
		Vector2(width_px * 0.65, height_px * 0.85), Vector2(width_px * 0.1, height_px * 0.85)
	])
	visual.add_child(window_frame)

	var window = Polygon2D.new()
	window.color = Color(0.75, 0.88, 0.95)
	window.polygon = PackedVector2Array([
		Vector2(width_px * 0.12, height_px * 0.33), Vector2(width_px * 0.63, height_px * 0.33),
		Vector2(width_px * 0.63, height_px * 0.82), Vector2(width_px * 0.12, height_px * 0.82)
	])
	visual.add_child(window)

	# Door
	var door = Polygon2D.new()
	door.color = Color(0.55, 0.4, 0.25)
	door.polygon = PackedVector2Array([
		Vector2(width_px * 0.72, height_px * 0.45), Vector2(width_px * 0.92, height_px * 0.45),
		Vector2(width_px * 0.92, height_px), Vector2(width_px * 0.72, height_px)
	])
	visual.add_child(door)

	# Golf ball logo on window
	var logo = Polygon2D.new()
	logo.color = Color(1, 1, 1, 0.6)
	var logo_points = PackedVector2Array()
	var logo_center = Vector2(width_px * 0.37, height_px * 0.55)
	for i in range(8):
		var angle = i * TAU / 8
		logo_points.append(logo_center + Vector2(cos(angle) * 8, sin(angle) * 8))
	logo.polygon = logo_points
	visual.add_child(logo)

func _draw_restaurant(visual: Node2D, width_px: int, height_px: int) -> void:
	"""Draw restaurant - dining building with warm aesthetic"""
	# Shadow
	var shadow = Polygon2D.new()
	shadow.name = "DropShadow"
	shadow.color = _get_shadow_color()
	shadow.polygon = PackedVector2Array([
		Vector2(3, height_px * 0.5), Vector2(width_px + 5, height_px * 0.5),
		Vector2(width_px + 7, height_px + 3), Vector2(5, height_px + 3)
	])
	shadow.z_index = -1
	visual.add_child(shadow)
	_custom_shadow = shadow

	# Main building - warm brick color
	var main = Polygon2D.new()
	main.color = Color(0.75, 0.55, 0.45)
	main.polygon = PackedVector2Array([
		Vector2(0, height_px * 0.15), Vector2(width_px, height_px * 0.15),
		Vector2(width_px, height_px), Vector2(0, height_px)
	])
	visual.add_child(main)

	# Roof
	var roof = Polygon2D.new()
	roof.color = Color(0.45, 0.3, 0.25)
	roof.polygon = PackedVector2Array([
		Vector2(-3, height_px * 0.15), Vector2(width_px * 0.5, -height_px * 0.15),
		Vector2(width_px + 3, height_px * 0.15)
	])
	visual.add_child(roof)

	# Warm glowing windows
	for i in range(3):
		var x_offset = width_px * (0.18 + i * 0.28)
		var window_frame = Polygon2D.new()
		window_frame.color = Color(0.35, 0.25, 0.2)
		window_frame.polygon = PackedVector2Array([
			Vector2(x_offset - 14, height_px * 0.35), Vector2(x_offset + 14, height_px * 0.35),
			Vector2(x_offset + 14, height_px * 0.7), Vector2(x_offset - 14, height_px * 0.7)
		])
		visual.add_child(window_frame)

		var window = Polygon2D.new()
		window.color = Color(1.0, 0.9, 0.6, 0.9)  # Warm glow
		window.polygon = PackedVector2Array([
			Vector2(x_offset - 11, height_px * 0.38), Vector2(x_offset + 11, height_px * 0.38),
			Vector2(x_offset + 11, height_px * 0.67), Vector2(x_offset - 11, height_px * 0.67)
		])
		visual.add_child(window)

	# Door with awning
	var awning = Polygon2D.new()
	awning.color = Color(0.7, 0.2, 0.2)
	awning.polygon = PackedVector2Array([
		Vector2(width_px * 0.38, height_px * 0.72), Vector2(width_px * 0.62, height_px * 0.72),
		Vector2(width_px * 0.65, height_px * 0.78), Vector2(width_px * 0.35, height_px * 0.78)
	])
	visual.add_child(awning)

	var door = Polygon2D.new()
	door.color = Color(0.45, 0.3, 0.2)
	door.polygon = PackedVector2Array([
		Vector2(width_px * 0.42, height_px * 0.78), Vector2(width_px * 0.58, height_px * 0.78),
		Vector2(width_px * 0.58, height_px), Vector2(width_px * 0.42, height_px)
	])
	visual.add_child(door)

func _draw_snack_bar(visual: Node2D, width_px: int, height_px: int) -> void:
	"""Draw snack bar - cheerful food kiosk"""
	# Shadow
	var shadow = Polygon2D.new()
	shadow.name = "DropShadow"
	shadow.color = _get_shadow_color()
	shadow.polygon = PackedVector2Array([
		Vector2(2, height_px * 0.4), Vector2(width_px + 4, height_px * 0.4),
		Vector2(width_px + 5, height_px + 2), Vector2(3, height_px + 2)
	])
	shadow.z_index = -1
	visual.add_child(shadow)
	_custom_shadow = shadow

	# Main kiosk - cheerful yellow/orange
	var kiosk = Polygon2D.new()
	kiosk.color = Color(0.95, 0.8, 0.3)
	kiosk.polygon = PackedVector2Array([
		Vector2(0, height_px * 0.2), Vector2(width_px, height_px * 0.2),
		Vector2(width_px, height_px), Vector2(0, height_px)
	])
	visual.add_child(kiosk)

	# Striped awning
	var awning_base = Polygon2D.new()
	awning_base.color = Color(0.9, 0.3, 0.2)
	awning_base.polygon = PackedVector2Array([
		Vector2(-4, height_px * 0.15), Vector2(width_px + 4, height_px * 0.15),
		Vector2(width_px + 6, height_px * 0.28), Vector2(-6, height_px * 0.28)
	])
	visual.add_child(awning_base)

	# Awning stripes
	for i in range(5):
		var stripe = Polygon2D.new()
		stripe.color = Color(0.95, 0.95, 0.95)
		var x1 = i * width_px / 4.5
		var x2 = x1 + width_px / 9
		stripe.polygon = PackedVector2Array([
			Vector2(x1, height_px * 0.16), Vector2(x2, height_px * 0.16),
			Vector2(x2 + 2, height_px * 0.27), Vector2(x1 + 2, height_px * 0.27)
		])
		visual.add_child(stripe)

	# Counter window
	var counter_frame = Polygon2D.new()
	counter_frame.color = Color(0.5, 0.35, 0.2)
	counter_frame.polygon = PackedVector2Array([
		Vector2(width_px * 0.1, height_px * 0.35), Vector2(width_px * 0.9, height_px * 0.35),
		Vector2(width_px * 0.9, height_px * 0.75), Vector2(width_px * 0.1, height_px * 0.75)
	])
	visual.add_child(counter_frame)

	var counter_interior = Polygon2D.new()
	counter_interior.color = Color(0.25, 0.2, 0.18)
	counter_interior.polygon = PackedVector2Array([
		Vector2(width_px * 0.12, height_px * 0.38), Vector2(width_px * 0.88, height_px * 0.38),
		Vector2(width_px * 0.88, height_px * 0.72), Vector2(width_px * 0.12, height_px * 0.72)
	])
	visual.add_child(counter_interior)

	# Counter shelf
	var shelf = Polygon2D.new()
	shelf.color = Color(0.65, 0.5, 0.35)
	shelf.polygon = PackedVector2Array([
		Vector2(width_px * 0.08, height_px * 0.73), Vector2(width_px * 0.92, height_px * 0.73),
		Vector2(width_px * 0.92, height_px * 0.78), Vector2(width_px * 0.08, height_px * 0.78)
	])
	visual.add_child(shelf)

	# Menu board
	var menu = Polygon2D.new()
	menu.color = Color(0.15, 0.15, 0.12)
	menu.polygon = PackedVector2Array([
		Vector2(width_px * 0.2, height_px * 0.42), Vector2(width_px * 0.55, height_px * 0.42),
		Vector2(width_px * 0.55, height_px * 0.58), Vector2(width_px * 0.2, height_px * 0.58)
	])
	visual.add_child(menu)

	# Menu text lines (decorative)
	for i in range(3):
		var menu_line = Polygon2D.new()
		menu_line.color = Color(1, 1, 1, 0.6)
		var y = height_px * (0.45 + i * 0.04)
		menu_line.polygon = PackedVector2Array([
			Vector2(width_px * 0.22, y), Vector2(width_px * 0.5, y),
			Vector2(width_px * 0.5, y + 2), Vector2(width_px * 0.22, y + 2)
		])
		visual.add_child(menu_line)

func _draw_driving_range(visual: Node2D, width_px: int, height_px: int) -> void:
	"""Draw driving range - practice area with covered bays"""
	# Shadow
	var shadow = Polygon2D.new()
	shadow.name = "DropShadow"
	shadow.color = _get_shadow_color()
	shadow.polygon = PackedVector2Array([
		Vector2(3, height_px * 0.4), Vector2(width_px + 5, height_px * 0.4),
		Vector2(width_px + 7, height_px + 3), Vector2(5, height_px + 3)
	])
	shadow.z_index = -1
	visual.add_child(shadow)
	_custom_shadow = shadow

	# Green turf area (outfield)
	var turf = Polygon2D.new()
	turf.color = Color(0.35, 0.65, 0.35)
	turf.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(width_px, 0),
		Vector2(width_px, height_px * 0.35), Vector2(0, height_px * 0.35)
	])
	visual.add_child(turf)

	# Target distance markers
	for i in range(3):
		var marker = Polygon2D.new()
		marker.color = Color(1, 1, 1, 0.4)
		var x = width_px * (0.3 + i * 0.25)
		marker.polygon = PackedVector2Array([
			Vector2(x - 8, height_px * 0.1), Vector2(x + 8, height_px * 0.1),
			Vector2(x + 8, height_px * 0.15), Vector2(x - 8, height_px * 0.15)
		])
		visual.add_child(marker)

	# Hitting bay structure - concrete pad
	var pad = Polygon2D.new()
	pad.color = Color(0.75, 0.72, 0.68)
	pad.polygon = PackedVector2Array([
		Vector2(0, height_px * 0.35), Vector2(width_px, height_px * 0.35),
		Vector2(width_px, height_px), Vector2(0, height_px)
	])
	visual.add_child(pad)

	# Roof/canopy structure
	var roof = Polygon2D.new()
	roof.color = Color(0.4, 0.35, 0.3)
	roof.polygon = PackedVector2Array([
		Vector2(-3, height_px * 0.32), Vector2(width_px + 3, height_px * 0.32),
		Vector2(width_px + 5, height_px * 0.42), Vector2(-5, height_px * 0.42)
	])
	visual.add_child(roof)

	# Support posts
	for i in range(4):
		var post = Polygon2D.new()
		post.color = Color(0.5, 0.45, 0.4)
		var x = width_px * (0.15 + i * 0.25)
		post.polygon = PackedVector2Array([
			Vector2(x - 3, height_px * 0.42), Vector2(x + 3, height_px * 0.42),
			Vector2(x + 3, height_px), Vector2(x - 3, height_px)
		])
		visual.add_child(post)

	# Individual hitting mats
	for i in range(3):
		var mat = Polygon2D.new()
		mat.color = Color(0.25, 0.55, 0.3)
		var x = width_px * (0.2 + i * 0.28)
		mat.polygon = PackedVector2Array([
			Vector2(x - 18, height_px * 0.55), Vector2(x + 18, height_px * 0.55),
			Vector2(x + 18, height_px * 0.9), Vector2(x - 18, height_px * 0.9)
		])
		visual.add_child(mat)

	# Ball buckets (decorative)
	for i in range(3):
		var bucket = Polygon2D.new()
		bucket.color = Color(0.85, 0.75, 0.3)
		var x = width_px * (0.28 + i * 0.28)
		bucket.polygon = PackedVector2Array([
			Vector2(x - 5, height_px * 0.7), Vector2(x + 5, height_px * 0.7),
			Vector2(x + 6, height_px * 0.82), Vector2(x - 6, height_px * 0.82)
		])
		visual.add_child(bucket)

func _draw_cart_shed(visual: Node2D, width_px: int, height_px: int) -> void:
	"""Draw cart shed - covered parking for golf carts"""
	# Shadow
	var shadow = Polygon2D.new()
	shadow.name = "DropShadow"
	shadow.color = _get_shadow_color()
	shadow.polygon = PackedVector2Array([
		Vector2(4, height_px * 0.5), Vector2(width_px + 6, height_px * 0.5),
		Vector2(width_px + 8, height_px + 4), Vector2(6, height_px + 4)
	])
	shadow.z_index = -1
	visual.add_child(shadow)
	_custom_shadow = shadow

	# Concrete floor
	var floor_pad = Polygon2D.new()
	floor_pad.color = Color(0.7, 0.68, 0.65)
	floor_pad.polygon = PackedVector2Array([
		Vector2(0, height_px * 0.6), Vector2(width_px, height_px * 0.6),
		Vector2(width_px, height_px), Vector2(0, height_px)
	])
	visual.add_child(floor_pad)

	# Back wall
	var back_wall = Polygon2D.new()
	back_wall.color = Color(0.55, 0.48, 0.42)
	back_wall.polygon = PackedVector2Array([
		Vector2(0, height_px * 0.15), Vector2(width_px, height_px * 0.15),
		Vector2(width_px, height_px * 0.6), Vector2(0, height_px * 0.6)
	])
	visual.add_child(back_wall)

	# Roof
	var roof = Polygon2D.new()
	roof.color = Color(0.35, 0.32, 0.28)
	roof.polygon = PackedVector2Array([
		Vector2(-4, height_px * 0.1), Vector2(width_px + 4, height_px * 0.1),
		Vector2(width_px + 6, height_px * 0.22), Vector2(-6, height_px * 0.22)
	])
	visual.add_child(roof)

	# Support posts
	for i in range(4):
		var post = Polygon2D.new()
		post.color = Color(0.45, 0.4, 0.35)
		var x = width_px * (0.08 + i * 0.3)
		post.polygon = PackedVector2Array([
			Vector2(x - 4, height_px * 0.22), Vector2(x + 4, height_px * 0.22),
			Vector2(x + 4, height_px), Vector2(x - 4, height_px)
		])
		visual.add_child(post)

	# Golf carts (simplified)
	for i in range(2):
		var x = width_px * (0.25 + i * 0.45)
		# Cart body
		var cart_body = Polygon2D.new()
		cart_body.color = Color(0.95, 0.95, 0.9)
		cart_body.polygon = PackedVector2Array([
			Vector2(x - 20, height_px * 0.45), Vector2(x + 20, height_px * 0.45),
			Vector2(x + 22, height_px * 0.85), Vector2(x - 22, height_px * 0.85)
		])
		visual.add_child(cart_body)
		# Cart roof
		var cart_roof = Polygon2D.new()
		cart_roof.color = Color(0.3, 0.5, 0.35)
		cart_roof.polygon = PackedVector2Array([
			Vector2(x - 18, height_px * 0.35), Vector2(x + 18, height_px * 0.35),
			Vector2(x + 20, height_px * 0.48), Vector2(x - 20, height_px * 0.48)
		])
		visual.add_child(cart_roof)
		# Wheels
		for wx in [x - 14, x + 14]:
			var wheel = Polygon2D.new()
			wheel.color = Color(0.2, 0.2, 0.2)
			wheel.polygon = PackedVector2Array([
				Vector2(wx - 5, height_px * 0.82), Vector2(wx + 5, height_px * 0.82),
				Vector2(wx + 5, height_px * 0.92), Vector2(wx - 5, height_px * 0.92)
			])
			visual.add_child(wheel)

func _draw_restroom(visual: Node2D, width_px: int, height_px: int) -> void:
	"""Draw restroom - small utility building"""
	# Shadow
	var shadow = Polygon2D.new()
	shadow.name = "DropShadow"
	shadow.color = _get_shadow_color()
	shadow.polygon = PackedVector2Array([
		Vector2(2, height_px * 0.5), Vector2(width_px + 4, height_px * 0.5),
		Vector2(width_px + 5, height_px + 2), Vector2(3, height_px + 2)
	])
	shadow.z_index = -1
	visual.add_child(shadow)
	_custom_shadow = shadow

	# Main building - clean light color
	var building = Polygon2D.new()
	building.color = Color(0.88, 0.88, 0.85)
	building.polygon = PackedVector2Array([
		Vector2(0, height_px * 0.2), Vector2(width_px, height_px * 0.2),
		Vector2(width_px, height_px), Vector2(0, height_px)
	])
	visual.add_child(building)

	# Roof
	var roof = Polygon2D.new()
	roof.color = Color(0.45, 0.42, 0.38)
	roof.polygon = PackedVector2Array([
		Vector2(-2, height_px * 0.15), Vector2(width_px + 2, height_px * 0.15),
		Vector2(width_px + 3, height_px * 0.25), Vector2(-3, height_px * 0.25)
	])
	visual.add_child(roof)

	# Two doors (mens/womens)
	for i in range(2):
		var x = width_px * (0.2 + i * 0.45)
		var door_frame = Polygon2D.new()
		door_frame.color = Color(0.35, 0.3, 0.25)
		door_frame.polygon = PackedVector2Array([
			Vector2(x - 12, height_px * 0.35), Vector2(x + 12, height_px * 0.35),
			Vector2(x + 12, height_px), Vector2(x - 12, height_px)
		])
		visual.add_child(door_frame)

		var door_inner = Polygon2D.new()
		door_inner.color = Color(0.5, 0.45, 0.4)
		door_inner.polygon = PackedVector2Array([
			Vector2(x - 10, height_px * 0.38), Vector2(x + 10, height_px * 0.38),
			Vector2(x + 10, height_px - 2), Vector2(x - 10, height_px - 2)
		])
		visual.add_child(door_inner)

	# Gender signs (simplified rectangles)
	var sign1 = Polygon2D.new()
	sign1.color = Color(0.3, 0.5, 0.7)  # Blue
	sign1.polygon = PackedVector2Array([
		Vector2(width_px * 0.15, height_px * 0.45), Vector2(width_px * 0.25, height_px * 0.45),
		Vector2(width_px * 0.25, height_px * 0.58), Vector2(width_px * 0.15, height_px * 0.58)
	])
	visual.add_child(sign1)

	var sign2 = Polygon2D.new()
	sign2.color = Color(0.7, 0.4, 0.5)  # Pink
	sign2.polygon = PackedVector2Array([
		Vector2(width_px * 0.6, height_px * 0.45), Vector2(width_px * 0.7, height_px * 0.45),
		Vector2(width_px * 0.7, height_px * 0.58), Vector2(width_px * 0.6, height_px * 0.58)
	])
	visual.add_child(sign2)

func _draw_bench(visual: Node2D, width_px: int, height_px: int) -> void:
	"""Draw bench - park-style seating with backrest"""
	# Shadow
	var shadow = Polygon2D.new()
	shadow.name = "DropShadow"
	shadow.color = _get_shadow_color()
	shadow.polygon = PackedVector2Array([
		Vector2(width_px * 0.12, height_px * 0.75), Vector2(width_px * 0.88, height_px * 0.75),
		Vector2(width_px * 0.9, height_px + 2), Vector2(width_px * 0.1, height_px + 2)
	])
	shadow.z_index = -1
	visual.add_child(shadow)
	_custom_shadow = shadow

	# Metal frame/legs (wrought iron style)
	var frame_color = Color(0.25, 0.25, 0.28)
	for x_pos in [width_px * 0.18, width_px * 0.82]:
		# Vertical support
		var leg = Polygon2D.new()
		leg.color = frame_color
		leg.polygon = PackedVector2Array([
			Vector2(x_pos - 4, height_px * 0.25), Vector2(x_pos + 4, height_px * 0.25),
			Vector2(x_pos + 4, height_px * 0.95), Vector2(x_pos - 4, height_px * 0.95)
		])
		visual.add_child(leg)
		# Decorative curved armrest
		var arm = Polygon2D.new()
		arm.color = frame_color
		arm.polygon = PackedVector2Array([
			Vector2(x_pos - 6, height_px * 0.35), Vector2(x_pos + 6, height_px * 0.35),
			Vector2(x_pos + 8, height_px * 0.42), Vector2(x_pos - 8, height_px * 0.42)
		])
		visual.add_child(arm)

	# Wooden backrest slats
	var wood_color = Color(0.55, 0.38, 0.22)
	var wood_highlight = Color(0.65, 0.48, 0.3)
	for i in range(3):
		var y = height_px * (0.28 + i * 0.08)
		var slat = Polygon2D.new()
		slat.color = wood_color if i % 2 == 0 else wood_highlight
		slat.polygon = PackedVector2Array([
			Vector2(width_px * 0.15, y), Vector2(width_px * 0.85, y),
			Vector2(width_px * 0.85, y + 5), Vector2(width_px * 0.15, y + 5)
		])
		visual.add_child(slat)

	# Wooden seat slats
	for i in range(3):
		var y = height_px * (0.52 + i * 0.1)
		var slat = Polygon2D.new()
		slat.color = wood_color if i % 2 == 0 else wood_highlight
		slat.polygon = PackedVector2Array([
			Vector2(width_px * 0.12, y), Vector2(width_px * 0.88, y),
			Vector2(width_px * 0.88, y + 6), Vector2(width_px * 0.12, y + 6)
		])
		visual.add_child(slat)

func _draw_generic(visual: Node2D, width_px: int, height_px: int) -> void:
	"""Draw generic building - simple but presentable"""
	# Shadow
	var shadow = Polygon2D.new()
	shadow.name = "DropShadow"
	shadow.color = _get_shadow_color()
	shadow.polygon = PackedVector2Array([
		Vector2(3, height_px * 0.5), Vector2(width_px + 4, height_px * 0.5),
		Vector2(width_px + 5, height_px + 2), Vector2(4, height_px + 2)
	])
	shadow.z_index = -1
	visual.add_child(shadow)
	_custom_shadow = shadow

	# Main structure
	var building = Polygon2D.new()
	building.color = Color(0.72, 0.7, 0.68)
	building.polygon = PackedVector2Array([
		Vector2(0, height_px * 0.2), Vector2(width_px, height_px * 0.2),
		Vector2(width_px, height_px), Vector2(0, height_px)
	])
	visual.add_child(building)

	# Roof
	var roof = Polygon2D.new()
	roof.color = Color(0.5, 0.45, 0.4)
	roof.polygon = PackedVector2Array([
		Vector2(-2, height_px * 0.15), Vector2(width_px + 2, height_px * 0.15),
		Vector2(width_px + 3, height_px * 0.25), Vector2(-3, height_px * 0.25)
	])
	visual.add_child(roof)

	# Simple window
	var window = Polygon2D.new()
	window.color = Color(0.7, 0.82, 0.9)
	window.polygon = PackedVector2Array([
		Vector2(width_px * 0.3, height_px * 0.35), Vector2(width_px * 0.7, height_px * 0.35),
		Vector2(width_px * 0.7, height_px * 0.6), Vector2(width_px * 0.3, height_px * 0.6)
	])
	visual.add_child(window)

	# Door
	var door = Polygon2D.new()
	door.color = Color(0.45, 0.35, 0.28)
	door.polygon = PackedVector2Array([
		Vector2(width_px * 0.4, height_px * 0.65), Vector2(width_px * 0.6, height_px * 0.65),
		Vector2(width_px * 0.6, height_px), Vector2(width_px * 0.4, height_px)
	])
	visual.add_child(door)

func get_building_info() -> Dictionary:
	return {
		"type": building_type,
		"position": grid_position,
		"width": width,
		"height": height,
		"cost": building_data.get("cost", 0),
		"upgrade_level": upgrade_level,
		"data": building_data
	}

## Restore building from saved data
func restore_from_info(info: Dictionary) -> void:
	var new_level = info.get("upgrade_level", 1)
	if new_level != upgrade_level:
		upgrade_level = new_level
		# Refresh visuals to match upgraded state
		for child in get_children():
			if child.name == "Visual" or child.name == "ClickArea":
				child.queue_free()
		# Use call_deferred to ensure old nodes are freed first
		call_deferred("_update_visuals")

func _on_sun_direction_changed(_new_direction: float) -> void:
	"""Update shadow colors when sun direction changes"""
	var shadow_system: Node = null
	if has_node("/root/ShadowSystem"):
		shadow_system = get_node("/root/ShadowSystem")
	if not shadow_system:
		return

	# Update contact shadow color
	if _shadow_refs.has("contact") and is_instance_valid(_shadow_refs["contact"]):
		_shadow_refs["contact"].color = shadow_system.get_contact_shadow_color()

	# Update custom building shadow color
	if _custom_shadow and is_instance_valid(_custom_shadow):
		_custom_shadow.color = shadow_system.get_shadow_color()

## Get shadow color from ShadowSystem or use default
func _get_shadow_color() -> Color:
	if has_node("/root/ShadowSystem"):
		var shadow_system = get_node("/root/ShadowSystem")
		return shadow_system.get_shadow_color()
	return Color(0, 0, 0, 0.25)

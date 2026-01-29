extends Node2D
class_name Rock
## Rock - Represents a decorative rock entity on the course

var grid_position: Vector2i = Vector2i(0, 0)
var rock_size: String = "medium"  # small, medium, large

var terrain_grid: TerrainGrid
var rock_data: Dictionary = {}

signal rock_selected(rock: Rock)
signal rock_destroyed(rock: Rock)

const ROCK_PROPERTIES: Dictionary = {
	"small": {"name": "Small Rock", "cost": 10, "width": 0.5, "height": 0.5, "color": Color(0.6, 0.6, 0.6)},
	"medium": {"name": "Medium Rock", "cost": 15, "width": 1.0, "height": 0.8, "color": Color(0.5, 0.5, 0.5)},
	"large": {"name": "Large Rock", "cost": 20, "width": 1.5, "height": 1.2, "color": Color(0.55, 0.55, 0.55)},
}

func _ready() -> void:
	add_to_group("rocks")

	# Load rock data (only if not already set by set_rock_size)
	if rock_data.is_empty():
		if rock_size in ROCK_PROPERTIES:
			rock_data = ROCK_PROPERTIES[rock_size].duplicate(true)
		else:
			rock_size = "medium"
			rock_data = ROCK_PROPERTIES["medium"].duplicate(true)
		_update_visuals()

func set_rock_size(size: String) -> void:
	"""Set the rock size and load its data"""
	rock_size = size
	if rock_size in ROCK_PROPERTIES:
		rock_data = ROCK_PROPERTIES[rock_size].duplicate(true)
	else:
		rock_size = "medium"
		rock_data = ROCK_PROPERTIES["medium"].duplicate(true)

	# Update visuals if already in tree (after _ready was called)
	if is_inside_tree():
		_update_visuals()

func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		rock_selected.emit(self)

func set_terrain_grid(grid: TerrainGrid) -> void:
	terrain_grid = grid

func set_position_in_grid(pos: Vector2i) -> void:
	grid_position = pos
	# Calculate world position from grid position
	if terrain_grid:
		var world_pos = terrain_grid.grid_to_screen(pos)
		global_position = world_pos

func destroy() -> void:
	rock_destroyed.emit(self)
	queue_free()

func _update_visuals() -> void:
	"""Create visual representation for the rock"""
	# Remove existing visual if it exists
	if has_node("Visual"):
		get_node("Visual").queue_free()

	# Create a Node2D to hold the visual
	var visual = Node2D.new()
	visual.name = "Visual"
	add_child(visual)

	var color = rock_data.get("color", Color.GRAY)
	var width = rock_data.get("width", 1.0)
	var height = rock_data.get("height", 0.8)

	# Draw rock shape based on size
	match rock_size:
		"small":
			_draw_small_rock(visual, color)
		"medium":
			_draw_medium_rock(visual, color)
		"large":
			_draw_large_rock(visual, color)
		_:
			_draw_medium_rock(visual, color)

func _draw_small_rock(visual: Node2D, color: Color) -> void:
	"""Draw a small rock"""
	var rock = Polygon2D.new()
	rock.color = color
	rock.polygon = PackedVector2Array([
		Vector2(-8, 5),
		Vector2(0, -5),
		Vector2(8, 5),
		Vector2(4, 10),
		Vector2(-4, 10)
	])
	visual.add_child(rock)

	# Add highlight
	var highlight = Polygon2D.new()
	highlight.color = Color(color.r * 1.3, color.g * 1.3, color.b * 1.3)
	highlight.polygon = PackedVector2Array([
		Vector2(-4, 2),
		Vector2(0, -3),
		Vector2(4, 2)
	])
	visual.add_child(highlight)

func _draw_medium_rock(visual: Node2D, color: Color) -> void:
	"""Draw a medium rock"""
	var rock = Polygon2D.new()
	rock.color = color
	rock.polygon = PackedVector2Array([
		Vector2(-15, 8),
		Vector2(-10, -8),
		Vector2(0, -10),
		Vector2(12, -5),
		Vector2(15, 8),
		Vector2(8, 15),
		Vector2(-8, 15)
	])
	visual.add_child(rock)

	# Add highlight
	var highlight = Polygon2D.new()
	highlight.color = Color(color.r * 1.3, color.g * 1.3, color.b * 1.3)
	highlight.polygon = PackedVector2Array([
		Vector2(-8, 4),
		Vector2(-4, -6),
		Vector2(4, -6),
		Vector2(8, 4)
	])
	visual.add_child(highlight)

func _draw_large_rock(visual: Node2D, color: Color) -> void:
	"""Draw a large rock"""
	var rock = Polygon2D.new()
	rock.color = color
	rock.polygon = PackedVector2Array([
		Vector2(-20, 10),
		Vector2(-15, -10),
		Vector2(0, -15),
		Vector2(18, -8),
		Vector2(22, 10),
		Vector2(12, 20),
		Vector2(-12, 20)
	])
	visual.add_child(rock)

	# Add highlight
	var highlight = Polygon2D.new()
	highlight.color = Color(color.r * 1.3, color.g * 1.3, color.b * 1.3)
	highlight.polygon = PackedVector2Array([
		Vector2(-10, 5),
		Vector2(-6, -8),
		Vector2(6, -8),
		Vector2(10, 5)
	])
	visual.add_child(highlight)

	# Add shadow
	var shadow = Polygon2D.new()
	shadow.color = Color(0, 0, 0, 0.3)
	shadow.polygon = PackedVector2Array([
		Vector2(-8, 12),
		Vector2(8, 12),
		Vector2(10, 18),
		Vector2(-10, 18)
	])
	visual.add_child(shadow)

func get_rock_info() -> Dictionary:
	return {
		"size": rock_size,
		"position": grid_position,
		"cost": rock_data.get("cost", 15),
		"width": rock_data.get("width", 1.0),
		"height": rock_data.get("height", 0.8),
		"name": rock_data.get("name", "Rock")
	}

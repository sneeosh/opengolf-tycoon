extends Control
class_name MiniMap
## MiniMap - Shows course overview with click-to-navigate

signal camera_move_requested(world_position: Vector2)

const MAP_SIZE: int = 180  # Size of mini-map in pixels
const BORDER_WIDTH: int = 2

var _terrain_grid: TerrainGrid = null
var _entity_layer = null  # EntityLayer reference
var _golfer_manager = null  # GolferManager reference
var _camera_rect: Rect2 = Rect2()  # Current camera viewport in grid coords
var _map_texture: ImageTexture = null
var _needs_redraw: bool = true
var _update_timer: float = 0.0
var _is_dragging: bool = false  # Track drag state for click-and-drag navigation
const UPDATE_INTERVAL: float = 0.5  # Redraw terrain every 0.5 seconds

# Color palette for terrain types
const TERRAIN_COLORS: Dictionary = {
	0: Color(0.2, 0.5, 0.2),      # GRASS - dark green
	1: Color(0.3, 0.6, 0.3),      # ROUGH - medium green
	2: Color(0.4, 0.8, 0.4),      # FAIRWAY - light green
	3: Color(0.3, 0.9, 0.3),      # GREEN - bright green
	4: Color(0.9, 0.85, 0.6),     # BUNKER - sand color
	5: Color(0.3, 0.5, 0.9),      # WATER - blue
	6: Color(0.7, 0.7, 0.7),      # PATH - gray
	7: Color(0.5, 0.8, 0.5),      # TEE_BOX - tee green
	8: Color(0.15, 0.15, 0.15),   # OUT_OF_BOUNDS - dark
}

func _ready() -> void:
	custom_minimum_size = Vector2(MAP_SIZE + BORDER_WIDTH * 2, MAP_SIZE + BORDER_WIDTH * 2)
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(terrain_grid: TerrainGrid, entity_layer, golfer_manager) -> void:
	_terrain_grid = terrain_grid
	_entity_layer = entity_layer
	_golfer_manager = golfer_manager
	_needs_redraw = true

	# Connect to terrain changes
	if terrain_grid:
		terrain_grid.tile_changed.connect(_on_terrain_changed)

func _on_terrain_changed(_pos: Vector2i, _old_type: int, _new_type: int) -> void:
	_needs_redraw = true

func set_camera_rect(viewport_rect: Rect2, grid_width: int, grid_height: int) -> void:
	# Convert screen rect to normalized coordinates (0-1)
	_camera_rect = Rect2(
		viewport_rect.position.x / (grid_width * _terrain_grid.tile_width),
		viewport_rect.position.y / (grid_height * _terrain_grid.tile_height),
		viewport_rect.size.x / (grid_width * _terrain_grid.tile_width),
		viewport_rect.size.y / (grid_height * _terrain_grid.tile_height)
	)
	queue_redraw()

func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		if _needs_redraw:
			_regenerate_map_texture()
			_needs_redraw = false
		queue_redraw()  # Redraw for golfer positions

func _regenerate_map_texture() -> void:
	if not _terrain_grid:
		return

	var grid_width = _terrain_grid.grid_width
	var grid_height = _terrain_grid.grid_height

	# Create image at appropriate resolution
	var img = Image.create(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RGBA8)

	# Sample terrain at reduced resolution
	for px in range(MAP_SIZE):
		for py in range(MAP_SIZE):
			# Map pixel to grid position
			var gx = int(float(px) / MAP_SIZE * grid_width)
			var gy = int(float(py) / MAP_SIZE * grid_height)
			var terrain_type = _terrain_grid.get_tile(Vector2i(gx, gy))

			var color = TERRAIN_COLORS.get(terrain_type, Color(0.3, 0.3, 0.3))
			img.set_pixel(px, py, color)

	_map_texture = ImageTexture.create_from_image(img)

func _draw() -> void:
	# Draw border
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.3, 0.3), true)

	# Draw map texture
	if _map_texture:
		draw_texture(_map_texture, Vector2(BORDER_WIDTH, BORDER_WIDTH))

	# Draw holes (tees and greens)
	_draw_holes()

	# Draw buildings
	_draw_buildings()

	# Draw active golfers
	_draw_golfers()

	# Draw camera viewport rectangle
	_draw_camera_rect()

func _draw_holes() -> void:
	if not GameManager.current_course:
		return

	for hole in GameManager.current_course.holes:
		# Tee position - small circle
		var tee_px = _grid_to_map_pos(hole.tee_position)
		draw_circle(tee_px, 3, Color(1.0, 1.0, 0.5))  # Yellow

		# Green position - small square
		var green_px = _grid_to_map_pos(hole.green_position)
		draw_rect(Rect2(green_px - Vector2(2, 2), Vector2(4, 4)), Color(0.2, 1.0, 0.2))  # Bright green

func _draw_buildings() -> void:
	if not _entity_layer:
		return

	var buildings = _entity_layer.get_all_buildings()
	for building in buildings:
		var pos = _grid_to_map_pos(building.grid_position)
		var w = max(2, building.width * MAP_SIZE / _terrain_grid.grid_width)
		var h = max(2, building.height * MAP_SIZE / _terrain_grid.grid_height)
		draw_rect(Rect2(pos, Vector2(w, h)), Color(0.6, 0.4, 0.2))  # Brown

func _draw_golfers() -> void:
	if not _golfer_manager:
		return

	var golfers = _golfer_manager.get_active_golfers()
	for golfer in golfers:
		if golfer and is_instance_valid(golfer):
			var grid_pos = _terrain_grid.screen_to_grid(golfer.global_position)
			var map_pos = _grid_to_map_pos(grid_pos)
			draw_circle(map_pos, 2, Color(1.0, 0.3, 0.3))  # Red dots

func _draw_camera_rect() -> void:
	if _camera_rect.size.x <= 0 or _camera_rect.size.y <= 0:
		return

	# Convert normalized camera rect to map pixels
	var rect_pos = Vector2(
		BORDER_WIDTH + _camera_rect.position.x * MAP_SIZE,
		BORDER_WIDTH + _camera_rect.position.y * MAP_SIZE
	)
	var rect_size = Vector2(
		_camera_rect.size.x * MAP_SIZE,
		_camera_rect.size.y * MAP_SIZE
	)

	# Clamp to map bounds
	rect_pos.x = clamp(rect_pos.x, BORDER_WIDTH, BORDER_WIDTH + MAP_SIZE)
	rect_pos.y = clamp(rect_pos.y, BORDER_WIDTH, BORDER_WIDTH + MAP_SIZE)

	# Draw viewport rectangle outline
	var rect = Rect2(rect_pos, rect_size)
	draw_rect(rect, Color(1, 1, 1, 0.8), false, 2.0)

func _grid_to_map_pos(grid_pos: Vector2i) -> Vector2:
	if not _terrain_grid:
		return Vector2.ZERO
	var nx = float(grid_pos.x) / _terrain_grid.grid_width
	var ny = float(grid_pos.y) / _terrain_grid.grid_height
	return Vector2(BORDER_WIDTH + nx * MAP_SIZE, BORDER_WIDTH + ny * MAP_SIZE)

func _map_to_world_pos(map_pos: Vector2) -> Vector2:
	if not _terrain_grid:
		return Vector2.ZERO
	# Convert map pixel position to world position
	var nx = (map_pos.x - BORDER_WIDTH) / MAP_SIZE
	var ny = (map_pos.y - BORDER_WIDTH) / MAP_SIZE
	var gx = nx * _terrain_grid.grid_width
	var gy = ny * _terrain_grid.grid_height
	return _terrain_grid.grid_to_screen_center(Vector2i(int(gx), int(gy)))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var local_pos = event.position
				# Check if click is within map area
				if _is_within_map(local_pos):
					_is_dragging = true
					var world_pos = _map_to_world_pos(local_pos)
					camera_move_requested.emit(world_pos)
					accept_event()
			else:
				# Mouse button released
				_is_dragging = false

	elif event is InputEventMouseMotion and _is_dragging:
		var local_pos = event.position
		# Continue moving camera while dragging within map area
		if _is_within_map(local_pos):
			var world_pos = _map_to_world_pos(local_pos)
			camera_move_requested.emit(world_pos)
			accept_event()

func _is_within_map(local_pos: Vector2) -> bool:
	return local_pos.x >= BORDER_WIDTH and local_pos.x < BORDER_WIDTH + MAP_SIZE \
		and local_pos.y >= BORDER_WIDTH and local_pos.y < BORDER_WIDTH + MAP_SIZE

func _input(event: InputEvent) -> void:
	# Toggle visibility with M key
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M and not event.is_command_or_control_pressed():
			visible = not visible
			get_viewport().set_input_as_handled()

func force_redraw() -> void:
	_needs_redraw = true

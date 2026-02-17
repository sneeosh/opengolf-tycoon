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

# Fallback color palette (used if theme is unavailable)
const FALLBACK_TERRAIN_COLORS: Dictionary = {
	0: Color(0.18, 0.22, 0.18),   # EMPTY
	1: Color(0.2, 0.5, 0.2),      # GRASS
	2: Color(0.4, 0.8, 0.4),      # FAIRWAY
	3: Color(0.3, 0.6, 0.3),      # ROUGH
	4: Color(0.25, 0.45, 0.22),   # HEAVY_ROUGH
	5: Color(0.3, 0.9, 0.3),      # GREEN
	6: Color(0.5, 0.8, 0.5),      # TEE_BOX
	7: Color(0.9, 0.85, 0.6),     # BUNKER
	8: Color(0.3, 0.5, 0.9),      # WATER
	9: Color(0.7, 0.7, 0.7),      # PATH
	10: Color(0.15, 0.15, 0.15),  # OUT_OF_BOUNDS
	11: Color(0.15, 0.35, 0.15),  # TREES
	12: Color(0.45, 0.32, 0.22),  # FLOWER_BED
	13: Color(0.48, 0.46, 0.42),  # ROCKS
}

# Cached theme-aware terrain colors (rebuilt on theme change)
var _terrain_colors: Dictionary = {}

func _build_terrain_colors() -> void:
	"""Build mini-map colors from current course theme"""
	var theme_colors = CourseTheme.get_terrain_colors(GameManager.current_theme)
	if theme_colors.is_empty():
		_terrain_colors = FALLBACK_TERRAIN_COLORS.duplicate()
		return

	_terrain_colors = {
		TerrainTypes.Type.EMPTY: theme_colors.get("empty", Color(0.18, 0.22, 0.18)),
		TerrainTypes.Type.GRASS: theme_colors.get("grass", Color(0.2, 0.5, 0.2)),
		TerrainTypes.Type.FAIRWAY: theme_colors.get("fairway_light", Color(0.4, 0.8, 0.4)),
		TerrainTypes.Type.ROUGH: theme_colors.get("rough", Color(0.3, 0.6, 0.3)),
		TerrainTypes.Type.HEAVY_ROUGH: theme_colors.get("heavy_rough", Color(0.25, 0.45, 0.22)),
		TerrainTypes.Type.GREEN: theme_colors.get("green_light", Color(0.3, 0.9, 0.3)),
		TerrainTypes.Type.TEE_BOX: theme_colors.get("tee_box_light", Color(0.5, 0.8, 0.5)),
		TerrainTypes.Type.BUNKER: theme_colors.get("bunker", Color(0.9, 0.85, 0.6)),
		TerrainTypes.Type.WATER: theme_colors.get("water", Color(0.3, 0.5, 0.9)),
		TerrainTypes.Type.PATH: theme_colors.get("path", Color(0.7, 0.7, 0.7)),
		TerrainTypes.Type.OUT_OF_BOUNDS: theme_colors.get("oob", Color(0.15, 0.15, 0.15)),
		TerrainTypes.Type.TREES: theme_colors.get("trees", Color(0.15, 0.35, 0.15)),
		TerrainTypes.Type.FLOWER_BED: theme_colors.get("flower_bed", Color(0.45, 0.32, 0.22)),
		TerrainTypes.Type.ROCKS: theme_colors.get("rocks", Color(0.48, 0.46, 0.42)),
	}

# Land boundary colors
const BOUNDARY_COLOR = Color(0.9, 0.6, 0.2, 1.0)  # Orange/gold property line
const UNOWNED_TINT = Color(0.3, 0.2, 0.2, 0.4)    # Subtle dark tint on unowned

func _ready() -> void:
	custom_minimum_size = Vector2(MAP_SIZE + BORDER_WIDTH * 2, MAP_SIZE + BORDER_WIDTH * 2)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_terrain_colors()
	# Listen for theme changes to update colors
	if EventBus.has_signal("theme_changed"):
		EventBus.theme_changed.connect(_on_theme_changed)

func _on_theme_changed(_theme_type) -> void:
	_build_terrain_colors()
	_needs_redraw = true

func setup(terrain_grid: TerrainGrid, entity_layer, golfer_manager) -> void:
	_terrain_grid = terrain_grid
	_entity_layer = entity_layer
	_golfer_manager = golfer_manager
	_needs_redraw = true

	# Connect to terrain changes
	if terrain_grid:
		terrain_grid.tile_changed.connect(_on_terrain_changed)

	# Connect to land manager for property line updates
	call_deferred("_connect_land_signals")

func _on_terrain_changed(_pos: Vector2i, _old_type: int, _new_type: int) -> void:
	_needs_redraw = true

func _connect_land_signals() -> void:
	# Connect to land manager signals (deferred to ensure manager exists)
	if GameManager.land_manager:
		if not GameManager.land_manager.land_purchased.is_connected(_on_land_purchased):
			GameManager.land_manager.land_purchased.connect(_on_land_purchased)
		if not GameManager.land_manager.land_boundary_changed.is_connected(_on_land_boundary_changed):
			GameManager.land_manager.land_boundary_changed.connect(_on_land_boundary_changed)

func _on_land_purchased(_parcel: Vector2i) -> void:
	_needs_redraw = true
	queue_redraw()

func _on_land_boundary_changed() -> void:
	_needs_redraw = true
	queue_redraw()

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

			var color = _terrain_colors.get(terrain_type, Color(0.3, 0.3, 0.3))
			img.set_pixel(px, py, color)

	_map_texture = ImageTexture.create_from_image(img)

func _draw() -> void:
	# Draw border
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.3, 0.3), true)

	# Draw map texture
	if _map_texture:
		draw_texture(_map_texture, Vector2(BORDER_WIDTH, BORDER_WIDTH))

	# Draw land boundary (property lines)
	_draw_land_boundary()

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

func _draw_land_boundary() -> void:
	if not GameManager.land_manager or not _terrain_grid:
		return

	var lm = GameManager.land_manager
	var parcel_size = lm.PARCEL_SIZE  # 20 tiles per parcel
	var cols = lm.PARCEL_GRID_COLS    # 6 columns
	var rows = lm.PARCEL_GRID_ROWS    # 6 rows
	var offset = lm.GRID_OFFSET       # 4 tiles margin

	# Draw tint on unowned parcels
	for px in range(cols):
		for py in range(rows):
			var parcel_pos = Vector2i(px, py)
			if not lm.owned_parcels.has(parcel_pos):
				# Calculate parcel bounds in map pixels (account for grid offset)
				var grid_start = Vector2i(offset + px * parcel_size, offset + py * parcel_size)
				var grid_end = Vector2i(offset + (px + 1) * parcel_size, offset + (py + 1) * parcel_size)
				var map_start = _grid_to_map_pos(grid_start)
				var map_end = _grid_to_map_pos(grid_end)
				var rect = Rect2(map_start, map_end - map_start)
				draw_rect(rect, UNOWNED_TINT)

	# Draw property lines at parcel boundaries
	for px in range(cols):
		for py in range(rows):
			var parcel_pos = Vector2i(px, py)
			var is_owned = lm.owned_parcels.has(parcel_pos)
			if not is_owned:
				continue  # Only draw borders from owned side

			var grid_x = offset + px * parcel_size
			var grid_y = offset + py * parcel_size

			# Check right neighbor
			if px < cols - 1:
				var right = Vector2i(px + 1, py)
				if not lm.owned_parcels.has(right):
					var start = _grid_to_map_pos(Vector2i(grid_x + parcel_size, grid_y))
					var end = _grid_to_map_pos(Vector2i(grid_x + parcel_size, grid_y + parcel_size))
					draw_line(start, end, BOUNDARY_COLOR, 1.5)

			# Check bottom neighbor
			if py < rows - 1:
				var bottom = Vector2i(px, py + 1)
				if not lm.owned_parcels.has(bottom):
					var start = _grid_to_map_pos(Vector2i(grid_x, grid_y + parcel_size))
					var end = _grid_to_map_pos(Vector2i(grid_x + parcel_size, grid_y + parcel_size))
					draw_line(start, end, BOUNDARY_COLOR, 1.5)

			# Check left neighbor
			if px > 0:
				var left = Vector2i(px - 1, py)
				if not lm.owned_parcels.has(left):
					var start = _grid_to_map_pos(Vector2i(grid_x, grid_y))
					var end = _grid_to_map_pos(Vector2i(grid_x, grid_y + parcel_size))
					draw_line(start, end, BOUNDARY_COLOR, 1.5)

			# Check top neighbor
			if py > 0:
				var top = Vector2i(px, py - 1)
				if not lm.owned_parcels.has(top):
					var start = _grid_to_map_pos(Vector2i(grid_x, grid_y))
					var end = _grid_to_map_pos(Vector2i(grid_x + parcel_size, grid_y))
					draw_line(start, end, BOUNDARY_COLOR, 1.5)

			# Draw border at map edges for owned edge parcels
			if px == 0:
				var start = _grid_to_map_pos(Vector2i(grid_x, grid_y))
				var end = _grid_to_map_pos(Vector2i(grid_x, grid_y + parcel_size))
				draw_line(start, end, BOUNDARY_COLOR, 1.5)
			if py == 0:
				var start = _grid_to_map_pos(Vector2i(grid_x, grid_y))
				var end = _grid_to_map_pos(Vector2i(grid_x + parcel_size, grid_y))
				draw_line(start, end, BOUNDARY_COLOR, 1.5)
			if px == cols - 1:
				var start = _grid_to_map_pos(Vector2i(grid_x + parcel_size, grid_y))
				var end = _grid_to_map_pos(Vector2i(grid_x + parcel_size, grid_y + parcel_size))
				draw_line(start, end, BOUNDARY_COLOR, 1.5)
			if py == rows - 1:
				var start = _grid_to_map_pos(Vector2i(grid_x, grid_y + parcel_size))
				var end = _grid_to_map_pos(Vector2i(grid_x + parcel_size, grid_y + parcel_size))
				draw_line(start, end, BOUNDARY_COLOR, 1.5)

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
	# Don't process any gameplay hotkeys while in main menu
	if GameManager.current_mode == GameManager.GameMode.MAIN_MENU:
		return

	# Toggle visibility with Tab key
	if event is InputEventKey and event.pressed and not event.echo:
		# Don't process hotkeys if a text input has focus
		var focused = get_viewport().gui_get_focus_owner()
		if focused is LineEdit or focused is TextEdit:
			return
		if event.keycode == KEY_TAB and not event.is_command_or_control_pressed():
			visible = not visible
			get_viewport().set_input_as_handled()

func force_redraw() -> void:
	_needs_redraw = true

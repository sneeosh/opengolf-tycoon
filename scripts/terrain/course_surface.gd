extends ColorRect
class_name CourseSurface
## Continuous, world-anchored terrain. One RGBA texel per simulation tile:
## R = terrain ID / 255, G = bunker depth, B = (base elevation + 5) / 10, A reserved. No save format changes.

const PALETTE_KEYS: Array[String] = [
	"empty", "grass", "fairway_light", "rough", "heavy_rough", "green_light",
	"tee_box_light", "bunker", "water", "path", "oob", "grass", "flower_bed", "grass",
]
var _grid: TerrainGrid
var _data: Image
var _texture: ImageTexture
var _palette: ImageTexture
var _dirty := false

func initialize(grid: TerrainGrid) -> void:
	_grid = grid
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(grid.grid_width * grid.tile_width, grid.grid_height * grid.tile_height)
	_data = Image.create(grid.grid_width, grid.grid_height, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_data)
	var surface_material := ShaderMaterial.new()
	surface_material.shader = preload("res://shaders/course_surface.gdshader")
	surface_material.set_shader_parameter("terrain_data", _texture)
	surface_material.set_shader_parameter("elevation_data", _texture)
	surface_material.set_shader_parameter("grid_size", Vector2(grid.grid_width, grid.grid_height))
	surface_material.set_shader_parameter("tile_size", Vector2(grid.tile_width, grid.tile_height))
	material = surface_material
	refresh_palette()
	rebuild()
	grid.tile_changed.connect(_on_tile_changed)
	grid.elevation_changed.connect(_on_elevation_changed)
	EventBus.theme_changed.connect(_on_theme_changed)
	EventBus.load_completed.connect(_on_load_completed)

func refresh_palette() -> void:
	var colors := Image.create(PALETTE_KEYS.size(), 1, false, Image.FORMAT_RGBA8)
	for i in range(PALETTE_KEYS.size()):
		colors.set_pixel(i, 0, TilesetGenerator.get_color(PALETTE_KEYS[i]))
	_palette = ImageTexture.create_from_image(colors)
	material.set_shader_parameter("palette", _palette)
	material.set_shader_parameter("fringe_color", TilesetGenerator.get_color("fringe"))

func rebuild() -> void:
	for x in range(_grid.grid_width):
		for y in range(_grid.grid_height):
			_write_tile(Vector2i(x, y))
	_dirty = true

func _write_tile(pos: Vector2i) -> void:
	_data.set_pixel(pos.x, pos.y, Color(float(_grid.get_tile(pos)) / 255.0,
		float(_grid.get_bunker_depth(pos)), float(_grid.get_elevation(pos) + 5) / 10.0, 1.0))

func _on_tile_changed(pos: Vector2i, _old: int, _new: int) -> void:
	update_tile(pos)

func _on_elevation_changed(pos: Vector2i, _old: int, _new: int) -> void:
	update_tile(pos)

func update_tile(pos: Vector2i) -> void:
	_write_tile(pos)
	_dirty = true

func _on_theme_changed(_theme: int) -> void:
	refresh_palette()

func _on_load_completed(success: bool) -> void:
	if success:
		rebuild()
		refresh_palette()

func _process(_delta: float) -> void:
	# Painting/batch generation uploads at most once per frame, never per tile.
	if _dirty:
		_texture.update(_data)
		_dirty = false

func _exit_tree() -> void:
	if EventBus.theme_changed.is_connected(_on_theme_changed):
		EventBus.theme_changed.disconnect(_on_theme_changed)
	if EventBus.load_completed.is_connected(_on_load_completed):
		EventBus.load_completed.disconnect(_on_load_completed)

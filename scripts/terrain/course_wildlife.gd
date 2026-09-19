extends Node2D
class_name CourseWildlife
## Small, purely visual residents. No collision, maintenance, RNG, or save data.
## Cached habitats rebuild after edits; the draw loop visits only bounded residents.

const MAX_DUCK_FAMILIES := 12
const MAX_GARDENS := 24
const NEIGHBORS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const BUTTERFLY_COLORS := [Color("ffcb67"), Color("eaa9cf"), Color("aad8ee")]
var terrain_grid: TerrainGrid
var _water_tiles: Dictionary = {}
var _flower_tiles: Dictionary = {}
var _duck_homes: Array[Vector2i] = []
var _garden_homes: Array[Vector2i] = []
var _time := 0.0
var _refresh_elapsed := 0.0
var _draw_elapsed := 0.0
var _habitats_dirty := false

func initialize(grid: TerrainGrid) -> void:
	terrain_grid = grid
	z_index = 1 # Water residents sit below the trees, golfers, and UI.
	grid.tile_changed.connect(_on_tile_changed)
	EventBus.load_completed.connect(_on_load_completed)
	EventBus.decoration_placed.connect(_on_decoration_placed)
	EventBus.decoration_removed.connect(_on_decoration_removed)
	rebuild()

func _exit_tree() -> void:
	EventBus.load_completed.disconnect(_on_load_completed)
	EventBus.decoration_placed.disconnect(_on_decoration_placed)
	EventBus.decoration_removed.disconnect(_on_decoration_removed)

func _on_load_completed(success: bool) -> void:
	if success:
		rebuild()

func _on_decoration_placed(_type: String, _pos: Vector2i) -> void:
	_habitats_dirty = true

func _on_decoration_removed(_pos: Vector2i) -> void:
	_habitats_dirty = true

func _on_tile_changed(pos: Vector2i, _old: int, type: int) -> void:
	_track_tile(pos, type)
	_habitats_dirty = true

func _track_tile(pos: Vector2i, type: int) -> void:
	_water_tiles.erase(pos)
	_flower_tiles.erase(pos)
	if type == TerrainTypes.Type.WATER:
		_water_tiles[pos] = true
	elif type == TerrainTypes.Type.FLOWER_BED:
		_flower_tiles[pos] = true

func rebuild() -> void:
	_water_tiles.clear()
	_flower_tiles.clear()
	for x in range(terrain_grid.grid_width):
		for y in range(terrain_grid.grid_height):
			var pos := Vector2i(x, y)
			_track_tile(pos, terrain_grid.get_tile(pos))
	_refresh_residents()

func _refresh_residents() -> void:
	var ponds: Array[Vector2i] = []
	for pos in _water_tiles:
		var wet_neighbors := 0
		for offset in NEIGHBORS:
			if _water_tiles.has(pos + offset):
				wet_neighbors += 1
		# Skip isolated painted puddles and fragile one-tile-wide corners.
		if wet_neighbors >= 3:
			ponds.append(pos)
	_duck_homes = _spaced_homes(ponds, MAX_DUCK_FAMILIES, 5.0)
	var gardens: Array[Vector2i] = []
	for pos in _flower_tiles:
		gardens.append(pos)
	var entities = GameManager.entity_layer
	if is_instance_valid(entities):
		for decoration in entities.decorations.values():
			if decoration.decoration_type in ["flower_garden", "bird_bath"]:
				gardens.append(decoration.grid_position)
	_garden_homes = _spaced_homes(gardens, MAX_GARDENS, 2.0)
	_habitats_dirty = false
	_refresh_elapsed = 0.0
	queue_redraw()

func _spaced_homes(candidates: Array[Vector2i], limit: int, spacing: float) -> Array[Vector2i]:
	# Prefer the playable center; stable tie-breaking makes load/new-game repeatable.
	var center := Vector2(terrain_grid.grid_width, terrain_grid.grid_height) * 0.5
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := Vector2(a).distance_squared_to(center)
		var db := Vector2(b).distance_squared_to(center)
		return da < db if da != db else a.y * terrain_grid.grid_width + a.x < b.y * terrain_grid.grid_width + b.x)
	var homes: Array[Vector2i] = []
	for pos in candidates:
		var crowded := false
		for other in homes:
			if Vector2(pos).distance_to(Vector2(other)) < spacing:
				crowded = true
				break
		if not crowded:
			homes.append(pos)
			if homes.size() >= limit:
				break
	return homes

func _process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	_refresh_elapsed += real_delta
	if _habitats_dirty and _refresh_elapsed >= 0.25:
		_refresh_residents()
	if GameManager.is_paused or GameManager.current_speed == GameManager.GameSpeed.PAUSED:
		return
	_time += real_delta
	_draw_elapsed += real_delta
	if _draw_elapsed >= 1.0 / 15.0:
		_draw_elapsed = 0.0
		queue_redraw()

static func duck_offset(phase: float) -> Vector2:
	# Complete route fits inside the center of a 64x32 water tile, including bodies.
	return Vector2(cos(phase) * 17.0, sin(phase) * 5.5)

static func butterflies_active(hour: float, season: int, raining: bool) -> bool:
	return hour >= 7.0 and hour < 18.0 and season != SeasonSystem.Season.WINTER and not raining

static func fireflies_active(hour: float, season: int, raining: bool) -> bool:
	return hour >= 17.5 and hour <= 21.0 and season in [SeasonSystem.Season.SPRING, SeasonSystem.Season.SUMMER] and not raining

func _draw() -> void:
	if not terrain_grid:
		return
	var weather := GameManager.weather_system
	var raining := is_instance_valid(weather) and weather.is_raining()
	var storm := is_instance_valid(weather) and weather.weather_type == WeatherSystem.WeatherType.HEAVY_RAIN
	var season := SeasonSystem.get_season(GameManager.current_day)
	var view := terrain_grid.get_visible_world_rect().grow(60.0)
	if not storm:
		for home in _duck_homes:
			# Recheck the tile immediately, so painting land never leaves a stranded duck.
			if terrain_grid.get_tile(home) != TerrainTypes.Type.WATER:
				continue
			var center := terrain_grid.grid_to_screen_center(home)
			if view.has_point(center):
				_draw_family(center, _time * 0.32 + float(home.x * 3 + home.y) * 0.7)
	var butterflies := butterflies_active(GameManager.current_hour, season, raining)
	var fireflies := fireflies_active(GameManager.current_hour, season, raining)
	for home in _garden_homes:
		var center := terrain_grid.grid_to_screen_center(home)
		if not view.has_point(center):
			continue
		var phase := float(home.x * 13 + home.y * 7)
		if butterflies:
			_draw_butterfly(center, phase, BUTTERFLY_COLORS[posmod(home.x + home.y, BUTTERFLY_COLORS.size())])
		if fireflies:
			for i in range(3):
				_draw_firefly(center, phase + i * 2.7)

func _draw_family(center: Vector2, phase: float) -> void:
	# Two gold ducklings follow the adult around a lazy oval.
	for i in range(2, -1, -1):
		var t := phase - float(i) * 0.65
		var p := (center + duck_offset(t)).round()
		var facing := -1.0 if sin(t) > 0.0 else 1.0
		_draw_duck(p, facing, i > 0)

func _draw_duck(p: Vector2, facing: float, chick: bool) -> void:
	var scale_factor := 0.58 if chick else 1.0
	var wake := Color(0.77, 0.93, 0.84, 0.25)
	draw_arc(p + Vector2(-facing * 5.0, 2.0), 8.0 * scale_factor, 0.15, PI - 0.15, 10, wake, 1.0)
	draw_set_transform(p, 0.0, Vector2(facing * scale_factor, scale_factor))
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -1), Vector2(-5, -6), Vector2(2, -6), Vector2(7, -2), Vector2(5, 3), Vector2(-4, 3)]), Color("edca67") if chick else Color("f4efdc"))
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -2), Vector2(-12, -5), Vector2(-9, 1)]), Color("d3a44c") if chick else Color("c3c9b5"))
	draw_circle(Vector2(5, -7), 4.0, Color("ffe58c") if chick else Color("fdf8e9"))
	draw_line(Vector2(8, -6), Vector2(12, -6), Color("e4a443"), 3.0)
	draw_circle(Vector2(6, -8), 0.9, Color("293d32"))
	draw_line(Vector2(-5, -2), Vector2(0, 0), Color("c4a04c") if chick else Color("bcc8b8"), 2.0)
	draw_set_transform(Vector2.ZERO)

func _draw_butterfly(center: Vector2, phase: float, color: Color) -> void:
	var t := _time + phase
	var p := center + Vector2(sin(t * 0.65) * 22.0, cos(t * 0.9) * 8.0 - 13.0)
	var wing := 1.0 + absf(sin(t * 7.0)) * 4.0
	draw_circle(p + Vector2(-wing * 0.65, -1), wing * 0.6, color)
	draw_circle(p + Vector2(wing * 0.65, -1), wing * 0.6, color)
	draw_line(p + Vector2(0, -3), p + Vector2(0, 3), Color("58483e"), 1.0)

func _draw_firefly(center: Vector2, phase: float) -> void:
	var t := _time * 0.7 + phase
	var p := center + Vector2(sin(t) * 27.0, cos(t * 0.8) * 10.0 - 7.0)
	var glow := pow(maxf(0.0, sin(t * 1.6)), 3.0)
	draw_circle(p, 5.0, Color(0.81, 0.94, 0.38, glow * 0.08))
	draw_circle(p, 2.5, Color(0.87, 1.0, 0.49, glow * 0.25))
	draw_circle(p, 1.0, Color(1.0, 1.0, 0.71, glow))

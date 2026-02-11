extends Node
class_name TilesetGenerator
## Generates a textured tileset image for more visually appealing terrain

const TILE_WIDTH = 64
const TILE_HEIGHT = 32
const TILES_PER_ROW = 7
const ROWS = 2

static func generate_tileset() -> ImageTexture:
	var image = Image.create(TILE_WIDTH * TILES_PER_ROW, TILE_HEIGHT * ROWS, false, Image.FORMAT_RGBA8)

	# Row 0: EMPTY, GRASS, FAIRWAY, ROUGH, HEAVY_ROUGH, GREEN, TEE_BOX
	_draw_empty_tile(image, 0, 0)
	_draw_grass_tile(image, 1, 0)
	_draw_fairway_tile(image, 2, 0)
	_draw_rough_tile(image, 3, 0)
	_draw_heavy_rough_tile(image, 4, 0)
	_draw_green_tile(image, 5, 0)
	_draw_tee_box_tile(image, 6, 0)

	# Row 1: BUNKER, WATER, PATH, OUT_OF_BOUNDS, TREES, FLOWER_BED, ROCKS
	_draw_bunker_tile(image, 0, 1)
	_draw_water_tile(image, 1, 1)
	_draw_path_tile(image, 2, 1)
	_draw_oob_tile(image, 3, 1)
	_draw_trees_tile(image, 4, 1)
	_draw_flower_bed_tile(image, 5, 1)
	_draw_rocks_tile(image, 6, 1)

	var texture = ImageTexture.create_from_image(image)
	return texture

static func _get_tile_rect(col: int, row: int) -> Rect2i:
	return Rect2i(col * TILE_WIDTH, row * TILE_HEIGHT, TILE_WIDTH, TILE_HEIGHT)

static func _fill_tile(image: Image, col: int, row: int, color: Color) -> void:
	var rect = _get_tile_rect(col, row)
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			image.set_pixel(x, y, color)

static func _draw_empty_tile(image: Image, col: int, row: int) -> void:
	var base = Color(0.18, 0.22, 0.18)
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var noise = rng.randf_range(-0.03, 0.03)
			image.set_pixel(x, y, Color(base.r + noise, base.g + noise, base.b + noise))

static func _draw_grass_tile(image: Image, col: int, row: int) -> void:
	var base = Color(0.42, 0.58, 0.32)
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 23456

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var noise = rng.randf_range(-0.06, 0.06)
			# Add some clumpy variation
			var clump = sin(x * 0.5) * cos(y * 0.8) * 0.04
			image.set_pixel(x, y, Color(base.r + noise + clump, base.g + noise * 1.2 + clump, base.b + noise * 0.8))

static func _draw_fairway_tile(image: Image, col: int, row: int) -> void:
	var light = Color(0.42, 0.78, 0.42)
	var dark = Color(0.36, 0.72, 0.36)
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 34567

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			# Diagonal mowing stripes
			var local_x = x - rect.position.x
			var local_y = y - rect.position.y
			var stripe = int((local_x + local_y) / 8) % 2
			var base = light if stripe == 0 else dark
			var noise = rng.randf_range(-0.02, 0.02)
			image.set_pixel(x, y, Color(base.r + noise, base.g + noise, base.b + noise))

static func _draw_rough_tile(image: Image, col: int, row: int) -> void:
	var base = Color(0.36, 0.52, 0.30)
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 45678

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var noise = rng.randf_range(-0.08, 0.08)
			# Tufty grass pattern
			var tuft = sin(x * 0.8 + y * 0.3) * 0.05
			image.set_pixel(x, y, Color(base.r + noise + tuft, base.g + noise * 1.3 + tuft, base.b + noise * 0.7))

static func _draw_heavy_rough_tile(image: Image, col: int, row: int) -> void:
	var base = Color(0.30, 0.45, 0.26)
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 56789

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var noise = rng.randf_range(-0.1, 0.1)
			# Dense clumpy pattern
			var clump = sin(x * 0.6) * sin(y * 0.9) * 0.08
			image.set_pixel(x, y, Color(base.r + noise + clump, base.g + noise * 1.4 + clump, base.b + noise * 0.6))

static func _draw_green_tile(image: Image, col: int, row: int) -> void:
	var light = Color(0.38, 0.88, 0.48)
	var dark = Color(0.34, 0.82, 0.44)
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 67890

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			# Fine horizontal stripes for putting green
			var local_y = y - rect.position.y
			var stripe = int(local_y / 4) % 2
			var base = light if stripe == 0 else dark
			var noise = rng.randf_range(-0.015, 0.015)
			image.set_pixel(x, y, Color(base.r + noise, base.g + noise, base.b + noise))

static func _draw_tee_box_tile(image: Image, col: int, row: int) -> void:
	var light = Color(0.48, 0.76, 0.45)
	var dark = Color(0.42, 0.70, 0.40)
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 78901

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			# Checkerboard-ish pattern
			var local_x = x - rect.position.x
			var local_y = y - rect.position.y
			var check = (int(local_x / 8) + int(local_y / 4)) % 2
			var base = light if check == 0 else dark
			var noise = rng.randf_range(-0.02, 0.02)
			image.set_pixel(x, y, Color(base.r + noise, base.g + noise, base.b + noise))

static func _draw_bunker_tile(image: Image, col: int, row: int) -> void:
	var base = Color(0.92, 0.85, 0.62)
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 89012

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			# Sandy granular texture
			var noise = rng.randf_range(-0.08, 0.08)
			var grain = rng.randf_range(-0.04, 0.04)
			image.set_pixel(x, y, Color(base.r + noise + grain, base.g + noise * 0.9 + grain, base.b + noise * 0.5))

static func _draw_water_tile(image: Image, col: int, row: int) -> void:
	var base = Color(0.25, 0.55, 0.85)
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 90123

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var local_x = x - rect.position.x
			var local_y = y - rect.position.y
			# Wave pattern
			var wave = sin(local_x * 0.2 + local_y * 0.1) * 0.06
			var noise = rng.randf_range(-0.03, 0.03)
			image.set_pixel(x, y, Color(base.r + wave + noise, base.g + wave * 0.8 + noise, base.b + wave * 0.3 + noise))

static func _draw_path_tile(image: Image, col: int, row: int) -> void:
	var base = Color(0.75, 0.72, 0.65)
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 1234

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			# Gravel texture with speckles
			var noise = rng.randf_range(-0.1, 0.1)
			# Occasional darker pebble
			var pebble = 0.0
			if rng.randf() < 0.08:
				pebble = -0.15
			image.set_pixel(x, y, Color(base.r + noise + pebble, base.g + noise * 0.95 + pebble, base.b + noise * 0.9 + pebble))

static func _draw_oob_tile(image: Image, col: int, row: int) -> void:
	var base = Color(0.40, 0.33, 0.30)
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 2345

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var noise = rng.randf_range(-0.05, 0.05)
			image.set_pixel(x, y, Color(base.r + noise, base.g + noise, base.b + noise))

static func _draw_trees_tile(image: Image, col: int, row: int) -> void:
	# Dark green base - the tree overlay will draw actual trees on top
	var base = Color(0.20, 0.42, 0.20)
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 3456

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var noise = rng.randf_range(-0.06, 0.06)
			var dapple = sin(x * 0.4) * cos(y * 0.6) * 0.05
			image.set_pixel(x, y, Color(base.r + noise + dapple, base.g + noise * 1.2 + dapple, base.b + noise * 0.8))

static func _draw_flower_bed_tile(image: Image, col: int, row: int) -> void:
	# Brown mulch/soil base - flower overlay will add flowers
	var base = Color(0.45, 0.32, 0.22)
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 4567

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var noise = rng.randf_range(-0.08, 0.08)
			# Mulch texture
			var mulch = 0.0
			if rng.randf() < 0.15:
				mulch = rng.randf_range(-0.1, 0.1)
			image.set_pixel(x, y, Color(base.r + noise + mulch, base.g + noise * 0.8 + mulch, base.b + noise * 0.6 + mulch))

static func _draw_rocks_tile(image: Image, col: int, row: int) -> void:
	# Gray rocky ground - rock overlay will add actual rocks
	var base = Color(0.48, 0.46, 0.42)
	var rect = _get_tile_rect(col, row)
	var rng = RandomNumberGenerator.new()
	rng.seed = 5678

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var noise = rng.randf_range(-0.1, 0.1)
			# Rocky texture with variation
			var rocky = sin(x * 0.3 + y * 0.2) * 0.06
			image.set_pixel(x, y, Color(base.r + noise + rocky, base.g + noise * 0.98 + rocky, base.b + noise * 0.95 + rocky))

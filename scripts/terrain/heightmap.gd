class_name Heightmap
extends RefCounted
## Heightmap - Course-wide R8 grayscale texture encoding sub-tile elevation
##
## Resolution: 512x512 (4 pixels per tile on a 128x128 grid)
## Value encoding: 0 = lowest (-5), 128 = sea level (0), 255 = highest (+5)
## Updated on elevation/tile changes, not every frame.
##
## FastNoiseLite Simplex noise is overlaid on top of per-terrain profiles to
## break tile-aligned patterns and create natural rolling terrain.
## A 5-tap Gaussian blur smooths sharp tile boundaries after pixel writes.

const PIXELS_PER_TILE: int = 4
const SEA_LEVEL: int = 128  # Grayscale value for elevation 0
const ELEVATION_SCALE: float = 25.6  # Grayscale units per integer elevation level

const NEIGHBOR_DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

# 5-tap separable Gaussian kernel (sigma ~1.0, pre-normalized)
const BLUR_KERNEL: Array[float] = [0.06136, 0.24477, 0.38774, 0.24477, 0.06136]
const BLUR_RADIUS: int = 2

# Per-terrain noise amplitude in elevation units (not grayscale)
const NOISE_AMPLITUDES: Dictionary = {
	TerrainTypes.Type.EMPTY: 0.08,
	TerrainTypes.Type.GRASS: 0.15,
	TerrainTypes.Type.FAIRWAY: 0.12,
	TerrainTypes.Type.ROUGH: 0.16,
	TerrainTypes.Type.HEAVY_ROUGH: 0.18,
	TerrainTypes.Type.GREEN: 0.04,
	TerrainTypes.Type.TEE_BOX: 0.02,
	TerrainTypes.Type.BUNKER: 0.06,
	TerrainTypes.Type.WATER: 0.0,
	TerrainTypes.Type.PATH: 0.02,
	TerrainTypes.Type.OUT_OF_BOUNDS: 0.10,
	TerrainTypes.Type.TREES: 0.14,
	TerrainTypes.Type.FLOWER_BED: 0.10,
	TerrainTypes.Type.ROCKS: 0.12,
}

var _image: Image
var _texture: ImageTexture
var _grid_width: int
var _grid_height: int
var _noise_detail: FastNoiseLite  # Small-scale texture (freq 0.15)
var _noise_broad: FastNoiseLite   # Broad rolling hills (freq 0.03)
var _noise_seed: int

func _init(grid_width: int = 128, grid_height: int = 128, noise_seed: int = 0) -> void:
	_grid_width = grid_width
	_grid_height = grid_height
	_noise_seed = noise_seed if noise_seed != 0 else randi()

	# Detail noise: small-scale terrain texture
	_noise_detail = FastNoiseLite.new()
	_noise_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_detail.seed = _noise_seed
	_noise_detail.frequency = 0.15
	_noise_detail.fractal_octaves = 2
	_noise_detail.fractal_lacunarity = 2.0
	_noise_detail.fractal_gain = 0.5

	# Broad noise: rolling hills spanning 5-10 tiles
	_noise_broad = FastNoiseLite.new()
	_noise_broad.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_broad.seed = _noise_seed + 1000  # Different seed for independent pattern
	_noise_broad.frequency = 0.03
	_noise_broad.fractal_octaves = 2
	_noise_broad.fractal_lacunarity = 2.0
	_noise_broad.fractal_gain = 0.5

	var tex_width: int = grid_width * PIXELS_PER_TILE   # 512
	var tex_height: int = grid_height * PIXELS_PER_TILE  # 512
	_image = Image.create(tex_width, tex_height, false, Image.FORMAT_R8)
	_image.fill(Color(float(SEA_LEVEL) / 255.0, 0, 0))  # R8: uses red channel only
	_texture = ImageTexture.create_from_image(_image)

func get_texture() -> ImageTexture:
	return _texture

func get_noise_seed() -> int:
	return _noise_seed

## Convert integer elevation (-5..+5) to grayscale byte (0..255)
static func elevation_to_grayscale(elevation: int) -> int:
	return clampi(SEA_LEVEL + roundi(elevation * ELEVATION_SCALE), 0, 255)

## Convert grayscale byte back to float elevation
static func grayscale_to_elevation(gray: int) -> float:
	return (float(gray) - SEA_LEVEL) / ELEVATION_SCALE

## Sample dual-frequency noise for a pixel, scaled by terrain type amplitude
func _get_noise_offset(px: int, py: int, terrain_type: int) -> int:
	var amplitude: float = NOISE_AMPLITUDES.get(terrain_type, 0.04)
	if amplitude <= 0.0:
		return 0
	var detail: float = _noise_detail.get_noise_2d(float(px), float(py))  # [-1, 1]
	var broad: float = _noise_broad.get_noise_2d(float(px), float(py))    # [-1, 1]
	# Broad hills contribute 60%, detail texture 40%
	var combined: float = broad * 0.6 + detail * 0.4
	return roundi(combined * amplitude * ELEVATION_SCALE)

## Update the heightmap for a single tile, applying its terrain profile
func set_tile_elevation(pos: Vector2i, base_elevation: int, terrain_type: int) -> void:
	var profile: Array = ElevationProfiles.get_varied_profile(terrain_type, pos)
	var base_gray: int = elevation_to_grayscale(base_elevation)
	var px: int = pos.x * PIXELS_PER_TILE
	var py: int = pos.y * PIXELS_PER_TILE

	for ly in PIXELS_PER_TILE:
		for lx in PIXELS_PER_TILE:
			var offset_gray: int = roundi(profile[ly][lx] * ELEVATION_SCALE)
			var noise_offset: int = _get_noise_offset(px + lx, py + ly, terrain_type)
			var final_gray: int = clampi(base_gray + offset_gray + noise_offset, 0, 255)
			_set_pixel_safe(px + lx, py + ly, final_gray)

	_blur_region(pos)
	_texture.update(_image)

## Write heightmap with 1-pixel border blending into neighbors
func set_tile_elevation_blended(pos: Vector2i, base_elevation: int, terrain_type: int,
								terrain_grid: TerrainGrid) -> void:
	var profile: Array = ElevationProfiles.get_varied_profile(terrain_type, pos)
	var base_gray: int = elevation_to_grayscale(base_elevation)
	var px: int = pos.x * PIXELS_PER_TILE
	var py: int = pos.y * PIXELS_PER_TILE

	# Write the core 4x4 block
	for ly in PIXELS_PER_TILE:
		for lx in PIXELS_PER_TILE:
			var offset_gray: int = roundi(profile[ly][lx] * ELEVATION_SCALE)
			var noise_offset: int = _get_noise_offset(px + lx, py + ly, terrain_type)
			var final_gray: int = clampi(base_gray + offset_gray + noise_offset, 0, 255)
			_set_pixel_safe(px + lx, py + ly, final_gray)

	# Blend border pixels with each neighbor
	for dir_idx in NEIGHBOR_DIRS.size():
		var n_pos: Vector2i = pos + NEIGHBOR_DIRS[dir_idx]
		if not terrain_grid.is_valid_position(n_pos):
			continue
		var n_elev: int = terrain_grid.get_elevation(n_pos)
		var n_type: int = terrain_grid.get_tile(n_pos)
		var n_profile: Array = ElevationProfiles.get_varied_profile(n_type, n_pos)
		var n_base_gray: int = elevation_to_grayscale(n_elev)

		# Average the border pixels where tiles meet
		_blend_border(px, py, profile, base_gray, terrain_type,
					  n_pos.x * PIXELS_PER_TILE, n_pos.y * PIXELS_PER_TILE,
					  n_profile, n_base_gray, n_type, NEIGHBOR_DIRS[dir_idx])

	_blur_region(pos)
	_texture.update(_image)

## Bulk rebuild — call after loading a save or generating terrain
func rebuild_from_grids(terrain_grid: TerrainGrid) -> void:
	for y in _grid_height:
		for x in _grid_width:
			var pos: Vector2i = Vector2i(x, y)
			var elev: int = terrain_grid.get_elevation(pos)
			var ttype: int = terrain_grid.get_tile(pos)
			var profile: Array = ElevationProfiles.get_varied_profile(ttype, pos)
			var base_gray: int = elevation_to_grayscale(elev)
			var px: int = pos.x * PIXELS_PER_TILE
			var py: int = pos.y * PIXELS_PER_TILE

			for ly in PIXELS_PER_TILE:
				for lx in PIXELS_PER_TILE:
					var offset_gray: int = roundi(profile[ly][lx] * ELEVATION_SCALE)
					var noise_offset: int = _get_noise_offset(px + lx, py + ly, ttype)
					var final_gray: int = clampi(base_gray + offset_gray + noise_offset, 0, 255)
					_set_pixel_safe(px + lx, py + ly, final_gray)

	_blur_full()
	_texture.update(_image)

func _blend_border(px1: int, py1: int, prof1: Array, base1: int, ttype1: int,
				   px2: int, py2: int, prof2: Array, base2: int, ttype2: int,
				   dir: Vector2i) -> void:
	# For each pixel on the shared edge, average values from both tiles (including noise)
	if dir == Vector2i(1, 0):  # Neighbor to the right
		for ly in PIXELS_PER_TILE:
			var v1: int = base1 + roundi(prof1[ly][PIXELS_PER_TILE - 1] * ELEVATION_SCALE) + _get_noise_offset(px1 + PIXELS_PER_TILE - 1, py1 + ly, ttype1)
			var v2: int = base2 + roundi(prof2[ly][0] * ELEVATION_SCALE) + _get_noise_offset(px2, py2 + ly, ttype2)
			var avg: int = clampi((v1 + v2) / 2, 0, 255)
			_set_pixel_safe(px1 + PIXELS_PER_TILE - 1, py1 + ly, avg)
			_set_pixel_safe(px2, py2 + ly, avg)
	elif dir == Vector2i(-1, 0):  # Neighbor to the left
		for ly in PIXELS_PER_TILE:
			var v1: int = base1 + roundi(prof1[ly][0] * ELEVATION_SCALE) + _get_noise_offset(px1, py1 + ly, ttype1)
			var v2: int = base2 + roundi(prof2[ly][PIXELS_PER_TILE - 1] * ELEVATION_SCALE) + _get_noise_offset(px2 + PIXELS_PER_TILE - 1, py2 + ly, ttype2)
			var avg: int = clampi((v1 + v2) / 2, 0, 255)
			_set_pixel_safe(px1, py1 + ly, avg)
			_set_pixel_safe(px2 + PIXELS_PER_TILE - 1, py2 + ly, avg)
	elif dir == Vector2i(0, 1):  # Neighbor below
		for lx in PIXELS_PER_TILE:
			var v1: int = base1 + roundi(prof1[PIXELS_PER_TILE - 1][lx] * ELEVATION_SCALE) + _get_noise_offset(px1 + lx, py1 + PIXELS_PER_TILE - 1, ttype1)
			var v2: int = base2 + roundi(prof2[0][lx] * ELEVATION_SCALE) + _get_noise_offset(px2 + lx, py2, ttype2)
			var avg: int = clampi((v1 + v2) / 2, 0, 255)
			_set_pixel_safe(px1 + lx, py1 + PIXELS_PER_TILE - 1, avg)
			_set_pixel_safe(px2 + lx, py2, avg)
	elif dir == Vector2i(0, -1):  # Neighbor above
		for lx in PIXELS_PER_TILE:
			var v1: int = base1 + roundi(prof1[0][lx] * ELEVATION_SCALE) + _get_noise_offset(px1 + lx, py1, ttype1)
			var v2: int = base2 + roundi(prof2[PIXELS_PER_TILE - 1][lx] * ELEVATION_SCALE) + _get_noise_offset(px2 + lx, py2 + PIXELS_PER_TILE - 1, ttype2)
			var avg: int = clampi((v1 + v2) / 2, 0, 255)
			_set_pixel_safe(px1 + lx, py1, avg)
			_set_pixel_safe(px2 + lx, py2 + PIXELS_PER_TILE - 1, avg)

func _set_pixel_safe(x: int, y: int, gray_value: int) -> void:
	if x >= 0 and x < _image.get_width() and y >= 0 and y < _image.get_height():
		_image.set_pixel(x, y, Color(float(gray_value) / 255.0, 0, 0))

func _get_pixel_gray(x: int, y: int) -> float:
	return _image.get_pixel(x, y).r * 255.0

## Separable Gaussian blur over the entire heightmap image
func _blur_full() -> void:
	var w: int = _image.get_width()
	var h: int = _image.get_height()

	# Horizontal pass: _image -> temp
	var temp: PackedFloat32Array = PackedFloat32Array()
	temp.resize(w * h)

	for y in h:
		for x in w:
			var sum: float = 0.0
			for k in BLUR_KERNEL.size():
				var sx: int = clampi(x + k - BLUR_RADIUS, 0, w - 1)
				sum += _get_pixel_gray(sx, y) * BLUR_KERNEL[k]
			temp[y * w + x] = sum

	# Vertical pass: temp -> _image
	for y in h:
		for x in w:
			var sum: float = 0.0
			for k in BLUR_KERNEL.size():
				var sy: int = clampi(y + k - BLUR_RADIUS, 0, h - 1)
				sum += temp[sy * w + x] * BLUR_KERNEL[k]
			_set_pixel_safe(x, y, roundi(sum))

## Blur a small region around a single tile (tile pixels + 2px border)
func _blur_region(tile_pos: Vector2i) -> void:
	var w: int = _image.get_width()
	var h: int = _image.get_height()
	var px: int = tile_pos.x * PIXELS_PER_TILE
	var py: int = tile_pos.y * PIXELS_PER_TILE

	# Region to write back (tile + blur radius border)
	var x0: int = maxi(px - BLUR_RADIUS, 0)
	var y0: int = maxi(py - BLUR_RADIUS, 0)
	var x1: int = mini(px + PIXELS_PER_TILE + BLUR_RADIUS, w)
	var y1: int = mini(py + PIXELS_PER_TILE + BLUR_RADIUS, h)
	var rw: int = x1 - x0
	var rh: int = y1 - y0

	# Horizontal pass into temp array
	var temp: PackedFloat32Array = PackedFloat32Array()
	temp.resize(rw * rh)

	for ry in rh:
		var gy: int = y0 + ry
		for rx in rw:
			var gx: int = x0 + rx
			var sum: float = 0.0
			for k in BLUR_KERNEL.size():
				var sx: int = clampi(gx + k - BLUR_RADIUS, 0, w - 1)
				sum += _get_pixel_gray(sx, gy) * BLUR_KERNEL[k]
			temp[ry * rw + rx] = sum

	# Vertical pass from temp, write to image
	for ry in rh:
		var gy: int = y0 + ry
		for rx in rw:
			var gx: int = x0 + rx
			var sum: float = 0.0
			for k in BLUR_KERNEL.size():
				var sy: int = clampi(gy + k - BLUR_RADIUS, 0, h - 1)
				# Use temp if within our region, otherwise read from image
				var ty: int = sy - y0
				if ty >= 0 and ty < rh:
					sum += temp[ty * rw + rx] * BLUR_KERNEL[k]
				else:
					sum += _get_pixel_gray(gx, sy) * BLUR_KERNEL[k]
			_set_pixel_safe(gx, gy, roundi(sum))

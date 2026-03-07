class_name Heightmap
extends RefCounted
## Heightmap - Course-wide R8 grayscale texture encoding sub-tile elevation
##
## Resolution: 512x512 (4 pixels per tile on a 128x128 grid)
## Value encoding: 0 = lowest (-5), 128 = sea level (0), 255 = highest (+5)
## Updated on elevation/tile changes, not every frame.

const PIXELS_PER_TILE: int = 4
const SEA_LEVEL: int = 128  # Grayscale value for elevation 0
const ELEVATION_SCALE: float = 25.6  # Grayscale units per integer elevation level

var _image: Image
var _texture: ImageTexture
var _grid_width: int
var _grid_height: int

func _init(grid_width: int = 128, grid_height: int = 128) -> void:
	_grid_width = grid_width
	_grid_height = grid_height
	var tex_width := grid_width * PIXELS_PER_TILE   # 512
	var tex_height := grid_height * PIXELS_PER_TILE  # 512
	_image = Image.create(tex_width, tex_height, false, Image.FORMAT_R8)
	_image.fill(Color(float(SEA_LEVEL) / 255.0, 0, 0))  # R8: uses red channel only
	_texture = ImageTexture.create_from_image(_image)

func get_texture() -> ImageTexture:
	return _texture

## Convert integer elevation (-5..+5) to grayscale byte (0..255)
static func elevation_to_grayscale(elevation: int) -> int:
	return clampi(SEA_LEVEL + roundi(elevation * ELEVATION_SCALE), 0, 255)

## Convert grayscale byte back to float elevation
static func grayscale_to_elevation(gray: int) -> float:
	return (float(gray) - SEA_LEVEL) / ELEVATION_SCALE

## Update the heightmap for a single tile, applying its terrain profile
func set_tile_elevation(pos: Vector2i, base_elevation: int, terrain_type: int) -> void:
	var profile := ElevationProfiles.get_varied_profile(terrain_type, pos)
	var base_gray := elevation_to_grayscale(base_elevation)
	var px := pos.x * PIXELS_PER_TILE
	var py := pos.y * PIXELS_PER_TILE

	for ly in PIXELS_PER_TILE:
		for lx in PIXELS_PER_TILE:
			# profile is a 4x4 float array, values in [-1.0, +1.0] range
			# representing sub-tile elevation offset relative to base
			var offset_gray := roundi(profile[ly][lx] * ELEVATION_SCALE)
			var final_gray := clampi(base_gray + offset_gray, 0, 255)
			_set_pixel_safe(px + lx, py + ly, final_gray)

	_texture.update(_image)

## Write heightmap with 1-pixel border blending into neighbors
func set_tile_elevation_blended(pos: Vector2i, base_elevation: int, terrain_type: int,
								terrain_grid: TerrainGrid) -> void:
	var profile := ElevationProfiles.get_varied_profile(terrain_type, pos)
	var base_gray := elevation_to_grayscale(base_elevation)
	var px := pos.x * PIXELS_PER_TILE
	var py := pos.y * PIXELS_PER_TILE

	# Write the core 4x4 block
	for ly in PIXELS_PER_TILE:
		for lx in PIXELS_PER_TILE:
			var offset_gray := roundi(profile[ly][lx] * ELEVATION_SCALE)
			var final_gray := clampi(base_gray + offset_gray, 0, 255)
			_set_pixel_safe(px + lx, py + ly, final_gray)

	# Blend border pixels with each neighbor
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n_pos := pos + dir
		if not terrain_grid.is_valid_position(n_pos):
			continue
		var n_elev := terrain_grid.get_elevation(n_pos)
		var n_type := terrain_grid.get_tile(n_pos)
		var n_profile := ElevationProfiles.get_varied_profile(n_type, n_pos)
		var n_base_gray := elevation_to_grayscale(n_elev)

		# Average the border pixels where tiles meet
		_blend_border(px, py, profile, base_gray,
					  n_pos.x * PIXELS_PER_TILE, n_pos.y * PIXELS_PER_TILE,
					  n_profile, n_base_gray, dir)

	_texture.update(_image)

## Bulk rebuild — call after loading a save or generating terrain
func rebuild_from_grids(terrain_grid: TerrainGrid) -> void:
	for y in _grid_height:
		for x in _grid_width:
			var pos := Vector2i(x, y)
			var elev := terrain_grid.get_elevation(pos)
			var ttype := terrain_grid.get_tile(pos)
			var profile := ElevationProfiles.get_varied_profile(ttype, pos)
			var base_gray := elevation_to_grayscale(elev)
			var px := pos.x * PIXELS_PER_TILE
			var py := pos.y * PIXELS_PER_TILE

			for ly in PIXELS_PER_TILE:
				for lx in PIXELS_PER_TILE:
					var offset_gray := roundi(profile[ly][lx] * ELEVATION_SCALE)
					var final_gray := clampi(base_gray + offset_gray, 0, 255)
					_set_pixel_safe(px + lx, py + ly, final_gray)
	_texture.update(_image)

func _blend_border(px1: int, py1: int, prof1: Array, base1: int,
				   px2: int, py2: int, prof2: Array, base2: int,
				   dir: Vector2i) -> void:
	# For each pixel on the shared edge, average values from both tiles
	if dir == Vector2i(1, 0):  # Neighbor to the right
		for ly in PIXELS_PER_TILE:
			var v1 := base1 + roundi(prof1[ly][PIXELS_PER_TILE - 1] * ELEVATION_SCALE)
			var v2 := base2 + roundi(prof2[ly][0] * ELEVATION_SCALE)
			var avg := clampi((v1 + v2) / 2, 0, 255)
			_set_pixel_safe(px1 + PIXELS_PER_TILE - 1, py1 + ly, avg)
			_set_pixel_safe(px2, py2 + ly, avg)
	elif dir == Vector2i(-1, 0):  # Neighbor to the left
		for ly in PIXELS_PER_TILE:
			var v1 := base1 + roundi(prof1[ly][0] * ELEVATION_SCALE)
			var v2 := base2 + roundi(prof2[ly][PIXELS_PER_TILE - 1] * ELEVATION_SCALE)
			var avg := clampi((v1 + v2) / 2, 0, 255)
			_set_pixel_safe(px1, py1 + ly, avg)
			_set_pixel_safe(px2 + PIXELS_PER_TILE - 1, py2 + ly, avg)
	elif dir == Vector2i(0, 1):  # Neighbor below
		for lx in PIXELS_PER_TILE:
			var v1 := base1 + roundi(prof1[PIXELS_PER_TILE - 1][lx] * ELEVATION_SCALE)
			var v2 := base2 + roundi(prof2[0][lx] * ELEVATION_SCALE)
			var avg := clampi((v1 + v2) / 2, 0, 255)
			_set_pixel_safe(px1 + lx, py1 + PIXELS_PER_TILE - 1, avg)
			_set_pixel_safe(px2 + lx, py2, avg)
	elif dir == Vector2i(0, -1):  # Neighbor above
		for lx in PIXELS_PER_TILE:
			var v1 := base1 + roundi(prof1[0][lx] * ELEVATION_SCALE)
			var v2 := base2 + roundi(prof2[PIXELS_PER_TILE - 1][lx] * ELEVATION_SCALE)
			var avg := clampi((v1 + v2) / 2, 0, 255)
			_set_pixel_safe(px1 + lx, py1, avg)
			_set_pixel_safe(px2 + lx, py2 + PIXELS_PER_TILE - 1, avg)

func _set_pixel_safe(x: int, y: int, gray_value: int) -> void:
	if x >= 0 and x < _image.get_width() and y >= 0 and y < _image.get_height():
		_image.set_pixel(x, y, Color(float(gray_value) / 255.0, 0, 0))

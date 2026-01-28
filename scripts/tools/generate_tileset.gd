@tool
extends EditorScript

## Tool script to generate placeholder tileset for terrain types
## Run this from Editor > Run Script in Godot

func _run() -> void:
	print("Generating placeholder tileset...")

	# Tile dimensions (isometric)
	const TILE_WIDTH = 64
	const TILE_HEIGHT = 32
	const TILES_PER_ROW = 7

	# Calculate image dimensions (14 terrain types in a grid)
	var num_types = 14
	var rows = ceili(float(num_types) / TILES_PER_ROW)
	var image_width = TILES_PER_ROW * TILE_WIDTH
	var image_height = rows * TILE_HEIGHT

	# Create image
	var image = Image.create(image_width, image_height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))  # Transparent background

	# Get terrain colors from TerrainTypes
	var terrain_colors = [
		Color(0.2, 0.2, 0.2),        # 0: EMPTY
		Color(0.4, 0.6, 0.3),        # 1: GRASS
		Color(0.3, 0.75, 0.3),       # 2: FAIRWAY
		Color(0.35, 0.55, 0.25),     # 3: ROUGH
		Color(0.3, 0.45, 0.2),       # 4: HEAVY_ROUGH
		Color(0.2, 0.85, 0.3),       # 5: GREEN
		Color(0.25, 0.8, 0.35),      # 6: TEE_BOX
		Color(0.9, 0.85, 0.6),       # 7: BUNKER
		Color(0.2, 0.5, 0.8),        # 8: WATER
		Color(0.7, 0.7, 0.65),       # 9: PATH
		Color(0.5, 0.3, 0.3),        # 10: OUT_OF_BOUNDS
		Color(0.15, 0.4, 0.15),      # 11: TREES
		Color(0.8, 0.4, 0.5),        # 12: FLOWER_BED
		Color(0.5, 0.5, 0.5),        # 13: ROCKS
	]

	# Draw isometric diamond tiles
	for i in range(num_types):
		var col = i % TILES_PER_ROW
		var row = i / TILES_PER_ROW
		var base_x = col * TILE_WIDTH
		var base_y = row * TILE_HEIGHT

		draw_isometric_tile(image, base_x, base_y, TILE_WIDTH, TILE_HEIGHT, terrain_colors[i])

	# Save the image
	var save_path = "res://assets/tilesets/terrain_tileset.png"
	var err = image.save_png(save_path)

	if err == OK:
		print("✓ Tileset generated successfully at: ", save_path)
		print("  Image size: ", image_width, "x", image_height)
		print("  Tiles: ", num_types, " (", TILES_PER_ROW, " per row)")
	else:
		print("✗ Error saving tileset: ", err)

func draw_isometric_tile(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	# Draw a solid filled rectangle
	for py in range(height):
		for px in range(width):
			var pixel_x = x + px
			var pixel_y = y + py
			if pixel_x >= 0 and pixel_x < image.get_width() and pixel_y >= 0 and pixel_y < image.get_height():
				image.set_pixel(pixel_x, pixel_y, color)

func draw_isometric_outline(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	var half_width = width / 2
	var half_height = height / 2

	# Draw 4 edges of the diamond
	var edges = [
		[Vector2(half_width, 0), Vector2(width, half_height)],         # Top-right edge
		[Vector2(width, half_height), Vector2(half_width, height)],    # Bottom-right edge
		[Vector2(half_width, height), Vector2(0, half_height)],        # Bottom-left edge
		[Vector2(0, half_height), Vector2(half_width, 0)],             # Top-left edge
	]

	for edge in edges:
		draw_line_on_image(image, x + edge[0].x, y + edge[0].y, x + edge[1].x, y + edge[1].y, color)

func draw_line_on_image(image: Image, x0: float, y0: float, x1: float, y1: float, color: Color) -> void:
	# Simple line drawing using Bresenham's algorithm
	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy

	var x = int(x0)
	var y = int(y0)

	while true:
		if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
			image.set_pixel(x, y, color)

		if x == int(x1) and y == int(y1):
			break

		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy

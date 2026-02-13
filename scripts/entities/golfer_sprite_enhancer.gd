extends RefCounted
class_name GolferSpriteEnhancer
## GolferSpriteEnhancer - Enhances golfer Polygon2D rendering
##
## Adds outlines, direction-based facing, and better proportions to
## the existing procedural golfer sprites.

## Direction the golfer is facing (for visual mirroring)
enum Facing { RIGHT, LEFT, UP, DOWN }

## Add dark outlines to all Polygon2D parts of a golfer visual
static func add_outlines(visual: Node2D, outline_color: Color = Color(0.1, 0.1, 0.1, 0.8), outline_width: float = 1.0) -> void:
	for child in visual.get_children():
		if child is Polygon2D and child.polygon.size() > 0:
			_add_outline_to_polygon(child, outline_color, outline_width)

## Add a single outline Line2D behind a Polygon2D
static func _add_outline_to_polygon(poly: Polygon2D, color: Color, width: float) -> void:
	# Check if outline already exists
	var outline_name = poly.name + "Outline"
	if poly.get_parent().has_node(outline_name):
		return

	var line = Line2D.new()
	line.name = outline_name
	line.width = width
	line.default_color = color
	line.z_index = poly.z_index - 1  # Behind the polygon

	# Copy polygon points as line points (closed loop)
	var points = poly.polygon.duplicate()
	if points.size() > 0:
		points.append(points[0])  # Close the loop
	line.points = points

	# Match transform
	line.position = poly.position
	line.rotation = poly.rotation
	line.scale = poly.scale

	# Add before the polygon so it renders behind
	var parent = poly.get_parent()
	parent.add_child(line)
	parent.move_child(line, poly.get_index())

## Update visual facing based on movement direction
static func update_facing(visual: Node2D, direction: Vector2) -> Facing:
	if direction.length_squared() < 0.01:
		return Facing.DOWN  # Default facing

	# Mirror the visual horizontally based on movement direction
	if direction.x < -0.1:
		visual.scale.x = -abs(visual.scale.x)
		return Facing.LEFT
	elif direction.x > 0.1:
		visual.scale.x = abs(visual.scale.x)
		return Facing.RIGHT

	if direction.y < -0.1:
		return Facing.UP
	return Facing.DOWN

## Apply a highlight glow effect (for player-controlled golfer)
static func apply_player_highlight(visual: Node2D, color: Color = Color(0.3, 0.9, 0.3, 0.4)) -> void:
	var highlight_name = "PlayerHighlight"
	if visual.has_node(highlight_name):
		return

	# Create a simple glow circle behind the golfer
	var highlight = Polygon2D.new()
	highlight.name = highlight_name
	highlight.z_index = -2
	highlight.color = color

	# Create circle polygon
	var points = PackedVector2Array()
	for i in range(16):
		var angle = (i / 16.0) * TAU
		points.append(Vector2(cos(angle) * 12, sin(angle) * 8))  # Elliptical
	highlight.polygon = points

	visual.add_child(highlight)
	visual.move_child(highlight, 0)  # Move to back

## Remove player highlight
static func remove_player_highlight(visual: Node2D) -> void:
	var highlight = visual.get_node_or_null("PlayerHighlight")
	if highlight:
		highlight.queue_free()

## Apply tier-based visual distinction (subtle color tinting)
static func apply_tier_badge(info_container: Control, tier: int) -> void:
	if not info_container:
		return

	var badge_name = "TierBadge"
	var existing = info_container.get_node_or_null(badge_name)
	if existing:
		existing.queue_free()

	var tier_names = {0: "B", 1: "C", 2: "S", 3: "P"}
	var tier_colors = {
		0: Color(0.6, 0.6, 0.6),   # Gray for beginner
		1: Color(0.5, 0.8, 0.5),   # Green for casual
		2: Color(0.5, 0.6, 0.9),   # Blue for serious
		3: Color(0.9, 0.7, 0.3),   # Gold for pro
	}

	var badge = Label.new()
	badge.name = badge_name
	badge.text = "[%s]" % tier_names.get(tier, "?")
	badge.add_theme_font_size_override("font_size", 8)
	badge.add_theme_color_override("font_color", tier_colors.get(tier, Color.WHITE))
	info_container.add_child(badge)

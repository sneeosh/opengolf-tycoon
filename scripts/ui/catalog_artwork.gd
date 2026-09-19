extends Control
class_name CatalogArtwork
## Catalog thumbnails use the same drawing code as objects on the course.
var kind := ""
var data: Dictionary = {}
var is_building := false
var _texture: Texture2D

func _ready() -> void:
	var path: String = Decoration.SPRITE_PATHS.get(kind, "")
	if not is_building and not path.is_empty() and ResourceLoader.exists(path):
		_texture = load(path)
	queue_redraw()

static func decorate_button(button: Button, type: String, item: Dictionary, building: bool) -> void:
	var copy := button.text
	button.text = ""
	button.icon = null
	button.custom_minimum_size = Vector2(335 if building else 305, 100)
	var art := CatalogArtwork.new()
	art.kind = type
	art.data = item
	art.is_building = building
	art.position = Vector2(6, 8)
	art.size = Vector2(100, 82)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(art)
	var label := Label.new()
	label.text = copy
	label.position = Vector2(110, 23)
	label.add_theme_font_size_override("font_size", 14)
	label.modulate.a = .45 if button.disabled else 1.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)

func _draw() -> void:
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	if is_building:
		var dimensions: Array = data.get("size", [1, 1])
		var footprint := Vector2(dimensions[0] * 64, dimensions[1] * 32)
		var scale_factor := minf(88.0 / footprint.x, 70.0 / (footprint.y + 70))
		draw_set_transform(Vector2((100-footprint.x*scale_factor)/2, 60 * scale_factor), 0, Vector2.ONE * scale_factor)
		CourseArchitecture.draw_building(self, kind, footprint)
	elif GardenArt.has_art(kind):
		draw_set_transform(Vector2(50, 62), 0, Vector2.ONE * 1.25)
		GardenArt.draw_piece(self, kind)
	elif PathFurniture.has_art(kind):
		draw_set_transform(Vector2(50, 62), 0, Vector2.ONE * 1.25)
		PathFurniture.draw_item(self, kind, Vector2i.DOWN)
	else:
		if _texture:
			var texture := _texture
			var ratio := minf(80.0 / texture.get_width(), 74.0 / texture.get_height())
			var dimensions := texture.get_size() * ratio
			draw_texture_rect(texture, Rect2((size-dimensions)/2, dimensions), false)
	draw_set_transform(Vector2.ZERO)

func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("46684b")
	style.set_corner_radius_all(8)
	return style

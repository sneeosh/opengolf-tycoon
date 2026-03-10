extends Node
class_name ElevationShaderController
## ElevationShaderController - Bridges GDScript and the elevation lighting shader
##
## Syncs light direction with the day/night cycle and weather conditions.
## Camera mapping is handled in the shader via VERTEX world_position.

var _shader_material: ShaderMaterial
var _color_rect: ColorRect
var _terrain_grid: TerrainGrid

func setup(terrain_grid: TerrainGrid, color_rect: ColorRect, shader_material: ShaderMaterial) -> void:
	_terrain_grid = terrain_grid
	_color_rect = color_rect
	_shader_material = shader_material

func _process(_delta: float) -> void:
	if not _shader_material:
		return

	# Sync light direction with time of day
	_update_light_from_time()

	# Shader LOD via zoom — disable contours when zoomed far out
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera:
		if camera.zoom.x < 0.3:
			_shader_material.set_shader_parameter("contour_enabled", false)
		else:
			_shader_material.set_shader_parameter("contour_enabled", true)

func _update_light_from_time() -> void:
	var hour: float = GameManager.current_hour

	# Sun arc: rises east (right), sets west (left)
	# 6 AM = east (1, -0.3), noon = overhead (0, -1), 6 PM = west (-1, -0.3)
	if hour >= 6.0 and hour <= 18.0:
		var t: float = (hour - 6.0) / 12.0  # 0.0 at 6AM, 1.0 at 6PM
		var angle: float = lerpf(-PI * 0.15, -PI * 0.85, t)  # East to west arc
		var sun_dir: Vector2 = Vector2(cos(angle), sin(angle)).normalized()
		_shader_material.set_shader_parameter("light_direction", sun_dir)
		_shader_material.set_shader_parameter("light_intensity", 0.5)
		_shader_material.set_shader_parameter("shadow_intensity", 0.4)
	else:
		# Night: dim moonlight from above-left
		_shader_material.set_shader_parameter("light_direction", Vector2(-0.5, -0.8))
		_shader_material.set_shader_parameter("light_intensity", 0.15)
		_shader_material.set_shader_parameter("shadow_intensity", 0.15)

	# Weather dimming
	if GameManager.weather_system:
		var weather_mod: float = GameManager.weather_system.get_light_modifier()
		var current_light: float = float(_shader_material.get_shader_parameter("light_intensity"))
		_shader_material.set_shader_parameter("light_intensity", current_light * weather_mod)

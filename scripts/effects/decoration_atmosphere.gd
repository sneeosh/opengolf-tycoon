extends Node2D
class_name DecorationAtmosphere
## Animated details attached to existing decorative sprites; no simulation effects.

var kind := ""
var terrain_grid: TerrainGrid
var _time := 0.0
var _redraw_elapsed := 0.0

func _process(delta: float) -> void:
	if GameManager.is_paused or GameManager.current_speed == GameManager.GameSpeed.PAUSED:
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	_time += real_delta
	_redraw_elapsed += real_delta
	if _redraw_elapsed >= 1.0 / 15.0:
		_redraw_elapsed = 0.0
		queue_redraw()

func _draw() -> void:
	if terrain_grid and not terrain_grid.get_visible_world_rect().grow(64).has_point(global_position):
		return
	var phase := _time + global_position.x * 0.017
	if kind == "fountain":
		_draw_fountain(phase)
	elif kind == "bird_bath":
		_draw_bird_bath(phase)

func _draw_fountain(phase: float) -> void:
	var water := Color(0.78, 0.94, 1.0, 0.65)
	# Falling beads follow the existing sprite's central jet into the lower bowl.
	for i in range(6):
		var t := fposmod(phase * 0.8 + float(i) / 6.0, 1.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := Vector2(side * t * 12.0, -43.0 + t * t * 27.0)
		draw_line(p, p + Vector2(side, 2.0 + t), water, 1.0)
	# Elliptical ripple fits the original basin, rather than growing onto the turf.
	var ripple := fposmod(phase * 0.55, 1.0)
	draw_set_transform(Vector2(0, -16), 0.0, Vector2(1.0, 0.35))
	draw_arc(Vector2.ZERO, 5.0 + ripple * 15.0, 0, TAU, 20,
		Color(0.85, 0.97, 1.0, (1.0 - ripple) * 0.55), 1.0)
	draw_set_transform(Vector2.ZERO)

func _draw_bird_bath(phase: float) -> void:
	var weather := GameManager.weather_system
	if GameManager.current_hour >= 18.0 or (is_instance_valid(weather) and weather.is_raining()):
		return
	var visit := fposmod(phase, 16.0)
	if visit > 8.0:
		return
	# A little robin pauses on the lip, dips its head, then leaves between visits.
	var p := Vector2(10.0, -23.0)
	var dip := maxf(0.0, sin(visit * 2.4)) * 3.0
	draw_line(p + Vector2(0, 4), p + Vector2(0, 7), Color("655140"), 1.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(2, 0), p + Vector2(8, -2), p + Vector2(4, 3)]), Color("746858"))
	draw_circle(p, 4.0, Color("81775f"))
	draw_circle(p + Vector2(-1, 1), 2.5, Color("d88653"))
	draw_circle(p + Vector2(-3, -3 + dip), 2.5, Color("9a8868"))
	draw_line(p + Vector2(-4, -2 + dip), p + Vector2(-7, -1 + dip), Color("ddb86e"), 1.0)
	draw_circle(p + Vector2(-4, -3 + dip), 0.65, Color("282f29"))

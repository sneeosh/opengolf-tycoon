extends Node2D
class_name ClubhouseTerrace
## An animated forecourt contained entirely within the clubhouse footprint.
var footprint := Vector2(256, 128)
var level := 1
var _time := 0.0
var _redraw := 0.0

func _process(delta: float) -> void:
	if GameManager.is_paused or GameManager.current_speed == GameManager.GameSpeed.PAUSED:
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	_time += real_delta
	_redraw += real_delta
	if _redraw >= 0.1:
		_redraw = 0.0
		queue_redraw()

func _draw() -> void:
	var grid := GameManager.terrain_grid
	if grid and not grid.get_visible_world_rect().grow(256).has_point(global_position):
		return
	var bottom := footprint.y - 5.0
	# Furniture stays in the side bays; the center entrance remains open.
	for side in [25.0, footprint.x - 25.0]:
		var seat := Vector2(side, bottom - 8)
		_draw_table(seat, side > footprint.x * 0.5)
		if level >= 2:
			_draw_umbrella(seat + Vector2(0, -4), side > footprint.x * 0.5)
	for side in [8.0, footprint.x - 8.0]:
		var p := Vector2(side, bottom - 36)
		draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 8)), Color("826046"))
		for i in range(3):
			draw_circle(p + Vector2(i * 4 - 4, -7), 4, Color("4b703e"))
			draw_circle(p + Vector2(i * 4 - 4, -9), 1.5, Color("e6b7aa"))
	# Bags by the door, with small club heads catching the light.
	for i in range(2 + level):
		var p := Vector2(footprint.x * 0.5 + 36 + i * 7, bottom - 3)
		draw_line(p + Vector2(-2, 1), p + Vector2(3, 1), Color(0.1, 0.2, 0.13, 0.25), 2)
		draw_rect(Rect2(p - Vector2(2, 12), Vector2(5, 12)), Color("79493f") if i % 2 == 0 else Color("335c54"))
		for club in range(2):
			var top := p + Vector2(club * 3 - 1, -18 - club * 2)
			draw_line(p + Vector2(club, -10), top, Color("bcbca6"), 1)
			draw_line(top, top + Vector2(2, 0), Color("e1dfc3"), 2)
	var weather := GameManager.weather_system
	var open := GameManager.current_hour >= 7 and GameManager.current_hour < 19
	if open and not (is_instance_valid(weather) and weather.is_raining()):
		# Cosmetic clubhouse staff: bounded to the entrance, never simulated golfers.
		var t := _time * 0.4
		var p := Vector2(footprint.x * 0.5 - 22 + sin(t) * 14, bottom - 3)
		_draw_person(p, Color("f0e1b4"), sin(_time * 5.0) * 1.2)
		if level >= 2:
			_draw_person(Vector2(17, bottom - 7), Color("839fba"), 0)
		if level >= 3:
			_draw_person(Vector2(footprint.x - 17, bottom - 7), Color("c78e83"), 0)

func _draw_table(p: Vector2, right: bool) -> void:
	draw_line(p + Vector2(0, -7), p, Color("4f5e4a"), 2)
	for x in [-9, 9]:
		draw_line(p + Vector2(x, -4), p + Vector2(x, 1), Color("52604c"), 2)
		draw_line(p + Vector2(x - 3, -5), p + Vector2(x + 3, -5), Color("bc9966"), 2)
	draw_set_transform(p + Vector2(0, -8), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 9, Color("d4bc88"))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(p + Vector2(-3 if right else 2, -11), Vector2(2, 3)), Color("faf1d7"))

func _draw_umbrella(p: Vector2, right: bool) -> void:
	draw_line(p, p + Vector2(0, -25), Color("8f8060"), 1)
	var top := p + Vector2(0, -28)
	var edges := [Vector2(-18, 5), Vector2(-9, 11), Vector2(9, 11), Vector2(18, 5)]
	for i in range(3):
		var color := Color("e3d3a2") if i % 2 == 0 else Color("497362")
		if right and i % 2 == 1:
			color = Color("975e4b")
		draw_colored_polygon(PackedVector2Array([top, top + edges[i], top + edges[i + 1]]), color)
	draw_circle(top, 1.5, Color("f0deb0"))

func _draw_person(p: Vector2, shirt: Color, step: float) -> void:
	draw_line(p + Vector2(-3, 1), p + Vector2(4, 1), Color(0.1, 0.15, 0.1, 0.25), 2)
	draw_line(p + Vector2(-2, -4), p + Vector2(-2, step), Color("455046"), 2)
	draw_line(p + Vector2(2, -4), p + Vector2(2, -step), Color("455046"), 2)
	draw_rect(Rect2(p + Vector2(-3, -11), Vector2(6, 7)), shirt)
	draw_circle(p + Vector2(0, -14), 3, Color("d8b28a"))
	draw_line(p + Vector2(-3, -16), p + Vector2(4, -16), Color("f0e9cd"), 2)

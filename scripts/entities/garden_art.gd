extends Node2D
class_name GardenArt
## Hand-built miniature garden pieces. The same draw routine powers placement and catalogs.
const KINDS := ["rose_border", "lavender_bed", "hydrangea", "clipped_hedge", "rose_arch", "pergola", "picnic_table", "patio_table", "garden_lamp", "stone_wall", "picket_fence", "terracotta_planters", "lily_pool", "rock_garden", "course_clock", "viewing_deck"]
var kind := "rose_border"

func _draw() -> void:
	draw_piece(self, kind)

static func has_art(type: String) -> bool:
	return type in KINDS

static func poly(c: CanvasItem, pts: Array, color: String) -> void:
	c.draw_colored_polygon(PackedVector2Array(pts), Color(color))

static func line(c: CanvasItem, a: Vector2, b: Vector2, color: String, width := 1.0) -> void:
	c.draw_line(a, b, Color(color), width, true)

static func oval(c: CanvasItem, p: Vector2, radius: Vector2, color: String) -> void:
	var pts := PackedVector2Array()
	for i in range(24):
		var angle := TAU * i / 24.0
		pts.append(p + Vector2(cos(angle), sin(angle)) * radius)
	c.draw_colored_polygon(pts, Color(color))

static func bloom(c: CanvasItem, p: Vector2, color: String) -> void:
	c.draw_circle(p, 2.7, Color("385a36"))
	for i in range(4):
		var a := i * TAU / 4.0
		c.draw_circle(p + Vector2(cos(a), sin(a)) * 1.6, 1.6, Color(color))
	c.draw_circle(p, .8, Color("f8d98a"))

static func post(c: CanvasItem, p: Vector2, height: float, color := "e6d8ae") -> void:
	line(c, p, p - Vector2(0, height), "6c6348", 4)
	line(c, p - Vector2(1, 0), p - Vector2(1, height), color, 2)

static func draw_piece(c: CanvasItem, type: String) -> void:
	oval(c, Vector2(2, 1), Vector2(25, 8), "263b303c")
	match type:
		"rose_border", "lavender_bed", "hydrangea":
			poly(c, [Vector2(-27,-7),Vector2(20,-7),Vector2(27,5),Vector2(-20,5)], "bd9c73")
			poly(c, [Vector2(-24,-7),Vector2(19,-7),Vector2(24,2),Vector2(-19,2)], "574d35")
			for i in range(13):
				var p := Vector2(-21+(i%7)*6, -5+(i/7)*5)
				var flower := "e7a7b5" if type == "rose_border" else "b7a4e4"
				if type == "hydrangea":
					oval(c,p-Vector2(0,4),Vector2(6,5),"487448")
					bloom(c,p-Vector2(0,8),"b6cce7")
				elif type == "lavender_bed":
					for dx in [-2,0,2]:
						line(c,p+Vector2(dx,0),p+Vector2(dx-1,-10-i%3),"7b9161")
						line(c,p+Vector2(dx-1,-6),p+Vector2(dx-1,-11-i%3),flower,2)
				else:
					bloom(c,p-Vector2(0,5+i%3),flower)
		"clipped_hedge":
			poly(c,[Vector2(-26,1),Vector2(24,1),Vector2(27,-15),Vector2(-22,-15)],"365b35")
			poly(c,[Vector2(-26,-12),Vector2(23,-12),Vector2(27,-19),Vector2(-21,-19)],"78964e")
			for i in range(14):
				c.draw_circle(Vector2(-23+i*3.5,-8-(i%3)*2),1.7,Color("527b40"))
		"rose_arch":
			for x in [-21,21]:
				post(c,Vector2(x,0),35)
				for y in range(7,34,8):
					bloom(c,Vector2(x+sin(y)*3,-y),"e7a0ac")
			var pts := PackedVector2Array()
			for i in range(17):
				var a := PI + PI * i / 16.0
				pts.append(Vector2(cos(a)*21,-34+sin(a)*12))
			c.draw_polyline(pts,Color("e6d8ae"),3,true)
			for i in range(1,16,3): bloom(c,pts[i],"dca3ba")
		"pergola":
			for x in [-22,22]:
				for y in [-9,6]: post(c,Vector2(x,y),32)
			for y in range(-42,-21,4): line(c,Vector2(-28,y),Vector2(27,y+4),"c4ab78",3)
			for x in range(-23,26,8): line(c,Vector2(x,-44),Vector2(x+5,-22),"e3cda0",2)
			for x in [-22,22]:
				for y in range(8,30,7): bloom(c,Vector2(x,-y),"bcafd9")
		"picnic_table", "patio_table":
			if type == "picnic_table":
				for x in [-15,15]:
					line(c,Vector2(x-5,3),Vector2(x+3,-15),"655641",3)
					line(c,Vector2(x+5,3),Vector2(x-3,-15),"655641",3)
				for y in [-5,5]:
					poly(c,[Vector2(-26,y-6),Vector2(22,y-6),Vector2(27,y-2),Vector2(-21,y-2)],"b98956")
				poly(c,[Vector2(-23,-18),Vector2(18,-18),Vector2(24,-10),Vector2(-17,-10)],"d0a16d")
				line(c,Vector2(-20,-15),Vector2(20,-15),"987049")
			else:
				post(c,Vector2.ZERO,17,"a9956b")
				oval(c,Vector2(0,-14),Vector2(18,8),"e8dcc0")
				for x in [-23,23]:
					post(c,Vector2(x,3),12,"688365")
					oval(c,Vector2(x,-8),Vector2(7,4),"9aaa79")
				post(c,Vector2(0,-14),25,"c5b994")
				poly(c,[Vector2(-28,-32),Vector2(0,-49),Vector2(28,-32),Vector2(0,-26)],"e1c17d")
				poly(c,[Vector2(-28,-32),Vector2(0,-49),Vector2(0,-26)],"fbebc2")
		"garden_lamp":
			post(c,Vector2.ZERO,40,"40534a")
			c.draw_rect(Rect2(-5,-48,10,11),Color("f4e0a0"))
			poly(c,[Vector2(-7,-48),Vector2(0,-54),Vector2(7,-48)],"3c5549")
			for x in [-5,0,5]: line(c,Vector2(x,-48),Vector2(x,-37),"3c5549")
			line(c,Vector2(-6,-37),Vector2(6,-37),"3c5549",2)
		"stone_wall":
			c.draw_rect(Rect2(-27,-15,53,18),Color("8f947d"))
			for row in range(3):
				for col in range(6):
					var x := -27+col*9+(row%2)*3
					c.draw_rect(Rect2(x,-14+row*5,8,4),Color("b9b49a" if col%2 else "c7c2a8"))
			poly(c,[Vector2(-28,-15),Vector2(24,-15),Vector2(28,-19),Vector2(-24,-19)],"d4cdb3")
		"picket_fence":
			for y in [-7,-18]: line(c,Vector2(-26,y),Vector2(26,y),"bfb68e",3)
			for x in range(-25,27,7):
				poly(c,[Vector2(x-2,0),Vector2(x-2,-22),Vector2(x,-26),Vector2(x+2,-22),Vector2(x+2,0)],"f0e6c7")
		"terracotta_planters":
			for x in [-15,15]:
				poly(c,[Vector2(x-9,-12),Vector2(x+9,-12),Vector2(x+6,1),Vector2(x-6,1)],"b87755")
				oval(c,Vector2(x,-12),Vector2(10,4),"dfaa74")
				for i in range(5): bloom(c,Vector2(x-6+i*3,-16-i%2*4),"f4d083")
		"lily_pool":
			oval(c,Vector2.ZERO,Vector2(28,12),"bfb899")
			oval(c,Vector2(0,-2),Vector2(24,9),"396e69")
			oval(c,Vector2(0,-3),Vector2(21,7),"72b5ac")
			for p in [Vector2(-12,-3),Vector2(9,-1),Vector2(3,-6)]:
				oval(c,p,Vector2(5,2.5),"5d894d")
				bloom(c,p-Vector2(0,2),"efe8c7")
		"rock_garden":
			oval(c,Vector2.ZERO,Vector2(27,10),"b9ae86")
			for i in range(5):
				var p := Vector2(-19+i*9,-2-i%2*5)
				poly(c,[p+Vector2(-7,2),p+Vector2(-5,-7),p+Vector2(2,-13),p+Vector2(7,-4),p+Vector2(6,3)],"858d7a")
				poly(c,[p+Vector2(-5,-7),p+Vector2(2,-13),p+Vector2(7,-4)],"c8c7ac")
				bloom(c,p+Vector2(2,2),"d2b4d2")
		"course_clock":
			post(c,Vector2.ZERO,38,"365645")
			c.draw_circle(Vector2(0,-39),11,Color("355847"))
			c.draw_circle(Vector2(0,-39),8.5,Color("f4e8bc"))
			line(c,Vector2(0,-39),Vector2(0,-45),"475746",2)
			line(c,Vector2(0,-39),Vector2(5,-37),"475746",2)
			for i in range(12):
				var a := TAU*i/12.0
				c.draw_circle(Vector2(0,-39)+Vector2(cos(a),sin(a))*7,0.7,Color("475746"))
		"viewing_deck":
			poly(c,[Vector2(-28,-9),Vector2(23,-9),Vector2(29,6),Vector2(-22,6)],"ad895b")
			for y in range(-7,7,3): line(c,Vector2(-26,y),Vector2(24,y),"d1ac77")
			for x in [-24,0,24]: post(c,Vector2(x,-8),17)
			line(c,Vector2(-24,-25),Vector2(24,-25),"e4d5aa",3)

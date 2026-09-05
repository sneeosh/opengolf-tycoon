extends Node2D
class_name CourseArchitecture
## Shared, footprint-relative architecture for built structures and placement ghosts.
## Horizontal facades, a consistent receding depth, and fixed door heights keep
## every facility in the same miniature world. Upgrades extend the facade with new bays, retaining door and window scale.
var kind := "clubhouse"
var footprint := Vector2(256, 128)
var level := 1
var clock := 0.0
var redraw_elapsed := 0.0

func _process(delta: float) -> void:
	if not GameManager.is_paused:
		clock += delta
	redraw_elapsed += delta
	if redraw_elapsed >= 0.1:
		redraw_elapsed = 0.0
		queue_redraw()

func _draw() -> void:
	draw_building(self, kind, footprint, level, clock, GameManager.current_hour)

static func body_width(kind_name: String, size: Vector2, tier: int) -> float:
	if kind_name == "clubhouse":
		return 138.0 + 28.0 * (clampi(tier, 1, 3) - 1)
	return size.x - 36.0 if size.x > 64 else 36.0

static func poly(c: CanvasItem, points: Array, col: String) -> void:
	c.draw_colored_polygon(PackedVector2Array(points), Color(col))

static func rect(c: CanvasItem, x: float, y: float, w: float, h: float, col: String) -> void:
	c.draw_rect(Rect2(x, y, w, h), Color(col))

static func line(c: CanvasItem, a: Vector2, b: Vector2, col: String, width := 1.0) -> void:
	c.draw_line(a, b, Color(col), width)

static func window(c: CanvasItem, x: float, y: float, wide: float, night: bool) -> void:
	rect(c, x - 3, y - 2, wide + 6, 18, "b4a982")
	rect(c, x, y, wide, 13, "eecf85" if night else "577b7a")
	rect(c, x + 1, y + 1, wide - 2, 4, "ffe7a9" if night else "8faeaa")
	rect(c, x + wide / 2 - .5, y, 1, 13, "ece0bd")
	rect(c, x, y + 6, wide, 1, "ece0bd")
	rect(c, x - 4, y + 14, wide + 8, 2, "f5e8c6")
	for side in [-1, 1]:
		var sx: float = x - 7 if side == -1 else x + wide + 2
		rect(c, sx, y, 4, 13, "345d49")
		for yy in range(2, 12, 3):
			line(c, Vector2(sx, y + yy), Vector2(sx + 4, y + yy), "53775a")

static func planter(c: CanvasItem, p: Vector2, wide := 15.0) -> void:
	poly(c, [p + Vector2(-wide/2, -5), p + Vector2(wide/2, -5), p + Vector2(wide/2-2, 2), p + Vector2(-wide/2+2, 2)], "a56c4c")
	rect(c, p.x-wide/2-1, p.y-6, wide+2, 2, "c78d61")
	for i in range(5):
		var q := p + Vector2(-wide/2+2+i*(wide-4)/4, -8 - (i%2)*2)
		c.draw_circle(q, 3, Color("527442"))
		c.draw_circle(q+Vector2(0,-2), 1.5, Color("e9ae88" if i%2 else "efe2a6"))

static func lantern(c: CanvasItem, p: Vector2, night: bool) -> void:
	# Bracket and glass stay attached to the wall, even during evening glow.
	if night:
		c.draw_circle(p + Vector2(0, 3), 8, Color(1, .78, .35, .08))
		c.draw_circle(p + Vector2(0, 3), 5, Color(1, .82, .43, .12))
	line(c, p + Vector2(-3, -3), p + Vector2(0, -3), "46513d", 2)
	line(c, p + Vector2(0, -3), p, "46513d")
	rect(c, p.x - 2, p.y, 4, 6, "eacb79" if night else "b9c2a2")
	poly(c, [p+Vector2(-3,0),p+Vector2(0,-2),p+Vector2(3,0)], "43523d")
	line(c,p+Vector2(-2,6),p+Vector2(2,6),"43523d")
	line(c,p,p+Vector2(0,6),"6b7150")

static func porch_seat(c: CanvasItem, p: Vector2) -> void:
	# Short wooden seat tucked behind the veranda rail, at human scale.
	for row in range(3):
		rect(c,p.x,p.y-9+row*2,17,1,"8c6847")
	poly(c,[p+Vector2(0,-3),p+Vector2(17,-3),p+Vector2(19,0),p+Vector2(2,0)],"ab8357")
	for dx in [3,15]:
		line(c,p+Vector2(dx,0),p+Vector2(dx,4),"5d6549",2)

static func climbing_rose(c: CanvasItem, p: Vector2, height: float) -> void:
	# Sparse climbing stems expose the siding and never cover the doorway.
	for i in range(int(height/4)):
		var q := p+Vector2(sin(i*1.8)*2,-i*4)
		line(c,q+Vector2(0,4),q,"536642")
		c.draw_circle(q+Vector2(-2 if i%2 else 2,-1),2,Color("73854f"))
		if i%3 == 1:
			c.draw_circle(q+Vector2(2,-2),2,Color("d69b82"))
			c.draw_circle(q+Vector2(2,-2),.7,Color("efd5a1"))

static func house(c: CanvasItem, x: float, base: float, w: float, tall: float, depth: float, night: bool, bays: bool = false) -> void:
	var d := Vector2(-depth * .55, -depth * .5)
	var e := base-tall
	# Masonry mass, grounded foundation and shaded west return.
	poly(c, [Vector2(x,base),Vector2(x, e),Vector2(x,e)+d,Vector2(x,base)+d], "b6ad87")
	for yy in range(int(e)+5, int(base)-4, 5):
		line(c, Vector2(x,yy)+d,Vector2(x,yy),"a79f7e")
	var sw := Vector2(x,e+16)+d*.65
	poly(c,[sw,sw-d*.35,sw-d*.35+Vector2(0,12),sw+Vector2(0,12)],"526f66")
	line(c,sw+Vector2(0,6),sw-d*.35+Vector2(0,6),"d9cba6")
	rect(c, x, e, w, tall, "e7dbb7")
	for yy in range(int(e)+5, int(base)-4, 5):
		line(c, Vector2(x+1,yy),Vector2(x+w-1,yy),"d9cda9")
	rect(c, x, base-5, w, 5, "a39476")
	rect(c, x, e, w, 4, "a69c7d")
	rect(c, x+2, e+4, 3, tall-9, "f5e9c8")
	rect(c, x+w-5, e+4, 3, tall-9, "f5e9c8")
	if bays:
		for bx in range(int(x)+9,int(x+w)-26,32):
			rect(c,bx,e+9,25,tall-13,"455b48")
			rect(c,bx+2,e+12,21,tall-16,"304638")
			rect(c,bx-2,e+6,29,3,"f3e5bf")
	else:
		for distance in [24.0, 50.0, 76.0, 102.0]:
			for direction in [-1.0, 1.0]:
				var wx: float = x+w*.5+distance*direction-5
				if wx >= x+12 and wx+10 <= x+w-12:
					window(c,wx,e+12,10,night)
		var door := x+w*.5-7
		rect(c,door-3,base-27,20,27,"f5e9c8")
		rect(c,door,base-25,14,25,"345843")
		rect(c,door+3,base-22,8,8,"e7c77f" if night else "8caaa0")
		rect(c,door+3,base-11,8,8,"456a50")
		c.draw_circle(Vector2(door+11,base-12),1,Color("d5b369"))
	# Gabled roof: ridge follows the facade; both planes share the same depth.
	var left := Vector2(x-5,e-1)
	var right := Vector2(x+w+5,e-1)
	var ridge := d*.5+Vector2(0,-15)
	poly(c,[left+d,right+d,right+ridge,left+ridge],"755943")
	poly(c,[left,left+ridge,right+ridge,right],"a46d4b")
	poly(c,[left,left+d,left+ridge],"c7b38c")
	for row in range(1,5):
		var t := row/5.0
		line(c,left.lerp(left+ridge,t),right.lerp(right+ridge,t),"ba8057")
		for col in range(8,int(w),12):
			var a := left+Vector2(col+(row%2)*5,0)+ridge*t
			line(c,a,a+ridge*.17,"8b6047")
	line(c,left+ridge,right+ridge,"d3a076",2)
	line(c,left,right,"654f3c",3)
	line(c,left+Vector2(0,2),right+Vector2(0,2),"f0dfb9",2)

static func draw_building(c: CanvasItem, kind_name: String, size: Vector2, tier := 1, time := 0.0, hour := 10.0) -> void:
	if kind_name == "bench":
		c.draw_set_transform(Vector2(size.x*.5,size.y*.7))
		PathFurniture.draw_item(c,"park_bench",Vector2i.DOWN)
		c.draw_set_transform(Vector2.ZERO)
		return
	var club := kind_name == "clubhouse"
	var night := hour >= 17 or hour < 6
	var w := body_width(kind_name,size,tier)
	var x := (size.x-w)*.5
	var base := size.y-25 if club or kind_name == "restaurant" else size.y-15
	var tall := 46.0 if size.x > 64 else 33.0
	var depth := 35.0 if size.x > 64 else 20.0
	var roof_base := base-tall
	# A modest apron follows the facade; its back edge sits under the walls.
	poly(c,[Vector2(x-10,base-12),Vector2(x+w+4,base-12),Vector2(x+w+13,base+17),Vector2(x-2,base+17)],"b7ab87")
	poly(c,[Vector2(x-9,base-12),Vector2(x+w+3,base-12),Vector2(x+w+11,base+14),Vector2(x-1,base+14)],"d4c8a4")
	for j in range(int(x),int(x+w),18):
		line(c,Vector2(j,base+2),Vector2(j+4,base+13),"c0b38f")
	# Mass-shaped contact shadow, never a detached oval under the terrace.
	poly(c,[Vector2(maxf(1,x-20),base-20),Vector2(x+w,base-5),Vector2(x+w+13,base+6),Vector2(x-1,base+6)],"78816a")
	house(c,x,base,w,tall,depth,night,kind_name in ["cart_shed","driving_range"])
	if club or kind_name == "restaurant":
		# Brick chimney rises out of the rear roof plane.
		var chimney := Vector2(x+w-27,roof_base-22)
		rect(c,chimney.x,chimney.y-15,9,20,"956c52")
		rect(c,chimney.x+6,chimney.y-15,3,20,"72563f")
		for j in range(3):
			line(c,chimney+Vector2(0,-11+j*5),chimney+Vector2(8,-11+j*5),"c09771")
		rect(c,chimney.x-2,chimney.y-17,13,3,"d0b68d")
		if hour >= 6 and hour < 20:
			for j in range(3):
				var t := fmod(time*.22+j/3.0,1.0)
				c.draw_circle(chimney+Vector2(4+sin(t*3)*5,-20-t*22),2+t*3,Color(.91,.9,.81,(1-t)*.28))
		# Recessed porch floor and shadow make the rail sit in front of the wall.
		rect(c,x+7,base-16,w-13,17,"b8b08c")
		rect(c,x+w*.5-10,base-16,20,16,"f0dfb9")
		rect(c,x+w*.5-7,base-16,14,16,"345843")
		c.draw_circle(Vector2(x+w*.5+4,base-12),1,Color("d5b369"))
		poly(c,[Vector2(x+7,base),Vector2(x+w-6,base),Vector2(x+w+1,base+5),Vector2(x+12,base+5)],"a99571")
		porch_seat(c,Vector2(x+22,base))
		if club:
			porch_seat(c,Vector2(x+w-40,base))
		else:
			# A tiny bistro table with a folded napkin, sheltered by the roof.
			var tx := x+w-30
			line(c,Vector2(tx,base-4),Vector2(tx,base+3),"566048",2)
			poly(c,[Vector2(tx-8,base-5),Vector2(tx,base-8),Vector2(tx+8,base-5),Vector2(tx,base-2)],"e8dabc")
			rect(c,tx-2,base-6,3,2,"f6ebcf")
		# An attached veranda, with a clear central entrance and planted ends.
		var py := base-18
		poly(c,[Vector2(x+5,py-5),Vector2(x+w-5,py-5),Vector2(x+w+1,py+3),Vector2(x+11,py+3)],"496a4b")
		line(c,Vector2(x+11,py+3),Vector2(x+w+1,py+3),"e8dbb7",3)
		# A small entrance gable breaks the long canopy and marks the front door.
		var entry := x+w*.5
		poly(c,[Vector2(entry-21,py+3),Vector2(entry,py-10),Vector2(entry+21,py+3)],"ded0ac")
		poly(c,[Vector2(entry-22,py+1),Vector2(entry,py-13),Vector2(entry+23,py+1),Vector2(entry+20,py+3),Vector2(entry,py-9),Vector2(entry-19,py+3)],"385c42")
		line(c,Vector2(entry-18,py+4),Vector2(entry+19,py+4),"f0e1bf",2)
		for px in [x+13,x+w*.5-17,x+w*.5+17,x+w-2]:
			rect(c,px+3,py+5,2,18,"918b6b")
			rect(c,px,py+4,3,20,"f0e3bf")
			rect(c,px-1,base+3,5,3,"a99d7b")
		for side in [0,1]:
			var start := x+15 if side == 0 else x+w*.5+20
			var end := x+w*.5-19 if side == 0 else x+w-3
			line(c,Vector2(start,base-4),Vector2(end,base-4),"ede0bc",2)
			for p in range(int(start),int(end),7):
				line(c,Vector2(p,base-4),Vector2(p,base+3),"d4c6a0",2)
		rect(c,x+w*.5-15,base+5,30,3,"b3a487")
		rect(c,x+w*.5-18,base+8,36,3,"e4d4ae")
		lantern(c,Vector2(x+w*.5-12,base-12),night)
		lantern(c,Vector2(x+w*.5+12,base-12),night)
		climbing_rose(c,Vector2(x+9,base+3),26)
		planter(c,Vector2(x+6,base+10))
		planter(c,Vector2(x+w-4,base+10))
		if club:
			# Small central dormer and clock make the clubhouse recognizable.
			var cx := x+w*.5
			rect(c,cx-10,roof_base-16,20,14,"eee0bd")
			poly(c,[Vector2(cx-14,roof_base-16),Vector2(cx,roof_base-27),Vector2(cx+14,roof_base-16)],"5b6b49")
			c.draw_circle(Vector2(cx,roof_base-9),5,Color("fcf0ce"))
			line(c,Vector2(cx,roof_base-9),Vector2(cx,roof_base-12),"5e6249")
			line(c,Vector2(cx,roof_base-9),Vector2(cx+3,roof_base-8),"5e6249")
			if tier >= 2:
				rect(c,x+15,base-13,24,5,"294b39")
				line(c,Vector2(x+19,base-11),Vector2(x+35,base-11),"dfc888")
	else:
		planter(c,Vector2(x+w-3,base+5),10)
		if kind_name == "snack_bar" or kind_name == "pro_shop":
			var aw := w-8
			for j in range(0,int(aw),6):
				poly(c,[Vector2(x+4+j,base-23),Vector2(x+10+j,base-23),Vector2(x+13+j,base-17),Vector2(x+7+j,base-17)],"eadbbb" if j%12 == 0 else "54734d")
		if kind_name == "restroom":
			rect(c,x+w*.5-6,base-29,12,5,"3c604a")
			for dx in [-2,2]:
				c.draw_circle(Vector2(x+w*.5+dx,base-27),1,Color("eee1bf"))
		if kind_name in ["cart_shed","driving_range"]:
			for bx in range(int(x)+12,int(x+w)-23,32):
				if kind_name == "cart_shed":
					rect(c,bx,base-9,18,6,"d8d4ae")
					rect(c,bx-2,base-17,21,3,"b8c4a1")
					for dx in [1,14]:
						line(c,Vector2(bx+dx,base-14),Vector2(bx+dx,base-8),"71816a")
						c.draw_circle(Vector2(bx+dx,base-2),2,Color("39483b"))
				else:
					rect(c,bx,base-3,18,7,"577a4a")
					c.draw_circle(Vector2(bx+11,base),1,Color("fff0ca"))

	# Individual landmarks distinguish facilities without changing their scale.
	if club and tier == 3:
		for dx in [-52,52]:
			var cx: float = x+w*.5+dx
			rect(c,cx-7,roof_base-14,14,12,"e8dab6")
			rect(c,cx-4,roof_base-12,8,8,"eecf85" if night else "739489")
			line(c,Vector2(cx,roof_base-12),Vector2(cx,roof_base-4),"f3e6c4")
			poly(c,[Vector2(cx-10,roof_base-14),Vector2(cx,roof_base-21),Vector2(cx+10,roof_base-14)],"576c49")
	if kind_name == "restaurant":
		rect(c,x+w*.5-15,base-38,30,8,"38583e")
		for dx in [-5,5]:
			line(c,Vector2(x+w*.5+dx,base-36),Vector2(x+w*.5+dx,base-32),"e1c98f",1)
		c.draw_circle(Vector2(x+w*.5,base-34),2,Color("e1c98f"))
	if kind_name == "snack_bar":
		rect(c,x+5,base-16,w-10,16,"e5d8b3")
		rect(c,x+7,base-16,w-14,9,"3e5645")
		rect(c,x+4,base-7,w-8,3,"916b48")
		for dx in [11,18]:
			rect(c,x+dx,base-11,3,4,"efdfb8")

	if kind_name == "pro_shop":
		var badge := Vector2(x+w*.5,base-33)
		c.draw_circle(badge,6,Color("355840"))
		line(c,badge+Vector2(-3,3),badge+Vector2(3,-3),"ddc58d")
		line(c,badge+Vector2(3,3),badge+Vector2(-3,-3),"ddc58d")
		c.draw_circle(badge,2,Color("f3e7c5"))
	if club and tier >= 2:
		# A pennant above the clock makes the growing clubhouse easy to find.
		var mast := Vector2(x+w*.5,roof_base-28)
		line(c,mast,mast+Vector2(0,-18),"c9b98f",1)
		var flutter := sin(time*2.8)*1.5
		poly(c,[mast+Vector2(1,-18),mast+Vector2(13,-16+flutter),mast+Vector2(1,-11)],"d6b967")
		c.draw_circle(mast+Vector2(0,-19),1.2,Color("efdb9f"))

	facility_details(c,kind_name,x,base,w,roof_base,night)

static func chalkboard(c: CanvasItem, p: Vector2, wide := 10.0) -> void:
	line(c,p+Vector2(-1,1),p+Vector2(2,-13),"816443",2)
	line(c,p+Vector2(wide+2,1),p+Vector2(wide-1,-13),"816443",2)
	rect(c,p.x,p.y-12,wide,11,"b18a5b")
	rect(c,p.x+1,p.y-11,wide-2,8,"365145")
	for row in range(3):
		line(c,p+Vector2(3,-9+row*2),p+Vector2(wide-2-row%2*2,-9+row*2),"d6d4ad")

static func golf_bag(c: CanvasItem, p: Vector2) -> void:
	poly(c,[p+Vector2(-3,-11),p+Vector2(3,-12),p+Vector2(4,0),p+Vector2(-2,1)],"915d47")
	line(c,p+Vector2(-1,-10),p+Vector2(0,0),"c69667",2)
	for i in range(3):
		var q := p+Vector2(-2+i*2,-10)
		line(c,q,q+Vector2(-1,-6-i%2*2),"a6b4ab")
		line(c,q+Vector2(-1,-6-i%2*2),q+Vector2(2,-6-i%2*2),"d5d9c4",2)

static func facility_details(c: CanvasItem, type: String, x: float, base: float, w: float, eaves: float, night: bool) -> void:
	match type:
		"pro_shop":
			# Merchandise behind the glass and a bag stand beside the clear door.
			for side in [-1,1]:
				var wx: float = x+w*.5+24*side
				poly(c,[Vector2(wx-3,eaves+17),Vector2(wx-1,eaves+15),Vector2(wx+1,eaves+15),Vector2(wx+3,eaves+17),Vector2(wx+2,eaves+19),Vector2(wx+1,eaves+18),Vector2(wx+1,eaves+23),Vector2(wx-1,eaves+23),Vector2(wx-1,eaves+18),Vector2(wx-2,eaves+19)],"d2ba76" if side == -1 else "b7cebd")
			golf_bag(c,Vector2(x+13,base+4))
			golf_bag(c,Vector2(x+21,base+5))
			chalkboard(c,Vector2(x+w-20,base+8))
			lantern(c,Vector2(x+w*.5+13,base-16),night)
			climbing_rose(c,Vector2(x+3,base),29)
			planter(c,Vector2(x+22,eaves+30),16)
		"restaurant":
			chalkboard(c,Vector2(x+w-18,base+11),11)
			# Window boxes add dining-room warmth above the veranda roof.
			for dx in [-50,50]:
				planter(c,Vector2(x+w*.5+dx,eaves+31),16)
		"snack_bar":
			# Wall menu and a cup badge identify this as a refreshment hut.
			rect(c,x+1,base-16,6,10,"b99160")
			rect(c,x+2,base-15,4,8,"395b48")
			for row in range(3):
				line(c,Vector2(x+3,base-13+row*2),Vector2(x+5,base-13+row*2),"ebd6a0")
			var cx := x+w*.5
			rect(c,cx-6,eaves+4,12,6,"3f6147")
			rect(c,cx-2,eaves+5,4,3,"f2e0b7")
			c.draw_arc(Vector2(cx+2,eaves+6),1, -PI*.5,PI*.5,5,Color("f2e0b7"))
			line(c,Vector2(cx-4,base-3),Vector2(cx-4,base+2),"aa9877")
			line(c,Vector2(cx+4,base-3),Vector2(cx+4,base+2),"aa9877")
			climbing_rose(c,Vector2(x+w-2,base),20)
			lantern(c,Vector2(x+w-2,base-22),night)
		"restroom":
			# A modest sheltered threshold and garden trellis suit the small footprint.
			var cx := x+w*.5
			poly(c,[Vector2(cx-12,base-25),Vector2(cx,base-32),Vector2(cx+12,base-25)],"4c6c4d")
			line(c,Vector2(cx-12,base-24),Vector2(cx+12,base-24),"f0dfb9",2)
			rect(c,cx-9,base+1,18,3,"b8aa87")
			rect(c,cx-11,base+4,22,2,"e3d2ab")
			for yy in range(0,25,5):
				line(c,Vector2(x+1,base-yy),Vector2(x+8,base-yy-3),"a3946e")
			climbing_rose(c,Vector2(x+5,base),27)
			lantern(c,Vector2(x+w-5,base-19),night)
		"cart_shed":
			# Louvered roof vent, cross-braced posts, equipment hooks and wheel stops.
			var cx := x+w*.5
			rect(c,cx-9,eaves-18,18,13,"ddceaa")
			for row in range(4):
				rect(c,cx-6,eaves-15+row*2,12,1,"718367")
			poly(c,[Vector2(cx-12,eaves-18),Vector2(cx,eaves-25),Vector2(cx+12,eaves-18)],"526a49")
			for bx in range(int(x)+12,int(x+w)-23,32):
				line(c,Vector2(bx-5,eaves+7),Vector2(bx+2,eaves+14),"b9aa84",2)
				rect(c,bx,base+5,19,2,"ad9e7c")
				# Steering wheel, seat back and headlights on each parked cart.
				c.draw_arc(Vector2(bx+12,base-10),2,0,TAU,8,Color("425743"))
				rect(c,bx+2,base-12,6,3,"97815b")
				for dx in [2,14]:
					rect(c,bx+dx,base-7,2,2,"f3df9e")
			lantern(c,Vector2(x+w-9,eaves+12),night)
			golf_bag(c,Vector2(x+w-13,base+3))
		"driving_range":
			# Readable timber pavilion with ball baskets and padded dividers.
			for bx in range(int(x)+12,int(x+w)-23,32):
				line(c,Vector2(bx-5,eaves+8),Vector2(bx+3,eaves+16),"bcae85",2)
				line(c,Vector2(bx+20,eaves+8),Vector2(bx+13,eaves+16),"bcae85",2)
				line(c,Vector2(bx-2,base-1),Vector2(bx+2,base+9),"395f45",2)
				poly(c,[Vector2(bx+18,base-4),Vector2(bx+24,base-4),Vector2(bx+23,base+1),Vector2(bx+19,base+1)],"ad9061")
				for dx in [19,21,23]:
					c.draw_circle(Vector2(bx+dx,base-4),.8,Color("f2e8c9"))
				if (bx-int(x)-12)%96 == 0:
					lantern(c,Vector2(bx+22,eaves+13),night)
			var cx := x+w*.5
			rect(c,cx-26,eaves-4,52,10,"31563e")
			for side in [-1,1]:
				line(c,Vector2(cx+side*6,eaves+1),Vector2(cx+side*21,eaves+1),"bdad70")
			c.draw_circle(Vector2(cx,eaves+1),3,Color("eee4bf"))

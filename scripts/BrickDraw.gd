extends RefCounted
class_name BrickDraw
## 程序化繪製塑膠積木／箭頭／棋盤框（原創美術）


static func draw_rounded_rect(ci: CanvasItem, rect: Rect2, color: Color, radius: float, filled: bool = true, width: float = -1.0) -> void:
	if filled:
		ci.draw_rect(rect, color, true)
		# 簡易圓角覆蓋：四角用圓
		var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
		if r > 0.5:
			ci.draw_circle(rect.position + Vector2(r, r), r, color)
			ci.draw_circle(rect.position + Vector2(rect.size.x - r, r), r, color)
			ci.draw_circle(rect.position + Vector2(r, rect.size.y - r), r, color)
			ci.draw_circle(rect.position + Vector2(rect.size.x - r, rect.size.y - r), r, color)
			ci.draw_rect(Rect2(rect.position.x + r, rect.position.y, rect.size.x - 2.0 * r, rect.size.y), color, true)
			ci.draw_rect(Rect2(rect.position.x, rect.position.y + r, rect.size.x, rect.size.y - 2.0 * r), color, true)
	else:
		ci.draw_rect(rect, color, false, width)


static func draw_frame(ci: CanvasItem, outer: Rect2, inset: float, frame_col: Color, shadow_col: Color, recess_col: Color) -> void:
	# soft shadow
	var shadow := outer.grow(6)
	shadow.position += Vector2(0, 8)
	ci.draw_rect(shadow, shadow_col, true)
	# outer plastic
	ci.draw_rect(outer, frame_col, true)
	# highlight rim
	ci.draw_rect(Rect2(outer.position, Vector2(outer.size.x, 6)), frame_col.lightened(0.18), true)
	# recess
	var inner := outer.grow(-inset)
	ci.draw_rect(inner, recess_col, true)
	# inner soft shadow
	ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 10)), Color(0, 0, 0, 0.18), true)
	ci.draw_rect(Rect2(inner.position, Vector2(10, inner.size.y)), Color(0, 0, 0, 0.12), true)


static func draw_cross_cell(ci: CanvasItem, rect: Rect2, yellow: Color) -> void:
	var pad := rect.grow(-1)
	ci.draw_rect(pad, yellow.darkened(0.12), true)
	var raised := pad.grow(-3)
	ci.draw_rect(raised, yellow, true)
	# bevel
	ci.draw_rect(Rect2(raised.position, Vector2(raised.size.x, 4)), yellow.lightened(0.25), true)
	ci.draw_rect(Rect2(raised.position + Vector2(0, raised.size.y - 4), Vector2(raised.size.x, 4)), yellow.darkened(0.18), true)


static func draw_empty_cell(ci: CanvasItem, rect: Rect2, col: Color) -> void:
	var inset := rect.grow(-1.5)
	ci.draw_rect(inset, col, true)


static func draw_wall_cell(ci: CanvasItem, rect: Rect2, col: Color) -> void:
	var inset := rect.grow(-1)
	ci.draw_rect(inset, col, true)
	ci.draw_rect(inset.grow(-4), col.darkened(0.25), true)


static func draw_stud_brick(ci: CanvasItem, rect: Rect2, base: Color, selected: bool = false) -> void:
	var r: float = minf(8.0, minf(rect.size.x, rect.size.y) * 0.22)
	# drop shadow
	var sh := rect
	sh.position += Vector2(2, 3)
	ci.draw_rect(sh, Color(0, 0, 0, 0.28), true)
	# body
	ci.draw_rect(rect, base.darkened(0.08), true)
	var face := rect.grow(-2)
	ci.draw_rect(face, base, true)
	# top/left highlight
	ci.draw_rect(Rect2(face.position, Vector2(face.size.x, 4)), base.lightened(0.28), true)
	ci.draw_rect(Rect2(face.position, Vector2(4, face.size.y)), base.lightened(0.18), true)
	# bottom/right shade
	ci.draw_rect(Rect2(face.position + Vector2(0, face.size.y - 4), Vector2(face.size.x, 4)), base.darkened(0.22), true)
	ci.draw_rect(Rect2(face.position + Vector2(face.size.x - 4, 0), Vector2(4, face.size.y)), base.darkened(0.16), true)
	# circular stud
	var cx := face.position + face.size * 0.5
	var stud_r: float = minf(face.size.x, face.size.y) * 0.22
	ci.draw_circle(cx + Vector2(1, 1.5), stud_r, base.darkened(0.25))
	ci.draw_circle(cx, stud_r, base.lightened(0.12))
	ci.draw_circle(cx - Vector2(stud_r * 0.28, stud_r * 0.28), stud_r * 0.35, Color(1, 1, 1, 0.45))
	ci.draw_arc(cx, stud_r, 0, TAU, 24, base.darkened(0.35), 1.5)
	if selected:
		ci.draw_rect(rect.grow(2), Color(1, 1, 1, 0.9), false, 3.0)


static func draw_triangle_arrow(ci: CanvasItem, center: Vector2, side: String, color: Color, size: float) -> void:
	var pts := PackedVector2Array()
	var half := size * 0.55
	match side:
		"top":
			pts = PackedVector2Array([
				center + Vector2(0, half),
				center + Vector2(-half, -half * 0.55),
				center + Vector2(half, -half * 0.55),
			])
		"bottom":
			pts = PackedVector2Array([
				center + Vector2(0, -half),
				center + Vector2(-half, half * 0.55),
				center + Vector2(half, half * 0.55),
			])
		"left":
			pts = PackedVector2Array([
				center + Vector2(half, 0),
				center + Vector2(-half * 0.55, -half),
				center + Vector2(-half * 0.55, half),
			])
		"right":
			pts = PackedVector2Array([
				center + Vector2(-half, 0),
				center + Vector2(half * 0.55, -half),
				center + Vector2(half * 0.55, half),
			])
		_:
			pts = PackedVector2Array([
				center + Vector2(0, half),
				center + Vector2(-half, -half),
				center + Vector2(half, -half),
			])
	# soft shadow
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(1.5, 2))
	ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.3))
	ci.draw_colored_polygon(pts, color)
	# highlight edge
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), color.lightened(0.35), 1.5, true)

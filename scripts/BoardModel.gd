extends RefCounted
class_name BoardModel
## 《色塊出清》棋盤規則（與 tools/verify_levels.py 同步）
##
## 移動規則摘要：
## 1. 棋盤格子分為：可行走格、固定牆、黃色十字通道（可行走）。
## 2. 色塊為多格 polyomino，整塊平移，不可旋轉。
## 3. 邊緣色箭頭：點擊後，找出該列／該行上「距離閘口最近」的同色色塊，
##    沿箭頭方向滑到受阻或出清。
## 4. 亦可點選色塊後朝四向滑動（直到受阻）。
## 5. 離場條件：下一步若有任何一格越出棋盤，該格必須對應「同色、同側」的箭頭閘口；
##    只要有一格經合法閘口離場，整塊立即出清。
## 6. 不可從無閘口的邊緣滑出。黃色通道只是通道，不是出口。

const SIDES := {
	"top": Vector2i(0, -1),
	"bottom": Vector2i(0, 1),
	"left": Vector2i(-1, 0),
	"right": Vector2i(1, 0),
}

var grid_w: int = 7
var grid_h: int = 7
var walls: Dictionary = {} ## "x,y" -> true
var cross: Dictionary = {} ## "x,y" -> true
var pieces: Dictionary = {} ## id:int -> {id, color:Color, color_hex:String, cells:Array[Vector2i]}
var arrows: Array = [] ## {side, index, color:Color, color_hex, dir}
var goal: Dictionary = {}
var hint_text: String = ""
var hint_highlight: String = ""
var hint_highlight_color: String = "#FFD400"
var level_name: String = ""
var level_id: int = 1
var raw: Dictionary = {}

var cross_col: int = 3
var cross_row: int = 3


func load_from_dict(data: Dictionary) -> void:
	raw = data
	grid_w = int(data.get("width", 7))
	grid_h = int(data.get("height", 7))
	level_name = str(data.get("name", "關卡"))
	level_id = int(data.get("id", 1))
	hint_text = str(data.get("hint_text", "點邊緣的色箭頭，或滑動色塊"))
	hint_highlight = str(data.get("hint_highlight", ""))
	hint_highlight_color = str(data.get("hint_highlight_color", "#FFD400"))
	goal = data.get("goal", {"type": "clear_all"})
	if typeof(goal) != TYPE_DICTIONARY:
		goal = {"type": "clear_all"}
	walls.clear()
	cross.clear()
	pieces.clear()
	arrows.clear()
	for w in data.get("walls", []):
		walls["%d,%d" % [int(w["x"]), int(w["y"])]] = true
	_parse_cross(data.get("yellow_cross", data.get("cross", {})))
	for p in data.get("pieces", []):
		var pid := int(p["id"])
		var cells: Array[Vector2i] = []
		for c in p.get("cells", []):
			cells.append(Vector2i(int(c["x"]), int(c["y"])))
		var hex := _norm_hex(str(p.get("color", "#FF6B9D")))
		pieces[pid] = {
			"id": pid,
			"color": Color(hex),
			"color_hex": hex,
			"cells": cells,
		}
	for a in data.get("edge_arrows", data.get("arrows", [])):
		var hex2 := _norm_hex(str(a.get("color", "#FFFFFF")))
		arrows.append({
			"side": str(a.get("side", "top")),
			"index": int(a.get("index", 0)),
			"color": Color(hex2),
			"color_hex": hex2,
			"dir": str(a.get("dir", "out")),
		})


func _parse_cross(xc) -> void:
	cross_col = grid_w / 2
	cross_row = grid_h / 2
	if typeof(xc) == TYPE_DICTIONARY:
		cross_col = int(xc.get("cx", xc.get("col", cross_col)))
		cross_row = int(xc.get("cy", xc.get("row", cross_row)))
		var mode := str(xc.get("type", "plus"))
		if mode == "plus" or xc.has("col") or xc.has("cx") or xc.has("row") or xc.has("cy"):
			for x in grid_w:
				cross["%d,%d" % [x, cross_row]] = true
			for y in grid_h:
				cross["%d,%d" % [cross_col, y]] = true
		for c in xc.get("cells", []):
			cross["%d,%d" % [int(c["x"]), int(c["y"])]] = true
	elif typeof(xc) == TYPE_ARRAY:
		for c in xc:
			cross["%d,%d" % [int(c["x"]), int(c["y"])]] = true
	else:
		for x in grid_w:
			cross["%d,%d" % [x, cross_row]] = true
		for y in grid_h:
			cross["%d,%d" % [cross_col, y]] = true


func _norm_hex(h: String) -> String:
	var s := h.strip_edges().to_upper()
	if not s.begins_with("#"):
		s = "#" + s
	return s


func cell_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < grid_w and y < grid_h


func is_wall(x: int, y: int) -> bool:
	return walls.has(cell_key(x, y))


func is_cross(x: int, y: int) -> bool:
	return cross.has(cell_key(x, y))


func occupancy() -> Dictionary:
	var occ := {}
	for pid in pieces.keys():
		for cell: Vector2i in pieces[pid]["cells"]:
			if in_bounds(cell.x, cell.y):
				occ[cell_key(cell.x, cell.y)] = pid
	return occ


func piece_at(x: int, y: int) -> int:
	return int(occupancy().get(cell_key(x, y), -1))


func side_dir(side: String) -> Vector2i:
	return SIDES.get(side, Vector2i.ZERO)


func _exit_side(dir: Vector2i) -> String:
	if dir.y < 0:
		return "top"
	if dir.y > 0:
		return "bottom"
	if dir.x < 0:
		return "left"
	return "right"


func has_gate(side: String, index: int, color_hex: String) -> bool:
	var want := _norm_hex(color_hex)
	for a in arrows:
		if str(a["side"]) == side and int(a["index"]) == index and str(a["color_hex"]) == want:
			return true
	return false


func _on_track(cell: Vector2i, arrow: Dictionary) -> bool:
	var side := str(arrow["side"])
	var idx := int(arrow["index"])
	if side == "top" or side == "bottom":
		return cell.x == idx
	return cell.y == idx


func _dist_to_gate(cell: Vector2i, arrow: Dictionary) -> int:
	var side := str(arrow["side"])
	if side == "top":
		return cell.y
	if side == "bottom":
		return grid_h - 1 - cell.y
	if side == "left":
		return cell.x
	return grid_w - 1 - cell.x


func nearest_matching(arrow: Dictionary) -> int:
	var want := str(arrow["color_hex"])
	var best_pid := -1
	var best_d := 100000
	for pid in pieces.keys():
		var p: Dictionary = pieces[pid]
		if str(p["color_hex"]) != want:
			continue
		for cell: Vector2i in p["cells"]:
			if not _on_track(cell, arrow):
				continue
			var d := _dist_to_gate(cell, arrow)
			if d < best_d:
				best_d = d
				best_pid = int(pid)
	return best_pid


func arrow_ready(arrow: Dictionary) -> bool:
	var pid := nearest_matching(arrow)
	if pid < 0:
		return false
	var dir := side_dir(str(arrow["side"]))
	return _can_step(pid, dir)


func _copy_cells(cells: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells:
		out.append(c)
	return out


func _cell_exit_valid(cell: Vector2i, dir: Vector2i, color_hex: String) -> bool:
	var nx := cell.x + dir.x
	var ny := cell.y + dir.y
	if in_bounds(nx, ny):
		return true
	var side := _exit_side(dir)
	var idx := cell.x if side == "top" or side == "bottom" else cell.y
	return has_gate(side, idx, color_hex)


func _can_step(pid: int, dir: Vector2i) -> bool:
	if not pieces.has(pid):
		return false
	var p: Dictionary = pieces[pid]
	var occ := occupancy()
	var hex := str(p["color_hex"])
	for cell: Vector2i in p["cells"]:
		var nx := cell.x + dir.x
		var ny := cell.y + dir.y
		if in_bounds(nx, ny):
			if is_wall(nx, ny):
				return false
			var other: int = int(occ.get(cell_key(nx, ny), -1))
			if other >= 0 and other != pid:
				return false
		else:
			if not _cell_exit_valid(cell, dir, hex):
				return false
	return true


func _would_eject(pid: int, dir: Vector2i) -> bool:
	for cell: Vector2i in pieces[pid]["cells"]:
		if not in_bounds(cell.x + dir.x, cell.y + dir.y):
			return true
	return false


func _apply_step(pid: int, dir: Vector2i) -> void:
	var p: Dictionary = pieces[pid]
	var new_cells: Array[Vector2i] = []
	for cell: Vector2i in p["cells"]:
		new_cells.append(cell + dir)
	p["cells"] = new_cells


func _slide(pid: int, dir: Vector2i) -> Dictionary:
	var fail := {"ok": false, "pid": pid, "dir": dir, "steps": 0, "cleared": false}
	if not pieces.has(pid):
		return fail
	if not _can_step(pid, dir):
		return fail
	var from_cells := _copy_cells(pieces[pid]["cells"])
	var col: Color = pieces[pid]["color"]
	var steps := 0
	while _can_step(pid, dir):
		if _would_eject(pid, dir):
			steps += 1
			pieces.erase(pid)
			return {
				"ok": true,
				"pid": pid,
				"dir": dir,
				"steps": steps,
				"cleared": true,
				"color": col,
				"from_cells": from_cells,
			}
		_apply_step(pid, dir)
		steps += 1
		if steps > grid_w + grid_h + 2:
			break
	if steps <= 0:
		return fail
	return {
		"ok": true,
		"pid": pid,
		"dir": dir,
		"steps": steps,
		"cleared": false,
		"color": col,
		"from_cells": from_cells,
		"to_cells": _copy_cells(pieces[pid]["cells"]),
	}


func try_arrow(arrow_idx: int) -> Dictionary:
	if arrow_idx < 0 or arrow_idx >= arrows.size():
		return {"ok": false, "steps": 0, "cleared": false}
	var arrow: Dictionary = arrows[arrow_idx]
	var pid := nearest_matching(arrow)
	if pid < 0:
		return {"ok": false, "steps": 0, "cleared": false, "reason": "no_piece"}
	var dir := side_dir(str(arrow["side"]))
	var result := _slide(pid, dir)
	result["arrow_idx"] = arrow_idx
	result["arrow"] = arrow
	return result


func try_swipe(pid: int, dir: Vector2i) -> Dictionary:
	if dir == Vector2i.ZERO:
		return {"ok": false, "steps": 0, "cleared": false}
	return _slide(pid, dir)


func quadrant_of(cell: Vector2i) -> String:
	if is_cross(cell.x, cell.y):
		return ""
	if cell.x < cross_col and cell.y < cross_row:
		return "tl"
	if cell.x > cross_col and cell.y < cross_row:
		return "tr"
	if cell.x < cross_col and cell.y > cross_row:
		return "bl"
	if cell.x > cross_col and cell.y > cross_row:
		return "br"
	return ""


func _sort_ok(mapping: Dictionary) -> bool:
	var qcols := {"tl": {}, "tr": {}, "bl": {}, "br": {}}
	for pid in pieces.keys():
		var hex := str(pieces[pid]["color_hex"])
		for cell: Vector2i in pieces[pid]["cells"]:
			if is_cross(cell.x, cell.y):
				return false
			var q := quadrant_of(cell)
			if q == "":
				return false
			qcols[q][hex] = true
	for q in qcols.keys():
		var n: int = qcols[q].size()
		if n > 1:
			return false
		if mapping.has(q):
			var want := _norm_hex(str(mapping[q]))
			if n == 0:
				return false
			if not qcols[q].has(want):
				return false
	return true


func check_win() -> bool:
	var t := str(goal.get("type", "clear_all"))
	match t:
		"clear_all":
			return pieces.is_empty()
		"clear_color":
			var want := _norm_hex(str(goal.get("color", "")))
			for pid in pieces.keys():
				if str(pieces[pid]["color_hex"]) == want:
					return false
			return true
		"reach_cross":
			var want2 := _norm_hex(str(goal.get("color", "")))
			for pid in pieces.keys():
				if want2 != "#" and want2 != "" and str(pieces[pid]["color_hex"]) != want2:
					continue
				for cell: Vector2i in pieces[pid]["cells"]:
					if is_cross(cell.x, cell.y):
						return true
			return false
		"sort_quadrants":
			var mapping: Dictionary = goal.get("quadrants", {})
			if typeof(mapping) != TYPE_DICTIONARY:
				mapping = {}
			return _sort_ok(mapping)
		"combined":
			for col in goal.get("clear_colors", []):
				var want3 := _norm_hex(str(col))
				for pid in pieces.keys():
					if str(pieces[pid]["color_hex"]) == want3:
						return false
			var sq = goal.get("sort_quadrants", {})
			if typeof(sq) == TYPE_DICTIONARY and not sq.is_empty():
				if not _sort_ok(sq):
					return false
			elif sq:
				if not _sort_ok({}):
					return false
			return true
	return false


func snapshot() -> Dictionary:
	var snap_pieces := {}
	for pid in pieces.keys():
		var cells_arr: Array = []
		for cell: Vector2i in pieces[pid]["cells"]:
			cells_arr.append({"x": cell.x, "y": cell.y})
		snap_pieces[int(pid)] = {
			"id": int(pid),
			"color_hex": str(pieces[pid]["color_hex"]),
			"cells": cells_arr,
		}
	return {"pieces": snap_pieces}


func restore(snap: Dictionary) -> void:
	pieces.clear()
	var sp: Dictionary = snap.get("pieces", {})
	for pid_key in sp.keys():
		var id := int(pid_key)
		var cells: Array[Vector2i] = []
		for c in sp[pid_key]["cells"]:
			cells.append(Vector2i(int(c["x"]), int(c["y"])))
		var hex := _norm_hex(str(sp[pid_key]["color_hex"]))
		pieces[id] = {
			"id": id,
			"color": Color(hex),
			"color_hex": hex,
			"cells": cells,
		}


func goal_summary() -> String:
	var t := str(goal.get("type", "clear_all"))
	match t:
		"clear_all":
			return "把所有色塊從同色箭頭推出"
		"clear_color":
			return "出清指定顏色"
		"reach_cross":
			return "把色塊滑到黃色十字通道"
		"sort_quadrants":
			return "讓每個象限只剩一種顏色"
		"combined":
			return "出清指定色，並把其餘色塊歸位象限"
	return "完成關卡目標"

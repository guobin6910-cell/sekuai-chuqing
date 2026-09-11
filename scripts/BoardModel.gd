extends RefCounted
class_name BoardModel
## 《色塊出清》棋盤規則（與 tools/verify_levels.py 同步）
##
## 移動規則摘要：
## 1. 棋盤格子：可行走格、固定牆；黃色十字為可選通道（可行走，不是出口）。
## 2. 色塊為多格 polyomino，整塊平移，不可旋轉；僅在棋盤內滑動。
## 3. 邊緣色箭頭是固定顏色的出口標記（閘口），不是必按的推鈕。
## 4. 接觸出清：每次成功滑動一步後（及關卡載入時），若某色塊任一格
##    佔上同色箭頭對應的邊框格，該色塊立即消失。
##    閘口格：top→(index,0)、bottom→(index,h-1)、left→(0,index)、right→(w-1,index)
## 5. 異色接觸箭頭閘口無效，不會出清。
## 6. 點擊箭頭可選：僅高亮同色色塊，不推動、不出清。

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
var has_cross: bool = false
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
	hint_text = str(data.get("hint_text", "把色塊滑到同色箭頭上"))
	hint_highlight = str(data.get("hint_highlight", ""))
	hint_highlight_color = str(data.get("hint_highlight_color", "#FFD400"))
	goal = data.get("goal", {"type": "clear_all"})
	if typeof(goal) != TYPE_DICTIONARY:
		goal = {"type": "clear_all"}
	walls.clear()
	cross.clear()
	pieces.clear()
	arrows.clear()
	has_cross = false
	for w in data.get("walls", []):
		walls["%d,%d" % [int(w["x"]), int(w["y"])]] = true
	var xc = null
	if data.has("yellow_cross"):
		xc = data["yellow_cross"]
	elif data.has("cross"):
		xc = data["cross"]
	_parse_cross(xc)
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
	cross.clear()
	has_cross = false
	cross_col = grid_w / 2
	cross_row = grid_h / 2
	# Optional: null / false / omit / empty → no yellow cross
	if xc == null:
		return
	if typeof(xc) == TYPE_BOOL:
		if not bool(xc):
			return
		# true → default centered plus
		_build_plus(cross_col, cross_row)
		return
	if typeof(xc) == TYPE_DICTIONARY:
		if xc.is_empty():
			return
		if xc.get("enabled", true) == false:
			return
		cross_col = int(xc.get("cx", xc.get("col", cross_col)))
		cross_row = int(xc.get("cy", xc.get("row", cross_row)))
		var mode := str(xc.get("type", ""))
		var want_plus := (
			mode == "plus"
			or xc.has("col") or xc.has("cx")
			or xc.has("row") or xc.has("cy")
		)
		if want_plus:
			_build_plus(cross_col, cross_row)
		for c in xc.get("cells", []):
			cross["%d,%d" % [int(c["x"]), int(c["y"])]] = true
			has_cross = true
		return
	if typeof(xc) == TYPE_ARRAY:
		for c in xc:
			cross["%d,%d" % [int(c["x"]), int(c["y"])]] = true
			has_cross = true


func _build_plus(col: int, row: int) -> void:
	for x in grid_w:
		cross["%d,%d" % [x, row]] = true
	for y in grid_h:
		cross["%d,%d" % [col, y]] = true
	has_cross = true


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


## Gate cell covered by an arrow on (side, index).
func gate_cell(side: String, index: int) -> Vector2i:
	match side:
		"top":
			return Vector2i(index, 0)
		"bottom":
			return Vector2i(index, grid_h - 1)
		"left":
			return Vector2i(0, index)
		"right":
			return Vector2i(grid_w - 1, index)
	return Vector2i(-1, -1)


func has_gate(side: String, index: int, color_hex: String) -> bool:
	var want := _norm_hex(color_hex)
	for a in arrows:
		if str(a["side"]) == side and int(a["index"]) == index and str(a["color_hex"]) == want:
			return true
	return false


func matching_piece_ids(color_hex: String) -> Array:
	var want := _norm_hex(color_hex)
	var out: Array = []
	for pid in pieces.keys():
		if str(pieces[pid]["color_hex"]) == want:
			out.append(int(pid))
	return out


## Contact-clear: piece clears when any cell occupies a same-color arrow's gate cell.
func try_auto_clear() -> Array:
	var cleared: Array = []
	var to_erase: Array = []
	var seen: Dictionary = {}
	for a in arrows:
		var side := str(a["side"])
		var idx := int(a["index"])
		var want := str(a["color_hex"])
		var gc := gate_cell(side, idx)
		if not in_bounds(gc.x, gc.y):
			continue
		var pid := piece_at(gc.x, gc.y)
		if pid < 0 or seen.has(pid):
			continue
		if not pieces.has(pid):
			continue
		if str(pieces[pid]["color_hex"]) != want:
			continue
		seen[pid] = true
		to_erase.append(pid)
		cleared.append({
			"pid": pid,
			"color": pieces[pid]["color"],
			"color_hex": str(pieces[pid]["color_hex"]),
			"cells": _copy_cells(pieces[pid]["cells"]),
			"arrow": a,
			"gate": gc,
		})
	for pid in to_erase:
		pieces.erase(pid)
	return cleared


func _copy_cells(cells: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in cells:
		out.append(c)
	return out


func _can_step(pid: int, dir: Vector2i) -> bool:
	if not pieces.has(pid):
		return false
	var p: Dictionary = pieces[pid]
	var occ := occupancy()
	for cell: Vector2i in p["cells"]:
		var nx := cell.x + dir.x
		var ny := cell.y + dir.y
		if not in_bounds(nx, ny):
			return false
		if is_wall(nx, ny):
			return false
		var other: int = int(occ.get(cell_key(nx, ny), -1))
		if other >= 0 and other != pid:
			return false
	return true


func _apply_step(pid: int, dir: Vector2i) -> void:
	var p: Dictionary = pieces[pid]
	var new_cells: Array[Vector2i] = []
	for cell: Vector2i in p["cells"]:
		new_cells.append(cell + dir)
	p["cells"] = new_cells


## Slide inside board until blocked; contact-clear after each step.
func try_swipe(pid: int, dir: Vector2i) -> Dictionary:
	var fail := {"ok": false, "pid": pid, "dir": dir, "steps": 0, "cleared": false, "cleared_list": []}
	if dir == Vector2i.ZERO or not pieces.has(pid):
		fail["reason"] = "bad_dir" if dir == Vector2i.ZERO else "no_piece"
		return fail
	if not _can_step(pid, dir):
		fail["reason"] = "blocked"
		return fail
	var from_cells := _copy_cells(pieces[pid]["cells"])
	var col: Color = pieces[pid]["color"]
	var steps := 0
	var cleared_list: Array = []
	var cleared_self := false
	while pieces.has(pid) and _can_step(pid, dir):
		_apply_step(pid, dir)
		steps += 1
		var got := try_auto_clear()
		if not got.is_empty():
			cleared_list.append_array(got)
			for item in got:
				if int(item["pid"]) == pid:
					cleared_self = true
			if cleared_self or not pieces.has(pid):
				break
		if steps > grid_w + grid_h + 2:
			break
	if steps <= 0:
		return fail
	var result := {
		"ok": true,
		"pid": pid,
		"dir": dir,
		"steps": steps,
		"cleared": cleared_self,
		"cleared_list": cleared_list,
		"color": col,
		"from_cells": from_cells,
	}
	if pieces.has(pid):
		result["to_cells"] = _copy_cells(pieces[pid]["cells"])
	return result


## Optional UX: tapping an arrow only reports matching pieces (no push/clear).
func peek_arrow(arrow_idx: int) -> Dictionary:
	if arrow_idx < 0 or arrow_idx >= arrows.size():
		return {"ok": false, "pids": [], "reason": "bad_arrow"}
	var arrow: Dictionary = arrows[arrow_idx]
	var pids: Array = matching_piece_ids(str(arrow["color_hex"]))
	return {
		"ok": true,
		"arrow": arrow,
		"arrow_idx": arrow_idx,
		"pids": pids,
		"color_hex": str(arrow["color_hex"]),
	}


func quadrant_of(cell: Vector2i) -> String:
	if not has_cross:
		return ""
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
	if not has_cross:
		return false
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
			return "把色塊滑到同色邊框箭頭上出清"
		"clear_color":
			return "出清指定顏色"
		"reach_cross":
			return "把色塊滑到黃色十字通道"
		"sort_quadrants":
			return "讓每個象限只剩一種顏色"
		"combined":
			return "出清指定色，並把其餘色塊歸位象限"
	return "完成關卡目標"

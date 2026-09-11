extends Control
## 遊戲主畫面：棋盤、選取、滑動、Undo、通關

const BG := Color("1a1040")
const CELL_EMPTY := Color("2a1a55")
const CELL_WALL := Color("0d0820")
const GRID_LINE := Color("3d2a6e")
const SELECT_GLOW := Color("FFFFFF")

var level_data: Dictionary = {}
var grid_w: int = 5
var grid_h: int = 5
## piece_id -> { id, color: Color, cells: Array[Vector2i] }
var pieces: Dictionary = {}
var walls: Dictionary = {}  # "x,y" -> true

var selected_id: int = -1
var undo_stack: Array = []  # Array of snapshots
var animating: bool = false

var cell_size: float = 64.0
var board_origin: Vector2 = Vector2.ZERO

var hud_label: Label
var board_layer: Control
var piece_layer: Control
var fx_layer: Control
var hint_label: Label

var _drag_start: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _press_piece: int = -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_level(GameState.current_level_index)
	_build_ui()
	_push_undo_baseline()
	queue_redraw()


func _load_level(index: int) -> void:
	level_data = GameState.load_level_dict(index)
	grid_w = int(level_data.get("width", 5))
	grid_h = int(level_data.get("height", 5))
	walls.clear()
	pieces.clear()
	selected_id = -1
	undo_stack.clear()
	for w in level_data.get("walls", []):
		walls["%d,%d" % [int(w["x"]), int(w["y"])]] = true
	for p in level_data.get("pieces", []):
		var pid := int(p["id"])
		var cells: Array[Vector2i] = []
		for c in p["cells"]:
			cells.append(Vector2i(int(c["x"]), int(c["y"])))
		pieces[pid] = {
			"id": pid,
			"color": Color(str(p.get("color", "#FF6B9D"))),
			"cells": cells,
		}


func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_right = -16
	root.offset_top = 24
	root.offset_bottom = -24
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	hud_label = Label.new()
	hud_label.text = str(level_data.get("name", "關卡"))
	hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_label.add_theme_font_size_override("font_size", 28)
	hud_label.add_theme_color_override("font_color", Color("FFE66D"))
	root.add_child(hud_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	root.add_child(btn_row)

	btn_row.add_child(_hud_btn("重新開始", _on_restart))
	btn_row.add_child(_hud_btn("上一步", _on_undo))
	btn_row.add_child(_hud_btn("選關", _on_level_select))

	hint_label = Label.new()
	hint_label.text = "點選色塊，再朝上下左右拖曳滑動"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	root.add_child(hint_label)

	var board_host := Control.new()
	board_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(board_host)

	board_layer = Control.new()
	board_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	board_layer.draw.connect(_draw_board)
	board_layer.gui_input.connect(_on_board_input)
	board_host.add_child(board_layer)

	piece_layer = Control.new()
	piece_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	piece_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_host.add_child(piece_layer)

	fx_layer = Control.new()
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_host.add_child(fx_layer)

	# 延後計算 cell_size（等 layout）
	board_host.resized.connect(_recalc_layout)
	call_deferred("_recalc_layout")


func _hud_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(140, 48)
	b.add_theme_font_size_override("font_size", 18)
	var n := StyleBoxFlat.new()
	n.bg_color = Color("5B4B8A")
	n.corner_radius_top_left = 10
	n.corner_radius_top_right = 10
	n.corner_radius_bottom_left = 10
	n.corner_radius_bottom_right = 10
	n.content_margin_left = 10
	n.content_margin_right = 10
	var h := n.duplicate()
	h.bg_color = Color("7B6BAA")
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.pressed.connect(cb)
	return b


func _recalc_layout() -> void:
	if board_layer == null:
		return
	var area := board_layer.size
	if area.x < 10 or area.y < 10:
		return
	var pad := 8.0
	cell_size = min((area.x - pad * 2) / float(grid_w), (area.y - pad * 2) / float(grid_h))
	var bw := cell_size * grid_w
	var bh := cell_size * grid_h
	board_origin = Vector2((area.x - bw) * 0.5, (area.y - bh) * 0.5)
	_rebuild_piece_visuals()
	board_layer.queue_redraw()


func _draw_board() -> void:
	if board_layer == null:
		return
	for y in grid_h:
		for x in grid_w:
			var r := Rect2(board_origin + Vector2(x, y) * cell_size, Vector2(cell_size, cell_size))
			var inset := r.grow(-2)
			var col := CELL_WALL if _is_wall(x, y) else CELL_EMPTY
			board_layer.draw_rect(inset, col, true)
			board_layer.draw_rect(inset, GRID_LINE, false, 1.5)
	# 外框
	var outer := Rect2(board_origin, Vector2(cell_size * grid_w, cell_size * grid_h))
	board_layer.draw_rect(outer.grow(3), Color("95E1FF"), false, 3.0)


func _rebuild_piece_visuals() -> void:
	if piece_layer == null:
		return
	for c in piece_layer.get_children():
		c.queue_free()
	for pid in pieces.keys():
		var p: Dictionary = pieces[pid]
		var node := Control.new()
		node.name = "Piece_%d" % pid
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece_layer.add_child(node)
		for cell: Vector2i in p["cells"]:
			if not _in_bounds(cell.x, cell.y):
				continue
			var block := Panel.new()
			block.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var style := StyleBoxFlat.new()
			style.bg_color = p["color"]
			style.corner_radius_top_left = int(cell_size * 0.18)
			style.corner_radius_top_right = int(cell_size * 0.18)
			style.corner_radius_bottom_left = int(cell_size * 0.18)
			style.corner_radius_bottom_right = int(cell_size * 0.18)
			if pid == selected_id:
				style.border_color = SELECT_GLOW
				style.border_width_left = 3
				style.border_width_right = 3
				style.border_width_top = 3
				style.border_width_bottom = 3
			else:
				style.border_color = p["color"].lightened(0.25)
				style.border_width_left = 1
				style.border_width_right = 1
				style.border_width_top = 1
				style.border_width_bottom = 1
			block.add_theme_stylebox_override("panel", style)
			var margin := cell_size * 0.08
			block.position = board_origin + Vector2(cell) * cell_size + Vector2(margin, margin)
			block.size = Vector2(cell_size - margin * 2, cell_size - margin * 2)
			node.add_child(block)


func _is_wall(x: int, y: int) -> bool:
	return walls.has("%d,%d" % [x, y])


func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < grid_w and y < grid_h


func _occupancy() -> Dictionary:
	## "x,y" -> piece_id（僅棋盤內）
	var occ := {}
	for pid in pieces.keys():
		for cell: Vector2i in pieces[pid]["cells"]:
			if _in_bounds(cell.x, cell.y):
				occ["%d,%d" % [cell.x, cell.y]] = pid
	return occ


func _piece_at(gx: int, gy: int) -> int:
	var occ := _occupancy()
	return int(occ.get("%d,%d" % [gx, gy], -1))


func _screen_to_cell(local_pos: Vector2) -> Vector2i:
	var rel := local_pos - board_origin
	if rel.x < 0 or rel.y < 0:
		return Vector2i(-1, -1)
	var gx := int(rel.x / cell_size)
	var gy := int(rel.y / cell_size)
	if not _in_bounds(gx, gy):
		return Vector2i(-1, -1)
	return Vector2i(gx, gy)


func _on_board_input(event: InputEvent) -> void:
	if animating:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_start = mb.position
				_dragging = true
				var cell := _screen_to_cell(mb.position)
				_press_piece = _piece_at(cell.x, cell.y) if cell.x >= 0 else -1
				if _press_piece >= 0:
					selected_id = _press_piece
					_rebuild_piece_visuals()
			else:
				if _dragging and selected_id >= 0:
					var delta: Vector2 = mb.position - _drag_start
					_try_slide_from_drag(delta)
				_dragging = false
				_press_piece = -1
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_drag_start = st.position
			_dragging = true
			var cell2 := _screen_to_cell(st.position)
			_press_piece = _piece_at(cell2.x, cell2.y) if cell2.x >= 0 else -1
			if _press_piece >= 0:
				selected_id = _press_piece
				_rebuild_piece_visuals()
		else:
			if _dragging and selected_id >= 0:
				var delta2: Vector2 = st.position - _drag_start
				_try_slide_from_drag(delta2)
			_dragging = false
			_press_piece = -1
	elif event is InputEventScreenDrag:
		pass  # 松手時處理


func _try_slide_from_drag(delta: Vector2) -> void:
	if delta.length() < cell_size * 0.25:
		return  # 僅選取
	var dir := Vector2i.ZERO
	if abs(delta.x) >= abs(delta.y):
		dir = Vector2i(1, 0) if delta.x > 0 else Vector2i(-1, 0)
	else:
		dir = Vector2i(0, 1) if delta.y > 0 else Vector2i(0, -1)
	_slide_selected(dir)


func _unhandled_input(event: InputEvent) -> void:
	if animating or selected_id < 0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_slide_selected(Vector2i(-1, 0))
			KEY_RIGHT, KEY_D:
				_slide_selected(Vector2i(1, 0))
			KEY_UP, KEY_W:
				_slide_selected(Vector2i(0, -1))
			KEY_DOWN, KEY_S:
				_slide_selected(Vector2i(0, 1))
			KEY_Z:
				if event.ctrl_pressed:
					_on_undo()


func _can_step(pid: int, dir: Vector2i) -> bool:
	var occ := _occupancy()
	var p: Dictionary = pieces[pid]
	for cell: Vector2i in p["cells"]:
		var nx := cell.x + dir.x
		var ny := cell.y + dir.y
		if not _in_bounds(nx, ny):
			continue  # 離開棋盤 OK
		if _is_wall(nx, ny):
			return false
		var other: int = int(occ.get("%d,%d" % [nx, ny], -1))
		if other >= 0 and other != pid:
			return false
	return true


func _apply_step(pid: int, dir: Vector2i) -> void:
	var p: Dictionary = pieces[pid]
	var new_cells: Array[Vector2i] = []
	for cell: Vector2i in p["cells"]:
		new_cells.append(cell + dir)
	p["cells"] = new_cells


func _is_fully_off(pid: int) -> bool:
	for cell: Vector2i in pieces[pid]["cells"]:
		if _in_bounds(cell.x, cell.y):
			return false
	return true


func _slide_selected(dir: Vector2i) -> void:
	if selected_id < 0 or not pieces.has(selected_id) or animating:
		return
	if not _can_step(selected_id, dir):
		hint_label.text = "此方向無法移動"
		return

	# 計算可滑幾步
	var steps := 0
	var sim_cells: Array[Vector2i] = pieces[selected_id]["cells"].duplicate()
	while true:
		# 暫時套用檢查
		var ok := true
		var occ := {}
		for pid in pieces.keys():
			if pid == selected_id:
				continue
			for cell: Vector2i in pieces[pid]["cells"]:
				if _in_bounds(cell.x, cell.y):
					occ["%d,%d" % [cell.x, cell.y]] = pid
		for cell: Vector2i in sim_cells:
			var nx := cell.x + dir.x
			var ny := cell.y + dir.y
			if not _in_bounds(nx, ny):
				continue
			if _is_wall(nx, ny):
				ok = false
				break
			if occ.has("%d,%d" % [nx, ny]):
				ok = false
				break
		if not ok:
			break
		# 前進一步
		var next_cells: Array[Vector2i] = []
		for cell: Vector2i in sim_cells:
			next_cells.append(cell + dir)
		sim_cells = next_cells
		steps += 1
		# 若已完全離場，停止
		var all_off := true
		for cell: Vector2i in sim_cells:
			if _in_bounds(cell.x, cell.y):
				all_off = false
				break
		if all_off:
			break
		if steps > grid_w + grid_h + 2:
			break

	if steps <= 0:
		hint_label.text = "此方向無法移動"
		return

	_snapshot_before_move()
	animating = true
	hint_label.text = "滑動中…"
	await _animate_slide(selected_id, dir, steps)
	# 套用最終位置
	var final_cells: Array[Vector2i] = []
	for cell: Vector2i in pieces[selected_id]["cells"]:
		final_cells.append(cell + dir * steps)
	pieces[selected_id]["cells"] = final_cells

	var cleared := false
	if _is_fully_off(selected_id):
		var col: Color = pieces[selected_id]["color"]
		_spawn_exit_particles(col, dir)
		pieces.erase(selected_id)
		selected_id = -1
		cleared = true

	_rebuild_piece_visuals()
	board_layer.queue_redraw()
	animating = false
	hint_label.text = "點選色塊，再朝上下左右拖曳滑動"

	if pieces.is_empty():
		await get_tree().create_timer(0.35).timeout
		_on_win()
	elif cleared:
		hint_label.text = "色塊已清除！"


func _animate_slide(pid: int, dir: Vector2i, steps: int) -> void:
	var node := piece_layer.get_node_or_null("Piece_%d" % pid)
	if node == null:
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var dist := Vector2(dir) * cell_size * float(steps)
	tw.tween_property(node, "position", node.position + dist, 0.12 + 0.04 * steps)
	await tw.finished


func _spawn_exit_particles(color: Color, dir: Vector2i) -> void:
	# 簡易粒子：數個小方塊飛出並淡出
	var center := board_origin + Vector2(grid_w, grid_h) * cell_size * 0.5
	if dir.x > 0:
		center = board_origin + Vector2(grid_w * cell_size, grid_h * cell_size * 0.5)
	elif dir.x < 0:
		center = board_origin + Vector2(0, grid_h * cell_size * 0.5)
	elif dir.y > 0:
		center = board_origin + Vector2(grid_w * cell_size * 0.5, grid_h * cell_size)
	else:
		center = board_origin + Vector2(grid_w * cell_size * 0.5, 0)

	for i in 10:
		var p := ColorRect.new()
		p.color = color
		p.size = Vector2(8, 8)
		p.position = center + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx_layer.add_child(p)
		var tw := create_tween()
		var target := p.position + Vector2(dir) * randf_range(40, 90) + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		tw.tween_property(p, "position", target, 0.4)
		tw.parallel().tween_property(p, "modulate:a", 0.0, 0.4)
		tw.tween_callback(p.queue_free)


func _snapshot_before_move() -> void:
	undo_stack.append(_make_snapshot())


func _push_undo_baseline() -> void:
	# 不推入，讓第一次 undo 回到開局：開局時 stack 空，restart 用 reload
	pass


func _make_snapshot() -> Dictionary:
	var snap_pieces := {}
	for pid in pieces.keys():
		var cells_arr: Array = []
		for cell: Vector2i in pieces[pid]["cells"]:
			cells_arr.append({"x": cell.x, "y": cell.y})
		snap_pieces[pid] = {
			"id": pid,
			"color": pieces[pid]["color"].to_html(false),
			"cells": cells_arr,
		}
	return {"pieces": snap_pieces, "selected": selected_id}


func _restore_snapshot(snap: Dictionary) -> void:
	pieces.clear()
	var sp: Dictionary = snap["pieces"]
	for pid in sp.keys():
		var id := int(pid)
		var cells: Array[Vector2i] = []
		for c in sp[pid]["cells"]:
			cells.append(Vector2i(int(c["x"]), int(c["y"])))
		pieces[id] = {
			"id": id,
			"color": Color(str(sp[pid]["color"])),
			"cells": cells,
		}
	selected_id = int(snap.get("selected", -1))
	if selected_id >= 0 and not pieces.has(selected_id):
		selected_id = -1


func _on_undo() -> void:
	if animating:
		return
	if undo_stack.is_empty():
		hint_label.text = "沒有可復原的步驟"
		return
	var snap: Dictionary = undo_stack.pop_back()
	_restore_snapshot(snap)
	_rebuild_piece_visuals()
	board_layer.queue_redraw()
	hint_label.text = "已復原一步"


func _on_restart() -> void:
	if animating:
		return
	_load_level(GameState.current_level_index)
	undo_stack.clear()
	hud_label.text = str(level_data.get("name", "關卡"))
	_recalc_layout()
	hint_label.text = "重新開始"


func _on_level_select() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")


func _on_win() -> void:
	GameState.mark_cleared(GameState.current_level_index)
	get_tree().change_scene_to_file("res://scenes/Win.tscn")

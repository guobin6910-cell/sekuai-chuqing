extends Control
## 遊戲主畫面：滑動色塊、接觸同色箭頭自動出清、Undo／通關

const BG := Color("1B1438")
const FRAME := Color("B8A4E0")
const RECESS := Color("2A2050")
const CELL_EMPTY := Color("32245A")
const CELL_WALL := Color("140E2A")
const CROSS_Y := Color("FFD400")

var model: BoardModel = BoardModel.new()
var selected_id: int = -1
var undo_stack: Array = []
var animating: bool = false
var pulse_pids: Dictionary = {} ## pid -> true (arrow tap highlight)

var cell_size: float = 56.0
var frame_inset: float = 36.0
var board_origin: Vector2 = Vector2.ZERO

var board_host: Control
var board_layer: Control
var piece_layer: Control
var arrow_layer: Control
var fx_layer: Control

var hud_label: Label
var hint_label: RichTextLabel
var goal_label: Label

var _drag_start: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _arrow_hit_rects: Array = []
var _pulse_tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_level(GameState.current_level_index)
	_build_ui()


func _load_level(index: int) -> void:
	var data := GameState.load_level_dict(index)
	model = BoardModel.new()
	model.load_from_dict(data)
	selected_id = -1
	undo_stack.clear()
	pulse_pids.clear()
	# Level-start contact check (pieces already on matching gates).
	model.try_auto_clear()


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
	root.offset_left = 14
	root.offset_right = -14
	root.offset_top = 18
	root.offset_bottom = -18
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	hud_label = Label.new()
	hud_label.text = model.level_name
	hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_label.add_theme_font_size_override("font_size", 26)
	hud_label.add_theme_color_override("font_color", Color("FFE66D"))
	UITheme.apply(hud_label)
	root.add_child(hud_label)

	hint_label = RichTextLabel.new()
	hint_label.bbcode_enabled = true
	hint_label.fit_content = true
	hint_label.scroll_active = false
	hint_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint_label.custom_minimum_size = Vector2(0, 36)
	hint_label.add_theme_font_size_override("normal_font_size", 22)
	hint_label.add_theme_color_override("default_color", Color(1, 1, 1, 0.92))
	UITheme.apply(hint_label)
	_refresh_hint()
	root.add_child(hint_label)

	goal_label = Label.new()
	goal_label.text = model.goal_summary()
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal_label.add_theme_font_size_override("font_size", 15)
	goal_label.add_theme_color_override("font_color", Color("95E1FF"))
	UITheme.apply(goal_label)
	root.add_child(goal_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	root.add_child(btn_row)
	btn_row.add_child(_hud_btn("重新開始", _on_restart))
	btn_row.add_child(_hud_btn("上一步", _on_undo))
	btn_row.add_child(_hud_btn("選關", _on_level_select))

	board_host = Control.new()
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

	arrow_layer = Control.new()
	arrow_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	arrow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow_layer.draw.connect(_draw_arrows)
	board_host.add_child(arrow_layer)

	fx_layer = Control.new()
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_host.add_child(fx_layer)

	board_host.resized.connect(_recalc_layout)
	call_deferred("_recalc_layout")
	call_deferred("_check_win_after_load")


func _check_win_after_load() -> void:
	if model.check_win():
		_on_win()


func _refresh_hint(extra: String = "") -> void:
	if hint_label == null:
		return
	var text := model.hint_text if extra.is_empty() else extra
	var hi := model.hint_highlight
	var hc := model.hint_highlight_color
	if hi != "" and text.find(hi) >= 0:
		var col := Color(hc)
		var tag := "[color=#%s][b]%s[/b][/color]" % [col.to_html(false), hi]
		text = text.replace(hi, tag)
	hint_label.text = "[center]%s[/center]" % text


func _hud_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(132, 46)
	b.add_theme_font_size_override("font_size", 18)
	var n := StyleBoxFlat.new()
	n.bg_color = Color("5B4B8A")
	n.corner_radius_top_left = 12
	n.corner_radius_top_right = 12
	n.corner_radius_bottom_left = 12
	n.corner_radius_bottom_right = 12
	n.content_margin_left = 10
	n.content_margin_right = 10
	var h := n.duplicate()
	h.bg_color = Color("7B6BAA")
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_color_override("font_color", Color.WHITE)
	UITheme.apply(b)
	b.pressed.connect(cb)
	return b


func _recalc_layout() -> void:
	if board_layer == null:
		return
	var area := board_layer.size
	if area.x < 10 or area.y < 10:
		return
	frame_inset = minf(42.0, minf(area.x, area.y) * 0.08)
	var pad := 6.0
	var usable := Vector2(area.x - pad * 2.0 - frame_inset * 2.0, area.y - pad * 2.0 - frame_inset * 2.0)
	cell_size = minf(usable.x / float(model.grid_w), usable.y / float(model.grid_h))
	var bw := cell_size * model.grid_w
	var bh := cell_size * model.grid_h
	board_origin = Vector2((area.x - bw) * 0.5, (area.y - bh) * 0.5)
	_rebuild_piece_visuals()
	board_layer.queue_redraw()
	arrow_layer.queue_redraw()


func _outer_frame_rect() -> Rect2:
	return Rect2(
		board_origin - Vector2(frame_inset, frame_inset),
		Vector2(cell_size * model.grid_w, cell_size * model.grid_h) + Vector2(frame_inset, frame_inset) * 2.0
	)


func _draw_board() -> void:
	if board_layer == null or cell_size < 1.0:
		return
	var outer := _outer_frame_rect()
	BrickDraw.draw_frame(board_layer, outer, frame_inset, FRAME, Color(0, 0, 0, 0.35), RECESS)
	for y in model.grid_h:
		for x in model.grid_w:
			var r := Rect2(board_origin + Vector2(x, y) * cell_size, Vector2(cell_size, cell_size))
			if model.is_wall(x, y):
				BrickDraw.draw_wall_cell(board_layer, r, CELL_WALL)
			elif model.is_cross(x, y):
				BrickDraw.draw_cross_cell(board_layer, r, CROSS_Y)
			else:
				BrickDraw.draw_empty_cell(board_layer, r, CELL_EMPTY)


func _draw_arrows() -> void:
	_arrow_hit_rects.clear()
	if arrow_layer == null or cell_size < 1.0:
		return
	var asize: float = minf(frame_inset * 0.72, cell_size * 0.55)
	for i in model.arrows.size():
		var a: Dictionary = model.arrows[i]
		var side := str(a["side"])
		var idx := int(a["index"])
		var center := _arrow_center(side, idx)
		var col: Color = a["color"]
		BrickDraw.draw_triangle_arrow(arrow_layer, center, side, col, asize)
		var hit := Rect2(center - Vector2(asize, asize), Vector2(asize, asize) * 2.0)
		_arrow_hit_rects.append({"rect": hit, "idx": i})


func _arrow_center(side: String, idx: int) -> Vector2:
	var mid := frame_inset * 0.48
	match side:
		"top":
			return Vector2(board_origin.x + (idx + 0.5) * cell_size, board_origin.y - mid)
		"bottom":
			return Vector2(board_origin.x + (idx + 0.5) * cell_size, board_origin.y + model.grid_h * cell_size + mid)
		"left":
			return Vector2(board_origin.x - mid, board_origin.y + (idx + 0.5) * cell_size)
		"right":
			return Vector2(board_origin.x + model.grid_w * cell_size + mid, board_origin.y + (idx + 0.5) * cell_size)
	return board_origin


func _rebuild_piece_visuals() -> void:
	if piece_layer == null:
		return
	for c in piece_layer.get_children():
		c.queue_free()
	for pid in model.pieces.keys():
		var p: Dictionary = model.pieces[pid]
		var node := Control.new()
		node.name = "Piece_%d" % pid
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece_layer.add_child(node)
		var pulsed := pulse_pids.has(int(pid))
		for cell: Vector2i in p["cells"]:
			if not model.in_bounds(cell.x, cell.y):
				continue
			var drawer := _BrickCell.new()
			drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			drawer.base_color = p["color"]
			drawer.selected = (int(pid) == selected_id) or pulsed
			var margin := cell_size * 0.06
			drawer.position = board_origin + Vector2(cell) * cell_size + Vector2(margin, margin)
			drawer.size = Vector2(cell_size - margin * 2.0, cell_size - margin * 2.0)
			node.add_child(drawer)


class _BrickCell extends Control:
	var base_color: Color = Color.WHITE
	var selected: bool = false

	func _draw() -> void:
		BrickDraw.draw_stud_brick(self, Rect2(Vector2.ZERO, size), base_color, selected)


func _screen_to_cell(local_pos: Vector2) -> Vector2i:
	var rel := local_pos - board_origin
	if rel.x < 0 or rel.y < 0:
		return Vector2i(-1, -1)
	var gx := int(rel.x / cell_size)
	var gy := int(rel.y / cell_size)
	if not model.in_bounds(gx, gy):
		return Vector2i(-1, -1)
	return Vector2i(gx, gy)


func _arrow_at(local_pos: Vector2) -> int:
	for item in _arrow_hit_rects:
		if item["rect"].has_point(local_pos):
			return int(item["idx"])
	return -1


func _on_board_input(event: InputEvent) -> void:
	if animating:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_drag_start = mb.position
			_dragging = true
			var aidx := _arrow_at(mb.position)
			if aidx >= 0:
				_dragging = false
				_activate_arrow(aidx)
				return
			var cell := _screen_to_cell(mb.position)
			var pid := model.piece_at(cell.x, cell.y) if cell.x >= 0 else -1
			if pid >= 0:
				selected_id = pid
				pulse_pids.clear()
				_rebuild_piece_visuals()
		else:
			if _dragging and selected_id >= 0:
				_try_swipe_drag(mb.position - _drag_start)
			_dragging = false
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_drag_start = st.position
			_dragging = true
			var aidx2 := _arrow_at(st.position)
			if aidx2 >= 0:
				_dragging = false
				_activate_arrow(aidx2)
				return
			var cell2 := _screen_to_cell(st.position)
			var pid2 := model.piece_at(cell2.x, cell2.y) if cell2.x >= 0 else -1
			if pid2 >= 0:
				selected_id = pid2
				pulse_pids.clear()
				_rebuild_piece_visuals()
		else:
			if _dragging and selected_id >= 0:
				_try_swipe_drag(st.position - _drag_start)
			_dragging = false


func _try_swipe_drag(delta: Vector2) -> void:
	if delta.length() < cell_size * 0.22:
		return
	var dir := Vector2i.ZERO
	if abs(delta.x) >= abs(delta.y):
		dir = Vector2i(1, 0) if delta.x > 0 else Vector2i(-1, 0)
	else:
		dir = Vector2i(0, 1) if delta.y > 0 else Vector2i(0, -1)
	_slide_selected(dir)


func _unhandled_input(event: InputEvent) -> void:
	if animating:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z and event.ctrl_pressed:
			_on_undo()
			return
		if selected_id < 0:
			return
		match event.keycode:
			KEY_LEFT, KEY_A:
				_slide_selected(Vector2i(-1, 0))
			KEY_RIGHT, KEY_D:
				_slide_selected(Vector2i(1, 0))
			KEY_UP, KEY_W:
				_slide_selected(Vector2i(0, -1))
			KEY_DOWN, KEY_S:
				_slide_selected(Vector2i(0, 1))


func _activate_arrow(idx: int) -> void:
	# Arrows are exit markers; tap only highlights matching pieces.
	var peek := model.peek_arrow(idx)
	if not peek.get("ok", false):
		return
	pulse_pids.clear()
	var pids: Array = peek.get("pids", [])
	for pid in pids:
		pulse_pids[int(pid)] = true
	if pids.is_empty():
		_refresh_hint("沒有同色色塊")
	else:
		_refresh_hint("同色色塊已標示 — 滑到箭頭上才會出清")
		if selected_id < 0 and pids.size() > 0:
			selected_id = int(pids[0])
	_rebuild_piece_visuals()
	_pulse_pieces_briefly()


func _pulse_pieces_briefly() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.tween_interval(0.85)
	_pulse_tween.tween_callback(func ():
		pulse_pids.clear()
		_rebuild_piece_visuals()
	)


func _slide_selected(dir: Vector2i) -> void:
	if selected_id < 0 or animating:
		return
	var snap := model.snapshot()
	var result := model.try_swipe(selected_id, dir)
	if not result.get("ok", false):
		_refresh_hint("此方向無法移動")
		return
	undo_stack.append(snap)
	animating = true
	_play_result(result)


func _play_result(result: Dictionary) -> void:
	animating = true
	var pid: int = int(result.get("pid", -1))
	var dir: Vector2i = result.get("dir", Vector2i.ZERO)
	var steps: int = int(result.get("steps", 1))
	var cleared: bool = bool(result.get("cleared", false))
	var cleared_list: Array = result.get("cleared_list", [])
	var col: Color = result.get("color", Color.WHITE)
	var from_cells: Array = result.get("from_cells", [])

	# Animate slide; if cleared mid/end, ghost travels then particles.
	if cleared:
		await _spawn_ghost_and_tween(result)
		_spawn_clear_particles(col, from_cells, dir, steps)
		for item in cleared_list:
			if int(item.get("pid", -1)) != pid:
				_spawn_clear_particles(item.get("color", Color.WHITE), item.get("cells", []), Vector2i.ZERO, 0)
	else:
		_rebuild_piece_visuals()
		var node := piece_layer.get_node_or_null("Piece_%d" % pid)
		if node:
			node.position -= Vector2(dir) * cell_size * float(steps)
			var tw := create_tween()
			tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(node, "position", node.position + Vector2(dir) * cell_size * float(steps), 0.12 + 0.04 * steps)
			await tw.finished
		else:
			await get_tree().create_timer(0.05).timeout
		# Non-self clears (shouldn't happen often without moving that piece)
		for item in cleared_list:
			_spawn_clear_particles(item.get("color", Color.WHITE), item.get("cells", []), Vector2i.ZERO, 0)

	if cleared and selected_id == pid:
		selected_id = -1
	pulse_pids.clear()
	_rebuild_piece_visuals()
	board_layer.queue_redraw()
	arrow_layer.queue_redraw()
	animating = false
	_refresh_hint()

	if model.check_win():
		await get_tree().create_timer(0.35).timeout
		_on_win()
	elif cleared:
		_refresh_hint("色塊已出清！")


func _spawn_ghost_and_tween(result: Dictionary) -> void:
	var from_cells: Array = result.get("from_cells", [])
	var dir: Vector2i = result.get("dir", Vector2i.ZERO)
	var steps: int = int(result.get("steps", 1))
	var col: Color = result.get("color", Color.WHITE)
	var ghost := Control.new()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	piece_layer.add_child(ghost)
	for c in from_cells:
		var cell := _as_cell(c)
		var drawer := _BrickCell.new()
		drawer.base_color = col
		var margin := cell_size * 0.06
		drawer.position = board_origin + Vector2(cell) * cell_size + Vector2(margin, margin)
		drawer.size = Vector2(cell_size - margin * 2.0, cell_size - margin * 2.0)
		ghost.add_child(drawer)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "position", ghost.position + Vector2(dir) * cell_size * float(steps), 0.12 + 0.04 * steps)
	tw.parallel().tween_property(ghost, "modulate:a", 0.15, 0.12 + 0.04 * steps)
	await tw.finished
	ghost.queue_free()


func _as_cell(c) -> Vector2i:
	if typeof(c) == TYPE_VECTOR2I:
		return c
	if typeof(c) == TYPE_DICTIONARY:
		return Vector2i(int(c["x"]), int(c["y"]))
	return Vector2i.ZERO


func _spawn_clear_particles(color: Color, cells: Array, dir: Vector2i, steps: int) -> void:
	var center := board_origin + Vector2(model.grid_w, model.grid_h) * cell_size * 0.5
	if cells.size() > 0:
		var cell := _as_cell(cells[0])
		center = board_origin + Vector2(cell) * cell_size + Vector2(cell_size, cell_size) * 0.5
		if dir != Vector2i.ZERO and steps > 0:
			center += Vector2(dir) * cell_size * float(steps)
	for i in 14:
		var p := ColorRect.new()
		p.color = color.lightened(randf_range(-0.1, 0.2))
		var s := randf_range(6, 12)
		p.size = Vector2(s, s)
		p.position = center + Vector2(randf_range(-18, 18), randf_range(-18, 18))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fx_layer.add_child(p)
		var tw := create_tween()
		var scatter := Vector2(dir) * randf_range(20, 70) if dir != Vector2i.ZERO else Vector2.ZERO
		var target := p.position + scatter + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		tw.tween_property(p, "position", target, 0.45)
		tw.parallel().tween_property(p, "modulate:a", 0.0, 0.45)
		tw.tween_callback(p.queue_free)


func _on_undo() -> void:
	if animating:
		return
	if undo_stack.is_empty():
		_refresh_hint("沒有可復原的步驟")
		return
	var snap: Dictionary = undo_stack.pop_back()
	model.restore(snap)
	selected_id = -1
	pulse_pids.clear()
	_rebuild_piece_visuals()
	board_layer.queue_redraw()
	arrow_layer.queue_redraw()
	_refresh_hint("已復原一步")


func _on_restart() -> void:
	if animating:
		return
	_load_level(GameState.current_level_index)
	hud_label.text = model.level_name
	goal_label.text = model.goal_summary()
	_recalc_layout()
	_refresh_hint("重新開始")


func _on_level_select() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")


func _on_win() -> void:
	GameState.mark_cleared(GameState.current_level_index)
	get_tree().change_scene_to_file("res://scenes/Win.tscn")

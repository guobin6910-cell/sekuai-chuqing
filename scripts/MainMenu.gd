extends Control
## 主選單


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("1B1438")
	add_child(bg)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 28)
	add_child(v)

	var pad_top := Control.new()
	pad_top.custom_minimum_size = Vector2(0, 40)
	v.add_child(pad_top)

	var title := Label.new()
	title.text = "色塊出清"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("FFE66D"))
	UITheme.apply(title)
	v.add_child(title)

	var sub := Label.new()
	sub.text = "黃十字通道 · 邊緣色箭頭 · 塑膠積木"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color("95E1FF"))
	UITheme.apply(sub)
	v.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 48)
	v.add_child(spacer)

	v.add_child(_make_btn("開始遊戲", _on_start))
	v.add_child(_make_btn("選擇關卡", _on_select))

	var tip := Label.new()
	tip.text = "消除必須透過同色邊框箭頭\n拖曳／WASD 僅在棋盤內滑動，無法推出"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 17)
	tip.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	UITheme.apply(tip)
	v.add_child(tip)


func _make_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 72)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 28)
	_style_button(b)
	UITheme.apply(b)
	b.pressed.connect(cb)
	return b


func _style_button(b: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color("4ECDC4")
	n.corner_radius_top_left = 16
	n.corner_radius_top_right = 16
	n.corner_radius_bottom_left = 16
	n.corner_radius_bottom_right = 16
	n.content_margin_left = 24
	n.content_margin_right = 24
	n.content_margin_top = 12
	n.content_margin_bottom = 12
	var h := n.duplicate()
	h.bg_color = Color("7EE8E0")
	var p := n.duplicate()
	p.bg_color = Color("3AA99F")
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_color_override("font_color", Color("1a1040"))
	b.add_theme_color_override("font_hover_color", Color("1a1040"))
	b.add_theme_color_override("font_pressed_color", Color("1a1040"))


func _on_start() -> void:
	GameState.current_level_index = 0
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_select() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

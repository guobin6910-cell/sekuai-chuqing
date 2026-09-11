extends Control
## 通關畫面


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("1a1040")
	add_child(bg)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 24)
	add_child(v)

	var title := Label.new()
	title.text = "通關！"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color("FFE66D"))
	v.add_child(title)

	var sub := Label.new()
	var lv := GameState.current_level_index + 1
	sub.text = "已清空第 %d 關的所有色塊" % lv
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color("95E1FF"))
	v.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	v.add_child(spacer)

	if GameState.has_next_level():
		v.add_child(_btn("下一關", _on_next))
	else:
		var done := Label.new()
		done.text = "恭喜完成全部 5 關！"
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done.add_theme_font_size_override("font_size", 22)
		done.add_theme_color_override("font_color", Color("4ECDC4"))
		v.add_child(done)

	v.add_child(_btn("再玩一次", _on_retry))
	v.add_child(_btn("選擇關卡", _on_select))
	v.add_child(_btn("主選單", _on_menu))


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 64)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 26)
	var n := StyleBoxFlat.new()
	n.bg_color = Color("4ECDC4")
	n.corner_radius_top_left = 14
	n.corner_radius_top_right = 14
	n.corner_radius_bottom_left = 14
	n.corner_radius_bottom_right = 14
	var h := n.duplicate()
	h.bg_color = Color("7EE8E0")
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_color_override("font_color", Color("1a1040"))
	b.add_theme_color_override("font_hover_color", Color("1a1040"))
	b.pressed.connect(cb)
	return b


func _on_next() -> void:
	GameState.current_level_index += 1
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_retry() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_select() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")


func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

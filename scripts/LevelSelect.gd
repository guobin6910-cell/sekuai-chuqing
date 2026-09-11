extends Control
## 選關畫面


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("1B1438")
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16)
	root.offset_left = 32
	root.offset_right = -32
	root.offset_top = 48
	root.offset_bottom = -48
	add_child(root)

	var title := Label.new()
	title.text = "選擇關卡"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("FFE66D"))
	root.add_child(title)

	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 14)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(grid)

	for i in GameState.LEVEL_COUNT:
		var data := GameState.load_level_dict(i)
		var name_str: String = str(data.get("name", "第%d關" % (i + 1)))
		var locked := i > GameState.unlocked_upto
		var b := Button.new()
		b.text = ("%s  🔒" % name_str) if locked else name_str
		b.disabled = locked
		b.custom_minimum_size = Vector2(0, 64)
		b.add_theme_font_size_override("font_size", 22)
		_style_level_btn(b, locked)
		var idx := i
		b.pressed.connect(func(): _open_level(idx))
		grid.add_child(b)

	var back := Button.new()
	back.text = "返回主選單"
	back.custom_minimum_size = Vector2(0, 56)
	back.add_theme_font_size_override("font_size", 22)
	_style_back(back)
	back.pressed.connect(_on_back)
	root.add_child(back)


func _style_level_btn(b: Button, locked: bool) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color("2d1b69") if locked else Color("5B4B8A")
	n.corner_radius_top_left = 12
	n.corner_radius_top_right = 12
	n.corner_radius_bottom_left = 12
	n.corner_radius_bottom_right = 12
	n.content_margin_left = 16
	n.content_margin_right = 16
	n.content_margin_top = 10
	n.content_margin_bottom = 10
	var h := n.duplicate()
	h.bg_color = Color("7B6BAA")
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("disabled", n)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 0.45) if locked else Color.WHITE)


func _style_back(b: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color("4ECDC4")
	n.corner_radius_top_left = 12
	n.corner_radius_top_right = 12
	n.corner_radius_bottom_left = 12
	n.corner_radius_bottom_right = 12
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	b.add_theme_stylebox_override("pressed", n)
	b.add_theme_color_override("font_color", Color("1B1438"))


func _open_level(index: int) -> void:
	GameState.current_level_index = index
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

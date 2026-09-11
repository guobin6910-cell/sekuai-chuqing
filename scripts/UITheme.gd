extends Node
## CJK UI font autoload — Godot default fonts lack Traditional Chinese glyphs.
## Preload keeps the font in the Web export PCK.

const FONT_PATH := "res://assets/fonts/jf-openhuninn-2.1.ttf"
const _FONT_RES: Font = preload("res://assets/fonts/jf-openhuninn-2.1.ttf")

static var font: Font


func _enter_tree() -> void:
	font = _FONT_RES
	_apply_default_theme()


func _apply_default_theme() -> void:
	if font == null:
		push_warning("UITheme: CJK font missing at %s" % FONT_PATH)
		return
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 18
	# Root theme so Labels/Buttons created later inherit CJK glyphs.
	get_tree().root.theme = theme


## Apply font overrides to a Label / Button / RichTextLabel (and children recursively optional).
static func apply(control: Control) -> void:
	if control == null or font == null:
		return
	if control is RichTextLabel:
		control.add_theme_font_override("normal_font", font)
		control.add_theme_font_override("bold_font", font)
		control.add_theme_font_override("italics_font", font)
		control.add_theme_font_override("bold_italics_font", font)
		control.add_theme_font_override("mono_font", font)
	else:
		control.add_theme_font_override("font", font)


static func apply_tree(root: Control) -> void:
	if root == null:
		return
	apply(root)
	for child in root.get_children():
		if child is Control:
			apply_tree(child)

extends Node
## 全域狀態：目前關卡、已解鎖關卡

const LEVEL_COUNT := 5
const LEVEL_PATHS := [
	"res://levels/level_01.json",
	"res://levels/level_02.json",
	"res://levels/level_03.json",
	"res://levels/level_04.json",
	"res://levels/level_05.json",
]

var current_level_index: int = 0
var unlocked_upto: int = 4  # MVP：五關皆可選；過關仍會推進


func get_level_path(index: int) -> String:
	if index < 0 or index >= LEVEL_COUNT:
		return ""
	return LEVEL_PATHS[index]


func load_level_dict(index: int) -> Dictionary:
	var path := get_level_path(index)
	if path.is_empty():
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("無法讀取關卡: %s" % path)
		return {}
	var text := file.get_as_text()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("關卡 JSON 格式錯誤: %s" % path)
		return {}
	return data


func mark_cleared(index: int) -> void:
	if index >= unlocked_upto and index + 1 < LEVEL_COUNT:
		unlocked_upto = index + 1
	elif index + 1 >= LEVEL_COUNT:
		unlocked_upto = LEVEL_COUNT - 1


func has_next_level() -> bool:
	return current_level_index + 1 < LEVEL_COUNT

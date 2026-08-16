extends Node

signal day_changed(new_day: int)

const MAX_DAY: int = 7
const DAY_KANJI: Array[String] = ["一", "二", "三", "四", "五", "六", "七"]

var current_day: int = 7

func get_day_status_name() -> String:
	return str(current_day) + "day"

func get_day_display_text() -> String:
	var index := current_day - 1
	if index < DAY_KANJI.size():
		return DAY_KANJI[index] + "夜目"
	else:
		return str(current_day) + "夜目"

func advance_day() -> void:
	if current_day >= MAX_DAY:
		print("[DayManager] 既に最終日です")
		return
	current_day += 1
	day_changed.emit(current_day)
	print("[DayManager] 日付変更 → ", get_day_status_name())
	if SaveManager:
		SaveManager.save_game()

func set_day(day: int) -> void:
	current_day = clampi(day, 1, MAX_DAY)
	day_changed.emit(current_day)
	print("[DayManager] 日付を強制設定 → ", get_day_status_name())

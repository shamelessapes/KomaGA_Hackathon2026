extends Node

## セーブデータ管理クラス (SaveManager)
## 日付（current_day）およびインベントリ取得状況を user://save_data.json に保存・復元します。

const SAVE_PATH = "user://save_data.json"


## セーブデータが存在し、パース可能か確認
func has_save_data() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		return false
	var data = json.get_data()
	return typeof(data) == TYPE_DICTIONARY and data.has("day")


## 現在のゲーム状態（日付・インベントリ）を保存
func save_game() -> void:
	var slots_data: Array = []
	if InventoryManager:
		for slot in InventoryManager.slots:
			if slot != null and typeof(slot) == TYPE_DICTIONARY and not slot.is_empty():
				var scale_vec: Vector2 = slot.get("item_scale", Vector2.ONE)
				var slot_copy = {
					"item_id": slot.get("item_id", ""),
					"count": slot.get("count", 1),
					"scale_x": scale_vec.x,
					"scale_y": scale_vec.y
				}
				slots_data.append(slot_copy)
			else:
				slots_data.append(null)

	var current_day_val: int = 1
	if Daymanager:
		current_day_val = Daymanager.current_day

	var save_dict = {
		"day": current_day_val,
		"slots": slots_data
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_dict, "\t")
		file.store_string(json_string)
		file.close()
		#print("[SaveManager] セーブデータを保存しました (Day: %d)" % current_day_val)
	#else:
		#push_error("[SaveManager] セーブデータの書き込みに失敗しました")


## セーブデータから日付とインベントリを復元
func load_game() -> bool:
	if not has_save_data():
		print("[SaveManager] 有効なセーブデータが存在しません")
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("[SaveManager] セーブファイルの読み込みに失敗しました")
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("[SaveManager] JSONパースエラー")
		return false

	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return false

	# 日付の復元
	var saved_day = int(data.get("day", 1))
	if Daymanager:
		Daymanager.set_day(saved_day)

	# インベントリの復元
	if InventoryManager:
		InventoryManager._init_slots()
		var slots_data = data.get("slots", [])
		for i in range(min(slots_data.size(), InventoryManager.max_slots)):
			var s_data = slots_data[i]
			if s_data != null and typeof(s_data) == TYPE_DICTIONARY and not s_data.is_empty():
				var scale_x = float(s_data.get("scale_x", 1.0))
				var scale_y = float(s_data.get("scale_y", 1.0))
				InventoryManager.slots[i] = {
					"item_id": String(s_data.get("item_id", "")),
					"count": int(s_data.get("count", 1)),
					"item_scale": Vector2(scale_x, scale_y)
				}
		InventoryManager.inventory_updated.emit()

	print("[SaveManager] セーブデータをロードしました (Day: %d)" % saved_day)
	return true


## 新規ゲーム開始時の初期化
func new_game() -> void:
	if Daymanager:
		Daymanager.set_day(1)
	if InventoryManager:
		InventoryManager._init_slots()
		InventoryManager.inventory_updated.emit()
	save_game()

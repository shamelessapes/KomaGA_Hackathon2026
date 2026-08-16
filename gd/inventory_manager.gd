extends Node

## インベントリデータ管理マネージャー
## UI制御は一切行わず、純粋なデータ管理・判定・シグナル通知を担当します。

## シグナル定義
signal inventory_updated
signal item_added(item_id: String, slot_index: int, count: int)
signal item_removed(item_id: String, slot_index: int, count: int)
signal item_used(item_id: String, slot_index: int)
signal inventory_message(message: String)

## 最大スロット数 (Inspector設定可能・初期値3)
@export var max_slots: int = 3

## インベントリスロット配列 [ { "item_id": String, "count": int } または null ]
var slots: Array = []

## 合成レシピデータベース [ [id_a, id_b] -> result_id ]
var _recipes: Dictionary = {}


func _ready() -> void:
	_init_slots()
	_register_default_recipes()
	inventory_updated.connect(_on_inventory_updated_autosave)


func _on_inventory_updated_autosave() -> void:
	if SaveManager:
		SaveManager.save_game()


## スロットの初期化
func _init_slots() -> void:
	slots.clear()
	for i in range(max_slots):
		slots.append(null)


## ----------------------------------------------------
## アイテム追加関連
## ----------------------------------------------------
## アイテムの追加が可能か判定
func can_add_item(item_id: String, count: int = 1) -> bool:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		return false

	# 設置物カテゴリのアイテムはスロットへの格納を拒否
	if item_data.has_category("設置物") or item_data.has_category(ItemDatabase.CATEGORY_SETTIBUTSU):
		return false

	# スタック可能な場合、既存スロットへの追加余地をチェック
	if item_data.stackable:
		for slot in slots:
			if slot != null and slot["item_id"] == item_id:
				if slot["count"] + count <= item_data.max_stack:
					return true

	# 空きスロットがあるかチェック
	for slot in slots:
		if slot == null:
			return true

	return false


## アイテムをインベントリに追加
func add_item(item_id: String, count: int = 1, item_scale: Vector2 = Vector2.ZERO) -> bool:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		return false

	# 設置物カテゴリのアイテムはスロットへの格納を拒否
	if item_data.has_category("設置物") or item_data.has_category(ItemDatabase.CATEGORY_SETTIBUTSU):
		print("【インベントリ拒否】設置物カテゴリのアイテム '%s' はスロットに格納できません。" % item_data.name)
		return false

	var final_scale: Vector2 = item_scale
	if final_scale == Vector2.ZERO:
		final_scale = item_data.world_scale

	# 1. スタック可能なら既存の同アイテムスロットへ加算
	if item_data.stackable:
		for i in range(max_slots):
			var slot = slots[i]
			if slot != null and slot["item_id"] == item_id:
				var space = item_data.max_stack - slot["count"]
				if space > 0:
					var add_amount = min(space, count)
					slot["count"] += add_amount
					count -= add_amount
					item_added.emit(item_id, i, add_amount)
					inventory_updated.emit()
					inventory_message.emit("【%s】を拾った" % item_data.name)
					if count <= 0:
						return true

	# 2. 空きスロットに新しく格納
	while count > 0:
		var empty_index = _find_empty_slot()
		if empty_index == -1:
			inventory_message.emit("持ち物がいっぱいです")
			return false

		var add_amount = min(count, item_data.max_stack if item_data.stackable else 1)
		slots[empty_index] = {
			"item_id": item_id,
			"count": add_amount,
			"item_scale": final_scale
		}
		count -= add_amount
		item_added.emit(item_id, empty_index, add_amount)
		inventory_updated.emit()
		inventory_message.emit("【%s】を拾った" % item_data.name)

	return true


## 指定のアイテムIDを所持しているか確認
func has_item(item_id: String) -> bool:
	for slot in slots:
		if slot != null and typeof(slot) == TYPE_DICTIONARY and slot.get("item_id", "") == item_id and slot.get("count", 0) > 0:
			return true
	return false


## 指定カテゴリのアイテムを1つ以上所持しているか確認
func has_item_in_category(category_name: String) -> bool:
	for slot in slots:
		if slot != null and typeof(slot) == TYPE_DICTIONARY and slot.get("count", 0) > 0:
			var item_id: String = slot.get("item_id", "")
			var item_data = ItemDatabase.get_item(item_id)
			if item_data:
				if item_data.has_category(category_name) or (category_name == "食べ物" and item_data.has_category(ItemDatabase.CATEGORY_FOOD)):
					return true
	return false


## 指定のアイテムIDを所持スロットから消費/削除
func remove_item_by_id(item_id: String, count: int = 1) -> bool:
	for i in range(max_slots):
		var slot = slots[i]
		if slot != null and typeof(slot) == TYPE_DICTIONARY and slot.get("item_id", "") == item_id:
			return remove_item_at(i, count)
	return false



## 空きスロットのインデックスを取得（なければ-1）
func _find_empty_slot() -> int:
	for i in range(max_slots):
		if slots[i] == null:
			return i
	return -1


## ----------------------------------------------------
## アイテム削除・使用関連
## ----------------------------------------------------
## スロットインデックスのアイテムを取得
func get_slot(slot_index: int) -> Dictionary:
	if slot_index >= 0 and slot_index < max_slots and slots[slot_index] != null:
		return slots[slot_index]
	return {}


## 2つのスロットの入れ替え
func swap_slots(index_a: int, index_b: int) -> void:
	if index_a < 0 or index_a >= max_slots or index_b < 0 or index_b >= max_slots:
		return
	var temp = slots[index_a]
	slots[index_a] = slots[index_b]
	slots[index_b] = temp
	inventory_updated.emit()



## 指定スロットのアイテムを使用
func use_item_at(slot_index: int, user: Node = null, target: Node = null) -> bool:
	var slot = get_slot(slot_index)
	if slot.is_empty():
		return false

	var item_id: String = slot["item_id"]
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		return false

	# 効果実行
	var success = ItemDatabase.execute_item_effect(item_id, user, target)
	if success:
		var effect_msg = ItemDatabase.get_item_effect_message(item_id)
		if effect_msg != "":
			inventory_message.emit(effect_msg)
		item_used.emit(item_id, slot_index)

		# usable == true の場合のみアイテムを消費する
		if item_data.usable:
			remove_item_at(slot_index, 1)
		return true

	return false


## 指定スロットからアイテム数を減らす
func remove_item_at(slot_index: int, count: int = 1) -> bool:
	var slot = get_slot(slot_index)
	if slot.is_empty():
		return false

	var item_id: String = slot["item_id"]
	slot["count"] -= count
	item_removed.emit(item_id, slot_index, count)

	if slot["count"] <= 0:
		slots[slot_index] = null

	inventory_updated.emit()
	return true


## ----------------------------------------------------
## 将来的な合成システム拡張ポイント
## ----------------------------------------------------
func _register_default_recipes() -> void:
	# 明示的デフォルトレシピの登録
	register_recipe("bloodpack", "hasami", "kusai_ti")
	register_recipe("fuku", "pacemaker", "migawari")

	# ItemDatabase から gousei レシピを自動登録
	if ItemDatabase:
		for item_id in ItemDatabase._items:
			var item_data = ItemDatabase._items[item_id]
			if item_data and item_data.gousei != "":
				_parse_and_register_gousei_string(item_data.gousei, item_data.id)


func _parse_and_register_gousei_string(gousei_str: String, default_result_id: String) -> void:
	# 書式: "item_a + item_b -> item_c" または "item_a + item_b"
	var parts = gousei_str.split("->")
	var ingredients_str = parts[0].strip_edges()
	var result_id = default_result_id
	if parts.size() > 1 and parts[1].strip_edges() != "":
		result_id = parts[1].strip_edges()

	var ingredients = ingredients_str.split("+")
	if ingredients.size() == 2 and result_id != "":
		var item_a = ingredients[0].strip_edges()
		var item_b = ingredients[1].strip_edges()
		register_recipe(item_a, item_b, result_id)


## 合成レシピの登録
func register_recipe(item_a: String, item_b: String, result_item: String) -> void:
	var key1 = item_a + "+" + item_b
	var key2 = item_b + "+" + item_a
	_recipes[key1] = result_item
	_recipes[key2] = result_item
	print("[InventoryManager] レシピ登録: '%s' + '%s' -> '%s'" % [item_a, item_b, result_item])


## 2つのアイテムIDから合成結果を取得（動的フォールバック付き）
func get_recipe_for_items(item_id_a: String, item_id_b: String) -> String:
	if item_id_a == "" or item_id_b == "":
		return ""

	var key1 = item_id_a + "+" + item_id_b
	if _recipes.has(key1):
		return _recipes[key1]

	var key2 = item_id_b + "+" + item_id_a
	if _recipes.has(key2):
		return _recipes[key2]

	# _recipes に未登録の場合、ItemDatabase から動的にレシピを検索・登録
	if ItemDatabase:
		for res_id in ItemDatabase._items:
			var item_data = ItemDatabase._items[res_id]
			if item_data and item_data.gousei != "":
				_parse_and_register_gousei_string(item_data.gousei, item_data.id)

	if _recipes.has(key1):
		return _recipes[key1]
	if _recipes.has(key2):
		return _recipes[key2]

	return ""


## 2つのスロットの合成結果を取得（存在しなければ空文字）
func get_recipe_result(slot_a_index: int, slot_b_index: int) -> String:
	var slot_a = get_slot(slot_a_index)
	var slot_b = get_slot(slot_b_index)
	if slot_a.is_empty() or slot_b.is_empty():
		return ""

	var id_a = slot_a.get("item_id", "")
	var id_b = slot_b.get("item_id", "")
	return get_recipe_for_items(id_a, id_b)


## 2つのスロットのアイテムを合成する処理
func combine_slots(slot_a_index: int, slot_b_index: int) -> bool:
	var result_id = get_recipe_result(slot_a_index, slot_b_index)
	if result_id == "":
		return false

	remove_item_at(slot_a_index, 1)
	remove_item_at(slot_b_index, 1)
	add_item(result_id, 1)
	var res_item = ItemDatabase.get_item(result_id)
	var res_name = res_item.name if res_item else result_id
	inventory_message.emit("合成成功！【%s】を作成しました" % res_name)
	return true

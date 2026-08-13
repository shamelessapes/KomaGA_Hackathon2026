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
	if item_data == null or not item_data.usable:
		return false

	# 効果実行
	var success = ItemDatabase.execute_item_effect(item_id, user, target)
	if success:
		inventory_message.emit("使用した: 【%s】" % item_data.name)
		item_used.emit(item_id, slot_index)
		
		# 使用後消費アイテムの場合、数を減らす（キーアイテム等は消費しない仕様にも拡張可）
		# 現段階ではデモとしてすべて消費
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
	# 例: 薬品A + 薬品B -> 中和剤 (将来用レシピ登録例)
	register_recipe("medicine_a", "medicine_b", "neutralizer")


## 合成レシピの登録
func register_recipe(item_a: String, item_b: String, result_item: String) -> void:
	var key1 = item_a + "+" + item_b
	var key2 = item_b + "+" + item_a
	_recipes[key1] = result_item
	_recipes[key2] = result_item


## 2つのスロットの合成結果を取得（存在しなければ空文字）
func get_recipe_result(slot_a_index: int, slot_b_index: int) -> String:
	var slot_a = get_slot(slot_a_index)
	var slot_b = get_slot(slot_b_index)
	if slot_a.is_empty() or slot_b.is_empty():
		return ""

	var key = slot_a["item_id"] + "+" + slot_b["item_id"]
	return _recipes.get(key, "")


## 2つのスロットのアイテムを合成する処理（将来のUI拡張用）
func combine_slots(slot_a_index: int, slot_b_index: int) -> bool:
	var result_id = get_recipe_result(slot_a_index, slot_b_index)
	if result_id == "":
		inventory_message.emit("合成できません")
		return false

	remove_item_at(slot_a_index, 1)
	remove_item_at(slot_b_index, 1)
	add_item(result_id, 1)
	inventory_message.emit("合成成功！【%s】を作成しました" % ItemDatabase.get_item(result_id).name)
	return true

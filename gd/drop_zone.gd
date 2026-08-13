extends Control

## 画面全体へのドラッグ＆ドロップ（アイテムを捨てる）領域

@onready var inventory_ui: CanvasLayer = $".."


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("from_slot_index") and data.has("item_id")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var slot_index: int = data["from_slot_index"]
	var item_id: String = data["item_id"]

	if inventory_ui and inventory_ui.has_method("handle_item_drop_to_world"):
		inventory_ui.handle_item_drop_to_world(slot_index, item_id)

extends CanvasLayer

## インベントリ全体のUIを統括するコントローラー

@onready var grid_container: GridContainer = $MarginContainer/VBoxContainer/GridContainer
@onready var tooltip: Control = $ItemTooltip
@onready var message_label: Label = $MarginContainer/VBoxContainer/MessageLabel

@export var slot_scene: PackedScene = preload("res://tscn/item_slot.tscn")

var slot_nodes: Array = []


func _ready() -> void:
	if message_label:
		message_label.text = ""

	_setup_slots()

	# InventoryManagerのシグナル接続
	if InventoryManager:
		InventoryManager.inventory_updated.connect(_on_inventory_updated)
		InventoryManager.inventory_message.connect(_show_message)
		_refresh_ui()


## 最大スロット数に応じたItemSlotノードの動的生成
func _setup_slots() -> void:
	# 既存ノードクリア
	for child in grid_container.get_children():
		child.queue_free()
	slot_nodes.clear()

	if InventoryManager == null:
		return

	var count = InventoryManager.max_slots
	for i in range(count):
		var slot_instance = slot_scene.instantiate()
		slot_instance.slot_index = i
		grid_container.add_child(slot_instance)
		slot_nodes.append(slot_instance)

		# スロットのシグナル接続
		slot_instance.slot_right_clicked.connect(_on_slot_right_clicked)
		slot_instance.slot_hovered.connect(_on_slot_hovered)
		slot_instance.slot_unhovered.connect(_on_slot_unhovered)


## 全スロットUIの描画更新
func _refresh_ui() -> void:
	if InventoryManager == null:
		return

	for i in range(slot_nodes.size()):
		var slot_node = slot_nodes[i]
		var slot_data = InventoryManager.get_slot(i)
		if not slot_data.is_empty():
			slot_node.update_slot(slot_data["item_id"], slot_data["count"])
		else:
			slot_node.clear_slot()


## シグナル受信：データ更新時
func _on_inventory_updated() -> void:
	_refresh_ui()


## シグナル受信：スロット右クリック（アイテム使用）
func _on_slot_right_clicked(slot_index: int) -> void:
	if InventoryManager:
		var player_node = get_tree().get_first_node_in_group("player")
		
		# プレイヤーが隠れ状態の場合、使用をブロック
		if player_node and "is_hidden" in player_node and player_node.is_hidden:
			InventoryManager.inventory_message.emit("今はアイテムが使えない！")
			return

		InventoryManager.use_item_at(slot_index, player_node, null)



## シグナル受信：ホバー開始（ツールチップ表示）
func _on_slot_hovered(item_id: String) -> void:
	if tooltip and tooltip.has_method("display_item_info"):
		tooltip.display_item_info(item_id)


## シグナル受信：ホバー終了（ツールチップ非表示）
func _on_slot_unhovered() -> void:
	if tooltip and tooltip.has_method("hide_tooltip"):
		tooltip.hide_tooltip()


var _message_tween: Tween


## 画面上に短いメッセージ（通知）を表示
func _show_message(msg: String) -> void:
	if msg == "":
		return
	print("【InventoryUI Notification】", msg)
	if message_label:
		message_label.text = msg
		message_label.modulate.a = 1.0
		if _message_tween and _message_tween.is_valid():
			_message_tween.kill()
		_message_tween = create_tween()
		_message_tween.tween_property(message_label, "modulate:a", 0.0, 2.5).set_delay(1.0)


## 画面上（UI外）にドロップされた際アイテムをマップ上に捨てる処理
func handle_item_drop_to_world(slot_index: int, item_id: String) -> void:
	if InventoryManager == null:
		return

	var current_scene = get_tree().current_scene
	if current_scene == null:
		return

	# スロットから保持しているscale情報を取得
	var slot_data = InventoryManager.get_slot(slot_index)
	var saved_scale: Vector2 = Vector2.ONE
	if not slot_data.is_empty() and slot_data.has("item_scale"):
		saved_scale = slot_data["item_scale"]

	# ドロップ位置（正確なワールドマウス座標）を取得
	var raw_drop_pos: Vector2 = current_scene.get_global_mouse_position()

	# NavigationRegion2Dの領域内へ強制補正（最も近い移動可能ポイントを算出）
	var final_drop_pos: Vector2 = raw_drop_pos
	var nav_map = current_scene.get_world_2d().get_navigation_map()
	if nav_map.is_valid():
		final_drop_pos = NavigationServer2D.map_get_closest_point(nav_map, raw_drop_pos)

	# マップ上へWorldItemを動的生成し、scaleと補正後の位置で復元
	var world_item_scene = preload("res://tscn/world_item.tscn")
	var world_item = world_item_scene.instantiate()
	world_item.item_id = item_id

	if item_id == "migawari" and current_scene and "migawari_world_scale" in current_scene:
		world_item.scale = current_scene.migawari_world_scale
	elif item_id == "kusai_ti" and current_scene and "kusai_ti_world_scale" in current_scene:
		world_item.scale = current_scene.kusai_ti_world_scale
	else:
		world_item.scale = saved_scale

	var items_container = current_scene.get_node_or_null("Items")
	if items_container:
		items_container.add_child(world_item)
	else:
		current_scene.add_child(world_item)

	world_item.global_position = final_drop_pos

	if current_scene.has_method("_setup_node_hover_outline"):
		current_scene._setup_node_hover_outline(world_item)


	var item_data = ItemDatabase.get_item(item_id)
	var item_name = item_data.name if item_data != null else item_id

	# インベントリから削除
	InventoryManager.remove_item_at(slot_index, 1)
	InventoryManager.inventory_message.emit("【%s】を捨てた" % item_name)

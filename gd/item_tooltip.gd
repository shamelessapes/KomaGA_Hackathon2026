extends Control

## アイテム情報ツールチップUI

@onready var panel: Panel = $Panel
@onready var name_label: Label = $Panel/VBoxContainer/NameLabel
@onready var desc_label: Label = $Panel/VBoxContainer/DescLabel

## オプション：マウスへの追従オフセット
@export var offset: Vector2 = Vector2(15, 15)


func _ready() -> void:
	hide() # 初期状態は非表示
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if visible:
		# マウスカーソル位置の追従
		global_position = get_global_mouse_position() + offset


## ツールチップの表示
func display_item_info(item_id: String) -> void:
	var item_data = ItemDatabase.get_item(item_id)
	if item_data == null:
		hide()
		return

	name_label.text = item_data.name
	desc_label.text = item_data.description
	
	show()


## ツールチップの非表示
func hide_tooltip() -> void:
	hide()

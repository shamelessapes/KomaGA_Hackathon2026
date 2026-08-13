extends Node2D

## マップ上に配置されるアイテム共通スクリプト

@export var item_id: String = "godot_kun"

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var area_2d: Area2D = $Area2D


func _ready() -> void:
	# Area2Dがアイテム判定用の "item" グループに属していることを担保
	if area_2d and not area_2d.is_in_group("item"):
		area_2d.add_to_group("item")

	_setup_item_visual()


## ItemDatabaseからアイコンなどの見た目情報を適用
func _setup_item_visual() -> void:
	if not ItemDatabase:
		return

	var item_data = ItemDatabase.get_item(item_id)
	if item_data and item_data.icon:
		sprite_2d.texture = item_data.icon
	else:
		# アイコンがない場合、デフォ画像やプレースホルダーを作成
		var img = Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 0.8, 0.2))
		sprite_2d.texture = ImageTexture.create_from_image(img)

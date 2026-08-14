extends Node

## アイテムマスターデータベース
## ゲーム内に登場するすべてのアイテムデータと効果定義を一元管理します。

## アイテムデータ構造を表す型定義
class ItemData:
	var id: String = ""
	var name: String = ""
	var description: String = ""
	var icon: Texture2D = null
	var usable: bool = false
	var stackable: bool = false
	var max_stack: int = 1
	var world_scale: Vector2 = Vector2(1.0, 1.0)
	var effect_handler: Callable = Callable()

	func _init(p_id: String, p_name: String, p_description: String, p_usable: bool = true, p_stackable: bool = false, p_max_stack: int = 1, p_icon: Texture2D = null, p_effect: Callable = Callable(), p_world_scale: Vector2 = Vector2(1.0, 1.0)):
		id = p_id
		name = p_name
		description = p_description
		usable = p_usable
		stackable = p_stackable
		max_stack = p_max_stack
		icon = p_icon
		effect_handler = p_effect
		world_scale = p_world_scale


# アイテムデータベース辞書 [id: String, ItemData]
var _items: Dictionary = {}

func _ready() -> void:
	_register_default_items()


## 初期アイテムの登録（将来的にJSONやResource外部読み込みへの拡張も可能）
func _register_default_items() -> void:
	# デフォルトプレースホルダーアイコンの作成（アイコン画像未設定時に使用）
	var _placeholder_tex = _create_placeholder_icon()

	# 1. テストアイテム
	register_item(ItemData.new(
		"godot_kun",
		"Godotくん",
		"デバック専用アイテム。使っても何も起こらない。",
		true,
		false,
		99,
		preload("res://image/icon.svg"),
		func(_user, _target): print("【効果実行】Godotくんを使用した。何も起こらない。"),
		Vector2(0.5, 0.5) 
	))



## 新規アイテムの登録API
func register_item(item_data: ItemData) -> void:
	_items[item_data.id] = item_data


## アイテムデータの取得
func get_item(item_id: String) -> ItemData:
	if _items.has(item_id):
		return _items[item_id]
	push_warning("ItemDatabase: アイテムID '%s' は登録されていません。" % item_id)
	return null


## アイテムが存在するか確認
func has_item(item_id: String) -> bool:
	return _items.has(item_id)


## アイテム効果の実行ハンドラ（スイッチ文・巨大if文を回避し、Callableを実行）
func execute_item_effect(item_id: String, user: Node = null, target: Node = null) -> bool:
	var data = get_item(item_id)
	if data == null:
		return false
	
	if not data.usable:
		print("このアイテムは使用できません: ", data.name)
		return false

	if data.effect_handler.is_valid():
		data.effect_handler.call(user, target)
		return true
	else:
		print("使用した: ", data.name)
		return true


## 簡易アイコン生成ヘルパー（アイコンテクスチャ指定がない場合の視覚用）
func _create_placeholder_icon() -> ImageTexture:
	var img = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.6, 0.9, 0.8))
	return ImageTexture.create_from_image(img)

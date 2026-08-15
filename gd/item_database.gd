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

	## アイテムのカテゴリ一覧 (モンスター弱点判定用: 音, 匂い, 動く, 温度, 食べ物, 生き物, 設置物, 合成)
	var categories: Array[String] = []

	## 設置物用設定 (必要アイテムID)
	var settibutsu: String = ""

	## 合成用設定 (例: "fuku + pacemaker -> migawari")
	var gousei: String = ""

	## 効果音再生用ファイルパス ("音" カテゴリ等)
	var sound_path: String = ""

	func _init(
		p_id: String,
		p_name: String,
		p_description: String,
		p_usable: bool = true,
		p_stackable: bool = false,
		p_max_stack: int = 1,
		p_icon: Texture2D = null,
		p_effect: Callable = Callable(),
		p_world_scale: Vector2 = Vector2(1.0, 1.0),
		p_categories: Array[String] = [],
		p_settibutsu: String = "",
		p_gousei: String = "",
		p_sound_path: String = ""
	):
		id = p_id
		name = p_name
		description = p_description
		usable = p_usable
		stackable = p_stackable
		max_stack = p_max_stack
		icon = p_icon
		effect_handler = p_effect
		world_scale = p_world_scale
		categories = p_categories
		settibutsu = p_settibutsu
		gousei = p_gousei
		sound_path = p_sound_path

	## 指定カテゴリを持っているか判定
	func has_category(category_name: String) -> bool:
		return category_name in categories


# 有効なカテゴリ定数定義
const CATEGORY_SOUND: String = "音"
const CATEGORY_SMELL: String = "匂い"
const CATEGORY_MOTION: String = "動く"
const CATEGORY_TEMPERATURE: String = "温度"
const CATEGORY_FOOD: String = "食べ物"
const CATEGORY_CREATURE: String = "生き物"
const CATEGORY_SETTIBUTSU: String = "設置物"
const CATEGORY_GOUSEI: String = "合成"

# アイテムデータベース辞書 [id: String, ItemData]
var _items: Dictionary = {}

func _ready() -> void:
	_register_default_items()


## 初期アイテムの登録（将来的にJSONやResource外部読み込みへの拡張も可能）
func _register_default_items() -> void:
	# デフォルトプレースホルダーアイコンの作成（アイコン画像未設定時に使用）
	var _placeholder_tex = _create_placeholder_icon()

	# 0. テストアイテム (カテゴリなし)
	register_item(ItemData.new(
		"godot_kun",
		"Godotくん",
		"デバック専用アイテム。使っても何も起こらない。",
		true,
		false,
		99,
		preload("res://image/icon.svg"),
		func(_user, _target): print("【効果実行】Godotくんを使用した。何も起こらない。"),
		Vector2(0.5, 0.5),
	))
	
# 1. ナースコール
	register_item(ItemData.new(
		"nursecall",
		"ナースコール",
		"看護師さんを呼べるベル、必要な時だけ押そう。",
		true, #（変えないで下さい）
		false, #（変えないで下さい）
		99, #（変えないで下さい）
		preload("res://image/icon.svg"), #（変えないで下さい）
		func(_user, _target): print("ナースコールを使用した。音が部屋に響き続けてる。"), #（変えないで下さい）
		Vector2(1.0, 1.0),
		["音"],
		"res://sound/ドア閉.mp3"
	))


# 2.薬剤
	register_item(ItemData.new(
		"medicine",
		"薬剤",
		"心臓の動きが弱くなるアブナイ薬。",
		true, #（変えないで下さい）
		false, #（変えないで下さい）
		99, #（変えないで下さい）
		preload("res://image/icon.svg"), #（変えないで下さい）
		func(_user, _target): print("薬剤を使用した。拍動が著しく低下した。"), #（変えないで下さい）
		Vector2(1.0, 1.0) , #（変えないで下さい）
		["音"]
	))


# 3. 血液パック
	register_item(ItemData.new(
		"bloodpack",
		"血液パック",
		"血液パック。大量の血が入ってる。",
		false, #（変えないで下さい）
		false, #（変えないで下さい）
		99, #（変えないで下さい）
		preload("res://image/icon.svg"), #（変えないで下さい）
		func(_user, _target): print("このアイテムは何かと組み合わせる必要がありそう。"), #（変えないで下さい）
		Vector2(1.0, 1.0) ,
		["匂い"]
	))


# 4. ハサミ
	register_item(ItemData.new(
		"hasami",
		"ハサミ",
		"お花を剪定するためのハサミ、けっこう鋭い。",
		false, #（変えないで下さい）
		false, #（変えないで下さい）
		99, #（変えないで下さい）
		preload("res://image/icon.svg"), #（変えないで下さい）
		func(_user, _target): print("このアイテムは何かと組み合わせる必要がありそう。"), #（変えないで下さい）
		Vector2(1.0, 1.0)
	))


# 5. アルコールスプレー
	register_item(ItemData.new(
		"aruko-ru",
		"他患者アイテム",
		"アルコールスプレー。アルコールくさい。",
		true, #（変えないで下さい）
		false, #（変えないで下さい）
		99, #（変えないで下さい）
		preload("res://image/icon.svg"), #（変えないで下さい）
		func(_user, _target): print("アルコールスプレーを振りまいた。周囲がアルコールくさい。"), #（変えないで下さい）
		Vector2(1.0, 1.0),
		["匂い"]
	))


# 6. テレビ
	register_item(ItemData.new(
		"tv",
		"テレビ",
		"病室に備え付けてあるテレビ、リモコンを使って好きな番組を見ることが出来る。",
		false, #（変えないで下さい）
		false, #（変えないで下さい）
		99, #（変えないで下さい）
		preload("res://image/icon.svg"), #（変えないで下さい）
		func(_user, _target): print("このアイテムは何かと組み合わせる必要がありそう。"), #（変えないで下さい）
		Vector2(1.0, 1.0), #（変えないで下さい）
		[CATEGORY_SETTIBUTSU,"音","動き"],
		"remokon",
		"res://sound/ドア閉.mp3"
	))


# 7. リモコン
	register_item(ItemData.new(
		"remokon",
		"リモコン",
		"テレビのリモコン、何故かよくなくしちゃう。",
		false, #（変えないで下さい）
		false, #（変えないで下さい）
		99, #（変えないで下さい）
		preload("res://image/icon.svg"), #（変えないで下さい）
		func(_user, _target): print("このアイテムは何かと組み合わせる必要がありそう。"), #（変えないで下さい）
		Vector2(1.0, 1.0)  #（変えないで下さい）
	))


# 8. 血圧計
	register_item(ItemData.new(
		"ketuatu",
		"血圧計",
		"血圧計、ボタンを押すと一定間隔で収縮する。",
		true, #（変えないで下さい）
		false, #（変えないで下さい）
		99, #（変えないで下さい）
		preload("res://image/icon.svg"), #（変えないで下さい）
		func(_user, _target): print("血圧計を使用した。血圧計が伸び縮みし続ける。"), #（変えないで下さい）
		Vector2(1.0, 1.0) ,
		["動き"]
	))


# 9. ドライヤー
	register_item(ItemData.new(
		"doraiya-",
		"ドライヤー",
		"ドライヤー、髪を乾かせる。でも病室にいるあいだはお風呂に入れない。",
		false, #（変えないで下さい）
		false, #（変えないで下さい）
		99, #（変えないで下さい）
		preload("res://image/icon.svg"), #（変えないで下さい）
		func(_user, _target): print("このアイテムは何かと組み合わせる必要がありそう。"), #（変えないで下さい）
		Vector2(1.0, 1.0) ,
		["音","温度"]
	))


# 10. コンセント
	register_item(ItemData.new(
		"konsento",
		"コンセント",
		"よくある、ありきたりなコンセント。",
		false, #（変えないで下さい）
		false, #（変えないで下さい）
		99, #（変えないで下さい）
		preload("res://image/konsento.png"), #（変えないで下さい）
		func(_user, _target): print("このアイテムは使用できないようだ。"), #（変えないで下さい）
		Vector2(1.0, 1.0), #（変えないで下さい）
		[CATEGORY_SETTIBUTSU],
		"doraiya-"
	))


# 11. お見舞い果物
	register_item(ItemData.new(
		"kudamono",
		"お見舞い果物",
		"誰かが置いてくれたお見舞いのリンゴ。",
		true, #（変えないで下さい）
		false, #（変えないで下さい）
		99, #（変えないで下さい）
		preload("res://image/icon.svg"), #（変えないで下さい）
		func(_user, _target): print("お見舞い果物を食べた。真っ赤なリンゴ。"), #（変えないで下さい）
		Vector2(1.0, 1.0) ,
		["食べ物"]
	))


# 12. 病院食
	register_item(ItemData.new(
		"food",
		"病院食",
		"看護師さんが持ってきてくれる病院食。",
		true, #（変えないで下さい）
		false, #（変えないで下さい）
		99, #（変えないで下さい）
		preload("res://image/icon.svg"), #（変えないで下さい）
		func(_user, _target): print("病院食を食べた。おなかいっぱい。"), #（変えないで下さい）
		Vector2(1.0, 1.0),
		["食べ物"]
	))


# 13. ペースメーカー
	register_item(ItemData.new(
		"pacemaker",
		"ペースメーカー",
		"ペースメーカー、電気で心臓の動きを助けてくれるらしい。",
		false, #（変えないで下さい）
		false, #（変えないで下さい）
		99, #（変えないで下さい）
		preload("res://image/icon.svg"), #（変えないで下さい）
		func(_user, _target): print("このアイテムは使用できないようだ。"), #（変えないで下さい）
		Vector2(1.0, 1.0)  #（変えないで下さい）
	))



# 15. 自分の服
	register_item(ItemData.new(
		"fuku",
		"自分の服",
		"入院中の患者はみんな着てる服、でも包帯を頭に巻いてるのは僕だけ。",
		false, #（変えないで下さい）
		false, #（変えないで下さい）
		99, #（変えないで下さい）
		preload("res://image/icon.svg"), #（変えないで下さい）
		func(_user, _target): print("このアイテムは何かと組み合わせる必要がありそう。"), #（変えないで下さい）
		Vector2(1.0, 1.0)  #（変えないで下さい）
	))


# 16. 身代わり人形
	register_item(ItemData.new(
		"migawari",
		"身代わり人形",
		"これをベッドに置けば、ヤツらをだませるかも",
		true, 
		false, 
		99, 
		preload("res://image/icon.svg"), 
		func(_user, _target): print("身代わり人形をおいた。"), 
		Vector2(1.0, 1.0),
		[CATEGORY_GOUSEI],
		"fuku + pacemaker -> migawari"
	))
	
	
# 17. 保冷剤
	register_item(ItemData.new(
		"horeizai",
		"保冷剤",
		"ひんやり冷たい保冷剤。",
		false, #（変えないで下さい）
		false, #（変えないで下さい）
		99, #（変えないで下さい）
		preload("res://image/icon.svg"), #（変えないで下さい）
		func(_user, _target): print("ひんやりして冷たい。"), #（変えないで下さい）
		Vector2(1.0, 1.0),
		["温度"]
	))
	
	
# 18. 身代わり人形
	register_item(ItemData.new(
		"kusai_ti",
		"破られた血液パック",
		"敗れた血液パック。血の匂いがぷんぷんする。",
		true, 
		false, 
		99, 
		preload("res://image/icon.svg"), 
		func(_user, _target): print("血をぶちまけた。部屋に血の匂いが充満する！"), 
		Vector2(1.0, 1.0),
		[CATEGORY_GOUSEI,"匂い"],
		"bloodpack + hasami -> kusai_ti"
	))


## 設置物使用時の効果実行フック（今後の設置物固有処理の拡張用）
func execute_settibutsu_effect(item_id: String, required_item_id: String, user: Node = null, target: Node = null) -> void:
	var data = get_item(item_id)
	if data == null:
		return

	print("[設置物効果実行] 設置物: '%s' を使用 (必要アイテム: '%s')" % [data.name, required_item_id])

	if data.effect_handler.is_valid():
		data.effect_handler.call(user, target)


## 新規アイテムの登録API
func register_item(item_data: ItemData) -> void:
	_items[item_data.id] = item_data
	if item_data.gousei != "" and InventoryManager != null and InventoryManager.has_method("_parse_and_register_gousei_string"):
		InventoryManager._parse_and_register_gousei_string(item_data.gousei, item_data.id)


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

	if data.effect_handler.is_valid():
		data.effect_handler.call(user, target)
		return true
	else:
		if not data.usable:
			print("このアイテムは使用できません: ", data.name)
		else:
			print("使用した: ", data.name)
		return true


## アイテム使用時の効果メッセージ（printテキスト）を取得
func get_item_effect_message(item_id: String) -> String:
	var data = get_item(item_id)
	if data == null:
		return ""

	var messages = {
		"godot_kun": "【効果実行】Godotくんを使用した。何も起こらない。",
		"nursecall": "ナースコールを使用した。音が部屋に響き続けてる。",
		"medicine": "薬剤を使用した。拍動が著しく低下した。",
		"bloodpack": "このアイテムは何かと組み合わせる必要がありそう。",
		"hasami": "このアイテムは何かと組み合わせる必要がありそう。",
		"aruko-ru": "アルコールスプレーを振りまいた。周囲がアルコールくさい。",
		"tv": "このアイテムは何かと組み合わせる必要がありそう。",
		"remokon": "このアイテムは何かと組み合わせる必要がありそう。",
		"ketuatu": "血圧計を使用した。血圧計が伸び縮みし続ける。",
		"doraiya-": "このアイテムは何かと組み合わせる必要がありそう。",
		"konsento": "このアイテムは使用できないようだ。",
		"kudamono": "お見舞い果物を食べた。真っ赤なリンゴ。",
		"food": "病院食を食べた。おなかいっぱい。",
		"pacemaker": "このアイテムは使用できないようだ。",
		"makura": "まくらを使用した。",
		"fuku": "このアイテムは何かと組み合わせる必要がありそう。",
		"migawari": "身代わり人形をおいた。",
		"horeizai": "ひんやりして冷たい。",
		"kusai_ti": "血をぶちまけた。部屋に血の匂いが充満する！"
	}

	return messages.get(item_id, "")


## 簡易アイコン生成ヘルパー（アイコンテクスチャ指定がない場合の視覚用）
func _create_placeholder_icon() -> ImageTexture:
	var img = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.6, 0.9, 0.8))
	return ImageTexture.create_from_image(img)

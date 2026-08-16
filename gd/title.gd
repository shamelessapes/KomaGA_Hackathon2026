extends Node2D

@onready var btn_nyuin: TextureButton = $"Control/Button nyuin"
@onready var btn_byousitu: TextureButton = $"Control/Button byousitu"
@onready var btn_asobi: TextureButton = $"Control/Button asobi"
@onready var btn_taiin: TextureButton = $"Control/Button taiin"

var popup_control: Control
var popup_close_btn: Button


func _ready() -> void:
	Global.fade_in(Color.BLACK)
	
	# ボタンシグナル接続およびホバー演出設定
	if btn_nyuin:
		btn_nyuin.pressed.connect(_on_nyuin_pressed)
		_setup_button_hover(btn_nyuin)

	if btn_byousitu:
		btn_byousitu.pressed.connect(_on_byousitu_pressed)
		_setup_button_hover(btn_byousitu)

	if btn_asobi:
		btn_asobi.pressed.connect(_on_asobi_pressed)
		_setup_button_hover(btn_asobi)

	if btn_taiin:
		btn_taiin.pressed.connect(_on_taiin_pressed)
		_setup_button_hover(btn_taiin)

	# セーブデータの有無による「病室に戻る」ボタンの状態管理
	_update_byousitsu_button_state()

	# 遊び方ポップアップの構築
	_setup_asobi_popup()

	var audio_player = get_node_or_null("AudioStreamPlayer")
	if audio_player and not audio_player.playing:
		audio_player.play()


func _update_byousitsu_button_state() -> void:
	if btn_byousitu == null:
		return
	var has_save: bool = false
	if SaveManager:
		has_save = SaveManager.has_save_data()

	if has_save:
		btn_byousitu.disabled = false
		btn_byousitu.modulate.a = 1.0
	else:
		btn_byousitu.disabled = true
		btn_byousitu.modulate.a = 0.5


## ボタン枠線のホバー白点灯演出
func _setup_button_hover(btn: Control) -> void:
	if btn == null:
		return

	var border = Panel.new()
	border.name = "HoverBorder"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.set_anchors_preset(Control.PRESET_FULL_RECT)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(1, 1, 1, 1)
	style.set_border_width_all(3)
	border.add_theme_stylebox_override("panel", style)
	border.visible = false
	btn.add_child(border)

	btn.mouse_entered.connect(func():
		if btn is BaseButton and (btn as BaseButton).disabled:
			return
		border.visible = true
	)
	btn.mouse_exited.connect(func():
		border.visible = false
	)


## 「遊び方」ポップアップ画面の構築
func _setup_asobi_popup() -> void:
	popup_control = Control.new()
	popup_control.name = "AsobiPopup"
	popup_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_control.size = Vector2(1152, 648)
	popup_control.visible = false
	popup_control.z_index = 50
	add_child(popup_control)

	# 1. 背景の暗いオーバーレイ（背面ボタンの入力遮断）
	var overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	popup_control.add_child(overlay)

	# 2. ポップアップ本体のパネル
	var window_panel = PanelContainer.new()
	window_panel.name = "WindowPanel"
	window_panel.custom_minimum_size = Vector2(800, 480)
	window_panel.layout_mode = 1
	window_panel.anchors_preset = Control.PRESET_CENTER
	window_panel.anchor_left = 0.5
	window_panel.anchor_top = 0.5
	window_panel.anchor_right = 0.5
	window_panel.anchor_bottom = 0.5
	window_panel.offset_left = -400
	window_panel.offset_top = -240
	window_panel.offset_right = 400
	window_panel.offset_bottom = 240
	window_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	window_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	panel_style.border_color = Color(0.9, 0.9, 0.9, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	window_panel.add_theme_stylebox_override("panel", panel_style)
	popup_control.add_child(window_panel)

	# 3. マージン＆レイアウト
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 35)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 35)
	margin.add_theme_constant_override("margin_bottom", 25)
	window_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	# 4. フォント設定 (しっぽり明朝, 25pt, 白文字)
	var font_res = load("res://font/shippori3/ShipporiMincho-OTF-Bold.otf") as Font

	var text_label = Label.new()
	text_label.name = "InstructionLabel"
	text_label.text = "【操作方法】\n移動：行きたい方向に向かって左クリック\n隠れる：隠れた居場所を右クリック\nアイテム取得：取得したいアイテムを右クリック\nアイテム使用：左上のアイテムアイコンを右クリックで使用\nアイテム合成：合成したいアイテム同士をドラッグで重ね合わせる。\nアイテム破棄：アイテムをドラッグで運んで破棄。"
	text_label.add_theme_color_override("font_color", Color.WHITE)
	text_label.add_theme_font_size_override("font_size", 25)
	if font_res:
		text_label.add_theme_font_override("font", font_res)
	vbox.add_child(text_label)

	# 5. 「閉じる」ボタン
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	popup_close_btn = Button.new()
	popup_close_btn.name = "ButtonClose"
	popup_close_btn.text = "閉じる"
	popup_close_btn.custom_minimum_size = Vector2(160, 48)
	popup_close_btn.add_theme_color_override("font_color", Color.WHITE)
	popup_close_btn.add_theme_font_size_override("font_size", 22)
	if font_res:
		popup_close_btn.add_theme_font_override("font", font_res)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.2, 0.25, 0.9)
	btn_style.border_color = Color(0.6, 0.6, 0.6, 1.0)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	popup_close_btn.add_theme_stylebox_override("normal", btn_style)

	btn_hbox.add_child(popup_close_btn)

	_setup_button_hover(popup_close_btn)
	popup_close_btn.pressed.connect(_on_close_popup_pressed)


## 「入院する」処理 (新規ゲーム開始)
func _on_nyuin_pressed() -> void:
	if SaveManager:
		SaveManager.new_game()
	Global.change_scene_with_fade("res://tscn/byousitsu.tscn", Color.BLACK, 1.0)


## 「病室に戻る」処理 (セーブデータ復元＆再開)
func _on_byousitu_pressed() -> void:
	if SaveManager and SaveManager.has_save_data():
		SaveManager.load_game()
		Global.change_scene_with_fade("res://tscn/byousitsu.tscn", Color.BLACK, 1.0)


## 「遊び方」処理 (ポップアップ表示)
func _on_asobi_pressed() -> void:
	if popup_control:
		popup_control.visible = true


## ポップアップ閉じる処理
func _on_close_popup_pressed() -> void:
	if popup_control:
		popup_control.visible = false


## 「退院する」処理 (ゲーム終了)
func _on_taiin_pressed() -> void:
	get_tree().quit()

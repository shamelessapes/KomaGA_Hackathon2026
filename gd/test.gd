extends Node

func _ready() -> void:
	print("=== テスト開始 ===")
	print("Enterキー: 日付を進める（フェード付き）")
	print("Sキー: 探索フェーズ開始")
	print("Hキー: 隠れんぼフェーズ開始")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):  
		print("--- 日付変更テスト ---")
		Scenetransition.change_day()

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_S:
				print("--- 探索フェーズ開始テスト ---")
				Phasemanager.start_search_phase()
			KEY_H:
				print("--- 隠れんぼフェーズ開始テスト ---")
				Phasemanager.start_hide_phase()

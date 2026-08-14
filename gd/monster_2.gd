# ========================================================
# ２．ばけもの（ちょうかく）
# ========================================================

extends MonsterBase

func _init() -> void:
	target_day = 2
	weakness_category = ["音"]

# モンスター2固有の拡張処理が必要な場合は以下をオーバーライド可能
# func _on_movement_update(delta: float) -> void:
# 	super._on_movement_update(delta)

# func _on_checkpoint_reached(index: int) -> void:
# 	super._on_checkpoint_reached(index)

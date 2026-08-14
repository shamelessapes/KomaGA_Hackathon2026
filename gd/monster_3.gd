# ========================================================
# ３．ばけもの（きゅうかく）
# ========================================================

extends MonsterBase

func _init() -> void:
	target_day = 3
	weakness_category = ["匂い"]

# モンスター3固有の拡張処理が必要な場合は以下をオーバーライド可能
# func _on_movement_update(delta: float) -> void:
# 	super._on_movement_update(delta)

# func _on_checkpoint_reached(index: int) -> void:
# 	super._on_checkpoint_reached(index)

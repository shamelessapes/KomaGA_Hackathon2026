extends Node2D

@onready var btn_nyuin = $"Button nyuin"    
@onready var btn_byousitu = $"Button byousitu"  
@onready var btn_asobi = $"Button asobi"    
@onready var btn_taiin = $"Button taiin"      

func _ready() -> void:
	Global.fade_in()

	btn_nyuin.pressed.connect(_on_nyuin_pressed)
	btn_byousitu.pressed.connect(_on_byousitu_pressed)
	btn_asobi.pressed.connect(_on_asobi_pressed)
	btn_taiin.pressed.connect(_on_taiin_pressed)


func _on_nyuin_pressed() -> void:
	pass


func _on_byousitu_pressed() -> void:
	pass


func _on_asobi_pressed() -> void:
	pass


func _on_taiin_pressed() -> void:
	get_tree().quit()

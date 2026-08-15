extends Node2D

@onready var btn_nyuin = $"Control/Button nyuin"    
@onready var btn_byousitu = $"Control/Button byousitu"  
@onready var btn_asobi = $"Control/Button asobi"    
@onready var btn_taiin = $"Control/Button taiin"      

func _ready() -> void:
	#Global.fade_in(Color.BLACK)

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

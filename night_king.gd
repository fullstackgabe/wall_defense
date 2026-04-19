class_name NightKing
extends "res://enemy_base.gd"

func _setup() -> void:
	max_hp       = 50.0
	hp           = 50.0
	move_speed   = 45.0
	lives_damage = 1
	gold_reward  = 15
	char_folder  = "night_king"

class_name Skeleton
extends "res://enemy_base.gd"

## Vagante (esqueleto/wight): inimigo comum. O Night King é o chefe (o dobro do Jon Snow).

func _setup() -> void:
	max_hp       = 25.0
	hp           = 25.0
	melee_damage = 12.5
	move_speed   = 55.0
	lives_damage = 1
	gold_reward  = 10
	char_folder  = "skeleton"
	sprite_px    = 48.0   ## PNG de 48 px em 1:1 (boneco ≈ 45 px no mundo; Night King e Jon ≈ 49)

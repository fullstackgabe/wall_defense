class_name NightKing
extends "res://enemy_base.gd"

func _setup() -> void:
	## Dobro do Jon Snow (MAX_HP 200, ATTACK_DAMAGE 11) — pedido do usuário, 26/10/2026.
	max_hp       = 400.0
	hp           = 400.0
	move_speed   = 45.0
	lives_damage = 3      ## passou = perde 3 vidas (todas, no começo)
	gold_reward  = 50
	melee_damage = 22.0
	char_folder  = "night_king"
	sprite_px    = 116.0  ## PNG de 88 px a ~1,3× (boneco ≈ 49 px no mundo, altura do Jon)

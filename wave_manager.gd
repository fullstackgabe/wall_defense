class_name WaveManager
extends Node

const _Skeleton  = preload("res://skeleton.gd")
const _NightKing = preload("res://night_king.gd")

## A cada BOSS_EVERY envios (automáticos, a cada 3 s — main.SPAWN_INTERVAL), o Night King vem junto,
## pelo meio. Ele não entra na contagem.
const BOSS_EVERY := 10

var _map: Node2D
var _spawn_parent: Node2D
var _sends: int = 0

# ---------------------------------------------------------------------------

func setup(map: Node2D, spawn_parent: Node2D) -> void:
	_map          = map
	_spawn_parent = spawn_parent

func spawn_pair() -> void:
	_sends += 1
	_spawn_one(_Skeleton, "A")
	_spawn_one(_Skeleton, "B")
	if _sends % BOSS_EVERY == 0:
		_spawn_one(_NightKing, "C")

func _spawn_one(kind, lane: String) -> void:
	var enemy = kind.new()
	_spawn_parent.add_child(enemy)
	enemy.start_path(_map.get_full_path(lane))
	enemy.died.connect(_on_enemy_died)
	enemy.escaped.connect(_on_enemy_escaped)

func _on_enemy_died(enemy, reward: int) -> void:
	GameState.add_gold(reward)

func _on_enemy_escaped(enemy, damage: int) -> void:
	GameState.lose_lives(damage)

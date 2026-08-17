class_name WaveManager
extends Node

const _NightKing = preload("res://night_king.gd")

var _map: Node2D
var _spawn_parent: Node2D

# ---------------------------------------------------------------------------

func setup(map: Node2D, spawn_parent: Node2D) -> void:
	_map          = map
	_spawn_parent = spawn_parent

func spawn_pair() -> void:
	_spawn_one("A")
	_spawn_one("B")

func _spawn_one(lane: String) -> void:
	var enemy = _NightKing.new()
	_spawn_parent.add_child(enemy)
	enemy.start_path(_map.get_full_path(lane))
	enemy.died.connect(_on_enemy_died)
	enemy.escaped.connect(_on_enemy_escaped)

func _on_enemy_died(enemy, reward: int) -> void:
	GameState.add_gold(reward)

func _on_enemy_escaped(enemy, damage: int) -> void:
	GameState.lose_lives(damage)

class_name EnemyBase
extends Node2D

const _PathFollower   = preload("res://path_follower.gd")
const _SpriteAnimator = preload("res://sprite_animator.gd")
const _HpBar          = preload("res://hp_bar.gd")

var max_hp: float       = 20.0
var hp: float           = 20.0
var move_speed: float   = 55.0
var lives_damage: int   = 1
var gold_reward: int    = 10
var char_folder: String = "night_king"
var sprite_px: float     = 80.0   ## tamanho do canvas do sprite no mundo (o personagem ocupa ~70%)
var is_immune: bool     = false   ## immune to normal projectiles (Night King)
var melee_damage: float = 25.0     ## dano por golpe no herói (definido no _setup de cada inimigo)

const MELEE_RANGE  := 52.0
const MELEE_RATE   := 1.0

var _follower
var _anim
var _engaged_hero: Node2D = null

signal died(enemy, reward: int)
signal escaped(enemy, damage: int)

# ---------------------------------------------------------------------------

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("enemies")

	_follower = _PathFollower.new()
	add_child(_follower)
	_follower.reached_end.connect(_on_reached_end)

	# Hitbox for tower range detection
	var area := Area2D.new()
	area.collision_layer = 8
	area.collision_mask  = 0
	area.monitorable     = true
	area.monitoring      = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	area.add_child(shape)
	add_child(area)

	_setup()

	_anim = _SpriteAnimator.new()
	add_child(_anim)
	_anim.setup(char_folder, sprite_px)
	_anim.attack_hit.connect(_on_attack_hit)
	add_child(_HpBar.new(func(): return hp / max_hp, _anim.head_y - 8.0))

## Override in subclass to set stats.
func _setup() -> void:
	pass

func start_path(path: Array) -> void:
	if path.is_empty():
		return
	global_position = path[0]
	_follower.setup(path, move_speed)

func get_progress() -> float:
	return _follower.get_progress()

# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if is_instance_valid(_engaged_hero):
		if global_position.distance_to(_engaged_hero.global_position) > MELEE_RANGE * 1.5:
			_engaged_hero = null
		else:
			var dir_to_hero := _vec_to_dir(
				(_engaged_hero.global_position - global_position).normalized())
			_anim.set_dir(dir_to_hero)
			_anim.play(true)
			_anim.tick(delta)
			return

	_engaged_hero = null

	var hero := _find_free_hero()
	if hero != null:
		_engaged_hero = hero
		return

	if _follower.is_finished():
		return
	var move: Vector2 = _follower.advance(delta, self)
	if move.length() > 0.5:
		_anim.set_dir(_vec_to_dir(move.normalized()))
	_anim.play()
	_anim.tick(delta)

func _find_free_hero() -> Node2D:
	for hero in get_tree().get_nodes_in_group("heroes"):
		if not is_instance_valid(hero):
			continue
		if global_position.distance_to(hero.global_position) > MELEE_RANGE:
			continue
		var already_engaged := false
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != self and is_instance_valid(e) and e.get("_engaged_hero") == hero:
				already_engaged = true
				break
		if not already_engaged:
			return hero
	return null

func _on_attack_hit() -> void:
	if is_instance_valid(_engaged_hero):
		_engaged_hero.take_damage(melee_damage)

func take_damage(amount: float) -> void:
	hp -= amount
	queue_redraw()
	if hp <= 0.0:
		died.emit(self, gold_reward)
		queue_free()

# ---------------------------------------------------------------------------

func _on_reached_end() -> void:
	escaped.emit(self, lives_damage)
	queue_free()

static func _vec_to_dir(v: Vector2) -> String:
	var deg := fmod(rad_to_deg(v.angle()) + 360.0, 360.0)
	if   deg < 22.5  or deg >= 337.5: return "east"
	elif deg < 67.5:                   return "south-east"
	elif deg < 112.5:                  return "south"
	elif deg < 157.5:                  return "south-west"
	elif deg < 202.5:                  return "west"
	elif deg < 247.5:                  return "north-west"
	elif deg < 292.5:                  return "north"
	else:                              return "north-east"

## Meio do corpo (o nó fica no pé): é para onde as flechas miram.
func body_center() -> Vector2:
	return global_position + Vector2(0.0, (_anim.head_y if _anim else -40.0) / 2.0)

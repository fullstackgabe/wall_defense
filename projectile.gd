class_name Projectile
extends Node2D

var damage: float  = 5.0
var speed: float   = 450.0

var _target: Node2D
var _target_pos: Vector2
var _sprite: Sprite2D

func setup(target: Node2D, dmg: float, spd: float) -> void:
	_target     = target
	_target_pos = target.global_position
	damage      = dmg
	speed       = spd

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var p := "res://projectiles/arrow.png"
	if ResourceLoader.exists(p):
		_sprite.texture = load(p)
		var tw := float(_sprite.texture.get_width())
		var th := float(_sprite.texture.get_height())
		_sprite.scale = Vector2.ONE * (20.0 / maxf(tw, th))
	add_child(_sprite)

func _process(delta: float) -> void:
	var dest: Vector2
	if is_instance_valid(_target):
		dest = _target.global_position
		_target_pos = dest
	else:
		dest = _target_pos

	var to := dest - global_position
	if to.length() <= speed * delta:
		_on_hit()
		return

	global_position += to.normalized() * speed * delta
	rotation = to.angle()

func _on_hit() -> void:
	if is_instance_valid(_target) and _target.has_method("take_damage"):
		_target.take_damage(damage)
	queue_free()

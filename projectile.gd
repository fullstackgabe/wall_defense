class_name Projectile
extends Node2D

var damage: float  = 5.0
var speed: float   = 450.0

var _target: Node2D
var _target_pos: Vector2
var _sprite: Sprite2D

func setup(target: Node2D, dmg: float, spd: float) -> void:
	_target     = target
	_target_pos = _aim_point(target)
	damage      = dmg
	speed       = spd

## Flecha legível (com 20 px virava um risco) e desenhada por cima da torre e das
## árvores — sai do alto da torre, que fica na frente dela no y-sort.
const ARROW_PX := 34.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 20
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var p := "res://projectiles/arrow.png"
	if ResourceLoader.exists(p):
		_sprite.texture = load(p)
		var tw := float(_sprite.texture.get_width())
		var th := float(_sprite.texture.get_height())
		_sprite.scale = Vector2.ONE * (ARROW_PX / maxf(tw, th))
	add_child(_sprite)

func _process(delta: float) -> void:
	var dest: Vector2
	if is_instance_valid(_target):
		dest = _aim_point(_target)
		_target_pos = dest
	else:
		dest = _target_pos

	var to := dest - global_position
	if to.length() <= speed * delta:
		_on_hit()
		return

	global_position += to.normalized() * speed * delta
	rotation = to.angle()

func _aim_point(t: Node2D) -> Vector2:
	return t.body_center() if t.has_method("body_center") else t.global_position

func _on_hit() -> void:
	if is_instance_valid(_target) and _target.has_method("take_damage"):
		_target.take_damage(damage)
	queue_free()

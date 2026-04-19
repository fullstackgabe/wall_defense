class_name ArcherTower
extends Node2D

const _Projectile = preload("res://projectile.gd")

const tower_type: String = "archer"
const DAMAGE:    float = 9.0
const RANGE_PX:  float = 220.0
const FIRE_RATE: float = 1.1

var _fire_timer:       float  = 0.0
var _enemies_in_range: Array  = []
var _show_range:       bool   = false
var _sprite:           Sprite2D

# ---------------------------------------------------------------------------

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_sprite()
	_build_range_area()

func _build_sprite() -> void:
	var path := "res://characters/archer_tower/stopped.png"
	if not ResourceLoader.exists(path):
		return
	_sprite = Sprite2D.new()
	_sprite.texture = load(path)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tw := float(_sprite.texture.get_width())
	var th := float(_sprite.texture.get_height())
	_sprite.scale = Vector2.ONE * (200.0 / maxf(tw, th))
	add_child(_sprite)

func _build_range_area() -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask  = 8
	area.monitoring      = true
	area.input_pickable  = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RANGE_PX
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	area.area_entered.connect(_on_enemy_entered)
	area.area_exited.connect(_on_enemy_exited)
	area.mouse_entered.connect(func(): _show_range = true; queue_redraw())
	area.mouse_exited.connect(func(): _show_range = false; queue_redraw())

# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_enemies_in_range = _enemies_in_range.filter(func(e): return is_instance_valid(e))

	_fire_timer += delta
	if _fire_timer < FIRE_RATE:
		return
	var target := _pick_target()
	if target == null:
		return
	_fire_timer = 0.0
	_shoot(target)

func _pick_target() -> Node2D:
	var best: Node2D  = null
	var best_prog: float = -1.0
	for e in _enemies_in_range:
		if is_instance_valid(e):
			var prog: float = e.get_progress()
			if prog > best_prog:
				best_prog = prog
				best = e
	return best

func _shoot(target: Node2D) -> void:
	var proj = _Projectile.new()
	get_parent().get_parent().add_child(proj)
	proj.global_position = global_position
	proj.setup(target, DAMAGE, 480.0)

# ---------------------------------------------------------------------------

func _on_enemy_entered(area: Area2D) -> void:
	var e := area.get_parent()
	if e.is_in_group("enemies") and not _enemies_in_range.has(e):
		_enemies_in_range.append(e)

func _on_enemy_exited(area: Area2D) -> void:
	_enemies_in_range.erase(area.get_parent())

func _draw() -> void:
	if _show_range:
		draw_arc(Vector2.ZERO, RANGE_PX, 0.0, TAU, 64, Color(0.2, 0.4, 0.9, 0.45), 1.5)
		draw_circle(Vector2.ZERO, RANGE_PX, Color(0.2, 0.4, 0.9, 0.08))

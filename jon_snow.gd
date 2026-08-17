class_name JonSnow
extends CharacterBody2D

const _SpriteAnimator = preload("res://sprite_animator.gd")

## Melee hero. Auto-chases nearby enemies and attacks them.
## Click to select, click map to reposition.

## Limites da muralha (devem bater com map.gd — GATE_COL=14, GATE_WIDTH=4)
const WALL_Y_TOP   := 8  * 40        ## 320
const WALL_Y_BOT   := 11 * 40        ## 440
const HOLE_X_LEFT  := 14 * 40        ## 560
const HOLE_X_RIGHT := 18 * 40        ## 720
const HOLE_X_MID   := (HOLE_X_LEFT + HOLE_X_RIGHT) / 2.0  ## 640

const MOVE_SPEED    := 80.0
const MELEE_RANGE   := 36.0
const CHASE_RANGE   := 160.0
const ATTACK_DAMAGE := 11.0
const MAX_HP        := 200.0
const SEL_COLOR     := Color(0.3, 0.8, 1.0, 0.55)
const WAYPOINT_DIST := 6.0

var hp: float              = MAX_HP
var _selected: bool        = false
var _locked_target: Node2D = null
var _anim
var _dir: String  = "south"
var _path: Array  = []

# ---------------------------------------------------------------------------

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer = 0
	collision_mask  = 1   ## colide com camada 1 (muralha)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)

	add_to_group("heroes")
	_anim = _SpriteAnimator.new()
	add_child(_anim)
	_anim.setup("jon_snow", 80.0)
	_anim.attack_hit.connect(_on_attack_hit)

# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return

	## Atualiza alvo mais próximo
	if not is_instance_valid(_locked_target) or \
	   global_position.distance_to(_locked_target.global_position) > CHASE_RANGE:
		_locked_target = _find_nearest_enemy()

	## Se tem waypoints manuais pendentes, segue eles
	if not _path.is_empty():
		var next: Vector2 = _path[0]
		if global_position.distance_to(next) < WAYPOINT_DIST:
			_path.pop_front()
			if _path.is_empty():
				velocity = Vector2.ZERO
				move_and_slide()
				_anim.stop()
				queue_redraw()
				return
		_move_toward(_path[0] if not _path.is_empty() else next, delta)
		_anim.play()
		_anim.tick(delta)
		queue_redraw()
		return

	## Sem destino manual — persegue inimigo
	if is_instance_valid(_locked_target):
		var dist := global_position.distance_to(_locked_target.global_position)
		if dist <= MELEE_RANGE:
			_dir = _vec_to_dir((_locked_target.global_position - global_position).normalized())
			_anim.set_dir(_dir)
			_anim.play(true)
			_anim.tick(delta)
			velocity = Vector2.ZERO
			move_and_slide()
		else:
			var chase_path := _compute_path(_locked_target.global_position)
			if not chase_path.is_empty():
				_move_toward(chase_path[0], delta)
			_anim.play()
			_anim.tick(delta)
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		_anim.stop()

	queue_redraw()

# ---------------------------------------------------------------------------
# Movimento com física

func _move_toward(pos: Vector2, delta: float) -> void:
	var to := pos - global_position
	if to.length() > 0.1:
		_dir = _vec_to_dir(to.normalized())
		velocity = to.normalized() * MOVE_SPEED
	else:
		velocity = Vector2.ZERO
	_anim.set_dir(_dir)
	move_and_slide()

# ---------------------------------------------------------------------------
# Pathfinding — contorna a muralha pelo buraco

func _set_destination(dest: Vector2) -> void:
	## Ignora cliques dentro da parte sólida da muralha (fora do buraco)
	var in_wall := dest.y >= WALL_Y_TOP and dest.y <= WALL_Y_BOT
	var in_hole := dest.x >= HOLE_X_LEFT and dest.x <= HOLE_X_RIGHT
	if in_wall and not in_hole:
		return
	_path = _compute_path(dest)

func _compute_path(dest: Vector2) -> Array:
	var from_y := global_position.y
	var dest_y := dest.y

	var from_castle := from_y > WALL_Y_BOT
	var from_forest := from_y < WALL_Y_TOP

	## Castelo → floresta/muralha: passa pelo buraco subindo
	if from_castle and not (dest_y > WALL_Y_BOT):
		return [
			Vector2(HOLE_X_MID, WALL_Y_BOT + 4),
			Vector2(HOLE_X_MID, WALL_Y_TOP - 4),
			dest
		]

	## Floresta → castelo/muralha: passa pelo buraco descendo
	if from_forest and not (dest_y < WALL_Y_TOP):
		return [
			Vector2(HOLE_X_MID, WALL_Y_TOP - 4),
			Vector2(HOLE_X_MID, WALL_Y_BOT + 4),
			dest
		]

	return [dest]

# ---------------------------------------------------------------------------

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

func _find_nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist    := CHASE_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_dist:
			best_dist = d
			best = e
	return best

# ---------------------------------------------------------------------------

func _on_attack_hit() -> void:
	if is_instance_valid(_locked_target) and \
	   global_position.distance_to(_locked_target.global_position) <= MELEE_RANGE:
		_locked_target.take_damage(ATTACK_DAMAGE)

func take_damage(amount: float) -> void:
	hp -= amount
	queue_redraw()
	if hp <= 0.0:
		queue_free()

# ---------------------------------------------------------------------------
# Input

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	var click := get_global_mouse_position()

	if not _selected:
		if global_position.distance_to(click) <= 24.0:
			_selected = true
			queue_redraw()
			get_viewport().set_input_as_handled()
	else:
		_set_destination(click)
		_selected = false
		queue_redraw()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Draw: selection ring + HP bar

func _draw() -> void:
	if _selected:
		draw_circle(Vector2.ZERO, 24.0, SEL_COLOR)
	var bar_w := 36.0
	var bar_h := 4.0
	var off   := Vector2(-bar_w / 2.0, -34.0)
	draw_rect(Rect2(off, Vector2(bar_w, bar_h)), Color(0.2, 0.2, 0.2))
	var ratio := hp / MAX_HP
	draw_rect(Rect2(off, Vector2(bar_w * ratio, bar_h)),
			  Color(0.1, 0.7, 0.9) if ratio > 0.3 else Color(0.9, 0.2, 0.1))

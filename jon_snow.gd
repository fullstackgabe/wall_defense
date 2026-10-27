class_name JonSnow
extends CharacterBody2D

const _SpriteAnimator = preload("res://sprite_animator.gd")
const _HpBar          = preload("res://hp_bar.gd")

## Melee hero. Auto-chases nearby enemies and attacks them.
## Click to select, click map to reposition.

## Limites da muralha (devem bater com map.gd — WALL_ROW 10–13, GATE_COL=18, GATE_WIDTH=4)
const WALL_Y_TOP   := 10 * 40        ## 400
const WALL_Y_BOT   := 13 * 40        ## 520
const HOLE_X_LEFT  := 18 * 40        ## 720
const HOLE_X_RIGHT := 22 * 40        ## 880
const HOLE_X_MID   := (HOLE_X_LEFT + HOLE_X_RIGHT) / 2.0  ## 800

const MOVE_SPEED    := 80.0
const MELEE_RANGE   := 52.0      ## igual ao EnemyBase.MELEE_RANGE: alcança quem o ataca
const BODY_RADIUS   := 12.0
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
	circle.radius = BODY_RADIUS
	shape.shape = circle
	add_child(shape)

	add_to_group("heroes")
	_anim = _SpriteAnimator.new()
	add_child(_anim)
	_anim.setup("jon_snow", 100.0)   ## 80 ficava pequeno demais (pedido do usuário, 26/10/2026)
	_anim.attack_hit.connect(_on_attack_hit)
	var bar := _HpBar.new(func(): return hp / MAX_HP, _anim.head_y - 8.0)
	bar.color_full = Color(0.1, 0.7, 0.9)
	bar.low_below  = 0.3
	add_child(bar)

# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return

	## Quem está batendo nele tem prioridade; senão, o inimigo mais próximo
	var attacker := _find_attacker()
	if attacker != null:
		_locked_target = attacker
	elif not is_instance_valid(_locked_target) or \
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
			while chase_path.size() > 1 and global_position.distance_to(chase_path[0]) < WAYPOINT_DIST:
				chase_path.pop_front()   # já está no waypoint (ex.: na boca do portão)
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
	## Floresta: só anda pelas estradas (o mapa, pai do Jon, conhece o traçado).
	var from_forest := global_position.y < WALL_Y_TOP
	var dest_forest := dest.y < WALL_Y_TOP
	var map := get_parent()
	if (from_forest or dest_forest) and map.has_method("forest_route"):
		var gate_top := Vector2(HOLE_X_MID, WALL_Y_TOP - 4)
		var gate_bot := Vector2(HOLE_X_MID, WALL_Y_BOT + 4)
		if from_forest and dest_forest:
			return map.forest_route(global_position, dest)
		if from_forest:
			var out: Array = map.forest_route(global_position, gate_top)
			if dest.y > WALL_Y_BOT:
				out.append(gate_bot)
			out.append(dest)
			return out
		var into: Array = [gate_bot, gate_top] if global_position.y > WALL_Y_BOT else [gate_top]
		return into + map.forest_route(gate_top, dest)

	## Caminho reto livre (ex.: os dois dentro do buraco) — vai direto.
	## Sem isso, perto da borda da muralha ele alternava entre a rota pelo
	## buraco e a rota direta a cada frame e ficava tremendo no lugar.
	if _segment_clear(global_position, dest):
		return [dest]

	var from_y := global_position.y
	var dest_y := dest.y

	## Castelo → buraco da muralha: entra pelo meio do buraco
	if from_y > WALL_Y_BOT and dest_y <= WALL_Y_BOT:
		return [Vector2(HOLE_X_MID, WALL_Y_BOT + 4), dest]

	return [dest]

## true se o segmento a→b não atravessa a parte sólida da muralha
## (considerando o raio do corpo).
func _segment_clear(a: Vector2, b: Vector2) -> bool:
	var steps := maxi(1, int(a.distance_to(b) / 8.0))
	for i in range(steps + 1):
		var p := a.lerp(b, float(i) / steps)
		var in_wall := p.y > WALL_Y_TOP - BODY_RADIUS and p.y < WALL_Y_BOT + BODY_RADIUS
		var in_hole := p.x > HOLE_X_LEFT + BODY_RADIUS and p.x < HOLE_X_RIGHT - BODY_RADIUS
		if in_wall and not in_hole:
			return false
	return true

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

func _find_attacker() -> Node2D:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.get("_engaged_hero") == self:
			return e
	return null

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
		## O nó fica no pé: aceita clique do pé até a cabeça.
		var rel := click - global_position
		if absf(rel.x) <= 24.0 and rel.y <= 12.0 and rel.y >= _anim.head_y - 4.0:
			_selected = true
			queue_redraw()
			get_viewport().set_input_as_handled()
	else:
		_set_destination(click)
		_selected = false
		queue_redraw()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Draw: selection ring (a barra de vida é o HpBar)

func _draw() -> void:
	if _selected:
		draw_circle(Vector2.ZERO, 24.0, SEL_COLOR)

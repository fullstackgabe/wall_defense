class_name TowerSlot
extends Area2D

const TILE_SIZE  := 40
const PAD_COLOR  := Color(1.0, 0.85, 0.30, 0.28)
const PAD_HOV    := Color(1.0, 0.85, 0.30, 0.55)
const PAD_BORDER := Color(1.0, 0.85, 0.30, 0.80)
const PAD_SEL    := Color(0.3, 0.8, 1.0, 0.70)   ## Jon Snow selected highlight

var cell: Vector2i = Vector2i(-1, -1)
var tower: Node2D  = null   ## null = free
var _hovered: bool = false

signal pad_clicked(pad)

func _ready() -> void:
	collision_layer  = 2
	collision_mask   = 0
	monitorable      = false
	monitoring       = false
	input_pickable   = true

	var shape := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.size = Vector2(TILE_SIZE - 4, TILE_SIZE - 4)
	shape.shape = rect
	add_child(shape)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

func is_free() -> bool:
	return tower == null

## Place a tower node centred on this pad.
func place_tower(t: Node2D) -> void:
	tower = t
	t.position = Vector2.ZERO
	add_child(t)
	queue_redraw()

## Remove installed tower (for sell / move).
func remove_tower() -> Node2D:
	if tower == null:
		return null
	remove_child(tower)
	var t := tower
	tower = null
	queue_redraw()
	return t

func _draw() -> void:
	var half := (TILE_SIZE - 6) / 2.0
	var r    := Rect2(-half, -half, TILE_SIZE - 6, TILE_SIZE - 6)
	if tower == null:
		var fill := PAD_HOV if _hovered else PAD_COLOR
		draw_rect(r, fill)
		draw_rect(r, PAD_BORDER, false, 1.5)
	else:
		# Subtle border so pad is still visible
		draw_rect(r, Color(PAD_BORDER, 0.25), false, 1.0)

func _on_mouse_entered() -> void:
	_hovered = true
	queue_redraw()

func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()

func _on_input_event(_viewport: Viewport, event: InputEvent, _idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pad_clicked.emit(self)
			get_viewport().set_input_as_handled()

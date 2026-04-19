extends Node2D

const TowerSlot = preload("res://tower_slot.gd")

# ---------------------------------------------------------------------------
# Grid
const TILE_SIZE := 40
const COLS      := 32
const ROWS      := 18

# ---------------------------------------------------------------------------
# Zonas (linhas)
const FOREST_ROW_START := 0
const FOREST_ROW_END   := 8    ## Floresta Assombrada (spawn inimigos)
const WALL_ROW_START   := 8
const WALL_ROW_END     := 11   ## Muralha de Gelo
const CASTLE_ROW_START := 11
const CASTLE_ROW_END   := 18   ## Castle Black (torres/herói)

const GATE_COL   := 14          ## Coluna inicial do buraco na muralha (cols 14-17, centro em x=640)
const GATE_WIDTH := 4           ## Largura do buraco em tiles

# ---------------------------------------------------------------------------
# Background
const BG_PATH := "res://backgrounds/map_bg.jpg"

# Paleta de fallback
const C_FOREST  := Color(0.07, 0.14, 0.06)   ## verde-escuro
const C_TREE    := Color(0.05, 0.10, 0.04)   ## árvores
const C_WALL    := Color(0.72, 0.84, 0.95)   ## gelo claro
const C_WALL_DK := Color(0.55, 0.70, 0.85)   ## sombra da muralha
const C_GATE    := Color(0.25, 0.38, 0.55)   ## portão azul escuro
const C_CASTLE  := Color(0.24, 0.26, 0.30)   ## pedra castle black
const C_STONE   := Color(0.18, 0.20, 0.23)   ## pedra mais escura

# ---------------------------------------------------------------------------
# Caminhos (células → convertidas para world em _ready)
## Caminho A: borda esquerda → frente da muralha → lane esquerda do buraco (col 15) → saída
const _PATH_A_CELLS: Array[Vector2i] = [
	Vector2i( 2, 0), Vector2i( 2, 6),   ## desce pela borda esquerda (floresta)
	Vector2i(15, 6),                     ## anda em frente à muralha (→ leste)
	Vector2i(15,11),                     ## desce pelo lado esquerdo do buraco
	Vector2i(15,13), Vector2i( 2,13),    ## vira à esquerda no castelo
	Vector2i( 2,18),                     ## sai pela base
]
## Caminho B: espelho exato do A em torno de x=640px (col 29 ↔ col 2, col 16 ↔ col 15)
const _PATH_B_CELLS: Array[Vector2i] = [
	Vector2i(29, 0), Vector2i(29, 6),   ## desce pela borda direita (floresta)
	Vector2i(16, 6),                     ## anda em frente à muralha (← oeste, 13 tiles)
	Vector2i(16,11),                     ## desce pelo lado direito do buraco
	Vector2i(16,13), Vector2i(29,13),    ## vira à direita no castelo
	Vector2i(29,18),                     ## sai pela base
]

## Slots de torre — linha 11, simétricos, evitando o buraco (cols 14-17)
const _PAD_CELLS: Array[Vector2i] = [
	Vector2i( 3,11), Vector2i( 7,11), Vector2i(11,11),
	Vector2i(21,11), Vector2i(25,11), Vector2i(29,11),
]

# ---------------------------------------------------------------------------

var path_a: Array = []
var path_b: Array = []

var _pads: Array = []    ## Array[TowerSlot]
var _has_bg := false

signal pad_clicked(pad)

# ---------------------------------------------------------------------------

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_compute_paths()
	_load_background()
	_build_wall_collision()
	_create_pads()

func _on_solid_wall(pos: Vector2) -> bool:
	var wall_y0 := float(WALL_ROW_START * TILE_SIZE)
	var wall_y1 := float(WALL_ROW_END   * TILE_SIZE)
	var hole_x0 := float(GATE_COL               * TILE_SIZE)
	var hole_x1 := float((GATE_COL + GATE_WIDTH) * TILE_SIZE)
	return pos.y >= wall_y0 and pos.y <= wall_y1 \
	   and not (pos.x >= hole_x0 and pos.x <= hole_x1)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _on_solid_wall(get_global_mouse_position()):
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Paths

func _compute_paths() -> void:
	for c in _PATH_A_CELLS: path_a.append(cell_to_world(c))
	for c in _PATH_B_CELLS: path_b.append(cell_to_world(c))

func get_full_path(spawn: String) -> Array:
	return path_a if spawn == "A" else path_b

# ---------------------------------------------------------------------------
# Slots de torre

func _create_pads() -> void:
	for cell in _PAD_CELLS:
		var pad := TowerSlot.new()
		pad.cell     = cell
		pad.position = cell_to_world(cell)
		add_child(pad)
		pad.pad_clicked.connect(func(p): pad_clicked.emit(p))
		_pads.append(pad)

func get_pads() -> Array:
	return _pads


# ---------------------------------------------------------------------------
# Coordenadas

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * TILE_SIZE, (cell.y + 0.5) * TILE_SIZE)

func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(
		clamp(int(pos.x / TILE_SIZE), 0, COLS - 1),
		clamp(int(pos.y / TILE_SIZE), 0, ROWS - 1)
	)

# ---------------------------------------------------------------------------
# Background

func _load_background() -> void:
	var abs_path := ProjectSettings.globalize_path(BG_PATH)
	var img := Image.new()
	if img.load(abs_path) != OK:
		return
	var tex := ImageTexture.create_from_image(img)
	var bg  := Sprite2D.new()
	bg.texture        = tex
	bg.centered       = false
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.scale = Vector2(
		float(COLS * TILE_SIZE) / tex.get_width(),
		float(ROWS * TILE_SIZE) / tex.get_height()
	)
	add_child(bg)
	move_child(bg, 0)
	_has_bg = true

func _draw() -> void:
	if not _has_bg:
		_draw_fallback()

func _draw_fallback() -> void:
	var W  := float(COLS * TILE_SIZE)
	var fy := float(FOREST_ROW_START * TILE_SIZE)
	var fh := float((FOREST_ROW_END - FOREST_ROW_START) * TILE_SIZE)
	var wy := float(WALL_ROW_START * TILE_SIZE)
	var wh := float((WALL_ROW_END - WALL_ROW_START) * TILE_SIZE)
	var cy := float(CASTLE_ROW_START * TILE_SIZE)
	var ch := float((CASTLE_ROW_END - CASTLE_ROW_START) * TILE_SIZE)
	var gx := float(GATE_COL * TILE_SIZE)

	## Floresta
	draw_rect(Rect2(0, fy, W, fh), C_FOREST)
	_draw_trees()

	var gate_px := float(GATE_COL * TILE_SIZE)
	var gate_w  := float(GATE_WIDTH * TILE_SIZE)

	## Muralha de Gelo
	draw_rect(Rect2(0,              wy, gate_px,             wh), C_WALL)
	draw_rect(Rect2(0,              wy, gate_px,             4),  C_WALL_DK)
	draw_rect(Rect2(gate_px + gate_w, wy, W - gate_px - gate_w, wh), C_WALL)
	draw_rect(Rect2(gate_px + gate_w, wy, W - gate_px - gate_w, 4),  C_WALL_DK)

	## Buraco na muralha (azul escuro, 3 tiles)
	draw_rect(Rect2(gate_px, wy, gate_w, wh), C_GATE)

	## Castle Black
	draw_rect(Rect2(0, cy, W, ch), C_CASTLE)
	_draw_stone_tiles(cy, ch)

func _draw_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for _i in range(28):
		var tx := rng.randf_range(0, float(COLS * TILE_SIZE))
		var ty := rng.randf_range(float(FOREST_ROW_START * TILE_SIZE),
								  float(FOREST_ROW_END   * TILE_SIZE))
		var r  := rng.randf_range(6.0, 14.0)
		draw_circle(Vector2(tx, ty), r, C_TREE)

func _draw_stone_tiles(cy: float, ch: float) -> void:
	## Grade de pedras no castle
	var step := float(TILE_SIZE)
	for col in range(COLS):
		for row in range(int(ch / step)):
			if (col + row) % 5 == 0:
				var rx := col * step
				var ry := cy + row * step
				draw_rect(Rect2(rx + 2, ry + 2, step - 4, step - 4), C_STONE)

# ---------------------------------------------------------------------------
# Colisão da muralha

func _build_wall_collision() -> void:
	var right_col := GATE_COL + GATE_WIDTH
	_add_static_block(0,         WALL_ROW_START, GATE_COL,           WALL_ROW_END - WALL_ROW_START)
	_add_static_block(right_col, WALL_ROW_START, COLS - right_col,   WALL_ROW_END - WALL_ROW_START)

func _add_static_block(col: int, row: int, w: int, h: int) -> void:
	var body  := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask  = 0
	var shape := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.size      = Vector2(w * TILE_SIZE, h * TILE_SIZE)
	shape.position = rect.size / 2.0
	shape.shape    = rect
	body.position  = Vector2(col * TILE_SIZE, row * TILE_SIZE)
	body.add_child(shape)
	add_child(body)

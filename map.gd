extends Node2D

const TowerSlot = preload("res://tower_slot.gd")

# ---------------------------------------------------------------------------
# Grid
const TILE_SIZE := 40
const COLS      := 40      ## 1600 px (câmera com zoom 0.8 mostra tudo em 1280×720)
const ROWS      := 22      ## 880 px

# ---------------------------------------------------------------------------
# Zonas (linhas)
const FOREST_ROW_START := 0
const FOREST_ROW_END   := 10   ## Floresta Assombrada (spawn inimigos)
const WALL_ROW_START   := 10
const WALL_ROW_END     := 13   ## Muralha de Gelo
const CASTLE_ROW_START := 13
const CASTLE_ROW_END   := 22   ## Castle Black (torres/herói)

const GATE_COL   := 18          ## Coluna inicial do buraco na muralha (cols 14-17, centro em x=640)
const GATE_WIDTH := 4           ## Largura do buraco em tiles

# ---------------------------------------------------------------------------
# Background
## Fundo ilustrado estilo Kingdom Rush (PixelLab, 320×180, desenhado ×4). Sem ele,
## o mapa cai nos tiles de `tiles/` e, sem esses, no fallback desenhado.
const BG_PATH := "res://backgrounds/map_bg.png"
## Camada de frente (árvores + portão) recortada do fundo por `tools/build_occluders.py`.
## Cada recorte é um Sprite2D com y-sort: o personagem passa por trás da copa e por
## dentro do túnel em vez de por cima. Refazer o atlas sempre que o fundo mudar.
const FG_PATH      := "res://backgrounds/map_fg.png"
const FG_JSON_PATH := "res://backgrounds/map_fg.json"
## Os personagens ficam no pé (SpriteAnimator.feet_offset), então a base de cada
## recorte entra no y-sort sem deslocamento.
const FG_SORT_OFFSET := 0.0

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
	Vector2i( 2, 0), Vector2i( 2, 7),   ## desce pela borda esquerda (floresta)
	Vector2i(19, 7),                     ## anda em frente à muralha (→ leste)
	Vector2i(19,13),                     ## desce pelo lado esquerdo do buraco
	Vector2i(19,16), Vector2i( 2,16),    ## vira à esquerda no castelo
	Vector2i( 2,22),                     ## sai pela base
]
## Caminho B: espelho exato do A em torno de x=640px (col 29 ↔ col 2, col 16 ↔ col 15)
const _PATH_B_CELLS: Array[Vector2i] = [
	Vector2i(37, 0), Vector2i(37, 7),   ## desce pela borda direita (floresta)
	Vector2i(20, 7),                     ## anda em frente à muralha (← oeste)
	Vector2i(20,13),                     ## desce pelo lado direito do buraco
	Vector2i(20,16), Vector2i(37,16),    ## vira à direita no castelo
	Vector2i(37,22),                     ## sai pela base
]

## Slots de torre — linha 11, simétricos, evitando o buraco (cols 14-17)
const _PAD_CELLS: Array[Vector2i] = [
	Vector2i( 4,13), Vector2i( 8,13), Vector2i(12,13), Vector2i(15,13),   ## logo abaixo da muralha
	Vector2i(24,13), Vector2i(27,13), Vector2i(31,13), Vector2i(35,13),
	Vector2i(10,19), Vector2i(29,19),                                     ## dentro do pátio
]

# ---------------------------------------------------------------------------

var path_a: Array = []
var path_b: Array = []

var _pads: Array = []    ## Array[TowerSlot]
var _has_bg := false
var _tile_grid: Array = []   ## Texture2D por célula [row][col] (vazio = sem tiles → fallback)

signal pad_clicked(pad)

# ---------------------------------------------------------------------------

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_compute_paths()
	y_sort_enabled = true
	_load_background()
	_build_foreground()
	_build_tile_grid()
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

## O nó do inimigo é o pé e o corpo sobe a partir dele; nas estradas horizontais o pé
## no centro deixava o corpo na beira de cima. Descendo o pé, o corpo fica no meio da faixa.
const PATH_FEET_DY := 14.0

func _compute_paths() -> void:
	for c in _PATH_A_CELLS: path_a.append(cell_to_world(c) + Vector2(0.0, PATH_FEET_DY))
	for c in _PATH_B_CELLS: path_b.append(cell_to_world(c) + Vector2(0.0, PATH_FEET_DY))

## "A"/"B": caminhos laterais com voltas; "C": reto pelo meio do buraco da muralha
## (x = 640), do topo até a base — usado pelo Night King.
func get_full_path(spawn: String) -> Array:
	match spawn:
		"A": return path_a
		"B": return path_b
		_:
			var x := float((GATE_COL + GATE_WIDTH / 2) * TILE_SIZE)
			return [Vector2(x, 0.0), Vector2(x, float(ROWS * TILE_SIZE))]

# ---------------------------------------------------------------------------
# Estradas da floresta — ninguém anda entre as árvores. Formato de pente: uma estrada
# horizontal (linha 7) e três verticais (A, meio/portão e B) que descem do topo até ela;
# a do meio continua até o portão.

func _forest_road_y() -> float:
	return cell_to_world(_PATH_A_CELLS[1]).y

func _forest_road_xs() -> Array:
	return [cell_to_world(_PATH_A_CELLS[0]).x, float((GATE_COL + GATE_WIDTH / 2) * TILE_SIZE),
			cell_to_world(_PATH_B_CELLS[0]).x]

## Ponto mais próximo de `p` em alguma estrada da floresta.
func snap_to_forest_road(p: Vector2) -> Vector2:
	var road_y := _forest_road_y()
	var xs := _forest_road_xs()
	var best := Vector2(clampf(p.x, xs[0], xs[2]), road_y)
	for i in xs.size():
		var y_max := float(WALL_ROW_START * TILE_SIZE) if i == 1 else road_y
		var c := Vector2(xs[i], clampf(p.y, 0.0, y_max))
		if p.distance_to(c) < p.distance_to(best):
			best = c
	return best

## Waypoints de `from` até `to` só pelas estradas da floresta (os dois já na estrada).
func forest_route(from: Vector2, to: Vector2) -> Array:
	var road_y := _forest_road_y()
	var a := snap_to_forest_road(from)
	var b := snap_to_forest_road(to)
	var route: Array = []
	if a.distance_to(from) > 4.0:
		route.append(a)
	var same_vertical := is_equal_approx(a.x, b.x) and a.y != road_y and b.y != road_y
	var both_on_road := is_equal_approx(a.y, road_y) and is_equal_approx(b.y, road_y)
	if not same_vertical and not both_on_road:
		if not is_equal_approx(a.y, road_y): route.append(Vector2(a.x, road_y))
		if not is_equal_approx(b.y, road_y): route.append(Vector2(b.x, road_y))
	route.append(b)
	return route

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
	if not ResourceLoader.exists(BG_PATH):
		return
	var tex: Texture2D = load(BG_PATH)
	var bg  := Sprite2D.new()
	bg.texture        = tex
	bg.centered       = false
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.scale = Vector2.ONE * float(COLS * TILE_SIZE) / tex.get_width()   # escala inteira (×4), sem distorcer
	add_child(bg)
	move_child(bg, 0)
	_has_bg = true

func _build_foreground() -> void:
	if not _has_bg or not ResourceLoader.exists(FG_PATH) or not FileAccess.file_exists(FG_JSON_PATH):
		return
	var atlas: Texture2D = load(FG_PATH)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FG_JSON_PATH))
	var k := float(COLS * TILE_SIZE) / float(data["source_size"][0])   # mesma escala do fundo (×4)
	for piece in data["pieces"]:
		var a: Array = piece["atlas"]
		var base_y := float(piece["base"]) * k
		var holder := Node2D.new()
		holder.position = Vector2(0.0, base_y - FG_SORT_OFFSET)
		var spr := Sprite2D.new()
		spr.texture        = atlas
		spr.region_enabled = true
		spr.region_rect    = Rect2(a[0], a[1], a[2], a[3])
		spr.centered       = false
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.scale          = Vector2.ONE * k
		spr.position       = Vector2(float(piece["pos"][0]) * k, float(piece["pos"][1]) * k - holder.position.y)
		holder.add_child(spr)
		add_child(holder)

func _draw() -> void:
	if _has_bg:
		return
	if not _tile_grid.is_empty():
		_draw_tiles()
	else:
		_draw_fallback()

# ---------------------------------------------------------------------------
# Tiles (PixelLab, 40×40 = 1 célula). Cada célula recebe um tile da sua zona;
# as células dos caminhos A/B viram trilha. Sorteio com seed fixa (mapa sempre igual).

const TILE_DIR := "res://tiles/"
const TILE_SEED := 1337

func _tile(name: String) -> Texture2D:
	var path := TILE_DIR + name + ".png"
	return load(path) if ResourceLoader.exists(path) else null

func _build_tile_grid() -> void:
	var t := {}
	for n in ["forest_0", "forest_1", "forest_2", "forest_3", "forest_4", "forest_pine", "forest_path",
			"ice_brick", "ice_wall", "ice_cracked", "gate",
			"stone_brick", "stone_snow", "stone_snow_2", "castle_path", "castle_path_2"]:
		t[n] = _tile(n)
		if t[n] == null:
			return   # falta algum tile → fica no fallback desenhado
	var path_cells := _path_cell_set()
	var rng := RandomNumberGenerator.new()
	rng.seed = TILE_SEED
	var forest := ["forest_0", "forest_1", "forest_2", "forest_3", "forest_4"]
	_tile_grid.clear()
	for row in ROWS:
		var line := []
		for col in COLS:
			var on_path := path_cells.has(Vector2i(col, row))
			var in_gate := col >= GATE_COL and col < GATE_COL + GATE_WIDTH
			var name: String
			var r := rng.randf()
			if row < WALL_ROW_START:
				if on_path:                 name = "forest_path"
				elif r < 0.06:              name = "forest_pine"
				elif r < 0.16:              name = "forest_3"   # detalhe: raízes
				else:                       name = "forest_1"   # chão principal da floresta
			elif row < WALL_ROW_END:
				if in_gate:                 name = "gate"
				elif r < 0.08:              name = "ice_cracked"
				else:                       name = "ice_brick"
			else:
				if on_path:                 name = "castle_path"
				elif row == CASTLE_ROW_START: name = "stone_brick"
				elif r < 0.12:              name = "stone_snow_2"
				else:                       name = "stone_snow"
			line.append(t[name])
		_tile_grid.append(line)

## Células por onde passam os caminhos A e B (segmentos retos entre waypoints).
func _path_cell_set() -> Dictionary:
	var cells := {}
	for path in [_PATH_A_CELLS, _PATH_B_CELLS]:
		for i in range(path.size() - 1):
			var a: Vector2i = path[i]
			var b: Vector2i = path[i + 1]
			var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
			var c := a
			while true:
				if c.y < ROWS: cells[c] = true
				if c == b: break
				c += step
	return cells

## Os tiles vêm com contorno preto de 1–2 px; desenha só o miolo esticado para a
## célula, senão o mapa vira uma grade.
const TILE_INSET := 2

func _draw_tiles() -> void:
	for row in _tile_grid.size():
		for col in _tile_grid[row].size():
			var tex: Texture2D = _tile_grid[row][col]
			var src := Rect2(TILE_INSET, TILE_INSET, tex.get_width() - TILE_INSET * 2, tex.get_height() - TILE_INSET * 2)
			draw_texture_rect_region(tex, Rect2(col * TILE_SIZE, row * TILE_SIZE, TILE_SIZE, TILE_SIZE), src)

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

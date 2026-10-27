extends Node2D

## Scene tree expected:
##   Main (this script)
##     Map       (map.gd)
##     TowerMenu (tower_menu.gd, Control)

const _ArcherTower = preload("res://archer_tower.gd")
const _WaveManager = preload("res://wave_manager.gd")
const _JonSnow     = preload("res://jon_snow.gd")
const _Hud         = preload("res://hud.gd")
const Styles       = preload("res://styles.gd")

const TOWER_SCRIPTS := { "archer": _ArcherTower }
const JON_SNOW_SPAWN_CELL := Vector2i(20, 14)
## Câmera afastada: o fundo ilustrado (400×224 ×4 = 1600×896) preenche exatamente a
## tela de 1280×720 (zoom 720/896 ≈ 0.80); o grid jogável ocupa os primeiros 880 px.
const CAMERA_ZOOM := 720.0 / 896.0
const RESPAWN_DELAY := 15.0
const SPAWN_INTERVAL := 3.0   ## uma horda a cada 3 s, automática (não há mais botão)

@onready var _map:        Node2D  = $Map
@onready var _tower_menu: Control = $TowerMenu

var _wave_manager   = null
var _jon_snow       = null
var _respawning:    bool  = false
var _respawn_timer: float = 0.0
var _respawn_btn:   Button = null
var _respawn_label: Label  = null
var _respawn_canvas: CanvasLayer = null
var _spawn_cooldown: float  = SPAWN_INTERVAL   ## 3 s antes da 1ª horda para construir

# ---------------------------------------------------------------------------

func _ready() -> void:
	$Camera2D.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	_tower_menu.scale = Vector2.ONE / CAMERA_ZOOM   # menu no mundo, mas do mesmo tamanho na tela
	_wave_manager = _WaveManager.new()
	add_child(_wave_manager)
	_wave_manager.setup(_map, _map)

	_map.pad_clicked.connect(_on_pad_clicked)
	_tower_menu.tower_chosen.connect(_on_tower_chosen)

	GameState.state_changed.connect(_on_state_changed)
	add_child(_Hud.new())
	_build_respawn_ui()
	_spawn_jon_snow()

# ---------------------------------------------------------------------------

func _spawn_jon_snow() -> void:
	if is_instance_valid(_jon_snow):
		return
	_jon_snow = _JonSnow.new()
	_jon_snow.global_position = _map.cell_to_world(JON_SNOW_SPAWN_CELL)
	_map.add_child(_jon_snow)
	_respawning = false
	_respawn_canvas.visible = false

func _build_respawn_ui() -> void:
	_respawn_canvas = CanvasLayer.new()
	_respawn_canvas.visible = false
	add_child(_respawn_canvas)

	var cx := 1280 / 2.0

	_respawn_btn = Button.new()
	_respawn_btn.text = "Ressuscitar"
	_respawn_btn.custom_minimum_size = Vector2(200, 46)
	_respawn_btn.position = Vector2(cx - 100, 12)
	_respawn_btn.disabled = true
	_respawn_btn.add_theme_font_size_override("font_size", 14)
	Styles.gold_button(_respawn_btn, Styles.GOLD, Styles.GOLD.lightened(0.2))
	_respawn_btn.add_theme_color_override("font_color", Styles.NIGHT)
	_respawn_btn.pressed.connect(_spawn_jon_snow)
	_respawn_canvas.add_child(_respawn_btn)

	_respawn_label = Label.new()
	_respawn_label.add_theme_color_override("font_color", Styles.SNOW)
	_respawn_label.add_theme_font_size_override("font_size", 14)
	_respawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_respawn_label.position = Vector2(cx - 100, 64)
	_respawn_label.custom_minimum_size = Vector2(200, 24)
	_respawn_canvas.add_child(_respawn_label)

## Envia uma horda (spawn_pair) a cada SPAWN_INTERVAL s, como se o jogador clicasse sem
## parar no antigo botão “Enviar Inimigos”. Para no game over.
func _tick_spawn(delta: float) -> void:
	if GameState.state == GameState.State.GAME_OVER:
		return
	_spawn_cooldown -= delta
	if _spawn_cooldown <= 0.0:
		_spawn_cooldown += SPAWN_INTERVAL
		_wave_manager.spawn_pair()

func _process(delta: float) -> void:
	_tick_spawn(delta)
	if not _respawning:
		if not is_instance_valid(_jon_snow) and not _respawn_canvas.visible:
			_respawning = true
			_respawn_timer = RESPAWN_DELAY
			_respawn_canvas.visible = true
			_respawn_label.visible = true
			_respawn_btn.disabled = true
		return

	_respawn_timer -= delta
	if _respawn_timer > 0.0:
		_respawn_label.text = "Aguarde %ds" % ceili(_respawn_timer)
	else:
		_respawn_label.visible = false
		_respawn_btn.disabled = false

# ---------------------------------------------------------------------------

func _on_pad_clicked(pad) -> void:
	if GameState.state == GameState.State.GAME_OVER:
		return
	_tower_menu.show_at_pad(pad)

func _on_tower_chosen(tower_type: String, pad) -> void:
	if tower_type == "__remove__":
		var t = pad.remove_tower()
		if t != null:
			GameState.add_gold(_tower_menu.sell_value(t.tower_type))
			t.queue_free()
		return
	var script = TOWER_SCRIPTS.get(tower_type)
	if script and GameState.spend_gold(_tower_menu.get_cost(tower_type)):
		pad.place_tower(script.new())

func _on_state_changed(new_state: GameState.State) -> void:
	if new_state == GameState.State.GAME_OVER:
		_show_game_over()

func _show_game_over() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	var dim := ColorRect.new()
	dim.color = Color.BLACK
	dim.size  = Vector2(1280, 720)
	canvas.add_child(dim)

	var title := Label.new()
	title.text = "A MURALHA CAIU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size     = Vector2(1280, 80)
	title.position = Vector2(0, 250)
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Styles.BLOOD.lightened(0.3))
	canvas.add_child(title)

	var btn := Button.new()
	btn.text = "Jogar de novo"
	btn.custom_minimum_size = Vector2(200, 46)
	btn.position = Vector2(1280 / 2.0 - 100, 360)
	btn.add_theme_font_size_override("font_size", 16)
	Styles.gold_button(btn, Styles.GOLD, Styles.GOLD.lightened(0.2))
	btn.pressed.connect(_restart)
	canvas.add_child(btn)

	_tower_menu.hide_menu()
	get_tree().paused = true

func _restart() -> void:
	get_tree().paused = false
	GameState.reset()
	get_tree().reload_current_scene()

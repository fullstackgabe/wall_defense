extends Node2D

## Scene tree expected:
##   Main (this script)
##     Map       (map.gd)
##     TowerMenu (tower_menu.gd, Control)

const _ArcherTower = preload("res://archer_tower.gd")
const _WaveManager = preload("res://wave_manager.gd")
const _JonSnow     = preload("res://jon_snow.gd")
const Styles       = preload("res://styles.gd")

const TOWER_SCRIPTS := { "archer": _ArcherTower }
const JON_SNOW_SPAWN_CELL := Vector2i(16, 12)
const RESPAWN_DELAY := 15.0

@onready var _map:        Node2D  = $Map
@onready var _tower_menu: Control = $TowerMenu

var _wave_manager   = null
var _jon_snow       = null
var _respawning:    bool  = false
var _respawn_timer: float = 0.0
var _respawn_btn:   Button = null
var _respawn_label: Label  = null
var _respawn_canvas: CanvasLayer = null

# ---------------------------------------------------------------------------

func _ready() -> void:
	_wave_manager = _WaveManager.new()
	add_child(_wave_manager)
	_wave_manager.setup(_map, _map)

	_map.pad_clicked.connect(_on_pad_clicked)
	_tower_menu.tower_chosen.connect(_on_tower_chosen)

	GameState.state_changed.connect(_on_state_changed)
	_build_respawn_ui()
	_build_spawn_btn()
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

func _build_spawn_btn() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var btn := Button.new()
	btn.text = "Enviar Inimigos"
	btn.custom_minimum_size = Vector2(200, 46)
	btn.add_theme_font_size_override("font_size", 14)
	Styles.gold_button(btn, Styles.GOLD, Styles.GOLD.lightened(0.2))
	btn.add_theme_color_override("font_color", Styles.NIGHT)
	btn.pressed.connect(func(): _wave_manager.spawn_pair())
	canvas.add_child(btn)
	await get_tree().process_frame
	btn.position = Vector2(1280 / 2.0 - btn.size.x / 2.0, 720 - btn.size.y - 12)

func _process(delta: float) -> void:
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
			t.queue_free()
		return
	var script = TOWER_SCRIPTS.get(tower_type)
	if script:
		pad.place_tower(script.new())

func _on_state_changed(new_state: GameState.State) -> void:
	if new_state == GameState.State.GAME_OVER:
		print("GAME OVER")

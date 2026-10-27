extends Control

const Styles = preload("res://styles.gd")

signal tower_chosen(tower_type, pad)
signal cancelled

## locked = torre planejada, ainda não implementada (aparece como “Em breve”).
const TOWER_DEFS := [
	{"type": "archer",     "label": "Torre de Flecha",   "cost": 50,  "locked": false},
	{"type": "barracks",   "label": "Quartel da Patrulha", "cost": 70,  "locked": true},
	{"type": "catapult",   "label": "Catapulta",         "cost": 100, "locked": true},
	{"type": "dragonglass","label": "Vidro de Dragão",   "cost": 120, "locked": true},
]

const SELL_REFUND := 0.6   ## fração do custo devolvida ao vender a torre

const LOCKED_BG := Color(0.22, 0.24, 0.28)

const PANEL_W  := 300
## Área do mundo onde o menu pode aparecer (mapa 1600×880). O menu é escalado por
## 1/zoom da câmera (em main.gd) para manter o tamanho na tela.
const WORLD_W := 1600
const WORLD_H := 880

var _current_pad = null
var _outer: PanelContainer
var _buttons: Array[Button] = []
var _build_panel: Control
var _remove_panel: Control
var _remove_title: Label
var _remove_btn:   Button

func _ready() -> void:
	visible = false
	_build_ui()

func _build_ui() -> void:
	_outer = PanelContainer.new()
	_outer.custom_minimum_size = Vector2(PANEL_W, 0)
	_outer.add_theme_stylebox_override("panel",
		Styles.bordered(Styles.NIGHT, Styles.GOLD, 8, 2))
	add_child(_outer)

	var vbox_outer := VBoxContainer.new()
	vbox_outer.add_theme_constant_override("separation", 0)
	_outer.add_child(vbox_outer)

	## ---- BUILD PANEL ----
	_build_panel = VBoxContainer.new()
	_build_panel.add_theme_constant_override("separation", 6)
	vbox_outer.add_child(_build_panel)

	for t in TOWER_DEFS:
		_build_panel.add_child(_build_tower_row(t))

	## ---- REMOVE PANEL ----
	_remove_panel = VBoxContainer.new()
	_remove_panel.add_theme_constant_override("separation", 6)
	_remove_panel.visible = false
	vbox_outer.add_child(_remove_panel)

	_remove_title = Label.new()
	_remove_title.add_theme_color_override("font_color", Styles.SNOW)
	_remove_title.add_theme_font_size_override("font_size", 13)
	_remove_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_remove_panel.add_child(_remove_title)

	_remove_btn = Button.new()
	_remove_btn.custom_minimum_size = Vector2(0, 32)
	_remove_btn.add_theme_font_size_override("font_size", 12)
	_remove_btn.add_theme_stylebox_override("normal", Styles.flat(Color(0.45, 0.0, 0.0), 6, 8))
	_remove_btn.add_theme_stylebox_override("hover",  Styles.flat(Color(0.65, 0.0, 0.0), 6, 8))
	_remove_btn.add_theme_color_override("font_color", Styles.SNOW)
	_remove_btn.pressed.connect(func(): _on_tower_btn("__remove__"))
	_remove_panel.add_child(_remove_btn)

## Linha: [nome da torre]  [Construir · custo]  (ou [Em breve · custo] se bloqueada)
func _build_tower_row(t: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_lbl := Label.new()
	name_lbl.text = t.label
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color",
		Styles.SNOW.darkened(0.45) if t.locked else Styles.SNOW)
	name_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(name_lbl)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(124, 30)
	btn.add_theme_font_size_override("font_size", 12)
	if t.locked:
		btn.text = "Em breve · %d" % t.cost
		btn.disabled = true
		btn.add_theme_stylebox_override("disabled", Styles.flat(LOCKED_BG, 6))
		btn.add_theme_color_override("font_disabled_color", Styles.SNOW.darkened(0.45))
	else:
		btn.text = "Construir · %d" % t.cost
		Styles.gold_button(btn, Styles.GOLD.darkened(0.2), Styles.GOLD)
		btn.add_theme_stylebox_override("disabled", Styles.flat(Styles.GOLD.darkened(0.6), 6))
		btn.add_theme_color_override("font_color", Styles.NIGHT)
		btn.add_theme_color_override("font_disabled_color", Styles.NIGHT.lightened(0.3))
		var type_copy: String = t.type
		btn.pressed.connect(_on_tower_btn.bind(type_copy))
	_buttons.append(btn)
	row.add_child(btn)

	return row

# ---------------------------------------------------------------------------

func show_at_pad(pad) -> void:
	_current_pad = pad
	if pad.is_free():
		_build_panel.visible  = true
		_remove_panel.visible = false
		_refresh_buttons()
	else:
		_build_panel.visible  = false
		_remove_panel.visible = true
		_remove_title.text = _get_tower_label(pad.tower)
		_remove_btn.text   = "Destruir (+%d)" % sell_value(pad.tower.tower_type)
	visible = true
	_outer.reset_size()
	var panel_h := _outer.get_combined_minimum_size().y
	size = Vector2(PANEL_W, panel_h)
	## Acima do slot (o slot fica na base da torre, logo abaixo da muralha)
	var world_pos: Vector2 = pad.global_position
	var w := PANEL_W * scale.x
	var h := panel_h * scale.y
	var px := world_pos.x - w / 2.0
	var py := world_pos.y - 24 - h
	position = Vector2(
		clamp(px, 4, WORLD_W - w - 4),
		clamp(py, 4, WORLD_H - h - 4)
	)

func hide_menu() -> void:
	visible = false
	_current_pad = null
	cancelled.emit()

func _refresh_buttons() -> void:
	for i in _buttons.size():
		if TOWER_DEFS[i].locked:
			continue
		_buttons[i].disabled = GameState.gold < TOWER_DEFS[i].cost

func get_cost(tower_type: String) -> int:
	for t in TOWER_DEFS:
		if t.type == tower_type:
			return t.cost
	return 0

func sell_value(tower_type: String) -> int:
	return int(get_cost(tower_type) * SELL_REFUND)

func _get_tower_label(tower: Node2D) -> String:
	if tower == null or not tower.get("tower_type"):
		return TOWER_DEFS[0].label
	for t in TOWER_DEFS:
		if t.type == tower.tower_type:
			return t.label
	return TOWER_DEFS[0].label

func _on_tower_btn(tower_type: String) -> void:
	if _current_pad == null:
		return
	var pad = _current_pad
	hide_menu()
	tower_chosen.emit(tower_type, pad)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if not Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()):
				hide_menu()

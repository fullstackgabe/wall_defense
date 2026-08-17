extends Control

const Styles = preload("res://styles.gd")

signal tower_chosen(tower_type, pad)
signal cancelled

const TOWER_DEFS := [
	{"type": "archer", "label": "Torre de Flecha", "cost": 50},
]

const PANEL_W  := 240
const SCREEN_W := 1280
const SCREEN_H := 720

var _current_pad = null
var _buttons: Array[Button] = []
var _build_panel: Control
var _remove_panel: Control
var _remove_title: Label

func _ready() -> void:
	visible = false
	_build_ui()

func _build_ui() -> void:
	var outer := PanelContainer.new()
	outer.add_theme_stylebox_override("panel",
		Styles.bordered(Styles.NIGHT, Styles.GOLD, 8, 2))
	add_child(outer)

	var vbox_outer := VBoxContainer.new()
	vbox_outer.add_theme_constant_override("separation", 0)
	outer.add_child(vbox_outer)

	## ---- BUILD PANEL ----
	_build_panel = VBoxContainer.new()
	_build_panel.add_theme_constant_override("separation", 4)
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

	var remove_btn := Button.new()
	remove_btn.text = "Destruir"
	remove_btn.custom_minimum_size = Vector2(0, 32)
	remove_btn.add_theme_font_size_override("font_size", 12)
	remove_btn.add_theme_stylebox_override("normal", Styles.flat(Color(0.45, 0.0, 0.0), 6, 8))
	remove_btn.add_theme_stylebox_override("hover",  Styles.flat(Color(0.65, 0.0, 0.0), 6, 8))
	remove_btn.add_theme_color_override("font_color", Styles.SNOW)
	remove_btn.pressed.connect(func(): _on_tower_btn("__remove__"))
	_remove_panel.add_child(remove_btn)

	custom_minimum_size = Vector2(PANEL_W, 0)

## Coluna: [nome torre] / [Construir]
func _build_tower_row(t: Dictionary) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	var name_lbl := Label.new()
	name_lbl.text = t.label
	name_lbl.add_theme_color_override("font_color", Styles.SNOW)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	var btn := Button.new()
	btn.text = "Construir"
	btn.custom_minimum_size = Vector2(0, 32)
	btn.add_theme_font_size_override("font_size", 12)
	Styles.gold_button(btn, Styles.GOLD.darkened(0.2), Styles.GOLD)
	btn.add_theme_color_override("font_color", Styles.NIGHT)
	var type_copy: String = t.type
	btn.pressed.connect(_on_tower_btn.bind(type_copy))
	_buttons.append(btn)
	vbox.add_child(btn)

	return vbox

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
	visible = true
	var world_pos: Vector2 = pad.global_position
	var px := world_pos.x - PANEL_W / 2.0
	var py := world_pos.y - size.y - 8
	position = Vector2(
		clamp(px, 4, SCREEN_W - PANEL_W - 4),
		clamp(py, 4, SCREEN_H - size.y - 4)
	)

func hide_menu() -> void:
	visible = false
	_current_pad = null
	cancelled.emit()

func _refresh_buttons() -> void:
	for btn in _buttons:
		btn.disabled = false
		btn.modulate = Color.WHITE

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
			if not get_rect().has_point(get_local_mouse_position()):
				hide_menu()

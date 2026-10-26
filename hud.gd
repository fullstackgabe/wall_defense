class_name Hud
extends CanvasLayer

## Painel fixo no canto superior esquerdo com ouro e vidas.
## Atualiza sozinho pelos sinais do GameState.

var _gold_label:  Label
var _lives_label: Label

# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_ui()
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.lives_changed.connect(_on_lives_changed)
	_on_gold_changed(GameState.gold)
	_on_lives_changed(GameState.lives)

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.add_theme_stylebox_override("panel",
		Styles.bordered(Color(Styles.NIGHT, 0.85), Styles.GOLD, 8, 2))
	add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	panel.add_child(hbox)

	_gold_label  = _make_label(Styles.GOLD)
	_lives_label = _make_label(Styles.SNOW)
	hbox.add_child(_gold_label)
	hbox.add_child(_lives_label)

func _make_label(color: Color) -> Label:
	var lbl := Label.new()
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 16)
	return lbl

# ---------------------------------------------------------------------------

func _on_gold_changed(value: int) -> void:
	_gold_label.text = "Ouro: %d" % value

func _on_lives_changed(value: int) -> void:
	_lives_label.text = "Vidas: %d" % value
	if value <= 3:
		_lives_label.add_theme_color_override("font_color", Styles.BLOOD.lightened(0.3))

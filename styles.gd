class_name Styles

# Paleta temática Wall Defense (Game of Thrones)
const NIGHT  := Color(0.039, 0.086, 0.157)  # #0A1628 — fundo de UI, tela de título
const ICE    := Color(0.722, 0.831, 0.910)  # #B8D4E8 — tiles da Muralha, fundos claros
const GOLD   := Color(0.784, 0.659, 0.294)  # #C8A84B — ouro, botões, bordas
const BLOOD  := Color(0.545, 0.000, 0.000)  # #8B0000 — dano, game over
const SNOW   := Color(0.910, 0.937, 0.961)  # #E8EFF5 — texto principal

static func flat(color: Color, radius := 6, padding := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_content_margin_all(padding)
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	return s

static func bordered(bg: Color, border: Color, radius := 8, border_px := 3) -> StyleBoxFlat:
	var s := flat(bg, radius)
	s.border_color        = border
	s.border_width_top    = border_px
	s.border_width_bottom = border_px
	s.border_width_left   = border_px
	s.border_width_right  = border_px
	return s

static func gold_button(btn: Button, normal: Color, hover: Color) -> void:
	btn.add_theme_stylebox_override("normal", flat(normal, 6))
	btn.add_theme_stylebox_override("hover",  flat(hover,  6))
	btn.add_theme_color_override("font_color", NIGHT)

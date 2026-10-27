class_name HpBar
extends Node2D

## Barra de vida com z_index alto: o sprite do personagem fica por baixo das árvores e
## do portão (y-sort do mapa), mas a barra continua visível por cima de tudo.

const BAR_W := 36.0
const BAR_H := 4.0

var ratio_fn: Callable          ## devolve a vida atual em 0–1
var color_full := Color(0.1, 0.8, 0.1)
var color_low  := Color(0.9, 0.2, 0.1)
var low_below  := 0.5           ## abaixo disso usa color_low

var _ratio := -1.0

func _init(fn: Callable, y_offset: float) -> void:
	ratio_fn = fn
	position = Vector2(0.0, y_offset)
	z_index  = 50

func _process(_delta: float) -> void:
	var r: float = clampf(ratio_fn.call(), 0.0, 1.0)
	if r != _ratio:
		_ratio = r
		queue_redraw()

func _draw() -> void:
	var off := Vector2(-BAR_W / 2.0, 0.0)
	draw_rect(Rect2(off, Vector2(BAR_W, BAR_H)), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(off, Vector2(BAR_W * _ratio, BAR_H)), color_full if _ratio > low_below else color_low)

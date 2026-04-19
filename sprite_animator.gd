class_name SpriteAnimator
extends Node

## Reusable 8-directional sprite animator.
## Add as child node, call setup(), then tick() from _process.

const WALK_FRAME_INTERVAL   := 0.12
const ATTACK_FRAME_INTERVAL := 0.28

const HIT_FRAME := 2   ## frame do impacto dentro do ciclo de ataque

signal attack_hit      ## emitido uma vez por ciclo, no frame de impacto

var _sprite: Sprite2D
var _walk_textures: Dictionary = {}
var _attack_textures: Dictionary = {}
var _dir: String = "south"
var _char_folder: String = ""
var _idle_texture: Texture2D = null
var _playing: bool = false
var _attacking: bool = false
var _frame: int = 0
var _frame_t: float = 0.0
var _hit_fired: bool = false  ## garante uma emissão por ciclo

# ---------------------------------------------------------------------------

func setup(char_folder: String, size_px: float = 80.0) -> void:
	_char_folder = char_folder
	_load_textures(char_folder)
	_build_sprite(char_folder, size_px)

func set_dir(dir: String) -> void:
	_dir = dir

func play(attacking: bool = false) -> void:
	if attacking and not _attacking:
		_frame     = 0
		_frame_t   = 0.0
		_hit_fired = false
	elif not attacking and _attacking:
		## Voltou a andar — garante reset do hit para próximo ataque
		_hit_fired = false
	_playing   = true
	_attacking = attacking

func stop() -> void:
	_playing   = false
	_attacking = false
	_frame     = 0
	_hit_fired = false
	if _sprite != null and _idle_texture != null:
		_sprite.texture = _idle_texture

func tick(delta: float) -> void:
	if not _playing:
		return
	var interval := ATTACK_FRAME_INTERVAL if _attacking else WALK_FRAME_INTERVAL
	_frame_t += delta
	if _frame_t < interval:
		return
	_frame_t -= interval
	## Usa o tamanho real dos frames carregados para o ciclo
	var pool   := _attack_textures if _attacking else _walk_textures
	var frames := _frames_for_dir(pool, _dir)
	var count  := frames.size() if frames.size() > 0 else 8
	_frame = (_frame + 1) % count
	if _frame == 0:
		_hit_fired = false
	if _attacking and _frame == HIT_FRAME % count and not _hit_fired:
		_hit_fired = true
		attack_hit.emit()
	_update_frame()

# ---------------------------------------------------------------------------

func _load_textures(char_folder: String) -> void:
	var dirs := ["south","north","east","west",
				 "south-east","south-west","north-east","north-west"]
	for d in dirs:
		var walk_frames: Array[Texture2D] = []
		for i in range(8):
			var p := "res://characters/%s/walk/%s/frame_%03d.png" % [char_folder, d, i]
			if ResourceLoader.exists(p):
				walk_frames.append(load(p))
		if not walk_frames.is_empty():
			_walk_textures[d] = walk_frames

		var atk_frames: Array[Texture2D] = []
		for i in range(8):
			var p := "res://characters/%s/attack/%s/frame_%03d.png" % [char_folder, d, i]
			if ResourceLoader.exists(p):
				atk_frames.append(load(p))
		if not atk_frames.is_empty():
			_attack_textures[d] = atk_frames

func _build_sprite(char_folder: String, size_px: float) -> void:
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var idle := "res://characters/%s/stopped.png" % char_folder
	if ResourceLoader.exists(idle):
		_idle_texture   = load(idle)
		_sprite.texture = _idle_texture
		var tw := float(_sprite.texture.get_width())
		var th := float(_sprite.texture.get_height())
		_sprite.scale = Vector2.ONE * (size_px / maxf(tw, th))
	get_parent().add_child(_sprite)

func _update_frame() -> void:
	var pool := _attack_textures if _attacking and not _attack_textures.is_empty() \
				else _walk_textures
	var frames: Array = _frames_for_dir(pool, _dir)
	if frames.is_empty() or _sprite == null:
		return
	_sprite.texture = frames[_frame % frames.size()]

func get_sprite() -> Sprite2D:
	return _sprite

## Falls back to nearest cardinal when diagonal is missing.
func _frames_for_dir(pool: Dictionary, dir: String) -> Array:
	if pool.has(dir):
		return pool[dir]
	var parts := dir.split("-")
	if parts.size() == 2:
		if pool.has(parts[1]): return pool[parts[1]]
		if pool.has(parts[0]): return pool[parts[0]]
	return pool.get("south", [])

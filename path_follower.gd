class_name PathFollower
extends Node

var _path: Array         ## Array[Vector2]
var _speed: float = 55.0
var _idx: int = 1        ## next waypoint index
var _finished: bool = false

signal reached_end

func setup(path: Array, spd: float) -> void:
	_path = path
	_speed = spd
	_idx = 1
	_finished = false

## Advances node along path. Returns movement vector this frame.
func advance(delta: float, node: Node2D) -> Vector2:
	if _finished or _path.size() < 2:
		return Vector2.ZERO

	var target: Vector2 = _path[_idx]
	var to_target: Vector2 = target - node.global_position
	var dist: float = to_target.length()
	var step: float = _speed * delta

	if step >= dist:
		node.global_position = target
		_idx += 1
		if _idx >= _path.size():
			_finished = true
			reached_end.emit()
		return to_target.normalized() * dist

	node.global_position += to_target.normalized() * step
	return to_target.normalized() * step

## 0.0 = just spawned, 1.0 = reached end. Used by towers to prioritise targets.
func get_progress() -> float:
	if _path.size() <= 1:
		return 1.0
	return float(_idx - 1) / float(_path.size() - 1)

func is_finished() -> bool:
	return _finished

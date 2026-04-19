extends Node

const STARTING_GOLD  := 99999
const STARTING_LIVES := 10

var gold:  int = STARTING_GOLD
var lives: int = STARTING_LIVES

enum State { PREP, GAME_OVER }
var state: State = State.PREP

signal gold_changed(value: int)
signal lives_changed(value: int)
signal state_changed(new_state: State)

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

func lose_lives(amount: int) -> void:
	lives = maxi(0, lives - amount)
	lives_changed.emit(lives)
	if lives == 0:
		_set_state(State.GAME_OVER)

func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(state)

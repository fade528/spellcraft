extends Node

signal life_lost(lives_remaining: int)
signal hp_changed(current_hp: float, max_hp: float)
signal game_over

@export var starting_lives: int = 3
@export var max_hp: float = 100.0

var lives: int
var current_hp: float
var _active_debuffs: Array[String] = []


func _ready() -> void:
	reset_run()


func take_damage(amount: float) -> void:
	print("[PM] take_damage called — amount: %.2f" % amount)
	current_hp = max(current_hp - amount, 0.0)
	hp_changed.emit(current_hp, max_hp)
	var _pm_soul = get_node_or_null("/root/PassiveManager")
	if _pm_soul != null and _pm_soul.has_method("on_player_damaged"):
		_pm_soul.on_player_damaged(amount)

	if current_hp <= 0.0:
		_lose_life()


func heal(amount: float) -> void:
	current_hp = minf(current_hp + amount, max_hp)
	hp_changed.emit(current_hp, max_hp)
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node != null and player_node.has_method("flash_heal"):
		player_node.flash_heal()


func register_debuff(debuff_name: String) -> void:
	_active_debuffs.push_back(debuff_name)


func remove_debuffs(count: int) -> Array[String]:
	# Removes up to count debuffs from most recent first.
	# Returns the list of removed names (for callers to act on).
	var removed: Array[String] = []
	for i in range(count):
		if _active_debuffs.is_empty():
			break
		removed.push_back(_active_debuffs.pop_back())
	return removed


func _lose_life() -> void:
	lives = max(lives - 1, 0)
	life_lost.emit(lives)

	if lives <= 0:
		_on_run_end()
		game_over.emit()
	else:
		refill_hp()


func _on_run_end() -> void:
	var inv = get_node_or_null("/root/PlayerInventory")
	if inv != null and inv.has_method("reset_run"):
		inv.reset_run()

	var pm = get_node_or_null("/root/PassiveManager")
	if pm != null and pm.has_method("recalculate"):
		pm.call_deferred("recalculate")


func refill_hp() -> void:
	current_hp = max_hp
	hp_changed.emit(current_hp, max_hp)


func reset_run() -> void:
	lives = starting_lives
	current_hp = max_hp
	_active_debuffs.clear()

extends Node

var element_counts: Dictionary = {}
var active_passives: Array[Dictionary] = []
var equipment: Dictionary = {
	"hat": null,
	"robe": null,
	"gloves": null,
	"boots": null,
	"weapon": null
}
var mana_pool: int = 0
var school_allocation: Dictionary = {}
var unallocated_mana: int = 0


func add_element(element: String) -> void:
	var element_key := element.to_lower()
	element_counts[element_key] = int(element_counts.get(element_key, 0)) + 1


func get_count(element: String) -> int:
	return int(element_counts.get(element.to_lower(), 0))


func get_scaling_multiplier(element: String) -> float:
	return 1.0 + get_count(element) * 0.02


func register_passive(effect: Dictionary) -> void:
	var effect_name := str(effect.get("effect_name", ""))
	if effect_name.is_empty():
		return

	for passive in active_passives:
		if str(passive.get("effect_name", "")) == effect_name:
			return

	active_passives.append(effect.duplicate(true))


func unregister_passive(effect_name: String) -> void:
	for index in range(active_passives.size() - 1, -1, -1):
		if str(active_passives[index].get("effect_name", "")) == effect_name:
			active_passives.remove_at(index)


func get_passives() -> Array[Dictionary]:
	return active_passives.duplicate(true)


func add_mana(amount: int) -> void:
	mana_pool += amount
	var spec_manager = get_node_or_null("/root/SpecManager")
	if spec_manager != null and spec_manager.has_method("allocate_mana_for_pickup"):
		spec_manager.allocate_mana_for_pickup(amount)
	else:
		unallocated_mana += amount


func allocate_to_school(school: String, amount: int) -> void:
	if amount <= 0 or amount > unallocated_mana:
		return
	var key := school.to_lower()
	school_allocation[key] = int(school_allocation.get(key, 0)) + amount
	unallocated_mana -= amount


func deallocate_from_school(school: String, amount: int) -> void:
	var key := school.to_lower()
	var current := int(school_allocation.get(key, 0))
	var to_remove := mini(amount, current)
	if to_remove <= 0:
		return
	school_allocation[key] = current - to_remove
	unallocated_mana += to_remove


func get_school_tier(school: String) -> int:
	return int(school_allocation.get(school.to_lower(), 0))


func get_school_multiplier(school: String) -> float:
	return 1.0 + get_school_tier(school) * 0.05


func reset_run() -> void:
	element_counts.clear()
	active_passives.clear()
	mana_pool = 0
	school_allocation.clear()
	unallocated_mana = 0

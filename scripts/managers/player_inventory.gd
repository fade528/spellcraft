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


func reset_run() -> void:
	element_counts.clear()
	active_passives.clear()

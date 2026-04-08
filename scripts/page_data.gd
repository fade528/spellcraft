class_name PageData
extends Resource


@export var page_name: String = "Page 1"

# Array of up to 4 slot Dictionaries.
# Each dict has keys:
#   elemental: String
#   empowerment: String
#   enchantment: String
#   delivery: String
#   target: String
@export var slots: Array[Dictionary] = []

@export var summon_element: String = "fire"
@export var ult1: String = ""
@export var ult2: String = ""


static func make_default_slot() -> Dictionary:
	return {
		"elemental": "fire",
		"empowerment": "fire",
		"enchantment": "fire",
		"delivery": "bolt",
		"target": "enemy"
	}


func ensure_slots(count: int = 4) -> void:
	while slots.size() < count:
		slots.append(PageData.make_default_slot())

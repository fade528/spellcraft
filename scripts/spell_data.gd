extends Resource
class_name SpellData

@export var spell_name: String = "Basic Bolt"
@export var elemental_element: String = "Arcane"
@export var empowerment_element: String = "None"
@export var enchantment_element: String = "None"
@export var combo_name: String = ""
@export var total_cd: float = 0.0
@export var total_budget: float = 0.0
@export var delivery_type: String = "bolt"
@export var dmgmult_chain: float = 1.0
@export var damage: float = 10.0
@export var cooldown: float = 0.6
@export var projectile_speed: float = 850.0

# Effects applied on projectile hit (enemy-targeted rows)
@export var on_hit_effects: Array[Dictionary] = []

# Effects applied to player (self-targeted rows)
@export var self_effects: Array[Dictionary] = []

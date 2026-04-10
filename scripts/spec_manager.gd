extends Node

const SPEC_PATHS := {
	"Pyroclast": "res://data/specs/pyroclast.tres",
	"Frostbinder": "res://data/specs/frostbinder.tres",
	"Archmage": "res://data/specs/archmage.tres",
}

var _active_spec: SpecData = null
var _active_spec_name: String = ""


func apply_spec(spec_name: String) -> void:
	if not SPEC_PATHS.has(spec_name):
		push_warning("SpecManager: unknown spec: " + spec_name)
		return
	var loaded = load(SPEC_PATHS[spec_name])
	if loaded == null:
		push_warning("SpecManager: failed to load: " + SPEC_PATHS[spec_name])
		return
	_active_spec = loaded as SpecData
	_active_spec_name = spec_name


func clear_spec() -> void:
	_active_spec = null
	_active_spec_name = ""


func get_active_spec() -> SpecData:
	return _active_spec


func get_active_spec_name() -> String:
	return _active_spec_name


func is_archmage() -> bool:
	return _active_spec == null or _active_spec_name == "Archmage"


func allocate_mana_for_pickup(amount: int) -> void:
	var inv = get_node_or_null("/root/PlayerInventory")
	if inv == null:
		return

	if is_archmage() or _active_spec == null:
		inv.unallocated_mana += amount
		return

	var ratios: Dictionary = _active_spec.allocation_ratios
	if ratios.is_empty():
		inv.unallocated_mana += amount
		return

	var remaining := amount
	var schools := ratios.keys()

	for i in range(schools.size()):
		var school: String = schools[i]
		var ratio: float = float(ratios[school])
		var share: int
		if i == schools.size() - 1:
			share = remaining
		else:
			share = int(floor(float(amount) * ratio))
		share = mini(share, remaining)
		if share > 0:
			inv.allocate_to_school(school, share)
			remaining -= share

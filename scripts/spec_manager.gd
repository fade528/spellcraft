extends Node

const SPEC_PATHS := {
	"Pyroclast": "res://data/specs/pyroclast.tres",
	"Frostbinder": "res://data/specs/frostbinder.tres",
	"Archmage": "res://data/specs/archmage.tres",
}
const CUSTOM_SAVE_PATH := "user://specs.json"

var _active_spec: SpecData = null
var _active_spec_name: String = ""
var _custom_specs: Dictionary = {}


func _ready() -> void:
	load_custom_specs()


func apply_spec(spec_name: String) -> void:
	if spec_name == "Archmage":
		clear_spec()
		return
	if _custom_specs.has(spec_name):
		_active_spec = _spec_from_dict(_custom_specs[spec_name])
		_active_spec_name = spec_name
	elif SPEC_PATHS.has(spec_name):
		var loaded = load(SPEC_PATHS[spec_name])
		if loaded == null:
			push_warning("SpecManager: failed to load: " + SPEC_PATHS[spec_name])
			return
		_active_spec = loaded as SpecData
		_active_spec_name = spec_name
	else:
		push_warning("SpecManager: unknown spec: " + spec_name)
		return
	var tm = get_node_or_null("/root/TomeManager")
	if tm != null:
		var preferred: Array = _active_spec.preferred_slots if _active_spec != null else []
		tm.load_for_spec(spec_name, preferred)


func clear_spec() -> void:
	_active_spec = null
	_active_spec_name = ""
	var tm = get_node_or_null("/root/TomeManager")
	if tm != null:
		tm.load_for_spec("archmage", [])


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
	inv.unallocated_mana += amount


func get_all_spec_names() -> Array[String]:
	var names: Array[String] = []
	for key in SPEC_PATHS.keys():
		if key != "Archmage":
			names.append(key)
	for key in _custom_specs.keys():
		names.append(key)
	return names


func save_spec_from_dict(spec_name: String, data: Dictionary) -> void:
	_custom_specs[spec_name] = data
	save_custom_specs()


func delete_custom_spec(spec_name: String) -> void:
	if _custom_specs.has(spec_name):
		_custom_specs.erase(spec_name)
		save_custom_specs()
		if _active_spec_name == spec_name:
			clear_spec()


func save_custom_specs() -> void:
	var file := FileAccess.open(CUSTOM_SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_custom_specs))


func load_custom_specs() -> void:
	if not FileAccess.file_exists(CUSTOM_SAVE_PATH):
		return
	var file := FileAccess.open(CUSTOM_SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_custom_specs = parsed


func _spec_from_dict(data: Dictionary) -> SpecData:
	var s := SpecData.new()
	s.spec_name = str(data.get("spec_name", ""))
	s.description = str(data.get("description", ""))
	s.allocation_ratios = data.get("allocation_ratios", {})
	var slots_raw: Array = data.get("preferred_slots", [])
	var typed_slots: Array[Dictionary] = []
	for slot in slots_raw:
		if slot is Dictionary:
			typed_slots.append(slot)
	s.preferred_slots = typed_slots
	var ults_raw: Array = data.get("preferred_ults", [])
	var typed_ults: Array[String] = []
	for ult in ults_raw:
		typed_ults.append(str(ult))
	s.preferred_ults = typed_ults
	return s


func allocate_remaining_by_spec() -> void:
	var inv = get_node_or_null("/root/PlayerInventory")
	if inv == null or is_archmage() or _active_spec == null:
		return
	var ratios: Dictionary = _active_spec.allocation_ratios
	if ratios.is_empty():
		return
	var total: int = inv.unallocated_mana
	if total <= 0:
		return
	var remaining: int = total
	var schools := ratios.keys()
	for i in range(schools.size()):
		var school: String = schools[i]
		var share: int
		if i == schools.size() - 1:
			share = remaining
		else:
			share = int(floor(float(total) * float(ratios[school])))
		share = mini(share, remaining)
		if share > 0:
			inv.school_allocation[school] = int(inv.school_allocation.get(school, 0)) + share
			remaining -= share
	inv.unallocated_mana = remaining


func allocate_all_by_spec() -> void:
	var inv = get_node_or_null("/root/PlayerInventory")
	if inv == null or is_archmage() or _active_spec == null:
		return
	# Move all school allocation back to unallocated
	for school in inv.school_allocation.keys():
		inv.unallocated_mana += int(inv.school_allocation[school])
	inv.school_allocation.clear()
	allocate_remaining_by_spec()


func save_archmage_as_spec(new_name: String) -> void:
	var tm = get_node_or_null("/root/TomeManager")
	var inv = get_node_or_null("/root/PlayerInventory")
	if tm == null or new_name.strip_edges().is_empty():
		return
	# Build preferred_slots from current archmage pages
	var preferred: Array = []
	for page in tm.pages:
		if not page.slots.is_empty():
			preferred.append(page.slots[0].duplicate())
	# Build ratios from current school allocation
	var ratios: Dictionary = {}
	if inv != null:
		var total := 0
		for school in inv.school_allocation.keys():
			total += int(inv.school_allocation[school])
		if total > 0:
			for school in inv.school_allocation.keys():
				ratios[school] = float(inv.school_allocation[school]) / float(total)
	var data := {
		"spec_name": new_name,
		"description": "",
		"allocation_ratios": ratios,
		"preferred_slots": preferred,
		"preferred_ults": [],
		"summon_element": "fire"
	}
	save_spec_from_dict(new_name, data)
	# Copy current archmage pages to new spec save file
	tm.save_pages()
	var archmage_path: String = tm._save_path_for("archmage")
	var new_path: String = tm._save_path_for(new_name)
	if FileAccess.file_exists(archmage_path):
		var content := FileAccess.open(archmage_path, FileAccess.READ).get_as_text()
		var out := FileAccess.open(new_path, FileAccess.WRITE)
		if out != null:
			out.store_string(content)
	# Switch to the new spec
	apply_spec(new_name)

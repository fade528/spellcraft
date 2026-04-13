extends Node

var _rows: Dictionary = {}
var _index: Dictionary = {}

const SPELL_ELEMENTS_CSV_PATH := "res://data/spell_elements.csv"

const COL_SPELL_ID := 0
const COL_ELEMENT := 1
const COL_POSITION := 2
const COL_TARGET := 3
const COL_EFFECT_NAME := 4
const COL_VALUE1 := 5
const COL_VALUE2 := 6
const COL_VALUE3 := 7
const COL_VALUE4 := 8
const COL_VALUE5 := 9
const COL_CD := 10
const COL_CD_TYPE := 11
const COL_DMGMULT := 12
const COL_BUDGET := 13
const COL_DESCRIPTION := 14
const COL_SCALE_VALUE1 := 15
const COL_SCALE_VALUE2 := 16
const COL_SCALE_VALUE3 := 17
const COL_SCALE_VALUE4 := 18
const COL_SCALE_VALUE5 := 19
const COL_SCALE_DMGMULT := 20
# col 21 = Scale Description (ignored)
const COL_STATUS := 22
const COL_DISPLAY_TEXT := 23


func _ready() -> void:
	_parse_spell_elements_csv()


func _parse_spell_elements_csv() -> void:
	_rows.clear()
	_index.clear()

	var file := FileAccess.open(SPELL_ELEMENTS_CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("SpellComposer failed to open %s" % SPELL_ELEMENTS_CSV_PATH)
		return

	if file.get_position() < file.get_length():
		file.get_csv_line(",")

	while file.get_position() < file.get_length():
		var columns := file.get_csv_line(",")
		if columns.is_empty():
			continue
		while columns.size() < 24:
			columns.append("")

		var row := {
			"spell_id": columns[COL_SPELL_ID].strip_edges(),
			"element": columns[COL_ELEMENT].strip_edges(),
			"position": columns[COL_POSITION].strip_edges(),
			"target": columns[COL_TARGET].strip_edges(),
			"effect_name": columns[COL_EFFECT_NAME].strip_edges(),
			"value1": _to_float(columns[COL_VALUE1]),
			"value2": _to_float(columns[COL_VALUE2]),
			"value3": _to_float(columns[COL_VALUE3]),
			"value4": _to_float(columns[COL_VALUE4]),
			"value5": _to_float(columns[COL_VALUE5]),
			"value1_raw": columns[COL_VALUE1].strip_edges(),
			"value2_raw": columns[COL_VALUE2].strip_edges(),
			"value3_raw": columns[COL_VALUE3].strip_edges(),
			"value4_raw": columns[COL_VALUE4].strip_edges(),
			"value5_raw": columns[COL_VALUE5].strip_edges(),
			"cd": _to_float(columns[COL_CD]),
			"cd_type": columns[COL_CD_TYPE].strip_edges(),
			"dmgmult": _to_float(columns[COL_DMGMULT]),
			"budget": _to_float(columns[COL_BUDGET]),
			"description": columns[COL_DESCRIPTION].strip_edges(),
			"display_text": columns[COL_DISPLAY_TEXT].strip_edges(),
			"scale_value1": _to_float(columns[COL_SCALE_VALUE1]),
			"scale_value2": _to_float(columns[COL_SCALE_VALUE2]),
			"scale_value3": _to_float(columns[COL_SCALE_VALUE3]),
			"scale_value4": _to_float(columns[COL_SCALE_VALUE4]),
			"scale_value5": _to_float(columns[COL_SCALE_VALUE5]),
			"scale_dmgmult": _to_float(columns[COL_SCALE_DMGMULT])
		}

		var status := columns[COL_STATUS].strip_edges().to_lower()
		var is_summon_row := str(row["position"]).to_lower() == "summon" and str(row["target"]).to_lower() == "summon"
		if status != "active" and not is_summon_row:
			continue

		var spell_id := str(row["spell_id"])
		if spell_id.is_empty():
			continue

		_rows[spell_id] = row

		var index_key := "%s_%s_%s" % [
			str(row["element"]).to_lower(),
			str(row["position"]).to_lower(),
			str(row["target"]).to_lower()
		]
		_index[index_key] = spell_id


func _to_float(s: String) -> Variant:
	if s.strip_edges() == "" or not s.strip_edges().is_valid_float():
		return s.strip_edges()
	return s.strip_edges().to_float()


func compose_spell(
	elemental: String,
	empowerment: String,
	enchantment: String,
	delivery: String,
	target_type: String
) -> SpellData:
	var target_key := target_type.to_lower()
	var elemental_row := _get_row_by_key("%s_elemental_%s" % [elemental.to_lower(), target_key])
	var empowerment_row := _get_row_by_key("%s_empowerment_%s" % [empowerment.to_lower(), target_key])
	var enchantment_row := _get_row_by_key("%s_enchantment_%s" % [enchantment.to_lower(), target_key])
	var rows := [elemental_row, empowerment_row, enchantment_row]

	var total_cd := 0.0
	var total_budget := 0.0
	for row in rows:
		if row.is_empty():
			continue

		if str(row.get("cd_type", "")).to_lower() == "cast":
			total_cd += _variant_to_float(row.get("cd", 0.0))
		total_budget += _variant_to_float(row.get("budget", 0.0))

	var base_dmgmult := _positive_or_neutral(elemental_row.get("dmgmult", 0.0))
	base_dmgmult *= _positive_or_neutral(empowerment_row.get("dmgmult", 0.0))
	base_dmgmult *= _positive_or_neutral(enchantment_row.get("dmgmult", 0.0))

	var inv := get_node_or_null("/root/PlayerInventory")
	var tier: int = 0
	if inv != null and inv.has_method("get_school_tier"):
		tier = inv.get_school_tier(elemental)
	var scale_dmgmult_val := _variant_to_float(elemental_row.get("scale_dmgmult", 0.0))
	var effective_dmgmult := base_dmgmult + scale_dmgmult_val * tier
	var spell_data := SpellData.new()
	spell_data.spell_name = "%s %s %s" % [elemental, empowerment, enchantment]
	spell_data.combo_name = spell_data.spell_name
	spell_data.elemental_element = elemental
	spell_data.empowerment_element = empowerment
	spell_data.enchantment_element = enchantment
	spell_data.delivery_type = delivery
	spell_data.total_cd = total_cd
	spell_data.total_budget = total_budget
	spell_data.cooldown = total_cd
	spell_data.dmgmult_chain = effective_dmgmult
	spell_data.damage = 1.0
	spell_data.on_hit_effects = []
	spell_data.self_effects = []

	for row in rows:
		if row.is_empty():
			continue

		var target := str(row.get("target", "")).to_lower()
		var effect := _build_effect_entry(row)
		if target == "enemy":
			effect["tier"] = tier
			spell_data.on_hit_effects.append(effect)
		elif target == "self":
			if str(row.get("cd_type", "")).to_lower() == "passive":
				var inventory = _get_player_inventory()
				if inventory != null:
					inventory.register_passive(effect)
			else:
				spell_data.self_effects.append(effect)

	return spell_data


func get_weakness_multiplier(attacker: String, defender: String) -> float:
	var attacker_key := attacker.to_lower()
	var defender_key := defender.to_lower()
	if defender_key.is_empty():
		return 1.0

	var beats := {
		"fire": "ice",
		"ice": "earth",
		"earth": "thunder",
		"thunder": "water",
		"water": "fire",
		"holy": "dark",
		"dark": "holy"
	}

	if beats.get(attacker_key, "") == defender_key:
		return 1.2
	if beats.get(defender_key, "") == attacker_key:
		return 0.8
	return 1.0


func is_stop_cast(element: String) -> bool:
	return element.to_lower() in ["holy", "dark"]


func get_summon_data(element: String) -> Dictionary:
	var key := element.to_lower() + "_summon_summon"
	if _index.has(key):
		return (_rows[_index[key]] as Dictionary).duplicate(true)
	return {}


func get_all_rows() -> Array:
	return _rows.values()


func _get_row_by_key(key: String) -> Dictionary:
	if not _index.has(key):
		return {}
	return (_rows[_index[key]] as Dictionary).duplicate(true)


func _build_effect_entry(row: Dictionary) -> Dictionary:
	return {
		"effect_name": str(row.get("effect_name", "")),
		"value1": row.get("value1", ""),
		"value2": row.get("value2", ""),
		"value3": row.get("value3", ""),
		"value4": row.get("value4", ""),
		"value5": row.get("value5", ""),
		"dmgmult": _variant_to_float(row.get("dmgmult", 0.0)),
		"scale_value1": row.get("scale_value1", 0.0),
		"scale_value2": row.get("scale_value2", 0.0),
		"scale_value3": row.get("scale_value3", 0.0),
		"scale_value4": row.get("scale_value4", 0.0),
		"scale_value5": row.get("scale_value5", 0.0),
		"scale_dmgmult": row.get("scale_dmgmult", 0.0),
		"cd_type": str(row.get("cd_type", ""))
	}


func _positive_or_neutral(value: Variant) -> float:
	var parsed := _variant_to_float(value)
	if parsed > 0.0:
		return parsed
	return 1.0


func _variant_to_float(value: Variant) -> float:
	if value is float:
		return value
	if value is int:
		return float(value)
	if value is String and value.is_valid_float():
		return value.to_float()
	return 0.0


func _get_player_inventory() -> Node:
	return get_node_or_null("/root/PlayerInventory")

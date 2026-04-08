extends Node

const MAX_PAGES := 8
const SAVE_PATH := "user://tome_pages.json"

var pages: Array = []
var active_page_index: int = 0
var _flip_cooldown: float = 0.0

signal page_flipped(index: int)
signal page_saved(index: int)
signal page_deleted(index: int)
signal page_renamed(index: int, new_name: String)
signal flip_blocked(reason: String)


func _ready() -> void:
	load_pages()
	if pages.is_empty():
		_add_default_page()


func _process(delta: float) -> void:
	if _flip_cooldown > 0.0:
		_flip_cooldown -= delta
		if _flip_cooldown < 0.0:
			_flip_cooldown = 0.0


func can_flip_page(target_index: int = -1) -> bool:
	if target_index == active_page_index:
		return true
	if _flip_cooldown > 0.0:
		return false
	var sm = get_node_or_null("/root/SummonManager")
	if sm != null and sm.has_method("is_recharged"):
		return sm.is_recharged()
	return true


func flip_to_page(index: int) -> void:
	if index < 0 or index >= pages.size():
		return
	if not can_flip_page(index):
		var reason := ""
		if _flip_cooldown > 0.0:
			reason = "Spell cooldown: %.1fs" % _flip_cooldown
		else:
			var sm = get_node_or_null("/root/SummonManager")
			if sm != null and sm.has_method("get_recharge_remaining"):
				reason = "Summon recharge: %.1fs" % sm.get_recharge_remaining()
			else:
				reason = "Summon not recharged"
		emit_signal("flip_blocked", reason)
		return

	active_page_index = index
	var page: PageData = pages[index]
	page.ensure_slots(4)

	# Refresh all SpellCasters on the player
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		var spell_casters := player.find_children("*", "Node2D", true, false)
		var caster_index := 0
		for child in spell_casters:
			if child.get_script() == null:
				continue
			if not child.has_method("refresh_spell"):
				continue
			if caster_index < page.slots.size():
				var slot: Dictionary = page.slots[caster_index]
				child.refresh_spell(
					slot.get("elemental", "fire"),
					slot.get("empowerment", "fire"),
					slot.get("enchantment", "fire"),
					slot.get("delivery", "bolt"),
					slot.get("target", "enemy")
				)
			caster_index += 1

	# Spawn summon for new page
	var sm = get_node_or_null("/root/SummonManager")
	if sm != null and sm.has_method("spawn_summon"):
		sm.spawn_summon(page.summon_element)

	# Set flip cooldown = longest total_cd across all SpellCasters
	var longest_cd := 0.0
	if player != null:
		for child in player.find_children("*", "Node2D", true, false):
			if child.has_method("refresh_spell") and child.get("spell_data") != null:
				var sd = child.get("spell_data")
				if sd != null and sd.get("cooldown") != null:
					longest_cd = max(longest_cd, float(sd.cooldown))
	_flip_cooldown = longest_cd

	emit_signal("page_flipped", index)


func save_pages() -> void:
	var data := []
	for page in pages:
		var slots_raw := []
		for slot in page.slots:
			slots_raw.append(slot.duplicate())
		data.append({
			"page_name": page.page_name,
			"summon_element": page.summon_element,
			"ult1": page.ult1,
			"ult2": page.ult2,
			"slots": slots_raw
		})
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))


func load_pages() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	if not parsed is Array:
		return
	pages.clear()
	for entry in parsed:
		var p := PageData.new()
		p.page_name = str(entry.get("page_name", "Page"))
		p.summon_element = str(entry.get("summon_element", "fire"))
		p.ult1 = str(entry.get("ult1", ""))
		p.ult2 = str(entry.get("ult2", ""))
		var slots_raw = entry.get("slots", [])
		p.slots = []
		for slot in slots_raw:
			p.slots.append({
				"elemental": str(slot.get("elemental", "fire")),
				"empowerment": str(slot.get("empowerment", "fire")),
				"enchantment": str(slot.get("enchantment", "fire")),
				"delivery": str(slot.get("delivery", "bolt")),
				"target": str(slot.get("target", "enemy"))
			})
		p.ensure_slots(4)
		pages.append(p)
	if pages.is_empty():
		_add_default_page()


func _add_default_page() -> void:
	var first := PageData.new()
	first.page_name = "Page 1"
	first.ensure_slots(4)
	pages.append(first)


func save_page(index: int, page: PageData) -> void:
	if index < 0 or index >= pages.size():
		return
	pages[index] = page
	save_pages()
	emit_signal("page_saved", index)


func get_page(index: int) -> PageData:
	if index < 0 or index >= pages.size():
		return null
	return pages[index]


func get_active_page() -> PageData:
	return get_page(active_page_index)


func add_page() -> void:
	if pages.size() >= MAX_PAGES:
		return
	var p := PageData.new()
	p.page_name = "Page %d" % (pages.size() + 1)
	p.ensure_slots(4)
	pages.append(p)
	save_pages()


func delete_page(index: int) -> void:
	if pages.size() <= 1:
		return
	if index < 0 or index >= pages.size():
		return
	pages.remove_at(index)
	if active_page_index >= pages.size():
		active_page_index = pages.size() - 1
	save_pages()
	emit_signal("page_deleted", index)


func rename_page(index: int, new_name: String) -> void:
	if index < 0 or index >= pages.size():
		return
	pages[index].page_name = new_name.strip_edges()
	save_pages()
	emit_signal("page_renamed", index, new_name)

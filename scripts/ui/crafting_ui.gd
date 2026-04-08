extends CanvasLayer

const ELEMENTS := ["Fire", "Ice", "Earth", "Thunder", "Water", "Holy", "Dark"]
const DELIVERIES := ["Bolt", "Burst", "Beam", "Blast", "Cleave", "Missile", "Wall", "Utility"]

signal ui_closed

var _editing_page_index: int = 0
var _draft_page: PageData = null
var _slot_pickers: Array[Dictionary] = []

@onready var panel_container: PanelContainer = $PanelContainer
@onready var tome_view: VBoxContainer = $PanelContainer/TomeView
@onready var page_editor_view: VBoxContainer = $PanelContainer/PageEditorView
@onready var page_list: VBoxContainer = $PanelContainer/TomeView/PageList
@onready var resume_button: Button = $PanelContainer/TomeView/ResumeButton
@onready var slot_container: VBoxContainer = $PanelContainer/PageEditorView/SlotContainer
@onready var summon_picker: OptionButton = $PanelContainer/PageEditorView/SummonRow/SummonPicker
@onready var total_cd_label: Label = $PanelContainer/PageEditorView/StatsPanel/CDLabel
@onready var budget_label: Label = $PanelContainer/PageEditorView/StatsPanel/BudgetLabel
@onready var dmgmult_label: Label = $PanelContainer/PageEditorView/StatsPanel/MultLabel
@onready var save_page_button: Button = $PanelContainer/PageEditorView/SavePageButton
@onready var back_button: Button = $PanelContainer/PageEditorView/BackButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	resume_button.pressed.connect(close_ui)
	save_page_button.pressed.connect(_on_save_page_pressed)
	back_button.pressed.connect(_on_back_pressed)
	summon_picker.item_selected.connect(_on_editor_picker_changed)

	_show_tome_view()


func open_ui() -> void:
	get_tree().paused = true
	show()
	_show_tome_view()
	_populate_tome_view()


func close_ui() -> void:
	get_tree().paused = false
	hide()
	emit_signal("ui_closed")


func _show_tome_view() -> void:
	tome_view.show()
	page_editor_view.hide()


func _populate_tome_view() -> void:
	for child in page_list.get_children():
		child.free()

	var tm = get_node_or_null("/root/TomeManager")
	if tm == null:
		return

	for i in range(tm.pages.size()):
		var page: PageData = tm.pages[i]
		var row := HBoxContainer.new()
		var is_active_page: bool = (i == tm.active_page_index)

		var name_label := Label.new()
		name_label.text = ("▶ " if is_active_page else "  ") + page.page_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var summary_label := Label.new()
		if not page.slots.is_empty():
			summary_label.text = str(page.slots[0].get("elemental", "fire")).capitalize()
		else:
			summary_label.text = "Empty"
		summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(summary_label)

		var edit_button := Button.new()
		edit_button.text = "Craft"
		edit_button.pressed.connect(_on_edit_pressed.bind(i))
		row.add_child(edit_button)

		var set_active_button := Button.new()
		set_active_button.text = "Set Active"
		set_active_button.disabled = is_active_page
		set_active_button.pressed.connect(_on_set_active_pressed.bind(i))
		row.add_child(set_active_button)

		var rename_button := Button.new()
		rename_button.text = "Rename"
		rename_button.pressed.connect(_on_rename_pressed.bind(i))
		row.add_child(rename_button)

		var delete_button := Button.new()
		delete_button.text = "Delete"
		delete_button.disabled = tm.pages.size() <= 1
		delete_button.pressed.connect(_on_delete_pressed.bind(i))
		row.add_child(delete_button)

		page_list.add_child(row)
	if tm.pages.size() < 8:
		var new_btn := Button.new()
		new_btn.text = "New Page"
		new_btn.pressed.connect(_on_new_page_pressed)
		page_list.add_child(new_btn)


func _on_edit_pressed(index: int) -> void:
	_editing_page_index = index
	var tm = get_node_or_null("/root/TomeManager")
	if tm == null:
		return

	var src: PageData = tm.get_page(index)
	if src == null:
		return

	_draft_page = PageData.new()
	_draft_page.page_name = src.page_name
	_draft_page.summon_element = src.summon_element
	_draft_page.slots = src.slots.duplicate(true)
	_draft_page.ult1 = src.ult1
	_draft_page.ult2 = src.ult2
	_draft_page.ensure_slots(4)

	_show_page_editor()
	_populate_page_editor()


func _show_page_editor() -> void:
	tome_view.hide()
	page_editor_view.show()


func _populate_page_editor() -> void:
	for child in slot_container.get_children():
		child.queue_free()

	_slot_pickers.clear()
	if _draft_page == null:
		return

	_draft_page.ensure_slots(4)

	for i in range(4):
		var slot: Dictionary = _draft_page.slots[i]
		var row := HBoxContainer.new()
		var is_active := i == 0
		if not is_active:
			row.modulate = Color(0.5, 0.5, 0.5)

		var slot_label := Label.new()
		slot_label.text = "Slot %d" % (i + 1)
		slot_label.custom_minimum_size = Vector2(60.0, 0.0)
		row.add_child(slot_label)

		var elemental_picker := _make_option_button(ELEMENTS, str(slot.get("elemental", "fire")))
		row.add_child(elemental_picker)

		var empowerment_picker := _make_option_button(ELEMENTS, str(slot.get("empowerment", "fire")))
		row.add_child(empowerment_picker)

		var enchantment_picker := _make_option_button(ELEMENTS, str(slot.get("enchantment", "fire")))
		row.add_child(enchantment_picker)

		var delivery_picker := _make_option_button(DELIVERIES, str(slot.get("delivery", "bolt")))
		row.add_child(delivery_picker)

		if not is_active:
			elemental_picker.disabled = true
			empowerment_picker.disabled = true
			enchantment_picker.disabled = true
			delivery_picker.disabled = true
		else:
			elemental_picker.item_selected.connect(_on_editor_picker_changed)
			empowerment_picker.item_selected.connect(_on_editor_picker_changed)
			enchantment_picker.item_selected.connect(_on_editor_picker_changed)
			delivery_picker.item_selected.connect(_on_editor_picker_changed)

		_slot_pickers.append({
			"elemental": elemental_picker,
			"empowerment": empowerment_picker,
			"enchantment": enchantment_picker,
			"delivery": delivery_picker
		})
		slot_container.add_child(row)

	summon_picker.clear()
	for element_name in ELEMENTS:
		summon_picker.add_item(element_name)
	_select_option_value(summon_picker, _draft_page.summon_element)

	_update_stats_panel()


func _on_save_page_pressed() -> void:
	if _draft_page == null:
		return

	_apply_editor_values_to_draft()

	var tm = get_node_or_null("/root/TomeManager")
	if tm == null:
		return

	tm.save_page(_editing_page_index, _draft_page)
	if _editing_page_index == tm.active_page_index:
		_apply_active_page_live()

	_show_tome_view()
	_populate_tome_view()


func _update_stats_panel() -> void:
	var sc = get_node_or_null("/root/SpellComposer")
	if sc == null or _draft_page == null:
		return
	if _draft_page.slots.is_empty():
		return

	var slot: Dictionary = _draft_page.slots[0]
	var sd = sc.compose_spell(
		str(slot.get("elemental", "fire")).to_lower(),
		str(slot.get("empowerment", "fire")).to_lower(),
		str(slot.get("enchantment", "fire")).to_lower(),
		str(slot.get("delivery", "bolt")).to_lower(),
		str(slot.get("target", "enemy")).to_lower()
	)
	if sd == null:
		return

	total_cd_label.text = "CD: %.2f" % sd.total_cd
	budget_label.text = "Budget: %.1f" % sd.total_budget
	dmgmult_label.text = "Mult: %.2f" % sd.dmgmult_chain


func _apply_active_page_live() -> void:
	var tm = get_node_or_null("/root/TomeManager")
	if tm == null:
		return
	var page: PageData = tm.get_active_page()
	if page == null:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var casters := player.find_children("*", "Node2D", true, false)
	var idx := 0
	for child in casters:
		if not child.has_method("refresh_spell"):
			continue
		if idx < page.slots.size():
			var slot: Dictionary = page.slots[idx]
			child.refresh_spell(
				slot.get("elemental", "fire"),
				slot.get("empowerment", "fire"),
				slot.get("enchantment", "fire"),
				slot.get("delivery", "bolt"),
				slot.get("target", "enemy")
			)
		idx += 1


func _on_new_page_pressed() -> void:
	var tm = get_node_or_null("/root/TomeManager")
	if tm == null:
		return

	tm.add_page()
	_populate_tome_view()


func _on_set_active_pressed(index: int) -> void:
	var tm = get_node_or_null("/root/TomeManager")
	if tm == null:
		return
	tm.active_page_index = index
	var page: PageData = tm.get_page(index)
	if page != null:
		page.ensure_slots(4)
		var player := get_tree().get_first_node_in_group("player")
		if player != null:
			var casters := player.find_children("*", "Node2D", true, false)
			var idx := 0
			for child in casters:
				if not child.has_method("refresh_spell"):
					continue
				if idx < page.slots.size():
					var slot: Dictionary = page.slots[idx]
					child.refresh_spell(
						slot.get("elemental", "fire"),
						slot.get("empowerment", "fire"),
						slot.get("enchantment", "fire"),
						slot.get("delivery", "bolt"),
						slot.get("target", "enemy")
					)
				idx += 1
		var sm = get_node_or_null("/root/SummonManager")
		if sm != null and sm.has_method("spawn_summon"):
			sm.spawn_summon(page.summon_element)
	tm.emit_signal("page_flipped", index)
	_populate_tome_view()


func _on_delete_pressed(index: int) -> void:
	var tm = get_node_or_null("/root/TomeManager")
	if tm == null:
		return
	tm.delete_page(index)
	_populate_tome_view()


func _on_rename_pressed(index: int) -> void:
	var tm = get_node_or_null("/root/TomeManager")
	if tm == null:
		return
	for child in page_list.get_children():
		if child is HBoxContainer and child.get_child_count() > 0:
			if child.get_child(0) is LineEdit:
				child.queue_free()
	var rename_row := HBoxContainer.new()
	var line_edit := LineEdit.new()
	line_edit.text = tm.pages[index].page_name
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rename_row.add_child(line_edit)
	var confirm_button := Button.new()
	confirm_button.text = "OK"
	confirm_button.pressed.connect(
		func():
			tm.rename_page(index, line_edit.text)
			_populate_tome_view()
	)
	rename_row.add_child(confirm_button)
	page_list.add_child(rename_row)
	line_edit.grab_focus()


func _on_back_pressed() -> void:
	_show_tome_view()
	_populate_tome_view()


func _on_editor_picker_changed(_index: int) -> void:
	_apply_editor_values_to_draft()
	_update_stats_panel()


func _apply_editor_values_to_draft() -> void:
	if _draft_page == null or _slot_pickers.is_empty():
		return

	_draft_page.ensure_slots(4)
	var slot: Dictionary = _draft_page.slots[0]
	var pickers: Dictionary = _slot_pickers[0]
	slot["elemental"] = _get_selected_option_value(pickers["elemental"])
	slot["empowerment"] = _get_selected_option_value(pickers["empowerment"])
	slot["enchantment"] = _get_selected_option_value(pickers["enchantment"])
	slot["delivery"] = _get_selected_option_value(pickers["delivery"])
	_draft_page.slots[0] = slot
	_draft_page.summon_element = _get_selected_option_value(summon_picker)


func _make_option_button(options: Array, selected_value: String) -> OptionButton:
	var picker := OptionButton.new()
	for option in options:
		picker.add_item(str(option))
	_select_option_value(picker, selected_value)
	return picker


func _select_option_value(picker: OptionButton, value: String) -> void:
	var target := value.to_lower()
	for i in range(picker.item_count):
		if picker.get_item_text(i).to_lower() == target:
			picker.select(i)
			return
	if picker.item_count > 0:
		picker.select(0)


func _get_selected_option_value(picker: OptionButton) -> String:
	if picker == null or picker.item_count == 0:
		return ""
	return picker.get_item_text(picker.selected).to_lower()

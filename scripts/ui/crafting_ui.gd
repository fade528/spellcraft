extends CanvasLayer

const ELEMENTS := ["Fire", "Ice", "Earth", "Thunder", "Water", "Holy", "Dark"]
const DELIVERIES := ["Bolt", "Burst", "Beam", "Blast", "Cleave", "Missile", "Wall", "Utility"]

signal ui_closed

var _editing_page_index: int = 0
var _draft_page: PageData = null
var _slot_pickers: Array[Dictionary] = []
var _ult1_picker: OptionButton = null
var _ult2_picker: OptionButton = null
enum TabView { SPEC_LIST, SPEC_EDITOR, TOME_LIST, PAGE_EDITOR }
var _current_tab: TabView = TabView.SPEC_LIST
var _editing_spec_name: String = ""
var _spec_editor_container: VBoxContainer = null
var _spec_slot_pickers: Array[Dictionary] = []
var _spec_summon_picker: OptionButton = null
var _spec_school_labels: Dictionary = {}
var _spec_ratios: Dictionary = {}
var _tome_school_labels: Dictionary = {}

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
var _tab_bar: HBoxContainer = null
var _spec_tab_container: VBoxContainer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	resume_button.pressed.connect(close_ui)
	save_page_button.pressed.connect(_on_save_page_pressed)
	back_button.pressed.connect(_on_back_pressed)
	summon_picker.item_selected.connect(_on_editor_picker_changed)
	for child in tome_view.get_children():
		if child != page_list:
			child.hide()
	_build_tab_ui()


func open_ui() -> void:
	get_tree().paused = true
	show()
	_switch_to_spec_list()


func _build_tab_ui() -> void:
	# Build a wrapper VBox to hold tab bar + content
	var wrapper := VBoxContainer.new()
	wrapper.name = "TabWrapper"
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Build tab bar
	_tab_bar = HBoxContainer.new()
	_tab_bar.name = "TabBar"

	var spec_tab_btn := Button.new()
	spec_tab_btn.name = "SpecTabBtn"
	spec_tab_btn.text = "Spec"
	spec_tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spec_tab_btn.pressed.connect(_on_spec_tab_pressed)
	_tab_bar.add_child(spec_tab_btn)

	wrapper.add_child(_tab_bar)

	# Spec tab content container
	_spec_tab_container = VBoxContainer.new()
	_spec_tab_container.name = "SpecTabContainer"
	_spec_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrapper.add_child(_spec_tab_container)

	_spec_editor_container = VBoxContainer.new()
	_spec_editor_container.name = "SpecEditorContainer"
	_spec_editor_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_spec_editor_container.hide()
	wrapper.add_child(_spec_editor_container)

	# Reparent existing tome_view and page_editor_view into wrapper
	tome_view.reparent(wrapper)
	page_editor_view.reparent(wrapper)

	# Add wrapper to panel_container
	panel_container.add_child(wrapper)


func _on_spec_tab_pressed() -> void:
	_switch_to_spec_list()


func _switch_to_spec_list() -> void:
	_current_tab = TabView.SPEC_LIST
	_spec_tab_container.show()
	if _spec_editor_container != null:
		_spec_editor_container.hide()
	tome_view.hide()
	page_editor_view.hide()
	_populate_spec_list()


func _switch_to_tome_list() -> void:
	_current_tab = TabView.TOME_LIST
	_spec_tab_container.hide()
	if _spec_editor_container != null:
		_spec_editor_container.hide()
	tome_view.show()
	page_editor_view.hide()
	_populate_tome_view()


func _populate_spec_list() -> void:
	for child in _spec_tab_container.get_children():
		child.queue_free()

	var sm = get_node_or_null("/root/SpecManager")
	var active_name := ""
	if sm != null:
		active_name = sm.get_active_spec_name()
	var is_archmage_active := (active_name == "" or active_name == "Archmage")

	# Archmage row
	var archmage_row := HBoxContainer.new()
	if is_archmage_active:
		archmage_row.modulate = Color(0.4, 1.0, 0.4)
	var archmage_label := Label.new()
	archmage_label.text = "Archmage"
	archmage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	archmage_row.add_child(archmage_label)
	var archmage_activate := Button.new()
	archmage_activate.text = "Activate"
	archmage_activate.disabled = is_archmage_active
	archmage_activate.pressed.connect(_on_activate_spec_from_list.bind("Archmage"))
	archmage_row.add_child(archmage_activate)
	var archmage_edit := Button.new()
	archmage_edit.text = "Edit"
	archmage_edit.pressed.connect(_on_edit_spec_pressed.bind("Archmage"))
	archmage_row.add_child(archmage_edit)
	var save_as_btn := Button.new()
	save_as_btn.text = "Save as Spec"
	var custom_count := 0
	if sm != null:
		for key in sm._custom_specs.keys():
			custom_count += 1
	save_as_btn.disabled = custom_count >= 5
	save_as_btn.pressed.connect(_on_save_archmage_as_spec_pressed)
	archmage_row.add_child(save_as_btn)
	_spec_tab_container.add_child(archmage_row)
	_spec_tab_container.add_child(HSeparator.new())

	# Built-in spec slots 1-5
	var builtin_names: Array[String] = []
	if sm != null:
		for key in sm.SPEC_PATHS.keys():
			if key != "Archmage":
				builtin_names.append(key)

	var lbl_builtin := Label.new()
	lbl_builtin.text = "-- Built-in Specs --"
	lbl_builtin.modulate = Color(0.7, 0.7, 0.7)
	lbl_builtin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spec_tab_container.add_child(lbl_builtin)

	for i in range(5):
		var row := HBoxContainer.new()
		if i < builtin_names.size():
			var spec_name: String = builtin_names[i]
			var is_active := (spec_name == active_name)
			if is_active:
				row.modulate = Color(0.4, 1.0, 0.4)
			var name_label := Label.new()
			name_label.text = spec_name
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)
			var activate_btn2 := Button.new()
			activate_btn2.text = "Activate"
			activate_btn2.disabled = is_active
			activate_btn2.pressed.connect(_on_activate_spec_from_list.bind(spec_name))
			row.add_child(activate_btn2)
			var edit_btn := Button.new()
			edit_btn.text = "Edit"
			edit_btn.pressed.connect(_on_edit_spec_pressed.bind(spec_name))
			row.add_child(edit_btn)
		else:
			var empty_label := Label.new()
			empty_label.text = "-- reserved --"
			empty_label.modulate = Color(0.35, 0.35, 0.35)
			empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(empty_label)
		_spec_tab_container.add_child(row)

	_spec_tab_container.add_child(HSeparator.new())

	# Custom spec slots 6-10
	var custom_names: Array[String] = []
	if sm != null:
		for key in sm._custom_specs.keys():
			custom_names.append(key)

	var lbl_custom := Label.new()
	lbl_custom.text = "-- My Specs --"
	lbl_custom.modulate = Color(0.7, 0.7, 0.7)
	lbl_custom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spec_tab_container.add_child(lbl_custom)

	for i in range(5):
		var row := HBoxContainer.new()
		if i < custom_names.size():
			var spec_name: String = custom_names[i]
			var is_active := (spec_name == active_name)
			if is_active:
				row.modulate = Color(0.4, 1.0, 0.4)
			var name_label := Label.new()
			name_label.text = spec_name
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)
			var activate_btn2 := Button.new()
			activate_btn2.text = "Activate"
			activate_btn2.disabled = is_active
			activate_btn2.pressed.connect(_on_activate_spec_from_list.bind(spec_name))
			row.add_child(activate_btn2)
			var edit_btn := Button.new()
			edit_btn.text = "Edit"
			edit_btn.pressed.connect(_on_edit_spec_pressed.bind(spec_name))
			row.add_child(edit_btn)
			var delete_btn := Button.new()
			delete_btn.text = "Delete"
			delete_btn.pressed.connect(_on_delete_spec_pressed.bind(spec_name))
			row.add_child(delete_btn)
		else:
			var empty_label := Label.new()
			empty_label.text = "-- empty slot --"
			empty_label.modulate = Color(0.35, 0.35, 0.35)
			empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(empty_label)
		_spec_tab_container.add_child(row)

	_spec_tab_container.add_child(HSeparator.new())
	var resume_row := HBoxContainer.new()
	var resume_btn := Button.new()
	resume_btn.text = "Resume"
	resume_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume_btn.pressed.connect(close_ui)
	resume_row.add_child(resume_btn)
	_spec_tab_container.add_child(resume_row)


func _on_activate_spec_from_list(spec_name: String) -> void:
	var sm = get_node_or_null("/root/SpecManager")
	if sm == null:
		return
	if spec_name == "Archmage":
		sm.clear_spec()
	else:
		sm.apply_spec(spec_name)
	_populate_spec_list()


func _on_reset_spec_pressed(spec_name: String) -> void:
	var sm = get_node_or_null("/root/SpecManager")
	var tm = get_node_or_null("/root/TomeManager")
	if sm == null or tm == null:
		return
	# Only reset if this is the active spec
	var preferred: Array = []
	if sm.SPEC_PATHS.has(spec_name):
		var loaded = load(sm.SPEC_PATHS[spec_name])
		if loaded != null:
			preferred = (loaded as SpecData).preferred_slots
	tm.reset_to_default(preferred)
	_populate_spec_editor()


func _on_save_archmage_as_spec_pressed() -> void:
	# Build a name input row inline
	for child in _spec_tab_container.get_children():
		if child.name == "SaveAsRow":
			return
	var save_row := HBoxContainer.new()
	save_row.name = "SaveAsRow"
	var field := LineEdit.new()
	field.placeholder_text = "New spec name"
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(field)
	var confirm_btn := Button.new()
	confirm_btn.text = "Save"
	confirm_btn.pressed.connect(func() -> void:
		var new_name := field.text.strip_edges()
		if new_name.is_empty():
			return
		var sm = get_node_or_null("/root/SpecManager")
		if sm != null:
			sm.save_archmage_as_spec(new_name)
		_switch_to_tome_list()
	)
	save_row.add_child(confirm_btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_populate_spec_list)
	save_row.add_child(cancel_btn)
	# Insert at top of spec container
	_spec_tab_container.add_child(save_row)
	_spec_tab_container.move_child(save_row, 0)
	field.grab_focus()


func _on_edit_spec_pressed(spec_name: String) -> void:
	_editing_spec_name = spec_name
	_switch_to_spec_editor()
	# Spec editor coming in next step - stub for now
	pass


func _on_delete_spec_pressed(spec_name: String) -> void:
	var sm = get_node_or_null("/root/SpecManager")
	if sm == null:
		return
	sm.delete_custom_spec(spec_name)
	_populate_spec_list()


func _on_new_spec_pressed() -> void:
	_editing_spec_name = ""
	_switch_to_spec_editor()
	# Spec editor coming in next step - stub for now
	pass


func _switch_to_spec_editor() -> void:
	_current_tab = TabView.SPEC_EDITOR
	_spec_tab_container.hide()
	_spec_editor_container.show()
	tome_view.hide()
	page_editor_view.hide()
	_populate_spec_editor()


func _populate_spec_editor() -> void:
	for child in _spec_editor_container.get_children():
		child.queue_free()

	var ELEMENT_COLORS := {
		"fire": Color(1.0, 0.3, 0.1),
		"ice": Color(0.5, 0.85, 1.0),
		"earth": Color(0.6, 0.4, 0.2),
		"thunder": Color(1.0, 0.9, 0.1),
		"water": Color(0.1, 0.4, 0.9),
		"holy": Color(1.0, 1.0, 0.85),
		"dark": Color(0.55, 0.1, 0.85)
	}

	var back_row := HBoxContainer.new()
	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.pressed.connect(_switch_to_spec_list)
	back_row.add_child(back_btn)
	var tome_btn := Button.new()
	tome_btn.text = "Go to Tome"
	tome_btn.pressed.connect(
		func() -> void:
			var sm_t = get_node_or_null("/root/SpecManager")
			if sm_t != null:
				if _editing_spec_name == "" or _editing_spec_name == "Archmage":
					sm_t.clear_spec()
				else:
					sm_t.apply_spec(_editing_spec_name)
			_switch_to_tome_list()
	)
	back_row.add_child(tome_btn)
	# Reset to Default button - only for built-in specs
	var sm2 = get_node_or_null("/root/SpecManager")
	if sm2 != null and sm2.SPEC_PATHS.has(_editing_spec_name):
		var reset_btn2 := Button.new()
		reset_btn2.text = "Reset Spec"
		reset_btn2.pressed.connect(
			func() -> void:
				_on_reset_spec_pressed(_editing_spec_name)
				_switch_to_spec_list()
		)
		back_row.add_child(reset_btn2)
	_spec_editor_container.add_child(back_row)
	_spec_editor_container.add_child(HSeparator.new())

	_spec_slot_pickers.clear()
	_spec_school_labels.clear()

	var sm = get_node_or_null("/root/SpecManager")
	var inv = get_node_or_null("/root/PlayerInventory")

	var existing_slots: Array = []
	var existing_summon: String = "fire"
	var existing_ratios: Dictionary = {}
	if _editing_spec_name != "" and sm != null:
		var custom = sm._custom_specs.get(_editing_spec_name, {})
		if not custom.is_empty():
			existing_slots = custom.get("preferred_slots", [])
			existing_summon = custom.get("summon_element", "fire")
			existing_ratios = custom.get("allocation_ratios", {})
		elif sm.get_active_spec_name() == _editing_spec_name and sm.get_active_spec() != null:
			var spec = sm.get_active_spec()
			existing_slots = spec.preferred_slots.duplicate(true)
			existing_ratios = spec.allocation_ratios.duplicate()
	_spec_ratios = {}
	var SCHOOL_LIST := ["fire", "ice", "earth", "thunder", "water", "holy", "dark"]
	for s in SCHOOL_LIST:
		_spec_ratios[s] = float(existing_ratios.get(s, 0.0))

	# Name field
	var name_row := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = "Name:"
	name_lbl.custom_minimum_size = Vector2(80, 0)
	name_row.add_child(name_lbl)
	var name_field := LineEdit.new()
	name_field.name = "SpecNameField"
	name_field.text = _editing_spec_name
	name_field.placeholder_text = "Enter spec name"
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_field)
	var sm_ro = get_node_or_null("/root/SpecManager")
	if sm_ro != null and sm_ro.SPEC_PATHS.has(_editing_spec_name):
		name_field.editable = false
		name_field.modulate = Color(0.6, 0.6, 0.6)
	_spec_editor_container.add_child(name_row)
	_spec_editor_container.add_child(HSeparator.new())

	# 4 spell rows
	for i in range(4):
		var slot_dict: Dictionary = existing_slots[i] if i < existing_slots.size() else {}
		var row := HBoxContainer.new()
		var slot_lbl := Label.new()
		slot_lbl.text = "Slot %d" % (i + 1)
		slot_lbl.custom_minimum_size = Vector2(60, 0)
		row.add_child(slot_lbl)
		var el_pick := _make_option_button(ELEMENTS, str(slot_dict.get("elemental", "fire")))
		var em_pick := _make_option_button(ELEMENTS, str(slot_dict.get("empowerment", "fire")))
		var en_pick := _make_option_button(ELEMENTS, str(slot_dict.get("enchantment", "fire")))
		var dl_pick := _make_option_button(DELIVERIES, str(slot_dict.get("delivery", "bolt")))
		row.add_child(el_pick)
		row.add_child(em_pick)
		row.add_child(en_pick)
		row.add_child(dl_pick)
		_spec_slot_pickers.append({
			"elemental": el_pick,
			"empowerment": em_pick,
			"enchantment": en_pick,
			"delivery": dl_pick
		})
		_spec_editor_container.add_child(row)

	_spec_editor_container.add_child(HSeparator.new())

	# Summon picker
	var summon_row := HBoxContainer.new()
	var summon_lbl := Label.new()
	summon_lbl.text = "Summon:"
	summon_lbl.custom_minimum_size = Vector2(80, 0)
	summon_row.add_child(summon_lbl)
	_spec_summon_picker = OptionButton.new()
	for el in ELEMENTS:
		_spec_summon_picker.add_item(el)
	_select_option_value(_spec_summon_picker, existing_summon)
	summon_row.add_child(_spec_summon_picker)
	_spec_editor_container.add_child(summon_row)

	# Ult pickers (placeholder)
	for u in range(2):
		var ult_row := HBoxContainer.new()
		var ult_lbl := Label.new()
		ult_lbl.text = "Ult %d:" % (u + 1)
		ult_lbl.custom_minimum_size = Vector2(80, 0)
		ult_row.add_child(ult_lbl)
		var ult_pick := OptionButton.new()
		ult_pick.add_item("placeholder")
		ult_row.add_child(ult_pick)
		_spec_editor_container.add_child(ult_row)

	_spec_editor_container.add_child(HSeparator.new())

	# School ratio swatches
	var SCHOOL_NAMES := ["fire", "ice", "earth", "thunder", "water", "holy", "dark"]
	var swatch_row := HBoxContainer.new()
	for school in SCHOOL_NAMES:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var school_name_lbl := Label.new()
		school_name_lbl.text = school.capitalize()
		school_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		school_name_lbl.modulate = ELEMENT_COLORS.get(school, Color.WHITE)
		col.add_child(school_name_lbl)
		var input := LineEdit.new()
		input.name = "RatioInput_" + school
		var pct_val := int(_spec_ratios.get(school, 0.0) * 100.0)
		input.text = str(pct_val) if pct_val > 0 else ""
		input.placeholder_text = "0"
		input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(input)
		swatch_row.add_child(col)
	_spec_editor_container.add_child(swatch_row)
	var ratio_hint := Label.new()
	ratio_hint.text = "Enter whole numbers (e.g. 80 / 20). Values normalise on save."
	ratio_hint.add_theme_font_size_override("font_size", 18)
	ratio_hint.modulate = Color(0.7, 0.7, 0.7)
	_spec_editor_container.add_child(ratio_hint)

	# Live school allocation with +/-
	_spec_editor_container.add_child(HSeparator.new())
	var alloc_title := Label.new()
	alloc_title.text = "Mana Allocation:"
	alloc_title.modulate = Color(0.8, 0.8, 0.8)
	_spec_editor_container.add_child(alloc_title)
	var live_swatch_row := HBoxContainer.new()
	var SCHOOL_NAMES2 := ["fire", "ice", "earth", "thunder", "water", "holy", "dark"]
	for school in SCHOOL_NAMES2:
		var col2 := VBoxContainer.new()
		col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tier_lbl2 := Label.new()
		var tier2: int = inv.get_school_tier(school) if inv != null else 0
		tier_lbl2.text = "T%d" % tier2
		tier_lbl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_lbl2.modulate = ELEMENT_COLORS.get(school, Color.WHITE)
		_spec_school_labels[school] = tier_lbl2
		col2.add_child(tier_lbl2)
		var plus_btn2 := Button.new()
		plus_btn2.text = "+"
		plus_btn2.pressed.connect(_on_spec_school_alloc_plus.bind(school))
		col2.add_child(plus_btn2)
		var minus_btn2 := Button.new()
		minus_btn2.text = "-"
		minus_btn2.pressed.connect(_on_spec_school_alloc_minus.bind(school))
		col2.add_child(minus_btn2)
		var name_lbl3 := Label.new()
		name_lbl3.text = school.capitalize()
		name_lbl3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl3.modulate = ELEMENT_COLORS.get(school, Color.WHITE)
		col2.add_child(name_lbl3)
		live_swatch_row.add_child(col2)
	_spec_editor_container.add_child(live_swatch_row)
	var alloc_btn_row := HBoxContainer.new()
	var alloc_reset_btn := Button.new()
	alloc_reset_btn.text = "Reset Allocation"
	alloc_reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alloc_reset_btn.pressed.connect(_on_spec_editor_reset_alloc)
	alloc_btn_row.add_child(alloc_reset_btn)
	var alloc_rem_btn := Button.new()
	alloc_rem_btn.text = "Alloc Remaining %"
	alloc_rem_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var has_spec2: bool = sm != null and not sm.is_archmage()
	alloc_rem_btn.disabled = not has_spec2
	alloc_rem_btn.pressed.connect(_on_spec_editor_alloc_remaining)
	alloc_btn_row.add_child(alloc_rem_btn)
	var alloc_all_btn2 := Button.new()
	alloc_all_btn2.text = "Alloc All %"
	alloc_all_btn2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alloc_all_btn2.disabled = not has_spec2
	alloc_all_btn2.pressed.connect(_on_spec_editor_alloc_all)
	alloc_btn_row.add_child(alloc_all_btn2)
	_spec_editor_container.add_child(alloc_btn_row)

	# Mana summary
	var mana_lbl := Label.new()
	mana_lbl.name = "SpecManaLabel"
	var total: int = inv.mana_pool if inv != null else 0
	var free_mana: int = inv.unallocated_mana if inv != null else 0
	mana_lbl.text = "Mana: %d | Free: %d" % [total, free_mana]
	_spec_editor_container.add_child(mana_lbl)
	_spec_editor_container.add_child(HSeparator.new())

	# Save and Cancel
	var btn_row := HBoxContainer.new()
	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(_on_save_spec_pressed)
	btn_row.add_child(save_btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(_switch_to_spec_list)
	btn_row.add_child(cancel_btn)
	_spec_editor_container.add_child(btn_row)


func _refresh_school_labels() -> void:
	var inv = get_node_or_null("/root/PlayerInventory")
	if inv == null:
		return
	for school in _spec_school_labels.keys():
		var lbl: Label = _spec_school_labels[school]
		if is_instance_valid(lbl):
			lbl.text = "T%d" % inv.get_school_tier(school)
	var mana_lbl := _spec_editor_container.find_child("SpecManaLabel", true, false)
	if mana_lbl is Label:
		mana_lbl.text = "Mana: %d | Free: %d" % [inv.mana_pool, inv.unallocated_mana]


func _on_spec_school_alloc_plus(school: String) -> void:
	var inv = get_node_or_null("/root/PlayerInventory")
	if inv != null:
		inv.allocate_to_school(school, 1)
	_refresh_school_labels()


func _on_spec_school_alloc_minus(school: String) -> void:
	var inv = get_node_or_null("/root/PlayerInventory")
	if inv != null:
		inv.deallocate_from_school(school, 1)
	_refresh_school_labels()


func _on_spec_editor_reset_alloc() -> void:
	var inv = get_node_or_null("/root/PlayerInventory")
	if inv == null:
		return
	for school in inv.school_allocation.keys():
		inv.unallocated_mana += int(inv.school_allocation[school])
	inv.school_allocation.clear()
	_refresh_school_labels()


func _on_spec_editor_alloc_remaining() -> void:
	var sm = get_node_or_null("/root/SpecManager")
	if sm != null:
		sm.allocate_remaining_by_spec()
	_refresh_school_labels()


func _on_spec_editor_alloc_all() -> void:
	var sm = get_node_or_null("/root/SpecManager")
	if sm != null:
		sm.allocate_all_by_spec()
	_refresh_school_labels()


func _on_tome_school_plus(school: String) -> void:
	var inv = get_node_or_null("/root/PlayerInventory")
	if inv != null:
		inv.allocate_to_school(school, 1)
	_refresh_tome_school_labels()


func _on_tome_school_minus(school: String) -> void:
	var inv = get_node_or_null("/root/PlayerInventory")
	if inv != null:
		inv.deallocate_from_school(school, 1)
	_refresh_tome_school_labels()


func _refresh_tome_school_labels() -> void:
	var inv = get_node_or_null("/root/PlayerInventory")
	if inv == null:
		return
	for school in _tome_school_labels.keys():
		var lbl: Label = _tome_school_labels[school]
		if is_instance_valid(lbl):
			lbl.text = "T%d" % inv.get_school_tier(school)
	var mana_lbl := page_list.find_child("TomeManaLabel", true, false)
	if mana_lbl is Label:
		mana_lbl.text = "Mana: %d | Free: %d" % [inv.mana_pool, inv.unallocated_mana]


func _on_tome_reset_allocation() -> void:
	var inv = get_node_or_null("/root/PlayerInventory")
	if inv == null:
		return
	for school in inv.school_allocation.keys():
		inv.unallocated_mana += int(inv.school_allocation[school])
	inv.school_allocation.clear()
	_refresh_tome_school_labels()


func _on_tome_alloc_remaining() -> void:
	var sm = get_node_or_null("/root/SpecManager")
	if sm != null:
		sm.allocate_remaining_by_spec()
	_refresh_tome_school_labels()


func _on_tome_alloc_all() -> void:
	var sm = get_node_or_null("/root/SpecManager")
	if sm != null:
		sm.allocate_all_by_spec()
	_refresh_tome_school_labels()


func _on_save_spec_pressed() -> void:
	var name_field := _spec_editor_container.find_child("SpecNameField", true, false)
	if name_field == null:
		return
	var new_name: String = (name_field as LineEdit).text.strip_edges()
	if new_name.is_empty():
		return
	var sm_guard = get_node_or_null("/root/SpecManager")
	if sm_guard != null and sm_guard.SPEC_PATHS.has(new_name):
		# Built-in spec — update preferred_slots in memory only, do not save to custom
		push_warning("CraftingUI: built-in spec edits are not persisted to custom specs")
		_switch_to_spec_list()
		return
	var sm = get_node_or_null("/root/SpecManager")
	if sm == null:
		return
	var preferred: Array = []
	for pickers in _spec_slot_pickers:
		preferred.append({
			"elemental": _get_selected_option_value(pickers["elemental"]),
			"empowerment": _get_selected_option_value(pickers["empowerment"]),
			"enchantment": _get_selected_option_value(pickers["enchantment"]),
			"delivery": _get_selected_option_value(pickers["delivery"]),
			"target": "enemy"
		})
	var summon_el := _get_selected_option_value(_spec_summon_picker) if _spec_summon_picker != null else "fire"
	# Read ratio inputs from LineEdit fields
	var raw_values: Dictionary = {}
	var SCHOOL_LIST2 := ["fire", "ice", "earth", "thunder", "water", "holy", "dark"]
	var total_raw := 0.0
	for school in SCHOOL_LIST2:
		var field := _spec_editor_container.find_child("RatioInput_" + school, true, false)
		var val := 0.0
		if field is LineEdit and field.text.strip_edges() != "":
			val = float(field.text.strip_edges().to_int())
		raw_values[school] = val
		total_raw += val
	var ratios: Dictionary = {}
	if total_raw > 0.0:
		for school in SCHOOL_LIST2:
			if raw_values[school] > 0.0:
				ratios[school] = raw_values[school] / total_raw
	var data := {
		"spec_name": new_name,
		"description": "",
		"allocation_ratios": ratios,
		"preferred_slots": preferred,
		"preferred_ults": [],
		"summon_element": summon_el
	}
	sm.save_spec_from_dict(new_name, data)
	_switch_to_spec_list()


func close_ui() -> void:
	get_tree().paused = false
	hide()
	emit_signal("ui_closed")


func _show_tome_view() -> void:
	if _spec_tab_container != null:
		_spec_tab_container.hide()
	tome_view.show()
	page_editor_view.hide()


func _populate_tome_view() -> void:
	for child in page_list.get_children():
		child.queue_free()

	var tm = get_node_or_null("/root/TomeManager")
	if tm == null:
		return

	for i in range(tm.pages.size()):
		var page: PageData = tm.pages[i]
		var row := HBoxContainer.new()
		var is_active_page: bool = (i == tm.active_page_index)
		if is_active_page:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.4, 0.8, 0.4)
			row.add_theme_stylebox_override("panel", style)
			row.modulate = Color(0.4, 1.0, 0.4)

		var name_label := Label.new()
		var override_icon := "* " if page.is_overridden else "~ "
		name_label.text = ("> " if is_active_page else "  ") + override_icon + page.page_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var summary_label := Label.new()
		var el := str(page.slots[0].get("elemental", "-")).capitalize() if not page.slots.is_empty() else "-"
		var summon_el := page.summon_element.capitalize() if page.summon_element != "" else "-"
		var u1 := page.ult1.capitalize() if page.ult1 != "" else "-"
		var u2 := page.ult2.capitalize() if page.ult2 != "" else "-"
		summary_label.text = "%s | S:%s U:%s/%s" % [el, summon_el, u1, u2]
		summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(summary_label)

		var edit_button := Button.new()
		edit_button.text = "Craft"
		edit_button.pressed.connect(_on_edit_pressed.bind(i))
		row.add_child(edit_button)

		var set_active_button := Button.new()
		set_active_button.text = "Activate"
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
	var tome_resume_btn := Button.new()
	tome_resume_btn.text = "Resume"
	tome_resume_btn.pressed.connect(close_ui)
	page_list.add_child(tome_resume_btn)
	var inv = get_node_or_null("/root/PlayerInventory")
	var sm = get_node_or_null("/root/SpecManager")
	if inv != null:
		_tome_school_labels.clear()
		page_list.add_child(HSeparator.new())
		var SCHOOL_NAMES := ["fire", "ice", "earth", "thunder", "water", "holy", "dark"]
		var ELEMENT_COLORS := {
			"fire": Color(1.0, 0.3, 0.1), "ice": Color(0.5, 0.85, 1.0),
			"earth": Color(0.6, 0.4, 0.2), "thunder": Color(1.0, 0.9, 0.1),
			"water": Color(0.1, 0.4, 0.9), "holy": Color(1.0, 1.0, 0.85),
			"dark": Color(0.55, 0.1, 0.85)
		}
		# School input row
		var input_row := HBoxContainer.new()
		for school in SCHOOL_NAMES:
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var name_lbl := Label.new()
			name_lbl.text = school.capitalize()
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.modulate = ELEMENT_COLORS.get(school, Color.WHITE)
			col.add_child(name_lbl)
			var tier_lbl := Label.new()
			tier_lbl.text = "T%d" % inv.get_school_tier(school)
			tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tier_lbl.modulate = ELEMENT_COLORS.get(school, Color.WHITE)
			_tome_school_labels[school] = tier_lbl
			col.add_child(tier_lbl)
			var plus_btn := Button.new()
			plus_btn.text = "+"
			plus_btn.pressed.connect(_on_tome_school_plus.bind(school))
			col.add_child(plus_btn)
			var minus_btn := Button.new()
			minus_btn.text = "-"
			minus_btn.pressed.connect(_on_tome_school_minus.bind(school))
			col.add_child(minus_btn)
			input_row.add_child(col)
		page_list.add_child(input_row)
		# Mana summary
		var mana_summary := Label.new()
		mana_summary.name = "TomeManaLabel"
		mana_summary.text = "Mana: %d | Free: %d" % [inv.mana_pool, inv.unallocated_mana]
		mana_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		page_list.add_child(mana_summary)
		# Action buttons row
		var action_row := HBoxContainer.new()
		var reset_btn := Button.new()
		reset_btn.text = "Reset"
		reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reset_btn.pressed.connect(_on_tome_reset_allocation)
		action_row.add_child(reset_btn)
		var alloc_remaining_btn := Button.new()
		alloc_remaining_btn.text = "Alloc Remaining %"
		alloc_remaining_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var has_spec: bool = sm != null and not sm.is_archmage()
		alloc_remaining_btn.disabled = not has_spec
		alloc_remaining_btn.pressed.connect(_on_tome_alloc_remaining)
		action_row.add_child(alloc_remaining_btn)
		var alloc_all_btn := Button.new()
		alloc_all_btn.text = "Alloc All %"
		alloc_all_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		alloc_all_btn.disabled = not has_spec
		alloc_all_btn.pressed.connect(_on_tome_alloc_all)
		action_row.add_child(alloc_all_btn)
		page_list.add_child(action_row)


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

	# Ult pickers
	var ult1_row := HBoxContainer.new()
	var ult1_lbl := Label.new()
	ult1_lbl.text = "Ult 1:"
	ult1_lbl.custom_minimum_size = Vector2(60, 0)
	ult1_row.add_child(ult1_lbl)
	_ult1_picker = OptionButton.new()
	_ult1_picker.add_item("-")
	_ult1_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_select_option_value(_ult1_picker, _draft_page.ult1 if _draft_page.ult1 != "" else "-")
	ult1_row.add_child(_ult1_picker)
	slot_container.add_child(ult1_row)

	var ult2_row := HBoxContainer.new()
	var ult2_lbl := Label.new()
	ult2_lbl.text = "Ult 2:"
	ult2_lbl.custom_minimum_size = Vector2(60, 0)
	ult2_row.add_child(ult2_lbl)
	_ult2_picker = OptionButton.new()
	_ult2_picker.add_item("-")
	_ult2_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_select_option_value(_ult2_picker, _draft_page.ult2 if _draft_page.ult2 != "" else "-")
	ult2_row.add_child(_ult2_picker)
	slot_container.add_child(ult2_row)

	_update_stats_panel()


func _on_save_page_pressed() -> void:
	if _draft_page == null:
		return

	_apply_editor_values_to_draft()

	var tm = get_node_or_null("/root/TomeManager")
	if tm == null:
		return

	_draft_page.is_overridden = true
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
		page.is_overridden = false
		tm.save_pages()
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
		if sm != null and sm.has_method("spawn_summon") and sm.is_recharged():
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
	var ult1_val := _get_selected_option_value(_ult1_picker) if _ult1_picker != null else ""
	_draft_page.ult1 = "" if ult1_val == "-" else ult1_val
	var ult2_val := _get_selected_option_value(_ult2_picker) if _ult2_picker != null else ""
	_draft_page.ult2 = "" if ult2_val == "-" else ult2_val


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

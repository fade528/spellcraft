extends CanvasLayer

const ELEMENTS := ["Fire", "Ice", "Earth", "Thunder", "Water", "Holy", "Dark"]
const DELIVERIES := ["Bolt", "Burst", "Beam", "Blast", "Cleave", "Missile", "Wall", "Utility"]

signal ui_closed

enum TabView { SPEC_LIST, SPEC_EDITOR, PAGE_EDITOR }
var _current_tab: TabView = TabView.SPEC_LIST
var _editing_spec_name: String = ""
var _spec_editor_container: VBoxContainer = null
var _spec_school_labels: Dictionary = {}
var _spec_ratios: Dictionary = {}
var _ratio_input_fields: Dictionary = {}
var _spec_editor_page_index: int = 0
var _spec_page_section: VBoxContainer = null

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
	back_button.pressed.connect(_on_back_pressed)
	for child in tome_view.get_children():
		if child != page_list:
			child.hide()
	_build_tab_ui()

	call_deferred("_connect_menu_button")


func _connect_menu_button() -> void:
	var cs = get_tree().get_first_node_in_group("control_strip")
	if cs == null:
		cs = get_tree().current_scene.get_node_or_null("ControlStrip")
	if cs == null:
		cs = get_tree().current_scene.find_child("ControlStrip", true, false)
	if cs == null:
		return
	if not cs.has_signal("menu_button_pressed"):
		return
	if not cs.menu_button_pressed.is_connected(_on_menu_button_pressed):
		cs.menu_button_pressed.connect(_on_menu_button_pressed)


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
		_switch_to_spec_list()
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
	var page_section_label := Label.new()
	page_section_label.text = "PAGES"
	page_section_label.modulate = Color(0.8, 0.8, 0.8)
	_spec_editor_container.add_child(page_section_label)
	_spec_page_section = VBoxContainer.new()
	_spec_page_section.name = "PageSection"
	_spec_editor_container.add_child(_spec_page_section)
	_repopulate_page_section()

	# Live school allocation with +/-
	_spec_editor_container.add_child(HSeparator.new())
	var alloc_title := Label.new()
	alloc_title.text = "Mana & Ratios:"
	alloc_title.modulate = Color(0.8, 0.8, 0.8)
	_spec_editor_container.add_child(alloc_title)
	var shared_school_row := HBoxContainer.new()
	var SCHOOL_NAMES := ["fire", "ice", "earth", "thunder", "water", "holy", "dark"]
	for school in SCHOOL_NAMES:
		var school_name_lbl := Label.new()
		school_name_lbl.text = school.capitalize()
		school_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		school_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		school_name_lbl.modulate = ELEMENT_COLORS.get(school, Color.WHITE)
		shared_school_row.add_child(school_name_lbl)
	var is_editing_archmage: bool = (_editing_spec_name == "" or _editing_spec_name == "Archmage")
	var is_archmage_edit: bool = is_editing_archmage
	_ratio_input_fields.clear()
	var ratio_input_row := HBoxContainer.new()
	for school in SCHOOL_NAMES:
		var input := LineEdit.new()
		input.name = "RatioInput_" + school
		var pct_val := int(_spec_ratios.get(school, 0.0) * 100.0)
		input.text = str(pct_val) if pct_val > 0 else ""
		input.placeholder_text = "0"
		input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ratio_input_row.add_child(input)
		_ratio_input_fields[school] = input
	var ratio_hint := Label.new()
	ratio_hint.text = "Enter whole numbers (e.g. 80 / 20). Values normalise on save."
	ratio_hint.add_theme_font_size_override("font_size", 18)
	ratio_hint.modulate = Color(0.7, 0.7, 0.7)
	_spec_editor_container.add_child(shared_school_row)
	if not is_archmage_edit:
		_spec_editor_container.add_child(ratio_input_row)
		_spec_editor_container.add_child(ratio_hint)
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
	var has_spec2: bool = sm != null and not is_editing_archmage
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
	if is_archmage_edit:
		var archmage_hint := Label.new()
		archmage_hint.text = "% allocation requires a named spec"
		archmage_hint.add_theme_font_size_override("font_size", 18)
		archmage_hint.modulate = Color(0.55, 0.55, 0.55)
		archmage_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_spec_editor_container.add_child(archmage_hint)

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


func _read_ratio_inputs_normalised() -> Dictionary:
	var SCHOOL_LIST := ["fire", "ice", "earth", "thunder", "water", "holy", "dark"]
	var raw: Dictionary = {}
	var total := 0.0
	for school in SCHOOL_LIST:
		var val := 0.0
		if _ratio_input_fields.has(school):
			var field: LineEdit = _ratio_input_fields[school]
			if is_instance_valid(field) and field.text.strip_edges() != "":
				val = float(field.text.strip_edges().to_int())
		raw[school] = val
		total += val
	var result: Dictionary = {}
	if total > 0.0:
		for school in SCHOOL_LIST:
			if raw[school] > 0.0:
				result[school] = raw[school] / total
	return result


func _on_spec_editor_alloc_remaining() -> void:
	var inv = get_node_or_null("/root/PlayerInventory")
	if inv == null:
		return
	var ratios := _read_ratio_inputs_normalised()
	if ratios.is_empty():
		return
	var amount: int = inv.unallocated_mana
	if amount <= 0:
		return
	for school in ratios.keys():
		var share: int = int(float(amount) * ratios[school])
		if share > 0:
			inv.allocate_to_school(school, share)
	_refresh_school_labels()


func _on_spec_editor_alloc_all() -> void:
	var inv = get_node_or_null("/root/PlayerInventory")
	if inv == null:
		return
	var ratios := _read_ratio_inputs_normalised()
	if ratios.is_empty():
		return
	# Reset all allocation back to unallocated first
	for school in inv.school_allocation.keys():
		inv.unallocated_mana += int(inv.school_allocation[school])
	inv.school_allocation.clear()
	var amount: int = inv.unallocated_mana
	if amount <= 0:
		return
	for school in ratios.keys():
		var share: int = int(float(amount) * ratios[school])
		if share > 0:
			inv.allocate_to_school(school, share)
	_refresh_school_labels()


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
	var tm_save = get_node_or_null("/root/TomeManager")
	if tm_save != null and not tm_save.pages.is_empty():
		var first_page: PageData = tm_save.get_page(0)
		if first_page != null:
			first_page.ensure_slots(4)
			preferred = first_page.slots.duplicate(true)
	var summon_el := "fire"
	if tm_save != null and not tm_save.pages.is_empty():
		var first_page2: PageData = tm_save.get_page(0)
		if first_page2 != null:
			summon_el = first_page2.summon_element
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


func _on_menu_button_pressed() -> void:
	if visible:
		close_ui()
	else:
		open_ui()


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
	_repopulate_page_section()


func _on_back_pressed() -> void:
	_switch_to_spec_editor()


func _repopulate_page_section() -> void:
	if _spec_page_section == null:
		return
	for child in _spec_page_section.get_children():
		child.queue_free()

	var tm = get_node_or_null("/root/TomeManager")
	if tm == null:
		return

	var page_count: int = tm.pages.size()
	_spec_editor_page_index = clampi(_spec_editor_page_index, 0, maxi(page_count - 1, 0))

	# Nav row: Prev | Page X of Y | Next | + Add | - Remove
	var nav_row := HBoxContainer.new()
	var prev_btn := Button.new()
	prev_btn.text = "< Prev"
	prev_btn.disabled = _spec_editor_page_index <= 0
	prev_btn.pressed.connect(func() -> void:
		_spec_editor_page_index -= 1
		_repopulate_page_section()
	)
	nav_row.add_child(prev_btn)
	var page_lbl := Label.new()
	page_lbl.text = "Page %d of %d" % [_spec_editor_page_index + 1, page_count]
	page_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav_row.add_child(page_lbl)
	var next_btn := Button.new()
	next_btn.text = "Next >"
	next_btn.disabled = _spec_editor_page_index >= page_count - 1
	next_btn.pressed.connect(func() -> void:
		_spec_editor_page_index += 1
		_repopulate_page_section()
	)
	nav_row.add_child(next_btn)
	var add_btn := Button.new()
	add_btn.text = "+ Add"
	add_btn.disabled = page_count >= 8
	add_btn.pressed.connect(func() -> void:
		tm.add_page()
		_spec_editor_page_index = tm.pages.size() - 1
		_repopulate_page_section()
	)
	nav_row.add_child(add_btn)
	var remove_btn := Button.new()
	remove_btn.text = "- Remove"
	remove_btn.disabled = page_count <= 1
	remove_btn.pressed.connect(func() -> void:
		tm.delete_page(_spec_editor_page_index)
		_spec_editor_page_index = clampi(_spec_editor_page_index, 0, maxi(tm.pages.size() - 1, 0))
		_repopulate_page_section()
	)
	nav_row.add_child(remove_btn)
	_spec_page_section.add_child(nav_row)

	# Page name LineEdit — saves on focus_exited
	var page: PageData = tm.get_page(_spec_editor_page_index)
	if page == null:
		return
	var name_row := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = "Name:"
	name_lbl.custom_minimum_size = Vector2(60, 0)
	name_row.add_child(name_lbl)
	var name_edit := LineEdit.new()
	name_edit.text = page.page_name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var captured_index := _spec_editor_page_index
	name_edit.focus_exited.connect(func() -> void:
		tm.rename_page(captured_index, name_edit.text)
	)
	name_row.add_child(name_edit)
	var override_lbl := Label.new()
	override_lbl.text = "* " if page.is_overridden else "~ "
	name_row.add_child(override_lbl)
	_spec_page_section.add_child(name_row)

	# Spell slot rows (display only — greyed except slot 1)
	page.ensure_slots(4)
	for i in range(4):
		var slot: Dictionary = page.slots[i]
		var slot_row := HBoxContainer.new()
		if i > 0:
			slot_row.modulate = Color(0.55, 0.55, 0.55)
		var slot_lbl := Label.new()
		slot_lbl.text = "Slot %d" % (i + 1)
		slot_lbl.custom_minimum_size = Vector2(55, 0)
		slot_row.add_child(slot_lbl)
		var el := _make_option_button(ELEMENTS, str(slot.get("elemental", "fire")))
		var em := _make_option_button(ELEMENTS, str(slot.get("empowerment", "fire")))
		var en := _make_option_button(ELEMENTS, str(slot.get("enchantment", "fire")))
		var dl := _make_option_button(DELIVERIES, str(slot.get("delivery", "bolt")))
		if i == 0:
			var ci := _spec_editor_page_index
			var save_func := func(_idx: int) -> void:
				var pg: PageData = tm.get_page(ci)
				if pg == null:
					return
				pg.ensure_slots(4)
				pg.slots[0]["elemental"] = _get_selected_option_value(el)
				pg.slots[0]["empowerment"] = _get_selected_option_value(em)
				pg.slots[0]["enchantment"] = _get_selected_option_value(en)
				pg.slots[0]["delivery"] = _get_selected_option_value(dl)
				pg.is_overridden = true
				tm.save_page(ci, pg)
				if ci == tm.active_page_index:
					var player := get_tree().get_first_node_in_group("player")
					if player != null:
						var casters := player.find_children("*", "Node2D", true, false)
						var caster_idx := 0
						for child in casters:
							if child.has_method("refresh_spell") and caster_idx == 0:
								child.refresh_spell(
									pg.slots[0].get("elemental", "fire"),
									pg.slots[0].get("empowerment", "fire"),
									pg.slots[0].get("enchantment", "fire"),
									pg.slots[0].get("delivery", "bolt"),
									pg.slots[0].get("target", "enemy")
								)
								break
			el.item_selected.connect(save_func)
			em.item_selected.connect(save_func)
			en.item_selected.connect(save_func)
			dl.item_selected.connect(save_func)
		else:
			el.disabled = true
			em.disabled = true
			en.disabled = true
			dl.disabled = true
		slot_row.add_child(el)
		slot_row.add_child(em)
		slot_row.add_child(en)
		slot_row.add_child(dl)
		_spec_page_section.add_child(slot_row)

	# Summon row
	var s_row := HBoxContainer.new()
	var s_lbl := Label.new()
	s_lbl.text = "Summon:"
	s_lbl.custom_minimum_size = Vector2(60, 0)
	s_row.add_child(s_lbl)
	var s_pick := _make_option_button(ELEMENTS, page.summon_element)
	var s_ci := _spec_editor_page_index
	s_pick.item_selected.connect(func(_idx: int) -> void:
		var pg: PageData = tm.get_page(s_ci)
		if pg == null:
			return
		pg.summon_element = _get_selected_option_value(s_pick)
		pg.is_overridden = true
		tm.save_page(s_ci, pg)
	)
	s_row.add_child(s_pick)
	_spec_page_section.add_child(s_row)

	# Ult rows
	var ult_options: Array = ["-"] + ELEMENTS
	for u in range(2):
		var u_row := HBoxContainer.new()
		var u_lbl := Label.new()
		u_lbl.text = "Ult %d:" % (u + 1)
		u_lbl.custom_minimum_size = Vector2(60, 0)
		u_row.add_child(u_lbl)
		var u_val: String = page.ult1 if u == 0 else page.ult2
		var u_pick := _make_option_button(ult_options, u_val if u_val != "" else "-")
		u_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var u_ci := _spec_editor_page_index
		var u_slot := u
		u_pick.item_selected.connect(func(_idx: int) -> void:
			var pg: PageData = tm.get_page(u_ci)
			if pg == null:
				return
			var picked := _get_selected_option_value(u_pick)
			if u_slot == 0:
				pg.ult1 = "" if picked == "-" else picked
			else:
				pg.ult2 = "" if picked == "-" else picked
			pg.is_overridden = true
			tm.save_page(u_ci, pg)
		)
		u_row.add_child(u_pick)
		_spec_page_section.add_child(u_row)

	var action_row := HBoxContainer.new()
	var save_page_inline_btn := Button.new()
	save_page_inline_btn.text = "Save Page"
	save_page_inline_btn.custom_minimum_size = Vector2(0, 48)
	save_page_inline_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spi := _spec_editor_page_index
	save_page_inline_btn.pressed.connect(func() -> void:
		var pg: PageData = tm.get_page(spi)
		if pg == null:
			return
		pg.is_overridden = true
		tm.save_page(spi, pg)
		_repopulate_page_section()
	)
	action_row.add_child(save_page_inline_btn)
	var activate_btn := Button.new()
	activate_btn.text = "Activate"
	activate_btn.disabled = (spi == tm.active_page_index)
	activate_btn.custom_minimum_size = Vector2(0, 48)
	activate_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	activate_btn.pressed.connect(_on_set_active_pressed.bind(spi))
	action_row.add_child(activate_btn)
	_spec_page_section.add_child(action_row)


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

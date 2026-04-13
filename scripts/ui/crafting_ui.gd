extends CanvasLayer

const ELEMENTS := ["Fire", "Ice", "Earth", "Thunder", "Water", "Holy", "Dark"]
const DELIVERIES := ["Bolt", "Burst", "Beam", "Blast", "Cleave", "Missile", "Orbs", "Utility"]
const ELEMENT_COLOURS := {
	"fire": "#e05030",
	"ice": "#60d0f0",
	"earth": "#c08040",
	"thunder": "#f0e020",
	"water": "#4080e0",
	"holy": "#f0f0f0",
	"dark": "#9040c0"
}
const ELEMENT_COLOURS_NODE := {
	"fire": Color(0.88, 0.31, 0.19),
	"ice": Color(0.38, 0.82, 0.94),
	"earth": Color(0.75, 0.50, 0.25),
	"thunder": Color(0.94, 0.89, 0.13),
	"water": Color(0.25, 0.50, 0.88),
	"holy": Color(0.95, 0.95, 0.85),
	"dark": Color(0.56, 0.25, 0.75)
}
const DELIVERY_DESCRIPTIONS := {
	"bolt": "Standard missile with direction tracking and homing.",
	"missile": "Standard missile without tracking but slower speed and higher dmg.",
	"burst": "Tri shot with 25% reduced dmg at 10 degree angle each side.",
	"beam": "Instant straight line with max Y axis, penetrates all units.",
	"blast": "360 around the caster with significant range, dmg reduced.",
	"cleave": "Frontal cone with predefined hitbox range, easy to hit zone.",
	"orbs": "3 orbs surround and rotate the player, each rotate is 1 instance per orb.",
	"utility": "Self-targeted effect."
}

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
var _draft_allocation: Dictionary = {}
var _draft_mana_pool: int = 0
var _draft_initialised: bool = false
var _alloc_spinboxes: Dictionary = {}
var _draft_slots: Array[Dictionary] = []
var _slots_draft_dirty: bool = false
var _draft_page_name: String = ""
var _nav_prev_btn: Button = null
var _nav_next_btn: Button = null
var _nav_add_btn: Button = null
var _nav_remove_btn: Button = null
var _activate_btn: Button = null
var _confirm_spells_btn: Button = null

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
var _volume_row_built: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	resume_button.pressed.connect(close_ui)
	back_button.pressed.connect(_on_back_pressed)
	for child in tome_view.get_children():
		if child != page_list:
			child.hide()
	_build_tab_ui()

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 1.0)
	style.set_corner_radius_all(0)
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_top = 0
	style.border_width_bottom = 0
	panel_container.add_theme_stylebox_override("panel", style)

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
	_draft_initialised = false
	_slots_draft_dirty = false
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
	_volume_row_built = false

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

	if not _volume_row_built:
		_spec_tab_container.add_child(HSeparator.new())
		_build_volume_row(_spec_tab_container)
		_volume_row_built = true


func _set_bgm_volume(linear: float) -> void:
	var bgm: AudioStreamPlayer = get_tree().current_scene.get_node_or_null("BGMusic") as AudioStreamPlayer
	if bgm != null:
		bgm.volume_db = linear_to_db(max(linear, 0.0001))


func _set_sfx_volume(linear: float) -> void:
	for sfx_name in ["SpellHitSFX", "PlayerHurtSFX", "EnemyDeathSFX"]:
		var sfx: AudioStreamPlayer = get_tree().current_scene.get_node_or_null(sfx_name) as AudioStreamPlayer
		if sfx != null:
			sfx.volume_db = linear_to_db(max(linear, 0.0001))


func _save_volume_settings(bgm: float, sfx: float) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "bgm", bgm)
	cfg.set_value("audio", "sfx", sfx)
	cfg.save("user://settings.cfg")


func _load_volume_settings() -> Vector2:
	var cfg := ConfigFile.new()
	var err := cfg.load("user://settings.cfg")
	if err != OK:
		return Vector2(0.8, 0.8)
	var bgm: float = float(cfg.get_value("audio", "bgm", 0.8))
	var sfx: float = float(cfg.get_value("audio", "sfx", 0.8))
	return Vector2(bgm, sfx)


func _build_volume_row(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bgm_lbl := Label.new()
	bgm_lbl.text = "BGM"
	bgm_lbl.custom_minimum_size = Vector2(50, 0)
	row.add_child(bgm_lbl)

	var bgm_slider := HSlider.new()
	bgm_slider.min_value = 0.0
	bgm_slider.max_value = 1.0
	bgm_slider.step = 0.05
	bgm_slider.value = 0.8
	bgm_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bgm_slider)

	var sfx_lbl := Label.new()
	sfx_lbl.text = "SFX"
	sfx_lbl.custom_minimum_size = Vector2(50, 0)
	row.add_child(sfx_lbl)

	var sfx_slider := HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.value = 0.8
	sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sfx_slider)

	var saved := _load_volume_settings()
	bgm_slider.value = saved.x
	sfx_slider.value = saved.y
	_set_bgm_volume(saved.x)
	_set_sfx_volume(saved.y)

	bgm_slider.value_changed.connect(func(v: float) -> void:
		_set_bgm_volume(v)
		_save_volume_settings(v, sfx_slider.value)
	)
	sfx_slider.value_changed.connect(func(v: float) -> void:
		_set_sfx_volume(v)
		_save_volume_settings(bgm_slider.value, v)
	)

	parent.add_child(row)


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
	_draft_initialised = false
	_slots_draft_dirty = false
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
	if not _draft_initialised:
		var inv = get_node_or_null("/root/PlayerInventory")
		if inv != null:
			_draft_allocation = inv.school_allocation.duplicate()
			_draft_mana_pool = inv.mana_pool
		else:
			_draft_allocation = {}
			_draft_mana_pool = 0
		var tm_page = get_node_or_null("/root/TomeManager")
		if tm_page != null and _draft_initialised == false:
			_spec_editor_page_index = tm_page.active_page_index
		_draft_initialised = true
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
	_alloc_spinboxes.clear()

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
	_spec_page_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var scroll := ScrollContainer.new()
	scroll.name = "PageScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.add_child(_spec_page_section)
	_spec_editor_container.add_child(scroll)
	_repopulate_page_section()

	# Live school allocation with +/-
	_spec_editor_container.add_child(HSeparator.new())
	var alloc_header_row := HBoxContainer.new()
	var alloc_title := Label.new()
	alloc_title.text = "Mana & Ratios:"
	alloc_title.modulate = Color(0.8, 0.8, 0.8)
	alloc_header_row.add_child(alloc_title)
	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alloc_header_row.add_child(header_spacer)
	var header_mana_lbl := Label.new()
	header_mana_lbl.name = "SpecManaLabel"
	var total_mana: int = _draft_mana_pool
	var free_mana_header: int = _draft_mana_pool - _get_draft_allocated_total()
	header_mana_lbl.text = "Mana: %d | Free: %d" % [total_mana, free_mana_header]
	header_mana_lbl.modulate = Color(0.8, 0.8, 0.8)
	alloc_header_row.add_child(header_mana_lbl)
	_spec_editor_container.add_child(alloc_header_row)
	var shared_school_row := HBoxContainer.new()
	var SCHOOL_NAMES := ["fire", "ice", "earth", "thunder", "water", "holy", "dark"]
	for school in SCHOOL_NAMES:
		var school_key: String = str(school).to_lower()
		var school_name_lbl := Label.new()
		school_name_lbl.text = "%s %d" % [school.capitalize(), int(_draft_allocation.get(school_key, 0))]
		school_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		school_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		school_name_lbl.modulate = ELEMENT_COLORS.get(school, Color.WHITE)
		_spec_school_labels[school_key] = school_name_lbl
		shared_school_row.add_child(school_name_lbl)
	var is_editing_archmage: bool = (_editing_spec_name == "" or _editing_spec_name == "Archmage")
	var is_archmage_edit: bool = is_editing_archmage
	_spec_editor_container.add_child(shared_school_row)
	var live_swatch_row := HBoxContainer.new()
	var SCHOOL_NAMES2 := ["fire", "ice", "earth", "thunder", "water", "holy", "dark"]
	for school in SCHOOL_NAMES2:
		var col2 := VBoxContainer.new()
		col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tier_input := SpinBox.new()
		var current_allocation: int = int(_draft_allocation.get(school.to_lower(), 0))
		tier_input.min_value = 0
		tier_input.max_value = 99
		tier_input.step = 1
		tier_input.value = current_allocation
		tier_input.suffix = ""
		tier_input.prefix = "M"
		tier_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tier_input.value_changed.connect(_on_spec_school_tier_changed.bind(school))
		_alloc_spinboxes[school.to_lower()] = tier_input
		col2.add_child(tier_input)
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
	_ratio_input_fields.clear()
	var ratio_lbl := Label.new()
	ratio_lbl.text = "Ratio"
	ratio_lbl.modulate = Color(0.6, 0.6, 0.6)
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
	if not is_archmage_edit:
		_spec_editor_container.add_child(ratio_lbl)
		_spec_editor_container.add_child(ratio_input_row)
	var alloc_btn_row := HBoxContainer.new()
	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm Allocation"
	confirm_btn.pressed.connect(_on_confirm_allocation_pressed)
	alloc_btn_row.add_child(confirm_btn)
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

	var test_mana_input := SpinBox.new()
	test_mana_input.min_value = 1
	test_mana_input.max_value = 9999
	test_mana_input.step = 1
	test_mana_input.value = 10
	test_mana_input.custom_minimum_size = Vector2(100, 0)
	alloc_btn_row.add_child(test_mana_input)

	var test_mana_btn := Button.new()
	test_mana_btn.text = "Add"
	test_mana_btn.pressed.connect(func() -> void:
		var inv_add = get_node_or_null("/root/PlayerInventory")
		if inv_add == null:
			return
		inv_add.add_mana(int(test_mana_input.value))
		_draft_mana_pool = inv_add.mana_pool
		_refresh_allocation_display()
	)
	alloc_btn_row.add_child(test_mana_btn)
	_spec_editor_container.add_child(alloc_btn_row)
	if is_archmage_edit:
		var archmage_hint := Label.new()
		archmage_hint.text = "% allocation requires a named spec"
		archmage_hint.add_theme_font_size_override("font_size", 18)
		archmage_hint.modulate = Color(0.55, 0.55, 0.55)
		archmage_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_spec_editor_container.add_child(archmage_hint)

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
	_refresh_allocation_display()


func _get_draft_allocated_total() -> int:
	var allocated: int = 0
	for value in _draft_allocation.values():
		allocated += int(value)
	return allocated


func _refresh_allocation_display() -> void:
	var allocated: int = _get_draft_allocated_total()
	var free_mana: int = _draft_mana_pool - allocated
	for school in _spec_school_labels.keys():
		var label_control = _spec_school_labels[school]
		if label_control is Label and is_instance_valid(label_control):
			(label_control as Label).text = "%s %d" % [str(school).capitalize(), int(_draft_allocation.get(school, 0))]
	for school in _alloc_spinboxes.keys():
		var spinbox = _alloc_spinboxes[school]
		if spinbox is SpinBox and is_instance_valid(spinbox):
			(spinbox as SpinBox).set_value_no_signal(float(_draft_allocation.get(school, 0)))
	var mana_lbl := _spec_editor_container.find_child("SpecManaLabel", true, false)
	if mana_lbl is Label:
		mana_lbl.text = "Mana: %d | Free: %d" % [_draft_mana_pool, free_mana]


func _on_spec_school_tier_changed(new_val: float, school: String) -> void:
	var school_key: String = school.to_lower()
	var total_others := 0
	for key in _draft_allocation:
		if key != school_key:
			total_others += int(_draft_allocation.get(key, 0))
	var max_for_school: int = maxi(_draft_mana_pool - total_others, 0)
	_draft_allocation[school_key] = clampi(int(new_val), 0, max_for_school)
	_refresh_allocation_display()
	_repopulate_page_section()


func _on_spec_school_alloc_plus(school: String) -> void:
	var school_key: String = school.to_lower()
	var current: int = int(_draft_allocation.get(school_key, 0))
	var free_mana: int = _draft_mana_pool - _get_draft_allocated_total()
	if free_mana > 0:
		_draft_allocation[school_key] = current + 1
		_refresh_allocation_display()
	_repopulate_page_section()


func _on_spec_school_alloc_minus(school: String) -> void:
	var school_key: String = school.to_lower()
	var current: int = int(_draft_allocation.get(school_key, 0))
	if current > 0:
		_draft_allocation[school_key] = current - 1
		_refresh_allocation_display()
	_repopulate_page_section()


func _on_spec_editor_reset_alloc() -> void:
	for element in ELEMENTS:
		_draft_allocation[str(element).to_lower()] = 0
	_refresh_allocation_display()
	_repopulate_page_section()


func _on_confirm_allocation_pressed() -> void:
	var inv = get_node_or_null("/root/PlayerInventory")
	if inv == null:
		return
	var current_schools: Array = inv.school_allocation.keys()
	for school in current_schools:
		var current: int = int(inv.school_allocation.get(school, 0))
		if current > 0:
			inv.deallocate_from_school(school, current)
	for school in _draft_allocation:
		var amount: int = int(_draft_allocation.get(school, 0))
		if amount > 0:
			inv.allocate_to_school(school, amount)
	_draft_allocation = inv.school_allocation.duplicate()
	_draft_mana_pool = inv.mana_pool
	var pm = get_node_or_null("/root/PassiveManager")
	if pm != null and pm.has_method("recalculate"):
		pm.recalculate()
	for caster in get_tree().get_nodes_in_group("spell_casters"):
		if is_instance_valid(caster) and caster.has_method("_recompose_spell"):
			caster.call("_recompose_spell")
	_refresh_allocation_display()
	_repopulate_page_section()


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
	var ratios := _read_ratio_inputs_normalised()
	if ratios.is_empty():
		return
	var amount: int = _draft_mana_pool - _get_draft_allocated_total()
	if amount <= 0:
		return
	for school in ratios.keys():
		var share: int = int(float(amount) * ratios[school])
		if share > 0:
			_draft_allocation[school] = int(_draft_allocation.get(school, 0)) + share
	_refresh_allocation_display()
	_repopulate_page_section()


func _on_spec_editor_alloc_all() -> void:
	var ratios := _read_ratio_inputs_normalised()
	if ratios.is_empty():
		return
	for element in ELEMENTS:
		_draft_allocation[str(element).to_lower()] = 0
	var amount: int = _draft_mana_pool
	if amount <= 0:
		return
	for school in ratios.keys():
		var share: int = int(float(amount) * ratios[school])
		if share > 0:
			_draft_allocation[school] = int(_draft_allocation.get(school, 0)) + share
	_refresh_allocation_display()
	_repopulate_page_section()


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
		_slots_draft_dirty = false
		_spec_editor_page_index = (_spec_editor_page_index - 1 + page_count) % page_count
		_repopulate_page_section()
	)
	_nav_prev_btn = prev_btn
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
		_slots_draft_dirty = false
		_spec_editor_page_index = (_spec_editor_page_index + 1) % page_count
		_repopulate_page_section()
	)
	_nav_next_btn = next_btn
	nav_row.add_child(next_btn)
	var add_btn := Button.new()
	add_btn.text = "+ Add"
	add_btn.disabled = page_count >= 8
	add_btn.pressed.connect(func() -> void:
		_slots_draft_dirty = false
		tm.add_page()
		_spec_editor_page_index = tm.pages.size() - 1
		_repopulate_page_section()
	)
	_nav_add_btn = add_btn
	nav_row.add_child(add_btn)
	var remove_btn := Button.new()
	remove_btn.text = "- Remove"
	remove_btn.disabled = page_count <= 1
	remove_btn.pressed.connect(func() -> void:
		_slots_draft_dirty = false
		tm.delete_page(_spec_editor_page_index)
		_spec_editor_page_index = clampi(_spec_editor_page_index, 0, maxi(tm.pages.size() - 1, 0))
		_repopulate_page_section()
	)
	_nav_remove_btn = remove_btn
	nav_row.add_child(remove_btn)
	_spec_page_section.add_child(nav_row)

	# Page name LineEdit — saves on focus_exited
	var page: PageData = tm.get_page(_spec_editor_page_index)
	if page == null:
		return
	if not _slots_draft_dirty:
		_draft_page_name = page.page_name
		_draft_slots = []
		page.ensure_slots(4)
		for s in page.slots:
			if s is Dictionary:
				_draft_slots.append((s as Dictionary).duplicate(true))
			else:
				_draft_slots.append({})
		while _draft_slots.size() < 4:
			_draft_slots.append({})
	var name_row := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = "Name:"
	name_lbl.custom_minimum_size = Vector2(60, 0)
	name_row.add_child(name_lbl)
	var name_edit := LineEdit.new()
	name_edit.text = _draft_page_name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.focus_exited.connect(func() -> void:
		_draft_page_name = name_edit.text
		_slots_draft_dirty = true
		_update_nav_and_action_buttons()
	)
	name_edit.text_changed.connect(func(_new_text: String) -> void:
		_draft_page_name = name_edit.text
		_slots_draft_dirty = true
		_update_nav_and_action_buttons()
	)
	name_row.add_child(name_edit)
	var override_lbl := Label.new()
	override_lbl.text = "* " if page.is_overridden else "~ "
	name_row.add_child(override_lbl)
	_spec_page_section.add_child(name_row)

	page.ensure_slots(4)
	var header_row := HBoxContainer.new()
	var header_labels := ["Element", "Empowerment", "Enchantment", "Delivery"]
	var slot_header_lbl := Label.new()
	slot_header_lbl.text = "Slot"
	slot_header_lbl.custom_minimum_size = Vector2(55, 0)
	slot_header_lbl.modulate = Color(0.6, 0.6, 0.6)
	header_row.add_child(slot_header_lbl)
	for header_text in header_labels:
		var h := Label.new()
		h.text = header_text
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.modulate = Color(0.6, 0.6, 0.6)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header_row.add_child(h)
	_spec_page_section.add_child(header_row)

	# Spell slot rows
	for i in range(4):
		var slot: Dictionary = _draft_slots[i] if i < _draft_slots.size() else {}
		var slot_row := HBoxContainer.new()
		var slot_lbl := Label.new()
		slot_lbl.text = "Slot %d" % (i + 1)
		slot_lbl.custom_minimum_size = Vector2(55, 0)
		slot_row.add_child(slot_lbl)
		var el := _make_school_option_button(ELEMENTS, str(slot.get("elemental", "-")))
		var em := _make_school_option_button(ELEMENTS, str(slot.get("empowerment", "-")))
		var en := _make_school_option_button(ELEMENTS, str(slot.get("enchantment", "-")))
		var dl := _make_option_button(DELIVERIES, str(slot.get("delivery", "-")))
		var ci_slot := i
		var draft_func := func(
			_idx: int,
			slot_index: int,
			el_picker: OptionButton,
			em_picker: OptionButton,
			en_picker: OptionButton,
			dl_picker: OptionButton
		) -> void:
			while _draft_slots.size() <= slot_index:
				_draft_slots.append({})
			_draft_slots[slot_index]["elemental"] = _get_selected_option_value(el_picker)
			_draft_slots[slot_index]["empowerment"] = _get_selected_option_value(em_picker)
			_draft_slots[slot_index]["enchantment"] = _get_selected_option_value(en_picker)
			_draft_slots[slot_index]["delivery"] = _get_selected_option_value(dl_picker)
			_slots_draft_dirty = true
			_update_nav_and_action_buttons()
			_apply_picker_colour(el_picker)
			_apply_picker_colour(em_picker)
			_apply_picker_colour(en_picker)
		el.item_selected.connect(draft_func.bind(ci_slot, el, em, en, dl))
		em.item_selected.connect(draft_func.bind(ci_slot, el, em, en, dl))
		en.item_selected.connect(draft_func.bind(ci_slot, el, em, en, dl))
		dl.item_selected.connect(draft_func.bind(ci_slot, el, em, en, dl))
		var tooltip_row := slot_row
		var refresh_tooltip := func(
			idx: int,
			changed_picker: OptionButton,
			el_picker: OptionButton,
			em_picker: OptionButton,
			en_picker: OptionButton,
			dl_picker: OptionButton,
			tooltip_row_ref: HBoxContainer
		) -> void:
			var parts := _build_slot_tooltip_parts(el_picker, em_picker, en_picker, dl_picker, changed_picker, idx)
			_apply_picker_colour(el_picker)
			_apply_picker_colour(em_picker)
			_apply_picker_colour(en_picker)
			_show_slot_tooltip(tooltip_row_ref, parts)
		el.item_selected.connect(refresh_tooltip.bind(el, el, em, en, dl, tooltip_row))
		em.item_selected.connect(refresh_tooltip.bind(em, el, em, en, dl, tooltip_row))
		en.item_selected.connect(refresh_tooltip.bind(en, el, em, en, dl, tooltip_row))
		dl.item_selected.connect(refresh_tooltip.bind(dl, el, em, en, dl, tooltip_row))
		call_deferred("_show_slot_tooltip_deferred", tooltip_row, el, em, en, dl)
		slot_row.add_child(el)
		slot_row.add_child(em)
		slot_row.add_child(en)
		slot_row.add_child(dl)
		_spec_page_section.add_child(slot_row)
		_apply_picker_colour(el)
		_apply_picker_colour(em)
		_apply_picker_colour(en)

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
	var spi := _spec_editor_page_index
	var confirm_spells_btn := Button.new()
	confirm_spells_btn.text = "Confirm Spells"
	confirm_spells_btn.custom_minimum_size = Vector2(0, 48)
	confirm_spells_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_spells_btn.disabled = not _slots_draft_dirty
	confirm_spells_btn.pressed.connect(func() -> void:
		_on_confirm_spells_pressed(spi)
	)
	action_row.add_child(confirm_spells_btn)
	_confirm_spells_btn = confirm_spells_btn
	var cancel_slot_btn := Button.new()
	cancel_slot_btn.text = "Cancel"
	cancel_slot_btn.custom_minimum_size = Vector2(0, 48)
	cancel_slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_slot_btn.pressed.connect(func() -> void:
		_draft_page_name = ""
		_slots_draft_dirty = false
		_repopulate_page_section()
	)
	action_row.add_child(cancel_slot_btn)
	var activate_btn := Button.new()
	activate_btn.text = "Activate"
	activate_btn.disabled = (spi == tm.active_page_index)
	activate_btn.custom_minimum_size = Vector2(0, 48)
	activate_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	activate_btn.pressed.connect(_on_set_active_pressed.bind(spi))
	action_row.add_child(activate_btn)
	_activate_btn = activate_btn
	_spec_page_section.add_child(action_row)
	_update_nav_and_action_buttons()


func _update_nav_and_action_buttons() -> void:
	var dirty := _slots_draft_dirty
	if _nav_prev_btn != null and is_instance_valid(_nav_prev_btn):
		_nav_prev_btn.disabled = dirty
	if _nav_next_btn != null and is_instance_valid(_nav_next_btn):
		_nav_next_btn.disabled = dirty
	if _nav_add_btn != null and is_instance_valid(_nav_add_btn):
		var tm2 := get_node_or_null("/root/TomeManager")
		var pc: int = tm2.pages.size() if tm2 != null else 1
		_nav_add_btn.disabled = dirty or pc >= 8
	if _nav_remove_btn != null and is_instance_valid(_nav_remove_btn):
		var tm3 := get_node_or_null("/root/TomeManager")
		var pc2: int = tm3.pages.size() if tm3 != null else 1
		_nav_remove_btn.disabled = dirty or pc2 <= 1
	if _activate_btn != null and is_instance_valid(_activate_btn):
		var tm4 := get_node_or_null("/root/TomeManager")
		var already_active: bool = tm4 != null and _spec_editor_page_index == tm4.active_page_index
		_activate_btn.disabled = dirty or already_active
	if _confirm_spells_btn != null and is_instance_valid(_confirm_spells_btn):
		_confirm_spells_btn.disabled = not dirty


func _on_confirm_spells_pressed(page_index: int) -> void:
	var tm = get_node_or_null("/root/TomeManager")
	if tm == null:
		return
	var pg: PageData = tm.get_page(page_index)
	if pg == null:
		return
	pg.ensure_slots(4)
	for si in range(mini(_draft_slots.size(), 4)):
		var ds: Dictionary = _draft_slots[si]
		pg.slots[si]["elemental"] = ds.get("elemental", "")
		pg.slots[si]["empowerment"] = ds.get("empowerment", "")
		pg.slots[si]["enchantment"] = ds.get("enchantment", "")
		pg.slots[si]["delivery"] = ds.get("delivery", "bolt")
	pg.is_overridden = true
	tm.save_page(page_index, pg)
	tm.rename_page(page_index, _draft_page_name)
	_slots_draft_dirty = false
	if page_index == tm.active_page_index:
		var player := get_tree().get_first_node_in_group("player")
		if player != null and player.has_method("_refresh_all_casters"):
			player.call("_refresh_all_casters")
	_update_nav_and_action_buttons()


func _make_option_button(options: Array, selected_value: String) -> OptionButton:
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_item("-")
	for option in options:
		picker.add_item(str(option))
	_select_option_value(picker, selected_value)
	return picker


func _make_school_option_button(options: Array, selected_value: String) -> OptionButton:
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_item("-")
	var inv = get_node_or_null("/root/PlayerInventory")
	for option in options:
		var school := str(option)
		if inv != null and int(inv.school_allocation.get(school.to_lower(), 0)) == 0:
			continue
		picker.add_item(school)
	_select_option_value(picker, selected_value)
	return picker


func _apply_picker_colour(picker: OptionButton) -> void:
	var val := picker.get_item_text(picker.selected).to_lower()
	var colour: Color = ELEMENT_COLOURS_NODE.get(val, Color(0.85, 0.85, 0.85))
	picker.add_theme_color_override("font_color", colour)


func _build_description_bbcode(
	effect_name: String,
	raw_description: String,
	tier: int,
	row: Dictionary
) -> String:
	var title := "[b]%s M%d[/b]\n" % [effect_name.capitalize().replace("_", " "), tier]
	var desc := raw_description
	for vi in range(1, 6):
		var placeholder := "[value%d]" % vi
		if not desc.contains(placeholder):
			continue
		var raw_key := "value%d_raw" % vi
		var float_key := "value%d" % vi
		var scale_key := "scale_value%d" % vi
		var raw_str: String = str(row.get(raw_key, "")).strip_edges()

		if raw_str.is_valid_float():
			var base_val := float(raw_str)
			var scale_val := 0.0
			var raw_scale = row.get(scale_key, "")
			if str(raw_scale).is_valid_float():
				scale_val = float(str(raw_scale))
			var computed: float = base_val + scale_val * float(tier)
			var formatted: String
			if abs(computed - float(roundi(computed))) < 0.001:
				formatted = str(roundi(computed))
			else:
				formatted = "%.2f" % computed
			desc = desc.replace(placeholder, "[b]%s[/b]" % formatted)
		elif raw_str != "":
			var colour := str(ELEMENT_COLOURS.get(raw_str.to_lower(), ""))
			if colour != "":
				desc = desc.replace(placeholder, "[color=%s]%s[/color]" % [colour, raw_str.capitalize()])
			else:
				desc = desc.replace(placeholder, raw_str)
		else:
			desc = desc.replace(placeholder, "")

	for vi in range(1, 6):
		var scale_placeholder := "[ScaleValue%d]" % vi
		if desc.contains(scale_placeholder):
			var scale_key_raw := "scale_value%d" % vi
			var raw_scale_value = row.get(scale_key_raw, "")
			var scale_str := str(raw_scale_value) if str(raw_scale_value) != "" else "0"
			desc = desc.replace(scale_placeholder, "[b]%s[/b]" % scale_str)

	for element in ELEMENT_COLOURS:
		var colour := str(ELEMENT_COLOURS[element])
		var forms := [
			element.to_lower(),
			element.capitalize(),
			element.to_upper()
		]
		for form in forms:
			if desc.contains(form):
				desc = desc.replace(form, "[color=%s]%s[/color]" % [colour, form])

	return "[font_size=15]" + title + desc + "[/font_size]"


func _build_delivery_bbcode(delivery: String) -> String:
	var key := delivery.to_lower()
	var text := str(DELIVERY_DESCRIPTIONS.get(key, ""))
	if text == "":
		return ""
	return "[b]%s[/b]\n%s" % [delivery.capitalize(), text]


func _show_slot_tooltip(slot_row: HBoxContainer, parts: Array[String]) -> void:
	var parent := slot_row.get_parent()
	if parent == null:
		return
	var slot_idx := slot_row.get_index()
	var next := parent.get_child(slot_idx + 1) if slot_idx + 1 < parent.get_child_count() else null

	var tooltip_row: HBoxContainer
	if next != null and next is HBoxContainer and next.get_meta("slot_tooltip_row", false):
		tooltip_row = next as HBoxContainer
		for i in range(4):
			var rtl_idx := i + 1
			if rtl_idx < tooltip_row.get_child_count():
				var rtl := tooltip_row.get_child(rtl_idx)
				if rtl is RichTextLabel:
					(rtl as RichTextLabel).text = parts[i] if i < parts.size() else ""
		return

	tooltip_row = HBoxContainer.new()
	tooltip_row.set_meta("slot_tooltip_row", true)
	tooltip_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(tooltip_row)
	parent.move_child(tooltip_row, slot_idx + 1)

	var spacer := Label.new()
	spacer.custom_minimum_size = Vector2(55, 0)
	tooltip_row.add_child(spacer)

	for i in range(4):
		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rtl.add_theme_font_size_override("normal_font_size", 15)
		rtl.modulate = Color(0.85, 0.85, 0.85, 1.0)
		var text: String = parts[i] if i < parts.size() else ""
		rtl.text = text
		tooltip_row.add_child(rtl)


func _build_slot_tooltip_parts(
	el: OptionButton,
	em: OptionButton,
	en: OptionButton,
	dl: OptionButton,
	override_picker: OptionButton = null,
	override_idx: int = -1
) -> Array[String]:
	var get_val := func(picker: OptionButton) -> String:
		if picker == override_picker and override_idx >= 0:
			return picker.get_item_text(override_idx).to_lower()
		return _get_selected_option_value(picker)

	var composer = get_node_or_null("/root/SpellComposer")
	var inv = get_node_or_null("/root/PlayerInventory")
	var el_val: String = get_val.call(el)
	var em_val: String = get_val.call(em)
	var en_val: String = get_val.call(en)
	var dl_val: String = get_val.call(dl)
	var el_tier := 0
	var em_tier := 0
	var en_tier := 0
	if inv != null and inv.has_method("get_school_tier"):
		el_tier = int(inv.get_school_tier(el_val))
		em_tier = int(inv.get_school_tier(em_val))
		en_tier = int(inv.get_school_tier(en_val))

	var target_filter := "self" if dl_val == "utility" else "enemy"
	var parts: Array[String] = ["", "", "", ""]
	if composer != null and composer.has_method("get_all_rows"):
		var row_data = composer.call("get_all_rows")
		if row_data is Array:
			var rows := row_data as Array
			parts[0] = _find_effect_bbcode(rows, el_val, "Elemental", el_tier, target_filter)
			parts[1] = _find_effect_bbcode(rows, em_val, "Empowerment", em_tier, target_filter)
			parts[2] = _find_effect_bbcode(rows, en_val, "Enchantment", en_tier, target_filter)

	parts[3] = _build_delivery_bbcode(dl_val)
	return parts


func _find_effect_bbcode(
	rows: Array,
	element_value: String,
	position: String,
	tier: int,
	target_filter: String
) -> String:
	for row in rows:
		if not row is Dictionary:
			continue
		var row_dict := row as Dictionary
		if str(row_dict.get("element", "")).to_lower() != element_value:
			continue
		if str(row_dict.get("position", "")) != position:
			continue
		if str(row_dict.get("target", "")).to_lower() != target_filter:
			continue
		var display := str(row_dict.get("display_text", "")).strip_edges()
		var desc_text := display if display != "" else str(row_dict.get("description", "")).strip_edges()
		return _build_description_bbcode(
			str(row_dict.get("effect_name", "")),
			desc_text,
			tier,
			row_dict
		)
	return ""


func _show_slot_tooltip_deferred(
	slot_row: HBoxContainer,
	el: OptionButton,
	em: OptionButton,
	en: OptionButton,
	dl: OptionButton
) -> void:
	var parts := _build_slot_tooltip_parts(el, em, en, dl)
	_show_slot_tooltip(slot_row, parts)


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
	var val := picker.get_item_text(picker.selected)
	if val == "-":
		return ""
	return val.to_lower()

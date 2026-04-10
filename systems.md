# Spellcraft Roguelite — Systems Log

> Maintained by David. Updated as technical decisions are made. This is the source of truth for how things are actually built, as opposed to design.md which covers what the game is.

---

## How to Use This File

Every time a significant technical decision is made — architecture choice, pattern used, problem solved — add an entry here. This file is fed to AI assistants at the start of each session so they understand existing decisions and don't contradict them.

Format:
```
## [System Name]
Date: YYYY-MM-DD
Decision: What was decided
Reason: Why
Implementation: How it works in code
Notes: Gotchas, things to watch for
```

---

## Environment

**Date:** TBD
**Godot version:** 4.6.2.stable
**VS Code extensions:** godot-tools
**Target platform:** Android primary, iOS secondary
**Viewport:** 1080x1920 portrait
**Physics fps:** 60
**Git remote:** github.com/fade528/spellcraft

---

## [Template — copy this for each new system]

### System Name
**Date:** YYYY-MM-DD
**Decision:**
**Reason:**
**Implementation:**
```gdscript
# paste key code here
```
**Notes:**

---

## Decisions Log

---

### Player Movement
**Date:** TBD
**Decision:** CharacterBody2D with touchpad analogue input, 8-direction sprite facing
**Reason:** Touchpad gives full 360 degree vector naturally. Sprite snaps to nearest of 8 directions for visual clarity without restricting movement.
**Implementation:**
```gdscript
func get_direction_8(movement: Vector2) -> String:
    if movement.length() < 0.1:
        return "idle"
    var angle = rad_to_deg(movement.angle())
    if angle < -157.5 or angle >= 157.5:  return "left"
    elif angle < -112.5:                   return "up_left"
    elif angle < -67.5:                    return "up"
    elif angle < -22.5:                    return "up_right"
    elif angle < 22.5:                     return "right"
    elif angle < 67.5:                     return "down_right"
    elif angle < 112.5:                    return "down"
    else:                                  return "down_left"
```
**Notes:** Always multiply movement by delta. Use _physics_process not _process for movement.

---

### Collision Layers
**Date:** TBD
**Decision:** 7 layers as defined in context.md
**Reason:** Clean separation prevents spells hitting other spells, player colliding with own projectiles
**Implementation:** Set in Godot editor Project Settings > Layer Names > 2D Physics
**Notes:** Enable "Visible Collision Shapes" in debug settings during development

---

### Damage System
**Date:** TBD
**Decision:** All damage routed through Player.take_damage(amount, type)
**Reason:** Single entry point for damage makes iframes, metrics tracking, and death handling clean
**Notes:** iframe_duration exported to inspector for partner tuning. Default 1.0s.

---

### Iframes
**Date:** TBD
**Decision:** Timer node based, 1.0s default, sprite flash visual cue
**Notes:** iframe_duration exported. Partner tunes via inspector.

---

### Signal Convention
**Date:** TBD
**Decision:** Signals travel up, direct calls travel down
**Notes:** If GameManager function exceeds 5-6 lines, logic belongs in a domain manager.

---

### Resource vs State
**Date:** TBD
**Decision:** Resources = master data (spell definitions, enemy stats). Node variables = runtime state (current HP, cooldowns).
**Notes:** Always duplicate() resources before modifying per-instance values. Never store transactional values in resource files.

---

### Spawning Pattern
**Date:** TBD
**Decision:** EnemySpawner node in Game scene uses repeating Timer, instances Enemy scenes
**Notes:** Enemies despawn when position.y > 1980. spawn_rate and enemy_speed exported.

---

### Mana Drop System (Session 2.41)
**Date:** 2026-04-10
**Decision:** Replaced 7-element coloured orbs with a single generic mana orb. All drops are now identical light-blue ColorRects. PlayerInventory tracks a unified mana_pool and delegates allocation to SpecManager.
**Notes:** Rule added — always use `call_deferred("add_child", node)` when adding children inside physics callbacks.

---

### PlayerInventory Mana API (Session 2.41)
**Date:** 2026-04-10
**Decision:** Added mana economy fields and methods to PlayerInventory.
```gdscript
var mana_pool: int = 0
var school_allocation: Dictionary = {}
var unallocated_mana: int = 0

func add_mana(amount: int) -> void          # delegates to SpecManager.allocate_mana_for_pickup
func allocate_to_school(school, amount) -> void
func deallocate_from_school(school, amount) -> void
func get_school_tier(school: String) -> int
func get_school_multiplier(school: String) -> float
```
**Notes:** reset_run() clears mana_pool, school_allocation, unallocated_mana.

---

### School Gating in SpellCaster (Sessions 2.41 / 2.42)
**Date:** 2026-04-10 / 2026-04-10
**Decision:** SpellCaster silently skips firing if the elemental school has zero allocation AND school_allocation is not empty. Timer keeps running.
```gdscript
if _inventory != null and not _inventory.school_allocation.is_empty() and _inventory.get_school_tier(elemental_element) == 0:
    return
```
**Notes:** Gate only activates once player has made at least one allocation. Before any allocation, spells fire freely. Only elemental slot is gated — empowerment and enchantment are not checked. Timer only starts if stopped (fix for rapid-fire on page flip).

---

### SpecData Resource (Session 2.41)
**Date:** 2026-04-10
**Decision:** Specs are .tres resources stored in res://data/specs/. Three built-in specs: Pyroclast, Frostbinder, Archmage.
```gdscript
class_name SpecData extends Resource
@export var spec_name: String = ""
@export var description: String = ""
@export var allocation_ratios: Dictionary = {}
@export var preferred_slots: Array[Dictionary] = []
@export var preferred_ults: Array[String] = []
```
**Notes:** All keys in preferred_slots must be lowercase. Capital letters silently fail reads in Godot inspector.

---

### SpecManager Autoload (Sessions 2.41 / 2.42)
**Date:** 2026-04-10
**Decision:** SpecManager owns active spec state, mana allocation routing, custom spec persistence, and per-spec tome loading.
```gdscript
SpecManager.apply_spec(spec_name: String) -> void        # loads spec, calls tm.load_for_spec()
SpecManager.clear_spec() -> void                          # Archmage mode, calls tm.load_for_spec("archmage")
SpecManager.get_active_spec() -> SpecData
SpecManager.get_active_spec_name() -> String
SpecManager.is_archmage() -> bool
SpecManager.allocate_mana_for_pickup(amount: int) -> void # banks all to unallocated_mana
SpecManager.allocate_remaining_by_spec() -> void          # distributes unallocated per ratio
SpecManager.allocate_all_by_spec() -> void                # resets allocation then redistributes all
SpecManager.get_all_spec_names() -> Array[String]         # built-ins (excl Archmage) + custom
SpecManager.save_spec_from_dict(name, data) -> void       # saves to user://specs.json
SpecManager.delete_custom_spec(name) -> void
SpecManager.save_archmage_as_spec(new_name) -> void       # copies archmage pages + allocation to new custom spec
```
**Notes:** SPEC_PATHS const maps built-in names to .tres paths. Custom specs stored in _custom_specs dict, persisted to user://specs.json. allocate_mana_for_pickup now just banks to unallocated — no per-pickup routing.

---

### Per-Spec Tome Architecture (Session 2.42)
**Date:** 2026-04-10
**Decision:** Each spec owns its own set of pages (up to 8). Switching specs saves current pages and loads the new spec's pages. Archmage has its own pages too.

**Save files:** `user://pages_{spec_name_lowercase}.json` — e.g. pages_pyroclast.json, pages_archmage.json.

**TomeManager API additions:**
```gdscript
TomeManager.load_for_spec(spec_name: String, preferred_slots: Array = []) -> void
TomeManager.reset_to_default(preferred_slots: Array = []) -> void
TomeManager._save_path_for(spec_name: String) -> String
TomeManager._generate_default_pages(preferred_slots: Array) -> void
# _current_spec_name: String tracks active spec
```
**Notes:** On first open of a spec with no save file, default pages are generated from preferred_slots. If preferred_slots is empty (Archmage, custom specs), one blank page is created. Old user://tome_pages.json is obsolete — delete it.

---

### Page Flip Gate Change (Session 2.42)
**Date:** 2026-04-10
**Decision:** Removed summon recharge check from can_flip_page(). Page flips are now only gated by spell cooldown (_flip_cooldown). Summon spawn inside flip_to_page() is still guarded by is_recharged() — flip is allowed during recharge, but summon does not respawn until recharged naturally.
**Reason:** Blocking flips during recharge (up to 60s) was too punishing and prevented gameplay. Summon respawn is handled by SummonManager._process() automatically.
**Notes:** can_flip_page() now only checks _flip_cooldown > 0.

---

### CraftingUI Architecture (Session 2.42)
**Date:** 2026-04-10
**Decision:** Full redesign. Single Spec tab (no separate Tome tab). All UI built in code — no .tscn changes.

**Layout:**
- Spec list screen: Archmage (Activate + Edit + Save as Spec) | Built-in specs 1-5 (Activate + Edit) | Custom specs 6-10 (Activate + Edit + Delete) | Resume
- Spec editor screen: Back | Go to Tome | Reset Spec (built-ins only) | Name field (read-only for built-ins) | 4 slot rows | Summon/Ult pickers | Ratio inputs (integer % fields, normalise on save) | Mana Allocation (+/- per school, Reset Allocation, Alloc Remaining %, Alloc All %) | Save / Cancel
- Tome view: opened by "Go to Tome" in spec editor. Shows pages for active spec. Page rows with override indicator (~=spec-driven, *=manually edited), summary (elemental | S:summon U:ult1/ult2), Craft / Activate / Rename / Delete. Mana chart with +/- at bottom.

**Key patterns:**
- `_spec_tab_container` holds spec list content (built dynamically)
- `_spec_editor_container` holds spec editor content (built dynamically)
- `tome_view` / `page_editor_view` from .tscn reparented into wrapper VBox
- Tab bar has single Spec button only
- `enum TabView { SPEC_LIST, SPEC_EDITOR, TOME_LIST, PAGE_EDITOR }`

**Spec slots:** 10 total. Slots 1-5 = built-in .tres specs (Open, Edit, Reset Spec). Slots 6-10 = custom Archmage-crafted specs (Open, Edit, Delete). Archmage always present at top.

**JSON persistence:** Custom specs → user://specs.json. Page data → user://pages_{spec}.json per spec.

**PageData.is_overridden:** bool flag. Set true when player manually saves a page via Craft editor. Reset to false when Set Active is pressed. Shown as ~ (spec-driven) or * (overridden) prefix in tome page list.

---

### Mana Allocation Philosophy (Session 2.42)
**Date:** 2026-04-10
**Decision:** All mana orb pickups bank to unallocated_mana. No per-pickup routing. Player manually allocates via UI buttons or +/- controls. Three allocation actions: Reset Allocation (zero everything), Alloc Remaining % (distribute unallocated per spec ratio), Alloc All % (reset then redistribute entire pool per spec ratio).
**Reason:** Per-pickup routing with floor() caused incorrect distribution at small amounts. Banking + explicit allocation is clearer for the player and avoids rounding bugs.
**Notes:** Archmage players use +/- directly. Named spec players use the % buttons for quick setup then fine-tune with +/-.

---

### Shooter Projectile Collision Fix (Session 2.42)
**Date:** 2026-04-10
**Decision:** Shooter enemy projectiles now correctly hit player hurtbox (Layer 3) and summon hurtbox (Layer 6).
```gdscript
# In shooter._try_fire():
proj.collision_layer = 0
proj.collision_mask = 0
proj.set_collision_layer_value(5, true)
proj.set_collision_mask_value(3, true)
proj.set_collision_mask_value(6, true)

# In spell_projectile._on_area_entered():
if area.get_collision_layer_value(6):
    var sum = get_node_or_null("/root/SummonManager")
    if sum != null:
        sum.take_summon_damage(damage)
    queue_free()
    return
```
**Notes:** Summon hurtbox is on Layer 6. Shooter projectiles previously used raw integer mask `3` which only set bits 1 and 2, not bit 3 (player hurtbox). Always use set_collision_mask_value() for clarity.

---

### Next Session — 2.43 Spec Editor Tome Integration
**Date:** 2026-04-10
**Planned:** Embed tome page navigator directly inside spec editor. Remove separate Tome view. Spec editor becomes single unified screen: spec metadata + inline page navigator (prev/next) + page spell rows + mana allocation. Craft button pushes to page_editor_view, Back returns to spec editor.

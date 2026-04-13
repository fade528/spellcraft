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

## current status
**Session 2.48 complete:** Deferred Passives Part 2 implemented and verified.

**What was delivered in 2.48:**
- killfuel (A0005): per-physics-frame deduped CD cut on kill. One-shot timer fix applied.
- overheat (A0006): N-cast threshold fires delayed boosted shot. Badge shows while pending.
- bloodpower (G0004): HP-pct damage amp via PassiveManager.get_bloodpower_amp()
- soulsiphon (G0005): rearchitected to all 7 delivery types via PassiveManager leech
- dispel registration (F0006): wired but inert until enemies apply debuffs to player
- Burn stacking: additive _burn_damage, duration reset on reapply
- CD timer: one_shot=true architecture, wait_time corruption eliminated
- Dynamic stagger: active-casters-only even distribution in player._refresh_all_casters()
- Control strip: 4-slot CD row with colour bars
- Enemy debuff flash colours on hit
- Player green flash on any heal source

**Known outstanding:**
- Summon requires spell_elements.csv A0007 Status="active" to appear
- Utility delivery = self-target, not yet implemented
- Chaser to be rebuilt as Chaser2
- soulsiphon legacy arm still in all delivery _apply_on_hit_effects() — remove next session
- dispel registration inert until enemy-on-player debuffs exist
- Milestone bonuses not implemented
- get_school_multiplier() 0.05/tier vs design 0.02/count — needs alignment

**Next:** Session 2.49 — TBD

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
SpecManager.apply_spec(spec_name: String) -> void
SpecManager.clear_spec() -> void
SpecManager.get_active_spec() -> SpecData
SpecManager.get_active_spec_name() -> String
SpecManager.is_archmage() -> bool
SpecManager.allocate_mana_for_pickup(amount: int) -> void
SpecManager.allocate_remaining_by_spec() -> void
SpecManager.allocate_all_by_spec() -> void
SpecManager.get_all_spec_names() -> Array[String]
SpecManager.save_spec_from_dict(name, data) -> void
SpecManager.delete_custom_spec(name) -> void
SpecManager.save_archmage_as_spec(new_name) -> void
```
**Notes:** SPEC_PATHS const maps built-in names to .tres paths. Custom specs stored in _custom_specs dict, persisted to user://specs.json.

---

### Per-Spec Tome Architecture (Session 2.42)
**Date:** 2026-04-10
**Decision:** Each spec owns its own set of pages (up to 8). Switching specs saves current pages and loads the new spec's pages. Archmage has its own pages too.

**Save files:** `user://pages_{spec_name_lowercase}.json`

**TomeManager API additions:**
```gdscript
TomeManager.load_for_spec(spec_name: String, preferred_slots: Array = []) -> void
TomeManager.reset_to_default(preferred_slots: Array = []) -> void
TomeManager._save_path_for(spec_name: String) -> String
TomeManager._generate_default_pages(preferred_slots: Array) -> void
```
**Notes:** On first open of a spec with no save file, default pages generated from preferred_slots. Old user://tome_pages.json is obsolete.

---

### Page Flip Gate Change (Session 2.42)
**Date:** 2026-04-10
**Decision:** Removed summon recharge check from can_flip_page(). Page flips gated by spell cooldown only. Summon spawn inside flip_to_page() still guarded by is_recharged().
**Notes:** can_flip_page() now only checks _flip_cooldown > 0.

---

### CraftingUI Architecture (Session 2.42 / 2.43)
**Date:** 2026-04-10
**Decision:** Full redesign. Single Spec tab. All UI built in code — no .tscn changes. Session 2.43 removed separate Tome view — embedded inline.

**Flow:** Spec list → Spec editor (Name + PAGES inline + Mana & Ratios) → Back

**Key patterns:**
- `enum TabView { SPEC_LIST, SPEC_EDITOR, TOME_LIST, PAGE_EDITOR }`
- `_spec_editor_page_index` tracks page in navigator
- `_repopulate_page_section()` rebuilds only page section on prev/next
- Save spec builds preferred_slots from page 0 of TomeManager

---

### Mana Allocation Philosophy (Session 2.42)
**Date:** 2026-04-10
**Decision:** All mana orb pickups bank to unallocated_mana. Player manually allocates via +/- or % buttons. Three actions: Reset Allocation, Alloc Remaining %, Alloc All %.

---

### Shooter Projectile Collision Fix (Session 2.42)
**Date:** 2026-04-10
```gdscript
proj.set_collision_layer_value(5, true)
proj.set_collision_mask_value(3, true)
proj.set_collision_mask_value(6, true)
```
**Notes:** Always use set_collision_mask_value() — never raw integer mask.

---

### Menu Button (Session 2.43)
**Date:** 2026-04-11
**Decision:** Leftmost action button wired as Menu toggle (open/close CraftingUI).
**Implementation:** ControlStrip emits menu_button_pressed. Hit detection via _input() with dynamic rect scaling. Debounce 0.3s. ESC key also triggers.

---

### Android Export — Non-Resource File Inclusion (Session 2.43)
**Date:** 2026-04-11
**Decision:** CSV files must be included via include_filter in export preset.
**Implementation:** include_filter="data/*"
**Notes:** FileAccess.open("res://...") works on Android only if file is packed into PCK.

---

### Spell Scaling Foundation (Session 2.44)
**Date:** 2026-04-11
**Decision:** Full scaling pipeline across SpellComposer, SpellCaster, SpellProjectile.
- spell_elements.csv: ScaleValue1-5, ScaleDmgmult, Status columns. Only Status="active" rows loaded.
- SpellComposer embeds tier into each on_hit_effect dict at compose time.
- SpellCaster reads get_school_multiplier() at fire time.
- SpellProjectile._scaled() reads tier from effect dict.

---

### Delivery System (Session 2.45)
**Date:** 2026-04-12
**Decision:** All 7 delivery types as separate scenes under res://scenes/deliveries/.

- bolt.gd: Area2D, layer 5, mask 4. Direction tracking. Absorb on hit.
- burst.gd: 5 instances at ±20/±10/0° offsets, 0.75x damage each.
- missile.gd: homing, 120 deg/s turn, 400px/s, call_deferred queue_free.
- beam.gd: instant vertical hit scan 40px wide. ColorRect visual 1s fade.
- aoe.gd (blast): instant 300px radial. Polygon2D circle, 0.5s fade.
- cleave.gd: instant 600px cone, 45° half-angle. Polygon2D sector, 0.3s fade.
- orbs.gd: 3 persistent Area2D orbs orbit at 85px, 90°/s, 1 hit/cycle/orb.

**Notes:**
- instant-hit deliveries call _execute_hit() at end of setup_from_spell(), NOT in _ready()
- blast/cleave: add_child BEFORE setup_from_spell so _ready() draws polygon at origin first
- All delivery scripts share identical _apply_on_hit_effects(), _scaled(), _apply_aoe()

---

### Session 2.46b — Spell Effects Testing + Debug Pass
**Date:** 2026-04-13

- on_hit_effects must use `duplicate(true)` in setup_from_spell() in all delivery scripts
- PassiveManager.recalculate() no longer resets _iceshield_still_timer
- apply_slow() sets _is_chilled = true — enables brittle
- apply_pushback() uses raw distance value (not divided)
- Knockback guard in _physics_process() via _knockback_timer
- SpellCaster stores _cd_reduction: float, applied in _configure_cooldown_timer()
- ProgressionManager.heal(amount) added
- CSVs must be imported as plain text, not translation resources

---

### Session 2.47 — Deferred Passives Part 1
**Date:** 2026-04-13

**PassiveManager — three passive buckets**
- `_active_passives` — cd_type=passive, target=self
- `_active_cast_passives` — cd_type=cast, target=self
- `_active_enemy_passives` — cd_type=passive, target=enemy

**New APIs:**
```gdscript
# ProgressionManager
register_debuff(name: String) -> void
remove_debuffs(count: int) -> Array[String]

# SummonManager
heal_summon(amount: float) -> void
get_summon_max_hp() -> float
clear_debuffs() -> void   # no-op hook

# PassiveManager
get_damage_amp() -> float   # rootedpower amp
```

**Passives implemented:**
- holylight (F0005): stand 3.5s → heal player + summon for value2 * max_hp
- dispel (F0006): stand 1s → remove value1 debuffs from player/summon
- rootedpower (C0002): stand still → damage amp via get_damage_amp()
- consecration (F0004): verified working

**Purge vs Dispel:** Thunder Purge removes enemy buffs. Holy Dispel removes player debuffs. Separate systems.

---

### Session 2.48 — Deferred Passives Part 2 + CD Timer Fix
**Date:** 2026-04-14

### killfuel (A0005)
**Decision:** On enemy death, shooter.gd and tank.gd call PassiveManager.on_enemy_killed() before _spawn_death_particles(). PassiveManager searches _active_passives for killfuel and calls apply_cd_reduction_instant(cd_cut) on all spell_casters group members.
**Implementation:**
```gdscript
func apply_cd_reduction_instant(seconds: float) -> void:
    if cooldown_timer == null or cooldown_timer.is_stopped():
        return
    var full_cd := maxf(spell_data.cooldown - _cd_reduction, 1.5) if spell_data != null else 1.5
    var new_time := maxf(cooldown_timer.time_left - seconds, 0.1)
    cooldown_timer.wait_time = full_cd
    cooldown_timer.stop()
    cooldown_timer.start(new_time)
```
**Notes:** Cuts time_left on current cycle only. wait_time reset to full_cd ensures next cycle is correct. Per-physics-frame dedup via `_killfuel_last_physics_frame: int` prevents multi-kill AoE stacking. Uses Engine.get_physics_frames() not get_process_frames() — all kill callbacks are physics-frame events.

### CD Timer Architecture Fix (critical — Session 2.48)
**Decision:** SpellCaster.cooldown_timer changed from one_shot=false to one_shot=true.
**Reason:** one_shot=false caused wait_time corruption — when stop()/start(new_time) was called by killfuel, Godot stored new_time as the new wait_time, so the next natural cycle looped at the reduced time instead of full_cd. Confirmed via debug output showing wait_time degrading across successive kills.
**Implementation:** _on_cooldown_timer_timeout() manually restarts at full_cd after firing:
```gdscript
# At end of _on_cooldown_timer_timeout(), after _spawn_delivery():
var full_cd := maxf(spell_data.cooldown - _cd_reduction, 1.5) if spell_data != null else 1.5
cooldown_timer.wait_time = full_cd
cooldown_timer.start()
```
**Notes:** Never set one_shot=false on cooldown_timer. Always restart manually.

### overheat (A0006)
**Decision:** SpellCaster tracks _cast_count and _overheat_ready. _check_overheat() increments count on every fire. On threshold, sets _overheat_amp and _overheat_ready=true. On next fire, a 0.3s deferred timer spawns a second delivery at amplified damage, then resets both flags.
**Notes:** Boosted shot fires 0.3s after normal shot — visually distinct. Badge in buff row shows only while _overheat_ready=true. ControlStrip reads _overheat_ready from each SpellCaster child.

### bloodpower (G0004)
**Decision:** PassiveManager.get_bloodpower_amp() reads from _active_cast_passives. Computes hp_pct from ProgressionManager. Returns amp_low below threshold_low, amp_medium between thresholds, 0.0 above threshold_high. Called in both SpellCaster fire paths after get_damage_amp().

### soulsiphon (G0005) — rearchitecture
**Decision:** Removed soulsiphon from spell_projectile._apply_on_hit_effects(). PassiveManager.get_soulsiphon_leech() reads from _active_cast_passives. All 7 delivery scripts call leech after every enemy.take_damage().
**Notes:** Legacy soulsiphon arm still present in _apply_on_hit_effects() in all 7 delivery scripts as of session close — remove in 2.49 to prevent double-heal.

### Burn Stacking (Session 2.48)
**Decision:** apply_burn() in shooter.gd and tank.gd stacks additively. On reapplication while burn timer active: _burn_damage += dmg_per_tick, tick count resets to full duration. Fresh applications behave as before.
**Notes:** Stacking is unbounded — partner to tune dmg_per_tick values if accumulation becomes excessive.

### Dynamic Stagger Spacing (Session 2.48)
**Decision:** _refresh_all_casters() in player.gd now distributes stagger evenly across only actively firing casters. Excludes empty elemental, utility delivery, and stop-cast slots.
**Implementation:** interval = min_cd / active_count, floored at 0.5s. Stagger = i * interval.
**Reason:** Fixed 1s offsets wasted time gaps when fewer than 4 slots were active.

### Control Strip — 4-slot CD Row (Session 2.48)
**Decision:** spell_cd_label hidden. Replaced with 4 slot CD labels + colour bars built in _build_slot_cd_row(). Each slot shows S# RDY (green) or S# X.Xs (white) with fill bar red→yellow→green. Utility and empty slots show S# —. Updated every _process frame in _refresh_spell_cd().

### Enemy Debuff Flash Colours (Session 2.48)
**Decision:** _flash_debuff_colour(colour: Color) added to shooter.gd and tank.gd. Called from each apply_* method on application. Reuses hit_flash_tween. Holds debuff colour briefly before returning to base.
**Colours:** burn=orange, corrupt=purple, wet=dark blue, chill/slow=light blue, blind=white.

### Player Heal Flash (Session 2.48)
**Decision:** Player.flash_heal() flashes self.modulate green. Called from ProgressionManager.heal() — covers all heal sources (soulsiphon, holylight, flowstate, consecration).
**Notes:** Flashes self not player_sprite.modulate — avoids conflict with iframe alpha tween which animates children's modulate.a independently.

### Buff Badge Debuff Pulsing (Session 2.48)
**Decision:** Debuff badges in ControlStrip buff row pulse via looping tween on modulate.a (1.0 → 0.25 → 1.0 at 0.35s per phase). DEBUFF_FLASH_COLOURS const maps effect_name to Color. Passives without a flash colour entry remain static.

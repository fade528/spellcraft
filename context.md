# Spellcraft Roguelite — Master Context

> Read this first. This file gives you everything needed to assist on this project without reading all other docs.

---

## What This Project Is

A mobile-first 2D roguelite where players craft spells through element combinations, learn through experimentation, and prove mastery through boss fights. Built for Android/iOS in portrait mode.

**Core loop:** Fight → Collect → Craft → Adapt → Boss → Learn → Repeat

**Design philosophy:** Progression driven by understanding, not grinding. No stat inflation. No random powerup dependency. Player agency through knowledge of the spell system.

---

## The Team

**David** — Technical Lead
- SAP Solution Architect by profession, moderate coder
- Using Godot 4 + GDScript for the first time
- Stack: Godot 4, VS Code, Codex (AI agent), Git
- Handles: all code, architecture, scene structure, Git

**Partner** — Gameplay Lead
- Non-technical, strong gameplay instinct
- Handles: feel decisions, spell combo design, enemy tuning, playtesting, feedback.md, design.md updates

---

## Tech Stack

Engine:        Godot 4.6.2 stable
Language:      GDScript (always specify "Godot 4 GDScript" in prompts)
Editor:        VS Code + godot-tools extension
AI Agent:      Codex (in VS Code)
Version ctrl:  Git + GitHub (github.com/fade528/spellcraft)
Platform:      Android + iOS, portrait 1080x1920
Renderer:      Mobile

**Critical:** Always write Godot 4 GDScript, never Godot 3. Key differences: `@export`, `@onready`, `CharacterBody2D` (not KinematicBody2D), `velocity` not `move_and_slide(velocity)`.

---

## Current Status

Phase 2 in progress. Phase 1 (Alpha) is complete — game is playable, APK tested on device.

**Session 2.41 complete:** Mana economy replacing element drops. All drops are now generic mana orbs. Mana pools in PlayerInventory, school gating in SpellCaster, SpecData resources, SpecManager autoload with auto-allocation. CraftingUI Schools tab + full Spec UI deferred to Session 2.42.

**Next:** Session 2.42 — CraftingUI redesign. Spec-first two-tab layout (Spec / Tome). Full spec editor with spell slots, school swatches, ult pickers. JSON persistence for specs. Tome page override flag.

**Known bugs to fix in Session 2.42:**
1. Spell casting stops when summon dies — likely SummonManager signal or set_attack_spell(null) propagating incorrectly
2. Page flip respawns summon when it shouldn't — PageFlipWidget or TomeManager not checking summon recharge state

---

## Architecture Decisions

### Safe Node Access Pattern
**All scripts use `get_node_or_null("/root/NodeName")` to access autoloads.** Never use bare global autoload names. This is a project-wide rule due to a UID resolution issue with VS Code external editing.

```gdscript
# CORRECT
var pm = get_node_or_null("/root/ProgressionManager")
if pm:
    pm.take_damage(10)

# WRONG — do not use
ProgressionManager.take_damage(10)
```

### Autoload Registration
Autoloads must be registered manually via Godot editor UI (Project → Project Settings → Globals → Autoload). Always type paths manually — never use the folder browser, it generates UID references that fail to resolve.

**Autoload order (critical — do not change):**
```
ProgressionManager   res://scripts/progression_manager.gd
PlayerInventory      res://scripts/managers/player_inventory.gd
SpellComposer        res://scripts/managers/spell_composer.gd
SummonManager        res://scripts/managers/summon_manager.gd
TomeManager          res://scripts/managers/tome_manager.gd
SpecManager          res://scripts/spec_manager.gd
```

### Scene Structure (actual as built)

```
Game (scene) — res://scenes/game.tscn
├── ScrollingBackground
│   ├── BackgroundA (ColorRect)
│   └── BackgroundB (ColorRect)
├── Player (scene) — res://scenes/player.tscn
│   └── SpellCaster (Node2D)
│       └── CooldownTimer (Timer)
├── Camera2D
├── Projectiles (Node2D) — projectile container, group: "projectile_container"
├── SpellHitSFX (AudioStreamPlayer)
├── PlayerHurtSFX (AudioStreamPlayer)
├── EnemyDeathSFX (AudioStreamPlayer)
├── BGMusic (AudioStreamPlayer)
├── EnemySpawner (Node2D)
│   └── SpawnTimer (Timer)
├── HUD (CanvasLayer) — MarginContainer hidden (visible=false)
│   └── PageFlipWidget (Control)
├── CraftingUI (CanvasLayer)
└── ControlStrip (CanvasLayer)
    ├── StripPanel (ColorRect) — bottom 20% (y=1536, h=384)
    │   ├── ActivePageLabel
    │   ├── SpellCDLabel
    │   └── SummonLabel
    ├── ActionButtonLayer (Control) — y=1400, 4 placeholder buttons
    └── BossBarContainer (Control) — y=0, hidden until Session 3.x

Enemy scenes:
res://scenes/enemy.tscn       — Chaser
res://scenes/enemies/shooter.tscn
res://scenes/enemies/tank.tscn

Data files:
res://data/spell_elements.csv
res://data/specs/pyroclast.tres
res://data/specs/frostbinder.tres
res://data/specs/archmage.tres
```

### Input Zone Map (bottom 20% control strip)

```
Left  0-10%   → page flip gesture trigger only
Mid  10-90%   → touchpad (player movement) only
Right 90-100% → page flip gesture trigger only
```

### Player Input Architecture
- `player.gd` uses `_input()` — runs first, sees all events
- `page_flip_widget.gd` uses `_input()` — zone-guarded, only acts on edge zone presses
- Neither calls `set_input_as_handled()` — events are read-only, never consumed
- Touchpad activates only in strip zone (y >= 80%) and mid x zone (10-90%)
- Player clamps to top 80% of viewport (dynamic viewport size)
- RESPAWN_POSITION = Vector2(540, 1400)

### UI Layout (current as built)

```
┌─────────────────────────┐
│  Boss HP bar (reserved) │  ← Session 3.x, hidden
├─────────────────────────┤
│                         │
│    GAME AREA            │
│                         │
├─────────────────────────┤  ← y=1400
│  [btn][btn][btn][btn]   │  ← 4 reserved action buttons (canvas layer)
├─────────────────────────┤  ← y=1536 (80%)
│  HP bar  ❤❤❤            │  ← in control strip
│  page / CD / summon     │
│  school swatches T0-Tn  │  ← mana display row
│  Mana: X | Free: X      │
│  [   touchpad   ]       │
└─────────────────────────┘  ← y=1920
```

The old HUD MarginContainer is hidden. HP/lives now live in ControlStrip.
ControlStrip exposes: `update_hp(current, maximum)` and `update_lives(count)`.

### Signal Flow Rule
- Signals travel **upward** (child → parent/manager)
- Direct calls travel **downward** (manager → child)
- GameManager is coordinator only — thin orchestrator, does not implement domain logic
- Domain managers own their logic: SpellComposer, PlayerInventory, SummonManager, TomeManager, ProgressionManager, SpecManager

### Collision Layers

```
Layer 1 — Player physical body
Layer 2 — Enemy physical body
Layer 3 — Player hurtbox (Area2D)
Layer 4 — Enemy hurtbox (Area2D)
Layer 5 — Spell projectiles (Area2D)
Layer 6 — Mana drops (Area2D)
Layer 7 — Screen boundaries
```

### Data Pattern
- **CSV files** = master spell data. `res://data/spell_elements.csv` — edited in Google Sheets only, never by Codex.
- **Resources (.tres)** = other master data (spec definitions, enemy stats, level configs). Stored in `res://data/specs/`.
- **Node variables** = runtime state (current HP, cooldown timers).
- Always `duplicate()` resources before modifying per-instance values.

### Game States

```gdscript
enum GameState {
    SCROLLING,
    BOSS_PREP,
    BOSS_FIGHT,
    BOSS_METRICS,
    GAME_OVER
}
```

---

## Key Systems Summary

### Spell System (Session 2.1 — complete)

Each spell is composed from 3 element slots + delivery:

| Slot | Purpose |
|---|---|
| Elemental | Core identity, sets inherent dmgmult |
| Empowerment | Damage amplification (DoT, chains, execute) |
| Enchantment | Functions and gimmicks (AoE, pushback, status) |

Delivery types: Bolt, Burst, Beam, Blast, Cleave, Missile, Wall, Utility

SpellData resource fields: `damage, cooldown, total_cd, dmgmult_chain, total_budget, projectile_speed, effects[]`

```gdscript
SpellComposer.compose_spell(elemental, empowerment, enchantment, delivery, target) -> SpellData
SpellComposer.is_stop_cast(element) -> bool
SpellComposer.get_weakness_multiplier(attacker, defender) -> float
```

Holy/Dark = stop-cast elements (fire on movement stop, not auto-cast).

### Mana and School System (Session 2.41 — complete)

All enemy drops are generic mana orbs (light blue ColorRect). No element-coloured drops.

**PlayerInventory mana API:**
```gdscript
PlayerInventory.add_mana(amount: int) -> void           # delegates to SpecManager.allocate_mana_for_pickup
PlayerInventory.allocate_to_school(school, amount) -> void
PlayerInventory.deallocate_from_school(school, amount) -> void
PlayerInventory.get_school_tier(school: String) -> int
PlayerInventory.get_school_multiplier(school: String) -> float
# Fields: mana_pool: int, school_allocation: Dictionary, unallocated_mana: int
```

**School gating:** SpellCaster checks `get_school_tier(elemental_element) == 0` at the top of `_on_cooldown_timer_timeout()`. If zero, spell is silently skipped (timer keeps running).

**SpecManager API:**
```gdscript
SpecManager.apply_spec(spec_name: String) -> void
SpecManager.clear_spec() -> void                        # Archmage mode
SpecManager.get_active_spec() -> SpecData
SpecManager.get_active_spec_name() -> String
SpecManager.is_archmage() -> bool
SpecManager.allocate_mana_for_pickup(amount: int) -> void
```

**Auto-allocation:** On mana pickup, SpecManager distributes per `allocation_ratios` in the active spec. Remainder (from floor rounding) goes to `unallocated_mana`. Archmage mode sends all to `unallocated_mana`.

**SpecData resource:**
```gdscript
class_name SpecData extends Resource
@export var spec_name: String
@export var description: String
@export var allocation_ratios: Dictionary    # {"fire": 0.6, "thunder": 0.4}
@export var preferred_slots: Array[Dictionary]  # [{elemental, empowerment, enchantment, delivery}]
@export var preferred_ults: Array[String]
```

Spec files: `res://data/specs/pyroclast.tres`, `frostbinder.tres`, `archmage.tres`

**ControlStrip mana display:** 7 school swatches showing TN tier, plus "Mana: X | Free: X" label. Updates every frame from PlayerInventory.

### Tome and Page System (Session 2.2 — complete)

Players hold a Tome with up to 8 Pages. Each Page = 4 spell slots + 1 summon + 2 ultimates. Pages saved to disk, persist across runs and restarts.

**Page flip gesture:** press left 0-10% or right 90-100% of control strip → 3x3 grid appears → drag direction selects page → release confirms.

**Escape menu (CraftingUI):** full crafting workshop. Pauses game. Edit slot 0 elements.

```gdscript
TomeManager.flip_to_page(index: int) -> void
TomeManager.can_flip_page(target_index: int = -1) -> bool
TomeManager.save_page(index: int, page: PageData) -> void
TomeManager.get_page(index: int) -> PageData
TomeManager.get_active_page() -> PageData
TomeManager.add_page() -> void
TomeManager.delete_page(index: int) -> void
TomeManager.rename_page(index: int, new_name: String) -> void
CraftingUI.open_ui() -> void
CraftingUI.close_ui() -> void
```

**PageData resource:**
```gdscript
class_name PageData extends Resource
@export var page_name: String
@export var slots: Array[Dictionary]  # {elemental, empowerment, enchantment, delivery, target}
@export var summon_element: String
@export var ult1: String
@export var ult2: String
func ensure_slots(count: int = 4) -> void
static func make_default_slot() -> Dictionary
```

### CraftingUI Redesign (Session 2.42 — PENDING)

Two-tab layout planned: **Spec** (default) / **Tome**.

**Spec tab:**
- Up to 5 spec slots + Archmage always present
- Each row: name, Activate, Edit, Delete (Archmage not deletable)
- Inner editor: 4 spell rows (elemental/empowerment/enchantment/delivery), summon picker, 2 ult pickers, school swatches (+/-), mana summary
- JSON persistence for specs

**Tome tab:**
- Page list with override flag indicator (spec-driven vs manually edited)
- Setting a page active resets override flag
- School swatches visible for Archmage mode manual allocation

### Summon System (Session 2.3 — complete)

```gdscript
SummonManager.spawn_summon(element: String) -> void
SummonManager.despawn_summon() -> void
SummonManager.set_attack_spell(spell: SpellData) -> void
SummonManager.get_summon_stat(key: String) -> Variant
SummonManager.is_recharged() -> bool
SummonManager.get_recharge_remaining() -> float
```

### Enemy System (Session 2.3 — complete)

Three enemy types, all with full status effect suite. All spawn_drop() calls use `call_deferred("add_child", drop)` — required for physics callback safety.

**Status effects:** apply_burn, apply_slow, apply_stagger, apply_brittle, apply_chain, apply_pushback, apply_blind, execute, apply_wet, apply_corruption, apply_chill, get_element, get_incoming_multiplier

### Control Strip (Sessions 2.2–2.41 — complete)

```gdscript
ControlStrip.update_hp(current: float, maximum: float) -> void
ControlStrip.update_lives(count: int) -> void
ControlStrip.update_mana_display() -> void   # called every frame from _process
```

### Life System (Session 1.4 — complete)

```gdscript
get_node_or_null("/root/ProgressionManager").take_damage(amount)
get_node_or_null("/root/ProgressionManager").heal(amount)
get_node_or_null("/root/ProgressionManager").reset_run()
```

### Item System (Phase 4 — stub only)
5 equipment slots: Hat, Robe, Gloves, Boots, Weapon. Slots stubbed in PlayerInventory. Drop from bosses only.

---

## Enemy Types (MVP)
1. **Chaser** — follows player, pressure movement, contact damage ✅
2. **Shooter** — fires projectiles at player, forces dodging ✅
3. **Tank** — slow, high HP, blocks progression ✅

---

## Sprite Approach
- All placeholder coloured rectangles for now
- Player: orange triangle
- Enemies: red (Chaser), dark red (Tank), purple (Shooter)
- Summon: yellow rectangle
- Mana orb: light blue ColorRect 16×16, Color(0.6, 0.8, 1.0)
- Final sprites: Phase 4 art pass

---

## Folder Structure

```
res://
├── data/
│   ├── spell_elements.csv
│   └── specs/
│       ├── pyroclast.tres
│       ├── frostbinder.tres
│       └── archmage.tres
├── scenes/
│   ├── game.tscn
│   ├── player.tscn
│   ├── spell_projectile.tscn
│   ├── enemy.tscn
│   ├── enemies/
│   │   ├── shooter.tscn
│   │   └── tank.tscn
│   ├── element_drop.tscn      ← now mana_drop (scene reused, script replaced)
│   ├── ui/
│   │   ├── crafting_ui.tscn
│   │   ├── PageFlipWidget.tscn
│   │   └── control_strip.tscn
│   └── boss/
├── scripts/
│   ├── element_drop.gd        ← now generic mana orb
│   ├── spec_data.gd           ← NEW Session 2.41
│   ├── spec_manager.gd        ← NEW Session 2.41
│   ├── managers/
│   │   ├── spell_composer.gd
│   │   ├── player_inventory.gd
│   │   ├── summon_manager.gd
│   │   └── tome_manager.gd
│   ├── ui/
│   │   ├── crafting_ui.gd
│   │   ├── page_flip_widget.gd
│   │   └── control_strip.gd
│   ├── enemies/
│   │   ├── enemy.gd
│   │   ├── shooter.gd
│   │   └── tank.gd
│   └── spells/
│       ├── spell_data.gd
│       ├── spell_caster.gd
│       └── spell_projectile.gd
├── resources/
└── assets/
```

---

## Codex Prompt Rules
1. Always start prompts with "Godot 4 GDScript"
2. Always paste relevant existing code as context
3. Always paste scene tree when asking for node-specific code
4. Use `get_node_or_null("/root/NodeName")` — never bare autoload globals
5. Verify output uses Godot 4 syntax before accepting
6. Never modify `res://data/spell_elements.csv` — read only
7. Never rewrite .tscn files — UID references break. Edit scripts only, make scene changes in Godot editor.
8. Use `mini()` not `min()` when comparing two ints — avoids Variant inference errors
9. Use `call_deferred("queue_free")` not `queue_free()` inside physics callbacks
10. Use `call_deferred("add_child", node)` not `add_child(node)` inside physics callbacks

---

## Files in This Project Root
- `context.md` — this file, read first every session
- `design.md` — full game design document
- `systems.md` — technical decisions log
- `session_plan.md` — all session prompts and status tracker
- `feedback.md` — partner playtesting notes
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

**Session 2.43 complete:** CraftingUI unified spec editor. Menu button. 
Android export CSV fix.

**What was delivered in 2.43:**
- CraftingUI: Removed separate Tome view — single unified spec+page editor screen
- Inline page navigator (prev/next, add/remove) inside spec editor
- Slot 1 live-editable with auto-save on change, live SpellCaster refresh
- Summon and Ult 1/2 live pickers with save on change
- Mana & Ratios section: ratio inputs for named specs, hidden for Archmage
- % allocation reads ratio inputs directly — works for non-active specs
- Menu button: leftmost action button opens/closes CraftingUI on desktop + Android
- Android: CSV files now correctly packed via include_filter="data/*" in export preset
- Bug fix: % allocation buttons incorrectly greyed when editing non-active named spec

**Next:** Session 2.44 — Partner playtesting feedback integration

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

Save files (user data — generated at runtime):
user://specs.json              — custom spec definitions
user://pages_archmage.json     — Archmage tome pages
user://pages_pyroclast.json    — Pyroclast tome pages
user://pages_frostbinder.json  — Frostbinder tome pages
user://pages_{custom}.json     — one file per custom spec
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
Layer 6 — Mana drops (Area2D) / Summon hurtbox (Area2D)
Layer 7 — Screen boundaries
```

**Note:** Layer 6 is shared between mana drops and summon hurtbox. Shooter projectiles use mask 3 (player) + mask 6 (summon). Player spells use mask 4 (enemy). Summon hurtbox hit routes to SummonManager.take_summon_damage().

### Data Pattern
- **CSV files** = master spell data. `res://data/spell_elements.csv` — edited in Google Sheets only, never by Codex.
- **Resources (.tres)** = other master data (spec definitions, enemy stats, level configs). Stored in `res://data/specs/`.
- **Node variables** = runtime state (current HP, cooldown timers).
- **JSON files** = player save data. user://specs.json (custom specs), user://pages_{spec}.json (per-spec tome pages).
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

```gdscript
SpellComposer.compose_spell(elemental, empowerment, enchantment, delivery, target) -> SpellData
SpellComposer.is_stop_cast(element) -> bool
SpellComposer.get_weakness_multiplier(attacker, defender) -> float
```

Holy/Dark = stop-cast elements (fire on movement stop, not auto-cast).

### Mana and School System (Sessions 2.41 / 2.42 — complete)

All enemy drops are generic mana orbs (light blue ColorRect). No element-coloured drops.

**PlayerInventory mana API:**
```gdscript
PlayerInventory.add_mana(amount: int) -> void           # banks to unallocated_mana via SpecManager
PlayerInventory.allocate_to_school(school, amount) -> void
PlayerInventory.deallocate_from_school(school, amount) -> void
PlayerInventory.get_school_tier(school: String) -> int
PlayerInventory.get_school_multiplier(school: String) -> float
# Fields: mana_pool: int, school_allocation: Dictionary, unallocated_mana: int
```

**School gating:** SpellCaster checks `not school_allocation.is_empty() and get_school_tier(elemental_element) == 0`. Gate only activates once player has made at least one allocation. Timer only restarts if stopped (prevents rapid-fire on page flip).

**SpecManager API:**
```gdscript
SpecManager.apply_spec(spec_name: String) -> void        # activates spec + loads its tome
SpecManager.clear_spec() -> void                          # Archmage mode
SpecManager.get_active_spec() -> SpecData
SpecManager.get_active_spec_name() -> String
SpecManager.is_archmage() -> bool
SpecManager.allocate_mana_for_pickup(amount: int) -> void # banks all to unallocated_mana
SpecManager.allocate_remaining_by_spec() -> void
SpecManager.allocate_all_by_spec() -> void
SpecManager.get_all_spec_names() -> Array[String]
SpecManager.save_spec_from_dict(name, data) -> void
SpecManager.delete_custom_spec(name) -> void
SpecManager.save_archmage_as_spec(new_name) -> void
```

**Mana allocation:** All pickups bank to unallocated_mana. Player allocates manually via UI. Three actions: Reset Allocation, Alloc Remaining %, Alloc All %.

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

### Tome and Page System (Sessions 2.2 / 2.42 — complete)

Each spec owns its own Tome (up to 8 pages). Switching specs saves current pages and loads the new spec's pages. Save files: `user://pages_{spec_name}.json`.

**PageData:**
```gdscript
class_name PageData extends Resource
@export var page_name: String
@export var slots: Array[Dictionary]   # {elemental, empowerment, enchantment, delivery, target}
@export var summon_element: String
@export var ult1: String
@export var ult2: String
@export var is_overridden: bool = false  # true = manually edited, false = spec-driven
func ensure_slots(count: int = 4) -> void
static func make_default_slot() -> Dictionary
```

**TomeManager API:**
```gdscript
TomeManager.load_for_spec(spec_name: String, preferred_slots: Array = []) -> void
TomeManager.reset_to_default(preferred_slots: Array = []) -> void
TomeManager.flip_to_page(index: int) -> void
TomeManager.can_flip_page(target_index: int = -1) -> bool  # only checks spell cooldown now
TomeManager.save_page(index: int, page: PageData) -> void
TomeManager.get_page(index: int) -> PageData
TomeManager.get_active_page() -> PageData
TomeManager.add_page() -> void
TomeManager.delete_page(index: int) -> void
TomeManager.rename_page(index: int, new_name: String) -> void
TomeManager.reset_override_flags() -> void
```

**Page flip gate:** Only spell cooldown (_flip_cooldown). Summon recharge no longer blocks flips — summon respawn is skipped during recharge but flip is allowed.

**Page override indicator:** `~ ` prefix = spec-driven (is_overridden=false), `* ` prefix = manually edited (is_overridden=true).

**CraftingUI:**
```gdscript
CraftingUI.open_ui() -> void
CraftingUI.close_ui() -> void

```

### CraftingUI (Session 2.42 — complete)

Single Spec tab. All UI built in code, no .tscn changes. Spec list → Spec editor → Tome view → Page editor flow.

**Spec slots:** Archmage (always top) | Built-in 1-5 (Activate/Edit/Reset Spec) | Custom 6-10 (Activate/Edit/Delete) | Resume
**Spec editor:** Back | Go to Tome | Reset Spec (built-ins only) | Name (read-only for built-ins) | Slot pickers | Summon/Ult pickers | Ratio % inputs | Mana Allocation (+/- per school, Reset Allocation, Alloc Remaining %, Alloc All %)
**Tome view:** Per-spec page list with override indicators, summary row, Craft/Activate/Rename/Delete, mana chart with +/- at bottom.

**Next session (2.43):** Embed tome inline in spec editor. Remove separate Tome view. Prev/next page navigator inside spec editor.

### CraftingUI (Session 2.43 — complete)

Single unified screen. No separate Tome view.

**Flow:** Spec list → Spec editor (Name + PAGES inline + Mana & Ratios) 
→ Back to spec list

**Page section:** Prev/Next navigator, page name LineEdit (saves on 
focus_exited), Slot 1 live pickers (save on change), Summon live picker, 
Ult 1/2 live pickers, Save Page button, Activate button.

**Mana & Ratios:** School name labels (always shown), ratio % inputs 
(named specs only), T0/+/- allocation controls, Reset/Alloc Remaining 
%/Alloc All %, Mana summary. Archmage shows hint label instead of % buttons.

### Summon System (Session 2.3 — complete)

```gdscript
SummonManager.spawn_summon(element: String) -> void
SummonManager.despawn_summon() -> void
SummonManager.set_attack_spell(spell: SpellData) -> void
SummonManager.get_summon_stat(key: String) -> Variant
SummonManager.is_recharged() -> bool
SummonManager.get_recharge_remaining() -> float
```

Summon hurtbox on Layer 6. Shooter projectiles now correctly hit summon (mask 6). Damage routed to SummonManager.take_summon_damage().

### Enemy System (Session 2.3 — complete)

Three enemy types, all with full status effect suite. All spawn_drop() calls use `call_deferred("add_child", drop)`.

**Status effects:** apply_burn, apply_slow, apply_stagger, apply_brittle, apply_chain, apply_pushback, apply_blind, execute, apply_wet, apply_corruption, apply_chill, get_element, get_incoming_multiplier

**Shooter projectile fix (Session 2.42):** Shooter enemy projectiles use `set_collision_mask_value(3, true)` and `set_collision_mask_value(6, true)` — never raw integer mask assignment.

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
│   ├── element_drop.tscn
│   ├── ui/
│   │   ├── crafting_ui.tscn
│   │   ├── PageFlipWidget.tscn
│   │   └── control_strip.tscn
│   └── boss/
├── scripts/
│   ├── element_drop.gd
│   ├── spec_data.gd
│   ├── spec_manager.gd
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
11. Never use raw integer collision_mask assignment — always use set_collision_mask_value() for clarity
12. GDScript lambda closures in for loops capture loop variables by reference — use .bind(value) instead

---

## Files in This Project Root
- `context.md` — this file, read first every session
- `design.md` — full game design document
- `systems.md` — technical decisions log
- `session_plan.md` — all session prompts and status tracker
- `feedback.md` — partner playtesting notes


## Session Management
Each working session is a separate chat. Always open with
"Read context.md and systems.md first" then the specific task.
See session_plan.md for the full list of planned sessions.

# Spellcraft Roguelite — Master Context

> Read this first. This file gives you everything needed to assist on this project without reading all other docs.

---

## What This Project Is

A mobile-first 2D roguelite where players craft spells through element combinations, learn through experimentation, and prove mastery through boss fights. Built for Android/iOS in portrait mode.

**Core loop:**Fight → Collect → Craft → Adapt → Boss → Learn → Repeat

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

## Tech StackEngine:        Godot 4.6.2 stable
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

**Completed:** Player movement, enemy spawning, spell auto-cast, life system, HUD, game over, juice pass, audio, APK.

**Session 2.1 complete:** CSV-driven spell combo system built and verified in-engine.

**Session 2.2 complete:** Tome + Page system, CraftingUI pause menu, PageFlipWidget edge-swipe gesture, ControlStrip footer, persistent page save/load, rename/delete/set active pages, input zones finalized.

**Next:** Session 2.3 — Enemy Variants + Status Effects + Summon AI.

---

## Architecture Decisions

### Safe Node Access Pattern
**All scripts use `get_node_or_null("/root/NodeName")` to access autoloads.** Never use bare global autoload names. This is a project-wide rule due to a UID resolution issue with VS Code external editing.

```gdscriptCORRECT
var pm = get_node_or_null("/root/ProgressionManager")
if pm:
pm.take_damage(10)WRONG — do not use
ProgressionManager.take_damage(10)

### Autoload Registration
Autoloads must be registered manually via Godot editor UI (Project → Project Settings → Globals → Autoload). Always type paths manually — never use the folder browser, it generates UID references that fail to resolve.

**Autoload order (critical — do not change):**
ProgressionManager   res://scripts/progression_manager.gd
PlayerInventory      res://scripts/managers/player_inventory.gd
SpellComposer        res://scripts/managers/spell_composer.gd
SummonManager        res://scripts/managers/summon_manager.gd
TomeManager          res://scripts/managers/tome_manager.gd


### Scene Structure (actual as built)Game (scene) — res://scenes/game.tscn
├── ScrollingBackground
│   ├── BackgroundA (ColorRect)
│   └── BackgroundB (ColorRect)
├── Player (scene) — res://scenes/player.tscn
│   └── SpellCaster (Node2D)
│       └── CooldownTimer (Timer)
├── Camera2D
├── Projectiles (Node2D) — projectile container
├── SpellHitSFX (AudioStreamPlayer)
├── PlayerHurtSFX (AudioStreamPlayer)
├── EnemyDeathSFX (AudioStreamPlayer)
├── BGMusic (AudioStreamPlayer)
├── EnemySpawner (Node)
│   └── SpawnTimer (Timer)
├── HUD (CanvasLayer)
│   ├── MarginContainer
│   │   └── VBoxContainer
│   │       ├── HBoxContainer
│   │       │   ├── Life1, Life2, Life3 (ColorRect)
│   │       └── HPRow
│   │           ├── HPBar (ProgressBar)
│   │           └── HPLabel (Label)
│   └── PageFlipWidget (Control)
├── CraftingUI (CanvasLayer)
└── ControlStrip (CanvasLayer)

### Input Zone Map (bottom 20% control strip)Left  0-10%   → page flip gesture trigger only
Mid  10-90%   → touchpad (player movement) only
Right 90-100% → page flip gesture trigger only

### Player Input Architecture
- `player.gd` uses `_input()` — runs first, sees all events
- `page_flip_widget.gd` uses `_input()` — zone-guarded, only acts on edge zone presses
- Neither calls `set_input_as_handled()` — events are read-only, never consumed
- Touchpad activates only in strip zone (y >= 80%) and mid x zone (10-90%)
- Player clamps to top 80% of viewport (dynamic viewport size)
- RESPAWN_POSITION = Vector2(540, 1400)

### UI Layout (current + reserved)┌─────────────────────────┐
│  Boss HP bar (reserved) │  ← Session 3.x
├─────────────────────────┤
│                         │
│    GAME AREA (80%)      │
│                         │
├─────────────────────────┤
│  HP bar + Lives         │  ← move here future session
│  4 action buttons       │  ← reserved Session 4.x
├─────────────────────────┤
│  CONTROL STRIP (20%)    │  ← built Session 2.2
│  touchpad + info        │
└─────────────────────────┘

### Signal Flow Rule
- Signals travel **upward** (child → parent/manager)
- Direct calls travel **downward** (manager → child)
- GameManager is coordinator only — thin orchestrator, does not implement domain logic
- Domain managers own their logic: SpellComposer, PlayerInventory, SummonManager, TomeManager, ProgressionManager

### Collision LayersLayer 1 — Player physical body
Layer 2 — Enemy physical body
Layer 3 — Player hurtbox (Area2D)
Layer 4 — Enemy hurtbox (Area2D)
Layer 5 — Spell projectiles (Area2D)
Layer 6 — Element drops (Area2D)
Layer 7 — Screen boundaries

### Data Pattern
- **CSV files** = master spell data. `res://data/spell_elements.csv` — edited in Google Sheets only, never by Codex.
- **Resources (.tres)** = other master data (enemy stats, level configs).
- **Node variables** = runtime state (current HP, cooldown timers).
- Always `duplicate()` resources before modifying per-instance values.

### Game States
```gdscriptenum GameState {
SCROLLING,
BOSS_PREP,
BOSS_FIGHT,
BOSS_METRICS,
GAME_OVER
}

---

## Key Systems Summary

### Spell System (Session 2.1 — complete)

Each spell is composed from 3 element slots + delivery:

| Slot | Purpose |
|---|---|
| Elemental | Core identity, sets inherent dmgmult |
| Empowerment | Damage amplification (DoT, chains, execute) |
| Enchantment | Functions and gimmicks (AoE, pushback, status) |
| Delivery | How the spell fires (bolt, burst, beam, etc.) |

**7 elements:** Fire, Ice, Earth, Thunder, Water, Holy, Dark

**Damage formula:**final_dmg = item_base_dmg × elemental_dmgmult × weakness_mult × emp_dmgmult × enc_dmgmult × buff_debuff_mult

**All spell data lives in `res://data/spell_elements.csv`** — 49 rows, one per element/position/target combination. SpellComposer parses this on _ready().

**SpellData fields (current):**
```gdscript@export var spell_name: String
@export var elemental_element: String
@export var empowerment_element: String
@export var enchantment_element: String
@export var combo_name: String
@export var total_cd: float
@export var total_budget: float
@export var delivery_type: String
@export var dmgmult_chain: float   # composed multiplier
@export var damage: float          # always 1.0 — use dmgmult_chain
@export var cooldown: float        # = total_cd
@export var projectile_speed: float
@export var on_hit_effects: Array[Dictionary]
@export var self_effects: Array[Dictionary]

**Key APIs:**
```gdscriptSpellComposer.compose_spell(elemental, empowerment, enchantment, delivery, target) -> SpellData
SpellComposer.get_weakness_multiplier(attacker, defender) -> float
SpellComposer.is_stop_cast(element) -> bool  # true for holy/dark
SpellComposer.get_summon_data(element) -> Dictionary
SpellCaster.refresh_spell(elemental, empowerment, enchantment, delivery, target) -> void
PlayerInventory.add_element(element) -> void
PlayerInventory.get_scaling_multiplier(element) -> float  # 1.0 + count * 0.02

**Holy/Dark special:** These elements do NOT auto-cast. They fire the moment the player stops moving, gated by cooldown.

**Weakness wheel:**Fire → Ice → Earth → Thunder → Water → Fire
Holy ↔ Dark
Weakness = ×1.2, Resist = ×0.8, Neutral = ×1.0

### Summon System (Session 2.1 stub — full AI in 2.3)

One summon active at a time, independent of spell slots. All players have a summon. Summons follow the player, mimic slot 1 attacks, have HP and recharge on death.

```gdscriptSummonManager.initialize(player: Node2D) -> void
SummonManager.spawn_summon(element: String) -> void
SummonManager.despawn_summon() -> void
SummonManager.get_summon_stat(key: String) -> Variant
SummonManager.is_recharged() -> bool
SummonManager.get_recharge_remaining() -> float

Summon recharge times: most = 60s, Stormspirit (Thunder) = 20s.

### Tome and Page System (Session 2.2 — complete)

Players hold a Tome with up to 8 Pages. Each Page = 4 spell slots + 1 summon + 2 ultimates. Pages saved to disk, persist across runs and restarts.

**Page flip gesture:** press left 0-10% or right 90-100% of control strip → 3x3 grid appears centre screen → drag into middle zone → direction determines page → release confirms. No pause.

**Escape menu (CraftingUI):** full crafting workshop. Pauses game. Rename, delete, create pages (up to 8). Edit slot 0 elements. Set active page. Stats panel shows live CD, budget, dmgmult.

**Control strip:** bottom 20% of screen always visible. Shows active page name, spell CD, summon recharge status. Touchpad lives here.

```gdscriptTomeManager.flip_to_page(index: int) -> void
TomeManager.can_flip_page(target_index: int = -1) -> bool
TomeManager.save_page(index: int, page: PageData) -> void
TomeManager.get_page(index: int) -> PageData
TomeManager.get_active_page() -> PageData
TomeManager.add_page() -> void
TomeManager.delete_page(index: int) -> void
TomeManager.rename_page(index: int, new_name: String) -> void
CraftingUI.open_ui() -> void
CraftingUI.close_ui() -> void

**PageData resource:**
```gdscriptclass_name PageData extends Resource
@export var page_name: String
@export var slots: Array[Dictionary]  # {elemental, empowerment, enchantment, delivery, target}
@export var summon_element: String
@export var ult1: String
@export var ult2: String
func ensure_slots(count: int = 4) -> void
static func make_default_slot() -> Dictionary

### Life System (Session 1.4 — complete)

ProgressionManager (autoload) owns lives, current_hp, max_hp. 3 lives total. On death: lose 1 life, respawn, screen clears. All 3 lost = game over.

```gdscriptget_node_or_null("/root/ProgressionManager").take_damage(amount)
get_node_or_null("/root/ProgressionManager").heal(amount)
get_node_or_null("/root/ProgressionManager").reset_run()

### Progression
Levels 1-6, unlocked by beating bosses. No stat inflation — unlocks = more spell slots and ultimate. Level 5 = Ultimate unlock. Level 6 = Ultimate upgrade. Summon slot always available.

### Boss System
Scrolling stops → arena forms → Preparation Phase (relearn allowed) → Boss Fight (no relearn, pure execution) → death shows metrics → retry loop.

### Item System (Phase 4 — stub only)
5 equipment slots: Hat, Robe, Gloves, Boots, Weapon. Slots stubbed in PlayerInventory. Drop from bosses only. Weapon provides item_base_dmg which feeds into SpellCaster.

---

## Enemy Types (MVP)
1. **Chaser** — follows player, pressure movement, contact damage
2. **Shooter** — fires projectiles at player, forces dodging (Session 2.3)
3. **Tank** — slow, high HP, blocks progression (Session 2.3)

**Enemy status methods:**
apply_burn ✅ | apply_slow ⬜ | apply_stagger ⬜ | apply_brittle ⬜ | apply_chain ⬜ | apply_pushback ⬜ | apply_blind ⬜ | execute ⬜ | get_element ⬜ | apply_wet ⬜ | apply_corruption ⬜ | apply_chill ⬜

All unimplemented methods are guarded by `has_method()` in spell_projectile.gd — silently skip, no crash.

---

## Sprite Approach
- All placeholder coloured rectangles for now
- Player: orange triangle
- Enemies: red rectangles
- Summon: yellow rectangle (stub)
- Final sprites: Phase 4 art pass

---

## Folder Structureres://
├── data/
│   └── spell_elements.csv
├── scenes/
│   ├── game.tscn
│   ├── player.tscn
│   ├── enemies/
│   ├── ui/
│   │   ├── crafting_ui.tscn
│   │   ├── PageFlipWidget.tscn
│   │   └── control_strip.tscn
│   └── boss/
├── scripts/
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
│   │   └── enemy.gd
│   └── spells/
│       ├── spell_data.gd
│       ├── spell_caster.gd
│       └── spell_projectile.gd
├── resources/
└── assets/

---

## Codex Prompt Rules
1. Always start prompts with "Godot 4 GDScript"
2. Always paste relevant existing code as context
3. Always paste scene tree when asking for node-specific code
4. Use `get_node_or_null("/root/NodeName")` — never bare autoload globals
5. Verify output uses Godot 4 syntax before accepting
6. Never modify `res://data/spell_elements.csv` — read only
7. Never rewrite .tscn files — UID references break. Edit scripts only, make scene changes in Godot editor.

---

## Files in This Project Root
- `context.md` — this file, read first every session
- `design.md` — full game design document
- `systems.md` — technical decisions log
- `session_plan.md` — all session prompts and status tracker
- `feedback.md` — partner playtesting notes
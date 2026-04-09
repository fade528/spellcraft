## Session Management
Each working session is a separate chat. Always open with
"Read context.md and systems.md first" then the specific task.
See session_plan.md for the full list of planned sessions.

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

**Completed:** Player movement, enemy spawning, spell auto-cast, life system, HUD, game over, juice pass, audio, APK.

**Session 2.1 complete:** CSV-driven spell combo system built and verified in-engine.

**Session 2.2 complete:** Tome + Page system, CraftingUI pause menu, PageFlipWidget edge-swipe gesture, ControlStrip footer, persistent page save/load, rename/delete/set active pages, input zones finalized.

**Session 2.3 complete:** Shooter + Tank enemy variants, all status effects on all enemy types, weighted spawner, full SummonManager AI (trail follow, HP, recharge, auto-respawn, attack), crit pop effect, UI layout with HP/lives/action buttons in control strip area.

**Next:** Session 2.4 — Element Drop System.

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
│  [   touchpad   ]       │
└─────────────────────────┘  ← y=1920
```

The old HUD MarginContainer is hidden. HP/lives now live in ControlStrip.
ControlStrip exposes: `update_hp(current, maximum)` and `update_lives(count)`.

### Signal Flow Rule
- Signals travel **upward** (child → parent/manager)
- Direct calls travel **downward** (manager → child)
- GameManager is coordinator only — thin orchestrator, does not implement domain logic
- Domain managers own their logic: SpellComposer, PlayerInventory, SummonManager, TomeManager, ProgressionManager

### Collision Layers

```
Layer 1 — Player physical body
Layer 2 — Enemy physical body
Layer 3 — Player hurtbox (Area2D)
Layer 4 — Enemy hurtbox (Area2D)
Layer 5 — Spell projectiles (Area2D)
Layer 6 — Element drops (Area2D)
Layer 7 — Screen boundaries
```

### Data Pattern
- **CSV files** = master spell data. `res://data/spell_elements.csv` — edited in Google Sheets only, never by Codex.
- **Resources (.tres)** = other master data (enemy stats, level configs).
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
| Delivery | How the spell fires (bolt, burst, beam, etc.) |

**7 elements:** Fire, Ice, Earth, Thunder, Water, Holy, Dark

**Damage formula:**
```
final_dmg = item_base_dmg × elemental_dmgmult × weakness_mult × emp_dmgmult × enc_dmgmult × buff_debuff_mult
```

**All spell data lives in `res://data/spell_elements.csv`** — 49 rows. SpellComposer parses this on _ready().

**SpellData fields (current):**
```gdscript
@export var spell_name: String
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
```

**Key APIs:**
```gdscript
SpellComposer.compose_spell(elemental, empowerment, enchantment, delivery, target) -> SpellData
SpellComposer.get_weakness_multiplier(attacker, defender) -> float
SpellComposer.is_stop_cast(element) -> bool  # true for holy/dark
SpellComposer.get_summon_data(element) -> Dictionary
SpellCaster.refresh_spell(elemental, empowerment, enchantment, delivery, target) -> void
PlayerInventory.add_element(element) -> void
PlayerInventory.get_scaling_multiplier(element) -> float  # 1.0 + count * 0.02
```

**Holy/Dark special:** These elements do NOT auto-cast. They fire the moment the player stops moving, gated by cooldown.

**Weakness wheel:**
```
Fire → Ice → Earth → Thunder → Water → Fire
Holy ↔ Dark
Weakness = ×1.2, Resist = ×0.8, Neutral = ×1.0
```

### Summon System (Session 2.3 — complete)

One summon active at a time, independent of spell slots. All players have a summon. Summons trail the player via path-history, attack nearby enemies mimicking slot 1 spell, have HP and auto-recharge on death.

```gdscript
SummonManager.initialize(player: Node2D) -> void
SummonManager.spawn_summon(element: String) -> void
SummonManager.despawn_summon() -> void
SummonManager.set_attack_spell(spell: SpellData) -> void
SummonManager.get_summon_stat(key: String) -> Variant
SummonManager.is_recharged() -> bool
SummonManager.get_recharge_remaining() -> float
```

**Trail follow:** Summon records player's path via position history (every 8px). Follows a point 60px behind along that path. Creates genuine tail-like lag during movement.

**Attack:** Fires at nearest enemy within 350px. Uses slot 1 spell dmgmult_chain × 10 base damage. SpellCaster calls `set_attack_spell()` after every `refresh_spell()`.

**HP/recharge:** Summon has HP from CSV. Takes 5 contact damage per enemy touch. On death: recharge timer starts (60s most elements, Thunder 20s). Auto-respawns same element when timer expires.

**Spawn:** Called from `player.gd _ready()`. Reads active page summon_element from TomeManager, defaults to "fire".

Summon recharge times: most = 60s, Stormspirit (Thunder) = 20s.

### Enemy System (Session 2.3 — complete)

Three enemy types, all with full status effect suite:

**Chaser** (`res://scenes/enemy.tscn`) — chases player, contact damage via ProgressionManager.
**Shooter** (`res://scenes/enemies/shooter.tscn`) — drifts to patrol Y (200-900px), patrols left/right, fires projectiles at player every 3s within 400px range. Projectiles clamped to never travel below y=1536 (control strip).
**Tank** (`res://scenes/enemies/tank.gd`) — 100 HP, 60 speed, 600px chase distance, 25 contact damage.

**Weighted spawner** — EnemySpawner has `chaser_weight`, `shooter_weight`, `tank_weight` exports. Null scenes are skipped.

**Status effects (all three types):**
```gdscript
apply_burn(dmg_per_tick, interval, duration)
apply_slow(amount, duration)
apply_stagger(chance, duration)
apply_brittle(freeze_duration, dmg_mult)  # requires _is_chilled
apply_chain(bounce_count)                 # bounces to nearest enemies within 200px
apply_pushback(distance)
apply_blind(duration)                     # random wander every 0.5s
execute(chance)                           # instant kill, blocked on is_boss=true
apply_wet(duration)
apply_corruption(dmg_per_tick, interval, duration)
apply_chill(duration)
get_element() -> String
get_incoming_multiplier(attacker_element) -> float  # wet+thunder = 1.5x
```

All status methods guarded by `has_method()` in spell_projectile.gd — silently skip, no crash.

**Known deferred fix:** `take_damage()` death path should use `call_deferred("queue_free")` instead of `queue_free()` to avoid physics callback warnings. Not yet applied.

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

### Control Strip (Session 2.2 + 2.3 — complete)

Bottom 20% of screen. Always visible. Shows HP bar, lives, active page name, spell CD, summon recharge status.

```gdscript
ControlStrip.update_hp(current: float, maximum: float) -> void
ControlStrip.update_lives(count: int) -> void
```

HP/lives auto-update via ProgressionManager signals (`hp_changed`, `lives_changed`).
4 action button placeholders at y=1400, above the strip. BossBarContainer at y=0, hidden.

### Life System (Session 1.4 — complete)

ProgressionManager (autoload) owns lives, current_hp, max_hp. 3 lives total.

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

**Enemy status methods (all implemented Session 2.3):**
apply_burn ✅ | apply_slow ✅ | apply_stagger ✅ | apply_brittle ✅ | apply_chain ✅ | apply_pushback ✅ | apply_blind ✅ | execute ✅ | get_element ✅ | apply_wet ✅ | apply_corruption ✅ | apply_chill ✅

---

## Sprite Approach
- All placeholder coloured rectangles for now
- Player: orange triangle
- Enemies: red (Chaser), dark red (Tank), purple (Shooter)
- Summon: yellow rectangle
- Final sprites: Phase 4 art pass

---

## Folder Structure

```
res://
├── data/
│   └── spell_elements.csv
├── scenes/
│   ├── game.tscn
│   ├── player.tscn
│   ├── spell_projectile.tscn
│   ├── enemy.tscn
│   ├── enemies/
│   │   ├── shooter.tscn
│   │   └── tank.tscn
│   ├── element_drop.tscn      ← NEW
│   ├── ui/
│   │   ├── crafting_ui.tscn
│   │   ├── PageFlipWidget.tscn
│   │   └── control_strip.tscn
│   └── boss/
├── scripts/
│   ├── element_drop.gd        ← NEW
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

---

## Files in This Project Root
- `context.md` — this file, read first every session
- `design.md` — full game design document
- `systems.md` — technical decisions log
- `session_plan.md` — all session prompts and status tracker
- `feedback.md` — partner playtesting notes

**Session 2.4 complete:** Element drop system (20% drop rate, coloured orbs, player collection, floating label), summon HP bar + recharge display in ControlStrip, element counter HUD (7 school swatches with live counts).

**Next:** Session 2.5 — Mana/School system architecture. All drops become generic mana orbs allocated into elemental schools. Schools gate spell casting. Specs system for new player onboarding.

### Element Drop System (Session 2.4 — complete)
- Enemies drop element orbs at 20% chance on death
- res://scenes/element_drop.tscn — Area2D, Layer 6, Mask 3
- res://scripts/element_drop.gd — @export element: String, 8s lifetime
- spawn_drop() on all three enemy types
- On collect: PlayerInventory.add_element(element), floating "+element" label
- game.gd handles signal connection via child_entered_tree

### Summon HP Bar (Session 2.4 — complete)
SummonManager signals:
- summon_hp_changed(current: float, maximum: float)
- summon_recharge_tick(seconds_remaining: float)
ControlStrip connects both, toggles HP bar / recharge label at y=212 in StripPanel.

### Element Counter HUD (Session 2.4 — complete)
7 coloured swatches in ControlStrip at y=256, live counts from PlayerInventory.element_counts.
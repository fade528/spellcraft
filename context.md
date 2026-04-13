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

**Session 2.48 complete:** Deferred Passives Part 2 — all steps implemented and tested in-engine.

**What was delivered in 2.48:**
- killfuel (A0005): enemy kill cuts current spell CD cycle only. Per-physics-frame deduped. One-shot timer architecture applied to prevent wait_time corruption.
- overheat (A0006): N-cast threshold fires a delayed boosted shot (+0.3s). Buff badge shows while proc pending, clears on shot fire.
- bloodpower (G0004): HP-pct damage amp via PassiveManager.get_bloodpower_amp(). Reads from _active_cast_passives.
- soulsiphon (G0005): rearchitected from projectile-only to all 7 delivery types via PassiveManager.get_soulsiphon_leech().
- dispel registration (F0006): register_debuff() calls wired in spell_projectile on-hit effects. Currently inert — enemies do not yet apply named debuffs to the player.
- Burn stacking: apply_burn() now additive (_burn_damage += dmg_per_tick), duration resets on reapply.
- CD timer architecture: cooldown_timer changed to one_shot=true with explicit restart in _on_cooldown_timer_timeout(). Prevents wait_time corruption from killfuel instant reductions.
- Dynamic stagger spacing: _refresh_all_casters() now distributes stagger evenly across only actively firing casters (excludes empty, utility, stop-cast slots).
- Control strip: 4-slot CD row replaces single SpellCDLabel. Colour bars fill red→yellow→green per slot.
- Enemy debuff flash colours: _flash_debuff_colour() on shooter and tank. Orange=burn, purple=corrupt, dark blue=wet, light blue=chill/slow, white=blind.
- Player green flash on any heal via ProgressionManager.heal() → player.flash_heal().
- Buff badges enlarged. Debuff badges pulse via looping tween on modulate.a.

**Known outstanding:**
- Summon requires spell_elements.csv A0007 Status set to "active" to appear
- Utility delivery type = self-target (same as target=self spells) — not yet implemented
- Chaser enemy still lives at res://scenes/enemy.tscn — to be rebuilt as Chaser2
- dispel registration inert until enemies apply named debuffs to the player
- Milestone bonuses not yet implemented
- get_school_multiplier() uses 0.05/tier — design doc says 0.02/count, needs alignment
- soulsiphon legacy arm still present in _apply_on_hit_effects() in all delivery scripts — remove in next session (double-heal risk if soulsiphon is in on_hit_effects)

**Next:** Session 2.49 — TBD (enemy variety / wave structure, OR spec system, OR equipment slots)

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
PassiveManager       res://scripts/managers/passive_manager.gd
```

### Scene Structure (actual as built)

```
Game (scene) — res://scenes/game.tscn
├── ScrollingBackground
│   ├── BackgroundA (ColorRect)
│   └── BackgroundB (ColorRect)
├── Player (scene) — res://scenes/player.tscn
│   ├── SpellCaster (Node2D)        ← slot 1, child of player in .tscn
│   │   └── CooldownTimer (Timer)   ← one_shot=true as of session 2.48
│   ├── SpellCaster2 (Node2D)       ← created at runtime in player._ready()
│   ├── SpellCaster3 (Node2D)
│   └── SpellCaster4 (Node2D)
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
    │   ├── ActivePageLabel         ← "▶ Fire all" etc
    │   ├── SpellCDLabel            ← hidden — replaced by 4-slot CD row
    │   ├── SummonLabel
    │   ├── BuffRow (HBoxContainer) ← passive badges, debuffs pulse
    │   ├── [4x slot CD labels]     ← S1/S2/S3/S4 with colour bars
    │   ├── [school swatches x7]
    │   └── ManaPoolLabel
    ├── ActionButtonLayer (Control) — y=1400, 4 placeholder buttons
    └── BossBarContainer (Control) — y=0, hidden until Session 3.x

Enemy scenes:
res://scenes/enemy.tscn       — Chaser (to be retired)
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
│  [buff badges — pulsing debuffs]
│  S1 X.Xs  S2 RDY  S3 X.Xs  S4 RDY   ← 4-slot CD row with colour bars
│  Summon: Ready / Xsec   │
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
- Domain managers own their logic: SpellComposer, PlayerInventory, SummonManager, TomeManager, ProgressionManager, SpecManager, PassiveManager

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
- **Node variables** = runtime state (current HP, cooldowns).
- **JSON files** = player save data. user://specs.json (custom specs), user://pages_{spec}.json (per-spec tome pages).
- Always `duplicate()` resources before modifying per-instance values.

### CD Timer Architecture (Session 2.48 — critical)
SpellCaster.cooldown_timer is `one_shot = true`. After firing, `_on_cooldown_timer_timeout()` explicitly restarts it at `full_cd = maxf(spell_data.cooldown - _cd_reduction, 1.5)`. This prevents wait_time corruption from killfuel instant reductions. Never set `one_shot = false` on cooldown_timer.

```gdscript
# In _on_cooldown_timer_timeout(), at the very end after _spawn_delivery():
var full_cd: float = maxf(spell_data.cooldown - _cd_reduction, 1.5) if spell_data != null else 1.5
cooldown_timer.wait_time = full_cd
cooldown_timer.start()
```

### PassiveManager Buckets (Session 2.47)
Three separate arrays populated in recalculate():
- `_active_passives` — cd_type=passive, target=self
- `_active_cast_passives` — cd_type=cast, target=self (soulsiphon, bloodpower, holylight, dispel, overheat)
- `_active_enemy_passives` — cd_type=passive, target=enemy (rootedpower)

### PassiveManager API (cumulative)

```gdscript
# Session 2.47
get_damage_amp() -> float           # rootedpower amp, 0.0 when moving
get_effective_damage(raw, element)  # applies damage_reduction + iceshield + element resist
is_iceshield_active() -> bool
on_enemy_killed() -> void           # killfuel proc — deduped per physics frame

# Session 2.48
get_overheat_effect() -> Dictionary # returns effect dict from _active_passives
get_bloodpower_amp() -> float       # reads HP% from ProgressionManager
get_soulsiphon_leech() -> float     # reads from _active_cast_passives
```

### SpellCaster API (cumulative)

```gdscript
refresh_spell(elemental, empowerment, enchantment, delivery, target) -> void
apply_cd_reduction(reduction: float) -> void   # permanent, baked into wait_time
apply_cd_reduction_instant(seconds: float) -> void  # cuts time_left this cycle only
set_stagger_delay(delay: float) -> void
set_moving(moving: bool) -> void
# _overheat_ready: bool — readable by ControlStrip for badge display
```

### Player API (cumulative)

```gdscript
take_damage(amount, element) -> void
apply_speed_bonus(bonus) -> void
flash_heal() -> void    # green modulate flash, called by ProgressionManager.heal()
respawn() -> void
```

### ProgressionManager API (cumulative)

```gdscript
take_damage(amount) -> void
heal(amount) -> void              # clamps to max_hp, emits hp_changed, calls player.flash_heal()
register_debuff(name) -> void
remove_debuffs(count) -> Array[String]
reset_run() -> void
get_current_hp() -> float         # or property current_hp
get_max_hp() -> float             # or property max_hp
is_dead() -> bool                 # check before applying on-death effects
```

### Enemy API (shooter + tank, cumulative)

```gdscript
take_damage(amount, element) -> void
apply_burn(dmg_per_tick, interval, duration) -> void   # stacks additively since 2.48
apply_slow(amount, duration) -> void
apply_stagger(chance, duration) -> void
apply_brittle(freeze_duration, dmg_mult) -> void
apply_chain(bounce_count) -> void
apply_pushback(distance) -> void
apply_blind(duration) -> void
apply_wet(duration) -> void
apply_corruption(dmg_per_tick, interval, duration) -> void
apply_chill(duration) -> void
apply_purge(count) -> void
execute(chance) -> void
get_element() -> String
get_incoming_multiplier(attacker_element) -> float
_flash_debuff_colour(colour: Color) -> void   # added 2.48
```

### TomeManager API
```gdscript
TomeManager.load_for_spec(spec_name: String, preferred_slots: Array = []) -> void
TomeManager.reset_to_default(preferred_slots: Array = []) -> void
TomeManager.flip_to_page(index: int) -> void
TomeManager.can_flip_page(target_index: int = -1) -> bool
TomeManager.save_page(index: int, page: PageData) -> void
TomeManager.get_page(index: int) -> PageData
TomeManager.get_active_page() -> PageData
TomeManager.add_page() -> void
TomeManager.delete_page(index: int) -> void
TomeManager.rename_page(index: int, new_name: String) -> void
TomeManager.reset_override_flags() -> void
```

**Page flip gate:** Only spell cooldown (_flip_cooldown). Summon recharge no longer blocks flips.
**Page override indicator:** `~ ` prefix = spec-driven, `* ` prefix = manually edited.

### Summon System
```gdscript
SummonManager.spawn_summon(element: String) -> void
SummonManager.despawn_summon() -> void
SummonManager.set_attack_spell(spell: SpellData) -> void
SummonManager.get_summon_stat(key: String) -> Variant
SummonManager.is_recharged() -> bool
SummonManager.get_recharge_remaining() -> float
SummonManager.heal_summon(amount: float) -> void
SummonManager.get_summon_max_hp() -> float
SummonManager.clear_debuffs() -> void   # no-op hook
```

### Control Strip API
```gdscript
ControlStrip.update_hp(current: float, maximum: float) -> void
ControlStrip.update_lives(count: int) -> void
ControlStrip.update_mana_display() -> void   # called every frame from _process
```

### CraftingUI
```gdscript
CraftingUI.open_ui() -> void
CraftingUI.close_ui() -> void
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
│   ├── deliveries/
│   │   ├── bolt.tscn
│   │   ├── burst.tscn
│   │   ├── missile.tscn
│   │   ├── beam.tscn
│   │   ├── aoe.tscn
│   │   ├── cleave.tscn
│   │   └── orbs.tscn
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
│   ├── progression_manager.gd
│   ├── managers/
│   │   ├── spell_composer.gd
│   │   ├── player_inventory.gd
│   │   ├── summon_manager.gd
│   │   ├── tome_manager.gd
│   │   └── passive_manager.gd
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
│       ├── spell_projectile.gd
│       └── deliveries/
│           ├── bolt.gd
│           ├── burst.gd
│           ├── missile.gd
│           ├── beam.gd
│           ├── aoe.gd
│           ├── cleave.gd
│           └── orbs.gd
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
13. cooldown_timer is one_shot=true — never set one_shot=false, always restart manually in timeout handler

---

## Files in This Project Root
- `context.md` — this file, read first every session
- `design.md` — full game design document
- `systems.md` — technical decisions log
- `session_plan.md` — all session prompts and status tracker
- `feedback.md` — partner playtesting notes

## KNOWN ISSUES
- Chaser (enemy.gd) has no debuff surface — retire in favour of Chaser2
- soulsiphon legacy arm still in _apply_on_hit_effects() in all 7 delivery scripts — double-heal risk, remove next session
- dispel registration wired but inert — enemies don't apply named debuffs to player yet
- rootedpower and stagger routing incorrectly into on_hit_effects
- SpellComposer register_passive() is dead path for PassiveManager
- Milestone bonuses not yet implemented
- get_school_multiplier() uses 0.05/tier — design doc says 0.02/count, needs alignment

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
**Implementation:**
```gdscript
enum DamageType { CONTACT, PROJECTILE, BOSS_ATTACK, ENVIRONMENT }

func take_damage(amount: float, type: DamageType = DamageType.CONTACT):
    if is_invincible:
        return
    hp -= amount
    combat_manager.record_damage_taken(amount, type)
    emit_signal("hp_changed", hp)
    if hp <= 0:
        emit_signal("player_died")
        return
    start_iframes()
```
**Notes:** iframe_duration exported to inspector for partner tuning. Default 1.0s.

---

### Iframes
**Date:** TBD
**Decision:** Timer node based, 1.0s default, sprite flash visual cue
**Reason:** Prevents rapid consecutive damage. Timer cleaner than delta accumulation.
**Implementation:**
```gdscript
func start_iframes():
    is_invincible = true
    $IframeTimer.start(iframe_duration)
    _play_iframe_visual()

func _on_iframe_timer_timeout():
    is_invincible = false

func _play_iframe_visual():
    var tween = create_tween()
    tween.set_loops(int(iframe_duration / 0.1))
    tween.tween_property(sprite, "modulate:a", 0.3, 0.05)
    tween.tween_property(sprite, "modulate:a", 1.0, 0.05)
```
**Notes:** iframe_duration exported. Partner tunes via inspector.

---

### Signal Convention
**Date:** TBD
**Decision:** Signals travel up, direct calls travel down
**Reason:** Keeps nodes decoupled. GameManager coordinates without knowing internals.
**Implementation:**
```
Child nodes → emit signals upward
GameManager → receives signals, delegates to domain managers
Domain managers → call methods directly on child nodes
```
**Notes:** If GameManager function exceeds 5-6 lines, logic belongs in a domain manager.

---

### Resource vs State
**Date:** TBD
**Decision:** Resources = master data (spell definitions, enemy stats). Node variables = runtime state (current HP, cooldowns).
**Reason:** Clean separation. Resources saved as .tres files, tunable in inspector. State resets each run.
**Notes:** Always duplicate() resources before modifying per-instance values. Never store transactional values in resource files.

---

### Spawning Pattern
**Date:** TBD
**Decision:** EnemySpawner node in Game scene uses repeating Timer, instances Enemy scenes
**Reason:** Clean separation. Spawner owns spawn logic, enemies own their behaviour.
**Implementation:**
```gdscript
func _on_spawn_timer_timeout():
    var enemy = enemy_scene.instantiate()
    enemy.position = Vector2(randf_range(50, 1030), -50)
    add_child(enemy)
```
**Notes:** Enemies despawn when position.y > 1980. spawn_rate and enemy_speed exported.

---

### Player Movement (Session 1.1)
**Date:** 2026-04-06
**Decision:** CharacterBody2D with touchpad CanvasLayer
**Implementation:** TouchpadBase + TouchpadKnob ColorRects, drag input via InputEventScreenDrag, 8-direction facing via FacingMarker Polygon2D, screen clamping to 1080x1920
**Notes:** Player starts top-left, will centre in Game scene

---

### Enemy Spawning (Session 1.2)
**Date:** 2026-04-06
**Decision:** Chaser enemies are separate CharacterBody2D scenes spawned by an EnemySpawner timer into the Game scene.
**Reason:** Keeps enemy behaviour self-contained while the spawner owns cadence and tuning through exported values.
**Implementation:**
```gdscript
@export var spawn_rate: float = 1.0
@export var enemy_speed: float = 150.0

func _on_spawn_timer_timeout() -> void:
    var enemy = enemy_scene.instantiate() as CharacterBody2D
    enemy.position = Vector2(randf_range(50.0, 1030.0), -50.0)
    enemy.set("move_speed", enemy_speed)
    get_parent().add_child(enemy)
```
**Notes:** Enemies join the `enemies` group on `_ready()` and despawn after passing `y > 1980`.

---

### Scrolling Background (Session 1.2)
**Date:** 2026-04-06
**Decision:** Two stacked `ColorRect` nodes scroll downward and wrap to fake an infinite background in portrait mode.
**Reason:** Placeholder art is enough for early feel testing and keeps Session 1.2 lightweight.
**Implementation:**
```gdscript
func _scroll_background(background_rect: ColorRect, delta: float) -> void:
    background_rect.position.y += background_scroll_speed * delta
    if background_rect.position.y >= 1920.0:
        background_rect.position.y -= 3840.0
```
**Notes:** Current playable harness is `res://scenes/game.tscn`.

---

### Enemy Chase Behaviour (Session 1.2)
**Date:** 2026-04-06
**Decision:** Chasers disengage when player distance exceeds chase_distance (default 300px)
**Reason:** Without cutoff, enemies stack on player indefinitely and never despawn
**Implementation:** Distance check in _physics_process before normalizing direction vector. If within chase_distance, move toward player. Otherwise fall straight down.
**Notes:** chase_distance is @export — tunable in inspector. Revisit during enemy tuning session.

---

### Collision Architecture — Interim (Session 1.2)
**Date:** 2026-04-06
**Decision:** Enemies and player both disable physical body collision with each other for now
**Reason:** move_and_slide() caused stacking. Damage will come via Area2D hurtboxes in Session 1.4
**Implementation:** set_collision_mask_value(1/2, false) in _ready() on both enemy and player
**Notes:** Remove this when hurtboxes are implemented in 1.4 — physical layers should be restored

---

### Spell System (Session 1.3)
**Date:** 2026-04-06
**Decision:** Spells use `SpellData` resources for tuning, a `SpellCaster` child on the player for auto-fire, and `Area2D` projectiles against enemy hurtboxes.
**Reason:** Keeps spell balance data separate from runtime casting logic and matches the planned layer-4/layer-5 hurtbox architecture.
**Implementation:** `res://scripts/spell_data.gd` defines damage, cooldown, and projectile_speed. `res://scripts/spell_caster.gd` runs a cooldown Timer, aims at the nearest node in group `enemies`, and instantiates `res://scenes/spell_projectile.tscn`. `res://scripts/spell_projectile.gd` moves upward by default, can be aimed toward a target, emits a hit signal, and damages enemies through their hurtbox Area2D.
**Notes:** Starter spell resource is `res://resources/spells/basic_bolt.tres`. Enemies now have a layer-4 hurtbox child and a `take_damage(amount)` method with exported `max_hp`.

---

### Life System + HP Bar (Session 1.4)
**Date:** 2026-04-06
**Decision:** Single HP bar owned by ProgressionManager autoload. Lives are retained as a second layer — losing all HP costs one life, refills HP to max, and triggers respawn. Three lives lost triggers game over.
**Reason:** HP bar is more future-proof than lives-only for a roguelite where spells, items, and enemies will deal variable damage amounts.
**Implementation:**
ProgressionManager (autoload at /root/ProgressionManager) owns `lives`, `current_hp`, `max_hp`. Exposes `take_damage(amount)`, `lose_life()`, `refill_hp()`, `reset_run()`. Emits `hp_changed(current_hp, max_hp)` and `life_lost(lives_remaining)` and `game_over`.

player.gd enforces iframes locally, then delegates to ProgressionManager.take_damage(). player_hurtbox.gd (Area2D layer 3, mask 2) detects enemy body overlap and calls player.take_damage(contact_damage). contact_damage is @export, default 10.0.

game.gd connects life_lost → clears enemies/projectiles groups → calls player.respawn(). Connects game_over → change_scene_to_file game_over.tscn. game_over.gd calls ProgressionManager.reset_run() before returning to game.tscn.

HUD shows three ColorRect life icons + ProgressBar (HPBar) + Label (HPLabel, format "100 / 100"). All HUD nodes reference ProgressionManager via get_node_or_null("/root/ProgressionManager").

**Notes:**
- iframe_duration is @export on player.gd, default 1.5s. Tunable in inspector.
- max_hp and starting_lives are @export on ProgressionManager. Tunable in inspector.
- Autoload must be registered via Godot editor UI (Project → Project Settings → Globals → Autoload), not by editing project.godot directly — direct edits produce a UID reference that Godot can't resolve. If the path shows as blank in the Autoload tab, delete and re-add the entry. Always type paths manually, never use the folder browser.
- All scripts use get_node_or_null("/root/NodeName") as the safe fetch pattern throughout the project. Never use bare global autoload references.
- Projectile-to-player damage not yet implemented (no layer-5 → layer-3 mask). Add in a future combat session.

---

### Audio (Session 1.5)
**Date:** 2026-04-06
**Decision:** All audio nodes pre-wired in game.tscn, streams assigned.
**Implementation:**
- `SpellHitSFX` — spell_hit.wav, plays on spell hit signal
- `PlayerHurtSFX` — hurt.wav, plays on hp_changed decrease
- `EnemyDeathSFX` — popenemydeath.wav, plays on enemy died signal
- `BGMusic` — mischeifaudop.wav, autoplay on, loop on

**File locations:**
```
res://assets/audio/sfx/spell_hit.wav
res://assets/audio/sfx/hurt.wav
res://assets/audio/sfx/popenemydeath.wav
res://assets/audio/music/mischeifaudop.wav
```
**Notes:** SFX use .wav (low latency). Music uses .ogg (compressed). No AudioBus mixing yet — all on Master bus. Separate SFX/Music buses come in Session 4.5.

---

### Spell Combo Architecture (Session 2.1)
**Date:** 2026-04-08
**Decision:** CSV-driven spell composition system. All spell values live in `res://data/spell_elements.csv`, edited in Google Sheets only. SpellComposer autoload parses the CSV and composes SpellData resources at runtime from element slot choices.

**Reason:** Data over scripts. Partner can tune values in Google Sheets without touching code. Adding new combos or elements = adding CSV rows, not writing new scripts.

**Slot Names (renamed from Primary/Modifier/Finisher):**
- Elemental — core identity of the spell, sets inherent dmgmult
- Empowerment — amplifies damage or damage-related attributes
- Enchantment — adds functions and gimmicks
- Summon — independent slot, managed separately by SummonManager

**Damage Formula:**
```
final_dmg = item_base_dmg × elemental_dmgmult_chain × weakness_mult × buff_debuff_mult

DoT tick dmg = final_dmg × value1 (e.g. burn = final_dmg × 0.1)
total_spell_cd = sum of cd values where cd_type == "cast"
```

**CSV Column Structure:**
```
spell_id | element | position | target | effect_name |
value1 | value2 | value3 | value4 | value5 |
cd | cd_type | dmgmult | budget | Description
```

**cd_type values:**
- `cast` — adds to total_spell_cd
- `passive` — registered with PlayerInventory, never adds to cd
- `recharge` — independent timer (summons, intervention, requiem)

**dmgmult rules:**
- dmgmult > 0 → multiplied into dmgmult_chain
- dmgmult = 0 → treated as 1.0 (neutral, no contribution)
- SpellData.damage is always set to 1.0 — flat damage comes from item_base_dmg only
- SpellData.dmgmult_chain holds the composed multiplier

**Weakness Wheel (hardcoded, never changes):**
```
fire beats ice → ×1.2      ice beats earth → ×1.2
earth beats thunder → ×1.2  thunder beats water → ×1.2
water beats fire → ×1.2     holy beats dark → ×1.2
dark beats holy → ×1.2
Reverse = ×0.8. No match = ×1.0. Empty defender = ×1.0.
```

**Holy/Dark special mechanic:**
- Elemental slot fires on player stop, not auto-cast
- Gated by cooldown — stopping triggers cast only if cd is ready
- SpellComposer.is_stop_cast(element) returns true for holy/dark
- SpellCaster tracks _is_moving and _just_stopped, checks is_stop_cast in timer callback

**Autoload registration order (critical):**
```
1. ProgressionManager
2. PlayerInventory
3. SpellComposer
4. SummonManager
```

**Autoloads:**
- `PlayerInventory` — tracks element_counts, active_passives, equipment stub. Exposes get_scaling_multiplier(element) → 1.0 + count × 0.02
- `SpellComposer` — loads CSV on _ready(), builds _rows and _index dictionaries, exposes compose_spell(), get_weakness_multiplier(), is_stop_cast(), get_summon_data()
- `SummonManager` — stub, spawns yellow placeholder that follows player. Full AI in Session 2.3. Call SummonManager.initialize(player) from player _ready()

**Summon system:**
- Summon slot is independent of the 3 spell slots — players always have one summon active
- One summon active at a time — spawning a new one despawns the existing one
- Summon attacks mimic player slot 1 spell effects (implemented in Session 2.3)
- Dual-element summons = future expansion, not planned yet
- All summon stats (hp, attack, recharge) in spell_elements.csv, position=Summon, target=Summon

**AoE effects:**
- explosion and splash use _apply_aoe(radius, dmg, exclude) — primary hit target is excluded to prevent double damage
- AoE hits all enemies in group "enemies" within radius except the excluded node

**Enemy status methods:**
- apply_burn(dmg_per_tick, interval, duration) implemented in enemy.gd — uses repeating Timer, first tick delayed by one interval to separate from impact number
- apply_slow, apply_stagger, apply_brittle, apply_chain, apply_pushback, apply_blind — not yet implemented, guarded by has_method() checks, silently skipped until Session 2.3
- execute() — not yet implemented, guarded by has_method()

**DoT damage numbers:**
- Burn ticks call take_damage() so they inherit crit chance naturally
- Damage numbers use random x offset (randf_range -12 to 12) to prevent stacking
- Impact number and first burn tick separated by one full interval (burn Timer starts with delay)

**CSV editing workflow:**
- Edit in Google Sheets only — never via text editor or Codex
- Export as CSV → replace res://data/spell_elements.csv
- Codex reads the CSV but never modifies it

**Files:**
```
res://data/spell_elements.csv
res://scripts/spell_data.gd
res://scripts/spell_caster.gd
res://scripts/spell_projectile.gd
res://scripts/managers/spell_composer.gd
res://scripts/managers/player_inventory.gd
res://scripts/managers/summon_manager.gd
```

**Verified in-engine (smoke test results):**
```
compose_spell("fire","fire","fire","bolt","enemy")
  → total_cd: 3.0 ✅
  → total_budget: 5.5 ✅
  → dmgmult_chain: 1.2 ✅
get_weakness_multiplier("fire","ice") → 1.2 ✅
is_stop_cast("holy") → true ✅
get_summon_data("fire") → forgespirits ✅
PlayerInventory scaling at count 0 → 1.0 ✅
Fire+Fire+Fire in-game: impact 12, explosion AoE 4 on clumped enemies, burn ticks 1 per second ✅
```
Read res://systems.md and append this new section
at the end of the Decisions Log:

### Tome + Page System (Session 2.2)
**Date:** 2026-04-08
**Decision:** Full tome/page system with persistent
storage, in-game flip gesture, and dedicated control strip.

**TomeManager autoload:**
- Manages up to 8 pages (PageData resources)
- Saves/loads to user://tome_pages.json on every mutation
- Pages persist across runs and restarts
- can_flip_page(target_index) bypasses gate if target == active
- Signals: page_flipped, page_saved, page_deleted, page_renamed, flip_blocked

**PageData resource:**
- class_name PageData extends Resource
- Fields: page_name, slots (Array[Dictionary]), summon_element, ult1, ult2
- ensure_slots(4) pads to 4 slots with fire/fire/fire/bolt defaults
- make_default_slot() static helper

**CraftingUI (Escape menu):**
- Pauses game on open (get_tree().paused = true)
- process_mode = PROCESS_MODE_ALWAYS so UI works while paused
- Tome view: lists pages with Craft, Set Active, Rename, Delete buttons
- Set Active bypasses flip cooldown gate — direct apply
- Page editor: slot 0 active, slots 1-3 greyed/disabled
- Stats panel: live CD, budget, dmgmult_chain via SpellComposer
- Save writes draft back and applies live if editing active page
- child.free() not queue_free() to prevent duplicate New Page button

**PageFlipWidget (in-game gesture):**
- Covers full screen, MOUSE_FILTER_IGNORE so input passes through
- Uses _input() not _unhandled_input()
- Gesture: press left 0-10% or right 90-100% of strip → grid appears
  centre screen → drag into middle zone → direction determines page →
  release confirms flip
- _select_start resets when finger enters middle zone (10-90%)
  so directional drag is not bounded by edge press position
- Grid: 3x3, centre cell = indicator, 8 cells = pages 1-8
- Empty page slots shown dimmed

**ControlStrip (always-visible HUD footer):**
- Bottom 20% of screen (y >= 80%)
- Shows: active page name, slot 1 spell CD, summon recharge status
- Updates every _process frame for CD and summon
- Touchpad zone: x 10-90%, y 80-100% (strip only)
- Flip trigger zones: x 0-10% and x 90-100%, y 80-100%

**Input zone map (bottom 20% strip):**
Left  0-10%  → flip gesture trigger
Mid  10-90%  → touchpad (player movement)
Right 90-100% → flip gesture trigger

**Player changes:**
- Clamps to top 80% of viewport (dynamic viewport size)
- Touchpad activates only in strip zone, excludes flip edges
- Uses _input() not _unhandled_input()
- RESPAWN_POSITION = Vector2(540, 1400)

**Autoload order (final for Phase 2):**
1. ProgressionManager
2. PlayerInventory
3. SpellComposer
4. SummonManager
5. TomeManager

**UI layout reserved (not yet built):**
- Top: Boss HP bar (Session 3.x)
- Below top: game area
- Above strip: HP bar + lives (move from top in future session)
- Above strip: 4 action buttons (Session 4.x)
- Bottom 20%: control strip (built this session)
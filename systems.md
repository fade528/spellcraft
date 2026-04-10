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


---

### Enemy Variants — Shooter + Tank (Session 2.3)
**Date:** 2026-04-08
**Decision:** Two new standalone enemy scripts (not extending enemy.gd). All three enemy types carry a full copy of status effect methods. No base class — duplication preferred over inheritance complexity at this stage.

**Shooter:**
- Drifts down to random patrol Y (200–900px), then patrols left/right at patrol_speed
- Fires spell_projectile.tscn at player every fire_rate seconds within fire_range (400px)
- Projectile direction clamped: `dir.y = min(dir.y, 0.0)` — never fires into control strip
- Skips fire if player is in control strip zone (player.y >= 1536)
- Hurtbox Area2D created in code (layer 4, no mask) — spell_projectile detects it
- Contact Area2D (no layer, mask 3) deals contact_damage via ProgressionManager

**Tank:**
- 100 HP, move_speed 60, chase_distance 600, contact_damage 25
- Identical hurtbox/contact setup to Shooter
- Always chasing (600px chase distance covers full screen)

**Collision pattern (all enemy types):**
- Root CharacterBody2D: layer 2, no mask
- Hurtbox Area2D: layer 4, no mask (projectile detects us, we don't detect projectile)
- Contact Area2D: no layer, mask 3 (detect player hurtbox, deal damage to ProgressionManager)
- No CollisionShape2D on root node — physics body shape not needed

**Known issue:** `queue_free()` called from `take_damage()` inside a physics callback triggers a warning. Fix: use `call_deferred("queue_free")` in death path. Not yet applied.

**Files:**
```
res://scripts/enemies/shooter.gd
res://scripts/enemies/tank.gd
res://scenes/enemies/shooter.tscn
res://scenes/enemies/tank.tscn
```

---

### Weighted Enemy Spawner (Session 2.3)
**Date:** 2026-04-08
**Decision:** EnemySpawner uses weight-based random selection across three enemy types. Null scene exports are skipped — this allows gradual introduction of enemy types without code changes.

**Implementation:**
```gdscript
var pool: Array = []
if chaser_scene != null: pool.append({"scene": chaser_scene, "weight": chaser_weight})
# ... then weighted random walk
```

**Current defaults:** chaser 0.6 / shooter 0.25 / tank 0.15 — tunable in inspector.

**Note:** `enemy_speed` export only applies to the Chaser. Shooter and Tank have their own exported speed defaults.

---

### Status Effects on Enemies (Session 2.3)
**Date:** 2026-04-08
**Decision:** All status methods implemented on all three enemy types. Timer-based pattern consistent with apply_burn. Key implementation notes:

- `apply_slow`: stores `_original_speed` before first application, guard with `_is_slowed` bool. Timer restart extends duration without stacking multiplier.
- `apply_stagger`: sets `_is_staggered = true`, physics_process returns early. Uses `_start_stagger_timer()` helper with meta for crit restore.
- `apply_brittle`: requires `_is_chilled == true`, reuses stagger timer, multiplies crit_multiplier and restores on timeout via stored meta.
- `apply_chain`: iterates "enemies" group, sorts by distance, bounces `_last_chain_damage` to nearest N. No recursion. `_last_chain_damage` set in `take_damage()`.
- `apply_blind`: sets `_blind_direction` randomly every 0.5s via `_blind_wander_timer` float in `_process()`. Physics process uses `_blind_direction` instead of toward-player.
- `apply_pushback`: single-frame velocity impulse away from player. `distance / 0.3` = velocity magnitude.
- `execute`: blocked if `is_boss == true`. Calls `take_damage(current_hp * 10.0)`.
- `apply_wet` / `apply_chill`: set bool flags, one-shot timer clears them.
- `apply_corruption`: identical to burn, separate timer + vars.
- `get_incoming_multiplier(attacker_element)`: wet + thunder = 1.5x. Future hook for Session 3.x.

**Variant inference fix:** `min()` on two ints returns Variant in strict mode. Use `mini()` instead:
```gdscript
var remaining_bounces: int = mini(bounce_count, nearby_enemies.size())
```

---

### Full SummonManager AI (Session 2.3)
**Date:** 2026-04-08
**Decision:** Summon follows player via trail path history, not position offset. Attacks nearest enemy independently on its own timer synced to slot 1 cooldown. HP + auto-recharge implemented.

**Trail follow system:**
- Records player global_position into `_trail_positions` array whenever player moves >= 8px (TRAIL_RECORD_DIST)
- Finds point 60px (TRAIL_FOLLOW_DIST) behind along the trail by accumulating segment lengths
- Summon `move_toward()` that trail point at 200px/s
- Array capped at 200 entries. Cleared and pre-filled with player position on spawn to prevent top-left drift.

**Attack system:**
- `set_attack_spell(spell)` called by SpellCaster after every `refresh_spell()` — keeps summon in sync with active page slot 0
- Finds nearest enemy within 350px, fires spell_projectile.tscn toward it
- Damage = `spell.dmgmult_chain * 10.0` (base 10 weapon dmg for summon)
- Projectile added to "projectile_container" group node (Projectiles node in game.tscn)

**HP/recharge:**
- Summon HP from CSV `hp` field. Takes 5 damage per enemy body_entered on hurtbox Area2D (layer 4, mask 2)
- `despawn_summon()` sets `_recharge_timer` from CSV `cd` field
- Auto-respawn in `_process()`: when `_recharge_timer` ticks to 0 and `_current_element != ""`, calls `spawn_summon(_current_element)`

**Spawn fix:** `add_child.call_deferred(summon_root)` required — `spawn_summon()` is called during player `_ready()` when scene tree is still setting up children. Direct `add_child()` fails silently.

**Files:**
```
res://scripts/managers/summon_manager.gd
```

---

### Crit Number Pop Effect (Session 2.3)
**Date:** 2026-04-08
**Decision:** Crit damage numbers pop out and hold in place rather than drifting upward like normal hits. This makes crits visually distinct.

**Normal hits:** float upward 40px, fade over 0.5s.
**Crits:** gold colour (1.0, 0.85, 0.1), pop from 52→68px then settle at 56px, hold 0.25s, fade in place. No upward movement.

Applied identically to enemy.gd, shooter.gd, tank.gd.

---

### UI Layout Overhaul (Session 2.3)
**Date:** 2026-04-08
**Decision:** HP bar and lives moved from HUD CanvasLayer into ControlStrip. 4 action button placeholders added above the strip. Boss bar reserved at top.

**Layout (all code-driven in control_strip.gd):**
- `StripPanel` (y=1536, h=384): HP bar at y=12, 4 action buttons replaced by labels, page/CD/summon labels at y=60/112/160
- `ActionButtonLayer` (Control, y=1400): 4 ColorRect buttons spanning full width (248px each, 20px margin, 16px gap), sit above strip in game canvas area
- `BossBarContainer` (Control, y=0): ProgressBar + Label, visible=false until Session 3.x

**Old HUD:** `MarginContainer` inside HUD set to `visible = false`. HUD node still exists — do not delete.

**ControlStrip public API:**
```gdscript
ControlStrip.update_hp(current: float, maximum: float) -> void
ControlStrip.update_lives(count: int) -> void
```

Auto-wired to ProgressionManager signals `hp_changed` and `lives_changed` in `_ready()`.

**Note:** Player clamp remains at 80% (`vp.y * 0.80`). Touchpad activation remains at 80%. Players can currently walk into the action button zone — address in a future session if needed.

### Element Drop System (Session 2.4)
**Date:** 2026-04-10
**Decision:** Enemies drop element orbs on death at 20% chance. Orb is Area2D (Layer 6, Mask 3), 16×16 ColorRect coloured by element, 8s lifetime. Player hurtbox (Layer 3) collection triggers PlayerInventory.add_element() and floating "+element" label.
**Implementation:**
- res://scenes/element_drop.tscn — Area2D root, CircleShape2D radius 16
- res://scripts/element_drop.gd — @export element, colour map, area_entered detection
- spawn_drop() added to enemy.gd, shooter.gd, tank.gd — called on death before queue_free
- game.gd _on_game_child_entered_tree detects element_drop.tscn nodes, connects collected signal
- Floating label spawned in game.gd _spawn_element_label()
**Known fix pending:** collision_mask must be set in code to `1 << 2` — editor value was overwritten by `collision_mask = 0` in _ready(). Fixed in element_drop.gd.
**Notes:** element export defaults to "none" on all three enemy scenes — set to real elements in inspector. DROP_CHANCE const = 0.20.

---

### Summon HP Bar + Recharge Display (Session 2.4)
**Date:** 2026-04-10
**Decision:** SummonManager emits two signals: summon_hp_changed(current, maximum) and summon_recharge_tick(seconds_remaining). ControlStrip connects to both and toggles between HP bar and recharge label.
**Implementation:**
- summon_hp_changed emitted in spawn_summon() and take_summon_damage()
- summon_recharge_tick emitted every 1s via _recharge_display_timer accumulator in _process(), and once at 0.0 on respawn
- control_strip.gd _build_summon_status() creates ProgressBar + Label at y=212, only one visible at a time
**Notes:** HP and recharge values are CSV-driven via spell_elements.csv cd and hp fields. 60s default recharge fallback if field missing.

---

### Element Counter HUD (Session 2.4)
**Date:** 2026-04-10
**Decision:** 7 coloured swatches with counters displayed in ControlStrip below summon bar at y=256/288. Reads from PlayerInventory.element_counts every frame.
**Colours:** fire=red, ice=light blue, earth=brown, water=dark blue, thunder=yellow, holy=white, dark=purple
**Implementation:**
- control_strip.gd _build_element_counters() builds 7 column layout at ~154px per column
- _element_count_labels Dictionary keyed by element name
- update_element_counts() called from _process(), reads inv.element_counts directly
**Notes:** Variable is element_counts (no underscore) in player_inventory.gd. Dark swatch uses purple Color(0.5,0,0.8) for visibility against dark background.

---

### Mana/School System — Architecture Planned (Session 2.4)
**Date:** 2026-04-10
**Decision:** Deferred to Session 2.5+. Design pivot: all drops become generic mana orbs, allocated into elemental schools. Schools gate spell casting (0 allocation = cannot cast). Specs provide auto-allocation ratios + preferred spell loadouts for new players. Archmage mode = freeform manual allocation.
**Reason:** Significant multi-session work. Current element_counts system remains in place as placeholder.
**Forward:** Requires SpecManager autoload, mana pool in PlayerInventory, school gating in SpellCaster, reallocation UI in CraftingUI.

### Mana Drop System (Session 2.41)
**Date:** 2026-04-10
**Decision:** Replaced 7-element coloured orbs with a single generic mana orb. All drops are now identical light-blue ColorRects. PlayerInventory tracks a unified mana_pool and delegates allocation to SpecManager.

**element_drop.gd changes:**
- Removed @export element and ELEMENT_COLORS
- Signal changed from `collected(element_name)` to `collected(drop_position: Vector2)`
- Calls `PlayerInventory.add_mana(1)` instead of `add_element(element)`
- Visual: Color(0.6, 0.8, 1.0), no element lookup

**enemy.gd / shooter.gd / tank.gd changes:**
- `drop.element = element` removed from spawn_drop() — property no longer exists
- `get_tree().current_scene.add_child(drop)` → `get_tree().current_scene.call_deferred("add_child", drop)` — required because spawn_drop() is called from take_damage() inside a physics callback

**game.gd changes:**
- Connection no longer uses `.bind(node.global_position)` — position now carried by signal itself
- `_on_element_collected(element_name, drop_position)` → `_on_element_collected(drop_position: Vector2)`
- Floating label shows "+mana" instead of "+element"

**Rule added:** Always use `call_deferred("add_child", node)` when adding children inside physics callbacks (take_damage, area_entered, etc.)

---

### PlayerInventory Mana API (Session 2.41)
**Date:** 2026-04-10
**Decision:** Added mana economy fields and methods to PlayerInventory. Element counts preserved — still used by get_scaling_multiplier() which SpellCaster reads.

**New fields:**
```gdscript
var mana_pool: int = 0
var school_allocation: Dictionary = {}
var unallocated_mana: int = 0
```

**New methods:**
```gdscript
func add_mana(amount: int) -> void
    # delegates to SpecManager.allocate_mana_for_pickup()
    # fallback: adds to unallocated_mana if SpecManager unavailable

func allocate_to_school(school: String, amount: int) -> void
    # guards: amount > 0, amount <= unallocated_mana

func deallocate_from_school(school: String, amount: int) -> void
    # removes up to current allocation, returns to unallocated_mana

func get_school_tier(school: String) -> int
    # returns int(school_allocation.get(school, 0))

func get_school_multiplier(school: String) -> float
    # returns 1.0 + tier * 0.05
```

**reset_run()** updated to clear mana_pool, school_allocation, unallocated_mana.

---

### School Gating in SpellCaster (Session 2.41)
**Date:** 2026-04-10
**Decision:** SpellCaster silently skips firing if the elemental school has zero allocation. Gate is at the top of _on_cooldown_timer_timeout(), cooldown timer keeps running so the spell fires immediately once school is unlocked.

```gdscript
func _on_cooldown_timer_timeout() -> void:
    var _inventory := get_node_or_null("/root/PlayerInventory")
    if _inventory != null and _inventory.get_school_tier(elemental_element) == 0:
        return
    # ... rest of fire logic
```

**Note:** Only the elemental slot is gated. Empowerment and enchantment elements are not checked — they're modifiers, not gatekeepers.

---

### SpecData Resource (Session 2.41)
**Date:** 2026-04-10
**Decision:** Specs are .tres resources stored in res://data/specs/. Three specs created: Pyroclast (fire/thunder), Frostbinder (ice/water), Archmage (empty — manual control).

```gdscript
class_name SpecData extends Resource
@export var spec_name: String = ""
@export var description: String = ""
@export var allocation_ratios: Dictionary = {}     # {"fire": 0.6, "thunder": 0.4}
@export var preferred_slots: Array[Dictionary] = [] # [{elemental, empowerment, enchantment, delivery}]
@export var preferred_ults: Array[String] = []
```

**Dictionary key casing:** All keys in preferred_slots must be lowercase (elemental, empowerment, enchantment, delivery). Capital E on "Enchantment" will silently fail reads. Enforce this when editing .tres files in the Inspector.

**Spec files:**
- pyroclast.tres — fire 0.8 / thunder 0.2 (dummy values, partner to tune)
- frostbinder.tres — ice 0.6 / water 0.4
- archmage.tres — all empty (allocation_ratios={}, preferred_slots=[], preferred_ults=[])

**Radiant spec deferred** — not yet created. Partner to define holy/dark allocation.

---

### SpecManager Autoload (Session 2.41)
**Date:** 2026-04-10
**Decision:** SpecManager is a new autoload registered after TomeManager. Owns active spec state. Handles mana allocation on pickup according to spec ratios.

**Autoload path:** res://scripts/spec_manager.gd

**Key design:**
- Specs loaded lazily via `load(path)` on apply_spec() — not preloaded at startup
- Archmage = null spec. is_archmage() returns true when _active_spec is null OR spec_name is "Archmage"
- allocate_mana_for_pickup() distributes per ratio using floor() for each school except the last which gets the remainder — prevents mana loss from rounding

```gdscript
SpecManager.apply_spec(spec_name: String) -> void
SpecManager.clear_spec() -> void
SpecManager.get_active_spec() -> SpecData
SpecManager.get_active_spec_name() -> String
SpecManager.is_archmage() -> bool
SpecManager.allocate_mana_for_pickup(amount: int) -> void
```

**SPEC_PATHS const** in spec_manager.gd maps display names to file paths. Add new specs here when created.

---

### ControlStrip Mana Display (Session 2.41)
**Date:** 2026-04-10
**Decision:** Replaced element counter swatches (raw counts) with school tier display (T0, T1, etc.) plus a mana summary label.

**Changes to control_strip.gd:**
- `_element_count_labels` renamed to `_school_tier_labels`
- `_build_element_counters()` replaced with `_build_mana_display()`
- `update_element_counts()` replaced with `update_mana_display()`
- Tier labels show "T0", "T1" etc. (not raw counts)
- ManaPoolLabel (name node) added at y=320 in StripPanel: "Mana: X | Free: X"
- `_process()` calls `update_mana_display()` every frame — acceptable polling cost given simplicity

**Colour map preserved** — same 7 school colours as before.

---

### Known Bugs — Deferred to Session 2.42
**Date:** 2026-04-10

**Bug 1: Spell casting stops on summon death**
- Symptom: After summon dies, player's spells stop firing
- Likely cause: SummonManager emitting a signal or calling set_attack_spell(null) that propagates incorrectly into SpellCaster
- Files to investigate: summon_manager.gd, spell_caster.gd

**Bug 2: Page flip respawns summon**
- Symptom: Flipping a page while summon is recharging respawns it immediately
- Likely cause: page_flip_widget.gd or crafting_ui.gd _on_set_active_pressed() calling sm.spawn_summon() without checking is_recharged()
- Files to investigate: page_flip_widget.gd, crafting_ui.gd (_on_set_active_pressed)

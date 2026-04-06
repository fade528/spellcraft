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
**Godot version:** 4.x (update with exact version on install)
**VS Code extensions:** godot-tools
**Target platform:** Android primary, iOS secondary
**Viewport:** 1080x1920 portrait
**Physics fps:** 60
**Git remote:** TBD

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

*(Add entries here as you build. Examples below show the format.)*

---

### Player Movement
**Date:** TBD
**Decision:** CharacterBody2D with touchpad analogue input, 8-direction sprite facing
**Reason:** Touchpad gives full 360 degree vector naturally. Sprite snaps to nearest of 8 directions for visual clarity without restricting movement.
**Implementation:**
```gdscript
# Snap movement vector to 8 directions for sprite selection only
# Movement itself remains fully analogue
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

### Player Movement
Date: [6 April 2026]
Decision: CharacterBody2D with touchpad CanvasLayer
Implementation: TouchpadBase + TouchpadKnob ColorRects,
drag input via InputEventScreenDrag, 8-direction facing
via FacingMarker Polygon2D, screen clamping to 1080x1920
Notes: Player starts top-left, will centre in Game scene

---

### Enemy Spawning
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

### Scrolling Background
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
**Notes:** Current playable harness is `res://scenes/game.tscn`, which contains `ScrollingBackground`, `Player`, and `EnemySpawner`.

### Enemy Chase Behaviour
Date: 2026-04-06
Decision: Chasers disengage when player distance exceeds chase_distance (default 300px)
Reason: Without cutoff, enemies stack on player indefinitely and never despawn
Implementation: Distance check in _physics_process before normalizing direction vector.
If within chase_distance, move toward player. Otherwise fall straight down.
Notes: chase_distance is @export — tunable in inspector. Revisit during enemy tuning session.

### Collision Architecture (interim)
Date: 2026-04-06
Decision: Enemies and player both disable physical body collision with each other for now
Reason: move_and_slide() caused stacking. Damage will come via Area2D hurtboxes in Session 1.4
Implementation: set_collision_mask_value(1/2, false) in _ready() on both enemy and player
Notes: Remove this when hurtboxes are implemented in 1.4 — physical layers should be restored
---

### Spell System
Date: 2026-04-06
Decision: Spells use `SpellData` resources for tuning, a `SpellCaster` child on the player for auto-fire, and `Area2D` projectiles against enemy hurtboxes.
Reason: This keeps spell balance data separate from runtime casting logic and matches the planned layer-4/layer-5 hurtbox architecture.
Implementation: `res://scripts/spell_data.gd` defines `damage`, `cooldown`, and `projectile_speed`.
`res://scripts/spell_caster.gd` runs a cooldown Timer, aims at the nearest node in group `enemies`, and instantiates `res://scenes/spell_projectile.tscn`.
`res://scripts/spell_projectile.gd` moves upward by default, can be aimed toward a target, emits a hit signal, and damages enemies through their hurtbox `Area2D`.
Notes: Starter spell resource is `res://resources/spells/basic_bolt.tres`. Enemies now have a layer-4 hurtbox child and a `take_damage(amount)` method with exported `max_hp`.

### Life System + HP Bar (Session 1.4 — complete)
**Date:** 2026-04-06
**Decision:** Single HP bar owned by ProgressionManager autoload. Lives are retained as a
second layer — losing all HP costs one life, refills HP to max, and triggers respawn.
Three lives lost triggers game over.
**Reason:** HP bar is more future-proof than lives-only for a roguelite where spells, items,
and enemies will deal variable damage amounts.
**Implementation:**
ProgressionManager (autoload at /root/ProgressionManager) owns `lives`, `current_hp`,
`max_hp`. Exposes `take_damage(amount)`, `lose_life()`, `refill_hp()`, `reset_run()`.
Emits `hp_changed(current_hp, max_hp)` and `life_lost(lives_remaining)` and `game_over`.

player.gd enforces iframes locally, then delegates to ProgressionManager.take_damage().
player_hurtbox.gd (Area2D layer 3, mask 2) detects enemy body overlap and calls
player.take_damage(contact_damage). contact_damage is @export, default 10.0.

game.gd connects life_lost → clears enemies/projectiles groups → calls player.respawn().
Connects game_over → change_scene_to_file game_over.tscn.
game_over.gd calls ProgressionManager.reset_run() before returning to game.tscn.

HUD shows three ColorRect life icons + ProgressBar (HPBar) + Label (HPLabel, format "100 / 100").
All HUD nodes reference ProgressionManager via get_node_or_null("/root/ProgressionManager")
rather than the bare global name — workaround for a UID autoload registration issue when
editing scripts externally in VS Code.

**Notes:**
- iframe_duration is @export on player.gd, default 1.5s. Tunable in inspector.
- max_hp and starting_lives are @export on ProgressionManager. Tunable in inspector.
- Autoload must be registered via Godot editor UI (Project → Project Settings → Globals →
  Autoload), not by editing project.godot directly — direct edits produce a UID reference
  that Godot can't resolve. If the path shows as blank in the Autoload tab, delete and
  re-add the entry.
- All scripts use get_node_or_null("/root/ProgressionManager") as the safe fetch pattern.
  Do not revert to bare ProgressionManager global references until the UID issue is confirmed
  resolved.
- Projectile-to-player damage not yet implemented (no layer-5 → layer-3 mask). Add in a
  future combat session.

  ### Audio — Session 1.5
**Date:** 2026-04-06

**Decision:** All audio nodes were pre-wired in Session 1.5 SFX change. 
This entry confirms streams are now assigned.

**SFX (AudioStreamPlayer nodes in game.tscn)**
- `SpellHitSFX` — spell_hit.wav assigned, plays on spell hit signal
- `PlayerHurtSFX` — hurt.wav assigned, plays on hp_changed decrease
- `EnemyDeathSFX` — popenemydeath.wav assigned, plays on enemy died signal
- All SFX as .wav format

**Background Music (AudioStreamPlayer in game.tscn)**
- BGMusic — assigned mischeifaudop.wav .wav, autoplay on, loop on

**File locations**
res://assets/audio/sfx/spell_hit.wav
res://assets/audio/sfx/hurt.wav
res://assets/audio/sfx/popenemydeath.wav
res://assets/audio/music/mischeifaudop.wav

**Notes:**
- SFX use .wav (low latency, better for short one-shots)
- Music uses .ogg (compressed, better for looping tracks)
- No AudioBus mixing yet — all playing on Master bus. 
  Separate SFX/Music buses come in Session 4.5 audio pass.
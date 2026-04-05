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

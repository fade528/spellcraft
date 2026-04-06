# Spellcraft Roguelite — Session Plan

> Session management guide. Each session is a separate chat.
> Always open every session with: "Read context.md first. [then your task]"
> For code sessions also include: current scene tree + relevant existing code
> Always specify "Godot 4 GDScript" in every prompt.

---

## How to Start Every Session

```
"Read context.md first. [task description]
Godot 4 GDScript.
Current scene tree: [paste]
Relevant existing code: [paste if applicable]"
```

---

## Phase 0 — Setup
**Status: ✅ Complete**

Environment configured:
- Godot 4.6.2, Mobile renderer, 1080x1920 portrait
- VS Code + godot-tools + Codex
- Claude Code installed (auth pending Max subscription)
- Git + GitHub at github.com/fade528/spellcraft
- All MD files in project root

---

## Phase 1 — Alpha Build
**Target: Movement + enemies + auto-cast spell. Placeholder art only.**

### Session 1.1 — Player Scene
**Status: ⏳ Next**
```
Read context.md first. Build Week 2 player scene —
CharacterBody2D, touchpad movement, 8 direction
facing, screen clamping, 1080x1920. Godot 4 GDScript.
```
**Delivers:** Player rectangle moves smoothly on canvas, stays in bounds

---

### Session 1.2 — Enemy Spawning
```
Read context.md first. Build Week 3 enemy spawner —
Chaser enemy, downward movement, repeating Timer,
despawn at bottom edge, scrolling background.
Godot 4 GDScript.
```
**Delivers:** Enemies scroll down, chaser follows player, background loops

---

### Session 1.3 — Spell System
```
Read context.md first. Build Week 4 spell system —
SpellData resource class, SpellProjectile Area2D,
SpellCaster auto-aim and auto-fire on cooldown,
nearest enemy targeting. Godot 4 GDScript.
```
**Delivers:** Player auto-fires toward nearest enemy, enemy takes damage and dies

---

### Session 1.4 — Life System + HUD
```
Read context.md first. Build Week 5 life system —
Player hurtbox Area2D, iframe system, contact damage
on enemies, ProgressionManager with 3 lives,
CanvasLayer HUD, game over state and restart.
Godot 4 GDScript.
```
**Delivers:** Full game loop — spawn, fight, take damage, lose lives, game over, restart

---

### Session 1.5 — Alpha Polish + APK
```
Read context.md first. Week 6 juice pass —
hit flash on enemy damage, death particles,
screen shake on player hit, placeholder SFX,
background music loop, build APK for Android.
Godot 4 GDScript.
```
**Delivers:** Playable APK in partner's hands for feel testing

---

## Phase 2 — Core Systems
**Target: Spell crafting, enemy variants, element drops, progression**

### Session 2.1 — Spell Combo Architecture
```
Read context.md and systems.md first. Design and build
the 4-part spell combination system —
element + modifier + finisher + delivery,
order matters, first 6-8 combos defined.
Godot 4 GDScript.
```
**Delivers:** Working spell combo system, combos produce different projectile behaviours

---

### Session 2.2 — Crafting UI
```
Read context.md and systems.md first. Build the
pause and crafting UI — spell slot display,
element inventory panel, combo construction,
free experimentation, no punishment on change.
Godot 4 GDScript.
```
**Delivers:** Player can pause, view elements, construct spells, resume

---

### Session 2.3 — Enemy Variants
```
Read context.md and systems.md first. Build Shooter
and Tank enemy types extending existing enemy
architecture. Shooter fires projectiles at player,
Tank has high HP and slow movement.
Godot 4 GDScript.
```
**Delivers:** Three enemy types — Chaser, Shooter, Tank

---

### Session 2.4 — Element Drop System
```
Read context.md and systems.md first. Build element
drop system — enemies emit drop signal on death,
ElementDrop scene spawns at position, player
collects via Area2D overlap, updates inventory.
Godot 4 GDScript.
```
**Delivers:** Enemies drop elements, player collects, inventory updates

---

### Session 2.5 — Spell Slot Progression
```
Read context.md and systems.md first. Build level
progression system — Levels 1-4 unlock additional
spell slots on boss defeat, no stat inflation,
ProgressionManager handles unlock logic.
Godot 4 GDScript.
```
**Delivers:** Beating bosses unlocks spell slots 1 through 4

---

## Phase 3 — Boss System
**Target: Full boss loop with metrics and retry**

### Session 3.1 — Boss State Machine
```
Read context.md and systems.md first. Build boss
state machine in GameManager — SCROLLING to
BOSS_PREP transition, arena forms, scrolling stops,
preparation phase allows relearn.
Godot 4 GDScript.
```
**Delivers:** Clean state transition from scrolling phase to boss arena

---

### Session 3.2 — First Boss Implementation
```
Read context.md and systems.md first. Implement
first boss — 2-3 attack patterns, phase transition
at 50% HP, health bar, death sequence,
signals to GameManager. Godot 4 GDScript.
```
**Delivers:** Playable first boss with distinct attack phases

---

### Session 3.3 — Boss Metrics System
```
Read context.md and systems.md first. Build boss
death metrics screen — CombatManager tracks damage
sources during fight, BossMetrics UI displays
after death, damage by source, status uptime,
build note. Godot 4 GDScript.
```
**Delivers:** Metrics screen shown after boss death with actionable data

---

### Session 3.4 — Boss Retry Loop
```
Read context.md and systems.md first. Polish boss
retry loop — relearn allowed before retry,
boss resets cleanly, lives system integrated,
metrics inform adjustment before next attempt.
Godot 4 GDScript.
```
**Delivers:** Complete boss retry loop — die, review, adjust, retry

---

## Phase 4 — Progression + Polish
**Target: Full level arc, ultimate, paragon, art, audio, performance**

### Session 4.1 — Full Level Progression
```
Read context.md and systems.md first. Build full
level 1-6 progression — boss defeat triggers level
advance, spell slots 1-4 unlock sequentially,
level 5 unlocks ultimate, level 6 upgrades it.
Godot 4 GDScript.
```

---

### Session 4.2 — Ultimate Ability
```
Read context.md and systems.md first. Design and
build ultimate ability — manual trigger button,
Level 5 unlock, Level 6 upgrade path,
fits existing spell combo philosophy.
Godot 4 GDScript.
```

---

### Session 4.3 — Paragon Generator
```
Read context.md and systems.md first. Build paragon
generator for Level 21+ — difficulty budget system,
weighted random enemy selection, weighted boss pool,
scaling values per paragon level.
Godot 4 GDScript.
```

---

### Session 4.4 — Full Art Pass
```
Read context.md and systems.md first. Replace all
placeholder rectangles with final sprites —
player 8 directional spritesheet, boss animations,
mob sprite sheets, UI elements.
Godot 4 GDScript.
```

---

### Session 4.5 — Audio Pass
```
Read context.md and systems.md first. Implement
full audio — background music per zone using
AudioStreamPlayer, spell SFX, hit impacts,
boss music, UI sounds, AudioBus mixing.
Godot 4 GDScript.
```

---

### Session 4.6 — Performance + Mobile Polish
```
Read context.md and systems.md first. Mobile
optimisation pass — draw call reduction, particle
limits on low end devices, shader simplification,
APK size reduction, test on low end Android.
Godot 4 GDScript.
```

---

## Phase 5 — Release
**Target: Live on Google Play and App Store**

### Session 5.1 — Google Play Submission
```
Read context.md first. Guide me through Google Play
store submission — APK signing, keystore setup,
store listing, screenshots, content rating, pricing.
```

---

### Session 5.2 — iOS App Store Submission
```
Read context.md first. Guide me through iOS App Store
submission — Godot iOS export setup, signing
certificates, TestFlight beta, App Store listing.
```

---

### Session 5.3 — Post Launch
```
Read context.md first. Post launch plan —
monitoring reviews, paragon content updates,
player feedback integration, update cadence.
```

---

## Ongoing Sessions — Use Any Time

### Debugging
```
Read context.md and systems.md first.
I have a bug: [describe exact behaviour]
Error message: [paste]
Relevant code: [paste]
Scene tree: [paste]
Godot 4 GDScript.
```

### Architecture Decision
```
Read context.md and systems.md first.
I need to decide how to implement [feature].
Current relevant architecture: [paste systems.md section]
Options I'm considering: [describe]
Godot 4 GDScript.
```

### Partner Feedback Translation
```
Read context.md first.
Partner feedback from latest playtest:
[paste feedback.md session]
Convert into prioritised technical tasks.
Flag anything that requires architecture changes.
```

### Performance Issue
```
Read context.md and systems.md first.
Performance issue on [device].
Current FPS: [X], target 60.
Godot profiler shows: [paste]
Relevant scene: [paste scene tree]
Godot 4 GDScript.
```

### Code Review
```
Read context.md and systems.md first.
Review this GDScript for correctness,
Godot 4 best practices, and alignment
with our architecture decisions:
[paste code]
```

---

## Session Status Tracker

| Session | Status | Notes |
|---|---|---|
| 0 — Setup | ✅ Complete | Environment fully configured |
| 1.1 — Player Scene | ✅ Complete | Player moves, boundaries work, orange triangle placeholder |
| 1.2 — Enemy Spawning | ✅ Complete | enemies spawn, chase player, added aggro radius |
| 1.3 — Spell System | ✅ Complete | spells fire correctly and enemies despawn after hit |
| 1.4 — Life System | ✅ Complete | added hp bar yo |
| 1.5 — Alpha Polish | ✅ Complete | Full juice pass done. All audio assigned. APK exported and tested on device. |
| 2.1 — Spell Combos | ⏳ Next | Start here |
| 2.2 — Crafting UI | ⬜ Pending | |
| 2.3 — Enemy Variants | ⬜ Pending | |
| 2.4 — Element Drops | ⬜ Pending | |
| 2.5 — Spell Slots | ⬜ Pending | |
| 3.1 — Boss State Machine | ⬜ Pending | |
| 3.2 — First Boss | ⬜ Pending | |
| 3.3 — Boss Metrics | ⬜ Pending | |
| 3.4 — Boss Retry Loop | ⬜ Pending | |
| 4.1 — Level Progression | ⬜ Pending | |
| 4.2 — Ultimate Ability | ⬜ Pending | |
| 4.3 — Paragon Generator | ⬜ Pending | |
| 4.4 — Art Pass | ⬜ Pending | |
| 4.5 — Audio Pass | ⬜ Pending | |
| 4.6 — Performance | ⬜ Pending | |
| 5.1 — Google Play | ⬜ Pending | |
| 5.2 — iOS App Store | ⬜ Pending | |
| 5.3 — Post Launch | ⬜ Pending | |

---

> Update status column as sessions complete.
> Add notes on key decisions made in each session.
> These notes feed into systems.md.


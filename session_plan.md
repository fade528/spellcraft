# Spellcraft Roguelite — Session Plan

> Session management guide. Each session is a separate chat.
> Always open every session with: "Read context.md and systems.md first. [then your task]"
> For code sessions also include: current scene tree + relevant existing code
> Always specify "Godot 4 GDScript" in every prompt.

---

## How to Start Every Session

```
"Read context.md and systems.md first. [task description]
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
**Status: ✅ Complete**

### Session 1.1 — Player Scene ✅
### Session 1.2 — Enemy Spawning ✅
### Session 1.3 — Spell System ✅
### Session 1.4 — Life System + HUD ✅
### Session 1.5 — Alpha Polish + APK ✅

---

## Phase 2 — Core Systems

### Session 2.1 — Spell Combo Architecture
**Status: ✅ Complete**

Key decisions:
- Slot names: Elemental / Empowerment / Enchantment / Summon
- All spell data in res://data/spell_elements.csv — Google Sheets only
- Autoloads: PlayerInventory, SpellComposer, SummonManager
- Damage formula: item_base_dmg x elemental_mult x weakness_mult x emp_mult x enc_mult
- Holy/Dark fire on stop, not auto-cast
- Summon slot independent, one active at a time
- AoE excludes primary hit target
- apply_burn on enemy with repeating Timer
- Equipment slots stubbed in PlayerInventory

Verified: Fire+Fire+Fire total_cd=3.0, dmgmult_chain=1.2, burn ticks and AoE working.

---

### Session 2.2 — Tome, Pages + Crafting UI

**Status: ✅ Complete**

Key decisions:
- TomeManager autoload, max 8 pages, JSON persistence
- PageData resource: slots, summon_element, ult1, ult2
- CraftingUI: pauses game, Escape to open, Edit→Craft rename
- Set Active bypasses flip cooldown gate directly
- child.free() not queue_free() to prevent duplicate buttons
- PageFlipWidget: edge swipe gesture (0-10%, 90-100% of strip)
- Grid always centre screen, drag direction decoupled from press point
- _select_start resets when finger enters mid zone (10-90%)
- ControlStrip: bottom 20%, shows page/CD/summon, touchpad lives here
- Input zones: 0-10% flip, 10-90% touchpad, 90-100% flip
- player.gd uses _input(), page_flip_widget.gd uses _input() with zone guards
- Player clamps to top 80% viewport, RESPAWN_POSITION = (540, 1400)
- .tscn files must never be rewritten by Codex — UID breaks scene

---

### Session 2.3 — Enemy Variants + Status Effects
**Status: ⬜ Pending**

**Note before starting:** player.gd uses _input() not _unhandled_input(). Enemy status methods are guarded by has_method(). Control strip bottom 20% must not be obstructed by enemy projectiles or effects. Paste current scene tree and enemy.gd + summon_manager.gd when opening.
Read context.md and systems.md first. Build Shooter
and Tank enemy types. Also implement all pending
status methods so spell effects land correctly.
Also implement SummonManager fully.
Existing enemy has: take_damage(), apply_burn()
Add to ALL enemy types:

apply_slow(amount, duration)
apply_stagger(chance, duration)
apply_brittle(freeze_duration, dmg_mult) — requires chilled
apply_chain(targets) — bounce to nearby enemies
apply_pushback(distance)
apply_blind(duration)
execute(chance) — instant kill, no bosses
get_element() -> String
apply_wet(), apply_corruption(), apply_chill()

SummonManager full implementation:

Summon follows player at 50px offset
Summon mimics player slot 1 spell on its own attack timer
Summon has HP, takes damage, dies and starts recharge timer
Recharge times from CSV: most = 60s, Thunder = 20s

Shooter enemy:

Fires projectile at player every 3s
Range 400px, disengages beyond range
Projectile uses existing spell_projectile scene

Tank enemy:

5x base HP, 0.4x speed
Contact damage 25
Same hurtbox/layer setup as Chaser

---

### Session 2.4 — Element Drop System
**Status: ⬜ Pending**

```
Read context.md and systems.md first. Build element
drop system — enemies drop elements on death,
ElementDrop scene spawns at position, player
collects via Area2D overlap, updates PlayerInventory.

Each enemy has an exported element_drop: String.
ElementDrop is a small coloured circle on Layer 6.
Player pickup via Area2D overlap.
Calls PlayerInventory.add_element(element).

Godot 4 GDScript.
Current scene tree: [paste]
Relevant code: [paste enemy.gd, player_inventory.gd]
```

**Delivers:** Enemies drop elements, player collects, scaling multiplier increases

---

### Session 2.5 — Spell Slot Progression
**Status: ⬜ Pending**

```
Read context.md and systems.md first. Build spell slot
progression — ProgressionManager tracks level,
beating a boss advances level, levels 1-4 each
unlock one additional SpellCaster on the player.

Level unlocks:
Lv1 = 1 slot (default), Lv2 = 2, Lv3 = 3, Lv4 = 4
Lv5 = Ultimate (Session 4.2), Lv6 = Ultimate upgrade

SpellCaster nodes pre-built on player but disabled.
ProgressionManager.advance_level() enables next one
and signals crafting UI to show the new slot.

Godot 4 GDScript.
Current scene tree: [paste]
Relevant code: [paste progression_manager.gd, spell_caster.gd]
```

**Delivers:** Beating bosses unlocks spell slots 1 through 4

---

## Phase 3 — Boss System

### Session 3.1 — Boss State Machine ⬜
### Session 3.2 — First Boss Implementation ⬜
### Session 3.3 — Boss Metrics System ⬜
### Session 3.4 — Boss Retry Loop ⬜

(Prompts unchanged from original — update when entering Phase 3)

---

## Phase 4 — Progression + Polish

### Session 4.1 — Full Level Progression ⬜
### Session 4.2 — Ultimate Ability ⬜
### Session 4.3 — Paragon Generator ⬜

### Session 4.4 — Item System
**Status: ⬜ Pending**

```
Read context.md and systems.md first. Build the item
system — 5 equipment slots (hat, robe, gloves, boots,
weapon), items drop from bosses only.

Equipment slots already stubbed in PlayerInventory.
Need: EquipmentData resource, item drop scene,
pickup logic, equip logic, stat application.

Slot primary stats:
Hat = +Max HP
Robe = +Damage %
Gloves = +Cast speed
Boots = +Move speed
Weapon = +Base damage (feeds item_base_dmg in SpellCaster)

Secondary stats per slot defined in equipment.csv (Phase 4).
Items drop exclusively from boss kills, one item per kill.

Godot 4 GDScript.
Current scene tree: [paste]
Relevant code: [paste player_inventory.gd, spell_caster.gd,
progression_manager.gd]
```

**Delivers:** Boss drops items, player equips them, stats apply

### Session 4.5 — Full Art Pass ⬜
### Session 4.6 — Audio Pass ⬜
### Session 4.7 — Performance + Mobile Polish ⬜

---

## Phase 5 — Release

### Session 5.1 — Google Play Submission ⬜
### Session 5.2 — iOS App Store Submission ⬜
### Session 5.3 — Post Launch ⬜

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
Read context.md and systems.md first.
Partner feedback from latest playtest: [paste]
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
| 1.1 — Player Scene | ✅ Complete | Player moves, boundaries work, orange triangle |
| 1.2 — Enemy Spawning | ✅ Complete | Enemies spawn, chase player, aggro radius |
| 1.3 — Spell System | ✅ Complete | Spells fire, enemies take damage and die |
| 1.4 — Life System | ✅ Complete | HP bar, 3 lives, game over, restart |
| 1.5 — Alpha Polish | ✅ Complete | Juice pass, audio, APK tested on device |
| 2.1 — Spell Combos | ✅ Complete | CSV system, 3 autoloads, Fire+Fire+Fire verified, DoT and AoE working |
| 2.2 — Tome + Crafting UI | ✅ Complete | TomeManager, PageData, CraftingUI pause menu, PageFlipWidget edge-swipe, ControlStrip, persistent JSON save, rename/delete/set active, input zones 0-10/10-90/90-100% |
| 2.3 — Enemy Variants | ⬜ Pending | Includes all status effects + full summon AI |
| 2.4 — Element Drops | ⬜ Pending | |
| 2.5 — Spell Slots | ⬜ Pending | |
| 3.1 — Boss State Machine | ⬜ Pending | |
| 3.2 — First Boss | ⬜ Pending | |
| 3.3 — Boss Metrics | ⬜ Pending | |
| 3.4 — Boss Retry Loop | ⬜ Pending | |
| 4.1 — Level Progression | ⬜ Pending | |
| 4.2 — Ultimate Ability | ⬜ Pending | |
| 4.3 — Paragon Generator | ⬜ Pending | |
| 4.4 — Item System | ⬜ Pending | New — hats, robes, gloves, boots, weapons |
| 4.5 — Art Pass | ⬜ Pending | |
| 4.6 — Audio Pass | ⬜ Pending | |
| 4.7 — Performance | ⬜ Pending | Renumbered from 4.6 |
| 5.1 — Google Play | ⬜ Pending | |
| 5.2 — iOS App Store | ⬜ Pending | |
| 5.3 — Post Launch | ⬜ Pending | |

---

> Update status column as sessions complete.
> Add notes on key decisions made in each session.
> These notes feed into systems.md.

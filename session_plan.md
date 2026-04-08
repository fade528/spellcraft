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
**Status: ⏳ Next**

```
Read context.md and systems.md first. Build the Tome
and Page system with integrated crafting UI.

== TOME AND PAGE SYSTEM ==

A Tome holds up to 10 Pages. Each Page is a complete
saved build: 4 spell slots + 1 summon + 2 ultimates.

Create TomeManager autoload at
res://scripts/managers/tome_manager.gd.

Inner class PageData:
  var page_name: String = "Page 1"
  var slots: Array[Dictionary] = []
  # each slot dict: { elemental, empowerment,
  #   enchantment, delivery, target }
  var summon_element: String = "fire"
  var ult1: String = ""
  var ult2: String = ""

TomeManager vars:
  var pages: Array = []       # max 10 PageData
  var active_page_index: int = 0
  var _flip_cooldown: float = 0.0
  var _can_flip: bool = true

TomeManager methods:
  func can_flip_page() -> bool
    # true if _flip_cooldown <= 0.0
    # AND SummonManager.is_recharged() == true

  func flip_to_page(index: int) -> void
    # guard: can_flip_page() must be true
    # call refresh_spell() on each SpellCaster
    # call SummonManager.spawn_summon()
    # set _flip_cooldown = longest total_cd across
    # all active SpellCasters

  func _process(delta: float) -> void
    # count down _flip_cooldown

  func save_page(index: int, page: PageData) -> void
  func get_page(index: int) -> PageData
  func get_active_page() -> PageData
  func add_page() -> void   # adds blank page if < 10

Add to SummonManager:
  func is_recharged() -> bool
    # true if summon is alive OR recharge timer complete

== CRAFTING UI ==

Build a pause menu CanvasLayer with two views:

VIEW 1 — TOME VIEW (default on pause):
- Scrollable list of all pages (up to 10)
- Each page shows its name + element summary
- Tap page to select it
- "Flip to this page" button — greyed with remaining
  time shown if page flip is gated
- "Edit page" opens View 2
- "New page" creates blank page
- Resume button

VIEW 2 — PAGE EDITOR:
- 4 spell slot rows (slot 1 active, 2-4 greyed if locked)
- Each row has 4 pickers: Elemental / Empowerment /
  Enchantment / Delivery
- Tap any picker to open element or delivery selector
- Summon picker row: tap to change summon element
- Stats panel: total_cd, total_budget, dmgmult_chain
  shown per active slot
- "Save page" writes back to TomeManager
- Back button returns to Tome View

Start with 1 spell slot active (2-4 visible but locked).
Elements: Fire, Ice, Earth, Thunder, Water, Holy, Dark.
Deliveries: Bolt, Burst, Beam, Blast, Cleave,
Missile, Wall, Utility.

Key APIs:
  SpellCaster.refresh_spell(elemental, empowerment,
    enchantment, delivery, target)
  SummonManager.spawn_summon(element)
  SummonManager.is_recharged() -> bool
  TomeManager.can_flip_page() -> bool
  TomeManager.flip_to_page(index)

Register TomeManager in Autoload after SummonManager.

Godot 4 GDScript.
Current scene tree: [paste]
Relevant code: [paste spell_caster.gd,
spell_composer.gd, summon_manager.gd]
```

**Delivers:** Tome with 10 pages, page editor, mid-combat page flipping gated by spell CD and summon recharge

---

### Session 2.3 — Enemy Variants + Status Effects
**Status: ⬜ Pending**

```
Read context.md and systems.md first. Build Shooter
and Tank enemy types. Also implement all pending
status methods so spell effects land correctly.

Existing enemy has: take_damage(), apply_burn()
Add to ALL enemy types:
- apply_slow(amount, duration)
- apply_stagger(chance, duration)
- apply_brittle(freeze_duration, dmg_mult) — requires chilled
- apply_chain(targets) — bounce to nearby enemies
- apply_pushback(distance)
- apply_blind(duration)
- execute(chance) — instant kill, no bosses
- get_element() -> String
- apply_wet(), apply_corruption(), apply_chill()

Also implement SummonManager fully:
- Summon follows player at 50px
- Summon mimics player slot 1 spell on its attack timer
- Summon takes damage and dies, recharges after cd

Shooter: fires at player every 3s, range 400px.
Tank: 5x HP, 0.4x speed, contact damage 25.

Godot 4 GDScript.
Current scene tree: [paste]
Relevant code: [paste enemy.gd, summon_manager.gd]
```

**Delivers:** Three enemy types, all status effects functional, summon AI working

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
| 2.2 — Tome + Crafting UI | ⏳ Next | Tome system + page editor combined |
| 2.3 — Enemy Variants | ⬜ Pending | Now includes all status effects + summon AI |
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

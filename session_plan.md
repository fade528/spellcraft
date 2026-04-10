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

### Session 2.1 — Spell Combo Architecture ✅
### Session 2.2 — Tome, Pages + Crafting UI ✅
### Session 2.3 — Enemy Variants + Status Effects + Summon AI ✅
### Session 2.4 — Element Drop System ✅

---

### Session 2.41 — Mana & School System ✅ COMPLETE
**Date:** 2026-04-10

Delivered:
- element_drop.gd → generic mana orb (light blue, no element property)
- PlayerInventory: mana_pool, school_allocation, unallocated_mana, full allocation API
- SpellCaster: school gate at top of _on_cooldown_timer_timeout()
- SpecData resource class (spec_data.gd)
- SpecManager autoload (spec_manager.gd) — auto-allocation per spec ratios
- ControlStrip: school tier display (T0–Tn) + mana summary label
- Spec .tres files: pyroclast.tres, frostbinder.tres, archmage.tres
- enemy.gd / shooter.gd / tank.gd: call_deferred("add_child") fix for physics callback

Deferred to 2.42:
- CraftingUI redesign (Spec tab + Tome tab)
- Full spec editor (spell slots, school swatches, ult pickers)
- JSON persistence for specs
- Tome page override flag

Known bugs logged (deferred to 2.42):
- Spell casting stops when summon dies
- Page flip respawns summon when recharging

---

### Session 2.42 — CraftingUI Redesign (NEXT)

```
Read context.md and systems.md first.
Godot 4 GDScript.
Session 2.42 — CraftingUI Redesign

Two known bugs to fix first (warm-up):
1. Spells stop casting when summon dies — investigate summon_manager.gd and spell_caster.gd
2. Page flip respawns summon during recharge — investigate page_flip_widget.gd and crafting_ui.gd _on_set_active_pressed()

Then redesign CraftingUI as a two-tab layout: Spec (default) / Tome.

SPEC TAB:
- List of up to 5 named spec slots + Archmage (always present, not deletable)
- Each row: spec name, Activate button (dimmed if active), Edit button, Delete button
- Empty slots are dimmed
- Inner spec editor:
  - 4 spell rows: elemental / empowerment / enchantment / delivery dropdowns
  - Summon picker (element dropdown)
  - 2 ult pickers (placeholder dropdown for now)
  - 7 school swatches with +/- buttons and tier labels
  - Mana: X | Free: X summary label
  - Save / Cancel buttons
- JSON persistence: specs saved to user://specs.json, loaded on startup

TOME TAB:
- Existing page list (preserve all current functionality)
- Each page row shows "★ Spec" or "✎ Override" indicator
- Setting a page active resets override flag
- Activating a spec repopulates non-overridden pages with preferred_slots

Archmage note: no preferred slots, school swatches visible directly in spec view for manual allocation.

Relevant files to paste:
crafting_ui.gd, spec_manager.gd, spec_data.gd, player_inventory.gd, tome_manager.gd
```

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

---

## Phase 3 — Boss System

### Session 3.1 — Boss State Machine ⬜
### Session 3.2 — First Boss Implementation ⬜
### Session 3.3 — Boss Metrics System ⬜
### Session 3.4 — Boss Retry Loop ⬜

---

## Phase 4 — Progression + Polish

### Session 4.1 — Full Level Progression ⬜
### Session 4.2 — Ultimate Ability ⬜
### Session 4.3 — Paragon Generator ⬜

### Session 4.4 — Item System ⬜

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
| 2.2 — Tome + Crafting UI | ✅ Complete | TomeManager, PageData, CraftingUI, PageFlipWidget, ControlStrip, JSON save, input zones |
| 2.3 — Enemy Variants | ✅ Complete | Shooter + Tank, all status effects, weighted spawner, summon trail/HP/attack/recharge, crit pop, UI layout |
| 2.4 — Element Drops | ✅ Complete | Element drop system, summon HP bar, element counter HUD |
| 2.41 — Mana & School System | ✅ Complete | Generic mana orbs, mana pool, school gating, SpecData, SpecManager, mana HUD. CraftingUI redesign deferred to 2.42 |
| 2.42 — CraftingUI Redesign | ⬜ Pending | Spec tab + Tome tab, spec editor, JSON persistence, 2 bug fixes |
| 2.5 — Spell Slots | ⬜ Pending | |
| 3.1 — Boss State Machine | ⬜ Pending | |
| 3.2 — First Boss | ⬜ Pending | |
| 3.3 — Boss Metrics | ⬜ Pending | |
| 3.4 — Boss Retry Loop | ⬜ Pending | |
| 4.1 — Level Progression | ⬜ Pending | |
| 4.2 — Ultimate Ability | ⬜ Pending | |
| 4.3 — Paragon Generator | ⬜ Pending | |
| 4.4 — Item System | ⬜ Pending | |
| 4.5 — Art Pass | ⬜ Pending | |
| 4.6 — Audio Pass | ⬜ Pending | |
| 4.7 — Performance | ⬜ Pending | |
| 5.1 — Google Play | ⬜ Pending | |
| 5.2 — iOS App Store | ⬜ Pending | |
| 5.3 — Post Launch | ⬜ Pending | |
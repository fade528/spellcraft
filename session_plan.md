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
- CraftingUI: pauses game, Escape to open
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

### Session 2.3 — Enemy Variants + Status Effects + Summon AI
**Status: ✅ Complete**

Key decisions:
- Shooter: patrols Y 200-900px, fires every 3s within 400px, projectile clamped (dir.y <= 0)
- Tank: 100 HP, speed 60, chase 600px, contact 25 damage
- Weighted spawner: chaser/shooter/tank weights, null scenes skipped
- All status effects on all three enemy types (slow, stagger, brittle, chain, pushback, blind, execute, wet, corruption, chill)
- `mini()` not `min()` for int comparisons — avoids Variant inference errors
- `call_deferred("queue_free")` needed in physics callbacks (not yet applied — known deferred fix)
- Summon trail: path-history follow (TRAIL_RECORD_DIST=8px, TRAIL_FOLLOW_DIST=60px, move_toward 200px/s)
- Summon attack: nearest enemy 350px, dmgmult_chain*10 damage, synced to slot 1 via set_attack_spell()
- Summon HP from CSV, 5 damage per enemy contact, auto-respawn on recharge timeout
- spawn_summon uses call_deferred(add_child) — called during _ready() tree setup
- Crit numbers: gold pop effect (52→68→56px, hold, fade) vs normal upward drift
- UI: HP/lives in ControlStrip, 4 action buttons at y=1400 (above strip), boss bar hidden
- Old HUD MarginContainer visible=false

---

## Session 2.4 — Element Drop System + Summon HUD ✅ COMPLETE
Date: 2026-04-10
All goals delivered:
- Element drop system working (20% drop, collect, floating label)
- Summon HP bar + recharge display in ControlStrip
- Element counter HUD (7 swatches, live counts)
- Mana/School system designed, deferred to 2.5

---

## Session 2.5 — Mana & School System (NEXT)

Context: Design pivot from element drops to universal mana drops allocated into elemental schools.

Goals:
1. MANA DROP SYSTEM
   - Replace element_drop with mana_drop (single neutral orb, white/blue colour)
   - PlayerInventory: add mana_pool (total), school_allocation Dict, unallocated_mana
   - add_mana() replaces add_element()
   - get_school_tier(school) -> int returns allocation count
   - get_school_multiplier(school) -> float returns 1.0 + tier * 0.05

2. SCHOOL GATING
   - SpellCaster checks get_school_tier(element) > 0 before casting
   - Greyed out indicator in ControlStrip if school locked

3. SPEC SYSTEM
   - SpecData resource: spec_name, allocation_ratios Dict, preferred_slots Array, preferred_ults Array
   - SpecManager autoload: apply_spec(spec), get_active_spec(), clear_spec() (Archmage mode)
   - Auto-allocation: on mana pickup, distribute per spec ratios
   - Spec selection screen or CraftingUI tab

4. REALLOCATION UI
   - CraftingUI tab for manual school allocation
   - Show current tier per school, unallocated mana pool
   - +/- buttons per school

Pre-session requirements:
- Partner defines 3-4 Specs with allocation ratios and preferred spell IDs
- Agree tier scaling formula (currently proposed: 1.0 + tier * 0.05)

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
| 2.3 — Enemy Variants | ✅ Complete | Shooter + Tank, all status effects, weighted spawner, summon trail/HP/attack/recharge, crit pop, UI layout, bugfix for Summon hit radius, projectile invun, contact logic | 
| 2.4 — Element Drops | ⬜ Pending | | also reminder to add a summon hp bar
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

---

> Update status column as sessions complete.
> Add notes on key decisions made in each session.
> These notes feed into systems.md.

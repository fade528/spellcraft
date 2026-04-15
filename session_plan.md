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

---

### Session 2.42 — CraftingUI Redesign ✅ COMPLETE
**Date:** 2026-04-10

Delivered:
- Bug fix: Spells stop after summon death — school gate now checks school_allocation.is_empty()
- Bug fix: Page flip respawns summon during recharge — is_recharged() guard in crafting_ui and flip_to_page
- Bug fix: Rapid-fire spells on page flip — _configure_cooldown_timer only starts if timer is stopped
- Bug fix: Page flip blocked during summon recharge — summon recharge removed from can_flip_page()
- Bug fix: Shooter projectiles not hitting player — collision mask fix (set_collision_mask_value)
- Bug fix: Shooter projectiles not hitting summon — mask 6 added, spell_projectile routes layer 6 to SummonManager
- CraftingUI: Single Spec tab, all UI built in code, no .tscn changes
- Spec list: Archmage (top) + 5 built-in slots + 5 custom slots (My Specs)
- Spec editor: slot pickers, summon/ult pickers, ratio % inputs, live mana allocation controls
- Per-spec tome: each spec owns pages_specname.json, switching specs saves/loads automatically
- Mana system: all pickups bank to unallocated_mana, player allocates via Reset/Alloc Remaining %/Alloc All %
- PageData.is_overridden: ~ prefix = spec-driven, * prefix = manually edited
- Save as Spec from Archmage: copies pages + allocation to new custom spec slot
- TomeManager: load_for_spec(), reset_to_default(), _generate_default_pages(), per-spec save paths
- SpecManager: allocate_remaining_by_spec(), allocate_all_by_spec(), save_archmage_as_spec()

Deferred to 2.43:
- Tome inline in spec editor (prev/next page navigation)
- Remove separate Tome view entirely

Known remaining issues:
- Frostbinder preferred_slots empty in .tres — needs data entry in Godot inspector
- Shooter projectile despawn: enemy projectiles travel downward, never hit DESPAWN_Y (-50) — they linger forever off-screen bottom

---

## Session 2.49b — Deferred Passives Cleanup + Fixes ✅ COMPLETE
**Status: COMPLETE — 2026-04-15**

Steps completed:
- STEP 1: execute() guard — already present from 2.49, confirmed ✅
- STEP 2: recalculate() cast passive dedup — implemented ✅
- STEP 3: mudwall cooldown reset — already correct, confirmed ✅
- STEP 4: FacingMarker rotation == 0.0 explicit branch + debug print ✅
- STEP 5: soulsiphon holy amp via target_element param ✅
- STEP 6: Chaser2 debuff test — revealed Bug B (cast+enemy collection) ✅ fixed

Additional bugs found and fixed during session:
- Bug B: cd_type=cast target=enemy effects silently dropped from _active_enemy_passives — fixed
- Passive integrity: passives reading CraftingUI cursor page not combat page — fixed
- Recalculate storm: dirty-flag dedup (recalculate → _do_recalculate) added — fixed
- _on_node_added spurious recalculate trigger: removed — fixed

---

## Session 2.43 — Spec Editor Tome Integration ✅ COMPLETE
Delivered: Unified spec+page editor, menu button, Android CSV fix.

## Session 2.44 — Partner Feedback Integration
Goal: Integrate partner playtesting notes from feedback.md.
Expected scope: spell feel tuning, enemy behaviour adjustments, 
UI feedback from Android testing.
Open prompt: Upload context.md, systems.md, feedback.md to begin.

```
Read context.md and systems.md first.
Godot 4 GDScript.
Session 2.43 — Embed tome page navigator inside spec editor.

Goal: Remove the separate Tome view. The spec editor becomes a single unified screen
containing both spec configuration AND page management.

Current flow: Spec editor → "Go to Tome" button → Tome view (separate)
Target flow: Spec editor has inline page section with prev/next navigation

LAYOUT (top to bottom in spec editor):
1. Header row: [< Back] [Reset Spec*] [Save as Spec**]
   * only for built-in specs
   ** only on Archmage row
2. Name field (read-only for built-ins)
3. Separator
4. SPEC TEMPLATE section:
   - 4 slot rows (elemental/empowerment/enchantment/delivery)
   - Summon picker + Ult 1 + Ult 2
   - Ratio % inputs (7 schools, integer inputs, normalise on save)
5. Separator
6. PAGES section:
   - Header: "Pages" label + [< Prev] [Page X of Y] [Next >] + [+ Add] [- Remove]
   - Current page name (editable inline via LineEdit)
   - Current page spell rows (same 4-slot picker layout as spec template above)
   - Current page summon + ult pickers
   - [Craft] button → opens page_editor_view (existing) for full edit
   - [Activate] button → sets this page active in-game
7. Separator
8. MANA ALLOCATION section (existing controls — keep as-is)
9. [Save Spec] [Cancel] buttons

ARCHITECTURE NOTES:
- Remove _switch_to_tome_list() and all tome_view show/hide logic
- _spec_editor_container handles everything
- Add _spec_editor_page_index: int = 0 to track which page is shown in editor
- Prev/Next buttons update _spec_editor_page_index and repopulate the page section only
- "Go to Tome" button on spec editor can be removed (tome is now inline)
- tome_view from .tscn can remain hidden permanently
- page_editor_view still used for deep craft editing — Back from page editor returns to spec editor

Paste these files to begin:
crafting_ui.gd, tome_manager.gd
```
## Session 2.45 — Delivery Scenes ✅ COMPLETE
All 8 prompts delivered. All 7 delivery types working.
Key bugs resolved: scene/script assignment, setup_from_spell signature
mismatch, instant-hit _ready() timing, blast key mismatch, summon
initialize missing, volume slider rebuild on reopen.

---

## Session 2.46 — Delivery Tuning + Partner Playtesting
Goal: Partner tests all 7 delivery types, feeds back on feel and values.
David applies tuning changes to deliveries.csv and delivery scripts.

Likely tuning targets:
- Orb orbit speed, radius, damage
- Burst spread angle and damage multiplier
- Cleave cone angle and range
- Beam width and duration
- Blast radius and visual scale
- Missile turn rate and speed
- CD floor (currently 1.5s — may need per-delivery override)

Technical prep for this session:
- Confirm Chaser2 rebuild (res://scenes/enemies/chaser.tscn)
- Utility delivery stub (self-target passthrough)
- Per-delivery CD support if needed (override in _configure_cooldown_timer)
---

### Session 2.5 — Wave Structure / Enemy Variety
**Status: ⬜ Pending**

> All spell system work stays under 2.4x. Session 2.5 begins non-spell systems.
> Spell slot progression (boss-gated SpellCaster unlocks) is Phase 4 content — see Session 4.1.

Candidates (pick focus at session start):
- [ ] Wave structure / enemy variety (spawner patterns, elite enemies, wave timer)
- [ ] Equipment slots (hat, robe, gloves, boots, weapon — drop from bosses)
- [ ] Summon empty-element Smite registration fix
- [ ] get_school_multiplier() 0.05 vs 0.02 alignment
- [ ] Spec system polish (Confirm Spells flow, spec picker in-game)
=== SESSION 2.46c SCOPE ===

PRIORITY 1 — Fix remaining delivery scripts:
  Verify bolt, cleave, aoe, missile, orbs all have on_hit_effects fix applied.
  Test each delivery type with a known on-hit effect (burndot recommended).

PRIORITY 2 — Fix SpellComposer routing for passive target=enemy rows:
  rootedpower (C0002) and stagger (C0003) are cd_type=passive target=enemy.
  These should fire as on-hit effects from the projectile, not as PassiveManager
  passives. They are currently included in on_hit_effects correctly but have no
  match arm in _apply_on_hit_effects(). Add match arms for rootedpower and stagger
  that check player movement state (rootedpower) or roll chance (stagger).
  Note: stagger already has apply_stagger on enemies — just needs the arm.

PRIORITY 3 — Deferred passives implementation:
  rootedpower (C0002): stand still → +dmg amp, track player velocity
  holylight (F0005): stand still → heal player + summon
  killfuel (A0005): on enemy kill → reduce remaining spell CDs
  overheat (A0006): every N spells → next spell gets amp
  smite (F0002): 2 same-school spells → next spell holy amp
  bloodpower (G0004): hp threshold → dmg boost
  soulrequiem (G0006): soul stacks on kill → dmg amp + AoE
  soulsiphon (G0005): lifeleech on hit + holy amp (heal() now available)
  dispel (F0006): cast → remove debuffs from player/summon

PRIORITY 4 — Base enemy refactor:
  Create base_enemy.gd with full debuff surface
  Shooter and Tank extend base_enemy
  Retire enemy.gd chaser, build Chaser2 in res://scenes/enemies/
  Set element field per enemy type for weakness system

PRIORITY 5 — Alignment fixes:
  get_school_multiplier() uses 0.05/tier — confirm intended vs design doc 0.02/count
  Implement milestone bonuses at 5, 10, 25, 50 mana allocation
  Remove dead register_passive() path from SpellComposer self-passive routing

FILES TO UPLOAD AT SESSION START:
  context.md, systems.md
  spell_composer.gd (routing fix)
  spell_projectile.gd (add rootedpower + stagger arms)
  passive_manager.gd (deferred passives)
  progression_manager.gd (confirm heal() present)
  player.gd (for killfuel kill signal wiring)
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
| 2.41 — Mana & School System | ✅ Complete | Generic mana orbs, mana pool, school gating, SpecData, SpecManager, mana HUD |
| 2.42 — CraftingUI Redesign | ✅ Complete | 6 bug fixes, spec list 10 slots, spec editor, per-spec tome, mana allocation UI, Save as Spec |
| 2.43 — Spec Editor Tome Integration | ✅ Complete | Inline page navigator in spec editor, remove separate Tome view, resolve android export not picking up the csv | 
| 2.44 — Spell Foundation | ✅ Complete |
| 2.45 — Spec Delivery Types | ✅ Complete |
| 2.46 — Passive and Spell on Hit effects | ✅ Complete |
| 2.47 — Spells 1/3 | ✅ Complete |
| 2.48 — Spells 2/3 | ✅ Complete |
| 2.49 — Spells 3/3 | ✅ Complete | smite, soulrequiem, soulsiphon, mudwall, base_enemy refactor, Chaser2 |
| 2.49b — Passives Cleanup | ✅ Complete | cast+enemy collection fix, dedup, combat page integrity, dirty-flag recalculate, soulsiphon holy amp |
| 2.5 — Wave Structure | ⬜ Pending | Non-spell systems begin here; all spell work stays 2.4x |
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

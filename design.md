# 🧪 Spellcraft Roguelite — Gameplay Design

---

# 🎯 Core Vision

A **knowledge-driven roguelite** where players:

* Craft spells through combinations
* Learn through experimentation
* Prove mastery through boss fights

> Progression is driven by **understanding**, not grinding.

---

# 🧠 Core Philosophy

* Discovery is **free and encouraged**
* Execution is **tested and meaningful**
* No artificial restrictions
* No stat-based brute forcing

---

# 📱 Gameplay Layout

## Screen Structure

* **Top 80%** → Play area (combat, enemies, movement)
* **Bottom 20%** → Controls

  * Touchpad (movement)
  * 2–4 buttons:

    * Ultimate
    * Pause / Learn

---

# 🎮 Core Gameplay Loop

```text
Fight → Collect → Craft → Adapt → Boss → Learn → Repeat
```

---

## Loop Breakdown

1. Player moves via touchpad
2. Spells auto-cast on cooldown
3. Enemies spawn from top (scrolling screen)
4. Player dodges and positions
5. Enemies drop elements/resources
6. Player collects resources
7. Player pauses to craft/relearn spells
8. Progress upward
9. Boss encounter (scroll stops)
10. Fight boss → win or retry

---

# ⚔️ Combat System

## Controls

* Movement: touchpad
* Spells: auto-cast
* Ultimate: manual button (unlocked at Level 5)

---

## Combat Philosophy

* Skill = **positioning + timing**
* No complex input combos
* Player influence comes from:

  * distance
  * angle
  * enemy grouping
  * element matchups

---

# 🧪 Spell System

## Structure

Each spell is built from 4 slots:

1. **Elemental** — core identity of the spell, sets the inherent damage multiplier and elemental weakness matchup
2. **Empowerment** — amplifies damage or damage-related attributes (DoT, chains, execute)
3. **Enchantment** — adds functions and gimmicks (AoE, pushback, status effects, walls)
4. **Delivery** — how the spell is fired (bolt, burst, beam, blast, cleave, missile, wall, utility/self)

Plus one independent slot:

5. **Summon** — a persistent companion that follows the player, attacks enemies, and mimics the player's slot 1 spell effects. One summon active at a time.

---

## Damage Formula

```
final_dmg = item_base_dmg × elemental_mult × weakness_mult × empowerment_mult × enchantment_mult × buff_debuff_mult
```

* All spell slots are **pure multipliers** — flat damage comes from items only
* DoT ticks (burn, corruption) use final_dmg as their base, not item_base_dmg
* AoE secondary hits (explosion, splash) use a fraction of final_dmg

---

## Element Weakness Wheel

```
Fire → Ice → Earth → Thunder → Water → Fire (circular)
Holy ↔ Dark (mutual)
```

* Attacking a weakness: ×1.2 damage
* Attacking a strength: ×0.8 damage
* Neutral matchup: ×1.0

---

## Holy and Dark — Special Mechanic

Holy and Dark Elemental spells do **not auto-cast**. They fire the moment the player **stops moving**, gated by cooldown. This rewards intentional positioning — the player chooses when to commit to a stationary cast for higher damage (×1.6 multiplier vs typical ×1.0–1.3).

---

## Element Scaling

Every element collected from enemy drops increases that element's contribution by +2%:

```
scaling = 1.0 + element_count × 0.02
```

At 50 elements collected, that element's multiplier is doubled.

---

## Delivery Types

| Delivery | Behaviour |
|---|---|
| Bolt | Single straight projectile |
| Burst | 3 projectiles in spread |
| Beam | Pierces enemies in a line |
| Blast | 360° AoE around caster |
| Cleave | Frontal cone AoE |
| Missile | Tracks nearest enemy |
| Wall | Fixed barrier, travels forward |
| Utility | Self-targeted — activates self slot effects |

When **Utility** delivery is chosen, self-slot effects activate instead of enemy-slot effects.

---

## Spell Budget

Every spell component has a **budget value** (1–5). The composed spell's total budget is the sum of all three slots. Budget is used for:

* Boss HP calibration
* Paragon difficulty scaling
* Identifying overpowered combos during tuning

Budget does not affect gameplay directly — it is a tuning tool only.

---

## Spell Cooldown

```
total_cd = elemental_cd + empowerment_cd + enchantment_cd
```

More powerful combinations cost more cooldown time. Passive and recharge effects do not contribute to total_cd.

---

# 🧿 Summon System

Each element has one summon unlocked in the Summon slot. Summons are independent of spell slots — all players have a summon active regardless of their spell build.

* One summon active at a time
* Summons follow the player at close range
* Summon attacks mimic the player's slot 1 spell effects
* Summons have HP and can die — they recharge on a timer (typically 60s)
* Each element's summon has a unique identity and special ability

**Summons by element:**

| Element | Summon | Special |
|---|---|---|
| Fire | Forgespirits (×2) | Mimic slot 1 attacks |
| Ice | Icewarden | Frostnova AoE every 5s, roots enemies |
| Earth | Stonegolem | Melee, stuns enemies on hit |
| Thunder | Stormspirit | On death triggers a ×4 slot 2 spell (recharge 20s) |
| Water | Waterelemental | Applies Wet debuff with attacks |
| Holy | Holyspirit | Heals player passively, attacks enemies |
| Dark | Shadowfiend | Fear aura — non-dark/boss units flee |

> Dual-element summons are a planned future expansion.

---

# 🎒 Item System

Items drop from **bosses only**. There are 5 equipment slots:

| Slot | Primary Stat | Secondary Options |
|---|---|---|
| Hat | +Max HP | +Element drop rate, +Spell range |
| Robe | +Damage % | +Effect duration, +Cooldown reduction |
| Gloves | +Cast speed | +Projectile speed, +Chain targets |
| Boots | +Move speed | +Iframe duration, +Pickup radius |
| Weapon | +Base damage | +Crit chance, +Element affinity |

**Key design principle:** Items are the **only source of flat damage**. Spells multiply that damage. A stronger weapon means all spells hit harder — the spell system shapes how that damage is applied, not its raw value.

**Drop model:**
* Items drop exclusively from boss kills
* No random mid-run item drops
* Each boss kill guarantees one item drop
* Players choose which slot to fill

Items are implemented in Phase 4. The equipment slot structure is stubbed in PlayerInventory from Session 2.1.

---

# 📖 Tome and Page System

The player holds a **Tome** — a spellbook containing up to **10 pages**. Each page is a complete saved build:

```
Page = 4 spell slots + 1 summon + 2 ultimates
```

Pages are the core unit of player expression. A player might have a "burn stack" page, a "chain thunder" page, and a "holy sustain" page, and switch between them based on what enemies they're facing.

---

## Flipping Pages

Pages can be flipped **mid-run during combat** — no pause required. This is the key mechanical difference from just editing spells. Flipping is an active combat decision, not a menu action.

**Page flip is gated by two conditions — both must be met:**

1. **Spell cooldowns** — a flat cooldown equal to the longest `total_cd` in the current page must have elapsed since the last cast
2. **Summon recharge** — the current summon must be fully recharged (not mid-recharge after death)

The gate is `max(longest_spell_cd, summon_recharge_remaining)`. In practice the summon recharge (typically 60s) is almost always the bottleneck, which means **summon management is a strategic layer** — keeping your summon alive directly affects how quickly you can react to a changing situation.

Stormspirit (Thunder) recharges in 20s vs 60s for most summons, making Thunder pages the most page-flip friendly.

---

## Editing Pages

Pages are edited freely during **pause** — no restrictions, no punishment. The crafting UI shows the current page and allows full editing of all 4 spell slots and the summon choice.

Players can also create new pages and fill them from scratch during pause.

---

## Page Structure

```
Page = {
  name: String           # player-named, e.g. "Burn Stack"
  slot1: SpellConfig     # elemental + empowerment + enchantment + delivery
  slot2: SpellConfig     # (locked until Level 2)
  slot3: SpellConfig     # (locked until Level 3)
  slot4: SpellConfig     # (locked until Level 4)
  summon: String         # element name
  ult1: String           # (locked until Level 5)
  ult2: String           # (locked until Level 6)
}
```

Locked slots are visible but greyed out — players can see what's coming and plan ahead.

---

## DoT and Ongoing Effects on Page Flip

Active DoT effects on enemies (burn ticks, corruption) **continue after a page flip** — the fire is already on the enemy, not tied to the page. This rewards pre-applying status effects before flipping to a different offensive page.

---

# 🔁 Crafting / Relearn System

## During Run

* Unlimited pause
* Free page and spell editing
* Fast iteration
* No punishment for changing spells or pages

---

## Purpose

* Encourage discovery
* Allow rapid testing of builds
* Enable learning without punishment

---

# 💀 Life System

## Total Lives: 3

---

## 🟢 Normal Run (Scrolling Phase)

On death:

* Lose 1 life
* Respawn
* Screen clears
* Keep all resources
* Continue run

---

## 🔴 Boss Phase

On death:

* Lose 1 life
* Boss resets
* Player respawns
* Same build retained
* **Relearn allowed BEFORE next attempt**

---

## 💀 Game Over

* Lose all 3 lives → Run restarts

---

# 🧠 Boss System

## Transition

* Scrolling stops
* Arena forms
* Player enters **Preparation Phase**

---

## Preparation Phase

* Full relearn allowed
* Final build adjustments
* No pressure

---

## Boss Fight

* No relearn during fight
* Pure execution
* Positioning + build tested

---

## Retry Loop

```text
Fight → Die → Review Metrics → Adjust Build → Retry
```

---

# 📊 Boss Feedback System

After each death, show:

## Metrics

* Boss HP remaining %
* Top damage sources
* Damage taken by source
* Status effect uptime (burn, slow, etc.)
* Build note summary

---

## Example

```
Boss HP Remaining: 28%

Your top damage:
- Burn: 42%
- Chain: 31%
- Direct hit: 19%

You took most damage from:
- Arc burst: 54%
- Contact damage: 33%

Build note:
High sustained damage, weak burst window.
```

---

## Design Goal

> Provide **clear insight**, not overwhelming data

---

# 🎯 Progression System

## Levels (1–6)

Progression is unlocked by **beating bosses**

---

## Level Unlocks

```text
Lv1 → 1 spell slot
Lv2 → 2 spell slots
Lv3 → 3 spell slots
Lv4 → 4 spell slots
Lv5 → Ultimate unlock
Lv6 → Ultimate upgrade
```

Summon slot is always available from the start regardless of level.

---

## Notes

* No stat inflation
* Unlocks = more options, not raw power
* Full kit unlocked by Lv6

---

# 🧠 Player Progression

Not based on:

* grinding
* stats
* farming

Based on:

* understanding element combinations
* adapting builds to enemy types
* learning boss patterns
* optimising item + spell synergy

---

# 👥 Player Types Supported

## 🧪 Crafter

* experiments often
* optimizes element matchups
* builds around status effects and summon synergy
* uses pause frequently

---

## ⚡ Streamliner

* stacks raw damage via items
* picks strong elemental matchups
* relies on summon as passive support
* adapts less

---

> Both viable early, mastery favors understanding

---

# 🎮 Enemy Design (MVP)

## Types

1. **Chaser** → pressure player movement, melee contact damage
2. **Shooter** → fires projectiles at player, forces dodging
3. **Tank** → slow, high HP, blocks progression

## Status Interactions

Enemies carry element tags set by debuffs:

* Chilled → enemy counts as Ice unit
* Wet → enemy counts as Water unit
* Corrupted → enemy counts as Dark unit
* Frostnova hit → enemy counts as Ice unit
* Blinded → enemy projectiles no longer track player

These tags affect weakness calculations — a Wet enemy hit by Thunder takes bonus damage.

---

## Mana & School System

All enemy drops are generic Mana Orbs. On collection, mana is allocated into elemental Schools based on the player's active Spec, or manually via the Composer.

**Schools:** Fire, Ice, Earth, Water, Thunder, Holy, Dark

**School Tier:** Number of mana allocated to that school. Minimum 1 to unlock casting. Each tier increases spell effectiveness: base × (1.0 + tier × 0.05).

**Specs:** Predefined allocation templates with preferred spell loadouts. Designed for new players — the game proposes spells and allocates mana automatically. Players can switch Spec on any pause.

**Archmage Mode:** No Spec. Full manual allocation. For experienced players who want to build freely.

**Spell Gating:** A school spell cannot be cast with 0 allocation. This makes the first mana pickup into a school feel meaningful and forces intentional build decisions.


# ⚡ Difficulty Scaling

## Normal Levels 1–6

* Time-based enemy count increase
* Speed and HP scale per level
* Enemy mix changes per level

## Paragon (Level 7+)

* Difficulty budget system — each paragon level increases the total enemy difficulty budget per wave
* Weighted random enemy selection from pool
* Boss pool rotates with scaling HP and new attack patterns
* Implemented in Session 4.3

---

# 🧠 Design Principles

## ✔ Encourage

* experimentation
* fast iteration
* learning through failure
* element matchup discovery

---

## ✔ Enforce

* execution in boss fights
* commitment to builds during boss phase
* positioning skill

---

## ❌ Avoid

* grind-based progression
* stat overpowering
* menu-heavy gameplay
* over-complex UI

---

# 🎯 Core Experience

> "I experimented, I learned, I adapted — and now I can beat this."

---

# 🚀 Development Priority

## Phase 1 ✅ Complete

* Movement
* Auto-cast
* Enemy spawning
* Life system + HUD
* Alpha polish + APK

## Phase 2 — In Progress

* Spell combo architecture ✅
* Tome + Page system + Crafting UI
* Enemy variants + status effects
* Element drop system
* Spell slot progression

## Phase 3

* Boss system
* Boss state machine
* Boss metrics
* Boss retry loop

## Phase 4

* Full level progression
* Ultimate ability
* Paragon generator
* Item system (hats, robes, gloves, boots, weapons)
* Art pass
* Audio pass
* Performance + mobile polish

## Phase 5

* Google Play submission
* iOS App Store submission
* Post launch

---


# 🧠 Final Note

This is a **system-driven game**, not content-driven.

Keep it:

* small
* tight
* focused

> Depth comes from interaction, not volume.

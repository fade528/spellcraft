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
* Ultimate: manual button

---

## Combat Philosophy

* Skill = **positioning + timing**
* No complex input combos
* Player influence comes from:

  * distance
  * angle
  * enemy grouping

---

# 🧪 Spell System (Simplified)

## Structure

Each spell is built from:

1. Primary element
2. Modifier element
3. Finisher element
4. Delivery type

---

## Notes

* Order matters
* Spells are **authored but reusable via archetypes**
* Elements scale with collection

---

# 🔁 Crafting / Relearn System

## During Run

* Unlimited pause
* Free experimentation
* Fast iteration

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

* Lose all 3 lives
  → Run restarts

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
Fight → Die → Adjust → Retry
```

---

# 📊 Boss Feedback System

After each death, show:

## Metrics

* Boss HP remaining
* Top damage source
* Damage taken by source
* Status uptime (burn, slow, etc.)

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

---

Based on:

* understanding combinations
* adapting builds
* learning enemy patterns

---

# 👥 Player Types Supported

## 🧪 Crafter

* experiments often
* optimizes builds
* uses pause frequently

---

## ⚡ Streamliner

* stacks power
* avoids crafting
* adapts less

---

> Both viable early, mastery favors understanding

---

# 🎮 Enemy Design (MVP)

## Types

1. Chaser → pressure player movement
2. Shooter → forces dodging
3. Tank → blocks progression

---

# ⚡ Difficulty Scaling

* Time-based scaling
* Enemy count increases
* Speed increases
* Health increases

---

# 🧠 Design Principles

## ✔ Encourage

* experimentation
* fast iteration
* learning through failure

---

## ✔ Enforce

* execution in boss fights
* commitment to builds
* positioning skill

---

## ❌ Avoid

* grind-based progression
* stat overpowering
* menu-heavy gameplay
* over-complex UI

---

# 🎯 Core Experience

> “I experimented, I learned, I adapted — and now I can beat this.”

---

# 🚀 Development Priority

## Phase 1

* Movement
* Auto-cast
* Enemy spawning

---

## Phase 2

* Spell system
* Crafting UI
* Basic enemies

---

## Phase 3

* Boss system
* Life system
* Feedback metrics

---

# 🧠 Final Note

This is a **system-driven game**, not content-driven.

Keep it:

* small
* tight
* focused

---

> Depth comes from interaction, not volume.

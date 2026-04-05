# Spellcraft Roguelite — Master Context

> Read this first. This file gives you everything needed to assist on this project without reading all other docs.

---

## What This Project Is

A mobile-first 2D roguelite where players craft spells through element combinations, learn through experimentation, and prove mastery through boss fights. Built for Android/iOS in portrait mode.

**Core loop:**
```
Fight → Collect → Craft → Adapt → Boss → Learn → Repeat
```

**Design philosophy:** Progression driven by understanding, not grinding. No stat inflation. No random powerup dependency. Player agency through knowledge of the spell system.

---

## The Team

**David** — Technical Lead
- SAP Solution Architect by profession, moderate coder
- Using Godot 4 + GDScript for the first time
- Stack: Godot 4, VS Code, Codex (AI agent), Git
- Handles: all code, architecture, scene structure, Git

**Partner** — Gameplay Lead
- Non-technical, strong gameplay instinct
- Handles: feel decisions, spell combo design, enemy tuning, playtesting, feedback.md, design.md updates

---

## Tech Stack

```
Engine:        Godot 4.x
Language:      GDScript (always specify "Godot 4 GDScript" in prompts)
Editor:        VS Code + godot-tools extension
AI Agent:      Codex (in VS Code)
Version ctrl:  Git
Platform:      Android + iOS, portrait 1080x1920
```

**Critical:** Always write Godot 4 GDScript, never Godot 3. Key differences: `@export`, `@onready`, `CharacterBody2D` (not KinematicBody2D), `velocity` not `move_and_slide(velocity)`.

---

## Current Status

Week 1 of 6-week alpha sprint. Setting up dev environment. No game code written yet.

**Alpha target:** Movement + enemy scrolling + basic auto-cast spell. Placeholder art only (coloured rectangles). Get in partner's hands for feel testing.

---

## Architecture Decisions

### Scene Structure
```
Game (scene)
├── World (Node2D)
│   ├── Player (scene)
│   ├── EnemySpawner (Node)
│   ├── ScrollingBackground (scene)
│   └── ElementDrops (Node)
├── GameManager (Node)
├── ProgressionManager (Node)
├── CombatManager (Node)
├── SpellManager (Node)
└── UI (CanvasLayer)
    ├── HUD (scene)
    ├── PauseMenu (scene)
    └── BossMetrics (scene)
```

### Signal Flow Rule
- Signals travel **upward** (child → parent/manager)
- Direct calls travel **downward** (manager → child)
- GameManager is coordinator only — thin orchestrator, does not implement domain logic
- Domain managers own their logic: SpellManager, CombatManager, ProgressionManager

### Collision Layers
```
Layer 1 — Player physical body
Layer 2 — Enemy physical body
Layer 3 — Player hurtbox (Area2D)
Layer 4 — Enemy hurtbox (Area2D)
Layer 5 — Spell projectiles (Area2D)
Layer 6 — Element drops (Area2D)
Layer 7 — Screen boundaries
```

### Data Pattern
- **Resources (.tres)** = master data. Spell definitions, enemy stats, level configs. Never changes at runtime.
- **Node variables** = transaction data. Current HP, lives remaining, cooldown timers. Runtime state.
- Always `duplicate()` resources before modifying per-instance values.

### Game States
```gdscript
enum GameState {
    SCROLLING,
    BOSS_PREP,
    BOSS_FIGHT,
    BOSS_METRICS,
    GAME_OVER
}
```

---

## Key Systems Summary

### Spell System
Each spell built from 4 parts:
1. Primary element
2. Modifier element
3. Finisher element
4. Delivery type

Order matters. Spells are SpellData resources (.tres files). Player has spell slots (unlocked by level). Free crafting/relearning during pause — unlimited experimentation, no punishment.

### Life System
3 lives total. On death during scrolling: lose 1 life, respawn, screen clears, keep resources. On death during boss: lose 1 life, boss resets, relearn allowed before retry. All 3 lives lost = game over, run restarts.

### Progression
Levels 1-6, unlocked by beating bosses. No stat inflation — unlocks = more spell slots and ultimate ability. Level 5 = Ultimate unlock. Level 6 = Ultimate upgrade.

### Boss System
Scrolling stops → arena forms → Preparation Phase (relearn allowed) → Boss Fight (no relearn, pure execution) → death shows metrics screen → retry loop.

### Boss Metrics (shown after each death)
- Boss HP remaining %
- Top damage sources
- Damage taken by source
- Status effect uptime
- Build note summary

---

## Resource Definitions

```gdscript
# SpellData
class_name SpellData extends Resource
@export var spell_name: String
@export var primary_element: String
@export var modifier_element: String
@export var finisher_element: String
@export var delivery_type: String
@export var damage: float
@export var cooldown: float
@export var projectile_speed: float

# EnemyData
class_name EnemyData extends Resource
@export var enemy_name: String
@export var max_hp: float
@export var move_speed: float
@export var contact_damage: float
@export var difficulty_cost: int
@export var element_drop: String

# LevelConfig
class_name LevelConfig extends Resource
@export var level_number: int
@export var duration: float
@export var scroll_speed: float
@export var spawn_table: Array[SpawnEntry]
@export var boss: BossData
```

---

## Enemy Types (MVP)
1. **Chaser** — follows player, pressure movement
2. **Shooter** — fires projectiles, forces dodging
3. **Tank** — slow, high HP, blocks progression

## Sprite Approach
- Player: 8 directional sprites (draw 5, mirror 3)
- Boss: 8 directional + attack animations
- Mobs: 1-4 sprites, mostly scrolling downward
- MVP Phase 1-2: placeholder coloured rectangles only

---

## Folder Structure
```
res://
├── scenes/
│   ├── game.tscn
│   ├── player.tscn
│   ├── enemies/
│   ├── ui/
│   └── boss/
├── scripts/
│   ├── managers/
│   ├── player/
│   ├── enemies/
│   └── spells/
├── resources/
│   ├── spells/
│   ├── enemies/
│   └── levels/
└── assets/
    ├── sprites/
    ├── audio/
    └── placeholders/
```

---

## Codex Prompt Rules
1. Always start prompts with "Godot 4 GDScript"
2. Paste relevant existing code as context
3. Paste scene tree structure when asking for node-specific code
4. Verify output uses Godot 4 syntax before accepting

---

## Files in This Project Folder
- `context.md` — this file, read first
- `design.md` — full game design document
- `systems.md` — technical decisions log (updated as built)
- `roadmap.md` — 6-week alpha sprint plan
- `collab.md` — team roles and workflow
- `prompts.md` — Codex/AI prompt templates
- `feedback.md` — partner playtesting notes

# Spellcraft Roguelite — Development Roadmap

**Pace:** 10-15 hrs/week | **Target:** Thin Alpha (movement + enemies + auto-cast) | **Timeline:** 6 weeks

---

## Phase Overview

| Phase | Weeks | Focus | Deliverable |
|---|---|---|---|
| 0 | Week 1 | Dev environment + Godot fundamentals | Setup complete, first scene running |
| 1 | Weeks 2-3 | Core systems — movement + enemies | Player moves, enemies scroll |
| 2 | Weeks 4-5 | Auto-cast spell system + life system | Full game loop closed |
| 3 | Week 6 | Alpha polish + partner handoff | Playable APK for testing |

---

## Week 1 — Environment Setup + Godot Fundamentals

**Goal:** Working environment. No game code yet.

### Tasks
| Task | Owner | Done when |
|---|---|---|
| Install Godot 4.x | David | Godot opens, new project created |
| Set VS Code as external editor | David | Scripts open in VS Code on double-click |
| Install godot-tools VS Code extension | David | GDScript autocomplete working |
| Complete official Godot 2D tutorial | David | Tutorial game runs without errors |
| Set up Git repo | David | First commit pushed |
| Create project folder structure | David | scenes/ scripts/ assets/ resources/ exist |
| Install Codex in VS Code | David | Codex responding to GDScript prompts |
| Read design.md + collab.md | Partner | Partner understands scope and role |
| Install Archero + Vampire Survivors | Partner | Both played for 30+ mins |

### 🎯 Milestone
VS Code + Godot + Codex connected. Git live. Tutorial completed.

### Test Codex is working
Prompt: *"Write a Godot 4 GDScript for a CharacterBody2D that moves with WASD at 300px per second using delta"*

If output uses `@export`, `velocity`, `move_and_slide()` with no arguments — Godot 4 syntax confirmed. If it uses `KinematicBody2D` or `move_and_slide(velocity)` — Godot 3 syntax, add "Godot 4" more explicitly to every prompt.

---

## Week 2 — Player Movement

**Goal:** Player rectangle moves smoothly around the canvas on device.

### Tasks
| Task | Owner | Done when |
|---|---|---|
| Create Player scene (CharacterBody2D) | David | Scene opens in editor |
| Add placeholder sprite (blue rectangle) | David | Rectangle visible in viewport |
| Add CollisionShape2D | David | Shape visible in debug mode |
| Implement touchpad movement with delta | David | Moves smoothly in all directions |
| Add 8-direction sprite facing logic | David | Sprite faces movement direction |
| Add screen boundary clamping | David | Player cannot leave canvas edges |
| Create Game scene, instance Player | David | Player appears in Game scene |
| Set viewport to 1080x1920 | David | Canvas correct portrait size |
| Export move_speed to inspector | David | Speed tunable without code change |
| Test on actual Android device | David | Movement feels right on phone |

### 🎯 Milestone
Player rectangle moves smoothly, stays in bounds, feels responsive on device.

### Key Codex Prompts
- `"Godot 4 GDScript CharacterBody2D touchpad movement 8 directional with delta and screen boundary clamping"`
- `"Godot 4 GDScript snap Vector2 to 8 directions for sprite animation"`
- `"Godot 4 how to deploy APK to Android for testing"`

---

## Week 3 — Enemy Spawning + Scrolling

**Goal:** Enemies scroll down, player dodges. Partner gets first playtest.

### Tasks
| Task | Owner | Done when |
|---|---|---|
| Create Enemy scene (CharacterBody2D) | David | Enemy scene exists |
| Add Hurtbox Area2D to Enemy | David | Hurtbox on correct collision layer |
| Implement downward movement with delta | David | Enemy moves down at constant speed |
| Despawn when off bottom edge | David | Enemies removed at Y > 1980 |
| Create EnemySpawner node in Game scene | David | Spawner script exists |
| Implement repeating spawn Timer | David | Enemies spawn from random X at top |
| Create scrolling background | David | Background loops seamlessly |
| Add Chaser enemy type | David | One enemy type follows player |
| Export spawn_rate + enemy_speed | David | Both tunable from inspector |
| Partner first playtest | Partner | feedback.md updated with feel notes |

### 🎯 Milestone
Enemies scroll down, chaser follows player, background loops. Partner can dodge and feel the pressure.

### What Partner Tests This Week
- Does movement feel responsive enough to dodge?
- Is enemy speed threatening but learnable?
- Does scrolling create the right pressure?
- Any motion sickness on mobile?

### Key Codex Prompts
- `"Godot 4 GDScript Node2D enemy spawner instances CharacterBody2D scenes on repeating Timer"`
- `"Godot 4 GDScript CharacterBody2D chaser enemy moves toward player position"`
- `"Godot 4 GDScript seamless scrolling background using Sprite2D region"`

---

## Week 4 — Spell System Foundation

**Goal:** Auto-cast projectile fires at nearest enemy and deals damage.

### Tasks
| Task | Owner | Done when |
|---|---|---|
| Create SpellData resource class | David | SpellData.gd with damage + cooldown |
| Create basic_bolt.tres resource | David | First spell .tres file exists |
| Create SpellProjectile scene (Area2D) | David | Projectile with hitbox on correct layer |
| Implement projectile upward movement | David | Projectile moves at defined speed |
| Hit detection vs enemy hurtbox | David | Collision detected, signal emitted |
| Enemy take_damage() method | David | Enemy HP reduces on hit |
| Enemy death + queue_free() | David | Enemy removed at 0 HP |
| SpellCaster node on Player | David | Auto-fires on cooldown via Timer |
| Aim at nearest enemy | David | Projectile fires toward closest target |
| Export cooldown + damage | David | Both tunable from inspector |

### 🎯 Milestone
Player auto-fires toward nearest enemy. Enemy takes damage and dies. Core combat loop exists.

### Architecture Note
One spell only this week. Clean data structure is the priority, not feature breadth. The 4-part combo system builds on this foundation.

### Key Codex Prompts
- `"Godot 4 GDScript Resource class with @export variables for spell data"`
- `"Godot 4 GDScript Area2D projectile moves upward despawns off screen detects CharacterBody2D"`
- `"Godot 4 GDScript find nearest node in group"`
- `"Godot 4 GDScript auto cast spell on repeating Timer node"`

---

## Week 5 — Life System + HUD

**Goal:** Full game loop closed. Player takes damage, loses lives, reaches game over.

### Tasks
| Task | Owner | Done when |
|---|---|---|
| Add Player Hurtbox Area2D | David | Hurtbox on correct collision layer |
| Implement take_damage() on Player | David | HP reduces on enemy contact |
| Add iframe system (1.0s default) | David | Player flashes, immune after hit |
| Add contact_damage to Enemy resource | David | Chaser deals damage on overlap |
| Implement lives system (3 lives) | David | Lives tracked in ProgressionManager |
| Add respawn logic | David | Player respawns, screen clears |
| Create CanvasLayer for HUD | David | HUD sits above world, doesn't scroll |
| Add lives display to HUD | David | 3 icons visible, update on damage |
| Game over state | David | All lives lost triggers game over |
| Restart from game over | David | Player can restart run |

### 🎯 Milestone
Full loop: spawn → fight → take damage → lose lives → game over → restart.

### Key Codex Prompts
- `"Godot 4 GDScript Area2D hurtbox detects CharacterBody2D enemy overlap deals damage"`
- `"Godot 4 GDScript invincibility frames Timer sprite flash modulate alpha"`
- `"Godot 4 GDScript CanvasLayer HUD lives display updates on signal"`
- `"Godot 4 GDScript game over state change_scene_to_file"`

---

## Week 6 — Alpha Polish + Partner Handoff

**Goal:** No new systems. Juice and feel. APK in partner's hands.

### Tasks
| Task | Owner | Done when |
|---|---|---|
| Hit flash on enemy damage | David | Enemy flashes white on hit |
| Death particle burst | David | Particles on enemy despawn |
| Screen shake on player hit | David | Camera shakes on damage |
| Spell impact SFX (placeholder) | David | Generic sound on hit |
| Background music loop | David | Atmospheric loop playing |
| Tune spawn rate + enemy speed | Partner | Feels challenging but fair |
| Tune iframe duration | Partner | Forgiving without feeling invincible |
| Tune spell cooldown + damage | Partner | Auto-cast feels satisfying |
| Write detailed feedback.md | Partner | 10+ specific feel observations |
| Build APK for distribution | David | Partner installs on own device |

### 🎯 Milestone
Playable APK in partner's hands. Feedback.md populated. Decision: proceed to Phase 2 or iterate.

### Key Codex Prompts
- `"Godot 4 GDScript CPUParticles2D burst effect on node death"`
- `"Godot 4 GDScript Camera2D screen shake Tween"`
- `"Godot 4 GDScript export Android APK release"`

---

## Risks

| Risk | Mitigation |
|---|---|
| Codex produces Godot 3 syntax | Always include "Godot 4 GDScript" in every prompt |
| Scope creep before alpha done | No second spell, no enemy variants, no UI polish until Week 6 |
| Mobile performance issues | Test on actual device weekly, not just in editor |
| Partner loses momentum | Get build in partner's hands end of Week 3, not Week 6 |
| Node path errors | Always use `@onready var node = $NodeName` pattern |
| Git conflicts | David owns all .gd and .tscn files. Partner only edits .md files |

---

## Suggested Weekly Rhythm

| Day | Activity |
|---|---|
| Monday | Review feedback.md. Convert to task list. |
| Tue–Thu | Core build sessions. 2-3 hrs per evening. One task at a time. |
| Friday | Integration + light testing. Push to Git. |
| Saturday | Longer session 3-4 hrs. Hardest task of the week. |
| Sunday | Partner playtests latest build. Updates feedback.md. |

---

## After Alpha — Phase 2 Preview

Once partner confirms alpha feel is right:
- Spell combo system — 4-part construction, first 6-8 combos
- Pause + crafting UI — free experimentation during run
- Second and third enemy types — Shooter and Tank
- Element drop system
- Spell slot progression — Levels 1-4
- First boss — simple pattern, full state machine

Phase 2 estimated 6-8 weeks at same pace.

---

> Build thin. Test early. Iterate fast.
> The alpha exists to answer one question: does the core loop feel fun?

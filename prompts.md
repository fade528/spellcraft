# Spellcraft Roguelite — AI Prompt Templates

> Use these templates with Codex in VS Code or any AI coding assistant. Always include "Godot 4 GDScript" — AI tools default to Godot 3 syntax without this.

---

## Golden Rules for Every Prompt

1. Start with **"Godot 4 GDScript"** — always
2. Paste your **existing scene tree** when asking for node-specific code
3. Paste **existing related script** as context so AI pattern-matches your style
4. Specify **which node type** the script attaches to
5. Verify output: should use `@export`, `@onready`, `CharacterBody2D`, `move_and_slide()` with no args

---

## Godot 4 Syntax Checklist

If AI output contains any of these — it's Godot 3, reject it:
- `KinematicBody2D` → should be `CharacterBody2D`
- `move_and_slide(velocity)` → should be `move_and_slide()` (velocity set separately)
- `connect("signal", self, "_method")` → should be `signal.connect(_method)`
- `export var` → should be `@export var`
- `onready var` → should be `@onready var`
- `.visible = false` on a node (fine) vs `hide()` / `show()` (also fine)

---

## Week 1 — Setup

### Test Codex works for Godot 4
```
Write a Godot 4 GDScript for a CharacterBody2D that moves with WASD at 300 pixels per second using delta. Use @export for speed.
```

---

## Week 2 — Player Movement

### Basic movement
```
Godot 4 GDScript. CharacterBody2D player script with:
- Touchpad/joystick analogue input using Input.get_vector()
- Movement multiplied by delta for framerate independence
- @export var move_speed: float = 300.0
- Screen boundary clamping to 1080x1920 viewport
- Uses _physics_process not _process
```

### 8-direction sprite facing
```
Godot 4 GDScript function that takes a Vector2 movement input and returns one of 8 string direction names: "up", "up_right", "right", "down_right", "down", "down_left", "left", "up_left", "idle". Uses the angle of the vector. Snaps to nearest of 8 directions.
```

### Screen clamping
```
Godot 4 GDScript. Clamp a CharacterBody2D position to stay within a 1080x1920 viewport with 40px padding on all edges. Called in _physics_process after move_and_slide().
```

---

## Week 3 — Enemy Spawning

### Basic enemy movement
```
Godot 4 GDScript for a CharacterBody2D enemy that:
- Moves straight down at @export var move_speed: float = 150.0
- Uses _physics_process with delta
- Calls queue_free() when position.y exceeds 1980
- Is in group "enemies"
```

### Chaser enemy
```
Godot 4 GDScript for a CharacterBody2D chaser enemy that:
- Moves toward the player's position each physics frame
- Player is found via get_tree().get_first_node_in_group("player")
- @export var move_speed: float = 120.0
- Uses delta in _physics_process
- Calls queue_free() when position.y exceeds 1980
- Has @export var contact_damage: float = 8.0
```

### Enemy spawner
```
Godot 4 GDScript for a Node spawner that:
- Has a repeating Timer child node
- On timeout: instances an enemy PackedScene at random X between 50-1030, Y at -50
- @export var enemy_scene: PackedScene
- @export var spawn_rate: float = 2.0 (sets Timer wait_time)
- Adds instanced enemy as child of parent node (not self)
```

### Scrolling background
```
Godot 4 GDScript for a seamless scrolling background using two Sprite2D nodes stacked vertically. Scrolls downward at @export var scroll_speed: float = 50.0 pixels per second using delta. When top sprite moves below screen, repositions above the other creating infinite loop.
```

---

## Week 4 — Spell System

### SpellData resource
```
Godot 4 GDScript Resource class named SpellData with @export variables:
- spell_name: String
- damage: float = 10.0
- cooldown: float = 1.5
- projectile_speed: float = 400.0
- primary_element: String = "fire"
Use class_name SpellData extends Resource
```

### Projectile scene script
```
Godot 4 GDScript for an Area2D spell projectile that:
- Moves in a given direction at @export var speed: float = 400.0
- Direction set on spawn via a set_direction(dir: Vector2) method
- Has @export var damage: float = 10.0
- On body_entered signal: if body is in group "enemies", calls body.take_damage(damage), then queue_free()
- Calls queue_free() if position.y < -50 (off top of screen)
- Uses _physics_process with delta
```

### Find nearest enemy
```
Godot 4 GDScript function that finds and returns the nearest node in group "enemies" to a given position: Vector2. Returns null if no enemies exist. Uses distance_to() for comparison.
```

### SpellCaster auto-fire
```
Godot 4 GDScript Node script for auto-casting spells:
- Has @export var spell_data: SpellData resource
- Has @export var projectile_scene: PackedScene
- Uses a repeating Timer child (wait_time set from spell_data.cooldown)
- On timeout: finds nearest enemy, calculates direction vector, instances projectile, sets its direction and damage from spell_data, adds to parent scene
- If no enemy found, fires upward (Vector2.UP)
```

### Enemy take_damage
```
Godot 4 GDScript function for a CharacterBody2D enemy:
- @export var max_hp: float = 30.0
- var hp: float initialized to max_hp in _ready()
- func take_damage(amount: float): reduces hp, calls queue_free() if hp <= 0
- On death: emit signal "enemy_died" with position as parameter
```

---

## Week 5 — Life System

### Player hurtbox + iframes
```
Godot 4 GDScript player script additions:
- Area2D child named Hurtbox on collision layer 3, mask 0
- var is_invincible: bool = false
- @export var iframe_duration: float = 1.0
- @export var max_hp: float = 100.0
- var hp: float
- func take_damage(amount: float, type: int): checks is_invincible, reduces hp, starts iframes, emits "player_died" if hp <= 0
- func start_iframes(): sets is_invincible true, starts Timer, tweens sprite alpha between 0.3 and 1.0 for iframe_duration
- Timer timeout sets is_invincible false
```

### Lives system
```
Godot 4 GDScript Node script for ProgressionManager:
- var lives_remaining: int = 3
- func handle_player_death(): decrements lives, emits "lives_changed" signal with new count, emits "game_over" if lives_remaining <= 0, else emits "respawn_player"
- Signals: lives_changed(count: int), game_over, respawn_player
```

### Game over + scene change
```
Godot 4 GDScript. On receiving game_over signal: show a CanvasLayer game over panel with a restart button. On button pressed: call get_tree().change_scene_to_file("res://scenes/game.tscn") to restart run.
```

---

## Week 6 — Juice

### Hit flash on enemy
```
Godot 4 GDScript. In enemy take_damage(): use a Tween to set sprite modulate to Color.WHITE instantly, then tween back to Color(1,1,1,1) over 0.08 seconds.
```

### Death particles
```
Godot 4 GDScript. On enemy death: instance a CPUParticles2D node at the enemy's global position, add it to the scene root (not the enemy), set it to one_shot = true with 20 particles, emit and auto-queue_free after emission completes.
```

### Screen shake
```
Godot 4 GDScript function screen_shake(duration: float, intensity: float) on Camera2D:
- Uses Tween to rapidly offset camera position randomly within intensity range
- Runs for duration seconds with small steps
- Returns camera to original offset after completion
```

---

## General Utility Prompts

### Signal connection (Godot 4 style)
```
Godot 4 GDScript. Show how to connect a custom signal "enemy_died" emitted by an Enemy node to a method "_on_enemy_died" on the GameManager node. Use the modern signal.connect() syntax not the old connect() string method.
```

### Autoload / singleton
```
Godot 4 GDScript. Create an Autoload singleton script called Global that persists across scene changes and stores: current_level: int, lives_remaining: int, collected_elements: Dictionary, equipped_spells: Array. Explain how to register it in Project Settings.
```

### Resource loading
```
Godot 4 GDScript. Show two ways to load a SpellData resource: preload() for resources known at compile time, and load() for resources loaded dynamically at runtime. Show how to duplicate() the resource before modifying instance values.
```

### Scene instancing
```
Godot 4 GDScript. Show how to: 1) preload a PackedScene, 2) instantiate it, 3) set a property on it before adding to scene tree, 4) add it as a child of a specific node. Example: spawning an enemy at a given position.
```

### Group membership
```
Godot 4 GDScript. Show how to: add a node to a group in _ready(), check if a body entering an Area2D is in a specific group, get all nodes in a group via get_tree().get_nodes_in_group().
```

---

## Debugging Prompts

### Null reference error
```
I'm getting a null reference error in Godot 4 GDScript on this line: [paste line]. My scene tree is: [paste tree]. What's likely causing it and how do I fix it?
```

### Signal not firing
```
In Godot 4 GDScript my signal is not being received. Emitting node: [paste]. Receiving node: [paste]. Connection code: [paste]. What could be wrong?
```

### Collision not detecting
```
In Godot 4 my Area2D is not detecting the CharacterBody2D. Area2D collision layer: [X] mask: [Y]. CharacterBody2D collision layer: [X]. What's the issue?
```

---

## Prompt to Start Each Session

Paste this at the start of any AI session to restore context:

```
I'm building a mobile 2D roguelite in Godot 4 GDScript called Spellcraft. 
Read context.md first for full project context.
Current task: [describe what you're working on today]
Current scene tree: [paste relevant part]
Relevant existing code: [paste if applicable]
```

# Spellcraft Roguelite — Team Collaboration Structure

---

## Roles

### David — Technical Lead
- Project setup, architecture, Git management
- GDScript implementation and Codex agent prompting
- Scene structure and Godot node setup
- Spell system data architecture
- Performance, debugging, bug fixes
- Translating gameplay feedback into technical tasks

### Partner — Gameplay Lead
- Gameplay feel decisions — does this feel right?
- Enemy behaviour and difficulty tuning
- Spell combo design — what combinations exist and why
- Boss design and attack patterns
- Playtesting and structured feedback
- Progression and pacing decisions
- Asset direction — art style, music vibe
- Maintaining design.md as the game evolves

---

## Task Ownership

| Task | Owner | Notes |
|---|---|---|
| Movement + controls | David | Phase 1 priority |
| Auto-cast system | David | Core loop |
| Enemy spawning | David | Phase 1 priority |
| Spell combo architecture | David | Data structure design |
| Spell combo content | Partner | What combos feel fun |
| Enemy behaviour tuning | Partner | Speed, aggression, patterns |
| Boss attack patterns | Partner | Design, David implements |
| Boss feedback metrics UI | David | Phase 3 |
| Difficulty scaling values | Partner | Playtesting driven |
| Art style direction | Partner | Reference boards, mood |
| Asset implementation | David | Importing into Godot |
| Music selection | Partner | Using Suno / Udio |
| SFX selection | Partner | Using Freesound / Bfxr |
| Git + version control | David | Always |
| design.md updates | Partner | Keep it current |
| systems.md updates | David | Technical decisions log |

---

## Key Files

| File | Owner | Purpose |
|---|---|---|
| design.md | Partner | Game vision, mechanics, philosophy — source of truth for what the game is |
| systems.md | David | Technical decisions log — how things are actually built |
| feedback.md | Partner | Playtesting notes, feel issues, ideas from sessions |

---

## Day-to-Day Workflow

### Playtesting Loop
1. Partner plays build, notes feedback in feedback.md
2. David reviews feedback.md, converts to technical tasks
3. David implements with Codex assistance
4. Partner retests — loop repeats

### Design Decision Loop
1. Partner updates design.md with new ideas
2. Both review together — quick sync or async
3. David updates systems.md with implementation approach
4. David builds, Partner validates feel

---

## Decision Authority

| Decision Type | Final Say |
|---|---|
| Does this feel fun? | Partner |
| Should we build it this way technically? | David |
| What spell combos exist? | Partner |
| How is the spell system architected? | David |
| Enemy attack patterns | Partner |
| Enemy implementation in code | David |
| Art style and music vibe | Partner |
| Asset import and integration | David |
| Progression pacing | Partner |
| Performance and scope constraints | David |

---

## Ground Rules
- Partner does not need to touch code — feedback.md is the interface
- David does not make gameplay feel decisions unilaterally
- Both agree before cutting or significantly changing a core mechanic
- Keep scope tight — this is a small, focused game by design
- Playtest early and often — feel trumps features

---

## Development Phases

| Phase | Focus | Who Leads |
|---|---|---|
| Phase 1 | Movement, auto-cast, enemy spawning | David |
| Phase 2 | Spell system, crafting UI, basic enemies | Both |
| Phase 3 | Boss system, life system, feedback metrics | Both |

---

> "Depth comes from interaction, not volume."

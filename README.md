# Miyawana Defense — Game Design Document (GDD) & Technical Spec

> **A Tactical Side-Defense & Idle Base-Building Auto-Battler with Chibi Cats**  
> Built with **Godot Engine 4.x** (GDScript) | Platform: PC (Mouse-only / Mobile adaptable)

---

## 1. Executive Summary & Core Game Loop

**Miyawana Defense** combines the tactical positioning of lane-based auto-battlers with lightweight idle progression and hero gacha collection. 

Designed for a 3-month development cycle, the technical focus is placed on a **clean, decoupled, data-driven architecture** in Godot 4, procedural animation using run-time `Tween` nodes, and persistent state management.

```
[ MIYAWANA VILLAGE ]
  ├── Bakaneko AFK Farm (Passive currency via Unix timestamp delta)
  ├── The Forge (Monster Hunter style craft, sharpness & weaknesses)
  └── Hunter Recruitment / Gacha (Duplicates unlock passive Trait nodes)
          │
          ▼  (Deploy 4-Hunter Squad)
[ HORDE COMBAT (HORIZONTAL LANE) ]
  ├── Horizontal Viewport camera panning + Macro orders on cooldown
  ├── Guild Gate durability absorbs partial defeats (Risk management)
  └── Off-Screen telegraph warning (Telegraphs heavy Apex attacks)
          │
          ▼  (Rewards: Monster Loot + Zenny)
[ UPGRADE CYCLE & PERSISTENCE (JSON) ]
```

---

## 2. Combat Design & Spatial Layout

### 2.1 Horizontal Lane & Camera Viewport
* **Single-Lane Battlefield:** The *Guild Gate* sits on the far-left ($X = 0$), and the *Horde Spawn Point* is placed on the far-right ($X \approx 1400$).
* **Free Viewport Panning:** The player does not move characters individually. Instead, the player smoothly drags or pans the camera horizontally to inspect the frontline or check base integrity.
* **Off-Screen Hazard Telegraphing:** If a heavy monster or Apex boss charges an attack off-screen, a dynamic warning icon (`⚠️`) appears at the edge of the viewport indicating the incoming hazard's height and trajectory.

### 2.2 Squad Orders & Tactical Agency
To prevent visual clutter, the game enforces a strict ceiling of **4 Hunters vs. a maximum of 5–6 simultaneous monsters**:
* **Macro Squad Commands (Global Cooldown):**
  * `Advance / Aggressive:` Hunters press forward to close distance.
  * `Retreat / Defensive:` Hunters pull back to the Guild Gate to receive defensive coverage.
  * `Focus Fire:` Player clicks an enemy; all hunters prioritize that target regardless of frontline positioning.
* **Active Hunter Skills:** Energy bars fill during combat. Once charged, the player clicks hunter icons to release manual special skills (e.g., area-of-effect stuns, heavy slashes).

---

## 3. Procedural Tween Animation Pipeline

To eliminate the massive time bottleneck of drawing traditional sprite-sheets, characters use a minimalist **chibi geometry ("cone body + circle head")** driven by run-time `Tween` procedural motions:

| State | Procedural Tween Behavior | Readability Benefit |
| :--- | :--- | :--- |
| **Walk** | Pendular rotation oscilation (`-4°` to `+4°`) + sine Y bounce | Organic, cute cartoon bounce |
| **Attack Wind-Up** | Slight X pull-back + Squash (`scale.x = 1.25`, `scale.y = 0.8`) | Clear anticipation telegraph |
| **Hit Impact** | Vertical Stretch (`scale.y = 1.3`) + white monochrome hit-flash shader | Satisfying impact without extra art |
| **Damage Float** | Instantiated dynamic label rising & fading out | Detailed split: `125 (+45🔥)` |

---

## 4. Software Architecture in Godot 4

### 4.1 Data-Driven Design (`CustomResource`)
All static game data is decoupled into `.tres` files:

```gdscript
# HunterData.gd
class_name HunterData extends Resource

@export var id: String
@export var character_name: String
@export var star_rarity: int
@export var allowed_weapon_type: String # "Slash", "Blunt", "Pierce"

@export_group("Base Stats")
@export var max_health: float
@export var base_attack: float
@export var move_speed: float

@export_group("Skills & Traits")
@export var active_skill: Resource
@export var unlockable_traits: Array[Resource] # Unlocked through Gacha dupes
```

```gdscript
# MonsterData.gd
class_name MonsterData extends Resource

@export var id: String
@export var monster_name: String
@export var base_health: float
@export var base_damage: float
@export var loot_table: Dictionary # {"scale": 0.6, "claw": 0.25}

@export_group("Physical Resistances (Multipliers)")
@export var res_slash: float = 1.0   # >1.0 Weak, <1.0 Resistant
@export var res_blunt: float = 1.0
@export var res_pierce: float = 1.0

@export_group("Elemental Resistances")
@export var elemental_weakness: Dictionary # {"Fire": 1.5, "Water": 0.5}
```

### 4.2 Decoupled Event Bus & Components
* **`EventBus.gd` (Autoload Singleton):** Broadcasts global events without tight coupling (`horde_started`, `hunter_fainted`, `offscreen_warning_triggered`, `wave_completed`).
* **`HealthComponent` & `HitboxComponent`:** Entity health logic is modular. No heavy `RigidBody2D` physics engines are used; stopping ranges are evaluated via simple Euclidean distance ($|X_1 - X_2| \le \text{range}$).
* **`TraitComponent`:** Listens to combat signals. When a duplicate hunter is rolled in the gacha, new passive traits become active listeners (e.g., *"On kill, gain +20% attack speed for 5 seconds"*).

### 4.3 Persistence & AFK Farm Offline Math
Player data is saved to a local JSON file. Idle progress is calculated by comparing system Unix timestamps upon startup:

```gdscript
# Offline income calculation for the Bakaneko Farm
var current_time: int = Time.get_unix_time_from_system()
var elapsed_seconds: int = current_time - saved_profile.last_unix_timestamp
var elapsed_minutes: int = int(elapsed_seconds / 60)

var acorns_earned: int = min(elapsed_minutes * HARVEST_RATE_PER_MINUTE, MAX_CAPACITY)
saved_profile.acorns += acorns_earned
```

---

## 5. Scope Triage (3-Month Roadmap)

| Subsystem | Priority | Implementation Detail |
| :--- | :--- | :--- |
| **Core Combat** | **MUST (MVP)** | 4 Autonomous Hunters, 3 basic monsters + 1 Apex Boss (shader scale/glow modifier). Viewport panning, squad orders, and floating damage numbers. |
| **The Forge** | **MUST (MVP)** | Spend monster drop parts + Zenny to craft and sharpen elemental weapons. |
| **Recruitment / Gacha**| **MUST (MVP)** | Hunter pool with duplicate detection unlocking passive `TraitData` nodes. |
| **Bakaneko Farm (AFK)**| **MUST (MVP)** | Passive Zenny/Acorns collection calculated via offline Unix timestamp delta. |
| **Ginko's Casino** | **COULD (Phase 2)**| Optional simple High/Low card gambling minigame. |
| **Lab & Kitchen** | **BACKLOG** | Deferred to post-internship updates. |

---

## 6. Weekly Milestones (12 Weeks)

* **Weeks 1–3:** Core combat viewport, horizontal movement, procedural squash & stretch tweens, and base `CustomResource` schemas.
* **Weeks 4–6:** Tactical AI, distance checking, physical/elemental damage formula, off-screen warning system, and squad orders.
* **Weeks 7–9:** Village navigation, weapon crafting forge, gacha trait unlocking, and JSON save system with AFK offline math.
* **Weeks 10–12:** Apex boss modifiers, sound effects (SFX), balancing, final build exports, and technical internship documentation.
# Miyawana Defense — Game Design Document (GDD) & Technical Spec

> **A Tactical Side-Defense & Idle Base-Building Auto-Battler with Chibi Cats**  
> Built with **Godot Engine 4.x** (GDScript) | Platform: PC (Mouse-only / Mobile adaptable)

---

## 1. Executive Summary & Core Game Loop

**Miyawana Defense** combines the tactical positioning of lane-based auto-battlers with lightweight idle progression and hero gacha collection. 

Designed for a 3-month development cycle, the technical focus is placed on a **clean, decoupled, data-driven architecture** in Godot 4, procedural animation using run-time `Tween` nodes, dynamic facial expression states, and persistent state management.

[ MIYAWANA VILLAGE ] ├── Bakaneko AFK Farm (Passive currency via Unix timestamp
delta) ├── The Forge (Monster Hunter style craft, sharpness & weaknesses) └──
Hunter Recruitment / Gacha (Duplicates unlock passive Trait nodes) │ ▼
(Deploy 4-Hunter Squad) [ HORDE COMBAT (HORIZONTAL LANE) ] ├── Horizontal
Viewport camera panning + Macro orders on cooldown ├── Directional knockback &
Ballistic Launch physics ├── Faint & Gradual Revive system (No permanent squad
death) └── Off-Screen telegraph warning (Telegraphs heavy Apex attacks) │ ▼
(Rewards: Monster Loot + Zenny) [ UPGRADE CYCLE & PERSISTENCE (JSON) ]


---

## 2. Combat Design & Spatial Layout

### 2.1 Horizontal Lane & Camera Viewport
* **Single-Lane Battlefield:** The *Guild Gate* sits on the far-left ($X = 0$), and the *Horde Spawn Point* is placed on the far-right ($X \approx 1400$).
* **Free Viewport Panning:** The player does not move characters individually. Instead, the player smoothly drags or pans the camera horizontally to inspect the frontline or check base integrity.
* **Smart Directional Combat:** Hunters and monsters can face both directions and traverse each other. Knockback and launch vectors are calculated dynamically based on attacker origin ($\text{direction} = \text{sign}(X_{\text{victim}} - X_{\text{attacker}})$).
* **Off-Screen Hazard Telegraphing:** If a heavy monster or Apex boss charges an attack off-screen, a dynamic warning icon (`⚠️`) appears at the edge of the viewport indicating the incoming hazard's height and trajectory.

### 2.2 Squad Orders & Tactical Agency
To prevent visual clutter, the game enforces a strict ceiling of **4 Hunters vs. a maximum of 5–6 simultaneous monsters**:
* **Macro Squad Commands (Global Cooldown):**
  * `Advance / Aggressive:` Hunters press forward to close distance.
  * `Retreat / Defensive:` Hunters pull back to the Guild Gate to receive defensive coverage.
  * `Focus Fire:` Player clicks an enemy; all hunters prioritize that target regardless of frontline positioning.
* **Active Hunter Skills:** Energy bars fill during combat. Once charged, the player clicks hunter icons to release manual special skills (e.g., area-of-effect stuns, heavy slashes).

---

## 3. Procedural Tween Animation Pipeline & Visuals

To maximize visual quality while eliminating the bottleneck of drawing full traditional spritesheets, characters use high-detail **Chibi Pawn 2D Sprites** anchored at the feet, articulated via run-time procedural `Tween` curves and expression swapping:

| State / Reaction | Procedural Behavior | Visual & Mechanical Benefit |
| :--- | :--- | :--- |
| **Walk Cycle** | Foot-pivot pendular rotation (`-3°` to `+3°`) + subtle Y squash | Bouncy, expressive cartoon movement |
| **Light Hit (Flinch)** | Dynamic lean relative to strike angle + white flash shader | Immediate impact readability |
| **Heavy Hit (Knockback)** | Friction slide along ground with `EASE_OUT` + directional lean | Crunchy physical impact |
| **Air Launch (Heavy Attack)** | Parabolic arc spinning around center of mass $\rightarrow$ crash on back $\rightarrow$ inertia skid $\rightarrow$ spring recovery | Dramatic knockdown without broken physics |
| **Invulnerability (I-Frames)** | Hunter ignores damage while in `LAUNCHED` state until standing | Prevents physics desync & infinite juggles |
| **Faint & Revive** | Drops to `DEAD` face ($X\ X$), stays downed recovering HP $\rightarrow$ springs up | No permanent loss; tank/DPS recovery pacing |

---

## 4. Software Architecture in Godot 4

### 4.1 Data-Driven Design (`CustomResource`)
All static game data is decoupled into `.tres` files:

```gdscript
# HunterData.gd
class_name HunterData extends Resource

@export_group("Identity & Lore")
@export var id: String = "hunter_rathalos"
@export var hunter_name: String = "Rathalos Hunter"
@export_multiline var lore_description: String = "Backstory and personality..."

@export_group("Base Stats")
@export var max_health: float = 120.0
@export var base_attack: float = 30.0
@export var move_speed: float = 100.0
@export var revive_regen_rate: float = 25.0 # HP regenerated per second while fainted

@export_group("Visuals & Faces")
@export var texture_idle: Texture2D
@export var texture_hit: Texture2D
@export var texture_dead: Texture2D
@export var texture_idle_left: Texture2D # Optional: For asymmetrical designs
@export var special_faces: Dictionary = {} # Optional custom traits (e.g. "enraged")

@export_group("Abilities & Traits")
@export var active_skill: Resource # Holds ActiveSkillData
@export var traits: Array[Resource] = [] # Holds Array[TraitData]

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

4.2 State Machine & Hit Dispatching

Entities manage physics and visuals via strict finite states (IDLE_WALK, ACTING,
LAUNCHED, FAINTED), preventing animation clashes and position corruption. Damage
reception is unified under a single entry point:

func receive_hit(damage: float, knockback_force: float = 0.0, attacker_global_x: float = 0.0, is_launch: bool = false, launch_height: float = 120.0) -> void

4.3 Persistence & AFK Farm Offline Math

Player data is saved to a local JSON file. Idle progress is calculated by
comparing system Unix timestamps upon startup:

# Offline income calculation for the Bakaneko Farm
var current_time: int = Time.get_unix_time_from_system()
var elapsed_seconds: int = current_time - saved_profile.last_unix_timestamp
var elapsed_minutes: int = int(elapsed_seconds / 60)

var acorns_earned: int = min(elapsed_minutes * HARVEST_RATE_PER_MINUTE, MAX_CAPACITY)
saved_profile.acorns += acorns_earned

5. Scope Triage (3-Month Roadmap)

| Subsystem               | Priority            | Implementation Detail                                                                                                                        |
| :---------------------- | :------------------ | :------------------------------------------------------------------------------------------------------------------------------------------- |
| **Core Combat**         | **MUST (MVP)**      | 4 Autonomous Hunters, 3 basic monsters + 1 Apex Boss. Directional knockback, parabolic launches, I-Frames, squad orders, and damage numbers. |
| **The Forge**           | **MUST (MVP)**      | Spend monster drop parts + Zenny to craft and sharpen elemental weapons.                                                                     |
| **Recruitment / Gacha** | **MUST (MVP)**      | Hunter pool with duplicate detection unlocking passive `TraitData` nodes.                                                                    |
| **Bakaneko Farm (AFK)** | **MUST (MVP)**      | Passive Zenny/Acorns collection calculated via offline Unix timestamp delta.                                                                 |
| **Ginko's Casino**      | **COULD (Phase 2)** | Optional simple High/Low card gambling minigame.                                                                                             |
| **Lab & Kitchen**       | **BACKLOG**         | Deferred to post-internship updates.                                                                                                         |

6. Weekly Milestones (12 Weeks)

  - Weeks 1–3: Core combat viewport, horizontal movement, procedural squash &
    stretch tweens, launch & faint/revive state machines, and base
    CustomResource schemas.
  - Weeks 4–6: Monster AI roles, distance checking, physical/elemental damage
    formula, off-screen warning system, and squad orders.
  - Weeks 7–9: Village navigation, weapon crafting forge, gacha trait unlocking,
    and JSON save system with AFK offline math.
  - Weeks 10–12: Apex boss modifiers, sound effects (SFX), balancing, final
    build exports, and technical internship documentation.


---

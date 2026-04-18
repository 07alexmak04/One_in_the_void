# ☄️ One in the Void
**UM Game Jam 2026 Submission**

> "Integral hull breach. Navigation failure. You are alone, you are adrift, and you are losing control."

**One in the Void** is a high-octane 3D space survival game where survival isn't just about shooting rocks—it's about fighting against your own failing machine.

---

## 🕹️ The Hook: "Losing Control"
In this game, the theme is woven directly into the core mechanics. As your ship takes damage from the relentless meteorite field, it begins to malfunction:
- **Drift**: Your stabilizers fail, causing the ship to pull in random directions.
- **Control Inversion**: Impact shocks may temporarily reverse your steering.
- **Visual Interference**: HUD elements flicker and glitch as your power core fluctuates.

---

## 🏆 Special Challenges
We have implemented both optional game jam challenges:

### 1. 🤖 GLITCH-E (The Chaos Buddy)
A small, malfunctioning navigation drone that orbits your ship. GLITCH-E is technically "on your side," but its corrupted AI makes it unpredictable:
- **Helper Mode**: It will occasionally zap nearby meteorites with its plasma beam.
- **Chaos Mode**: It may accidentally shoot toward you, adding interference to your path!

### 2. 🗣️ Silly Voice Mode
Enabled via the **Main Menu toggle**, this mode replaces core sound effects with body/voice-generated SFX to meet the optional jam requirement.

---

## 🎮 Controls
| Action | Keys |
| :--- | :--- |
| **Move up/down** | `W` / `S` or arrows |
| **Move left/right** | `A` / `D` or arrows |
| **Shoot rifle** | `Space` (hold to auto-fire) |
| **Shoot rocket** | `R` (splash damage) |
| **Special Skill** | `Q` |
| **Pause** | `Esc` |

---

## 📊 Level Progress & Flow
Your mission follows a strict combat deployment path:
- **Main Menu** → `Start` | `Quit`
- **Level Select** → `Beginner` | `Intermediate` | `Hard`
- **Gameplay** → survive the timer without running out of health

| Level | Hits allowed | Survival time | Spawn rate | Meteor speed |
| :--- | :--- | :--- | :--- | :--- |
| **Beginner** | 5 | 15 s | 0.9 s | 12 u/s |
| **Intermediate** | 3 | 30 s | 0.55 s | 16 u/s |
| **Hard** | 1 | 60 s | 0.35 s | 22 u/s|

---

## 📂 Project Structure
```
one_in_the_void/
├── project.godot
├── scenes/
│   ├── main_menu.tscn       # Game entry point
│   ├── level_select.tscn
│   ├── gameplay.tscn        # Main spawner + HUD
│   ├── player.tscn          # Ship movement + malfunctions
│   ├── chaos_buddy.tscn     # The special challenge drone
│   └── victory.tscn
└── scripts/
    ├── game_state.gd        # Difficulty & Progression (Autoload)
    ├── player.gd            # Malfunction logic & movement
    └── chaos_buddy.gd       # Unpredictable drone AI
```

---

## 🚀 Technical Disclosures & Credits
This project was built during the UM Game Jam 2026 using **Godot 4.3 (Jolt Physics)**.

### **AI Usage Disclosure**
- **Coding**: Antigravity AI assisted with 3D physics integration, multi-viewport hangar rendering, and the "Silly Mode" remapping architecture.
- **Art**: The cinematic portrait of **Commander Yao** in the intro dialogue was generated via AI.

### **External Assets**
- **3D Ships & Rockets**: 'Battle-SpaceShip' & 'Missiles Pack' by **AurynSky**.
- **Meteorites**: 'LowPoly RockStones' by **Slaviandr**.
- **Planets**: '3D Planet Generator' by **naejimer**.
- **Music**: 'Outer Space Pack' collection.

# One in the Void

A 3D spaceship survival game built in Godot 4.6.
**Theme:** *Losing Control* — your ship has gone off course and drifted into a meteorite field. You cannot turn around. All you can do is dodge, shoot, and stay alive.

## Open the project

1. Open **Godot 4.6** (Forward+ renderer).
2. Choose **Import** and select `one_in_the_void/project.godot`.
3. Press **F5** / the Play button. The first scene is `scenes/main_menu.tscn`.

## Flow

- **Main Menu** → `Start` | `Quit`
- **Level Select** → `Beginner` | `Intermediate` | `Hard` | `Back`
- **Gameplay** → survive the timer without running out of health
- **Victory** → `Next Level` | `Quit` (back to menu)
- **Final Victory** (after Hard) → `Quit` only

## Levels

| Level        | Hits allowed | Survival time | Spawn rate  | Meteor speed |
|--------------|--------------|---------------|-------------|--------------|
| Beginner     | 5            | 15 s          | 0.9 s       | 12 u/s       |
| Intermediate | 3            | 30 s          | 0.55 s      | 16 u/s       |
| Hard         | 1            | 60 s          | 0.35 s      | 22 u/s       |

Tunables live in [scripts/game_state.gd](scripts/game_state.gd) under `LEVEL_CONFIG`.

## Controls

| Action         | Keys              |
|----------------|-------------------|
| Move up/down   | `W` / `S` or arrows |
| Move left/right| `A` / `D` or arrows |
| Shoot rifle    | `Space` (hold to auto-fire) |
| Shoot rocket   | `Shift` (splash damage) |
| Pause          | `Esc`             |

## Project layout

```
one_in_the_void/
├── project.godot
├── icon.svg
├── scenes/
│   ├── main_menu.tscn
│   ├── level_select.tscn
│   ├── gameplay.tscn
│   ├── player.tscn
│   ├── meteorite.tscn
│   ├── rifle_bullet.tscn
│   ├── rocket.tscn
│   ├── victory.tscn
│   └── final_victory.tscn
└── scripts/
    ├── game_state.gd          # autoload — difficulty + progression
    ├── main_menu.gd
    ├── level_select.gd
    ├── gameplay.gd            # spawner, HUD, pause, win/lose flow
    ├── player.gd              # spaceship movement + shooting + HP
    ├── meteorite.gd
    ├── rifle_bullet.gd
    ├── rocket.gd              # splash damage projectile
    ├── victory.gd
    └── final_victory.gd
```

## Optional external assets

The game ships entirely with Godot primitive meshes so it runs immediately. If you want to drop in the reference assets from the design brief, place them under `assets/` and swap the meshes in `player.tscn`, `meteorite.tscn`, and add a skybox / music:

- 3D Spaceship: https://free-game-assets.itch.io/battle-spaceship-free-3d-low-poly-models
- 3D Rocks: https://slaviandr.itch.io/lowpoly-rockstones
- Space background: https://deep-fold.itch.io/space-background-generator
- Music: https://gooseninja.itch.io/space-music-pack / https://leohpaz.itch.io/space-music-pack

## Notes on the design

- The ship's forward axis is locked to `-Z` — the "losing control" narrative is that the pilot cannot slow or turn; only lateral thrust works.
- Rocket applies splash damage in a 4-unit radius, useful when rocks cluster.
- Meteorites get tougher HP on higher difficulties (2 / 3 / 4), so the rifle is less reliable and the rocket becomes more valuable.
- Physics layers: `world`, `player`, `enemy`, `player_projectile`, `enemy_projectile` — wired in `project.godot` and set up per-node in the scripts.

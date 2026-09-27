# Shadow Shift

![Shadow Shift](screenshots/banner.png)

A short, atmospheric 2D platform-puzzle game made in **Godot 4.7.2**. A small hooded wanderer is lost in a ruined city at night. The way out only appears when you step between two versions of the world: **Light** and **Shadow**.

Press **Shift** to switch. Violet platforms exist only in the Shadow and amber platforms only in the Light. Whatever you are standing on disappears when you shift, so the trick is to **jump first and shift in mid-air**.

**▶ Play in your browser:** [itch.io page](YOUR-ITCH-LINK)

## What's inside

- **One mechanic, fully explored.** One level of 8 sections, each teaching a new use of Shadow Shift:
  - a gap that is too wide to jump
  - a wall you can only pass in the Shadow
  - an alternating staircase
  - a bridge covered in thorns that only hurt in the Shadow
  - a moving shadow platform
  - a vertical climb that switches world on every leap
- **Fair platforming.** Coyote time (you can still jump just after leaving a ledge), jump buffering and variable jump height (hold for a higher jump).
- **A safety rule for the mechanic.** You cannot shift if a platform would appear inside you, so you can never get stuck in a wall.
- **Lantern checkpoints.** Falling or touching a hazard sends you back to the last lantern you lit.
- **Hand-made look, no image files.** Everything is drawn in code with Godot's `_draw()`:
  - the hooded character, with squash-and-stretch
  - parallax ruins, stars and drifting dust
  - a moon that becomes an eclipse in the Shadow
  - a violet world tint, a vignette, camera shake and death particles
- **Full game loop.** Title screen, HUD (world state, timer, deaths), pause menu and a results screen with a rank:
  - *Unseen*: 0 deaths
  - *Wraith*: 1–5 deaths
  - *Survivor*: 6 or more deaths

| Light | Shadow |
|---|---|
| ![Light](screenshots/light.png) | ![Shadow](screenshots/shadow.png) |

| Thorn bridge | The exit |
|---|---|
| ![Thorn bridge](screenshots/thorn_bridge.png) | ![Finish](screenshots/finish.png) |

## Play

- **In the browser:** open the itch.io link above and click **Run game**.
- **From source:** open `project.godot` in **Godot 4.7.2** (standard build) and press **F5**.

## Controls

| Action | Keyboard | Controller |
|---|---|---|
| Move | A / D or arrow keys | Left stick / D-pad |
| Jump (hold for higher) | Space, W or Up | A |
| Shadow Shift | Shift, K or E | X / RB |
| Retry from last lantern | R | Y |
| Pause | Esc or P | Back |
| Start / play again | Enter | Start |

## How it works

| File | What it does |
|---|---|
| `scripts/game.gd` | Builds the whole level from a data table and holds the Light/Shadow state. Runs the game loop (death, respawn, checkpoints, exit) and builds the HUD and menus. |
| `scripts/player.gd` | Movement (coyote time, jump buffer, variable jump) and drawing the hooded character. |
| `scripts/platform.gd` | Stone, shadow and light platforms. Each answers `is_solid_in(shadow)` and turns its own collision on or off. |
| `scripts/hazard.gd` | Spikes (always deadly) and shadow thorns (deadly only in the Shadow). |
| `scripts/checkpoint.gd` | Lantern checkpoints. |
| `scripts/goal.gd` | The exit portal. |
| `scripts/background.gd` | Procedural parallax sky, moon, ruins and dust. |

The level is data, not hand-placed objects. Each platform is one line in `game.gd`:

```gdscript
[D, Rect2(1480, 480, 140, 22)],   # kind (S stone, D shadow, L light), x, y, width, height
```

A jump reaches about **128 px** up and **215 px** across, and every gap in the level is 60–80 px.

## Tests

`tools/route_bot.gd` is an automated playtest. For every jump in the level, it tries hundreds of combinations of jump timing, direction hold and mid-air shift through the real game physics. It reports how many of them land safely, so an impossible jump shows up immediately. It caught one real problem during development: the moving platform was too fast, so it was slowed down.

```
godot --headless --fixed-fps 60 --path . --script res://tools/route_bot.gd
godot --headless --path . --script res://tools/test_flow.gd
```

`test_flow.gd` checks three things:
- a shift is refused inside a wall
- death respawns you at the last lantern
- reaching the portal finishes the level

## Credits

Made by Vedant for the Cedar Codes mini game jam (Mission 1), in Godot 4.7.2. Built with help from Claude (AI) as a coding assistant.

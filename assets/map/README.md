# THOCK starter map

`ThockMap.rbxm` is a ready-made map: grass `Ground`, 8 `Plots`, a ring walkway in `Paths`, `Decor` and a centered `SpawnLocation` and a `Market` stall just behind the spawn at (0, 0, -14). There is no arena: the middle of the map is otherwise empty grass and players only walk base to base to steal. Keyfall Run is off via `GameConfig.Keyfall.Enabled = false`. The game code builds placeholder plots at runtime only when these are missing.

## Insert it

1. Open the place in Studio.
2. Right-click `Workspace` > Insert from File... > pick `assets/map/ThockMap.rbxm` (or drag the file into the viewport).
3. The file has several roots, so `Plots`, `Paths`, `Decor`, `SpawnLocation`, `Market` and `Ground` land directly in `Workspace`.
4. Delete the old `Baseplate`, then save to Roblox (File > Publish to Roblox).

## Rules

- Do not rename `Workspace.Plots`, `Plot1`..`Plot8`, or the `Base`, `RollKey` and `Board` parts in each plot. The server finds them by name.
- `Workspace.Market` needs a BasePart named `Counter`; the server adds the proximity prompt and recolors the `Cap1`..`Cap6` display keycaps. It builds the same stall at runtime when the model is missing.
- Everything else can be moved, recolored or decorated freely. Keep the plot positions if you want gameplay distances (delivery radius) to stay tuned, and keep radius 45 around the center free of props.
- `preview.png` is a top-down footprint render of the layout.

## Regenerate

```
lune run tools/build_map
lune run tools/export_footprints assets/map/ThockMap.rbxm footprints.json
python3 tools/render_preview.py footprints.json assets/map/preview.png
```

The preview step needs Pillow (`pip install pillow`). `tests/specs/map.spec.luau` validates the generated file.

## Key Market stall only

`assets/map/Market.rbxm` is the Key Market stall on its own (regenerate with `lune run tools/export_market` after `lune run tools/build_map`). In Studio: right-click Workspace → Insert from File… → `Market.rbxm`. Keep the model named `Market` directly in Workspace and keep its `Counter` part (the shop prompt goes there) and the display caps `Cap1`–`Cap6`. Move, rotate and decorate it freely, keep everything anchored, then save.

## Keyboard Escape obby

The obby is a giant keyboard you run across. Every key you step on presses down with a click and gives +speed (`GameConfig.Obby`: 24 base, +0.25 per tap, cap 80). Speed gets you past the obstacles further along. It is built at runtime from `GameConfig.Obby` (96 studs wide, opposite the Key Market, 64 studs from the map center) only when `workspace` has no model named `Obby`. To author it yourself, put a Model named `Obby` in Workspace. `lune run tools/export_obby` writes the generated level to `assets/map/Obby.rbxm` (ignored by version control) as a starting point.

Level 1 layout, entrance first: start pad (checkpoint), 12 rows of keys, safe area 1 (checkpoint + HOME pad), 12 rows over a maroon lava pit with missing keys and two pop-up keys (SHIFT, ENTER), speed gate (NEED 40 SPEED), end pad (checkpoint + HOME pad, "LEVEL 1 COMPLETE"). Three key pedestals: run A, over a lava hole in run B, and on the end pad.

Everything is driven by the `ObbyRole` attribute (string) on a BasePart anywhere under `workspace.Obby`, at any depth. Keep parts anchored.

| ObbyRole | Attributes | What it does |
| --- | --- | --- |
| `Zone` | none | Invisible box covering the whole course. Required: without it the server builds a placeholder. Taps, speed, checkpoints and key pickups only work inside it. Leaving it resets taps and speed. |
| `TapKey` | none | Each time a player's root enters the key's top footprint (up to 5 studs above its top) it counts +1 tap. Standing still does not count; leaving and re-entering does. The client presses the key down with a click. |
| `Kill` | none | Lava. A player whose root is inside its footprint (up to 4 studs above its top) dies. |
| `Checkpoint` | none | Standing on it sets the respawn point (kept through death) until the player leaves the Zone. |
| `Home` | none | Stepping on it sends the player to their own base. |
| `KeySpawn` | `Rarities` string, e.g. `"Epic,Legendary"` or weighted `"Rare:3,Epic:1"` | Marker where a rare keycap floats. Players hold E for 1.5s ("Take") within 10 studs. The key is lost on death and delivered at their base. Refills 60s after being taken. |
| `SpeedGate` | `RequiredSpeed` number (default 40) | Solid barrier. Players approach from its Back face (+Z side). With obby speed >= RequiredSpeed they are moved just past it; otherwise they get a "Need N speed!" toast. Put the sign (a SurfaceGui) on it yourself. |
| `PopUpKey` | `RiseHeight` (6), `UpSeconds` (1.5), `PeriodSeconds` (4), `PhaseSeconds` (0) | A key that rises `RiseHeight` studs for `UpSeconds` every `PeriodSeconds`, offset by `PhaseSeconds`. Make it tall (key height + RiseHeight) with its top flush with neighbouring keys so it walls the lane when up. Also counts as a tap key. |

Other parts (floors, walls, signs, decor) need no role. Delete `EndWall` on the generated level to attach level 2.

### Building level 2

1. Generate or insert the level 1 model, name it `Obby` in Workspace, and save.
2. Extend past `End`: delete `EndWall`, add keys (parts with `ObbyRole = TapKey`), more `Kill` slabs, `PopUpKey`s and a harder `SpeedGate` (for example `RequiredSpeed = 60`, which needs 144 taps).
3. Add a `Checkpoint` and a `Home` pad at the end of each new section, and `KeySpawn` pedestals with a `Rarities` attribute.
4. Resize the `Zone` box to cover the new area and continue the side walls.
5. Keep speeds reachable: speed = 24 + taps * 0.25, capped at 80.

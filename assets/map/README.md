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

## Keyboard Escape

Level 1 is a +1 speed keyboard course, not a jump obby. The server builds it at runtime when `Workspace.Obby` is missing or has no `Zone` part. It sits opposite the Key Market (`GameConfig.Obby.EntranceDistance`, 90 studs from the map center). The run is about 96 studs wide: a start pad, flat QWERTY rows to build speed, a safe zone with a HOME pad, hazard rows (missing keys over maroon lava, plus pop-up keys), a speed gate, then a finish pad with HOME and a "LEVEL 1 COMPLETE" sign.

Stepping on a key presses it and adds `SpeedPerTap` (0.25) to walk speed, from 24 up to 80. The gate stays shut until speed reaches `GateSpeed` (40). Leaving the zone or taking HOME resets that speed. Dying and respawning on a checkpoint keeps it. Rare keys sit on three pedestals; hold the prompt to take one, then carry it to your base. They are not auto-grabbed.

`lune run tools/export_obby` writes `assets/map/Obby.rbxm` from the same builder. That file is optional and is not part of the repo. In Studio: right-click Workspace → Insert from File… → `Obby.rbxm`, or build the parts yourself. Keep the model named `Obby` directly in Workspace. When a `Zone` part exists, the server uses your model as-is.

### Roles

The server walks every descendant and reads `ObbyRole`. These names all work (the second name is the Studio alias):

| Role | Alias | What it does |
| --- | --- | --- |
| `Zone` | | Invisible box around the course. Inside it, taps count, pickups work, and checkpoints stick. |
| `Tap` | `TapKey` | A key the player can step on. Optional `Letter` attribute. A sibling named `KeyNTop` presses with a part named `KeyNBody`. |
| `Popup` | `PopUpKey` | A tap key that also rises and sinks. `PopupUp`, `PopupDown`, `PopupPhase`, `PopupDepth` are seconds / studs. While it is down it does not collide. |
| `Kill` | | Lava. A root inside it, plus 4.5 studs above, dies. Keep it dark red and non-neon. |
| `Checkpoint` | | Sets the respawn until the player walks out of the zone. |
| `Finish` | | Same as a checkpoint, for the end pad. |
| `Return` | `Home` | Stepping on it sends the player to their base and clears obby speed. |
| `Gate` | `SpeedGate` | `SpeedNeeded` (number). Below that speed the player is pushed back and told the requirement. The wall stays non-solid so each player is judged on their own speed. |
| `KeySpawn` | | A pedestal. `Section` (or the older `Stage`) picks the rarity table in `GameConfig.Obby.Sections`. |
| `Wall` | | Solid sides and the far end so the lava cannot be walked around. |

Keep every part anchored.

### Level 2 without code

1. Duplicate the finish pad further down the run, or add new parts under `Workspace.Obby`.
2. Tag the new keys `Tap` / `TapKey`, holes in the floor as `Kill`, and the next barrier `SpeedGate` with a higher `SpeedNeeded`.
3. Add a `KeySpawn` with `Section` 1, 2, or 3.
4. Stretch the `Zone` so it covers the new parts.
5. Save the place. The server discovers nested roles on its own.

To change the generated level 1 instead, edit `FlatRows`, `HazardRows`, and `GateSpeed` in `GameConfig.Obby`. `Rules/Obby.Layout` places the rows; `ObbyService/Course` builds the parts.

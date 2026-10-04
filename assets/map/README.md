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

## Tap Obby only

`assets/map/Obby.rbxm` is the Tap Obby on its own: a 4-stage lava course (gaps, thin beams, staggered keycaps, a mixed gauntlet) with a safe area between stages, a start ramp and a finish platform. Regenerate it with `lune run tools/export_obby` (it runs the same `Course.luau` the server uses, so nothing needs building first).

In Studio: right-click Workspace → Insert from File… → `Obby.rbxm`. Keep the model named `Obby` directly in Workspace. When it exists the server uses it as-is; when it is missing (or has no `Zone` part) the server builds the same course at runtime opposite the Key Market, 64 studs from the map center (`GameConfig.Obby`).

The server finds parts by the `ObbyRole` attribute, so move, resize, recolor and decorate freely but keep the roles:

- `Zone`: invisible box covering the whole course. Inside it players get the tap walk speed, key pickups work and checkpoints are tracked.
- `Kill`: lava slabs. A player whose root is inside one (plus 4.5 studs above it) dies. Keep them dark red and non-neon.
- `Checkpoint`: safe area plinths (and the start platform). Standing on one sets the respawn point until the player leaves the zone.
- `Finish`: the final safe platform (also a checkpoint).
- `Return`: home pads; stepping on one sends the player to their own base.
- `KeySpawn` with a numeric `Stage` attribute (1-4): marker where a rare keycap floats. Stage picks the rarity table.
- `Wall`: side and end barriers that stop players walking around the lava. Keep them if you move the course.

Keep everything anchored. The default placement is on the opposite side of the map center from the Market (the Market's `Counter` part is used to find its angle), so the plot directly opposite the Market (plot 3 in the default map) must stay removed or the course will overlap it.

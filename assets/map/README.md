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

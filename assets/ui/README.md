# UI icon atlas

`icons.png` is a single 1024x1024 transparent sprite sheet: an 8x8 grid of 128px cells holding every UI icon (55 used, the rest empty). It is generated, so do not edit it by hand.

## Regenerate

```bash
PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node tools/icons/icons.svg.mjs
```

This redraws every icon from `tools/icons/icons.defs.mjs`, rasterizes with Chromium, writes `assets/ui/icons.png` and regenerates `src/client/Controllers/UIController/IconAtlas.luau` (names and cell positions; an `Image` id you already pasted is kept). Set `ICON_PREVIEW_DIR` to choose where the labelled preview sheets go. Add or reorder icons only in `icons.defs.mjs`.

## Upload to Roblox

1. Open Creator Hub, go to Creations (Development Items), then Decals/Images, and upload `assets/ui/icons.png`. Alternatively in Studio use View > Asset Manager > Images > Bulk Import. The sheet is 1024x1024, so Roblox keeps it at full size.
2. Wait for moderation to approve it and copy the asset id from the asset URL.
3. A Studio import creates a Decal; if the Decal id does not render in an ImageLabel, use the Image id of the Decal's `Texture` instead.
4. Open `src/client/Controllers/UIController/IconAtlas.luau` and set `Image = "rbxassetid://<id>"`.
5. Draw an icon with `IconAtlas.Apply(imageLabel, "Luck")`, which sets `Image`, `ImageRectOffset` and `ImageRectSize` and returns false while `Image` is empty or the name is unknown.

## Previewing before upload

```bash
PREVIEW_ATLAS=1 tools/ui_preview/run.sh
```

The harness sets the `IconAtlasPreview` attribute on ReplicatedStorage, so `Apply` uses `rbxassetid://preview-atlas` while `Image` is empty, and `tools/ui_preview/render.mjs` draws that from `assets/ui/icons.png`.

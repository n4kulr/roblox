# THOCK — Claude handoff (2026-10-07)

Paste this into the next session. Read **AGENTS.md** before changing code. Design ideas live in **BRAINSTORM.md**.

**Branch:** `claude/sharp-curie-svbmt1`  
**Owner:** n4kulr (not a programmer — keep explanations short and plain)  
**Session focus:** SAE-style pet meshes

---

## 1. What landed this session

### Pet mesh batch (DONE, pushed)

Commit **`096974c`** on `claude/sharp-curie-svbmt1` (~196 files). Untracked leftover: `assets/models/__pycache__/` (do not commit).

| What | Where |
| --- | --- |
| 26 pet OBJs | `assets/models/roster/pets_sae/*.obj` |
| Builder | `assets/models/_build_pets_sae.py` |
| Batch runner | `assets/models/_run_sae_batch.py` |
| Preview reframes / heroes | `_reframe_previews.py`, `_render_sae_heroes.py` |
| Preview sheets | `assets/models/previews/sae_pets_*.png`, `sae_hero_*.png` |
| Manifest | `assets/models/roster/manifest_sae_pets.json` |

**Style brief (owner):** ~90% Steal an Egg fandom Pets look — chunky plastic, dense studs/plates, **not** cube stubs. Then THOCK identity on Legendary+: gold rings, luck orbs, lightning bolts, keycap accents, phantom/laser/mythic FX. Do **not** copy SAE 1:1.

**Visual notes that stuck:**
- Dark purple preview backgrounds (white crushed contrast)
- No black outlines (they crushed colors)
- Hero cameras face **+Y front**, not backs
- Density / plates over low-poly stubs

**Not wired in-game yet.** `PetModels` / hatch viewport still use placeholders. `MeshTemplates` / `Meshes.luau` only cover Keycap / RollKey (and KeyboardCase path). Next engineering step if asked: Bulk Import OBJs → MeshIds → `Meshes.luau` or a `PetMeshes.luau` + wire `Utils/PetModels` / hatch reveal / base walkers.

### How to get pets into Roblox (owner asked)

1. Studio → Asset Manager → **Bulk Import** the 26 OBJs from `assets/models/roster/pets_sae/`.
2. Copy each MeshPart’s `MeshId` (`rbxassetid://…`).
3. Lead pastes ids into config (same pattern as `src/shared/Config/Meshes.luau`).
4. Game clones tinted MeshParts at runtime; empty string = fallback placeholders.
5. See `assets/models/README.md` for the Keycap/RollKey import pattern.

Blender on this machine: **5.2.2**, RPC on socket **9876** (`_blender_rpc.py`). Prefer that over assuming Blender MCP.

Studio MCP is enabled for Cursor (Assistant → Manage MCP Servers). Use it for playtest / viewport / place work when connected.

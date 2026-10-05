# THOCK — Handoff

Paste this file into the next AI session. It explains the project, where work stands, and how the owner likes to work.

Last updated: 2026-10-05, at commit 782f0a4 on `claude/sharp-curie-svbmt1`.

## The game

THOCK is a Roblox game about mechanical keyboards. It's an RNG game with income and base stealing, in the style of Steal a Brainrot.

- **Rolling:** players press the big roll key to get random keys. Keys come in 7 rarities: Common, Uncommon, Rare, Epic, Legendary, Mythic and Secret.
- **Income:** keys sit on the player's base board and earn Clicks, the currency.
- **Stealing:** players steal keys from other bases by holding E on a key. Rarer keys take longer to steal.
- **Other features:**
  - upgrades: Luck, Speed, Slots, Income, Golden Touch, Walls, Laser Lock
  - a Golden Roll every 100 rolls, sooner with Golden Touch
  - defense: glass walls and a laser lock
  - a Key Market stall
  - daily rewards
  - Robux store, passes and a season pass
  - rebirth, codes, leaderboards and trading
  - a "Keyboard Escape" obby: tap keys as you run to gain speed, hold E to grab rare keys and carry them home

## Repo and tooling

- **Repo:** github.com/n4kulr/roblox. Work branch: **`claude/sharp-curie-svbmt1`**. Commit and push only there, and don't open PRs unless asked.
- **Stack:** Rojo, with Wally packages in Packages/ and ServerPackages/ (git-ignored, installed with `wally install`). Strict Luau.
- **Rules:** read **AGENTS.md** before changing anything. The key rules:
  - no code comments
  - Init/Start/Destroy lifecycle
  - Trove cleanup
  - Packet networking with RateLimit
  - DataService (ProfileStore + Replica)
  - UI built in code under `src/client/Controllers/UIController`
- **Lead-owned files:** `src/shared/Packets.luau`, `src/shared/Config/*`, `src/shared/Rules/*` and `src/server/Data/PlayerData.luau`. Change them deliberately, not casually.
- **Tests:** a headless Lune test harness lives in `tests/` (`tests/harness`, specs in `tests/specs/*.spec.luau`). About 763 tests passed at 782f0a4. Every feature must ship with tests; this is a standing rule from the owner.
- **Full check:**
  - Run stylua, the luau-lsp typecheck, the rojo sourcemap and build, and all Lune tests.
  - In the previous cloud session this was a script at `<scratchpad>/check.sh <path>` with the tools in `<scratchpad>/bin`. A new session must recreate it, using the versions pinned in `aftman.toml`.
- **UI preview renderer:**
  - `tools/ui_preview/run.sh <outdir> 1280x720 [scenario]` renders every screen to PNG headlessly. It goes Lune, then JSON, then HTML, then a Playwright screenshot.
  - Use it to look at UI changes, since there's no Studio in the cloud.
- **Owner's setup:** the owner works on a Mac at `~/dev/roblox` with Rokit installed. Their workflow is `git pull` and then `rojo serve default.project.json --address 127.0.0.1`, connecting the Studio Rojo plugin to 127.0.0.1:34873. The place ID is 126712369980183.

## How the owner wants to work

- **Roles:** the lead AI does the thinking, design decisions and specs, and reviews and merges the work. Coding goes to **Sonnet 5.5 subagents**, run in parallel worktrees. The lead does verification itself.
- **Communication:** keep replies short, concrete and in plain language. The owner is a kid-game designer, not a programmer.
- **Map:** the owner edits the map in Studio. Never overwrite their map work, and don't ask them to reinsert map files.
- **Commit trailer:** every commit message ends with:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_012yg9Kt5wrtAVTPP3PQ736Y
  ```
  Don't put model names anywhere else in commits or code.
- **Taste:**
  - No neon; it's too bright.
  - Icons must be keyboard keycaps, never door keys.
  - No emojis in the UI.
  - The owner dislikes UI that looks "vibecoded". The target is **Stud UI Pack 2**, Pet Simulator 99, Grow a Garden and the top Roblox simulators: chunky, glossy, clean, flashy and satisfying.
- **Cursor commits:** some commits pushed from Cursor were reverted by the owner's choice (commit 8996882). Don't bring them back.

## In-flight work at last update

Five Sonnet agents were started in parallel, each in its own git worktree under `.claude/worktrees/`. Their work is **not merged yet**. If the cloud session is gone, that work is lost and must be redone from these specs.

1. **Icon atlas:**
   - A Node script draws about 52 SVG icons in the Stud style (thick #1A1530 outline, gradient, gloss, drop shadow) into a 1024x1024 PNG of 128px cells at `assets/ui/icons.png`.
   - It also writes `src/client/Controllers/UIController/IconAtlas.luau`, which holds `Image` (empty until the owner uploads the PNG), `CellSize`, `Rects` and `Apply(label, name)`.
   - The preview renderer supports the atlas through the image id `rbxassetid://preview-atlas`.
2. **UI overhaul:** a full Stud UI Pack 2-style rework of Kit and every screen.
   - **Text:** FredokaOne, white text with a dark stroke.
   - **Buttons:** 3 layers (shadow, gradient body, gloss) with a 3px outline, hover scale and a press squish.
   - **Modals:** a white body, a colored header ribbon with an icon badge, a big red round X, a dimmed background and a bounce on open. They close with ESC or by clicking outside.
   - **HUD top:** **SHOP left of MY BASE**, equal size. SHOP teleports to the market, and both are blocked while carrying a key (Travel module).
   - **HUD sides and bottom:** big square menu buttons with badges and tooltips; a huge ROLL button with Auto and Golden squares (the Golden fill rises with progress); stat chips.
   - The Kit icon tries IconAtlas first and falls back to Glyphs.
3. **Roll popup (DONE, merged; `RollController/ResultCards.luau`):**
   - Fix the bug where two simultaneous results get their text cropped by an invisible element.
   - Make the reveal satisfying: Back-ease pop-in, a burst behind Rare+, shimmer and shake on Epic+, confetti and a banner on Legendary+, a gold Golden variant, and a cap on stacking during auto-roll.
4. **Loading screen (DONE, merged; `src/first/Loading`, ReplicatedFirst):**
   - It lives in ReplicatedFirst. "THOCK" is typed on 5 glossy keycaps, with a key-row progress bar and tips.
   - It waits for `game:IsLoaded()` plus a `ClientReady` player attribute, with a 30s timeout. A SKIP button appears after 8s, and the keys fly out on exit.
5. **Obby (DONE, merged):**
   - Tap keys became the **same Keycap mesh as the base floor keys**: cream (222,218,208), no letters, 6.56 footprint, 2.2 tall, 0.24 gap.
   - Pop-up keys use the Epic color; the keycap mesh stretches vertically on them (8.2 tall), left unpolished.
   - They're skinned at runtime from MeshTemplates (`ObbyService/Skin.luau`).
   - The whole obby is committed as `assets/map/Obby.rbxm` (354 parts) to drag into Workspace; a spec stops it drifting from the builder. The game uses `workspace.Obby` if present.

**Next steps after the agents finish:**
1. Merge each branch into `claude/sharp-curie-svbmt1` and run the full check.
2. Render all screens and review them yourself.
3. Push.
4. Tell the owner to upload `assets/ui/icons.png` and paste the id into IconAtlas.luau.
5. Send before-and-after screenshots.

## Known notes

- `GameConfig.Keyfall.Enabled = false`; the owner doesn't want Keyfall.
- The obby gives +1 speed per tap, up to 80. The level 1 gate needs 40, which a straight run reaches.
- The obby entrance is 96 studs wide, opposite the Market. The owner will design later levels themselves using `ObbyRole` attributes (see `assets/map/README.md`).
- Max players should be 6, set by the owner in Game Settings.
- Robux passes and products still have AssetId 0 until the owner creates them.

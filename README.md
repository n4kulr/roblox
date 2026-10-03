# Frazer's Game Boilerplate

I made this boilerplate/template because I'm tired of people not using AI correctly to make Roblox games.

Ask your agent to set up the boilerplate by running the install scripts, and the rest is easy!

<details>
<summary>For AI agents:</summary>

If you're an agent, please refer to [AGENTS.md](/AGENTS.md) before making any code changes or install scripts.

</details>

## THOCK prototype

THOCK is a mechanical-keyboard RNG and incremental game. This prototype covers one loop: press the roll key, get a keycap, hear its sound, slot it into your keyboard, earn Clicks per second.

### Run it

```powershell
./scripts/install.ps1
rojo serve default.project.json --address 127.0.0.1
```

Open the place in Studio and connect the Rojo plugin to `localhost:34873`.

### Studio steps

- Publish the place, then enable **Game Settings > Security > Enable Studio Access to API Services**. Without it, data is mock data that resets when Play stops.
- Create a ScreenGui named `Hud` in StarterGui with two TextLabels named `Cash` and `Income`, and save the place. If it is missing, the HUD is disabled with a warning.
- Plots are optional. If `workspace.Plots` (a Folder of Models, each with BaseParts `Base`, `RollKey` and `Board`) does not exist, the server builds 8 placeholder plots and warns once.

### Notes

- Sounds are placeholders (built-in Roblox clicks and pings). Replace the sound ids, rarities, income and keys in `src/shared/Config/Keys.luau`; gameplay tunables are in `src/shared/Config/GameConfig.luau`.
- Controls: left click or tap the roll key, or press E / gamepad R2 within range.

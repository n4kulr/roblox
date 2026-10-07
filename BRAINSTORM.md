# THOCK brainstorm and to-do

Ideas and planned work. Tick items off as they ship.

## Top 5 next (recommended)

- [ ] Floating income numbers on base keys
- [ ] Auto-place best keys
- [ ] Sell junk with key locks
- [ ] Daily login streak
- [ ] Directional steal alerts

## Less tedious

- [ ] **Auto-place best keys**: a "Best" button fills the 8 slots with the highest earners; an optional setting auto-swaps when a better key is rolled.
- [ ] **Sell junk quickly**: "Sell all Common" or "sell everything below Rare", plus a lock toggle on keys to keep.
- [ ] **Auto-fuse**: prompt when 5 of the same key are owned, or fuse automatically when that setting is on.
- [ ] **Bulk hatch**: unlock hatching 3 eggs at once later in progression.
- [ ] **Skip-animation toggle** for common rolls and hatches; Rare and above always play.
- [ ] **Teleport buttons**: BASE, SHOP and EGGS jump straight there.

## Clearer

- [ ] **Floating income numbers**: "+1.2K" pops off base keys every few seconds.
- [ ] **Offline earnings screen**: "While you were away you earned 340K", with a count-up and an optional 2x through a product.
- [ ] **"New best!" callout** when a roll beats your worst slotted key, with a one-tap "place it".
- [ ] **Index completion rewards**: collecting every key of a rarity gives a small permanent boost.
- [ ] **Upgrade affordability hints**: a glow or badge on upgrades you can afford now (partly exists).

## Stealing

- [ ] **Directional steal alerts**: a screen-edge arrow toward the thief, plus a big "STOP THEM" moment.
- [ ] **Revenge button**: teleport near the last player who stole from you.
- [ ] **Protected key slot**: one key on your base can't be stolen; a second slot could be a game pass.

## Retention and monetization

- [ ] **Daily login streak**: a 7-day calendar on top of the existing playtime gifts.
- [ ] **Limited-time event egg**: rotates weekly, with a countdown on the egg bar.
- [ ] **Friend boost**: +10% luck per friend in the server, shown on the HUD.
- [ ] **Server luck events**: a server-wide banner naming who bought server luck, with "2x rolls for 10 min".

## Polish

- [ ] **Settings**: separate music and SFX sliders, a low-graphics toggle (the flag already exists), and mute for other players' key sounds.
- [ ] **Mobile pass**: bigger hit areas, a thumb-reachable roll button, and no overlap on small phones.

## Owner is doing these later

- [ ] Group chest in the map (group-gated; Roblox can't verify likes or favorites, and rewarding them is likely against the rules).
- [ ] Rebirth through the obby, gated by player level (for example, level 10 for the first rebirth).
- [ ] Obby redesign (the obby is disabled; leave its code alone until then).
- [ ] Custom 3D models for eggs, pets and keys, dropped into `ReplicatedStorage.Assets.Eggs/Pets/Keys` (pets batch: see `CLAUDE_HANDOFF.md`).

## Known follow-ups

- [ ] Galaxy Enter planets don't spin.
- [ ] RollController sends base ids only, so variants in reveals need a KeyId.
- [ ] Starter Pack "Worth R$ 99" is a placeholder.
- [ ] Music sound ids in `Config/Music.luau`.
- [ ] Robux product AssetIds are 0.
- [ ] Set max players to 6.
- [ ] Verify in Studio: the key legend overlay in viewports, and the hatch "fly to PETS" exit.

## Core loop (as shipped) — design notes 2026-10-07

**One sentence:** stand in base → roll keys → place best on board → earn Clicks → buy/place eggs → hatch pets → steal keys → rebirth.

| Pillar | Detail |
| --- | --- |
| Roll | Big Roll Key, 7 rarities, only inside own base |
| Income | Up to 8 board slots (`GameConfig.BoardSlots`) |
| Steal | Hold E; rarer = longer; carry home |
| Eggs/pets | Market eggs → place on base → hatch charms (`Config/Eggs.luau`, `Config/Charms.luau`) |
| Soft tutorial today | `TutorialController`: steps 0–1 only (“TAP THE KEY” / “ROLL AGAIN”). Roll 3 = guaranteed Rare. `TheftLessonDone` slows first steal for victims. |

**Verdict:**

- Structurally good — clear dopamine + PvP + theme.
- Short-term addicting — roll reveal + steal. Risk: AFK auto-roll kills the fantasy.
- Loop is deeply overdone (Steal a Brainrot / Pets Go clone space). Keyboard feel is the only real differentiator.
- Dual progression (keys and pets) can compete; eggs should support the board fantasy, not be a second game.
- Don’t invent a new genre — own the fantasy: thock a switch, build a keyboard, rip their keycap, hatch keycap pets.

## First 5 minutes — make it HELLA engaging (direction, not shipped)

**Goal sentence new players must learn:**  
> Press key → get cooler key → put it on your board → get richer → steal theirs.

Hide Market / Shop / Season / Rebirth until that sentence is muscle memory. Pets = dessert after the board clicks.

### Beat sheet

| Time | Beat | Do this |
| --- | --- | --- |
| 0:00 | Cold open | Spawn in base. Pulsing Roll Key. One line: **PRESS THE KEY.** No menus. |
| 0:10 | First thock | Authored Common. Exaggerated press + SFX. Auto-place. Floating `+/s`. |
| 0:25 | Escalation | Rolls 2–3; roll 3 Rare (already guaranteed) + stinger: “THIS EARNS MORE.” |
| 0:45 | Board fantasy | Frame the board: “YOUR KEYBOARD EARNS CLICKS.” Ticker visible. |
| 1:00 | Power fantasy | Scripted Epic. Confetti. “KEEP ROLLING.” |
| 1:30 | Steal tease | Beam to NPC/soft target. Short hold-E. Carry keycap home → board. |
| 2:15 | Defense | Auto-lock ~30s. “THEY CAN’T TAKE YOURS YET.” |
| 2:45 | Egg dessert | One free Linear Egg, beam to place, **fast** tutorial hatch, pet walks, `x1.2` pop. |
| 3:30 | Sandbox | Hints off. Auto-roll on. Soft goals: fill 4 slots / steal 1 real key. |
| 4:30 | Stay hook | Golden-roll progress tease or near-Legendary flex. |

### Clarity test (must pass at ~0:40 without reading UI)

1. What do I press? → the big key  
2. Why? → cooler keys = more money  
3. Where does money come from? → the board  
4. What are other players? → I can take their keys  

### Ship order if only 4 things get built

1. Authored first-roll sequence + auto-place + big `+/s`  
2. Forced first steal (NPC or soft target) + keycap carry feel  
3. One free fast egg after steal  
4. Exaggerate roll/steal audio-visual until it feels illegal  

### Standing out (theme as mechanics, not skins)

| Generic clone | THOCK |
| --- | --- |
| Roll pet/brainrot | **Thock a switch** |
| Place on pad | **Build a keyboard** |
| Steal hold-E | **Rip their keycap** |
| Hatch pet | **Egg → keycap pet on the board** |

Later (not first 5 min): slot synergies / layouts, louder steal counterplay, switch-sound status, delay long AFK incubators.

### Code touchpoints for onboarding work

- `src/client/Controllers/TutorialController.luau` — expand past steps 0–1  
- `src/server/Services/RollService/init.luau` — tutorial / guaranteed rolls (`GuaranteedRareRoll = 3`)  
- `src/server/Data/PlayerData.luau` — `Tutorial`, `TheftLessonDone`  
- `src/client/Controllers/UIController/Screens/Hud.luau` — observes Tutorial  
- Steal lesson: `StealService`, `Rules/Steal.luau`, `GameConfig.Steal.Lesson*`  
- Egg guide: `EggController/Guide.luau`, `Config/Eggs.Guide`  
- Hatch UX: `Screens/Hatch.luau`, `Utils/PetModels`, `Utils/EggModel`

**Contract files** (ask before casual edits): `Packets.luau`, `Config/*`, `Rules/*`, `PlayerData.luau`.

## Suggested next asks (from 2026-10-07 session)

- [ ] **Wire SAE pets** — Bulk Import + MeshIds + PetModels / walkers / hatch viewport (see `CLAUDE_HANDOFF.md`)
- [ ] **First-5-min tutorial** — implement the beat sheet above
- [ ] **Roll/steal juice** — thock SFX, press travel, steal yank feel
- [ ] **Retune early economy** — faster Epic/Legendary; align with scripted tutorial drops

Do not start large systems until the owner picks one.

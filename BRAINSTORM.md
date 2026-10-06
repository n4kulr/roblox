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
- [ ] Custom 3D models for eggs, pets and keys, dropped into `ReplicatedStorage.Assets.Eggs/Pets/Keys` (see HANDOFF.md).

## Known follow-ups

- [ ] Galaxy Enter planets don't spin.
- [ ] RollController sends base ids only, so variants in reveals need a KeyId.
- [ ] Starter Pack "Worth R$ 99" is a placeholder.
- [ ] Music sound ids in `Config/Music.luau`.
- [ ] Robux product AssetIds are 0.
- [ ] Set max players to 6.
- [ ] Verify in Studio: the key legend overlay in viewports, and the hatch "fly to PETS" exit.

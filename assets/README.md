# Assets

## Background music

The classical playlist lives in `src/shared/Config/Music.luau`. Each entry is `{ Name, SoundId }` and tracks with an empty `SoundId` are skipped, so the game runs silently until ids are filled in.

To add a track:

1. Open the Creator Store in Studio, choose Audio and search for "classical" or "piano". Roblox-uploaded and licensed tracks are free to use.
2. Copy the asset id and set `SoundId = "rbxassetid://<id>"` on the matching entry (add or rename entries freely).
3. Run `./scripts/check.ps1`.

`BaseVolume` is multiplied by the player's `MusicVolume` setting; `CrossfadeSeconds` is the overlap between tracks.

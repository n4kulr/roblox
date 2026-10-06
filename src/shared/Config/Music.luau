--!strict

export type Track = {
	Name: string,
	SoundId: string,
}

local Music = {
	BaseVolume = 0.35,
	CrossfadeSeconds = 2,
	DuckMultiplier = 0.3,
	DuckFadeSeconds = 0.4,
	VolumeFadeSeconds = 0.25,
	LoadTimeoutSeconds = 10,
	PollSeconds = 0.25,
	Playlist = {
		{ Name = "Clair de Lune", SoundId = "" },
		{ Name = "Gymnopedie No.1", SoundId = "" },
		{ Name = "Canon in D", SoundId = "" },
		{ Name = "Moonlight Sonata", SoundId = "" },
		{ Name = "Spring (Vivaldi)", SoundId = "" },
	} :: { Track },
}

return table.freeze(Music)

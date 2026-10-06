--!strict

return table.freeze({
	NearMargin = 14,
	FarLimit = 60,
	WobbleRange = 160,
	ReadyDelayPadding = 0.1,
	HatchPromptHold = 0.6,
	HatchPromptRange = 12,
	HatchActionText = "Hatch",
	ValidColor = Color3.fromRGB(90, 235, 120),
	InvalidColor = Color3.fromRGB(255, 80, 80),
	FullVerdict = "Full",
	OkVerdict = "Ok",
	FailToast = "Couldn't place that egg!",
	Messages = table.freeze({
		Invalid = "Place eggs on your base!",
		Bounds = "Place eggs on your base!",
		RollKey = "Not on the Roll Key!",
		Spacing = "Too close to another egg!",
	} :: { [string]: string }),
	Wobble = table.freeze({
		IdleAmplitude = 0.045,
		IdleSpeed = 1.6,
		ReadyAmplitude = 0.11,
		ReadySpeed = 5,
		SwayRatio = 0.8,
	}),
})

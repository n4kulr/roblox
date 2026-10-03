--!strict

export type Clip = { Start: number, Length: number }
export type Switch = { Id: string, Name: string, Presses: { Clip }, Release: Clip? }

return table.freeze({
	SpriteId = "rbxassetid://112299938536962",
	Switches = table.freeze({
		MxBlack = table.freeze({
			Id = "MxBlack",
			Name = "Cherry MX Black",
			Presses = table.freeze({
				table.freeze({ Start = 0.000, Length = 0.064 }),
				table.freeze({ Start = 0.364, Length = 0.064 }),
				table.freeze({ Start = 0.728, Length = 0.064 }),
				table.freeze({ Start = 1.092, Length = 0.064 }),
			}),
			Release = table.freeze({ Start = 1.456, Length = 0.050 }),
		}),
		MxRed = table.freeze({
			Id = "MxRed",
			Name = "Cherry MX Red",
			Presses = table.freeze({
				table.freeze({ Start = 1.806, Length = 0.151 }),
				table.freeze({ Start = 2.257, Length = 0.156 }),
				table.freeze({ Start = 2.713, Length = 0.147 }),
				table.freeze({ Start = 3.159, Length = 0.156 }),
			}),
		}),
		MxBrown = table.freeze({
			Id = "MxBrown",
			Name = "Cherry MX Brown",
			Presses = table.freeze({
				table.freeze({ Start = 3.615, Length = 0.094 }),
				table.freeze({ Start = 4.009, Length = 0.094 }),
				table.freeze({ Start = 4.403, Length = 0.094 }),
				table.freeze({ Start = 4.798, Length = 0.094 }),
			}),
			Release = table.freeze({ Start = 5.192, Length = 0.071 }),
		}),
		MxBrownPbt = table.freeze({
			Id = "MxBrownPbt",
			Name = "Cherry MX Brown PBT",
			Presses = table.freeze({
				table.freeze({ Start = 5.563, Length = 0.134 }),
				table.freeze({ Start = 5.997, Length = 0.146 }),
				table.freeze({ Start = 6.443, Length = 0.165 }),
				table.freeze({ Start = 6.907, Length = 0.182 }),
			}),
		}),
		MxBlue = table.freeze({
			Id = "MxBlue",
			Name = "Cherry MX Blue",
			Presses = table.freeze({
				table.freeze({ Start = 7.389, Length = 0.069 }),
				table.freeze({ Start = 7.759, Length = 0.069 }),
				table.freeze({ Start = 8.127, Length = 0.069 }),
				table.freeze({ Start = 8.496, Length = 0.069 }),
			}),
			Release = table.freeze({ Start = 8.865, Length = 0.031 }),
		}),
		NkCream = table.freeze({
			Id = "NkCream",
			Name = "NK Cream",
			Presses = table.freeze({
				table.freeze({ Start = 9.196, Length = 0.197 }),
				table.freeze({ Start = 9.693, Length = 0.231 }),
				table.freeze({ Start = 10.224, Length = 0.201 }),
				table.freeze({ Start = 10.725, Length = 0.244 }),
			}),
		}),
		CreamTravel = table.freeze({
			Id = "CreamTravel",
			Name = "Cream Travel",
			Presses = table.freeze({
				table.freeze({ Start = 11.269, Length = 0.071 }),
				table.freeze({ Start = 11.639, Length = 0.071 }),
				table.freeze({ Start = 12.010, Length = 0.071 }),
				table.freeze({ Start = 12.381, Length = 0.071 }),
			}),
			Release = table.freeze({ Start = 12.751, Length = 0.054 }),
		}),
		Turquoise = table.freeze({
			Id = "Turquoise",
			Name = "Turquoise",
			Presses = table.freeze({
				table.freeze({ Start = 13.105, Length = 0.085 }),
				table.freeze({ Start = 13.491, Length = 0.085 }),
				table.freeze({ Start = 13.876, Length = 0.085 }),
				table.freeze({ Start = 14.261, Length = 0.085 }),
			}),
			Release = table.freeze({ Start = 14.646, Length = 0.048 }),
		}),
		EgOreo = table.freeze({
			Id = "EgOreo",
			Name = "EG Oreo",
			Presses = table.freeze({
				table.freeze({ Start = 14.994, Length = 0.114 }),
				table.freeze({ Start = 15.408, Length = 0.120 }),
				table.freeze({ Start = 15.828, Length = 0.112 }),
				table.freeze({ Start = 16.240, Length = 0.110 }),
			}),
		}),
		EgCrystalPurple = table.freeze({
			Id = "EgCrystalPurple",
			Name = "EG Crystal Purple",
			Presses = table.freeze({
				table.freeze({ Start = 16.650, Length = 0.134 }),
				table.freeze({ Start = 17.083, Length = 0.128 }),
				table.freeze({ Start = 17.511, Length = 0.124 }),
				table.freeze({ Start = 17.935, Length = 0.129 }),
			}),
		}),
		HolyPanda = table.freeze({
			Id = "HolyPanda",
			Name = "Holy Panda",
			Presses = table.freeze({
				table.freeze({ Start = 18.365, Length = 0.067 }),
				table.freeze({ Start = 18.731, Length = 0.065 }),
				table.freeze({ Start = 19.096, Length = 0.066 }),
				table.freeze({ Start = 19.463, Length = 0.066 }),
			}),
			Release = table.freeze({ Start = 19.829, Length = 0.053 }),
		}),
		ToprePurple = table.freeze({
			Id = "ToprePurple",
			Name = "Topre Purple Hybrid",
			Presses = table.freeze({
				table.freeze({ Start = 20.182, Length = 0.174 }),
				table.freeze({ Start = 20.656, Length = 0.182 }),
				table.freeze({ Start = 21.138, Length = 0.198 }),
				table.freeze({ Start = 21.635, Length = 0.188 }),
			}),
		}),
	}),
})

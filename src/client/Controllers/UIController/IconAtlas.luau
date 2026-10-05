--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Atlas = {
	Image: string,
	CellSize: number,
	Rects: { [string]: Vector2 },
	Apply: (label: ImageLabel | ImageButton, name: string) -> boolean,
}

local IconAtlas: Atlas = nil :: any

IconAtlas = table.freeze({
	Image = "rbxassetid://103213574924512",
	CellSize = 128,
	Rects = table.freeze({
		Keys = Vector2.new(0, 0),
		Upgrades = Vector2.new(128, 0),
		Index = Vector2.new(256, 0),
		Rebirth = Vector2.new(384, 0),
		Daily = Vector2.new(512, 0),
		Gift = Vector2.new(640, 0),
		Store = Vector2.new(768, 0),
		Leaderboard = Vector2.new(896, 0),
		Pass = Vector2.new(0, 128),
		Shop = Vector2.new(128, 128),
		Home = Vector2.new(256, 128),
		Settings = Vector2.new(384, 128),
		Roll = Vector2.new(512, 128),
		Auto = Vector2.new(640, 128),
		Golden = Vector2.new(768, 128),
		Clicks = Vector2.new(896, 128),
		Luck = Vector2.new(0, 256),
		Speed = Vector2.new(128, 256),
		Slots = Vector2.new(256, 256),
		Income = Vector2.new(384, 256),
		Walls = Vector2.new(512, 256),
		LockTime = Vector2.new(640, 256),
		Lock = Vector2.new(768, 256),
		Unlock = Vector2.new(896, 256),
		Trade = Vector2.new(0, 384),
		Sound = Vector2.new(128, 384),
		Music = Vector2.new(256, 384),
		Graphics = Vector2.new(384, 384),
		Code = Vector2.new(512, 384),
		Crown = Vector2.new(640, 384),
		Check = Vector2.new(768, 384),
		Close = Vector2.new(896, 384),
		Plus = Vector2.new(0, 512),
		Minus = Vector2.new(128, 512),
		Robux = Vector2.new(256, 512),
		Clock = Vector2.new(384, 512),
		Warning = Vector2.new(512, 512),
		Thief = Vector2.new(640, 512),
		Sparkle = Vector2.new(768, 512),
		Potion = Vector2.new(896, 512),
		Globe = Vector2.new(0, 640),
		People = Vector2.new(128, 640),
		Run = Vector2.new(256, 640),
		Gem = Vector2.new(384, 640),
		Season = Vector2.new(512, 640),
		Arrow = Vector2.new(640, 640),
		Info = Vector2.new(768, 640),
		Fire = Vector2.new(896, 640),
		Heart = Vector2.new(0, 768),
		Bell = Vector2.new(128, 768),
		Search = Vector2.new(256, 768),
		Sell = Vector2.new(384, 768),
		Equip = Vector2.new(512, 768),
		Star = Vector2.new(640, 768),
		Megaphone = Vector2.new(768, 768),
	}),
	Apply = function(label: ImageLabel | ImageButton, name: string): boolean
		local rect: Vector2? = IconAtlas.Rects[name]
		local image = IconAtlas.Image
		if image == "" then
			local preview = ReplicatedStorage:GetAttribute("IconAtlasPreview")
			if type(preview) == "string" then
				image = preview
			end
		end
		if image == "" or rect == nil then
			return false
		end
		local target: any = label
		target.Image = image
		target.ImageRectOffset = rect
		target.ImageRectSize = Vector2.new(IconAtlas.CellSize, IconAtlas.CellSize)
		return true
	end,
})

return IconAtlas

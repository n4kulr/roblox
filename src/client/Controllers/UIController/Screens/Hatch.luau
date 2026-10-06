--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CharmConfig = require(ReplicatedStorage.Config.Charms)
local Eggs = require(ReplicatedStorage.Config.Eggs)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Charms = require(ReplicatedStorage.Rules.Charms)
local EggModel = require(ReplicatedStorage.Utils.EggModel)
local PetModels = require(ReplicatedStorage.Utils.PetModels)
local HatchPlan = require(script.Parent.Parent.HatchPlan)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)
local Viewport = require(script.Parent.Parent.Viewport)

type Shard = { Frame: Frame, Angle: number, Speed: number, Spin: number }
type Piece = { Frame: Frame, Angle: number, Speed: number, Spin: number, Color: number }
type Star = { Frame: Frame, Angle: number, Radius: number, Phase: number }

local theme = Kit.Theme
local eggSize = 320
local petSize = 340
local centerY = 0.47
local shardCap = 24
local confettiCap = 40
local starCap = 14
local lineCount = HatchPlan.CrackLines
local minTapTime = 0.25
local queueLimit = 5
local dropFall = 0.4
local dropBounce = 0.15
local gravity = 900
local shardLife = 1.3
local confettiLife = 2.2
local white = Color3.new(1, 1, 1)
local ink = theme.Ink
local gold = theme.Gold
local rainbowColors: { Color3 } = {
	Color3.fromRGB(255, 92, 110),
	Color3.fromRGB(255, 190, 70),
	Color3.fromRGB(110, 235, 110),
	Color3.fromRGB(70, 200, 255),
	Color3.fromRGB(170, 110, 255),
}

local HatchScreen = {}

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

local function backOut(alpha: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	local t = alpha - 1
	return 1 + c3 * t ^ 3 + c1 * t ^ 2
end

local function box(parent: Instance, name: string, z: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.ZIndex = z
	frame.Visible = false
	frame.Parent = parent
	return frame
end

local function tintBurst(burst: Frame, color: Color3)
	for _, child in burst:GetChildren() do
		if child:IsA("ImageLabel") then
			child.ImageColor3 = color
		elseif child:IsA("Frame") then
			child.BackgroundColor3 = color
		end
	end
end

function HatchScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local playUi = Kit.UiSound(context.Controllers)
	local random = Random.new(7)

	local gui, root = Kit.ScreenGui("ThockHatch", 30, context.PlayerGui, trove)
	gui.Enabled = false

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.BackgroundColor3 = ink
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Parent = root

	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.BackgroundTransparency = 1
	stage.BorderSizePixel = 0
	stage.Size = UDim2.fromScale(1, 1)
	stage.ZIndex = 2
	stage.Parent = root

	local rays = Kit.Burst({
		Parent = stage,
		Diameter = 1100,
		Position = UDim2.fromScale(0.5, centerY),
		Color = white,
	})
	rays.Name = "Rays"
	rays.Visible = false

	local stars: { Star } = {}
	for index = 1, starCap do
		local frame = box(stage, `Star{index}`, 3)
		frame.Size = UDim2.fromOffset(26, 26)
		for turn = 0, 1 do
			local arm = Instance.new("Frame")
			arm.Name = `Arm{turn}`
			arm.BackgroundColor3 = gold
			arm.BorderSizePixel = 0
			arm.AnchorPoint = Vector2.new(0.5, 0.5)
			arm.Position = UDim2.fromScale(0.5, 0.5)
			arm.Size = UDim2.fromScale(0.7, 0.7)
			arm.Rotation = turn * 45
			arm.Parent = frame
		end
		table.insert(stars, {
			Frame = frame,
			Angle = (index - 1) * (360 / starCap) + random:NextNumber() * 12,
			Radius = 230 + random:NextNumber() * 170,
			Phase = random:NextNumber() * 6,
		})
	end

	local eggHolder = box(stage, "EggStage", 4)
	eggHolder.Size = UDim2.fromOffset(eggSize, eggSize)
	local eggScale = Instance.new("UIScale")
	eggScale.Parent = eggHolder
	local eggBox = Instance.new("Frame")
	eggBox.Name = "Tilt"
	eggBox.BackgroundTransparency = 1
	eggBox.BorderSizePixel = 0
	eggBox.AnchorPoint = Vector2.new(0.5, 0.5)
	eggBox.Position = UDim2.fromScale(0.5, 0.5)
	eggBox.Size = UDim2.fromScale(1, 1)
	eggBox.Parent = eggHolder
	local eggView = Viewport.new({
		Parent = eggBox,
		Name = "EggModel",
		Direction = Vector3.new(0, 0.12, 1),
		ZIndex = 1,
	})
	local cracks: { Frame } = {}
	for index = 1, lineCount do
		local line = Instance.new("Frame")
		line.Name = `Crack{index}`
		line.BackgroundColor3 = ink
		line.BorderSizePixel = 0
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		local angle = (index - 1) * (360 / lineCount) + random:NextNumber() * 20
		local radius = 30 + random:NextNumber() * 80
		line.Position =
			UDim2.new(0.5, math.cos(math.rad(angle)) * radius, 0.5, math.sin(math.rad(angle)) * radius * 1.1)
		line.Size = UDim2.fromOffset(6, 38 + random:NextNumber() * 40)
		line.Rotation = angle + 90 + (random:NextNumber() - 0.5) * 40
		line.ZIndex = 2
		line.Visible = false
		Kit.Corner(line, 3)
		Kit.Stroke(line, white, 2)
		line.Parent = eggBox
		table.insert(cracks, line)
	end

	local shards: { Shard } = {}
	for index = 1, shardCap do
		local frame = box(stage, `Shard{index}`, 5)
		local width = 22 + random:NextNumber() * 28
		frame.Size = UDim2.fromOffset(width, width * 0.7)
		frame.BackgroundTransparency = 0
		Kit.Corner(frame, 4)
		table.insert(shards, {
			Frame = frame,
			Angle = (index - 1) * (360 / shardCap) + random:NextNumber() * 14 - 90,
			Speed = 260 + random:NextNumber() * 420,
			Spin = (random:NextNumber() - 0.5) * 900,
		})
	end

	local petHolder = box(stage, "PetStage", 6)
	petHolder.Size = UDim2.fromOffset(petSize, petSize)
	petHolder.Position = UDim2.fromScale(0.5, centerY)
	local petScale = Instance.new("UIScale")
	petScale.Parent = petHolder
	local petView = Viewport.new({
		Parent = petHolder,
		Name = "PetModel",
		Direction = Vector3.new(0.35, 0.3, -1),
		ZIndex = 1,
	})

	local pieces: { Piece } = {}
	for index = 1, confettiCap do
		local frame = box(stage, `Confetti{index}`, 7)
		frame.Size = UDim2.fromOffset(10, 16)
		frame.BackgroundTransparency = 0
		table.insert(pieces, {
			Frame = frame,
			Angle = (index - 1) * (360 / confettiCap) + random:NextNumber() * 9 - 90,
			Speed = 300 + random:NextNumber() * 650,
			Spin = (random:NextNumber() - 0.5) * 900,
			Color = random:NextInteger(1, #rainbowColors),
		})
	end

	local title = Kit.Label({
		Parent = stage,
		Name = "Title",
		Align = Enum.TextXAlignment.Center,
		Text = "NEW PET!",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.13),
		Size = UDim2.fromOffset(640, 70),
		TextSize = 60,
		Title = true,
		Scaled = true,
	})
	title.ZIndex = 8
	title.Visible = false
	local titleScale = Instance.new("UIScale")
	titleScale.Parent = title
	local petName = Kit.Label({
		Parent = stage,
		Name = "PetName",
		Align = Enum.TextXAlignment.Center,
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, centerY, 215),
		Size = UDim2.fromOffset(640, 60),
		TextSize = 52,
		Title = true,
		Scaled = true,
	})
	petName.ZIndex = 8
	petName.Visible = false
	local nameScale = Instance.new("UIScale")
	nameScale.Parent = petName
	local chipHolder = Kit.Chip({
		Parent = stage,
		Name = "Rarity",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, centerY, 268),
		Size = UDim2.fromOffset(190, 36),
		TextSize = 24,
	})
	local chip = chipHolder.Parent :: Frame
	chip.ZIndex = 8
	chip.Visible = false
	local effect = Kit.Label({
		Parent = stage,
		Name = "Effect",
		Align = Enum.TextXAlignment.Center,
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, centerY, 316),
		Size = UDim2.fromOffset(560, 40),
		TextSize = 34,
		Title = true,
		Scaled = true,
	})
	effect.ZIndex = 8
	effect.Visible = false
	local status = Kit.Label({
		Parent = stage,
		Name = "Status",
		Align = Enum.TextXAlignment.Center,
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, centerY, 352),
		Size = UDim2.fromOffset(640, 26),
		TextSize = 20,
		Scaled = true,
	})
	status.ZIndex = 8
	status.Visible = false
	local hint = Kit.Label({
		Parent = stage,
		Name = "Hint",
		Align = Enum.TextXAlignment.Center,
		Text = "Tap to continue",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -28),
		Size = UDim2.fromOffset(360, 36),
		TextSize = 28,
		Title = true,
		Scaled = true,
	})
	hint.ZIndex = 8
	hint.Visible = false

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BackgroundColor3 = white
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 20
	flash.Parent = root

	local tapCatcher = Instance.new("TextButton")
	tapCatcher.Name = "Tap"
	tapCatcher.Text = ""
	tapCatcher.AutoButtonColor = false
	tapCatcher.BackgroundTransparency = 1
	tapCatcher.BorderSizePixel = 0
	tapCatcher.Size = UDim2.fromScale(1, 1)
	tapCatcher.ZIndex = 25
	tapCatcher.Parent = root

	local plan: HatchPlan.Plan? = nil
	local events: { HatchPlan.Event } = {}
	local nextEvent = 1
	local elapsed = 0
	local isPlaying = false
	local currentEgg: Eggs.Egg? = nil
	local currentCharm: CharmConfig.Charm? = nil
	local rarityColor = white
	local isActivePet = false
	local queue: { { Egg: string, Charm: string, Active: boolean } } = {}

	local function sound(): any
		return context.Controllers.SoundController
	end

	local function fire(event: HatchPlan.Event)
		local current = plan
		local charm = currentCharm
		if not current or not charm then
			return
		end
		local sounds = sound()
		local kind = event.Kind
		if kind == "Land" then
			if sounds then
				sounds:PlaySwitch("MxBlack", "Press", 0.7, 1, nil, "Other")
			end
		elseif kind == "Swell" then
			if sounds then
				sounds:PlaySwell(
					HatchPlan.RevealRarity(charm.Rarity, current.Name),
					current.BurstAt - event.At,
					"Other"
				)
			end
		elseif kind == "Crack" then
			local item = current.Beats[event.Index]
			if sounds then
				sounds:PlaySwitch("MxBlue", "Press", item.Pitch, item.Volume, nil, "Other")
			end
		elseif kind == "CrackRelease" then
			local item = current.Beats[event.Index]
			if sounds then
				sounds:PlaySwitch("MxBlue", "Release", item.Pitch, item.Volume * 0.8, nil, "Other")
			end
		elseif kind == "Burst" then
			if sounds then
				sounds:PlaySwitch("MxBlue", "Release", 1.4, 1, nil, "Other")
				if current.Name == "Basic" then
					playUi("Confirm")
				else
					sounds:PlayReveal(HatchPlan.RevealRarity(charm.Rarity, current.Name), "Other")
				end
			end
			context.Toast(
				if isActivePet
					then `New pet: {charm.Name}! Now active!`
					else `New pet: {charm.Name}! Stored (only your best {CharmConfig.ActiveLimit} pets are active)`,
				"Good"
			)
		elseif kind == "Name" then
			if sounds and current.Name ~= "Basic" then
				playUi("Confirm")
			end
		end
	end

	local function render(time: number)
		local current = plan
		local egg = currentEgg
		if not current or not egg then
			return
		end
		local burstAt = current.BurstAt
		local isLow = current.IsLow
		backdrop.BackgroundTransparency = 1 - 0.7 * clamp01(time / 0.25)

		local shake = 0
		if not isLow and current.Shake > 0 then
			for index, item in current.Beats do
				if time >= item.Start and time <= item.End then
					shake = current.Shake * index / #current.Beats
				end
			end
			if time >= burstAt then
				shake = current.Shake * 2 * math.exp(-(time - burstAt) * 6)
			end
		end
		stage.Position = UDim2.fromOffset(math.sin(time * 57) * shake, math.cos(time * 43) * shake)

		local tilt, squash, drop = 0, 1, 0
		if time < current.Land - dropBounce then
			local alpha = clamp01(time / (current.Land - dropBounce))
			drop = -560 * (1 - alpha * alpha)
		elseif time < current.Land then
			local alpha = (time - (current.Land - dropBounce)) / dropBounce
			drop = -38 * math.sin(alpha * math.pi)
			squash = 1 - 0.06 * math.sin(alpha * math.pi)
		end
		local shown = 0
		for _, item in current.Beats do
			if time >= item.Start then
				local alpha = clamp01((time - item.Start) / (item.End - item.Start))
				tilt = math.sin(alpha * math.pi * 3) * item.Tilt * (1 - 0.15 * alpha)
				squash = 1 + 0.07 * math.sin(alpha * math.pi)
				if time >= item.Start + 0.08 then
					shown = math.max(shown, item.Cracks)
				end
			end
		end
		eggHolder.Visible = time < burstAt + 0.06
		eggHolder.Position = UDim2.new(0.5, 0, centerY, drop)
		eggScale.Scale = current.EggScale * squash
		eggBox.Rotation = tilt
		Viewport.Pose(eggView, tilt * 0.6)
		for index, line in cracks do
			line.Visible = index <= shown
		end

		local after = time - burstAt
		local flashAlpha = 0
		if after >= -0.12 and after < 0.45 then
			flashAlpha = if after < 0 then 1 + after / 0.12 else 1 - after / 0.45
		end
		flash.BackgroundTransparency = 1 - 0.85 * clamp01(flashAlpha)

		local isRevealed = after >= 0
		rays.Visible = isRevealed
		petHolder.Visible = isRevealed
		title.Visible = isRevealed
		if isRevealed then
			local appear = clamp01(after / 0.5)
			petScale.Scale = math.max(0.05, backOut(appear))
			local bob = if isLow then 0 else math.sin(after * 3) * 0.05
			Viewport.Pose(
				petView,
				if isLow then 20 else (after * current.Spin) % 360,
				0,
				0,
				bob * petView.Radius
			)
			rays.Rotation = if isLow then 0 else after * 22
			tintBurst(
				rays,
				if current.Rainbow
					then Color3.fromHSV((after * 0.5) % 1, 0.55, 1)
					else rarityColor:Lerp(white, 0.2)
			)
			rays.Size = UDim2.fromOffset(current.RayDiameter, current.RayDiameter)
			titleScale.Scale = 1 + 0.5 * (1 - clamp01(after / 0.3)) ^ 2
		end
		petName.Visible = time >= current.NameAt
		nameScale.Scale = 1 + 0.6 * (1 - clamp01((time - current.NameAt) / 0.25)) ^ 2
		chip.Visible = time >= current.ChipAt
		effect.Visible = time >= current.ChipAt
		status.Visible = time >= current.ChipAt
		hint.Visible = time >= current.ReadyAt
		hint.TextTransparency = 0.15 + 0.3 * (0.5 + 0.5 * math.sin(time * 6))

		for index, shard in shards do
			local frame = shard.Frame
			if isRevealed and index <= current.Shards and after < shardLife then
				local angle = math.rad(shard.Angle)
				frame.Visible = true
				frame.BackgroundColor3 = if index % 2 == 0 then egg.Color else egg.SpotColor
				frame.Position = UDim2.new(
					0.5,
					math.cos(angle) * shard.Speed * after,
					centerY,
					math.sin(angle) * shard.Speed * after + 0.5 * gravity * after * after
				)
				frame.Rotation = shard.Spin * after
				frame.BackgroundTransparency = clamp01((after - 0.8) / 0.5)
			else
				frame.Visible = false
			end
		end
		for index, piece in pieces do
			local frame = piece.Frame
			if isRevealed and index <= current.Confetti and after < confettiLife then
				local angle = math.rad(piece.Angle)
				frame.Visible = true
				frame.BackgroundColor3 = if current.Rainbow
					then rainbowColors[piece.Color]
					else rarityColor:Lerp(rainbowColors[piece.Color], 0.35)
				frame.Position = UDim2.new(
					0.5,
					math.cos(angle) * piece.Speed * after * 0.8,
					centerY,
					math.sin(angle) * piece.Speed * after + 0.5 * 1100 * after * after
				)
				frame.Rotation = piece.Spin * after
				frame.BackgroundTransparency = clamp01((after - 1.7) / 0.5)
			else
				frame.Visible = false
			end
		end
		for index, star in stars do
			local frame = star.Frame
			if isRevealed and index <= current.Stars then
				local angle = math.rad(star.Angle + after * 12)
				local pulse = 0.6 + 0.4 * math.sin(after * 4 + star.Phase)
				frame.Visible = true
				frame.Position = UDim2.new(
					0.5,
					math.cos(angle) * star.Radius * 1.3,
					centerY,
					math.sin(angle) * star.Radius * 0.8
				)
				frame.Rotation = after * 40
				frame.Size =
					UDim2.fromOffset(26 * pulse * clamp01(after * 3), 26 * pulse * clamp01(after * 3))
			else
				frame.Visible = false
			end
		end
	end

	local function advance(target: number, onlyReveal: boolean)
		while nextEvent <= #events and events[nextEvent].At <= target do
			local event = events[nextEvent]
			nextEvent += 1
			local isRevealEvent = event.Kind == "Burst" or event.Kind == "Name" or event.Kind == "Chip"
			if not onlyReveal or isRevealEvent then
				fire(event)
			end
		end
		elapsed = target
		render(target)
	end

	local clearModels: () -> ()
	local start: (eggId: string, charmId: string, isActive: boolean) -> ()

	local function finish()
		isPlaying = false
		clearModels()
		flash.BackgroundTransparency = 1
		local following = table.remove(queue, 1)
		if following then
			start(following.Egg, following.Charm, following.Active)
		else
			context.Close("Hatch")
		end
	end

	clearModels = function()
		Viewport.Clear(eggView)
		Viewport.Clear(petView)
	end

	local function step(dt: number)
		local current = plan
		if not isPlaying or not current then
			return
		end
		advance(elapsed + dt, false)
		if elapsed >= current.AutoAt then
			finish()
		end
	end

	local function tap()
		local current = plan
		if not isPlaying or not current or elapsed < minTapTime then
			return
		end
		if elapsed < current.BurstAt then
			advance(current.BurstAt, true)
		elseif elapsed < current.ReadyAt then
			advance(current.ReadyAt, true)
			while nextEvent <= #events and events[nextEvent].At <= current.ReadyAt do
				nextEvent += 1
			end
		else
			finish()
		end
	end

	start = function(eggId: string, charmId: string, isActive: boolean)
		local egg = Eggs.ById[eggId]
		local charm = CharmConfig.ById[charmId]
		if not egg or not charm then
			return
		end
		if isPlaying then
			if #queue < queueLimit then
				table.insert(queue, { Egg = eggId, Charm = charmId, Active = isActive })
			end
			return
		end
		local dataController = context.Controllers.DataController
		local isLow = dataController ~= nil and dataController:Get({ "Settings", "LowGraphics" }) == true
		local minRank = 5
		if dataController then
			local stored = dataController:Get({ "Settings", "EffectsMinRarity" })
			if type(stored) == "number" and stored == stored then
				minRank = math.clamp(math.floor(stored), 1, 8)
			end
		end
		local rarity = CharmConfig.RarityByName[charm.Rarity]
		local built = HatchPlan.For(charm.Rarity, minRank, isLow)
		plan = built
		events = HatchPlan.Events(built)
		nextEvent = 1
		elapsed = 0
		currentEgg = egg
		currentCharm = charm
		isActivePet = isActive
		rarityColor = rarity.Color
		Viewport.Set(eggView, EggModel.Model(egg))
		Viewport.Set(petView, (PetModels.Build(charm)))
		local kind = CharmConfig.Kinds[charm.Kind]
		petName.Text = charm.Name
		petName.TextColor3 = rarity.Color:Lerp(white, 0.35)
		chipHolder.Text = rarity.Name
		Kit.Paint(chip, rarity.Color)
		effect.Text = Charms.Describe(charm.Id)
		effect.TextColor3 = kind.Color
		status.Text = if isActive
			then "Now active!"
			else `Stored (only your best {CharmConfig.ActiveLimit} pets are active)`
		status.TextColor3 = if isActive then theme.Green else gold
		title.Text = if rarity.Order >= 5
			then `{string.upper(rarity.Name)} PET!!!`
			else if rarity.Order >= 3 then `{string.upper(rarity.Name)} PET!` else "NEW PET!"
		title.TextColor3 = rarity.Color:Lerp(white, 0.4)
		isPlaying = true
		render(0)
		context.Open("Hatch")
	end

	local function reveal(charmId: string): boolean
		local charm = CharmConfig.ById[charmId]
		if not charm then
			return false
		end
		local egg = Eggs.Catalog[1]
		for _, candidate in Eggs.Catalog do
			if candidate.Drops[charm.Rarity] then
				egg = candidate
				break
			end
		end
		local owned: { [string]: number } = {}
		local dataController = context.Controllers.DataController
		local stored = if dataController then dataController:Get({ "Charms" }) else nil
		if type(stored) == "table" then
			for id, count in stored do
				if type(id) == "string" and type(count) == "number" then
					owned[id] = count
				end
			end
		end
		owned[charm.Id] = math.max(owned[charm.Id] or 0, 1)
		start(egg.Id, charm.Id, Charms.IsActive(owned, charm.Id))
		return true
	end

	trove:Add(Packets.AdminReward.OnClientEvent:Connect(function(kind: string, id: string, _count: number)
		if kind == "Pet" then
			reveal(id)
		end
	end))

	local charmController = context.Controllers.CharmController
	if charmController then
		trove:Add(charmController.Hatched:Connect(start))
	end

	trove:Connect(tapCatcher.Activated, tap)
	trove:Connect(RunService.Heartbeat, function(dt: number)
		if gui.Enabled then
			step(dt)
		end
	end)
	trove:Add(function()
		clearModels()
	end)

	local screen: any = {
		Modal = false,
		StartsOpen = false,
		Open = function(_self: Types.Screen)
			gui.Enabled = true
		end,
		Close = function(_self: Types.Screen)
			gui.Enabled = false
			isPlaying = false
			table.clear(queue)
			clearModels()
		end,
		Destroy = function(_self: Types.Screen)
			trove:Destroy()
		end,
		Play = function(_self: any, eggId: string, charmId: string, isActive: boolean?)
			start(eggId, charmId, isActive ~= false)
		end,
		Reveal = function(_self: any, charmId: string): boolean
			return reveal(charmId)
		end,
		Seek = function(_self: any, time: number)
			advance(time, false)
		end,
		Step = function(_self: any, dt: number)
			step(dt)
		end,
		Tap = function(_self: any)
			tap()
		end,
		Phase = function(_self: any): string
			local current = plan
			if not isPlaying or not current then
				return "Idle"
			end
			return HatchPlan.PhaseAt(current, elapsed)
		end,
		TierName = function(_self: any): string
			local current = plan
			return if current then current.Name else ""
		end,
		Elapsed = function(_self: any): number
			return elapsed
		end,
		IsPlaying = function(_self: any): boolean
			return isPlaying
		end,
		QueuedCount = function(_self: any): number
			return #queue
		end,
	}
	return screen :: Types.Screen
end

return HatchScreen

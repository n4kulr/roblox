--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CharmConfig = require(ReplicatedStorage.Config.Charms)
local Eggs = require(ReplicatedStorage.Config.Eggs)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Charms = require(ReplicatedStorage.Rules.Charms)
local AssetOverride = require(ReplicatedStorage.Utils.AssetOverride)
local EggModel = require(ReplicatedStorage.Utils.EggModel)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local PetModels = require(ReplicatedStorage.Utils.PetModels)
local HatchPlan = require(script.Parent.Parent.HatchPlan)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)
local Viewport = require(script.Parent.Parent.Viewport)

type Shard = { Frame: Frame, Angle: number, Speed: number, Spin: number }
type Piece = { Frame: Frame, Angle: number, Speed: number, Spin: number, Color: number }
type Star = { Frame: Frame, Angle: number, Radius: number, Phase: number }
type Queued = { Egg: string, Charm: string, Active: boolean }

local theme = Kit.Theme
local centerY = 0.44
local shardCap = 24
local sparkCap = 14
local confettiCap = 36
local starCap = 14
local lineCount = HatchPlan.CrackLines
local queueLimit = 5
local gravity = 1500
local shardLife = 1.1
local sparkLife = 0.7
local confettiLife = 2.2
local maxStep = 1 / 20
local white = theme.White
local ink = theme.Ink
local gold = theme.Gold
local goldGradient = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 244, 170)),
	ColorSequenceKeypoint.new(0.5, theme.Amber),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 244, 170)),
})
local rainbowGradient = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 92, 110)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 70)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 235, 110)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(70, 200, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 92, 110)),
})
local rainbowColors: { Color3 } = Kit.Rainbow

local HatchScreen = {}

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

local function backOut(alpha: number, overshoot: number): number
	local c3 = overshoot + 1
	local t = clamp01(alpha) - 1
	return 1 + c3 * t ^ 3 + overshoot * t ^ 2
end

local function outQuad(alpha: number): number
	local t = clamp01(alpha)
	return 1 - (1 - t) * (1 - t)
end

local function inQuad(alpha: number): number
	local t = clamp01(alpha)
	return t * t
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

local function squareHolder(parent: Instance, name: string, z: number): Frame
	local holder = box(parent, name, z)
	holder.Position = UDim2.fromScale(0.5, centerY)
	holder.Size = UDim2.fromScale(0.9, 0.5)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.AspectType = Enum.AspectType.FitWithinMaxSize
	ratio.DominantAxis = Enum.DominantAxis.Width
	ratio.Parent = holder
	return holder
end

local function textBlock(
	parent: Instance,
	name: string,
	y: number,
	height: number,
	textSize: number,
	stroke: number
): (TextLabel, UIScale)
	local label = Kit.Label({
		Parent = parent,
		Name = name,
		Align = Enum.TextXAlignment.Center,
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, y),
		Size = UDim2.fromScale(0.9, height),
		TextSize = textSize,
		Title = true,
		Scaled = true,
		StrokeSize = stroke,
	})
	label.ZIndex = Kit.ZIndex.Hover
	label.Visible = false
	local scale = Instance.new("UIScale")
	scale.Parent = label
	return label, scale
end

local function vignetteEdge(
	parent: Instance,
	name: string,
	position: UDim2,
	size: UDim2,
	rotation: number
): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = ink
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Position = position
	frame.Size = size
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = frame
	frame.Parent = parent
	return frame
end

function HatchScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local playUi = Kit.UiSound(context.Controllers)
	local random = Random.new(7)

	local gui, root = Kit.ScreenGui("ThockHatch", Kit.Layer.Cinematic, context.PlayerGui, trove)
	gui.Enabled = false

	local vignette: { Frame } = {
		vignetteEdge(root, "VignetteTop", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.32), 90),
		vignetteEdge(root, "VignetteBottom", UDim2.fromScale(0, 0.68), UDim2.fromScale(1, 0.32), 270),
		vignetteEdge(root, "VignetteLeft", UDim2.fromScale(0, 0), UDim2.fromScale(0.26, 1), 0),
		vignetteEdge(root, "VignetteRight", UDim2.fromScale(0.74, 0), UDim2.fromScale(0.26, 1), 180),
	}

	local shaker = Instance.new("Frame")
	shaker.Name = "Shaker"
	shaker.BackgroundTransparency = 1
	shaker.BorderSizePixel = 0
	shaker.Size = UDim2.fromScale(1, 1)
	shaker.ZIndex = Kit.ZIndex.Under
	shaker.Parent = root

	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.BackgroundTransparency = 1
	stage.BorderSizePixel = 0
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.5)
	stage.Size = UDim2.fromScale(1, 1)
	stage.Parent = shaker
	local stageScale = Instance.new("UIScale")
	stageScale.Parent = stage

	local glow = box(stage, "Glow", 2)
	glow.Position = UDim2.fromScale(0.5, centerY)
	glow.Size = UDim2.fromOffset(620, 620)
	local glowLayers: { Frame } = {}
	for index, fraction in { 1, 0.7, 0.42 } do
		local layer = Instance.new("Frame")
		layer.Name = `Layer{index}`
		layer.AnchorPoint = Vector2.new(0.5, 0.5)
		layer.Position = UDim2.fromScale(0.5, 0.5)
		layer.Size = UDim2.fromScale(fraction, fraction)
		layer.BackgroundTransparency = 0.82 - index * 0.04
		layer.BorderSizePixel = 0
		Kit.Corner(layer, 400)
		layer.Parent = glow
		table.insert(glowLayers, layer)
	end

	local rays = Kit.Burst({
		Parent = stage,
		Diameter = 1100,
		Position = UDim2.fromScale(0.5, centerY),
		Color = white,
	})
	rays.Name = "Rays"
	rays.ZIndex = Kit.ZIndex.Fill
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

	local eggHolder = squareHolder(stage, "EggStage", 4)
	local eggBox = Instance.new("Frame")
	eggBox.Name = "Tilt"
	eggBox.BackgroundTransparency = 1
	eggBox.BorderSizePixel = 0
	eggBox.AnchorPoint = Vector2.new(0.5, 0.92)
	eggBox.Position = UDim2.fromScale(0.5, 0.92)
	eggBox.Size = UDim2.fromScale(0, 0)
	eggBox.Parent = eggHolder
	local eggView = Viewport.new({
		Parent = eggBox,
		Name = "EggModel",
		Direction = Vector3.new(0, 0.12, 1),
		ZIndex = Kit.ZIndex.Base,
	})
	local cracks: { Frame } = {}
	for index = 1, lineCount do
		local line = Instance.new("Frame")
		line.Name = `Crack{index}`
		line.BackgroundColor3 = ink
		line.BorderSizePixel = 0
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		local angle = math.rad((index - 1) * (360 / lineCount) + random:NextNumber() * 20)
		local radius = 0.1 + random:NextNumber() * 0.26
		line.Position = UDim2.fromScale(0.5 + math.cos(angle) * radius, 0.5 + math.sin(angle) * radius * 1.15)
		line.Size = UDim2.fromScale(0.022, 0.1 + random:NextNumber() * 0.1)
		line.Rotation = math.deg(angle) + 90 + (random:NextNumber() - 0.5) * 40
		line.ZIndex = Kit.ZIndex.Under
		line.Visible = false
		Kit.Corner(line, 3)
		Kit.Stroke(line, white, 2)
		line.Parent = eggBox
		table.insert(cracks, line)
	end

	local shards: { Shard } = {}
	for index = 1, shardCap do
		local frame = box(stage, `Shard{index}`, 5)
		local width = 24 + random:NextNumber() * 30
		frame.Size = UDim2.fromOffset(width, width * 0.7)
		frame.BackgroundTransparency = 0
		Kit.Corner(frame, 5)
		table.insert(shards, {
			Frame = frame,
			Angle = (index - 1) * (360 / shardCap) + random:NextNumber() * 14 - 90,
			Speed = 320 + random:NextNumber() * 520,
			Spin = (random:NextNumber() - 0.5) * 1000,
		})
	end

	local petHolder = squareHolder(stage, "PetStage", 6)
	local petView = Viewport.new({
		Parent = petHolder,
		Name = "PetModel",
		Direction = Vector3.new(0.35, 0.3, -1),
		ZIndex = Kit.ZIndex.Base,
	})
	petView.Frame.AnchorPoint = Vector2.new(0.5, 0.5)
	petView.Frame.Position = UDim2.fromScale(0.5, 0.5)

	local sparks: { Shard } = {}
	for index = 1, sparkCap do
		local frame = box(stage, `Spark{index}`, 7)
		frame.Size = UDim2.fromOffset(18, 18)
		frame.BackgroundTransparency = 0
		frame.BackgroundColor3 = white
		Kit.Corner(frame, 3)
		table.insert(sparks, {
			Frame = frame,
			Angle = (index - 1) * (360 / sparkCap) + random:NextNumber() * 18,
			Speed = 260 + random:NextNumber() * 300,
			Spin = (random:NextNumber() - 0.5) * 540,
		})
	end

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

	local petName, nameScale = textBlock(stage, "PetName", 0.76, 0.12, 76, 5)
	local nameGradient = Instance.new("UIGradient")
	nameGradient.Enabled = false
	nameGradient.Parent = petName
	local rarityName, rarityScale = textBlock(stage, "RarityName", 0.845, 0.065, 44, 4)
	local chance, chanceScale = textBlock(stage, "Chance", 0.905, 0.05, 30, 3)
	chance.TextColor3 = white
	local hint, _hintScale = textBlock(stage, "Hint", 0.965, 0.04, 24, 3)
	hint.Text = "Tap to continue"

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BackgroundColor3 = white
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = Kit.ZIndex.Tooltip
	flash.Parent = root

	local tapCatcher = Instance.new("TextButton")
	tapCatcher.Name = "Tap"
	tapCatcher.Text = ""
	tapCatcher.AutoButtonColor = false
	tapCatcher.BackgroundTransparency = 1
	tapCatcher.BorderSizePixel = 0
	tapCatcher.Size = UDim2.fromScale(1, 1)
	tapCatcher.ZIndex = Kit.ZIndex.Top
	tapCatcher.Parent = root

	local plan: HatchPlan.Plan? = nil
	local events: { HatchPlan.Event } = {}
	local nextEvent = 1
	local elapsed = 0
	local exitElapsed: number? = nil
	local isPlaying = false
	local currentEgg: Eggs.Egg? = nil
	local currentCharm: CharmConfig.Charm? = nil
	local rarityColor = white
	local rarityOrder = 1
	local isActivePet = false
	local queue: { Queued } = {}
	local flightX, flightY = 0, 0

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
		if kind == "Appear" then
			if sounds then
				sounds:PlaySwitch("MxBlack", "Press", 0.7, 0.7, nil, "Other")
			end
		elseif kind == "Swell" then
			if sounds then
				sounds:PlaySwell(
					HatchPlan.RevealRarity(charm.Rarity, current.Name),
					current.BurstAt - event.At,
					"Other"
				)
			end
		elseif kind == "Swing" then
			local swing = current.Swings[event.Index]
			if sounds then
				sounds:PlaySwitch("MxBlue", "Press", swing.Pitch, swing.Volume, nil, "Other")
			end
		elseif kind == "Crack" then
			if sounds then
				sounds:PlaySwitch("MxBrown", "Release", 0.6 + 0.12 * event.Index, 0.8, nil, "Other")
			end
		elseif kind == "Burst" then
			if sounds then
				sounds:PlaySwitch("MxBlue", "Press", 0.55, 1, nil, "Other")
				sounds:PlaySwitch("MxBlue", "Release", 1.5, 1, nil, "Other")
				if current.Name ~= "Basic" then
					sounds:PlayReveal(HatchPlan.RevealRarity(charm.Rarity, current.Name), "Other")
				end
			end
			playUi("Confirm")
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
		local exiting = exitElapsed
		local exitAlpha = if exiting then inQuad(exiting / HatchPlan.ExitSeconds) else 0

		local vignetteAlpha = outQuad(time / 0.4) * (1 - exitAlpha)
		for _, edge in vignette do
			edge.BackgroundTransparency = 1 - vignetteAlpha
		end

		local shake = 0
		if not isLow and current.Shake > 0 and time >= burstAt then
			shake = current.Shake * 2 * math.exp(-(time - burstAt) * 6)
		end
		shaker.Position = UDim2.fromOffset(math.sin(time * 57) * shake, math.cos(time * 43) * shake)

		local after = time - burstAt
		local isRevealed = after >= 0

		eggHolder.Visible = time < burstAt
		if time < burstAt then
			local pop = HatchPlan.PopScale(time)
			local grow = HatchPlan.Grow(current, time)
			local squashX, squashY = HatchPlan.Squash(current, time)
			eggBox.Size = UDim2.fromScale(0.9 * pop * grow * squashX, 0.9 * pop * grow * squashY)
			local tilt = HatchPlan.Tilt(current, time)
			eggBox.Rotation = tilt
			Viewport.Pose(eggView, tilt * 0.5)
			local shown = HatchPlan.CracksShown(current, time)
			for index, line in cracks do
				line.Visible = index <= shown
			end
		end

		flash.BackgroundTransparency = 1 - HatchPlan.Flash(current, time)

		rays.Visible = isRevealed
		glow.Visible = isRevealed
		petHolder.Visible = isRevealed
		if isRevealed then
			local appear = after / HatchPlan.SpringSeconds
			local spring = math.max(0.02, backOut(appear, 2.4))
			petView.Frame.Size = UDim2.fromScale(spring, spring)
			local bob = if isLow then 0 else math.sin(after * 2.4) * 0.04
			Viewport.Pose(
				petView,
				if isLow then 20 else (20 + after * current.Spin) % 360,
				0,
				0,
				bob * petView.Radius
			)
			local pulse = if isLow then 1 else 1 + 0.05 * math.sin(after * 3)
			glow.Size = UDim2.fromOffset(620 * spring * pulse, 620 * spring * pulse)
			local tint = if current.Rainbow
				then Color3.fromHSV((after * 0.4) % 1, 0.55, 1)
				else rarityColor:Lerp(white, 0.2)
			for _, layer in glowLayers do
				layer.BackgroundColor3 = tint
			end
			rays.Rotation = if isLow then 0 else after * 20
			for _, child in rays:GetChildren() do
				if child:IsA("ImageLabel") then
					child.ImageColor3 = tint
				elseif child:IsA("Frame") then
					child.BackgroundColor3 = tint
				end
			end
			rays.Size = UDim2.fromOffset(
				current.RayDiameter * outQuad(after / 0.5),
				current.RayDiameter * outQuad(after / 0.5)
			)
		end

		petName.Visible = time >= current.NameAt
		nameScale.Scale = math.max(0.01, backOut((time - current.NameAt) / 0.3, 2.2))
		rarityName.Visible = time >= current.RarityAt
		rarityScale.Scale = math.max(0.01, backOut((time - current.RarityAt) / 0.3, 2.2))
		chance.Visible = time >= current.ChanceAt
		chanceScale.Scale = math.max(0.01, backOut((time - current.ChanceAt) / 0.3, 2))
		hint.Visible = time >= current.ReadyAt and exiting == nil
		hint.TextTransparency = 0.15 + 0.3 * (0.5 + 0.5 * math.sin(time * 6))
		if nameGradient.Enabled then
			nameGradient.Rotation = if current.Rainbow then (after * 120) % 360 else 0
			nameGradient.Offset = Vector2.new(if current.Rainbow then 0 else math.sin(after * 2) * 0.25, 0)
		end

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
					math.sin(angle) * shard.Speed * after + 0.5 * gravity * after * after - 60
				)
				frame.Rotation = shard.Spin * after
				frame.BackgroundTransparency = clamp01((after - 0.6) / 0.5)
			else
				frame.Visible = false
			end
		end
		for index, spark in sparks do
			local frame = spark.Frame
			if isRevealed and index <= current.Sparks and after < sparkLife then
				local angle = math.rad(spark.Angle)
				local travel = outQuad(after / sparkLife) * spark.Speed
				frame.Visible = true
				frame.BackgroundColor3 = if index % 2 == 0 then white else rarityColor:Lerp(white, 0.5)
				frame.Position = UDim2.new(0.5, math.cos(angle) * travel, centerY, math.sin(angle) * travel)
				frame.Rotation = 45 + spark.Spin * after
				local size = 18 * (1 - clamp01(after / sparkLife))
				frame.Size = UDim2.fromOffset(size, size)
			else
				frame.Visible = false
			end
		end
		for index, confetti in pieces do
			local frame = confetti.Frame
			if isRevealed and index <= current.Confetti and after < confettiLife then
				local angle = math.rad(confetti.Angle)
				frame.Visible = true
				frame.BackgroundColor3 = rainbowColors[confetti.Color]
				frame.Position = UDim2.new(
					0.5,
					math.cos(angle) * confetti.Speed * after * 0.8,
					centerY,
					math.sin(angle) * confetti.Speed * after + 0.5 * 1100 * after * after
				)
				frame.Rotation = confetti.Spin * after
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
				local size = 26 * pulse * clamp01(after * 3)
				frame.Visible = true
				frame.Position = UDim2.new(
					0.5,
					math.cos(angle) * star.Radius * 1.3,
					centerY,
					math.sin(angle) * star.Radius * 0.8
				)
				frame.Rotation = after * 40
				frame.Size = UDim2.fromOffset(size, size)
			else
				frame.Visible = false
			end
		end

		stageScale.Scale = 1 - 0.94 * exitAlpha
		stage.Position = UDim2.new(0.5, flightX * exitAlpha, 0.5, flightY * exitAlpha)
	end

	local function advance(target: number, onlyReveal: boolean)
		while nextEvent <= #events and events[nextEvent].At <= target do
			local event = events[nextEvent]
			nextEvent += 1
			local kind = event.Kind
			local isRevealEvent = kind == "Burst" or kind == "Name" or kind == "Rarity" or kind == "Chance"
			if not onlyReveal or isRevealEvent then
				fire(event)
			end
		end
		elapsed = target
		render(target)
	end

	local clearModels: () -> ()
	local start: (eggId: string, charmId: string, isActive: boolean) -> ()

	local function petsTarget(): (number, number)
		local ok, dx, dy = pcall(function()
			local hud = context.PlayerGui:FindFirstChild("Pets", true)
			if not hud or not hud:IsA("GuiObject") then
				return 0, 0
			end
			local position, size = hud.AbsolutePosition, hud.AbsoluteSize
			local rootSize = root.AbsoluteSize
			local rootPosition = root.AbsolutePosition
			local scale = root:FindFirstChild("ViewportScale") :: UIScale?
			local factor = if scale then scale.Scale else 1
			local x = (position.X + size.X / 2 - rootPosition.X) / factor - rootSize.X / 2
			local y = (position.Y + size.Y / 2 - rootPosition.Y) / factor - rootSize.Y / 2
			return x, y
		end)
		if ok and type(dx) == "number" and type(dy) == "number" and dx == dx and dy == dy then
			return dx, dy
		end
		return 0, 0
	end

	local function complete()
		isPlaying = false
		exitElapsed = nil
		clearModels()
		flash.BackgroundTransparency = 1
		local following = table.remove(queue, 1)
		if following then
			start(following.Egg, following.Charm, following.Active)
		else
			context.Close("Hatch")
		end
	end

	local function beginExit()
		local charm = currentCharm
		if exitElapsed ~= nil or not charm then
			return
		end
		exitElapsed = 0
		flightX, flightY = petsTarget()
		context.Toast(
			if isActivePet
				then `New pet: {charm.Name}! Now active!`
				else `New pet: {charm.Name}! Stored (only your best {CharmConfig.ActiveLimit} pets are active)`,
			"Good"
		)
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
		local clamped = math.min(dt, maxStep)
		local exiting = exitElapsed
		if exiting then
			exitElapsed = exiting + clamped
			elapsed += clamped
			render(elapsed)
			if (exitElapsed :: number) >= HatchPlan.ExitSeconds then
				complete()
			end
			return
		end
		advance(elapsed + clamped, false)
		if elapsed >= current.AutoAt then
			beginExit()
		end
	end

	local function tap()
		local current = plan
		if not isPlaying or not current or elapsed < HatchPlan.MinTapSeconds then
			return
		end
		if exitElapsed ~= nil then
			complete()
		elseif elapsed < current.BurstAt then
			advance(current.BurstAt, true)
		else
			beginExit()
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
		exitElapsed = nil
		currentEgg = egg
		currentCharm = charm
		isActivePet = isActive
		rarityColor = rarity.Color
		rarityOrder = rarity.Order
		Viewport.Set(eggView, AssetOverride.Find("Eggs", egg.Id) or EggModel.Model(egg))
		Viewport.Set(petView, AssetOverride.Find("Pets", charm.Id) or (PetModels.Build(charm)))
		petName.Text = charm.Name
		rarityName.Text = rarity.Name
		rarityName.TextColor3 = rarity.Color:Lerp(white, 0.2)
		local oneIn = 0
		for _, drop in Charms.Drops(eggId) do
			if drop.CharmId == charmId and drop.Chance > 0 then
				oneIn = math.floor(1 / drop.Chance + 0.5)
			end
		end
		chance.Text = if oneIn > 0 then `1 in {NumberFormat.Commas(oneIn)}` else ""
		if rarityOrder >= 5 then
			petName.TextColor3 = white
			nameGradient.Enabled = true
			nameGradient.Color = if built.Rainbow and rarityOrder >= 6 then rainbowGradient else goldGradient
		else
			petName.TextColor3 = rarity.Color:Lerp(white, 0.35)
			nameGradient.Enabled = false
		end
		flightX, flightY = 0, 0
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
	trove:Connect(RunService.RenderStepped, function(dt: number)
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
			exitElapsed = nil
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
			if exitElapsed ~= nil then
				return "Exit"
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

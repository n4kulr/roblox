--!strict

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)
local Keycap = require(script.Parent.Keycap)
local Progress = require(script.Parent.Progress)

export type Handle = {
	Gui: any,
	Step: (self: Handle, dt: number) -> (),
	Destroy: (self: Handle) -> (),
	IsDone: (self: Handle) -> boolean,
}

local Loader = {}

local white = Color3.new(1, 1, 1)
local designCenterX = Config.DesignWidth / 2

local function create(className: string, props: { [string]: any }): any
	local item: any = Instance.new(className :: any)
	for key, value in props do
		item[key] = value
	end
	return item
end

local function rarityColor(fraction: number): Color3
	local count = #Config.Rarities
	local scaled = math.clamp(fraction, 0, 1) * (count - 1)
	local low = math.floor(scaled)
	local high = math.min(low + 1, count - 1)
	return Config.Rarities[low + 1]:Lerp(Config.Rarities[high + 1], scaled - low)
end

local function label(parent: any, name: string, y: number, height: number, size: number, color: Color3): any
	local item = create("TextLabel", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(designCenterX, y),
		Size = UDim2.fromOffset(Config.DesignWidth - 40, height),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.FredokaOne,
		TextColor3 = color,
		TextSize = size,
		TextWrapped = true,
		Text = "",
		Parent = parent,
	})
	create("UIStroke", { Color = Config.Outline, Thickness = 2, Parent = item })
	return item
end

function Loader.Start(player: Player): Handle
	ReplicatedFirst:RemoveDefaultLoadingScreen()
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = create("ScreenGui", {
		Name = Config.GuiName,
		DisplayOrder = Config.DisplayOrder,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	local background = create("Frame", {
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = white,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = gui,
	})
	create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Config.BackgroundTop, Config.BackgroundBottom),
		Parent = background,
	})
	local pattern = create("ImageLabel", {
		Name = "Pattern",
		Position = UDim2.fromOffset(-128, -128),
		Size = UDim2.new(1, 256, 1, 256),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = Config.PatternId,
		ImageTransparency = 0.9,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(128, 128),
		Parent = background,
	})

	local content = create("Frame", {
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(Config.DesignWidth, Config.DesignHeight),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = gui,
	})
	local contentScale = create("UIScale", { Scale = 1, Parent = content })

	local caps: { Keycap.Cap } = {}
	local letterCount = #Config.Letters
	for index, letter in Config.Letters do
		local cap = Keycap.new({
			Parent = content,
			Size = Vector2.new(74, 74),
			Color = Config.Rarities[index],
			Letter = letter,
			Position = UDim2.fromOffset(designCenterX + (index - (letterCount + 1) / 2) * 84, 100),
			Stroke = 3,
			Travel = Config.PressTravel,
		})
		table.insert(caps, cap)
	end

	local under = create("Frame", {
		Name = "Under",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = content,
	})
	local barCaps: { Keycap.Cap } = {}
	local barCount = Config.ProgressKeys
	for index = 1, barCount do
		local cap = Keycap.new({
			Parent = under,
			Size = Vector2.new(30, 30),
			Color = Config.UnlitKey,
			Letter = "",
			Position = UDim2.fromOffset(designCenterX + (index - (barCount + 1) / 2) * 36, 215),
			Stroke = 2,
			Travel = 3,
		})
		cap.Root.Name = `Bar{index}`
		table.insert(barCaps, cap)
	end
	local percent = label(under, "Percent", 248, 34, 26, white)
	percent.Text = "0%"
	local tip = label(under, "Tip", 296, 48, 19, Color3.fromRGB(222, 212, 250))
	tip.Text = Config.Tips[1]

	local skipScale = create("UIScale", { Scale = 1 })
	local skip = create("TextButton", {
		Name = "Skip",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.fromOffset(92, 36),
		BackgroundColor3 = Config.Outline,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Font = Enum.Font.FredokaOne,
		Text = "SKIP",
		TextColor3 = white,
		TextSize = 18,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	skipScale.Parent = skip
	create("UICorner", { CornerRadius = UDim.new(0, 10), Parent = skip })
	create("UIStroke", { Color = white, Transparency = 0.6, Thickness = 2, Parent = skip })

	local click = create("Sound", {
		Name = "Click",
		SoundId = Config.Click.Id,
		Volume = Config.Click.Volume,
		Parent = gui,
	})

	gui.Parent = playerGui

	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ pattern, click })
		end)
	end)

	local elapsed = 0
	local displayed = 0
	local maxQueue = 0
	local exitTime = 0
	local tipTime = 0
	local tipIndex = 1
	local isSkipped = false
	local isExiting = false
	local isDone = false
	local connection: RBXScriptConnection? = nil
	local lastCycle: { number } = {}
	for index = 1, #caps do
		lastCycle[index] = -1
	end
	local lastLit = 0

	local function playClick()
		click.TimePosition = Config.Click.Start
		click:Play()
		task.delay(Config.Click.Length, function()
			click:Stop()
		end)
	end

	local function layout()
		local size = gui.AbsoluteSize
		local fit = math.min(size.X / Config.DesignWidth, size.Y / Config.DesignHeight)
		local scale = math.clamp(fit, Config.MinScale, Config.MaxScale)
		contentScale.Scale = scale
		skipScale.Scale = math.clamp(scale, 0.8, 1.2)
	end

	local function animateWave()
		for index, cap in caps do
			local localTime = elapsed - (index - 1) * Config.WaveStagger
			local depth = 0
			if localTime >= 0 then
				local cycle = math.floor(localTime / Config.WavePeriod)
				depth = Keycap.Depth(localTime - cycle * Config.WavePeriod)
				if cycle > lastCycle[index] then
					lastCycle[index] = cycle
					playClick()
				end
			end
			Keycap.SetPress(cap, depth)
		end
	end

	local function animateBar()
		local lit = Progress.LitCount(displayed, barCount)
		if lit ~= lastLit then
			for index, cap in barCaps do
				local isLit = index <= lit
				Keycap.SetColor(
					cap,
					if isLit then rarityColor((index - 1) / (barCount - 1)) else Config.UnlitKey
				)
				Keycap.SetPress(cap, if isLit then 0.5 else 0)
			end
			lastLit = lit
		end
		percent.Text = `{math.floor(displayed * 100 + 0.0001)}%`
	end

	local function animateExit()
		local fade = math.clamp(exitTime / 0.3, 0, 1)
		under.Position = UDim2.fromOffset(0, math.round(fade * 40))
		under.Visible = fade < 1
		skip.Visible = false
		for index, cap in caps do
			local start = (index - 1) * Config.ExitStagger
			local p = math.clamp((exitTime - start) / Config.ExitKeyTime, 0, 1)
			local punch = if p < 0.3 then 1 + 0.35 * (p / 0.3) else 1.35 * (1 - (p - 0.3) / 0.7)
			cap.Scale.Scale = math.max(punch, 0.05)
			local baseX = designCenterX + (index - (letterCount + 1) / 2) * 84
			cap.Root.Position = UDim2.fromOffset(baseX, 100 - p * p * 520)
			cap.Root.Visible = p < 1
		end
		local bgFade =
			math.clamp((exitTime - Config.ExitFadeStart) / (Config.ExitTime - Config.ExitFadeStart), 0, 1)
		background.BackgroundTransparency = bgFade
		pattern.ImageTransparency = 0.9 + 0.1 * bgFade
	end

	local handle: Handle
	local function finish()
		if isDone then
			return
		end
		isDone = true
		if connection then
			connection:Disconnect()
			connection = nil
		end
		gui:Destroy()
	end

	local function step(_self: Handle, dt: number)
		if isDone then
			return
		end
		elapsed += dt
		layout()
		local offset = (elapsed * 18) % 128
		pattern.Position = UDim2.fromOffset(-128 + offset, -128 + offset)

		if isExiting then
			exitTime += dt
			animateExit()
			if exitTime >= Config.ExitTime then
				finish()
			end
			return
		end

		local isLoaded = game:IsLoaded()
		local isReady = player:GetAttribute(Config.ReadyAttribute) == true
		local hasTimedOut = elapsed >= Config.Timeout
		local queue = ContentProvider.RequestQueueSize
		maxQueue = math.max(maxQueue, queue)
		local target = Progress.Target({
			Loaded = isLoaded,
			Ready = isReady,
			TimedOut = hasTimedOut,
			Queue = queue,
			MaxQueue = maxQueue,
		})
		displayed = Progress.Advance(displayed, target, elapsed, dt)
		skip.Visible = elapsed >= Config.SkipDelay

		animateWave()
		animateBar()

		tipTime += dt
		if tipTime >= Config.TipSeconds then
			tipTime = 0
			tipIndex = tipIndex % #Config.Tips + 1
			tip.Text = Config.Tips[tipIndex]
		end
		tip.TextTransparency = 1 - math.clamp(tipTime / 0.25, 0, 1)

		local isVisuallyDone = isSkipped or ((isReady or hasTimedOut) and displayed >= 0.999)
		if isLoaded and isVisuallyDone then
			displayed = 1
			animateBar()
			isExiting = true
			exitTime = 0
		end
	end

	handle = {
		Gui = gui,
		Step = step,
		Destroy = function(_self: Handle)
			finish()
		end,
		IsDone = function(_self: Handle): boolean
			return isDone
		end,
	}

	skip.Activated:Connect(function()
		isSkipped = true
	end)
	connection = RunService.Heartbeat:Connect(function(dt: number)
		handle:Step(dt)
	end)
	layout()
	animateWave()
	animateBar()
	return handle
end

return Loader

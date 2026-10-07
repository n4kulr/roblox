--!strict

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)
local Keycap = require(script.Parent.Keycap)
local Progress = require(script.Parent.Progress)

export type Handle = {
	Gui: ScreenGui,
	Step: (self: Handle, dt: number) -> (),
	Destroy: (self: Handle) -> (),
	IsDone: (self: Handle) -> boolean,
}

local Loader = {}

local white = Color3.new(1, 1, 1)

local function create(className: string, props: { [string]: any }): any
	local item: any = Instance.new(className :: any)
	for key, value in props do
		item[key] = value
	end
	return item
end

local function litColor(fraction: number): Color3
	local colors = Config.Lit
	local count = #colors
	local scaled = math.clamp(fraction, 0, 1) * (count - 1)
	local low = math.floor(scaled)
	local high = math.min(low + 1, count - 1)
	return colors[low + 1]:Lerp(colors[high + 1], scaled - low)
end

local function unitsOf(letter: string): number
	local wide = Config.Wide[letter]
	return if type(wide) == "number" then wide else 1
end

local function rowUnits(row: { string }): number
	local total = 0
	for _, letter in row do
		total += unitsOf(letter)
	end
	return total
end

function Loader.Start(player: Player): Handle
	ReplicatedFirst:RemoveDefaultLoadingScreen()
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = create("ScreenGui", {
		Name = Config.GuiName,
		DisplayOrder = Config.DisplayOrder,
		IgnoreGuiInset = true,
		ClipToDeviceSafeArea = false,
		ScreenInsets = Enum.ScreenInsets.None,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	local background = create("Frame", {
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Config.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = gui,
	})

	local board = create("Frame", {
		Name = "Board",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Config.Board,
		BorderSizePixel = 0,
		Parent = background,
	})
	create("UIPadding", {
		PaddingTop = UDim.new(Config.Pad, 0),
		PaddingBottom = UDim.new(Config.Pad, 0),
		PaddingLeft = UDim.new(Config.Pad * 0.5, 0),
		PaddingRight = UDim.new(Config.Pad * 0.5, 0),
		Parent = board,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(Config.Gap, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = board,
	})

	local caps: { Keycap.Cap } = {}
	local index = 0
	for rowIndex, row in Config.Rows do
		local rowFrame = create("Frame", {
			Name = `Row{rowIndex}`,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1 / #Config.Rows, 0),
			LayoutOrder = rowIndex,
			Parent = board,
		})
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(Config.Gap, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = rowFrame,
		})
		local total = rowUnits(row)
		local gapShare = Config.Gap * math.max(#row - 1, 0)
		local usable = math.max(1 - gapShare, 0.01)
		for order, letter in row do
			index += 1
			local width = usable * (unitsOf(letter) / total)
			local cap = Keycap.new({
				Parent = rowFrame,
				Letter = if letter == "SPACE" then "" else letter,
				Index = index,
				LayoutOrder = order,
				WidthScale = width,
			})
			table.insert(caps, cap)
		end
	end
	local keyCount = #caps

	local overlay = create("Frame", {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 20,
		Parent = background,
	})

	local title = create("TextLabel", {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.06),
		Size = UDim2.fromScale(0.9, 0.12),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.FredokaOne,
		Text = Config.Title,
		TextColor3 = Config.TitleColor,
		TextScaled = true,
		ZIndex = 21,
		Parent = overlay,
	})
	create("UIStroke", { Color = Config.Outline, Thickness = 4, Parent = title })

	local subtitle = create("TextLabel", {
		Name = "Subtitle",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.165),
		Size = UDim2.fromScale(0.7, 0.04),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.FredokaOne,
		Text = Config.Subtitle,
		TextColor3 = Config.StatusColor,
		TextScaled = true,
		TextTransparency = 0.15,
		ZIndex = 21,
		Parent = overlay,
	})
	create("UIStroke", { Color = Config.Outline, Thickness = 2, Parent = subtitle })

	local status = create("TextLabel", {
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.9),
		Size = UDim2.fromScale(0.8, 0.05),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.FredokaOne,
		Text = "LOADING 0%",
		TextColor3 = Config.StatusColor,
		TextScaled = true,
		ZIndex = 21,
		Parent = overlay,
	})
	create("UIStroke", { Color = Config.Outline, Thickness = 2.5, Parent = status })

	local tip = create("TextLabel", {
		Name = "Tip",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.96),
		Size = UDim2.fromScale(0.86, 0.045),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.FredokaOne,
		Text = Config.Tips[1],
		TextColor3 = Config.TipColor,
		TextScaled = true,
		ZIndex = 21,
		Parent = overlay,
	})
	create("UIStroke", { Color = Config.Outline, Thickness = 2, Parent = tip })

	local skip = create("TextButton", {
		Name = "Skip",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -14),
		Size = UDim2.fromOffset(72, 28),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.FredokaOne,
		Text = "SKIP",
		TextColor3 = white,
		TextSize = 18,
		TextTransparency = 0.25,
		Visible = false,
		ZIndex = 30,
		Parent = overlay,
	})
	create("UIStroke", { Color = Config.Outline, Thickness = 2, Transparency = 0.35, Parent = skip })

	local click = create("Sound", {
		Name = "Click",
		SoundId = Config.Click.Id,
		Volume = Config.Click.Volume,
		Parent = gui,
	})

	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ click })
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
	local lastLit = 0
	local connection: RBXScriptConnection? = nil

	local function playClick()
		click.TimePosition = Config.Click.Start
		click:Play()
		task.delay(Config.Click.Length, function()
			click:Stop()
		end)
	end

	local function paintKeys()
		local lit = Progress.LitCount(displayed, keyCount)
		if lit == lastLit then
			status.Text = `LOADING {math.floor(displayed * 100 + 0.0001)}%`
			return
		end
		for i = lastLit + 1, lit do
			local cap = caps[i]
			if cap then
				Keycap.SetLit(cap, true, litColor((i - 1) / math.max(keyCount - 1, 1)))
				playClick()
			end
		end
		lastLit = lit
		status.Text = `LOADING {math.floor(displayed * 100 + 0.0001)}%`
	end

	local function animateExit()
		local fade = math.clamp(exitTime / Config.ExitTime, 0, 1)
		local bgFade =
			math.clamp((exitTime - Config.ExitFadeStart) / (Config.ExitTime - Config.ExitFadeStart), 0, 1)
		background.BackgroundTransparency = bgFade
		board.BackgroundTransparency = fade
		title.TextTransparency = fade
		subtitle.TextTransparency = fade
		status.TextTransparency = fade
		tip.TextTransparency = fade
		skip.Visible = false
		for i, cap in caps do
			local start = (i - 1) / keyCount * 0.35
			local alpha = math.clamp((exitTime - start) / 0.35, 0, 1)
			cap.Face.BackgroundTransparency = alpha
			cap.Label.TextTransparency = if cap.IsLit then alpha else math.max(0.35, alpha)
		end
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
		paintKeys()

		tipTime += dt
		if tipTime >= Config.TipSeconds then
			tipTime = 0
			tipIndex = tipIndex % #Config.Tips + 1
			tip.Text = Config.Tips[tipIndex]
		end
		tip.TextTransparency = 0.1 + 0.9 * (1 - math.clamp(tipTime / 0.25, 0, 1))

		local isVisuallyDone = isSkipped or ((isReady or hasTimedOut) and displayed >= 0.999)
		if isLoaded and isVisuallyDone then
			displayed = 1
			paintKeys()
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
	paintKeys()
	return handle
end

return Loader

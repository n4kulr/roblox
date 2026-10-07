--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Kit = require(script.Parent.Parent.Kit)
local PlayerState = require(script.Parent.Parent.PlayerState)
local Types = require(script.Parent.Parent.Types)
local Pages = require(script.Pages)
local Widgets = require(script.Widgets)

type TroveInstance = typeof(Trove.new())
type Page = Widgets.Page

local displayOrder = Kit.Layer.Debug

local style = Widgets.Style
local palette = Widgets.Palette
local trim = Widgets.Trim
local isError = Widgets.IsError
local round = Widgets.Round
local outline = Widgets.Outline
local newLabel = Widgets.NewLabel
local newButton = Widgets.NewButton
local newBox = Widgets.NewBox
local windowWidth = style.WindowWidth
local minWindowWidth = style.MinWindowWidth
local minWindowHeight = style.MinWindowHeight
local screenMargin = style.ScreenMargin
local gripSize = style.GripSize
local edgeThickness = style.EdgeThickness
local gripLineLength = style.GripLineLength
local gripLineThickness = style.GripLineThickness
local titleHeight = style.TitleHeight
local pad = style.Pad
local inputHeight = style.InputHeight
local tabHeight = style.TabHeight
local defaultPageHeight = style.DefaultPageHeight
local statusHeight = style.StatusHeight
local gap = style.Gap
local smallTextSize = style.SmallTextSize
local backgroundTransparency = style.BackgroundTransparency
local startLeft = style.StartLeft
local startTop = style.StartTop
local minVisible = style.MinVisible
local defaultStatus = style.DefaultStatus
local noResponseText = style.NoResponseText
local tabNames = style.TabNames

local CheatsScreen = {}

function CheatsScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local playUi = Kit.UiSound(context.Controllers)
	local panelTrove: TroveInstance? = nil
	local gui: ScreenGui? = nil
	local panel: Frame? = nil
	local content: Frame? = nil
	local rootFrame: Frame? = nil
	local statusLabel: TextLabel? = nil
	local targetBox: TextBox? = nil
	local pages: { Page } = {}
	local position: Vector2? = nil
	local windowSize: Vector2? = nil
	local resizeHandles: { GuiObject } = {}
	local isBusy = false
	local isMinimized = false

	local function isDeveloper(): boolean
		return PlayerState.IsDeveloper()
	end

	local function setStatus(text: string)
		local label = statusLabel
		if not label then
			return
		end
		label.Text = text
		label.TextColor3 = if isError(text) then palette.Bad else palette.Good
	end

	local function send(command: string, args: string)
		if isBusy then
			return
		end
		isBusy = true
		Kit.Spawn(trove, function()
			local suffix = if targetBox then trim(targetBox.Text) else ""
			local argument = args
			if suffix ~= "" then
				argument = if args == "" then suffix else `{args} {suffix}`
			end
			return Packets.AdminCommand:Fire(command, argument)
		end, function(_isOk: boolean, result: any)
			isBusy = false
			if type(result) ~= "string" or result == "" then
				playUi("Error")
				setStatus(noResponseText)
				return
			end
			playUi(if isError(result) then "Error" else "Confirm")
			setStatus(result)
		end)
	end

	local function viewScale(): number
		local root = rootFrame
		local scale = if root then root:FindFirstChild("ViewportScale") else nil
		if scale and scale:IsA("UIScale") and scale.Scale > 0 then
			return scale.Scale
		end
		return 1
	end

	local function placeAt(target: Vector2)
		local window = panel
		local root = rootFrame
		if not window or not root then
			return
		end
		local size = root.AbsoluteSize / viewScale()
		local height = window.Size.Y.Offset
		local width = window.Size.X.Offset
		local clamped = Vector2.new(
			math.clamp(target.X, minVisible - width, math.max(size.X - minVisible, 0)),
			math.clamp(target.Y, 0, math.max(size.Y - math.min(height, titleHeight + minVisible), 0))
		)
		position = clamped
		window.Position = UDim2.fromOffset(clamped.X, clamped.Y)
	end

	local function selectPage(name: string)
		for _, page in pages do
			local isActive = page.Name == name
			page.Scroll.Visible = isActive
			page.Tab.BackgroundColor3 = if isActive then palette.Selected else palette.Button
			page.Tab.TextColor3 = if isActive then palette.Text else palette.Dim
		end
	end

	local function applyLayout()
		local window = panel
		local body = content
		local current = windowSize
		if not window or not body or not current then
			return
		end
		body.Visible = not isMinimized
		for _, handle in resizeHandles do
			handle.Visible = not isMinimized
		end
		local height = if isMinimized then titleHeight else current.Y
		window.Size = UDim2.fromOffset(current.X, height)
	end

	local function sizeLimits(): (Vector2, Vector2)
		local root = rootFrame
		local screen = if root then root.AbsoluteSize / viewScale() else Vector2.zero
		local minimum = Vector2.new(minWindowWidth, minWindowHeight)
		local maximum = Vector2.new(
			math.max(screen.X - 2 * screenMargin, minimum.X),
			math.max(screen.Y - 2 * screenMargin, minimum.Y)
		)
		return minimum, maximum
	end

	local function resizeTo(target: Vector2)
		local minimum, maximum = sizeLimits()
		windowSize = Vector2.new(
			math.clamp(target.X, minimum.X, maximum.X),
			math.clamp(target.Y, minimum.Y, maximum.Y)
		)
		applyLayout()
		local current = position
		if current then
			placeAt(current)
		end
	end

	local function build()
		local own = Trove.new()
		panelTrove = own
		local screenGui, root = Kit.ScreenGui("ThockCheats", displayOrder, context.PlayerGui, own, true)
		gui = screenGui
		rootFrame = root
		screenGui.Enabled = false

		local pagesTop = pad + inputHeight + gap + tabHeight + gap
		local pagesBottom = gap + statusHeight + pad
		local contentHeight = pagesTop + defaultPageHeight + pagesBottom
		windowSize = windowSize or Vector2.new(windowWidth, titleHeight + contentHeight)
		local initial = windowSize :: Vector2
		local window = Instance.new("Frame")
		window.Name = "Window"
		window.Active = true
		window.BackgroundColor3 = palette.Background
		window.BackgroundTransparency = backgroundTransparency
		window.BorderSizePixel = 0
		window.Size = UDim2.fromOffset(initial.X, initial.Y)
		window.Parent = root
		round(window)
		outline(window)
		panel = window

		local titleBar = Instance.new("Frame")
		titleBar.Name = "TitleBar"
		titleBar.BackgroundColor3 = palette.Bar
		titleBar.BorderSizePixel = 0
		titleBar.Size = UDim2.new(1, 0, 0, titleHeight)
		titleBar.Parent = window
		round(titleBar)
		local title = newLabel(titleBar, "Title", "THOCK DEV", palette.Text)
		title.Position = UDim2.fromOffset(8, 0)
		title.Size = UDim2.new(1, -(2 * titleHeight + 8), 1, 0)

		local closeButton = newButton(titleBar, "Close", "x", palette.Bar)
		closeButton.Position = UDim2.new(1, -titleHeight, 0, 0)
		closeButton.Size = UDim2.fromOffset(titleHeight, titleHeight)
		closeButton.TextColor3 = palette.Bad
		own:Connect(closeButton.Activated, function()
			context.Close("Cheats")
		end)
		table.clear(resizeHandles)
		local minimizeButton = newButton(titleBar, "Minimize", "-", palette.Bar)
		minimizeButton.Position = UDim2.new(1, -2 * titleHeight, 0, 0)
		minimizeButton.Size = UDim2.fromOffset(titleHeight, titleHeight)
		own:Connect(minimizeButton.Activated, function()
			isMinimized = not isMinimized
			minimizeButton.Text = if isMinimized then "+" else "-"
			applyLayout()
		end)

		local body = Instance.new("Frame")
		body.Name = "Content"
		body.BackgroundTransparency = 1
		body.BorderSizePixel = 0
		body.Position = UDim2.fromOffset(0, titleHeight)
		body.Size = UDim2.new(1, 0, 1, -titleHeight)
		body.Parent = window
		content = body

		local target = newBox(body, "TargetInput", "target: blank = me | name | all", "")
		target.Position = UDim2.fromOffset(pad, pad)
		target.Size = UDim2.new(1, -2 * pad, 0, inputHeight)
		targetBox = target

		local tabStrip = Instance.new("Frame")
		tabStrip.Name = "Tabs"
		tabStrip.BackgroundTransparency = 1
		tabStrip.BorderSizePixel = 0
		tabStrip.Position = UDim2.fromOffset(pad, pad + inputHeight + gap)
		tabStrip.Size = UDim2.new(1, -2 * pad, 0, tabHeight)
		tabStrip.Parent = body
		local tabLayout = Instance.new("UIListLayout")
		tabLayout.FillDirection = Enum.FillDirection.Horizontal
		tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
		tabLayout.Padding = UDim.new(0, gap)
		tabLayout.Parent = tabStrip

		local area = Instance.new("Frame")
		area.Name = "Pages"
		area.BackgroundTransparency = 1
		area.BorderSizePixel = 0
		area.Position = UDim2.fromOffset(pad, pagesTop)
		area.Size = UDim2.new(1, -2 * pad, 1, -(pagesTop + pagesBottom))
		area.Parent = body

		local status = newLabel(body, "Status", defaultStatus, palette.Dim)
		status.TextSize = smallTextSize
		status.Position = UDim2.new(0, pad + 2, 1, -(pad + statusHeight))
		status.Size = UDim2.new(1, -2 * pad - 4 - gripSize, 0, statusHeight)
		statusLabel = status

		local built = Pages.Build({
			Trove = own,
			Tabs = tabStrip,
			Area = area,
			Select = selectPage,
			Send = send,
			SetStatus = setStatus,
			PlayUi = playUi,
		})
		pages = built.Pages

		selectPage(tabNames[1])

		local function isPress(input: InputObject): boolean
			return input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
		end

		local function isMove(input: InputObject): boolean
			return input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
		end

		local dragOrigin: Vector2? = nil
		local dragStart = Vector2.zero
		local resizeOrigin: Vector2? = nil
		local resizeAxes = Vector2.zero

		local function addHandle(name: string, at: UDim2, extent: UDim2, axes: Vector2): Frame
			local handle = Instance.new("Frame")
			handle.Name = name
			handle.Active = true
			handle.BackgroundTransparency = 1
			handle.BorderSizePixel = 0
			handle.Position = at
			handle.Size = extent
			handle.ZIndex = Kit.ZIndex.Badge
			handle.Parent = window
			table.insert(resizeHandles, handle)
			own:Connect(handle.InputBegan, function(input: InputObject)
				if isPress(input) and not isMinimized then
					resizeOrigin = windowSize
					resizeAxes = axes
					dragStart = Vector2.new(input.Position.X, input.Position.Y)
				end
			end)
			return handle
		end

		addHandle(
			"ResizeRight",
			UDim2.new(1, -edgeThickness, 0, titleHeight),
			UDim2.new(0, edgeThickness, 1, -(titleHeight + gripSize)),
			Vector2.new(1, 0)
		)
		addHandle(
			"ResizeBottom",
			UDim2.new(0, 0, 1, -edgeThickness),
			UDim2.new(1, -gripSize, 0, edgeThickness),
			Vector2.new(0, 1)
		)
		local grip = addHandle(
			"ResizeGrip",
			UDim2.new(1, -gripSize, 1, -gripSize),
			UDim2.fromOffset(gripSize, gripSize),
			Vector2.new(1, 1)
		)
		for index = 0, 2 do
			local line = Instance.new("Frame")
			line.Name = `GripLine{index + 1}`
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.BackgroundColor3 = palette.Dim
			line.BorderSizePixel = 0
			line.Rotation = -45
			line.Size = UDim2.fromOffset(gripLineLength - 3 * index, gripLineThickness)
			line.Position = UDim2.fromOffset(3 + 3 * index, 3 + 3 * index)
			line.Parent = grip
		end

		own:Connect(titleBar.InputBegan, function(input: InputObject)
			if isPress(input) then
				dragOrigin = position
				dragStart = Vector2.new(input.Position.X, input.Position.Y)
			end
		end)
		own:Connect(UserInputService.InputChanged, function(input: InputObject)
			if not isMove(input) then
				return
			end
			local delta = (Vector2.new(input.Position.X, input.Position.Y) - dragStart) / viewScale()
			local origin = dragOrigin
			if origin then
				placeAt(origin + delta)
			end
			local base = resizeOrigin
			if base then
				resizeTo(base + delta * resizeAxes)
			end
		end)
		own:Connect(UserInputService.InputEnded, function(input: InputObject)
			if isPress(input) then
				dragOrigin = nil
				resizeOrigin = nil
			end
		end)

		local size = root.AbsoluteSize / viewScale()
		placeAt(position or Vector2.new(math.min(startLeft, math.max(size.X - initial.X, 0)), startTop))
		resizeTo(initial)
	end

	local developerChanged = PlayerState.DeveloperChanged()
	if developerChanged then
		trove:Connect(developerChanged, function()
			if not isDeveloper() then
				context.Close("Cheats")
			end
		end)
	end

	return {
		Modal = false,
		StartsOpen = false,
		CanOpen = function(_self: Types.Screen): boolean
			return isDeveloper()
		end,
		Open = function(_self: Types.Screen)
			if not isDeveloper() then
				return
			end
			if not gui then
				build()
			end
			local screenGui = gui :: ScreenGui
			screenGui.Enabled = true
		end,
		Close = function(_self: Types.Screen)
			local screenGui = gui
			if screenGui then
				screenGui.Enabled = false
			end
		end,
		Destroy = function(_self: Types.Screen)
			trove:Destroy()
			local own = panelTrove
			if own then
				own:Destroy()
				panelTrove = nil
			end
			gui = nil
			panel = nil
			content = nil
		end,
	}
end

return CheatsScreen

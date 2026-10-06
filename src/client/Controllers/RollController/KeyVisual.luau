--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Keys = require(ReplicatedStorage.Config.Keys)
local WorldNames = require(ReplicatedStorage.Config.WorldNames)

local Parts = WorldNames.Parts

export type KeyVisual = {
	Key: BasePart?,
	OriginCFrame: CFrame,
	OriginSize: Vector3,
	OriginColor: Color3,
	BuildingCount: number,
	Punching: boolean,
	SquashTweens: { Tween },
	Connections: { RBXScriptConnection },
	IsLowGraphics: () -> boolean,
	IsDestroyed: () -> boolean,
}

local squashDownSeconds = 0.04
local squashRiseSeconds = 0.15
local squashWidth = 1.08
local squashHeight = 0.6
local squashDrop = 0.2
local buildBaseAmplitude = 0.05
local buildGrowAmplitude = 0.25
local goldRestoreSeconds = 0.5
local punchFov = 8
local punchOutSeconds = 0.08
local punchBackSeconds = 0.3

local KeyVisual = {}

function KeyVisual.new(isLowGraphics: () -> boolean, isDestroyed: () -> boolean): KeyVisual
	return {
		Key = nil,
		OriginCFrame = CFrame.identity,
		OriginSize = Vector3.one,
		OriginColor = Color3.new(1, 1, 1),
		BuildingCount = 0,
		Punching = false,
		SquashTweens = {},
		Connections = {},
		IsLowGraphics = isLowGraphics,
		IsDestroyed = isDestroyed,
	}
end

local function disconnect(self: KeyVisual)
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end

function KeyVisual.Bind(self: KeyVisual, model: Model?)
	disconnect(self)
	local key = if model then model:FindFirstChild(Parts.RollKey) else nil
	if model and key and key:IsA("BasePart") then
		self.Key = key
		self.OriginCFrame = key.CFrame
		self.OriginSize = key.Size
		self.OriginColor = key.Color
		table.insert(
			self.Connections,
			key.AncestryChanged:Connect(function()
				if key.Parent ~= model then
					KeyVisual.Bind(self, model)
				end
			end)
		)
	else
		self.Key = nil
	end
	if model then
		table.insert(
			self.Connections,
			model.ChildAdded:Connect(function(child: Instance)
				if child.Name == Parts.RollKey and child ~= self.Key then
					KeyVisual.Bind(self, model)
				end
			end)
		)
	end
end

function KeyVisual.Clear(self: KeyVisual)
	table.clear(self.SquashTweens)
	self.Key = nil
	disconnect(self)
end

function KeyVisual.Squash(self: KeyVisual)
	local part = self.Key
	if not part then
		return
	end
	for _, active in self.SquashTweens do
		active:Cancel()
		active:Destroy()
	end
	table.clear(self.SquashTweens)
	local size = self.OriginSize
	local origin = self.OriginCFrame
	local down = TweenService:Create(
		part,
		TweenInfo.new(squashDownSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(size.X * squashWidth, size.Y * squashHeight, size.Z * squashWidth),
			CFrame = origin * CFrame.new(0, -size.Y * squashDrop, 0),
		}
	)
	local up = TweenService:Create(
		part,
		TweenInfo.new(squashRiseSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = size, CFrame = origin }
	)
	self.SquashTweens = { down, up }
	down.Completed:Once(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed then
			up:Play()
		end
	end)
	down:Play()
end

function KeyVisual.BuildUp(self: KeyVisual, rarity: Keys.Rarity)
	local part = self.Key
	local seconds = rarity.BuildUpSeconds
	local startedAt = os.clock()
	local connection: RBXScriptConnection? = nil
	if part then
		connection = RunService.RenderStepped:Connect(function()
			local alpha = math.clamp((os.clock() - startedAt) / seconds, 0, 1)
			local amplitude = buildBaseAmplitude + buildGrowAmplitude * alpha
			if not self.IsLowGraphics() then
				part.CFrame = self.OriginCFrame
					* CFrame.new(
						(math.random() - 0.5) * amplitude * 2,
						0,
						(math.random() - 0.5) * amplitude * 2
					)
			end
			part.Color = self.OriginColor:Lerp(rarity.Color, alpha)
		end)
	end
	self.BuildingCount += 1
	task.wait(seconds)
	if connection then
		connection:Disconnect()
	end
	self.BuildingCount -= 1
	if part and self.BuildingCount == 0 and not self.IsDestroyed() and part.Parent then
		part.CFrame = self.OriginCFrame
		part.Color = self.OriginColor
	end
end

function KeyVisual.Tint(self: KeyVisual, color: Color3)
	local part = self.Key
	if not part then
		return
	end
	part.Color = color
	task.delay(goldRestoreSeconds, function()
		if not self.IsDestroyed() and part.Parent and self.BuildingCount == 0 then
			part.Color = self.OriginColor
		end
	end)
end

function KeyVisual.PunchCamera(self: KeyVisual)
	local camera = workspace.CurrentCamera
	if not camera or self.Punching or self.IsLowGraphics() then
		return
	end
	self.Punching = true
	local baseFov = camera.FieldOfView
	local out = TweenService:Create(
		camera,
		TweenInfo.new(punchOutSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = baseFov + punchFov }
	)
	local back = TweenService:Create(
		camera,
		TweenInfo.new(punchBackSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ FieldOfView = baseFov }
	)
	out.Completed:Once(function()
		back:Play()
	end)
	back.Completed:Once(function()
		self.Punching = false
		out:Destroy()
		back:Destroy()
	end)
	out:Play()
end

return KeyVisual

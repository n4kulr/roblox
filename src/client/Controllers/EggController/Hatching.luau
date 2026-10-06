--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Eggs = require(ReplicatedStorage.Config.Eggs)
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Config = require(script.Parent.Config)

local Attributes = WorldNames.Attributes
local Parts = WorldNames.Parts
local Prompts = WorldNames.Prompts

export type Context = {
	GetOwnPlot: () -> Model?,
	Hatch: (index: number, eggId: string) -> (),
}

local Hatching = {}

local function prompt(body: Instance): ProximityPrompt?
	local existing = body:FindFirstChild(Prompts.HatchPrompt)
	return if existing and existing:IsA("ProximityPrompt") then existing else nil
end

local function readyEgg(model: Model): Eggs.Egg?
	local eggId = model:GetAttribute(Attributes.EggId)
	local readyAt = model:GetAttribute(Attributes.ReadyAt)
	local egg = if type(eggId) == "string" then Eggs.ById[eggId] else nil
	if egg and type(readyAt) == "number" and os.time() >= readyAt then
		return egg
	end
	return nil
end

local function build(context: Context, model: Model, body: BasePart, egg: Eggs.Egg)
	local created = Instance.new("ProximityPrompt")
	created.Name = Prompts.HatchPrompt
	created.ActionText = Config.HatchActionText
	created.ObjectText = egg.Name
	created.HoldDuration = Config.HatchPromptHold
	created.MaxActivationDistance = Config.HatchPromptRange
	created.RequiresLineOfSight = false
	created.KeyboardKeyCode = Enum.KeyCode.E
	created.Parent = body
	created.Triggered:Connect(function()
		local index = model:GetAttribute(Attributes.Index)
		if type(index) == "number" then
			context.Hatch(index, egg.Id)
		end
	end)
end

function Hatching.Bind(context: Context, plot: Model, model: Model, trove: any, plotChanged: any)
	local pending: thread? = nil
	local function cancelPending()
		local thread = pending
		pending = nil
		if thread then
			task.cancel(thread)
		end
	end
	local function sync()
		cancelPending()
		local body = model:FindFirstChild(Parts.EggBody)
		if not body or not body:IsA("BasePart") then
			return
		end
		local isMine = context.GetOwnPlot() == plot
		local egg = if isMine then readyEgg(model) else nil
		local existing = prompt(body)
		if not egg then
			if existing then
				existing:Destroy()
			end
			local readyAt = model:GetAttribute(Attributes.ReadyAt)
			if isMine and type(readyAt) == "number" then
				local wait = readyAt - os.time()
				if wait > 0 then
					pending = task.delay(wait + Config.ReadyDelayPadding, sync)
				end
			end
			return
		end
		if not existing then
			build(context, model, body, egg)
		end
	end
	for _, name in { Attributes.EggId, Attributes.ReadyAt } do
		trove:Connect(model:GetAttributeChangedSignal(name), sync)
	end
	trove:Connect(model.ChildAdded, function(child: Instance)
		if child.Name == Parts.EggBody then
			sync()
		end
	end)
	trove:Add(plotChanged:Connect(sync))
	trove:Add(cancelPending)
	sync()
end

return Hatching

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Market = require(ReplicatedStorage.Rules.Market)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Stall = require(script.Stall)

type TroveInstance = typeof(Trove.new())

type State = {
	Name: string,
	_trove: TroveInstance?,
}

local config = GameConfig.Market
local boundaryGuardSeconds = 1
local reachSlack = 6

local MarketService = {
	Name = "MarketService",
	_trove = nil :: TroveInstance?,
}
local services: { [string]: any } = {}
local counter: BasePart? = nil

local function isOfferIndex(value: any): boolean
	return type(value) == "number"
		and value == value
		and value % 1 == 0
		and value >= 1
		and value <= config.OfferCount
end

local function isNearCounter(player: Player): boolean
	local stand = counter
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not stand or not root or not root:IsA("BasePart") then
		return false
	end
	return (root.CFrame.Position - stand.CFrame.Position).Magnitude <= config.PromptRange + reachSlack
end

local function isNearBoundary(now: number): boolean
	local left = Market.SecondsLeft(now)
	return left < boundaryGuardSeconds or config.RefreshSeconds - left < boundaryGuardSeconds
end

local function buy(player: Player, index: number): boolean
	if not isOfferIndex(index) or not isNearCounter(player) then
		return false
	end
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	local replica = services.DataService:GetReplica(player)
	if not data or not replica then
		return false
	end
	local now = workspace:GetServerTimeNow()
	if isNearBoundary(now) then
		return false
	end
	local slot = Market.Slot(now)
	local offer = Market.Offers(slot)[index]
	if not offer then
		return false
	end
	if data.Market.Slot ~= slot then
		replica:SetValues({ "Market" }, { Slot = slot, Bought = {} })
	end
	local bought = data.Market.Bought[tostring(index)] or 0
	if bought >= offer.Stock then
		return false
	end
	services.KeyboardService:Settle(player)
	if data.Cash < offer.Price or not services.DataService:AdjustCash(player, -offer.Price) then
		return false
	end
	if not services.KeyboardService:AddKey(player, offer.KeyId) then
		services.DataService:AdjustCash(player, offer.Price)
		return false
	end
	services.DataService:Set(player, { "Market", "Bought", tostring(index) }, bought + 1)
	services.DataService:Set(player, { "Discovered", offer.KeyId }, (data.Discovered[offer.KeyId] or 0) + 1)
	services.DataService:RequestSave(player)
	return true
end

local function bindStall(trove: TroveInstance): Model
	local authored, stand = Stall.FindAuthored()
	local model: Model
	local anchor: BasePart
	if authored and stand then
		model = authored
		anchor = stand
	else
		local existing = workspace:FindFirstChild(Stall.PlaceholderName)
		local name = if existing then "MarketPlaceholder" else Stall.PlaceholderName
		if existing then
			warn(
				"[MarketService] workspace.Market needs a Model with a BasePart named Counter; building a placeholder"
			)
		end
		local built, counterPart = Stall.Build(name)
		built.Parent = workspace
		trove:Add(built)
		model = built
		anchor = counterPart
	end
	counter = anchor
	local prompt = Stall.EnsurePrompt(anchor)
	trove:Connect(prompt.Triggered, function(player: Player)
		player:SetAttribute("OpenMarket", os.clock())
	end)
	return model
end

function MarketService.Init(self: State, registry: { [string]: any })
	services = registry
	self._trove = Trove.new()
end

function MarketService.Start(self: State)
	local trove = self._trove :: TroveInstance
	local model = bindStall(trove)
	local paintedSlot = Market.Slot(workspace:GetServerTimeNow())
	Stall.Paint(model, paintedSlot)
	trove:Add(task.spawn(function()
		while true do
			local now = workspace:GetServerTimeNow()
			task.wait(math.max(0.1, Market.SecondsLeft(now) + 0.05))
			local slot = Market.Slot(workspace:GetServerTimeNow())
			if slot ~= paintedSlot then
				paintedSlot = slot
				Stall.Paint(model, slot)
			end
		end
	end))
	Packets.MarketBuy.OnServerInvoke = buy
end

function MarketService.Destroy(self: State)
	Packets.MarketBuy.OnServerInvoke = nil
	counter = nil
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return MarketService

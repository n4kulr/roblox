--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharmConfig = require(ReplicatedStorage.Config.Charms)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Charms = require(ReplicatedStorage.Rules.Charms)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type TroveInstance = typeof(Trove.new())

local theme = Kit.Theme
local accent = Color3.fromRGB(170, 96, 255)
local cardSize = Vector2.new(196, 200)
local pacingSeconds = 0.22
local slotCount = CharmConfig.EquipLimit

local CharmsScreen = {}

local function summaryText(equipped: { string }): string
	local effects = Charms.Effects(equipped)
	local parts: { string } = {}
	local function add(text: string)
		table.insert(parts, text)
	end
	if effects.Income > 1 then
		add(string.format("x%.2f Income", effects.Income))
	end
	if effects.Luck > 1 then
		add(string.format("x%.2f Luck", effects.Luck))
	end
	if effects.Speed > 1 then
		add(string.format("+%d%% Roll Speed", math.floor((effects.Speed - 1) * 100 + 0.5)))
	end
	if effects.GoldenReduction > 0 then
		add(`Golden -{effects.GoldenReduction}`)
	end
	if effects.StealSpeed > 1 then
		add(string.format("+%d%% Steal", math.floor((effects.StealSpeed - 1) * 100 + 0.5)))
	end
	if effects.LaserSeconds > 0 then
		add(`+{effects.LaserSeconds}s Laser`)
	end
	return if #parts == 0 then "Equip charms to power up!" else table.concat(parts, "   ")
end

function CharmsScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local cardsTrove = Trove.new()
	local slotsTrove = Trove.new()
	trove:Add(cardsTrove)
	trove:Add(slotsTrove)
	local playUi = Kit.UiSound(context.Controllers)
	local dataController = context.Controllers.DataController
	local owned: { [string]: number } = {}
	local equipped: { string } = {}
	local isOpen = false
	local isBusy = false
	local isDirty = true

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Charms",
		Title = "CHARMS",
		Glyph = "Luck",
		MaxSize = Vector2.new(900, 700),
		HeaderColor = accent,
		OnClose = function()
			context.Close("Charms")
		end,
		Sound = playUi,
	})
	local top = Kit.Panel({
		Parent = modal.Body,
		Name = "Equipped",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 0, 150),
		Color = theme.PanelDeep,
		Radius = Kit.Radius.L,
	})
	Kit.Label({
		Parent = top,
		Name = "Heading",
		Text = `EQUIPPED  {#equipped}/{slotCount}`,
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.fromOffset(300, 26),
		TextSize = 22,
		Title = true,
		Align = Enum.TextXAlignment.Left,
		Scaled = true,
	})
	local summary = Kit.Label({
		Parent = top,
		Name = "Summary",
		Text = "",
		Position = UDim2.fromOffset(14, 118),
		Size = UDim2.new(1, -28, 0, 26),
		TextSize = 22,
		Color = theme.GoodDeep,
		Align = Enum.TextXAlignment.Left,
		Scaled = true,
	})
	local slotRow = Instance.new("Frame")
	slotRow.Name = "Slots"
	slotRow.BackgroundTransparency = 1
	slotRow.Position = UDim2.fromOffset(10, 36)
	slotRow.Size = UDim2.new(1, -230, 0, 76)
	slotRow.Parent = top
	local slotList = Instance.new("UIListLayout")
	slotList.FillDirection = Enum.FillDirection.Horizontal
	slotList.Padding = UDim.new(0, 8)
	slotList.SortOrder = Enum.SortOrder.LayoutOrder
	slotList.Parent = slotRow
	local grid = Kit.GridScroll({
		Parent = modal.Body,
		Name = "Owned",
		Position = UDim2.fromOffset(6, 164),
		Size = UDim2.new(1, -12, 1, -170),
		CellSize = UDim2.fromOffset(cardSize.X, cardSize.Y),
	})
	local emptyNote = Kit.Label({
		Parent = modal.Body,
		Name = "Empty",
		Text = "No charms yet!\nBuy eggs at the market and hatch them on your base.",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.65, 0),
		Size = UDim2.new(0.8, 0, 0, 90),
		TextSize = 26,
		Wrapped = true,
		Scaled = true,
	})
	emptyNote.Visible = false

	local function request(charmId: string, equip: boolean): boolean
		local ok = Packets.EquipCharm:Fire(charmId, equip)
		return ok == true
	end

	local function toggle(charmId: string, equip: boolean)
		if isBusy then
			return
		end
		if equip and not Charms.CanEquip(owned, equipped, charmId) then
			playUi("Error")
			context.Toast(
				if #equipped >= slotCount
					then "All 3 slots are full! Unequip one first."
					else "Can't equip that one!",
				"Bad"
			)
			return
		end
		isBusy = true
		task.spawn(function()
			local ok = request(charmId, equip)
			isBusy = false
			playUi(if ok then "Confirm" else "Error")
		end)
	end

	local function equipBest()
		if isBusy then
			return
		end
		local target = Charms.Best(owned)
		isBusy = true
		task.spawn(function()
			local remaining = table.clone(target)
			for _, charmId in table.clone(equipped) do
				local found = table.find(remaining, charmId)
				if found then
					table.remove(remaining, found)
				else
					request(charmId, false)
					task.wait(pacingSeconds)
				end
			end
			for _, charmId in remaining do
				request(charmId, true)
				task.wait(pacingSeconds)
			end
			isBusy = false
			playUi("Confirm")
			context.Toast("Equipped your best charms!", "Good")
		end)
	end

	local best = Kit.Button(trove, {
		Parent = top,
		Name = "EquipBest",
		Text = "EQUIP BEST",
		Glyph = "Star",
		Position = UDim2.new(1, -12, 0, 40),
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(196, 68),
		Color = theme.Green,
		TextSize = 24,
		Callback = equipBest,
		Sound = playUi,
	})

	local function buildSlots()
		slotsTrove:Clean()
		for index = 1, slotCount do
			local charmId = equipped[index]
			local charm = if charmId then CharmConfig.ById[charmId] else nil
			local slot = Kit.Panel({
				Parent = slotRow,
				Name = `Slot{index}`,
				Size = UDim2.fromOffset(150, 76),
				LayoutOrder = index,
				Color = if charm then charm.Color else theme.Well,
				Radius = Kit.Radius.M,
			})
			slotsTrove:Add(slot)
			if charm then
				local kind = CharmConfig.Kinds[charm.Kind]
				Kit.IconPlate({
					Parent = slot,
					Name = "Art",
					Size = UDim2.fromOffset(44, 44),
					Position = UDim2.fromOffset(6, 6),
					Color = kind.Color,
					Glyph = kind.Glyph,
				})
				Kit.Label({
					Parent = slot,
					Name = "Name",
					Text = charm.Name,
					Position = UDim2.fromOffset(54, 4),
					Size = UDim2.new(1, -58, 0, 26),
					TextSize = 18,
					Title = true,
					Scaled = true,
				})
				Kit.Label({
					Parent = slot,
					Name = "Effect",
					Text = Charms.Describe(charm.Id),
					Position = UDim2.fromOffset(6, 50),
					Size = UDim2.new(1, -12, 0, 22),
					TextSize = 16,
					Title = true,
					Scaled = true,
				})
				local hit = Instance.new("TextButton")
				hit.Name = "Unequip"
				hit.BackgroundTransparency = 1
				hit.Text = ""
				hit.Size = UDim2.fromScale(1, 1)
				hit.ZIndex = 5
				hit.Parent = slot
				slotsTrove:Connect(hit.Activated, function()
					toggle(charm.Id, false)
				end)
			else
				Kit.Label({
					Parent = slot,
					Name = "Empty",
					Text = "EMPTY",
					Size = UDim2.fromScale(1, 1),
					TextSize = 24,
					Color = theme.Subtext,
					Scaled = true,
				})
			end
		end
		summary.Text = summaryText(equipped)
		local heading = top:FindFirstChild("Heading")
		if heading and heading:IsA("TextLabel") then
			heading.Text = `EQUIPPED  {#equipped}/{slotCount}`
		end
	end

	local function buildCard(charm: CharmConfig.Charm, order: number)
		local count = owned[charm.Id] or 0
		local rarity = CharmConfig.RarityByName[charm.Rarity]
		local kind = CharmConfig.Kinds[charm.Kind]
		local equippedCount = Charms.CountOf(equipped, charm.Id)
		local panel = Kit.Panel({
			Parent = grid,
			Name = `Charm_{charm.Id}`,
			Size = UDim2.fromOffset(cardSize.X, cardSize.Y),
			Color = theme.Panel,
			StrokeColor = rarity.Color,
			StrokeThickness = 5,
			LayoutOrder = order,
			Radius = Kit.Radius.L,
			Shards = true,
		})
		cardsTrove:Add(panel)
		Kit.IconPlate({
			Parent = panel,
			Name = "Art",
			Size = UDim2.fromOffset(62, 62),
			Position = UDim2.fromOffset(10, 10),
			Color = kind.Color,
			Glyph = kind.Glyph,
			Burst = true,
		})
		Kit.Chip({
			Parent = panel,
			Name = "Rarity",
			Text = rarity.Name,
			Size = UDim2.fromOffset(100, 26),
			Position = UDim2.new(1, -10, 0, 12),
			AnchorPoint = Vector2.new(1, 0),
			Color = rarity.Color,
			TextSize = 17,
		})
		Kit.Label({
			Parent = panel,
			Name = "CharmName",
			Text = charm.Name,
			Position = UDim2.fromOffset(78, 42),
			Size = UDim2.new(1, -86, 0, 30),
			TextSize = 22,
			Title = true,
			Align = Enum.TextXAlignment.Left,
			Scaled = true,
		})
		Kit.Label({
			Parent = panel,
			Name = "Effect",
			Text = Charms.Describe(charm.Id),
			Position = UDim2.fromOffset(10, 80),
			Size = UDim2.new(1, -20, 0, 40),
			Color = kind.Color,
			TextSize = 30,
			Title = true,
			Scaled = true,
		})
		Kit.Label({
			Parent = panel,
			Name = "Kind",
			Text = kind.Label,
			Position = UDim2.fromOffset(10, 120),
			Size = UDim2.new(1, -20, 0, 18),
			TextSize = 15,
			Subtle = true,
			Scaled = true,
		})
		local isOn = equippedCount > 0
		Kit.Button(cardsTrove, {
			Parent = panel,
			Name = "Equip",
			Text = if isOn then "UNEQUIP" else "EQUIP",
			Position = UDim2.new(0.5, 0, 1, -8),
			AnchorPoint = Vector2.new(0.5, 1),
			Size = UDim2.new(0.88, 0, 0, 44),
			Color = if isOn then theme.Orange else theme.Green,
			TextSize = 22,
			Callback = function()
				toggle(charm.Id, not isOn)
			end,
			Sound = playUi,
		})
		if count > 1 or equippedCount > 0 then
			Kit.Badge(panel, `x{count}`)
		end
	end

	local function rebuild()
		isDirty = false
		cardsTrove:Clean()
		buildSlots()
		local order = 0
		for index = #CharmConfig.Catalog, 1, -1 do
			local charm = CharmConfig.Catalog[index]
			if (owned[charm.Id] or 0) > 0 then
				order += 1
				buildCard(charm, order)
			end
		end
		emptyNote.Visible = order == 0
		best.SetDisabled(order == 0)
	end

	local function changed()
		if isOpen then
			rebuild()
		else
			isDirty = true
		end
	end

	trove:Add(dataController:Observe({ "Charms" }, function(value: any)
		owned = {}
		if type(value) == "table" then
			for id, count in value do
				if type(id) == "string" and type(count) == "number" then
					owned[id] = count
				end
			end
		end
		changed()
	end))
	trove:Add(dataController:Observe({ "EquippedCharms" }, function(value: any)
		equipped = {}
		if type(value) == "table" then
			for _, id in value do
				if type(id) == "string" then
					table.insert(equipped, id)
				end
			end
		end
		changed()
	end))

	return {
		Modal = true,
		StartsOpen = false,
		Open = function(_self: Types.Screen)
			isOpen = true
			if isDirty then
				rebuild()
			end
			modal.Show()
		end,
		Close = function(_self: Types.Screen)
			isOpen = false
			modal.Hide()
		end,
		Destroy = function(_self: Types.Screen)
			trove:Destroy()
		end,
	}
end

return CharmsScreen

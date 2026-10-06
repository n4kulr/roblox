local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local controllerPath = "StarterPlayer.StarterPlayerScripts.Controllers.RollController"

describe("Key model viewports", function()
	local world, Keys, Trove, playerGui, trove

	local function payload(rarityName: string, index: number?, keyId: string?): any
		local pick = Keys.ByRarity[rarityName][index or 1]
		return { Key = pick, KeyId = keyId, Rarity = Keys.GetRarity(pick), IsGolden = false }
	end

	local function frames(root: any): { any }
		local found = {}
		for _, item in root:GetDescendants() do
			if item.ClassName == "ViewportFrame" then
				table.insert(found, item)
			end
		end
		return found
	end

	local function holding(id: string): any
		for _, frame in frames(playerGui) do
			local model = frame:FindFirstChild(id)
			if model then
				return model
			end
		end
		return nil
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		Keys = world:require("ReplicatedStorage.Config.Keys")
		Trove = world:require("ReplicatedStorage.Packages.Trove")
		playerGui = world:newInstance("Folder")
		trove = Trove.new()
	end)

	describe("result cards", function()
		local function build(isLow: (() -> boolean)?)
			local ResultCards = world:require(`{controllerPath}.ResultCards`)
			return ResultCards.new(playerGui, trove, isLow or function()
				return false
			end)
		end

		it("shows the key model in a viewport on the card", function()
			local cards = build()
			local data = payload("Rare")
			cards:Show("Center", data, false)
			local model = holding(data.Key.Id)
			expect(model ~= nil):toBe(true)
			expect(model.Parent.Name):toBe("KeyModel")
			expect(model.Parent.CurrentCamera ~= nil):toBe(true)
		end)

		it("shows a variant model and name when the payload carries a variant id", function()
			local cards = build()
			local data = payload("Rare", 1, `{Keys.ByRarity.Rare[1].Id}@Gold`)
			cards:Show("Center", data, false)
			expect(holding(data.KeyId) ~= nil):toBe(true)
			local found = false
			for _, item in playerGui:GetDescendants() do
				if item.ClassName == "TextLabel" and item.Name == "KeyName" and string.find(item.Text, "Gold") then
					found = true
				end
			end
			expect(found):toBe(true)
		end)

		it("spins the model and holds it still on low graphics", function()
			local isLow = false
			local cards = build(function()
				return isLow
			end)
			local data = payload("Epic")
			cards:Show("Center", data, true)
			local model = holding(data.Key.Id)
			local before = model.PivotCFrame
			cards:Step(0.2)
			expect(model.PivotCFrame ~= before):toBe(true)
			isLow = true
			local still = model.PivotCFrame
			cards:Step(0.2)
			expect(model.PivotCFrame == still):toBe(true)
		end)

		it("reuses its viewports and models across 20 rolls", function()
			local cards = build()
			local baseline = #frames(playerGui)
			for roll = 1, 20 do
				cards:Show("Center", payload("Common", roll % 3 + 1), roll % 2 == 0)
				cards:Step(0.1)
				expect(#frames(playerGui)):toBe(baseline)
				for _, frame in frames(playerGui) do
					expect(#frame:GetChildren() <= 2):toBe(true)
				end
			end
			trove:Destroy()
			expect(#playerGui:GetDescendants()):toBe(0)
		end)
	end)

	describe("cinematic", function()
		local function build()
			local Cinematic = world:require(`{controllerPath}.Cinematic`)
			return Cinematic.new(playerGui, trove, function()
				return false
			end, function()
				return {}
			end)
		end

		it("shows the key model in the big viewport for every tier", function()
			local cine = build()
			for _, name in { "Rare", "Epic", "Legendary", "Mythic", "Secret" } do
				local data = payload(name)
				cine:Play(data)
				cine:Seek(0.9)
				expect(holding(data.Key.Id) ~= nil):toBe(true)
				cine:Step(10)
			end
			expect(#frames(playerGui)):toBe(1)
		end)

		it("shows a variant model", function()
			local cine = build()
			local data = payload("Legendary", 1, `{Keys.ByRarity.Legendary[1].Id}@Rainbow`)
			cine:Play(data)
			expect(holding(data.KeyId) ~= nil):toBe(true)
		end)

		it("keeps exactly one viewport after 20 plays and frees everything on destroy", function()
			local cine = build()
			for _ = 1, 20 do
				cine:Play(payload("Legendary"))
				cine:Step(0.3)
				cine:Step(10)
				expect(#frames(playerGui)):toBe(1)
				expect(#frames(playerGui)[1]:GetChildren() <= 2):toBe(true)
			end
			cine:Destroy()
			trove:Destroy()
			expect(#playerGui:GetDescendants()):toBe(0)
		end)
	end)
end)

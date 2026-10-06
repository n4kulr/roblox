local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local Enum = roblox.Enum
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

describe("KeyPressController", function()
	local world, controller, keysFolder, Keys, FloorGrid, Signal
	local localPlayer, played, tweens, heartbeat
	local capHeight, baseTop
	local offPoint = 20

	local fillerCell = 6
	local slotCell = 11

	local function newSignalNode(className: string): any
		local node = world:newInstance(className)
		node.ChildAdded = Signal.new()
		node.ChildRemoved = Signal.new()
		node.Destroying = Signal.new()
		return node
	end

	local function cellCenter(index: number): (number, number)
		local size = FloorGrid.CellSize
		local zeroBased = index - 1
		local column = zeroBased % 4
		local row = math.floor(zeroBased / 4)
		return -2 * size + (column + 0.5) * size, -2 * size + (row + 0.5) * size
	end

	local function addCap(index: number, attributes: { [string]: any }): any
		local x, z = cellCenter(index)
		local cap = world:newInstance("Part")
		cap.Name = `Cap{index}`
		cap.Size = Vector3.new(3.28, capHeight, 3.28)
		cap.CFrame = CFrame.new(x, baseTop - capHeight / 2, z)
		cap.Position = cap.CFrame.Position
		cap:SetAttribute("Cell", index)
		for name, value in attributes do
			cap:SetAttribute(name, value)
		end
		cap.Parent = keysFolder
		return cap
	end

	local function standAt(player: any, x: number, y: number, z: number, grounded: boolean?)
		local character = player.Character
		if not character then
			character = world:spawnCharacter(player, x, y, z)
		else
			world:moveCharacter(player, x, y, z)
		end
		character.HumanoidRootPart.Position = Vector3.new(x, y, z)
		character.Humanoid.FloorMaterial = if grounded == false then Enum.Material.Air else Enum.Material.Plastic
	end

	local function standOn(player: any, index: number, grounded: boolean?)
		local x, z = cellCenter(index)
		standAt(player, x, baseTop + 3, z, grounded)
	end

	local function stepOff(player: any)
		standAt(player, offPoint, baseTop + 3, offPoint)
	end

	local function beat()
		heartbeat:Fire(1 / 60)
	end

	local function restY(): number
		return baseTop - capHeight / 2
	end

	local function depthOf(cap: any): number
		return restY() - cap.CFrame.Position.Y
	end

	local function raises(): { any }
		local out = {}
		for _, tween in tweens do
			if tween.Style == Enum.EasingStyle.Back then
				table.insert(out, tween)
			end
		end
		return out
	end

	local function capAt(index: number): any
		return keysFolder:FindFirstChild(`Cap{index}`)
	end

	beforeEach(function()
		world = H.newWorld()
		Signal = world:require("ReplicatedStorage.Packages.Signal")
		Keys = world:require("ReplicatedStorage.Config.Keys")
		FloorGrid = world:require("ReplicatedStorage.Rules.FloorGrid")
		offPoint = 20
		capHeight = FloorGrid.CapHeight
		baseTop = 0.5 + capHeight
		localPlayer = world:newPlayer({ Name = "Local" })
		world.Players.LocalPlayer = localPlayer
		heartbeat = world.fakeServices.RunService.Heartbeat

		tweens = {}
		world.fakeServices.TweenService = {
			Create = function(_self: any, target: any, info: any, goal: any)
				local tween: any = { Completed = Signal.new(), Cancelled = false, Target = target, Goal = goal }
				tween.Seconds = info[1]
				tween.Style = info[2]
				tween.Direction = info[3]
				table.insert(tweens, tween)
				function tween.Play()
					for key, value in goal do
						target[key] = value
					end
					world.task.defer(function()
						tween.Completed:Fire()
					end)
				end
				function tween.Cancel()
					tween.Cancelled = true
				end
				function tween.Destroy() end
				return tween
			end,
		}

		world.workspace.CurrentCamera = { CFrame = CFrame.new(0, 20, 0) }
		world.workspace.ChildAdded = Signal.new()
		local plots = newSignalNode("Folder")
		plots.Name = "Plots"
		plots.Parent = world.workspace
		local plot = newSignalNode("Model")
		plot.Name = "Plot1"
		plot:SetAttribute("FloorColumns", 4)
		plot:SetAttribute("FloorRows", 4)
		local base = world:newPart("Base", 0, 0, 0)
		base.Size = Vector3.new(44, 1, 44)
		base.Parent = plot
		keysFolder = newSignalNode("Folder")
		keysFolder.Name = "Keys"
		keysFolder.Parent = plot
		plot.Parent = plots

		played = {}
		local registry = {
			SoundController = {
				PlaySwitch = function(
					_self: any,
					switchId: string,
					kind: string,
					_speed: number,
					volume: number,
					position: any,
					category: string
				)
					table.insert(played, {
						Switch = switchId,
						Kind = kind,
						Volume = volume,
						Category = category,
						Position = position,
					})
				end,
			},
			DataController = {
				Observe = function(_self: any, _path: any, callback: any)
					callback(false)
					return function() end
				end,
			},
		}
		controller = world:require("StarterPlayer.StarterPlayerScripts.Controllers.KeyPressController")
		addCap(fillerCell, { Filler = true })
		addCap(slotCell, { Slot = 1, KeyId = "GlassTink" })
		controller:Init(registry)
		controller:Start()
		table.insert(world.started, controller)
		world:flush()
	end)

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	it("presses a slot key down when a player steps on it and plays its own switch", function()
		local cap = capAt(slotCell)
		standOn(localPlayer, slotCell)
		beat()
		expect(depthOf(cap)):toBeCloseTo(1.1, 1e-6)
		expect(#played):toBe(1)
		expect(played[1].Kind):toBe("Press")
		expect(played[1].Switch):toBe(Keys.ById.GlassTink.Switch)
		expect(played[1].Volume):toBe(1)
		expect(played[1].Category):toBe("Board")
	end)

	it("presses filler caps shallower and with the quieter filler sound", function()
		local cap = capAt(fillerCell)
		standOn(localPlayer, fillerCell)
		beat()
		expect(depthOf(cap)):toBeCloseTo(0.75, 1e-6)
		expect(#played):toBe(1)
		expect(played[1].Switch):toBe("CreamTravel")
		expect(played[1].Volume):toBe(0.55)
	end)

	it("tags other players' presses with the Other volume category", function()
		local other = world:newPlayer({ Name = "Other" })
		standOn(other, fillerCell)
		beat()
		expect(#played):toBe(1)
		expect(played[1].Category):toBe("Other")
	end)

	it("keeps the key down while the player stands still", function()
		local cap = capAt(slotCell)
		standOn(localPlayer, slotCell)
		for _ = 1, 10 do
			beat()
			world:advance(0.2)
		end
		expect(depthOf(cap)):toBeCloseTo(1.1, 1e-6)
		expect(#played):toBe(1)
		expect(#raises()):toBe(0)
	end)

	it("waits the release delay then rises with a Back-eased tween when the player leaves", function()
		local cap = capAt(slotCell)
		standOn(localPlayer, slotCell)
		beat()
		stepOff(localPlayer)
		beat()
		expect(#played):toBe(2)
		expect(played[2].Kind):toBe("Release")
		world:advance(0.1)
		expect(depthOf(cap)):toBeCloseTo(1.1, 1e-6)
		expect(#raises()):toBe(0)
		world:advance(0.1)
		expect(#raises()):toBe(1)
		local up = raises()[1]
		expect(up.Seconds):toBe(0.25)
		expect(up.Direction):toBe(Enum.EasingDirection.Out)
		expect(depthOf(cap)):toBeCloseTo(0, 1e-6)
	end)

	it("cancels the pending raise when the player steps back on during the delay", function()
		local cap = capAt(slotCell)
		standOn(localPlayer, slotCell)
		beat()
		stepOff(localPlayer)
		beat()
		world:advance(0.1)
		standOn(localPlayer, slotCell)
		beat()
		world:advance(1)
		expect(#raises()):toBe(0)
		expect(depthOf(cap)):toBeCloseTo(1.1, 1e-6)
		expect(#played):toBe(2)
	end)

	it("presses again after a full release and re-step", function()
		local cap = capAt(fillerCell)
		standOn(localPlayer, fillerCell)
		beat()
		stepOff(localPlayer)
		beat()
		world:advance(1)
		expect(depthOf(cap)):toBeCloseTo(0, 1e-6)
		standOn(localPlayer, fillerCell)
		beat()
		expect(depthOf(cap)):toBeCloseTo(0.75, 1e-6)
		local pressSounds = 0
		for _, sound in played do
			if sound.Kind == "Press" then
				pressSounds += 1
			end
		end
		expect(pressSounds):toBe(2)
	end)

	it("only rises after every player has left a shared key", function()
		local cap = capAt(fillerCell)
		local other = world:newPlayer({ Name = "Other" })
		standOn(localPlayer, fillerCell)
		standOn(other, fillerCell)
		beat()
		expect(#played):toBe(1)
		stepOff(localPlayer)
		beat()
		world:advance(2)
		expect(#raises()):toBe(0)
		expect(depthOf(cap)):toBeCloseTo(0.75, 1e-6)
		stepOff(other)
		beat()
		world:advance(0.1)
		expect(#raises()):toBe(0)
		world:advance(0.1)
		expect(#raises()):toBe(1)
		expect(depthOf(cap)):toBeCloseTo(0, 1e-6)
	end)

	it("releases a key when its player leaves the game", function()
		local cap = capAt(fillerCell)
		local other = world:newPlayer({ Name = "Other" })
		standOn(other, fillerCell)
		beat()
		world:removePlayer(other)
		beat()
		world:advance(0.5)
		expect(#raises()):toBe(1)
		expect(depthOf(cap)):toBeCloseTo(0, 1e-6)
	end)

	it("ignores airborne players and locked caps", function()
		local filler = capAt(fillerCell)
		standOn(localPlayer, fillerCell, false)
		beat()
		expect(depthOf(filler)):toBeCloseTo(0, 1e-6)
		expect(#played):toBe(0)
		stepOff(localPlayer)
		beat()
		local locked = addCap(7, { Slot = 2, Locked = true })
		standOn(localPlayer, 7)
		beat()
		expect(depthOf(locked)):toBeCloseTo(0, 1e-6)
		expect(#played):toBe(0)
	end)

	it("handles stepping from one key straight onto another", function()
		local first = capAt(fillerCell)
		local second = capAt(slotCell)
		standOn(localPlayer, fillerCell)
		beat()
		standOn(localPlayer, slotCell)
		beat()
		expect(depthOf(second)):toBeCloseTo(1.1, 1e-6)
		expect(depthOf(first)):toBeCloseTo(0.75, 1e-6)
		world:advance(0.5)
		expect(depthOf(first)):toBeCloseTo(0, 1e-6)
		expect(depthOf(second)):toBeCloseTo(1.1, 1e-6)
	end)

	describe("cosmetic keys", function()
		local model, frame

		local function addCosmetic(cframe: any)
			world.workspace.CurrentCamera = { CFrame = CFrame.new(100, 20, 100) }
			offPoint = 125
			local cosmeticService = world:require("ServerScriptService.Services.CosmeticService")
			local part = world:newInstance("Part")
			part.Name = "keyboardstuff"
			part.CFrame = cframe
			part.Size = Vector3.new(40, 2, 40)
			model = cosmeticService.Build(part)
			for _, child in model:GetChildren() do
				child.Position = child.CFrame.Position
			end
			model.ChildAdded = Signal.new()
			model.Destroying = Signal.new()
			model.Parent = world.workspace
			world.workspace.ChildAdded:Fire(model)
			frame = model:GetAttribute("Frame")
		end

		local function cosmeticCap(i: number, j: number): any
			return model:FindFirstChild(`Cosmetic{i}_{j}`)
		end

		local function standOnCosmetic(player: any, i: number, j: number, grounded: boolean?)
			local pitch = FloorGrid.CellSize
			local position = frame * CFrame.new(i * pitch, capHeight + 3, j * pitch)
			standAt(player, position.Position.X, position.Position.Y, position.Position.Z, grounded)
		end

		local function cosmeticDepth(cap: any): number
			local rest = frame * CFrame.new(cap:GetAttribute("GridX") * 3.4, capHeight / 2 - 0.35, cap:GetAttribute("GridZ") * 3.4)
			return (rest.Position - cap.CFrame.Position).Magnitude
		end

		it("presses a cosmetic cap like a filler key and plays the filler sound", function()
			addCosmetic(CFrame.new(100, 5, 100))
			local cap = cosmeticCap(0, 0)
			standOnCosmetic(localPlayer, 0, 0)
			beat()
			expect(cosmeticDepth(cap)):toBeCloseTo(0.75, 1e-4)
			expect(#played):toBe(1)
			expect(played[1].Switch):toBe("CreamTravel")
			expect(played[1].Volume):toBe(0.55)
			expect(played[1].Kind):toBe("Press")
		end)

		it("keeps a cosmetic cap down while stood on, then rises after the delay", function()
			addCosmetic(CFrame.new(100, 5, 100))
			local cap = cosmeticCap(1, 1)
			standOnCosmetic(localPlayer, 1, 1)
			for _ = 1, 8 do
				beat()
				world:advance(0.25)
			end
			expect(cosmeticDepth(cap)):toBeCloseTo(0.75, 1e-4)
			expect(#raises()):toBe(0)
			stepOff(localPlayer)
			beat()
			world:advance(0.1)
			expect(#raises()):toBe(0)
			world:advance(0.1)
			expect(#raises()):toBe(1)
			expect(raises()[1].Seconds):toBe(0.25)
			expect(cosmeticDepth(cap)):toBeCloseTo(0, 1e-4)
			expect(played[#played].Kind):toBe("Release")
		end)

		it("cancels the raise on re-step and waits for both players on a shared cosmetic cap", function()
			addCosmetic(CFrame.new(100, 5, 100))
			local cap = cosmeticCap(-1, 2)
			local other = world:newPlayer({ Name = "Other" })
			standOnCosmetic(localPlayer, -1, 2)
			standOnCosmetic(other, -1, 2)
			beat()
			stepOff(localPlayer)
			beat()
			world:advance(1)
			expect(#raises()):toBe(0)
			stepOff(other)
			beat()
			world:advance(0.1)
			standOnCosmetic(other, -1, 2)
			beat()
			world:advance(1)
			expect(#raises()):toBe(0)
			expect(cosmeticDepth(cap)):toBeCloseTo(0.75, 1e-4)
		end)

		it("ignores positions on the floor beside a cosmetic cap and works on a rotated circle", function()
			addCosmetic(CFrame.new(100, 5, 100) * CFrame.Angles(0, 0.7, 0))
			local cap = cosmeticCap(0, 0)
			standOnCosmetic(localPlayer, 7, 0)
			beat()
			expect(cosmeticDepth(cap)):toBeCloseTo(0, 1e-4)
			expect(#played):toBe(0)
			standOnCosmetic(localPlayer, 0, 0)
			beat()
			expect(cosmeticDepth(cap)):toBeCloseTo(0.75, 1e-4)
		end)
	end)
end)

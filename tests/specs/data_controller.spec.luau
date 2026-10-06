local H = require("../harness/Harness")

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

describe("DataController", function()
	local world, controller, player, fakeClient, onNew

	local function newReplica(owner: any, data: any): any
		local replica: any = { Tags = { Player = owner }, Data = data, Handlers = {} }
		function replica.OnChange(_self: any, handler: any)
			table.insert(replica.Handlers, handler)
			return {
				Disconnect = function()
					replica.Handlers = {}
				end,
			}
		end
		function replica.Emit(_self: any, action: string, path: { any })
			for _, handler in table.clone(replica.Handlers) do
				handler(action, path)
			end
		end
		return replica
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		player = world:newPlayer({ Name = "Local" })
		world.Players.LocalPlayer = player
		fakeClient = {
			Requested = 0,
			OnNew = function(_name: string, handler: any)
				onNew = handler
				return {
					Disconnect = function()
						onNew = nil
					end,
				}
			end,
			RequestData = function()
				fakeClient.Requested += 1
			end,
		}
		world.overrides[world:node("ReplicatedStorage.ReplicaClient")] = fakeClient
		controller = world:require("StarterPlayer.StarterPlayerScripts.Controllers.DataController")
		controller:Init({})
		controller:Start()
	end)

	afterEach(function()
		controller:Destroy()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	it("requests data on start and reports nothing before the replica arrives", function()
		expect(fakeClient.Requested):toBe(1)
		expect(controller:IsLoaded()):toBe(false)
		expect(controller:Get()):toBeNil()
		expect(controller:Get({ "Cash" })):toBeNil()
	end)

	it("loads the local player's replica and reads nested paths", function()
		onNew(newReplica(player, { Cash = 5, Board = { "A", "B" } }))
		expect(controller:IsLoaded()):toBe(true)
		expect(controller:Get({ "Cash" })):toBe(5)
		expect(controller:Get({ "Board", 2 })):toBe("B")
		expect(controller:Get({ "Missing", "Deep" })):toBeNil()
		expect(controller:Get({ "Cash", "Deep" })):toBeNil()
		expect(controller:Get().Cash):toBe(5)
	end)

	it("ignores replicas that belong to other players", function()
		onNew(newReplica(world:newPlayer({ Name = "Other" }), { Cash = 1 }))
		expect(controller:IsLoaded()):toBe(false)
	end)

	it("fires Loaded with the data", function()
		local seen
		controller.Loaded:Connect(function(data: any)
			seen = data
		end)
		local data = { Cash = 2 }
		onNew(newReplica(player, data))
		expect(seen == data):toBe(true)
	end)

	it("calls observers registered before load once the data arrives", function()
		local values = {}
		controller:Observe({ "Cash" }, function(value: any)
			table.insert(values, { Value = value })
		end)
		expect(#values):toBe(0)
		onNew(newReplica(player, { Cash = 9 }))
		expect(#values):toBe(1)
		expect(values[1].Value):toBe(9)
	end)

	it("calls observers registered after load immediately", function()
		onNew(newReplica(player, { Cash = 3 }))
		local seen
		controller:Observe({ "Cash" }, function(value: any)
			seen = value
		end)
		expect(seen):toBe(3)
	end)

	it("only notifies observers whose path overlaps the change", function()
		local replica = newReplica(player, { Cash = 1, Board = { "A" }, Settings = { LowGraphics = false } })
		onNew(replica)
		local cash, board, graphics, root = 0, 0, 0, 0
		controller:Observe({ "Cash" }, function()
			cash += 1
		end)
		controller:Observe({ "Board" }, function()
			board += 1
		end)
		controller:Observe({ "Settings", "LowGraphics" }, function()
			graphics += 1
		end)
		controller:Observe({}, function()
			root += 1
		end)
		replica.Data.Cash = 2
		replica:Emit("Set", { "Cash" })
		expect(cash):toBe(2)
		expect(board):toBe(1)
		expect(graphics):toBe(1)
		expect(root):toBe(2)
		replica.Data.Board[1] = "Z"
		replica:Emit("Set", { "Board", 1 })
		expect(board):toBe(2)
		replica.Data.Settings.LowGraphics = true
		replica:Emit("Set", { "Settings" })
		expect(graphics):toBe(2)
	end)

	it("stops notifying a disconnected observer", function()
		local replica = newReplica(player, { Cash = 1 })
		onNew(replica)
		local count = 0
		local connection = controller:Observe({ "Cash" }, function()
			count += 1
		end)
		connection:Disconnect()
		replica:Emit("Set", { "Cash" })
		expect(count):toBe(1)
	end)

	it("stops a pending observer that disconnects before the data loads", function()
		local count = 0
		local connection = controller:Observe({ "Cash" }, function()
			count += 1
		end)
		connection:Disconnect()
		onNew(newReplica(player, { Cash = 1 }))
		expect(count):toBe(0)
	end)

	it("forgets the replica on destroy", function()
		controller:Destroy()
		expect(controller:IsLoaded()):toBe(false)
	end)
end)

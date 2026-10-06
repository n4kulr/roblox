local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local CFrame = roblox.CFrame

local Random = require("./Random")
local Tree = require("./Tree")

local World = {}
World.__index = World

local guiClasses: { [string]: boolean } = {
	ScreenGui = true,
	Frame = true,
	TextButton = true,
	TextLabel = true,
	ImageLabel = true,
	ScrollingFrame = true,
	UIScale = true,
	ViewportFrame = true,
}

local bytecodeCache: { [string]: string } = {}
local sharedTree: any = nil

local function getTree()
	if not sharedTree then
		sharedTree = Tree.fromSourcemap("sourcemap.json")
	end
	return sharedTree
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

local function deepMerge(target: any, overrides: any)
	for k, v in overrides do
		if type(v) == "table" and type(target[k]) == "table" then
			deepMerge(target[k], v)
		else
			target[k] = deepCopy(v)
		end
	end
	return target
end

World.deepCopy = deepCopy
World.deepMerge = deepMerge

local function resolve(root: any, path: string): any
	local node = root
	for part in string.gmatch(path, "[^%.]+") do
		node = node:FindFirstChild(part)
		if not node then
			error(`harness: no node '{path}' in sourcemap`, 3)
		end
	end
	return node
end

local function makeScheduler(world)
	local queue: { { at: number, seq: number, thread: thread, args: { any }, n: number } } = {}
	local seq = 0
	local inside = 0
	local task = {}

	local function run(thread: thread, ...)
		inside += 1
		local ok, err = coroutine.resume(thread, ...)
		inside -= 1
		if not ok then
			table.insert(world.errors, tostring(err))
			if world.printErrors then
				io.stderr:write(`[harness] thread error: {tostring(err)}\n`)
			end
		end
	end

	local function toThread(fnOrThread: any): thread
		if type(fnOrThread) == "thread" then
			return fnOrThread
		end
		return coroutine.create(fnOrThread)
	end

	local function schedule(thread: thread, delay: number, ...)
		seq += 1
		table.insert(queue, { at = world.clock + delay, seq = seq, thread = thread, args = table.pack(...), n = seq })
	end

	function task.spawn(fnOrThread: any, ...)
		local thread = toThread(fnOrThread)
		run(thread, ...)
		return thread
	end

	function task.defer(fnOrThread: any, ...)
		local thread = toThread(fnOrThread)
		schedule(thread, 0, ...)
		return thread
	end

	function task.delay(delay: number, fnOrThread: any, ...)
		local thread = toThread(fnOrThread)
		schedule(thread, delay or 0, ...)
		return thread
	end

	function task.wait(delay: number?)
		local duration = delay or 0
		if inside > 0 then
			schedule(coroutine.running(), duration, duration)
			return coroutine.yield()
		end
		world:advance(duration)
		return duration
	end

	function task.cancel(thread: thread)
		for index = #queue, 1, -1 do
			if queue[index].thread == thread then
				table.remove(queue, index)
			end
		end
		if coroutine.status(thread) == "suspended" then
			pcall(coroutine.close, thread)
		end
	end

	function task.synchronize() end
	function task.desynchronize() end

	local function pop(limit: number)
		local best = nil
		local bestIndex = nil
		for index, item in queue do
			if item.at <= limit and (not best or item.at < best.at or (item.at == best.at and item.seq < best.seq)) then
				best, bestIndex = item, index
			end
		end
		if bestIndex then
			table.remove(queue, bestIndex)
		end
		return best
	end

	function world.advance(self, seconds: number)
		local target = self.clock + seconds
		while true do
			local item = pop(target)
			if not item then
				break
			end
			local delta = item.at - self.clock
			if delta > 0 then
				self.clock = item.at
				self.now += delta
			end
			if coroutine.status(item.thread) == "suspended" then
				run(item.thread, table.unpack(item.args, 1, item.args.n))
			end
		end
		local rest = target - self.clock
		if rest > 0 then
			self.clock = target
			self.now += rest
		end
	end

	function world.flush(self)
		self:advance(0)
	end

	function world.pendingTasks(_self)
		return #queue
	end

	return task
end

local function makeSignalFactory(world)
	return function()
		return world:require("ReplicatedStorage.Packages.Signal").new()
	end
end

local function makePlayers(world)
	local Signal = world:require("ReplicatedStorage.Packages.Signal")
	local players = {
		PlayerAdded = Signal.new(),
		PlayerRemoving = Signal.new(),
		_list = {},
	}
	function players.GetPlayers(_self)
		return table.clone(players._list)
	end
	function players.GetNameFromUserIdAsync(_self, userId: number)
		world.nameLookups += 1
		if world.nameFailures > 0 then
			world.nameFailures -= 1
			error("fake name lookup failure")
		end
		local name = world.userNames[userId]
		if not name then
			error("fake name lookup: unknown user")
		end
		return name
	end
	function players.GetPlayerByUserId(_self, userId: number)
		for _, player in players._list do
			if player.UserId == userId then
				return player
			end
		end
		return nil
	end
	return players
end

local function makeFakeServices(world)
	local services: { [string]: any } = {}
	services.Players = world.Players

	local heartbeat = world:require("ReplicatedStorage.Packages.Signal").new()
	services.RunService = {
		Heartbeat = heartbeat,
		RenderStepped = world:require("ReplicatedStorage.Packages.Signal").new(),
		Stepped = world:require("ReplicatedStorage.Packages.Signal").new(),
		IsServer = function()
			return true
		end,
		IsClient = function()
			return false
		end,
		IsStudio = function()
			return false
		end,
		IsRunning = function()
			return true
		end,
		BindToRenderStep = function() end,
		UnbindFromRenderStep = function() end,
	}

	services.GuiService = {
		GetGuiInset = function()
			return roblox.Vector2.new(0, 58)
		end,
	}

	local guidCounter = 0
	services.HttpService = {
		GenerateGUID = function(_self, wrap: boolean?)
			guidCounter += 1
			local guid = string.format("00000000-0000-4000-8000-%012d", guidCounter)
			return if wrap == false then guid else `\{{guid}\}`
		end,
		JSONEncode = function(_self, value: any)
			return require("@lune/serde").encode("json", value)
		end,
		JSONDecode = function(_self, text: string)
			return require("@lune/serde").decode("json", text)
		end,
	}

	services.MarketplaceService = {
		ProcessReceipt = nil,
		PromptProductPurchase = function(_self, player: any, productId: number)
			table.insert(world.prompts, { Kind = "Product", Player = player, Id = productId })
		end,
		PromptGamePassPurchase = function(_self, player: any, passId: number)
			table.insert(world.prompts, { Kind = "Pass", Player = player, Id = passId })
		end,
		UserOwnsGamePassAsync = function(_self, userId: number, assetId: number)
			if world.passCheckFailures > 0 then
				world.passCheckFailures -= 1
				error("fake marketplace outage")
			end
			local owned = world.ownedPasses[userId]
			return owned ~= nil and owned[assetId] == true
		end,
		PromptPurchaseFinished = world:require("ReplicatedStorage.Packages.Signal").new(),
		PromptGamePassPurchaseFinished = world:require("ReplicatedStorage.Packages.Signal").new(),
	}

	local tags: { [string]: { any } } = {}
	services.CollectionService = {
		GetTagged = function(_self, tag: string)
			return table.clone(tags[tag] or {})
		end,
		GetInstanceAddedSignal = function()
			return world:require("ReplicatedStorage.Packages.Signal").new()
		end,
		GetInstanceRemovedSignal = function()
			return world:require("ReplicatedStorage.Packages.Signal").new()
		end,
		AddTag = function(_self, instance: any, tag: string)
			tags[tag] = tags[tag] or {}
			table.insert(tags[tag], instance)
		end,
		HasTag = function(_self, instance: any, tag: string)
			return table.find(tags[tag] or {}, instance) ~= nil
		end,
	}

	services.GroupService = {
		PromptJoinAsync = function(_self, groupId: number)
			if world.groupPromptUnavailable then
				error("fake group service unavailable")
			end
			table.insert(world.groupPrompts, groupId)
			return "Joined"
		end,
	}

	services.DataStoreService = {
		GetOrderedDataStore = function(_self, name: string)
			if world.orderedDown then
				error("fake ordered datastore unavailable")
			end
			local values = world.orderedStores[name]
			if not values then
				values = {}
				world.orderedStores[name] = values
			end
			return {
				SetAsync = function(_store, key: string, value: number)
					world.orderedWrites += 1
					if world.orderedDown then
						error("fake ordered datastore unavailable")
					end
					values[key] = value
				end,
				GetSortedAsync = function(_store, ascending: boolean, pageSize: number)
					world.orderedReads += 1
					if world.orderedDown then
						error("fake ordered datastore unavailable")
					end
					local page = {}
					for key, value in values do
						table.insert(page, { key = key, value = value })
					end
					table.sort(page, function(a, b)
						if a.value ~= b.value then
							if ascending then
								return a.value < b.value
							end
							return a.value > b.value
						end
						return a.key < b.key
					end)
					while #page > pageSize do
						table.remove(page)
					end
					return {
						GetCurrentPage = function()
							return page
						end,
					}
				end,
			}
		end,
		GetDataStore = function()
			return {
				GetAsync = function() end,
				SetAsync = function() end,
				UpdateAsync = function() end,
				RemoveAsync = function() end,
			}
		end,
	}
	services.AssetService = {
		CreateMeshPartAsync = function(_self, content: any, _options: any)
			table.insert(world.meshRequests, content)
			if world.meshDelay > 0 then
				world.task.wait(world.meshDelay)
			end
			if world.meshFailures[content] then
				error("fake asset service: cannot load " .. tostring(content))
			end
			return world:newInstance("MeshPart")
		end,
	}
	services.TextChatService = {}
	services.ServerStorage = Tree.node("ServerStorage", "ServerStorage")
	services.TweenService = {
		Create = function(_self, target: any, info: any, goal: { [string]: any })
			local isLooping = type(info) == "table" and info[4] == -1
			local tween: any = { Completed = world:require("ReplicatedStorage.Packages.Signal").new() }
			function tween.Play()
				if isLooping then
					return
				end
				for key, value in goal do
					pcall(function()
						target[key] = value
					end)
				end
				world.task.defer(function()
					tween.Completed:Fire()
				end)
			end
			function tween.Pause() end
			function tween.Cancel() end
			function tween.Destroy() end
			return tween
		end,
	}
	services.ReplicatedFirst = {
		RemoveDefaultLoadingScreen = function()
			world.defaultScreenRemovals += 1
		end,
	}
	services.ContentProvider = {
		RequestQueueSize = 0,
		PreloadAsync = function() end,
	}
	services.UserInputService = {
		InputBegan = world:require("ReplicatedStorage.Packages.Signal").new(),
		InputChanged = world:require("ReplicatedStorage.Packages.Signal").new(),
		InputEnded = world:require("ReplicatedStorage.Packages.Signal").new(),
		GetLastInputType = function()
			return roblox.Enum.UserInputType.MouseMovement
		end,
		TouchEnabled = false,
	}
	return services
end

function World.new(
	options: {
		Seed: number?,
		Time: number?,
		Clock: number?,
		PrintErrors: boolean?,
		AssetIds: { [string]: number }?,
		GuiSize: any?,
	}?
)
	options = options or {}
	local opts = options :: any
	local tree = getTree()
	local self = setmetatable({
		tree = tree,
		now = opts.Time or 1700000000,
		clock = opts.Clock or 1000,
		seed = opts.Seed or 1,
		errors = {} :: { string },
		warnings = {} :: { string },
		logs = {} :: { string },
		printErrors = opts.PrintErrors,
		guiSize = opts.GuiSize or roblox.Vector2.new(1280, 720),
		cache = {} :: { [any]: any },
		overrides = {} :: { [any]: any },
		fired = {} :: { { Packet: string, Target: any, Args: { any } } },
		started = {} :: { any },
		registry = {} :: { [string]: any },
		saves = {} :: { [any]: number },
		prompts = {} :: { { Kind: string, Player: any, Id: number } },
		ownedPasses = {} :: { [number]: { [number]: boolean } },
		passCheckFailures = 0,
		groupMembers = {} :: { [number]: { [number]: boolean } },
		groupFailures = 0,
		groupChecks = 0,
		groupPrompts = {} :: { number },
		groupPromptUnavailable = false,
		meshRequests = {} :: { any },
		meshFailures = {} :: { [any]: boolean },
		meshDelay = 0,
		orderedStores = {} :: { [string]: { [string]: number } },
		orderedDown = false,
		orderedReads = 0,
		orderedWrites = 0,
		userNames = {} :: { [number]: string },
		nameFailures = 0,
		nameLookups = 0,
		_kicked = {} :: { any },
		gameLoaded = true,
		defaultScreenRemovals = 0,
		bases = {} :: { [any]: any },
	}, World)

	self.task = makeScheduler(self)
	self.Random = {
		new = function(seed: number?)
			if seed == nil then
				self.seed += 1
				return Random.new(self.seed * 104729)
			end
			return Random.new(seed)
		end,
	}
	self.workspace = Tree.node("Workspace", "Workspace")
	self.workspace.GetServerTimeNow = function()
		return self.now
	end
	self.os = table.clone(os)
	self.os.time = function(t: any)
		if t ~= nil then
			return os.time(t)
		end
		return math.floor(self.now)
	end
	self.os.clock = function()
		return self.clock
	end
	self.Players = makePlayers(self)
	self.fakeServices = makeFakeServices(self)
	self:_installPacketStub()
	self.tree.ReplicatedStorage:SetAttribute("ServerLuckUntil", nil)
	self.tree.ReplicatedStorage:SetAttribute("ServerLuckBy", nil)
	self.game = self:_makeGame()
	self.Data = require("./FakeData").new(self)
	if opts.AssetIds then
		self:_overrideAssetIds(opts.AssetIds)
	end
	self.fakeRegistry = {
		DataService = self.Data.Service,
		PlotService = {
			Name = "PlotService",
			GetPlot = function(_self, player: any)
				return if self.Players._list and table.find(self.Players._list, player) then {} else nil
			end,
			GetBase = function(_self, player: any)
				if not (self.Players._list and table.find(self.Players._list, player)) then
					return nil
				end
				if not self.bases[player] then
					local base = self:newPart("Base", 0, 0, 0)
					base.Size = roblox.Vector3.new(44, 1, 44)
					self.bases[player] = base
				end
				return self.bases[player]
			end,
			GetRollKey = function(_self: any, player: any)
				if not (self.Players._list and table.find(self.Players._list, player)) then
					return nil
				end
				if not self.rollKeys then
					self.rollKeys = {}
				end
				if not self.rollKeys[player] then
					local part = self:newPart("RollKey", 0, 2, -10)
					part.Size = roblox.Vector3.new(8, 3, 8)
					self.rollKeys[player] = part
				end
				return self.rollKeys[player]
			end,
		},
	}
	return self
end

function World._overrideAssetIds(self, assetIds: { [string]: number })
	local real = self:require("ReplicatedStorage.Config.Monetization")
	local copy: any = { Passes = {}, PassById = {}, Products = {}, ProductById = {} }
	for _, pass in real.Passes do
		local clone = table.clone(pass)
		clone.AssetId = assetIds[pass.Id] or pass.AssetId
		table.insert(copy.Passes, clone)
		copy.PassById[clone.Id] = clone
	end
	for _, product in real.Products do
		local clone = table.clone(product)
		clone.AssetId = assetIds[product.Id] or product.AssetId
		table.insert(copy.Products, clone)
		copy.ProductById[clone.Id] = clone
	end
	self.overrides[self.tree.ReplicatedStorage.Config.Monetization] = copy
end

function World.own(self, player: any, assetId: number)
	self.ownedPasses[player.UserId] = self.ownedPasses[player.UserId] or {}
	self.ownedPasses[player.UserId][assetId] = true
end

function World.setGroupMember(self, player: any, groupId: number, isMember: boolean)
	self.groupMembers[player.UserId] = self.groupMembers[player.UserId] or {}
	self.groupMembers[player.UserId][groupId] = isMember
end

function World.receipt(self, player: any, productId: number, purchaseId: number?)
	self._receiptCount = (self._receiptCount or 0) + 1
	local handler = self.fakeServices.MarketplaceService.ProcessReceipt
	return handler({
		PurchaseId = purchaseId or self._receiptCount,
		PlayerId = player.UserId,
		ProductId = productId,
		CurrencySpent = 1,
		CurrencyType = "Robux",
		PlaceIdWherePurchased = 1,
	})
end

function World._makeGame(self)
	local world = self
	local roots = { "ReplicatedStorage", "ServerScriptService", "StarterPlayer" }
	local game = {
		PlaceId = 1,
		GameId = 1,
		JobId = "harness",
		CreatorId = 1,
		CreatorType = roblox.Enum.CreatorType.User,
	}
	function game.GetService(_self, name: string)
		if table.find(roots, name) then
			return world.tree:FindFirstChild(name)
		end
		local fake = world.fakeServices[name]
		if fake then
			return fake
		end
		error(`harness: service '{name}' is not mocked. Add it in tests/harness/World.luau`, 2)
	end
	function game.FindFirstChild(_self, name: string)
		return world.tree:FindFirstChild(name)
	end
	function game.IsLoaded()
		return world.gameLoaded
	end
	return setmetatable(game, {
		__rbxtype = "Instance",
		__index = function(_t, key)
			return world.tree:FindFirstChild(key)
		end,
	})
end

function World._installPacketStub(self)
	local world = self
	local ctor = {}
	local packetMethods = {}
	packetMethods.__index = packetMethods

	function packetMethods.Response(packet)
		return packet
	end
	function packetMethods.RateLimit(packet)
		return packet
	end
	function packetMethods.FireClient(packet, player: any, ...)
		table.insert(world.fired, { Packet = packet.Name, Target = player, Args = table.pack(...) })
	end
	function packetMethods.FireAllClients(packet, ...)
		table.insert(world.fired, { Packet = packet.Name, Target = "All", Args = table.pack(...) })
	end
	function packetMethods.FireClients(packet, targets: { any }, ...)
		for _, player in targets do
			table.insert(world.fired, { Packet = packet.Name, Target = player, Args = table.pack(...) })
		end
	end

	setmetatable(ctor, {
		__index = function(_t, key)
			return key
		end,
		__call = function(_t, name: string)
			local Signal = world:require("ReplicatedStorage.Packages.Signal")
			return setmetatable({
				Name = name,
				OnServerEvent = Signal.new(),
				OnClientEvent = Signal.new(),
				OnServerInvoke = nil,
			}, packetMethods)
		end,
	})
	self.overrides[self.tree.ReplicatedStorage.Packet] = ctor
end

function World.node(self, path: string)
	return resolve(self.tree, path)
end

function World._environment(self, node: any)
	local env: { [string]: any } = {
		script = node,
		game = self.game,
		workspace = self.workspace,
		task = self.task,
		os = self.os,
		Random = self.Random,
		require = function(target: any)
			return self:requireNode(target)
		end,
		typeof = function(value: any)
			if type(value) == "table" then
				local meta = getmetatable(value)
				if type(meta) == "table" and rawget(meta, "__rbxtype") then
					return rawget(meta, "__rbxtype")
				end
				return "table"
			end
			return typeof(value)
		end,
		warn = function(...)
			table.insert(self.warnings, table.concat(table.pack(...) :: any, " ", 1, select("#", ...)))
		end,
		print = function(...)
			table.insert(self.logs, table.concat(table.pack(...) :: any, " ", 1, select("#", ...)))
		end,
		tick = function()
			return self.now
		end,
		time = function()
			return self.clock
		end,
		wait = function(t: number?)
			return self.task.wait(t)
		end,
		spawn = function(f: any, ...)
			return self.task.spawn(f, ...)
		end,
		delay = function(t: number, f: any, ...)
			return self.task.delay(t, f, ...)
		end,
		Content = {
			fromUri = function(uri: string)
				return uri
			end,
		},
		shared = {},
		_G = {},
		Instance = {
			new = function(className: string)
				return self:newInstance(className)
			end,
		},
	}
	env.TweenInfo = {
		new = function(...)
			return table.pack(...)
		end,
	}
	env.unpack = table.unpack
	env.assert = assert
	env.error = error
	env.pcall = pcall
	env.xpcall = xpcall
	env.select = select
	env.tostring = tostring
	env.tonumber = tonumber
	env.type = type
	env.pairs = pairs
	env.ipairs = ipairs
	env.next = next
	env.rawget = rawget
	env.rawset = rawset
	env.rawequal = rawequal
	env.rawlen = rawlen
	env.setmetatable = setmetatable
	env.getmetatable = getmetatable
	env.math = math
	env.string = string
	env.table = table
	env.bit32 = bit32
	env.buffer = buffer
	env.coroutine = coroutine
	env.debug = debug
	env.newproxy = newproxy
	for _, name in {
		"Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "NumberRange", "NumberSequence",
		"NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "Rect", "Ray", "BrickColor",
		"Enum", "Font", "Region3", "Axes", "Faces", "PhysicalProperties",
	} do
		env[name] = (roblox :: any)[name]
	end
	return env
end

function World.requireNode(self, target: any)
	if not Tree.isNode(target) then
		error(`harness: require expects a ModuleScript node, got {typeof(target)}`, 3)
	end
	local override = self.overrides[target]
	if override ~= nil then
		return override
	end
	local cached = self.cache[target]
	if cached ~= nil then
		return cached.value
	end
	local file = Tree.fileOf(target)
	if not file then
		error(`harness: {Tree.pathOf(target)} has no file to load`, 3)
	end
	local bytecode = bytecodeCache[file]
	if not bytecode then
		bytecode = luau.compile(fs.readFile(file), { optimizationLevel = 1, debugLevel = 1 })
		bytecodeCache[file] = bytecode
	end
	local chunk = luau.load(bytecode, { debugName = file, environment = self:_environment(target) :: any, injectGlobals = false } :: any)
	local value = chunk()
	self.cache[target] = { value = value }
	return value
end

function World.require(self, path: string)
	return self:requireNode(resolve(self.tree, path))
end

function World.setTime(self, now: number)
	self.now = now
end

function World.newPlayer(self, info: { UserId: number?, Name: string?, DisplayName: string? }?)
	local i = (info or {}) :: any
	self._playerCount = (self._playerCount or 0) + 1
	local id = i.UserId or (1000 + self._playerCount)
	local name = i.Name or `Player{id}`
	local player = setmetatable({
		UserId = id,
		Name = name,
		DisplayName = i.DisplayName or name,
		Character = nil,
		Parent = self.Players,
		Kicked = nil,
		_attributes = {} :: { [string]: any },
		_children = {} :: { any },
	}, {
		__rbxtype = "Instance",
		__tostring = function()
			return name
		end,
	}) :: any
	player.Kick = function(p: any, reason: string?)
		p.Kicked = reason or ""
		table.insert(self._kicked, p)
	end
	local Signal = self:require("ReplicatedStorage.Packages.Signal")
	player.CharacterAdded = Signal.new()
	player.CharacterRemoving = Signal.new()
	player.Chatted = Signal.new()
	player.GetAttribute = function(p: any, attribute: string)
		return p._attributes[attribute]
	end
	local attributeSignals: { [string]: any } = {}
	player.AttributeChanged = Signal.new()
	player.GetAttributeChangedSignal = function(_p: any, attribute: string)
		local found = attributeSignals[attribute]
		if not found then
			found = Signal.new()
			attributeSignals[attribute] = found
		end
		return found
	end
	player.SetAttribute = function(p: any, attribute: string, value: any)
		if p._attributes[attribute] ~= value then
			p._attributes[attribute] = value
			local found = attributeSignals[attribute]
			if found then
				found:Fire()
			end
			p.AttributeChanged:Fire(attribute)
		end
	end
	player.FindFirstChild = function(p: any, childName: string)
		for _, child in p._children do
			if child.Name == childName then
				return child
			end
		end
		return nil
	end
	player.WaitForChild = function(p: any, childName: string)
		local child = p:FindFirstChild(childName)
		if not child then
			error(`harness: player has no child {childName}`, 2)
		end
		return child
	end
	player.IsInGroup = function(p: any, groupId: number)
		self.groupChecks += 1
		if self.groupFailures > 0 then
			self.groupFailures -= 1
			error("fake group lookup failure")
		end
		local groups = self.groupMembers[p.UserId]
		return groups ~= nil and groups[groupId] == true
	end
	player.IsA = function(_p: any, className: string)
		return className == "Player" or className == "Instance"
	end
	local backpack = self:newInstance("Backpack")
	backpack.Name = "Backpack"
	backpack.Parent = player
	table.insert(self.Players._list, player)
	self.Players.PlayerAdded:Fire(player)
	return player
end

function World.newInstance(self, className: string)
	local node = Tree.node(className, className)
	local Signal = self:require("ReplicatedStorage.Packages.Signal")
	if className == "Part" or className == "MeshPart" then
		node.Transparency = 0
	end
	if guiClasses[className] then
		node.AbsoluteSize = self.guiSize
		node.Rotation = 0
		node.Visible = true
		node.GetPropertyChangedSignal = function()
			return Signal.new()
		end
		node.InputBegan = Signal.new()
		node.InputChanged = Signal.new()
		node.InputEnded = Signal.new()
		if className == "TextButton" or className == "TextLabel" then
			node.Text = ""
		end
		if className == "TextButton" then
			node.MouseButton1Down = Signal.new()
			node.MouseButton1Up = Signal.new()
			node.MouseEnter = Signal.new()
			node.MouseLeave = Signal.new()
			node.Activated = Signal.new()
		end
		if className == "UIScale" then
			node.Scale = 1
		end
	end
	if className == "Camera" then
		node.FieldOfView = 70
		node.CFrame = roblox.CFrame.new()
		node.ViewportSize = self.guiSize
		node.WorldToViewportPoint = function(camera: any, point: any)
			local relative = camera.CFrame:PointToObjectSpace(point)
			local depth = -relative.Z
			local size = camera.ViewportSize
			local halfHeight = math.tan(math.rad(camera.FieldOfView) / 2) * math.max(depth, 1e-6)
			local x = relative.X / (halfHeight * size.X / size.Y)
			local y = relative.Y / halfHeight
			local onScreen = depth > 0 and math.abs(x) <= 1 and math.abs(y) <= 1
			return roblox.Vector3.new((x + 1) / 2 * size.X, (1 - y) / 2 * size.Y, depth), onScreen
		end
	end
	if className == "Sound" then
		node.Plays = 0
		node.Play = function(sound: any)
			sound.Plays += 1
		end
		node.Stop = function() end
		node.Pauses = 0
		node.Resumes = 0
		node.Pause = function(sound: any)
			sound.Pauses += 1
		end
		node.Resume = function(sound: any)
			sound.Resumes += 1
		end
		node.TimeLength = 0
		node.TimePosition = 0
		node.IsLoaded = false
		node.Volume = 1
		node.SoundId = ""
		node.Looped = false
	end
	if className == "ProximityPrompt" then
		node.Triggered = Signal.new()
		node.PromptButtonHoldBegan = Signal.new()
		node.PromptButtonHoldEnded = Signal.new()
	elseif className == "Humanoid" then
		node.Died = Signal.new()
		node.WalkSpeed = 16
		node.Health = 100
		node.EquipTool = function(humanoid: any, tool: any)
			tool.Parent = humanoid.Parent
		end
	end
	return node
end

function World.newPart(self, name: string, x: number, y: number, z: number)
	local part = self:newInstance("Part")
	part.Name = name
	part.CFrame = CFrame.new(x, y, z)
	return part
end

function World.spawnCharacter(self, player: any, x: number, y: number, z: number)
	local character = self:newInstance("Model")
	character.Name = player.Name
	local root = self:newPart("HumanoidRootPart", x, y, z)
	root.Parent = character
	local humanoid = self:newInstance("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.Parent = character
	player.Character = character
	player.CharacterAdded:Fire(character)
	return character
end

function World.moveCharacter(_self, player: any, x: number, y: number, z: number)
	player.Character.HumanoidRootPart.CFrame = CFrame.new(x, y, z)
end

function World.killCharacter(_self, player: any)
	player.Character.Humanoid.Health = 0
	player.Character.Humanoid.Died:Fire()
end

function World.resetCharacter(_self, player: any)
	local character = player.Character
	player.CharacterRemoving:Fire(character)
	player.Character = nil
end

function World.walkSpeed(_self, player: any): number
	return player.Character.Humanoid.WalkSpeed
end

function World.removePlayer(self, player: any)
	self.Players.PlayerRemoving:Fire(player)
	local index = table.find(self.Players._list, player)
	if index then
		table.remove(self.Players._list, index)
	end
	player.Parent = nil
	self.Data:Release(player)
end

function World.join(self, info: any?, overrides: any?, fireLoaded: boolean?)
	local player = self:newPlayer(info)
	local data = self.Data:Load(player, overrides, fireLoaded)
	return player, data
end

function World.joinAtBase(self, info: any?, overrides: any?, fireLoaded: boolean?)
	local player, data = self:join(info, overrides, fireLoaded)
	self:placeAtBase(player)
	return player, data
end

function World.placeAtBase(self, player: any)
	local character = self:newInstance("Model")
	character.Name = player.Name
	self:newPart("HumanoidRootPart", 0, 3, 0).Parent = character
	player.Character = character
end

function World.boot(self, names: { string }, extra: { [string]: any }?)
	local registry = self.registry
	for name, fake in self.fakeRegistry do
		registry[name] = fake
	end
	for name, override in extra or {} do
		registry[name] = override
	end
	local order = {}
	local ordered = names
	local needsMeshes = table.find(names, "PlotService") or table.find(names, "CosmeticService")
	if needsMeshes and not table.find(names, "MeshService") then
		ordered = table.clone(names)
		table.insert(ordered, 1, "MeshService")
	end
	for _, name in ordered do
		if registry[name] == nil then
			local module = self:require(`ServerScriptService.Services.{name}`)
			registry[name] = module
		end
		table.insert(order, registry[name])
	end
	for _, service in order do
		if service.Init then
			service:Init(registry)
		end
	end
	for _, service in order do
		if service.Start then
			service:Start()
		end
		table.insert(self.started, service)
	end
	return registry
end

function World.destroy(self)
	for index = #self.started, 1, -1 do
		local service = self.started[index]
		if service.Destroy then
			pcall(service.Destroy, service)
		end
	end
	table.clear(self.started)
end

function World.packets(self)
	return self:require("ReplicatedStorage.Packets")
end

function World.invoke(self, name: string, player: any, ...)
	local packet = self:packets()[name]
	if not packet then
		error(`harness: no packet '{name}'`, 2)
	end
	if packet.OnServerInvoke then
		return packet.OnServerInvoke(player, ...)
	end
	packet.OnServerEvent:Fire(player, ...)
	return nil
end

function World.firedOf(self, name: string)
	local out = {}
	for _, entry in self.fired do
		if entry.Packet == name then
			table.insert(out, entry)
		end
	end
	return out
end

function World.clearFired(self)
	table.clear(self.fired)
end

return World

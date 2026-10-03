local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local CFrame = roblox.CFrame

local Random = require("./Random")
local Tree = require("./Tree")

local World = {}
World.__index = World

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

	services.DataStoreService = {
		GetDataStore = function()
			return {
				GetAsync = function() end,
				SetAsync = function() end,
				UpdateAsync = function() end,
				RemoveAsync = function() end,
			}
		end,
	}
	services.TextChatService = {}
	services.ServerStorage = Tree.node("ServerStorage", "ServerStorage")
	services.TweenService = {
		Create = function()
			return { Play = function() end, Cancel = function() end }
		end,
	}
	return services
end

function World.new(
	options: { Seed: number?, Time: number?, Clock: number?, PrintErrors: boolean?, AssetIds: { [string]: number }? }?
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
		cache = {} :: { [any]: any },
		overrides = {} :: { [any]: any },
		fired = {} :: { { Packet: string, Target: any, Args: { any } } },
		started = {} :: { any },
		registry = {} :: { [string]: any },
		saves = {} :: { [any]: number },
		prompts = {} :: { { Kind: string, Player: any, Id: number } },
		ownedPasses = {} :: { [number]: { [number]: boolean } },
		passCheckFailures = 0,
		_kicked = {} :: { any },
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
		return true
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
		shared = {},
		_G = {},
		Instance = {
			new = function(className: string)
				return self:newInstance(className)
			end,
		},
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
	player.GetAttribute = function(p: any, attribute: string)
		return p._attributes[attribute]
	end
	player.SetAttribute = function(p: any, attribute: string, value: any)
		p._attributes[attribute] = value
	end
	player.IsA = function(_p: any, className: string)
		return className == "Player" or className == "Instance"
	end
	table.insert(self.Players._list, player)
	self.Players.PlayerAdded:Fire(player)
	return player
end

function World.newInstance(self, className: string)
	local node = Tree.node(className, className)
	local Signal = self:require("ReplicatedStorage.Packages.Signal")
	if className == "ProximityPrompt" then
		node.Triggered = Signal.new()
		node.PromptButtonHoldBegan = Signal.new()
		node.PromptButtonHoldEnded = Signal.new()
	elseif className == "Humanoid" then
		node.Died = Signal.new()
		node.WalkSpeed = 16
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

function World.boot(self, names: { string }, extra: { [string]: any }?)
	local registry = self.registry
	for name, fake in self.fakeRegistry do
		registry[name] = fake
	end
	for name, override in extra or {} do
		registry[name] = override
	end
	local order = {}
	for _, name in names do
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

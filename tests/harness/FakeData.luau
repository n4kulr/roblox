local FakeData = {}
FakeData.__index = FakeData

local function walk(root: any, path: { any }, upTo: number)
	local node = root
	for index = 1, upTo do
		node = node[path[index]]
		if type(node) ~= "table" then
			error(`FakeReplica: path breaks at {tostring(path[index])}`, 3)
		end
	end
	return node
end

local function newReplica(data: any)
	local replica: any = { Data = data, Log = {} }
	function replica.Set(self, path: { any }, value: any)
		table.insert(self.Log, { Op = "Set", Path = path, Value = value })
		if #path == 0 then
			error("FakeReplica: cannot Set the root", 2)
		end
		walk(data, path, #path - 1)[path[#path]] = value
	end
	function replica.SetValues(self, path: { any }, values: { [any]: any })
		table.insert(self.Log, { Op = "SetValues", Path = path, Value = values })
		local target = walk(data, path, #path)
		for key, value in values do
			target[key] = value
		end
	end
	function replica.TableInsert(self, path: { any }, value: any, index: number?)
		table.insert(self.Log, { Op = "TableInsert", Path = path, Value = value })
		local target = walk(data, path, #path)
		if index then
			table.insert(target, index, value)
		else
			table.insert(target, value)
		end
	end
	function replica.TableRemove(self, path: { any }, index: number)
		table.insert(self.Log, { Op = "TableRemove", Path = path, Value = index })
		return table.remove(walk(data, path, #path), index)
	end
	function replica.Subscribe() end
	return replica
end

function FakeData.new(world: any)
	local Signal = world:require("ReplicatedStorage.Packages.Signal")
	local GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
	local self = setmetatable({ _world = world, _data = {}, _replicas = {} }, FakeData)
	local service: any = {
		Name = "DataService",
		PlayerLoaded = Signal.new(),
		PlayerReleasing = Signal.new(),
	}
	function service.GetData(_self, player: any)
		return self._data[player]
	end
	function service.GetReplica(_self, player: any)
		return if self._data[player] then self._replicas[player] else nil
	end
	function service.Set(_self, player: any, path: { any }, value: any)
		local replica = self._replicas[player]
		if not self._data[player] or not replica then
			return false
		end
		if type(value) ~= "table" then
			local parent: any = replica.Data
			for index = 1, #path - 1 do
				parent = if type(parent) == "table" then parent[path[index]] else nil
			end
			if type(parent) == "table" and parent[path[#path]] == value then
				return true
			end
		end
		replica:Set(path, value)
		return true
	end
	function service.AdjustCash(_self, player: any, amount: number)
		if amount ~= amount or math.abs(amount) == math.huge or amount % 1 ~= 0 then
			return false
		end
		local data = self._data[player]
		if not data then
			return false
		end
		local nextBalance = data.Cash + amount
		if nextBalance < 0 or nextBalance > GameConfig.MaxCash then
			return false
		end
		service:Set(player, { "Cash" }, nextBalance)
		return service:RequestSave(player)
	end
	function service.RequestSave(_self, player: any)
		if not self._data[player] then
			return false
		end
		world.saves[player] = (world.saves[player] or 0) + 1
		return true
	end
	function service.WaitForSave(_self, player: any, _saved: (any) -> boolean)
		return self._data[player] ~= nil
	end
	self.Service = service
	return self
end

function FakeData.Load(self, player: any, overrides: any?, fireLoaded: boolean?)
	local World = require("./World")
	local template = self._world:require("ServerScriptService.Data.PlayerData").Template
	local data = World.deepCopy(template)
	if overrides then
		World.deepMerge(data, overrides)
	end
	self._data[player] = data
	self._replicas[player] = newReplica(data)
	if fireLoaded ~= false then
		self.Service.PlayerLoaded:Fire(player, data)
	end
	return data
end

function FakeData.Release(self, player: any)
	local data = self._data[player]
	if data then
		self.Service.PlayerReleasing:Fire(player, data)
	end
	self._data[player] = nil
	self._replicas[player] = nil
end

function FakeData.Replica(self, player: any)
	return self._replicas[player]
end

return FakeData

local Random = {}
Random.__index = Random

local twoTo32 = 4294967296
local autoSeed = 1

local function rotl(x: number, k: number): number
	return bit32.bor(bit32.lshift(x, k), bit32.rshift(x, 32 - k))
end

local function seedState(seed: number)
	local s = (math.floor(seed) % twoTo32)
	local out = {}
	for i = 1, 4 do
		s = (s * 1664525 + 1013904223) % twoTo32
		out[i] = s
	end
	if out[1] == 0 and out[2] == 0 and out[3] == 0 and out[4] == 0 then
		out[1] = 1
	end
	return out
end

function Random.new(seed: number?)
	if seed == nil then
		autoSeed += 1
		seed = autoSeed * 7919
	end
	return setmetatable({ _s = seedState(seed :: number) }, Random)
end

function Random._next32(self): number
	local s = self._s
	local result = bit32.band(rotl(bit32.band(s[2] * 5, 0xFFFFFFFF), 7) * 9, 0xFFFFFFFF)
	local t = bit32.lshift(s[2], 9)
	s[3] = bit32.bxor(s[3], s[1])
	s[4] = bit32.bxor(s[4], s[2])
	s[2] = bit32.bxor(s[2], s[3])
	s[1] = bit32.bxor(s[1], s[4])
	s[3] = bit32.bxor(s[3], t)
	s[4] = rotl(s[4], 11)
	return result
end

function Random.NextNumber(self, min: number?, max: number?): number
	local r = (self:_next32() * 2097152 + bit32.rshift(self:_next32(), 11)) / 9007199254740992
	if min and max then
		return min + r * (max - min)
	end
	return r
end

function Random.NextInteger(self, min: number, max: number): number
	return min + math.floor(self:NextNumber() * (max - min + 1))
end

function Random.Clone(self)
	return setmetatable({ _s = table.clone(self._s) }, Random)
end

return Random

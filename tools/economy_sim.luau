--!strict

local fs = require("@lune/fs")
local process = require("@lune/process")

local H = require("../tests/harness/Harness")

local world = H.newWorld()
local GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
local Keys = world:require("ReplicatedStorage.Config.Keys")
local Upgrades = world:require("ReplicatedStorage.Config.Upgrades")
local Rebirth = world:require("ReplicatedStorage.Rules.Rebirth")
local Stats = world:require("ReplicatedStorage.Rules.Stats")
local Roll = world:require("ServerScriptService.Services.RollService.Roll")

local seedCount = tonumber(process.args[1]) or 50
local horizonHours = tonumber(process.args[2]) or 48
local outputPath = process.args[3]
local horizon = horizonHours * 3600
local checkSeconds = 3
local bucketSeconds = 300
local detailedSeconds = 7200
local milestoneRarities = { "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
local tracked = { "Luck", "Speed", "Slots", "Income", "Golden" }
local rebirthLimit = 8
local paybackSlack = 8
local valueWeights: { [string]: number } = { Luck = 0.7, Speed = 0.6, Slots = 1, Income = 1, Golden = 0.5 }

type Purchase = { Time: number, Id: string, Level: number, Rebirths: number }

type Result = {
	Seed: number,
	First: { [string]: number },
	Second: { [string]: number },
	FirstUpgrade: number?,
	Rebirths: { number },
	Purchases: { Purchase },
	Rates: { { Time: number, Rate: number, Rebirths: number } },
	Maxed: { { Rebirths: number, Id: string, Time: number } },
	Rolls: number,
}

local rng = {
	NextNumber = function(_self: any): number
		return math.random()
	end,
	NextInteger = function(_self: any, low: number, high: number): number
		return math.random(low, high)
	end,
}

local hookSeconds = 2400
local sampleTimes: { number } = { 0, 30, 5400, 7200 }
for minute = 1, 45 do
	table.insert(sampleTimes, minute * 60)
end
for minute = 50, 60, 10 do
	table.insert(sampleTimes, minute * 60)
end
for hours = 3, horizonHours do
	table.insert(sampleTimes, hours * 3600)
end
table.sort(sampleTimes)

local function simulate(seed: number): Result
	math.randomseed(seed)
	local levels: { [string]: number } =
		{ Luck = 0, Speed = 0, Slots = 0, Income = 0, Walls = 0, LockTime = 0, Golden = 0 }
	local board: { string } = {}
	local inventory: { [string]: number } = {}
	local cash = 0
	local rebirths = 0
	local rolls = 0
	local goldenProgress = 0
	local rollAccumulator = 0
	local stats = Stats.Compute(board, levels, { Income = Rebirth.IncomeMultiplier(0) })
	local boardMinIncome = 0
	local boardCount = 0
	local dirty = false
	local result: Result = {
		Seed = seed,
		First = {},
		Second = {},
		FirstUpgrade = nil,
		Rebirths = {},
		Purchases = {},
		Rates = {},
		Maxed = {},
		Rolls = 0,
	}
	local nextSample = 1
	local maxedSeen: { [string]: boolean } = {}

	local function recompute()
		stats = Stats.Compute(board, levels, { Income = Rebirth.IncomeMultiplier(rebirths) })
	end

	local function equipBest()
		local slots = Stats.Slots(levels)
		local counts: { [string]: number } = {}
		for index = 1, GameConfig.BoardSlots do
			local keyId = board[index]
			if keyId and keyId ~= "" then
				counts[keyId] = (counts[keyId] or 0) + 1
			end
		end
		for keyId, count in inventory do
			counts[keyId] = (counts[keyId] or 0) + count
		end
		local ranked: { string } = {}
		local incomePerks: { string } = {}
		for keyId in counts do
			local perk = Keys.ById[keyId].Perk
			if perk and perk.Kind == "Income" then
				table.insert(incomePerks, keyId)
			else
				table.insert(ranked, keyId)
			end
		end
		table.sort(ranked, function(a: string, b: string): boolean
			local incomeA, incomeB = Keys.GetIncome(a), Keys.GetIncome(b)
			if incomeA ~= incomeB then
				return incomeA > incomeB
			end
			local hasPerkA, hasPerkB = Keys.ById[a].Perk ~= nil, Keys.ById[b].Perk ~= nil
			if hasPerkA ~= hasPerkB then
				return hasPerkA
			end
			return Keys.ById[a].Index < Keys.ById[b].Index
		end)
		table.sort(incomePerks, function(a: string, b: string): boolean
			return Keys.GetIncome(a) > Keys.GetIncome(b)
		end)
		local perkTotal = 0
		for _, keyId in incomePerks do
			perkTotal += counts[keyId]
		end
		local function layout(perkCount: number): { string }
			local layoutBoard: { string } = {}
			local slot = 1
			local remainingPerks = perkCount
			for _, keyId in incomePerks do
				local take = math.min(remainingPerks, counts[keyId])
				for _ = 1, math.min(take, slots - slot + 1) do
					layoutBoard[slot] = keyId
					slot += 1
				end
				remainingPerks -= take
			end
			for _, keyId in ranked do
				for _ = 1, math.min(counts[keyId], slots - slot + 1) do
					layoutBoard[slot] = keyId
					slot += 1
				end
			end
			return layoutBoard
		end
		local placed = layout(0)
		if perkTotal > 0 then
			local multiplier = Rebirth.IncomeMultiplier(rebirths)
			local function rateOf(perkCount: number): number
				return Stats.Compute(layout(perkCount), levels, { Income = multiplier }).Rate
			end
			local low, high = 0, math.min(perkTotal, slots)
			while high - low > 2 do
				local third = (high - low) // 3
				local left, right = low + third, high - third
				if rateOf(left) < rateOf(right) then
					low = left
				else
					high = right
				end
			end
			local bestRate = rateOf(0)
			local bestCount = 0
			for perkCount = low, high do
				local rate = rateOf(perkCount)
				if rate > bestRate then
					bestRate, bestCount = rate, perkCount
				end
			end
			placed = layout(bestCount)
		end
		local used: { [string]: number } = {}
		for index = 1, #placed do
			used[placed[index]] = (used[placed[index]] or 0) + 1
		end
		for keyId, count in used do
			counts[keyId] -= count
		end
		local slot = #placed + 1
		board = placed
		inventory = {}
		for keyId, count in counts do
			if count > 0 then
				inventory[keyId] = count
			end
		end
		boardCount = slot - 1
		boardMinIncome = if boardCount < slots then 0 else math.huge
		for index = 1, boardCount do
			boardMinIncome = math.min(boardMinIncome, Keys.GetIncome(placed[index]))
		end
		dirty = false
		recompute()
	end

	local function rawIncome(): number
		local total = 0
		for index = 1, boardCount do
			total += Keys.GetIncome(board[index])
		end
		return total
	end

	local function valueOf(id: string): number
		local upgrade = Upgrades.ById[id]
		local level = levels[id]
		if id == "Income" then
			return upgrade.PerLevel / (1 + level * upgrade.PerLevel)
		elseif id == "Luck" then
			return upgrade.PerLevel / (GameConfig.Luck + level * upgrade.PerLevel)
		elseif id == "Speed" then
			return upgrade.PerLevel / stats.RollsPerSecond
		elseif id == "Golden" then
			local every = Stats.GoldenEvery(levels)
			local after = math.max(1, every - upgrade.PerLevel)
			local luckNow = 1 + (GameConfig.GoldenRollLuck - 1) / every
			local luckAfter = 1 + (GameConfig.GoldenRollLuck - 1) / after
			return luckAfter / luckNow - 1
		elseif id == "Slots" then
			local slots = Stats.Slots(levels)
			if slots >= GameConfig.BoardSlots then
				return 0
			end
			local incomes: { number } = {}
			for keyId, count in inventory do
				for _ = 1, math.min(count, upgrade.PerLevel) do
					table.insert(incomes, Keys.GetIncome(keyId))
				end
			end
			table.sort(incomes, function(a: number, b: number): boolean
				return a > b
			end)
			local gain = 0
			for index = 1, math.min(upgrade.PerLevel, #incomes) do
				gain += incomes[index]
			end
			local base = math.max(1, rawIncome())
			return math.max(gain / base, 0.5 * upgrade.PerLevel / slots)
		end
		return 0
	end

	local clock = 0

	local function buyBest(): boolean
		local bestId: string? = nil
		local bestRatio = 0
		local bestCost = 0
		local remaining = math.max(0, Rebirth.Cost(rebirths) - cash) / math.max(1, stats.Rate)
		for _, id in tracked do
			local upgrade = Upgrades.ById[id]
			local cost = Upgrades.Cost(upgrade, levels[id])
			if cost then
				if cash >= cost then
					local gain = valueOf(id) * valueWeights[id]
					local ratio = gain / cost
					local payback = cost / math.max(1e-9, gain * stats.Rate)
					if ratio > bestRatio and payback <= remaining * paybackSlack then
						bestRatio, bestId, bestCost = ratio, id, cost
					end
				end
			elseif not maxedSeen[`{rebirths}:{id}`] then
				maxedSeen[`{rebirths}:{id}`] = true
				table.insert(result.Maxed, { Rebirths = rebirths, Id = id, Time = clock })
			end
		end
		if not bestId then
			return false
		end
		cash -= bestCost
		levels[bestId] += 1
		table.insert(
			result.Purchases,
			{ Time = clock, Id = bestId, Level = levels[bestId], Rebirths = rebirths }
		)
		if not result.FirstUpgrade then
			result.FirstUpgrade = clock
		end
		if bestId == "Slots" then
			equipBest()
		else
			recompute()
		end
		return true
	end

	local function doRoll()
		rolls += 1
		local isGuaranteed = rolls == GameConfig.GuaranteedRareRoll
		goldenProgress += 1
		local isGolden = not isGuaranteed and goldenProgress >= Stats.GoldenEvery(levels)
		local key = if isGuaranteed
			then Roll.PickInRarity(rng :: any, "Rare")
			else Roll.Pick(
				rng :: any,
				if isGolden then stats.Luck * GameConfig.GoldenRollLuck else stats.Luck
			)
		if isGolden then
			goldenProgress = 0
		end
		if result.First[key.Rarity] == nil then
			result.First[key.Rarity] = clock
		elseif result.Second[key.Rarity] == nil then
			result.Second[key.Rarity] = clock
		end
		inventory[key.Id] = (inventory[key.Id] or 0) + 1
		local perk = key.Perk
		if
			boardCount < Stats.Slots(levels)
			or Keys.GetIncome(key.Id) >= boardMinIncome
			or (perk ~= nil and perk.Kind == "Income")
		then
			dirty = true
		end
	end

	equipBest()
	while clock < horizon do
		clock += 1
		cash += stats.Rate
		rollAccumulator += stats.RollsPerSecond
		while rollAccumulator >= 1 do
			rollAccumulator -= 1
			doRoll()
		end
		if dirty then
			equipBest()
		end
		while nextSample <= #sampleTimes and clock >= sampleTimes[nextSample] do
			table.insert(
				result.Rates,
				{ Time = sampleTimes[nextSample], Rate = stats.Rate, Rebirths = rebirths }
			)
			nextSample += 1
		end
		if clock % checkSeconds == 0 then
			if cash >= Rebirth.Cost(rebirths) then
				table.insert(result.Rebirths, clock)
				rebirths += 1
				cash = 0
				for id in levels do
					levels[id] = 0
				end
				for index = 1, GameConfig.BoardSlots do
					local keyId = board[index]
					if keyId and keyId ~= "" then
						inventory[keyId] = (inventory[keyId] or 0) + 1
					end
				end
				board = {}
				equipBest()
			else
				while buyBest() do
				end
			end
		end
		if result.First.Secret and #result.Rebirths >= rebirthLimit then
			break
		end
		if clock > 36 * 3600 and result.First.Secret then
			break
		end
	end
	result.Rolls = rolls
	return result
end

local function formatTime(seconds: number?): string
	if seconds == nil then
		return "never"
	end
	local total = math.floor(seconds)
	return string.format("%d:%02d:%02d", total // 3600, (total % 3600) // 60, total % 60)
end

local function percentile(values: { number }, fraction: number): number?
	if #values == 0 then
		return nil
	end
	local sorted = table.clone(values)
	table.sort(sorted)
	local index = math.clamp(math.ceil(#sorted * fraction), 1, #sorted)
	local value = sorted[index]
	if value == math.huge then
		return nil
	end
	return value
end

local lines: { string } = {}
local function emit(text: string)
	table.insert(lines, text)
end

local results: { Result } = {}
local startedAt = os.clock()
for seed = 1, seedCount do
	table.insert(results, simulate(seed))
end

local typicalMarks: { (Result) -> number? } = {
	function(result: Result)
		return result.First.Epic
	end,
	function(result: Result)
		return result.First.Legendary
	end,
	function(result: Result)
		return result.Second.Legendary
	end,
	function(result: Result)
		return result.Rebirths[1]
	end,
}
local markMedians: { number } = {}
for index, mark in typicalMarks do
	local values: { number } = {}
	for _, result in results do
		table.insert(values, mark(result) or math.huge)
	end
	markMedians[index] = percentile(values, 0.5) or horizon
end

local function distanceToTypical(result: Result): number
	local total = 0
	for index, mark in typicalMarks do
		total += math.abs(math.log((mark(result) or horizon) / markMedians[index]))
	end
	return total
end

local median = results[1]
for _, result in results do
	if distanceToTypical(result) < distanceToTypical(median) then
		median = result
	end
end

emit("## Configuration")
emit("")
emit("| Rarity | 1 in | Income/s |")
emit("| --- | ---: | ---: |")
for _, rarity in Keys.Rarities do
	emit(`| {rarity.Name} | {rarity.Chance} | {rarity.Income} |`)
end
emit("")
emit(
	`Rebirth cost {Rebirth.Cost(0)} x{GameConfig.Rebirth.CostGrowth} per rebirth, +{GameConfig.Rebirth.IncomePerRebirth} income multiplier per rebirth. Base slots {GameConfig.BaseSlots}, rolls/s {GameConfig.RollsPerSecond}, golden roll every {GameConfig.GoldenRollEvery}.`
)
emit("")
emit("| Upgrade | Base cost | Growth | Per level | Max level | Cost of last level |")
emit("| --- | ---: | ---: | ---: | ---: | ---: |")
for _, upgrade in Upgrades.List do
	emit(
		`| {upgrade.Id} | {upgrade.BaseCost} | {upgrade.Growth} | {upgrade.PerLevel} | {upgrade.MaxLevel} | {Upgrades.Cost(
			upgrade,
			upgrade.MaxLevel - 1
		)} |`
	)
end
emit("")

emit(`## Milestones ({seedCount} seeds, horizon {horizonHours} h)`)
emit("")
emit("| Milestone | Seed 1 | Median | p10 | p90 | Reached |")
emit("| --- | ---: | ---: | ---: | ---: | ---: |")
local function milestoneRow(label: string, pick: (Result) -> number?)
	local values: { number } = {}
	for _, result in results do
		table.insert(values, pick(result) or math.huge)
	end
	local reached = 0
	for _, value in values do
		if value ~= math.huge then
			reached += 1
		end
	end
	emit(
		`| {label} | {formatTime(pick(results[1]))} | {formatTime(percentile(values, 0.5))} | {formatTime(
			percentile(values, 0.1)
		)} | {formatTime(percentile(values, 0.9))} | {reached}/{#results} |`
	)
end
milestoneRow("First upgrade", function(result: Result)
	return result.FirstUpgrade
end)
for _, name in milestoneRarities do
	milestoneRow(`First {name}`, function(result: Result)
		return result.First[name]
	end)
end
milestoneRow("Second Legendary", function(result: Result)
	return result.Second.Legendary
end)
for index = 1, 5 do
	milestoneRow(`Rebirth {index}`, function(result: Result)
		return result.Rebirths[index]
	end)
end
emit("")
emit("| Rebirth | Duration (median) | Ratio to previous |")
emit("| --- | ---: | ---: |")
local previousMedian: number? = nil
for index = 1, 6 do
	local durations: { number } = {}
	for _, result in results do
		local ended = result.Rebirths[index]
		local began = if index == 1 then 0 else result.Rebirths[index - 1]
		table.insert(durations, if ended and began then ended - began else math.huge)
	end
	local value = percentile(durations, 0.5)
	local ratio = if value and previousMedian then string.format("%.2f", value / previousMedian) else "-"
	emit(`| {index} | {formatTime(value)} | {ratio} |`)
	previousMedian = value
end
emit("")

emit(
	`## Median seed timeline (seed {median.Seed}, closest to the median Epic, Legendary, second Legendary and rebirth 1)`
)
emit("")
emit("Purchases per 5 minutes for the first 2 hours, then per hour. R marks a rebirth.")
emit("")
emit("| Window | Luck | Speed | Slots | Income | Golden | Events |")
emit("| --- | ---: | ---: | ---: | ---: | ---: | --- |")
local function windowRow(from: number, to: number)
	local counts: { [string]: number } = {}
	for _, purchase in median.Purchases do
		if purchase.Time > from and purchase.Time <= to then
			counts[purchase.Id] = (counts[purchase.Id] or 0) + 1
		end
	end
	local events: { string } = {}
	for index, at in median.Rebirths do
		if at > from and at <= to then
			table.insert(events, `R{index}`)
		end
	end
	for _, name in milestoneRarities do
		local at = median.First[name]
		if at and at > from and at <= to then
			table.insert(events, name)
		end
	end
	local cells: { string } = {}
	for _, id in tracked do
		table.insert(cells, tostring(counts[id] or 0))
	end
	emit(
		`| {formatTime(from)}-{formatTime(to)} | {table.concat(cells, " | ")} | {table.concat(events, ", ")} |`
	)
end
local lastTime = math.min(horizon, median.Rebirths[#median.Rebirths] or 0, 3 * 3600)
local last = math.max(lastTime, 3600)
local from = 0
while from < math.min(detailedSeconds, math.max(last, 3600)) do
	windowRow(from, from + bucketSeconds)
	from += bucketSeconds
end
local endTime = 0
for _, rate in median.Rates do
	endTime = math.max(endTime, rate.Time)
end
endTime = math.min(endTime, 12 * 3600)
while from < endTime do
	windowRow(from, from + 3600)
	from += 3600
end
emit("")

emit("## Purchase cadence (median over seeds)")
emit("")
emit("| Window | Purchases | Average gap | Longest gap |")
emit("| --- | ---: | ---: | ---: |")
local cadenceWindows = { { 0, 600 }, { 600, 2400 }, { 2400, 3600 }, { 3600, 7200 } }
for _, window in cadenceWindows do
	local counts: { number } = {}
	local averages: { number } = {}
	local longests: { number } = {}
	for _, result in results do
		local count, previousTime, longest = 0, window[1], 0
		for _, purchase in result.Purchases do
			if purchase.Time > window[1] and purchase.Time <= window[2] and purchase.Rebirths == 0 then
				count += 1
				longest = math.max(longest, purchase.Time - previousTime)
				previousTime = purchase.Time
			end
		end
		table.insert(counts, count)
		table.insert(averages, (window[2] - window[1]) / math.max(1, count))
		table.insert(longests, longest)
	end
	local averageGap = percentile(averages, 0.5) or 0
	emit(
		`| {formatTime(window[1])}-{formatTime(window[2])} | {percentile(counts, 0.5)} | {string.format(
			"%.1f",
			averageGap
		)} s | {percentile(longests, 0.5)} s |`
	)
end
emit("")

emit("## First 40 minutes (median seed)")
emit("")
emit(
	"Per minute: purchases (Luck, Speed, Slots, Income, Golden), Clicks per second at the end of the minute and what was found."
)
emit("")
emit("| Minute | Buys | Luck | Speed | Slots | Income | Golden | Cash/s | Events |")
emit("| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |")
for minute = 1, hookSeconds // 60 do
	local from = (minute - 1) * 60
	local to = minute * 60
	local counts: { [string]: number } = {}
	local total = 0
	for _, purchase in median.Purchases do
		if purchase.Time > from and purchase.Time <= to then
			counts[purchase.Id] = (counts[purchase.Id] or 0) + 1
			total += 1
		end
	end
	local events: { string } = {}
	for _, name in milestoneRarities do
		local at = median.First[name]
		if at and at > from and at <= to then
			table.insert(events, `first {name}`)
		end
	end
	local secondLegendary = median.Second.Legendary
	if secondLegendary and secondLegendary > from and secondLegendary <= to then
		table.insert(events, "second Legendary")
	end
	for index, at in median.Rebirths do
		if at > from and at <= to then
			table.insert(events, `rebirth {index}`)
		end
	end
	local rate = 0
	for _, sample in median.Rates do
		if sample.Time <= to then
			rate = sample.Rate
		end
	end
	local cells: { string } = {}
	for _, id in tracked do
		table.insert(cells, tostring(counts[id] or 0))
	end
	emit(`| {minute} | {total} | {table.concat(cells, " | ")} | {rate} | {table.concat(events, ", ")} |`)
end
emit("")

emit("## Median seed cash per second")
emit("")
emit("| Time | Cash/s | Rebirths |")
emit("| --- | ---: | ---: |")
for _, sample in median.Rates do
	if sample.Time <= 12 * 3600 and (sample.Time % 300 == 0 or sample.Time == 30) then
		emit(`| {formatTime(sample.Time)} | {sample.Rate} | {sample.Rebirths} |`)
	end
end
emit("")

emit("## Upgrades maxed within a life (median seed)")
emit("")
if #median.Maxed == 0 then
	emit("None.")
else
	emit("| Rebirths so far | Upgrade | Time |")
	emit("| ---: | --- | ---: |")
	for _, entry in median.Maxed do
		emit(`| {entry.Rebirths} | {entry.Id} | {formatTime(entry.Time)} |`)
	end
end
emit("")
emit(`Simulated in {string.format("%.1f", os.clock() - startedAt)} s.`)

local text = table.concat(lines, "\n")
print(text)
if outputPath then
	fs.writeFile(outputPath, text)
end

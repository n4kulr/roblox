--!strict

export type Entry = {
	Id: string,
	Tier: number,
	Income: number,
	Rank: number,
	Name: string,
}

local Sort = {
	Modes = table.freeze({ "BEST", "RARITY", "AMOUNT", "NAME" }),
}

function Sort.Order(list: { Entry }, totals: { [string]: number }, mode: string)
	table.sort(list, function(a: Entry, b: Entry): boolean
		local incomeA, incomeB = a.Income, b.Income
		local rankA, rankB = a.Rank, b.Rank
		local nameA, nameB = a.Name, b.Name
		if mode == "NAME" then
			return nameA < nameB
		end
		if mode == "AMOUNT" and totals[a.Id] ~= totals[b.Id] then
			return (totals[a.Id] or 0) > (totals[b.Id] or 0)
		end
		if mode == "RARITY" and (rankA ~= rankB or a.Tier ~= b.Tier) then
			if rankA ~= rankB then
				return rankA > rankB
			end
			return a.Tier > b.Tier
		end
		if incomeA ~= incomeB then
			return incomeA > incomeB
		end
		if rankA ~= rankB then
			return rankA > rankB
		end
		return nameA < nameB
	end)
end

return Sort

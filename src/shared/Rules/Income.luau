--!strict

local Income = {}

function Income.PotionSeconds(from: number, to: number, clicksUntil: number): number
	if to <= from then
		return 0
	end
	return math.clamp(math.min(to, clicksUntil) - from, 0, to - from)
end

function Income.Earned(
	baseRate: number,
	from: number,
	to: number,
	clicksUntil: number,
	potionMultiplier: number
): number
	if to <= from or baseRate <= 0 then
		return 0
	end
	local boosted = Income.PotionSeconds(from, to, clicksUntil)
	local plain = (to - from) - boosted
	return math.floor(baseRate * (plain + boosted * potionMultiplier))
end

return Income

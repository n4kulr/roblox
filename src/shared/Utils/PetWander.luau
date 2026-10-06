--!strict

local EggPlacement = require(script.Parent.EggPlacement)

export type Walker = {
	X: number,
	Z: number,
	TargetX: number,
	TargetZ: number,
	Pause: number,
	Heading: number,
	Phase: number,
	IsMoving: boolean,
	HalfX: number,
	HalfZ: number,
	Avoid: EggPlacement.Rect?,
	_random: Random,
}

local PetWander = {
	Inset = 3,
	Speed = 4,
	PauseMin = 1,
	PauseMax = 3,
	HopHeight = 0.25,
	HopRate = 9,
}

local attempts = 16

function PetWander.PickPoint(
	random: Random,
	halfX: number,
	halfZ: number,
	avoid: EggPlacement.Rect?
): (number, number)
	local limitX = math.max(halfX - PetWander.Inset, 0)
	local limitZ = math.max(halfZ - PetWander.Inset, 0)
	for _ = 1, attempts do
		local x = random:NextNumber(-limitX, limitX)
		local z = random:NextNumber(-limitZ, limitZ)
		if not EggPlacement.IsBlocked(avoid, x, z) then
			return x, z
		end
	end
	return limitX, limitZ
end

function PetWander.New(seed: number, halfX: number, halfZ: number, avoid: EggPlacement.Rect?): Walker
	local random = Random.new(seed)
	local x, z = PetWander.PickPoint(random, halfX, halfZ, avoid)
	local targetX, targetZ = PetWander.PickPoint(random, halfX, halfZ, avoid)
	return {
		X = x,
		Z = z,
		TargetX = targetX,
		TargetZ = targetZ,
		Pause = random:NextNumber(0, PetWander.PauseMax),
		Heading = random:NextNumber(0, math.pi * 2),
		Phase = 0,
		IsMoving = false,
		HalfX = halfX,
		HalfZ = halfZ,
		Avoid = avoid,
		_random = random,
	}
end

function PetWander.Step(walker: Walker, dt: number)
	if walker.Pause > 0 then
		walker.Pause -= dt
		walker.IsMoving = false
		walker.Phase = 0
		if walker.Pause > 0 then
			return
		end
		dt = -walker.Pause
		walker.Pause = 0
	end
	local dx, dz = walker.TargetX - walker.X, walker.TargetZ - walker.Z
	local distance = math.sqrt(dx * dx + dz * dz)
	local travel = PetWander.Speed * dt
	if distance > 0.001 then
		walker.Heading = math.atan2(-dx, -dz)
	end
	if distance <= travel then
		walker.X, walker.Z = walker.TargetX, walker.TargetZ
		walker.IsMoving = false
		walker.Pause = walker._random:NextNumber(PetWander.PauseMin, PetWander.PauseMax)
		walker.TargetX, walker.TargetZ =
			PetWander.PickPoint(walker._random, walker.HalfX, walker.HalfZ, walker.Avoid)
		return
	end
	walker.X += dx / distance * travel
	walker.Z += dz / distance * travel
	walker.IsMoving = true
	walker.Phase += dt * PetWander.HopRate
end

function PetWander.Hop(walker: Walker): number
	return if walker.IsMoving then math.abs(math.sin(walker.Phase)) * PetWander.HopHeight else 0
end

return PetWander

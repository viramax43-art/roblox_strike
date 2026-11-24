--!nonstrict
-- Серверная баллистика. Здесь считаются реальные попадания:
-- клиент присылает только точку и направление, всё остальное решает сервер.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Settings = require(Shared.Config.Settings)
local Ballistics = require(Shared.Ballistics)
local DamageModel = require(Shared.DamageModel)
local SeededRandom = require(Shared.SeededRandom)

local HitboxHistory = require(script.Parent.HitboxHistory)

local ProjectileService = {}

local function createRaycastParams(shooter)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	local exclude = {}
	if shooter and shooter.Character then
		table.insert(exclude, shooter.Character)
	end
	params.FilterDescendantsInstances = exclude

	return params
end

local function applyHit(shooter, stats, trace)
	local hitPart = trace.Hit and trace.Hit.Instance
	if not hitPart then
		return nil
	end

	local humanoid = DamageModel.getHumanoid(hitPart)
	if not humanoid then
		return nil
	end

	local targetPlayer = DamageModel.getPlayerFromCharacter(humanoid.Parent)
	if targetPlayer == shooter then
		return nil
	end

	if
		targetPlayer
		and not Settings.FriendlyFire
		and shooter.Team
		and targetPlayer.Team
		and shooter.Team == targetPlayer.Team
	then
		return nil
	end

	local region = DamageModel.getRegion(hitPart)
	local damage = DamageModel.computeDamage(stats, region, trace.Distance)
	if damage <= 0 then
		return nil
	end

	if targetPlayer then
		humanoid:SetAttribute("LastAttackerUserId", shooter.UserId)
	end

	-- Урон приходит в момент, когда пуля долетела, а не в момент выстрела.
	task.delay(trace.Time, function()
		if humanoid.Parent and humanoid.Health > 0 then
			humanoid:TakeDamage(damage)
		end
	end)

	return {
		region = region,
		damage = damage,
		position = trace.End,
		distance = trace.Distance,
		targetUserId = targetPlayer and targetPlayer.UserId or nil,
	}
end

-- Один выстрел = 1..N снарядов (дробь). Возвращает трейсеры для визуала и попадания.
function ProjectileService.fire(params)
	local shooter = params.Shooter
	local stats = params.Stats
	local origin = params.Origin
	local direction = params.Direction.Unit
	local spread = params.Spread or 0
	local seed = params.Seed or 0
	local pellets = math.clamp(math.floor(stats.Pellets or 1), 1, Settings.AntiCheat.MaxPelletsPerShot)

	local raycastParams = createRaycastParams(shooter)
	local restore = HitboxHistory.beginRewind(shooter, params.RewindSeconds or 0)

	local rng = SeededRandom.new(seed)
	local tracers = {}
	local hits = {}
	local longest = 0

	for index = 1, pellets do
		local pelletDirection = Ballistics.spreadDirection(direction, spread, rng)
		local trace = Ballistics.trace({
			Origin = origin,
			Direction = pelletDirection,
			MuzzleVelocity = stats.MuzzleVelocity,
			GravityScale = stats.GravityScale,
			MaxRange = stats.MaxRange,
		}, function(from, target)
			return workspace:Raycast(from, target, raycastParams)
		end)

		longest = math.max(longest, trace.Time)

		table.insert(tracers, {
			type = "Tracer",
			primary = index == 1,
			origin = trace.Origin,
			direction = pelletDirection,
			speed = stats.MuzzleVelocity,
			gravityScale = stats.GravityScale,
			duration = trace.Time,
			endPosition = trace.End,
			impacted = trace.Impacted,
			normal = trace.Normal,
			color = stats.TracerColor,
			sound = stats.Sound,
		})

		local hit = applyHit(shooter, stats, trace)
		if hit then
			table.insert(hits, hit)
		end
	end

	restore()

	return {
		Tracers = tracers,
		Hits = hits,
		Duration = longest,
	}
end

return ProjectileService

--!nonstrict
-- Урон: зоны попадания, множители по частям тела, падение урона с дистанцией.

local DamageModel = {}

local PART_REGIONS = {
	-- R15
	Head = "Head",
	UpperTorso = "Torso",
	LowerTorso = "Torso",
	LeftUpperArm = "Arms",
	LeftLowerArm = "Arms",
	LeftHand = "Arms",
	RightUpperArm = "Arms",
	RightLowerArm = "Arms",
	RightHand = "Arms",
	LeftUpperLeg = "Legs",
	LeftLowerLeg = "Legs",
	LeftFoot = "Legs",
	RightUpperLeg = "Legs",
	RightLowerLeg = "Legs",
	RightFoot = "Legs",
	-- R6
	["Left Arm"] = "Arms",
	["Right Arm"] = "Arms",
	["Left Leg"] = "Legs",
	["Right Leg"] = "Legs",
	HumanoidRootPart = "Torso",
}

local PREFIX_REGIONS = {
	{ "Head", "Head" },
	{ "Torso", "Torso" },
	{ "Arm", "Arms" },
	{ "Hand", "Arms" },
	{ "Leg", "Legs" },
	{ "Foot", "Legs" },
}

function DamageModel.getRegion(part)
	if not part then
		return "Torso"
	end

	local name = part.Name
	local direct = PART_REGIONS[name]
	if direct then
		return direct
	end

	for _, entry in ipairs(PREFIX_REGIONS) do
		if string.find(name, entry[1], 1, true) then
			return entry[2]
		end
	end

	return "Torso"
end

-- Линейное падение урона от Min до Max дистанции.
function DamageModel.getFalloffMultiplier(distance, falloff)
	if not falloff then
		return 1
	end

	local minDistance = falloff.Min or 0
	local maxDistance = falloff.Max or math.huge
	local minMultiplier = falloff.MinMultiplier or 1

	if distance <= minDistance then
		return 1
	end
	if distance >= maxDistance then
		return minMultiplier
	end

	local alpha = (distance - minDistance) / math.max(maxDistance - minDistance, 1e-6)
	return 1 + (minMultiplier - 1) * alpha
end

function DamageModel.computeDamage(stats, region, distance)
	local multiplier = 1
	if stats.BodyMultipliers and stats.BodyMultipliers[region] then
		multiplier = stats.BodyMultipliers[region]
	end

	local falloff = DamageModel.getFalloffMultiplier(distance, stats.Falloff)
	return stats.Damage * multiplier * falloff
end

-- Humanoid по любой части персонажа/манекена.
function DamageModel.getHumanoid(instance)
	if not instance then
		return nil
	end

	local current = instance
	while current and current ~= workspace do
		if current:IsA("Model") then
			local humanoid = current:FindFirstChildOfClass("Humanoid")
			if humanoid then
				return humanoid, current
			end
		end
		current = current.Parent
	end

	return nil
end

-- Игрок по персонажу (манекены вернут nil).
function DamageModel.getPlayerFromCharacter(character)
	local Players = game:GetService("Players")
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character == character then
			return player
		end
	end
	return nil
end

return DamageModel

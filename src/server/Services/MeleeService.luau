--!nonstrict
-- Ближний бой: отдельная механика (конус + дистанция), не стрельба.
-- Оружие ближнего боя живёт в тех же слотах, но стрельба для него отключена.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local DamageModel = require(Shared.DamageModel)
local WeaponLibrary = require(Shared.WeaponLibrary)

local MeleeService = {}

local nextAttackTime = {}

local function getTorso(character)
	return character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
		or character:FindFirstChild("HumanoidRootPart")
end

function MeleeService.attack(state)
	local player = state.Player
	local config = WeaponLibrary.getMelee(state.Current)
	if not config then
		return
	end

	local time = os.clock()
	if time < (nextAttackTime[player] or 0) then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	nextAttackTime[player] = time + 60 / math.max(config.Rpm, 1)

	local origin = root.Position
	local look = root.CFrame.LookVector
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.IgnoreWater = true

	local best = nil
	local bestDistance = config.Range

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other.Character then
			local humanoid = other.Character:FindFirstChildOfClass("Humanoid")
			local torso = getTorso(other.Character)
			if humanoid and humanoid.Health > 0 and torso then
				local delta = torso.Position - origin
				local distance = delta.Magnitude
				if distance > 0 and distance <= config.Range then
					local angle = math.deg(math.acos(math.clamp(look:Dot(delta.Unit), -1, 1)))
					if angle <= config.ConeAngle then
						local result = workspace:Raycast(origin, delta, raycastParams)
						if not result or result.Instance:IsDescendantOf(other.Character) then
							if distance < bestDistance then
								best = { Player = other, Part = torso, Humanoid = humanoid, Position = torso.Position }
								bestDistance = distance
							end
						end
					end
				end
			end
		end
	end

	if best then
		local region = DamageModel.getRegion(best.Part)
		local multiplier = (config.BodyMultipliers and config.BodyMultipliers[region]) or 1
		local damage = config.Damage * multiplier

		best.Humanoid:SetAttribute("LastAttackerUserId", player.UserId)
		best.Humanoid:TakeDamage(damage)

		Net.toClient(player, {
			type = "Hit",
			region = region,
			damage = damage,
			position = best.Position,
			melee = true,
		})
	end

	Net.effectToAll({
		type = "MeleeSwing",
		userId = player.UserId,
		meleeId = state.Current,
		position = origin,
		direction = look,
		hit = best ~= nil,
	}, nil)
end

function MeleeService.clear(player)
	nextAttackTime[player] = nil
end

function MeleeService.start()
	Players.PlayerRemoving:Connect(function(player)
		nextAttackTime[player] = nil
	end)
end

return MeleeService

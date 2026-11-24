--!nonstrict
-- Клиентская часть стрельбы: ввод, предсказание, связь с сервером.
-- Клиент не считает попадания — он рисует свой трейсер сразу и просит сервер
-- подтвердить выстрел. Сервер присылает аммо, попадания и отказы.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Settings = require(Shared.Config.Settings)
local Net = require(Shared.Net)
local Ballistics = require(Shared.Ballistics)
local SeededRandom = require(Shared.SeededRandom)
local WeaponLibrary = require(Shared.WeaponLibrary)

local WeaponController = {}
WeaponController.__index = WeaponController

local function getCharacterParts()
	local character = Players.LocalPlayer.Character
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end

	return character, humanoid, root
end

local function getMovementState(root, humanoid)
	local velocity = root.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

	return {
		Moving = horizontal > 2,
		Sprinting = horizontal > Settings.Character.WalkSpeed + 2,
		Airborne = humanoid.FloorMaterial == Enum.Material.Air,
		Crouching = math.abs(root.CFrame.RightVector.Y) > 0.8,
	}
end

function WeaponController.new(cameraController, viewModel, effects, hud)
	local self = setmetatable({}, WeaponController)

	self.cameraController = cameraController
	self.viewModel = viewModel
	self.effects = effects
	self.hud = hud

	self.weaponId = nil
	self.stats = nil
	self.melee = false
	self.attachments = {}
	self.loadout = table.clone(Settings.DefaultLoadout)

	self.ammo = 0
	self.reserve = 0
	self.fireMode = nil
	self.reloading = false
	self.equipUntil = 0
	self.nextFireTime = 0
	self.shotId = 0

	self.triggerDown = false

	self.raycastParams = RaycastParams.new()
	self.raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	self.raycastParams.IgnoreWater = true

	return self
end

function WeaponController:getSpread()
	local stats = self.stats
	if not stats then
		return 0
	end

	local _, humanoid, root = getCharacterParts()
	if not humanoid then
		return stats.Spread.Hip
	end

	local stance = self.cameraController:isAiming() and "Aim" or "Hip"
	return Ballistics.getSpread(stats, stance, getMovementState(root, humanoid))
end

-- Применяет состояние с сервера: что в руках, какие модули, сколько патронов.
function WeaponController:applyEquipped(payload)
	if type(payload.weaponId) ~= "string" then
		return
	end

	self.weaponId = payload.weaponId
	self.melee = payload.melee == true
	self.attachments = payload.attachments or {}
	if type(payload.loadout) == "table" then
		self.loadout = payload.loadout
	end

	self.hud:setReloading(0)

	if self.melee then
		local config = WeaponLibrary.getMelee(self.weaponId)
		self.stats = nil
		self.fireMode = nil
		self.ammo = 0
		self.reserve = 0
		self.reloading = false
		self.equipUntil = os.clock() + 0.4
		self.viewModel:setMelee(config)
		self.hud:setWeapon(self.weaponId, config, nil)
		self.hud:setCrosshairVisible(false)
		return
	end

	local stats = WeaponLibrary.resolve(self.weaponId, self.attachments)
	self.stats = stats
	if not stats then
		return
	end

	self.equipUntil = os.clock() + (stats.EquipTime or 0)
	self.nextFireTime = self.equipUntil
	self.reloading = false
	self.viewModel:setWeapon(stats)
	self.cameraController:setZoom(stats.Zoom or 1)
	self.hud:setWeapon(self.weaponId, stats, self.attachments)
	self.hud:setCrosshairVisible(true)
end

function WeaponController:applyAmmo(payload)
	if payload.weaponId and self.weaponId and payload.weaponId ~= self.weaponId then
		return
	end

	-- Ближний бой: патронов нет, HUD уже показывает название клинка.
	if self.melee or payload.melee then
		self.ammo = 0
		self.reserve = 0
		self.reloading = false
		self.hud:setReloading(0)
		return
	end

	self.ammo = tonumber(payload.ammo) or 0
	self.reserve = tonumber(payload.reserve) or 0
	self.reloading = payload.reloading == true

	if payload.fireMode ~= nil then
		self.fireMode = payload.fireMode
		self.hud:setFireMode(self.fireMode)
	end

	self.hud:setAmmo(self.ammo, self.reserve, self.reloading)
	if not self.reloading then
		self.hud:setReloading(0)
	end
end

function WeaponController:onState(payload)
	if type(payload) ~= "table" then
		return
	end

	local kind = payload.type
	if kind == "Equipped" then
		self:applyEquipped(payload)
	elseif kind == "Ammo" then
		self:applyAmmo(payload)
	elseif kind == "Reload" then
		self.reloading = true
		self.nextFireTime = math.max(self.nextFireTime, os.clock() + (payload.duration or 0))
		self.hud:setReloading(payload.duration)
	elseif kind == "ShotResult" then
		if type(payload.hits) == "table" and #payload.hits > 0 then
			self.hud:hitmarker()
		end
		if payload.ammo then
			self:applyAmmo(payload.ammo)
		end
	elseif kind == "Hit" then
		self.hud:hitmarker()
	end
end

function WeaponController:setAiming(aiming)
	self.cameraController:setAiming((not self.melee) and aiming)
end

function WeaponController:cycleFireMode()
	local stats = self.stats
	if not stats or not stats.FireModes or #stats.FireModes < 2 then
		return
	end

	local index = table.find(stats.FireModes, self.fireMode) or 1
	local mode = stats.FireModes[(index % #stats.FireModes) + 1]
	Net.toServer({ type = "SetFireMode", mode = mode })
end

function WeaponController:requestReload()
	if self.melee or not self.stats or self.reloading then
		return
	end
	if self.ammo >= self.stats.MagCapacity or self.reserve <= 0 then
		return
	end
	if os.clock() - (self.reloadRequestAt or 0) < 0.4 then
		return
	end

	self.reloadRequestAt = os.clock()
	Net.toServer({ type = "Reload" })
end

function WeaponController:tryMelee()
	local config = WeaponLibrary.getMelee(self.weaponId)
	if not config then
		return
	end

	local now = os.clock()
	if now < (self.meleeNextTime or 0) then
		return
	end

	self.meleeNextTime = now + 60 / math.max(config.Rpm, 1)
	Net.toServer({ type = "Melee" })
end

-- Точка выстрела: ствол оружия + направление на точку под прицелом.
function WeaponController:getShotRay()
	local camera = workspace.CurrentCamera
	local muzzle = self.viewModel:getMuzzlePosition()
	if not camera or not muzzle then
		return nil, nil
	end

	local character = Players.LocalPlayer.Character
	self.raycastParams.FilterDescendantsInstances = { character }

	local cameraOrigin = camera.CFrame.Position
	local look = camera.CFrame.LookVector
	local result = workspace:Raycast(cameraOrigin, look * 500, self.raycastParams)
	local aimPoint = result and result.Position or (cameraOrigin + look * 500)

	local delta = aimPoint - muzzle
	if delta.Magnitude < 3 then
		return muzzle, look
	end

	return muzzle, delta.Unit
end

function WeaponController:tryFire()
	local stats = self.stats
	if not stats or self.melee then
		return
	end

	local now = os.clock()
	if now < self.nextFireTime or now < self.equipUntil or self.reloading then
		return
	end
	if now - (self.reloadRequestAt or 0) < 0.3 then
		return
	end

	if self.ammo <= 0 then
		self:requestReload()
		return
	end

	local character, humanoid, root = getCharacterParts()
	if not character then
		return
	end

	local origin, direction = self:getShotRay()
	if not origin or not direction then
		return
	end

	local aiming = self.cameraController:isAiming()
	local stance = aiming and "Aim" or "Hip"
	local spread = Ballistics.getSpread(stats, stance, getMovementState(root, humanoid))
	local seed = math.random(1, 2147483647)

	self.shotId += 1
	Net.toServer({
		type = "Fire",
		shotId = self.shotId,
		origin = origin,
		direction = direction,
		seed = seed,
		stance = stance,
	})

	if Settings.Prediction.Enabled then
		self:predictShot(stats, origin, direction, spread, seed, character)
	end

	self.ammo = math.max(self.ammo - 1, 0)
	self.nextFireTime = now + 60 / math.max(stats.Rpm, 1)
	self.hud:setAmmo(self.ammo, self.reserve, self.reloading)

	self.cameraController:addRecoil(stats.Recoil.Vertical, stats.Recoil.Horizontal)
	if (stats.Recoil.Shake or 0) > 0 then
		self.cameraController:addRecoil(stats.Recoil.Shake * 0.2, stats.Recoil.Shake * 0.35)
	end
end

-- Тот же расчёт, что на сервере: seed + порядок вызовов rng дают одинаковый разброс.
function WeaponController:predictShot(stats, origin, direction, spread, seed, character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	local excluded = { character }
	if self.viewModel.model then
		table.insert(excluded, self.viewModel.model)
	end
	params.FilterDescendantsInstances = excluded

	local rng = SeededRandom.new(seed)
	local pellets = math.clamp(math.floor(stats.Pellets or 1), 1, Settings.AntiCheat.MaxPelletsPerShot)

	for index = 1, pellets do
		local pelletDirection = Ballistics.spreadDirection(direction, spread, rng)
		local trace = Ballistics.trace({
			Origin = origin,
			Direction = pelletDirection,
			MuzzleVelocity = stats.MuzzleVelocity,
			GravityScale = stats.GravityScale,
			MaxRange = stats.MaxRange,
		}, function(from, target)
			return workspace:Raycast(from, target, params)
		end)

		self.effects:spawnTracer({
			type = "Tracer",
			primary = index == 1,
			origin = trace.Origin,
			direction = pelletDirection,
			endPosition = trace.End,
			impacted = trace.Impacted,
			normal = trace.Normal,
			color = stats.TracerColor,
		})
	end
end

function WeaponController:step()
	if self.stats then
		self.hud:setSpread(self:getSpread())
	end

	if self.triggerDown and not self.melee and self.fireMode == "Auto" then
		self:tryFire()
	end
end

local SLOT_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
}

function WeaponController:start()
	Net.onState(function(payload)
		local ok, err = pcall(function()
			self:onState(payload)
		end)
		if not ok and Settings.Debug then
			warn("[Weapons] state: " .. tostring(err))
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.triggerDown = true
			if self.melee then
				self:tryMelee()
			elseif self.fireMode ~= "Auto" then
				self:tryFire()
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:setAiming(true)
		elseif input.UserInputType == Enum.UserInputType.Keyboard then
			local key = input.KeyCode
			if key == Enum.KeyCode.R then
				self:requestReload()
			elseif key == Enum.KeyCode.B then
				self:cycleFireMode()
			end

			local slot = SLOT_KEYS[key]
			if slot then
				Net.toServer({ type = "Equip", slot = slot })
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.triggerDown = false
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:setAiming(false)
		end
	end)

	Players.LocalPlayer.CharacterAdded:Connect(function()
		self.triggerDown = false
		self.reloading = false
		self.meleeNextTime = 0
		self.nextFireTime = 0
		self.equipUntil = os.clock() + 0.6
		self.hud:setReloading(0)
		self:setAiming(false)
	end)

	RunService.RenderStepped:Connect(function()
		self:step()
	end)
end

return WeaponController



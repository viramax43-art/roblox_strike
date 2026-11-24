--!nonstrict
-- Главный серверный сервис стрельбы.
-- Проверяет пакеты клиента, ведёт состояние игрока, считает попадания,
-- рассылает визуал. Клиент ничего не решает — только просит.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Settings = require(Shared.Config.Settings)
local Net = require(Shared.Net)
local Ballistics = require(Shared.Ballistics)
local WeaponLibrary = require(Shared.WeaponLibrary)

local HitboxHistory = require(script.Parent.HitboxHistory)
local ProjectileService = require(script.Parent.ProjectileService)
local MeleeService = require(script.Parent.MeleeService)
local PlayerState = require(script.Parent.PlayerState)

local WeaponService = {}

local states = {}

local function pushAmmo(state)
	Net.toClient(state.Player, state:getAmmoPayload())
end

local function pushEquip(state)
	Net.toClient(state.Player, state:getEquipPayload())
	pushAmmo(state)
end

local function getCharacterParts(player)
	local character = player.Character
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	if not humanoid or not root then
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

local function reloadPayload(state, duration)
	return {
		type = "Reload",
		weaponId = state.Current,
		duration = duration,
	}
end

local handlers = {}

function handlers.Equip(player, payload)
	local state = states[player]
	if not state then
		return
	end

	local identifier = payload.weaponId
	if type(identifier) ~= "string" and type(payload.slot) == "number" then
		identifier = state.Loadout[math.floor(payload.slot)]
	end

	if state:equip(identifier) then
		pushEquip(state)
	end
end

function handlers.Reload(player)
	local state = states[player]
	if not state then
		return
	end

	local ok, duration = state:startReload(os.clock())
	if ok then
		Net.toClient(player, reloadPayload(state, duration))
		pushAmmo(state)
	end
end

function handlers.SetFireMode(player, payload)
	local state = states[player]
	if not state then
		return
	end

	if state:setFireMode(payload.mode) then
		pushAmmo(state)
	end
end

function handlers.SetAttachment(player, payload)
	local state = states[player]
	if not state or type(payload.category) ~= "string" then
		return
	end

	local attachmentId = payload.attachmentId
	if attachmentId ~= nil and type(attachmentId) ~= "string" then
		return
	end

	if state:setAttachment(payload.category, attachmentId) then
		pushEquip(state)
	end
end

function handlers.Melee(player)
	local state = states[player]
	if not state or not state:isMelee() then
		return
	end

	MeleeService.attack(state)
end

function handlers.Fire(player, payload)
	local state = states[player]
	if not state or state:isMelee() then
		return
	end

	local origin = payload.origin
	local direction = payload.direction
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	if direction.Magnitude < 1e-3 then
		return
	end

	local stats = state:getStats()
	local character, humanoid, root = getCharacterParts(player)
	if not stats or not character or not humanoid or humanoid.Health <= 0 then
		return
	end

	if (origin - root.Position).Magnitude > Settings.AntiCheat.MaxOriginDistance then
		if Settings.Debug then
			warn(string.format("[Weapons] %s: точка выстрела вне допустимого радиуса", player.Name))
		end
		return
	end

	local time = os.clock()
	if not state:canFire(time) then
		return
	end
	if not state:acceptShotId(payload.shotId) then
		return
	end

	if not state:consumeRound() then
		local ok, duration = state:startReload(time)
		if ok then
			Net.toClient(player, reloadPayload(state, duration))
		end
		pushAmmo(state)
		return
	end

	local stance = payload.stance == "Aim" and "Aim" or "Hip"
	local movement = getMovementState(root, humanoid)
	local spread = Ballistics.getSpread(stats, stance, movement)

	local seed = math.floor(tonumber(payload.seed) or 0)
	if seed ~= seed or math.abs(seed) > 2147483647 then
		seed = 0
	end

	local result = ProjectileService.fire({
		Shooter = player,
		Stats = stats,
		Origin = origin,
		Direction = direction,
		Spread = spread,
		Seed = seed,
		RewindSeconds = HitboxHistory.getRewindSeconds(player),
	})

	state:registerShot(time)

	-- Свои трейсеры клиент рисует сам (предсказание), остальным — с сервера.
	for _, tracer in ipairs(result.Tracers) do
		Net.effectToAll(tracer, player)
	end

	Net.toClient(player, {
		type = "ShotResult",
		shotId = payload.shotId,
		weaponId = state.Current,
		hits = result.Hits,
		ammo = state:getAmmoPayload(),
	})
end

local function setupPlayer(player)
	if states[player] then
		return
	end

	local state = PlayerState.new(player, Settings.DefaultLoadout)
	states[player] = state

	state.OnChanged = function(changed)
		pushAmmo(changed)
	end

	state:equip(Settings.DefaultLoadout[1], true)

	player.CharacterAdded:Connect(function()
		state:reset()
		task.wait(0.2)
		pushEquip(state)
	end)

	pushEquip(state)
end

function WeaponService.start()
	Net.onAction(function(player, payload)
		if type(payload) ~= "table" or type(payload.type) ~= "string" then
			return
		end

		local handler = handlers[payload.type]
		if not handler then
			return
		end

		local ok, err = pcall(handler, player, payload)
		if not ok and Settings.Debug then
			warn("[Weapons] ошибка обработчика " .. payload.type .. ": " .. tostring(err))
		end
	end)

	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		HitboxHistory.clear(player)
		MeleeService.clear(player)
	end)

	-- В Studio игрок может существовать до подключения этого скрипта.
	for _, player in ipairs(Players:GetPlayers()) do
		setupPlayer(player)
	end

	if Settings.Debug then
		print("[Weapons] сервис запущен, оружие в игре: " .. tostring(#WeaponLibrary.getAllWeaponIds()))
	end
end

function WeaponService.getState(player)
	return states[player]
end

return WeaponService


--!nonstrict
-- Состояние игрока: слоты, патроны, перезарядка, модули, режим огня.
-- Вся логика проверок — здесь, сервис только принимает пакеты.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Settings = require(Shared.Config.Settings)
local WeaponLibrary = require(Shared.WeaponLibrary)

local PlayerState = {}
PlayerState.__index = PlayerState

local function now()
	return os.clock()
end

function PlayerState.new(player, loadout)
	local self = setmetatable({}, PlayerState)

	self.Player = player
	self.Loadout = table.clone(loadout)
	self.Current = nil
	self.Slots = {}
	self.Attachments = {}
	self.FireMode = nil
	self.NextFireTime = 0
	self.EquipUntil = 0
	self.ReloadingUntil = 0
	self.ReloadToken = 0
	self.LastShotId = 0
	self.ShotTimestamps = {}
	self.OnChanged = nil

	return self
end

function PlayerState:isMelee()
	return self.Current ~= nil and WeaponLibrary.isMelee(self.Current)
end

function PlayerState:getConfig()
	return WeaponLibrary.get(self.Current)
end

function PlayerState:getStats()
	if self:isMelee() then
		return nil
	end
	return WeaponLibrary.resolve(self.Current, self.Attachments[self.Current])
end

function PlayerState:getAttachments()
	return self.Attachments[self.Current] or {}
end

function PlayerState:getSlotIndex()
	for index, identifier in ipairs(self.Loadout) do
		if identifier == self.Current then
			return index
		end
	end
	return nil
end

function PlayerState:getAmmoState()
	local stats = self:getStats()
	if not stats then
		return nil
	end

	local slot = self.Slots[self.Current]
	if not slot then
		slot = { Ammo = stats.MagCapacity, Reserve = stats.Reserve }
		self.Slots[self.Current] = slot
	end

	slot.Ammo = math.min(slot.Ammo, stats.MagCapacity)
	return slot
end

function PlayerState:equip(identifier, force)
	if not identifier then
		return false
	end
	if not WeaponLibrary.isWeapon(identifier) and not WeaponLibrary.isMelee(identifier) then
		return false
	end
	if not table.find(self.Loadout, identifier) then
		return false
	end
	if self.Current == identifier and not force then
		return false
	end

	self.Current = identifier
	self.NextFireTime = 0
	self.ReloadingUntil = 0
	self.ReloadToken += 1

	local stats = self:getStats()
	if stats then
		local mode = self.FireMode
		if not mode or not table.find(stats.FireModes, mode) then
			mode = stats.FireModes[1]
		end
		self.FireMode = mode
		self.EquipUntil = now() + (stats.EquipTime or 0)
		self:getAmmoState()
	else
		self.FireMode = nil
		self.EquipUntil = now() + 0.4
	end

	return true
end

function PlayerState:isReloading(time)
	time = time or now()
	return self.ReloadingUntil > time
end

function PlayerState:canFire(time)
	if time < self.NextFireTime or time < self.EquipUntil then
		return false
	end
	if self:isReloading(time) then
		return false
	end

	local recent = 0
	for _, timestamp in ipairs(self.ShotTimestamps) do
		if time - timestamp <= 1 then
			recent += 1
		end
	end
	if recent >= Settings.AntiCheat.MaxShotsPerSecond then
		return false
	end

	return true
end

function PlayerState:acceptShotId(shotId)
	if type(shotId) ~= "number" or shotId ~= shotId then
		return false
	end
	if shotId <= self.LastShotId then
		return false
	end

	self.LastShotId = shotId
	return true
end

function PlayerState:registerShot(time)
	local stats = self:getStats()
	local interval = stats and WeaponLibrary.getFireInterval(stats) or 0.1
	local cooldown = math.max(interval * Settings.AntiCheat.FireRateSlack, Settings.AntiCheat.MinFireInterval)

	self.NextFireTime = time + cooldown

	table.insert(self.ShotTimestamps, time)
	while #self.ShotTimestamps > 0 and time - self.ShotTimestamps[1] > 1 do
		table.remove(self.ShotTimestamps, 1)
	end
end

function PlayerState:consumeRound()
	local ammo = self:getAmmoState()
	if not ammo or ammo.Ammo <= 0 then
		return false
	end

	ammo.Ammo -= 1
	return true
end

function PlayerState:startReload(time)
	local stats = self:getStats()
	if not stats or self:isReloading(time) then
		return false, 0
	end

	local ammo = self:getAmmoState()
	if not ammo or ammo.Ammo >= stats.MagCapacity or ammo.Reserve <= 0 then
		return false, 0
	end

	local duration = stats.ReloadTime or 2
	self.ReloadingUntil = time + duration
	self.ReloadToken += 1
	local token = self.ReloadToken

	task.delay(duration, function()
		if self.ReloadToken == token then
			self:finishReload()
		end
	end)

	return true, duration
end

function PlayerState:finishReload()
	local stats = self:getStats()
	if not stats then
		return
	end

	local ammo = self:getAmmoState()
	if ammo then
		local needed = stats.MagCapacity - ammo.Ammo
		local moved = math.min(needed, ammo.Reserve)
		ammo.Ammo += moved
		ammo.Reserve -= moved
	end

	self.ReloadingUntil = 0
	self:notify()
end

function PlayerState:setFireMode(mode)
	local stats = self:getStats()
	if not stats or not mode or not table.find(stats.FireModes, mode) then
		return false
	end

	self.FireMode = mode
	return true
end

function PlayerState:setAttachment(category, attachmentId)
	local current = self.Current
	if not current or self:isMelee() then
		return false
	end

	local config = WeaponLibrary.get(current)
	if not config then
		return false
	end

	local attachments = table.clone(self.Attachments[current] or {})
	attachments[category] = attachmentId

	local sanitized = WeaponLibrary.sanitizeAttachments(current, attachments)
	if attachmentId ~= nil and sanitized[category] ~= attachmentId then
		return false
	end

	self.Attachments[current] = sanitized

	local stats = WeaponLibrary.resolve(current, sanitized)
	local ammo = self.Slots[current]
	if ammo and stats then
		ammo.Ammo = math.min(ammo.Ammo, stats.MagCapacity)
	end

	return true, stats
end

function PlayerState:reset()
	self.NextFireTime = 0
	self.EquipUntil = now() + 0.5
	self.ReloadingUntil = 0
	self.ReloadToken += 1
	self.LastShotId = 0
	self.ShotTimestamps = {}

	for identifier, slot in pairs(self.Slots) do
		local stats = WeaponLibrary.resolve(identifier, self.Attachments[identifier])
		if stats then
			slot.Ammo = stats.MagCapacity
			slot.Reserve = stats.Reserve
		end
	end
end

function PlayerState:notify()
	if self.OnChanged then
		self.OnChanged(self)
	end
end

function PlayerState:getAmmoPayload()
	local stats = self:getStats()
	if not stats then
		return {
			type = "Ammo",
			weaponId = self.Current,
			ammo = 0,
			reserve = 0,
			fireMode = self.FireMode,
			reloading = false,
			melee = true,
		}
	end

	local ammo = self:getAmmoState()
	return {
		type = "Ammo",
		weaponId = self.Current,
		ammo = ammo.Ammo,
		reserve = ammo.Reserve,
		fireMode = self.FireMode,
		reloading = self:isReloading(),
	}
end

function PlayerState:getEquipPayload()
	return {
		type = "Equipped",
		weaponId = self.Current,
		slot = self:getSlotIndex(),
		attachments = self:getAttachments(),
		melee = self:isMelee(),
		loadout = self.Loadout,
	}
end

return PlayerState



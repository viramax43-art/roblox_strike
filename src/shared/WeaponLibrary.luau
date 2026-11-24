--!nonstrict
-- Сборка итоговых характеристик оружия с учётом модулей.
-- Здесь единственное место, где конфиг оружия складывается с обвесами —
-- клиент и сервер получают одинаковые цифры из одних и тех же данных.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Weapons = require(Config.Weapons)
local Attachments = require(Config.Attachments)
local Melee = require(Config.Melee)

local WeaponLibrary = {}

WeaponLibrary.Weapons = Weapons
WeaponLibrary.Melee = Melee

local resolveCache = {}

local function isAllowed(item, config)
	if not item.AllowedClasses then
		return true
	end

	for _, class in ipairs(item.AllowedClasses) do
		if class == "*" or class == config.Class then
			return true
		end
	end

	return false
end

function WeaponLibrary.get(weaponId)
	return Weapons[weaponId]
end

function WeaponLibrary.getMelee(meleeId)
	return Melee[meleeId]
end

function WeaponLibrary.isMelee(identifier)
	return Melee[identifier] ~= nil
end

function WeaponLibrary.isWeapon(identifier)
	return Weapons[identifier] ~= nil
end

function WeaponLibrary.getAllWeaponIds()
	local ids = {}
	for id in pairs(Weapons) do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

function WeaponLibrary.getDefaultAttachments(weaponId)
	local config = Weapons[weaponId]
	if not config then
		return {}
	end

	local defaults = {}
	for category, attachmentId in pairs(config.DefaultAttachments or {}) do
		defaults[category] = attachmentId
	end
	return defaults
end

-- Оставляет только существующие, подходящие по слоту и классу модули.
function WeaponLibrary.sanitizeAttachments(weaponId, attachments)
	local config = Weapons[weaponId]
	if not config then
		return {}
	end

	local slots = {}
	for _, category in ipairs(config.AttachmentSlots or {}) do
		slots[category] = true
	end

	local merged = WeaponLibrary.getDefaultAttachments(weaponId)
	for category, attachmentId in pairs(attachments or {}) do
		merged[category] = attachmentId
	end

	local sanitized = {}
	for category, attachmentId in pairs(merged) do
		local item = Attachments.get(attachmentId)
		if item and item.Category == category and slots[category] and isAllowed(item, config) then
			sanitized[category] = attachmentId
		end
	end

	return sanitized
end

function WeaponLibrary.getAvailableAttachments(weaponId, category)
	local config = Weapons[weaponId]
	if not config then
		return {}
	end

	local result = {}
	for _, item in pairs(Attachments.Items) do
		if item.Category == category and isAllowed(item, config) then
			table.insert(result, item)
		end
	end
	table.sort(result, function(a, b)
		return a.DisplayName < b.DisplayName
	end)

	return result
end

local function attachmentSignature(attachments)
	local parts = {}
	for _, category in ipairs(Attachments.Categories) do
		table.insert(parts, category .. "=" .. tostring(attachments[category]))
	end
	return table.concat(parts, "|")
end

local function shallowCopy(source)
	local copy = {}
	for key, value in pairs(source) do
		if type(value) == "table" then
			copy[key] = table.clone(value)
		else
			copy[key] = value
		end
	end
	return copy
end

-- Итоговые характеристики оружия с модулями.
-- Возвращаемый объект кэшируется: его нельзя менять на месте.
function WeaponLibrary.resolve(weaponId, attachments)
	local config = Weapons[weaponId]
	if not config then
		return nil
	end

	local sanitized = WeaponLibrary.sanitizeAttachments(weaponId, attachments)
	local cacheKey = weaponId .. "#" .. attachmentSignature(sanitized)
	local cached = resolveCache[cacheKey]
	if cached then
		return cached
	end

	local stats = shallowCopy(config)
	stats.Spread = stats.Spread or { Hip = 0, Ads = 0 }
	stats.Recoil = stats.Recoil or { Vertical = 0, Horizontal = 0, Shake = 0 }
	stats.Falloff = stats.Falloff or { Min = 0, Max = math.huge, MinMultiplier = 1 }
	stats.BodyMultipliers = stats.BodyMultipliers or { Head = 1, Torso = 1, Arms = 1, Legs = 1 }
	stats.Attachments = sanitized
	stats.Sound = "Default"

	for _, category in ipairs(Attachments.Categories) do
		local item = Attachments.get(sanitized[category])
		local modifiers = item and item.Modifiers
		if modifiers then
			if modifiers.HipSpreadMultiplier then
				stats.Spread.Hip *= modifiers.HipSpreadMultiplier
			end
			if modifiers.AdsSpreadMultiplier then
				stats.Spread.Ads *= modifiers.AdsSpreadMultiplier
			end
			if modifiers.SpreadMultiplier then
				stats.Spread.Hip *= modifiers.SpreadMultiplier
				stats.Spread.Ads *= modifiers.SpreadMultiplier
			end
			if modifiers.RecoilMultiplier then
				stats.Recoil.Vertical *= modifiers.RecoilMultiplier
				stats.Recoil.Horizontal *= modifiers.RecoilMultiplier
				stats.Recoil.Shake *= modifiers.RecoilMultiplier
			end
			if modifiers.MuzzleVelocityMultiplier then
				stats.MuzzleVelocity *= modifiers.MuzzleVelocityMultiplier
			end
			if modifiers.DamageMultiplier then
				stats.Damage *= modifiers.DamageMultiplier
			end
			if modifiers.RangeMultiplier then
				stats.Falloff.Min *= modifiers.RangeMultiplier
				stats.Falloff.Max *= modifiers.RangeMultiplier
			end
			if modifiers.MagCapacityAdd then
				stats.MagCapacity += modifiers.MagCapacityAdd
			end
			if modifiers.ReloadTimeMultiplier then
				stats.ReloadTime *= modifiers.ReloadTimeMultiplier
			end
			if modifiers.ReloadTimeAdd then
				stats.ReloadTime += modifiers.ReloadTimeAdd
			end
			if modifiers.Zoom then
				stats.Zoom = modifiers.Zoom
			end
			if modifiers.ScopeOverlay ~= nil then
				stats.ScopeOverlay = modifiers.ScopeOverlay
			end
			if modifiers.Sound then
				stats.Sound = modifiers.Sound
			end
		end
	end

	stats.MagCapacity = math.max(1, math.floor(stats.MagCapacity))
	stats.Reserve = math.max(0, math.floor(stats.Reserve or 0))
	stats.FireInterval = 60 / math.max(stats.Rpm, 1)
	stats.Spread.Hip = math.max(stats.Spread.Hip, 0)
	stats.Spread.Ads = math.max(stats.Spread.Ads, 0)

	resolveCache[cacheKey] = stats
	return stats
end

-- Патроны в минуту -> интервал между выстрелами (в секундах).
function WeaponLibrary.getFireInterval(stats)
	return 60 / math.max(stats.Rpm, 1)
end

return WeaponLibrary

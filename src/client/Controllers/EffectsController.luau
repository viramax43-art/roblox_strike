--!nonstrict
-- Визуал выстрелов: трейсеры, вспышки, попадания, взмахи.
-- Всё живёт в отдельной папке в Workspace и само себя убирает.
-- Канал ненадёжный: потеря эффекта ничего не ломает.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Settings = require(ReplicatedStorage.Shared.Config.Settings)

local EffectsController = {}
EffectsController.__index = EffectsController

local TRACER_FADE = 0.08

function EffectsController.new()
	local self = setmetatable({}, EffectsController)

	self.folder = Instance.new("Folder")
	self.folder.Name = "WeaponEffects"
	self.folder.Parent = workspace

	self.impacts = {}

	return self
end

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	for key, value in pairs(props) do
		part[key] = value
	end

	return part
end

function EffectsController:fadeOut(part, lifetime)
	local tween = TweenService:Create(part, TweenInfo.new(lifetime, Enum.EasingStyle.Quad), { Transparency = 1 })
	tween:Play()
	Debris:AddItem(part, lifetime + 0.05)
end

function EffectsController:spawnTracer(tracer)
	local origin = tracer.origin
	local endPosition = tracer.endPosition or (origin + (tracer.direction or Vector3.new(0, 0, -1)) * 100)
	local delta = endPosition - origin
	local length = delta.Magnitude
	if length < 0.5 then
		return
	end

	local streak = makePart({
		Name = "Tracer",
		Color = tracer.color or Color3.fromRGB(255, 210, 140),
		Size = Vector3.new(0.07, 0.07, length),
		CFrame = CFrame.lookAt(origin + delta * 0.5, endPosition),
		Transparency = 0.1,
		Parent = self.folder,
	})

	self:fadeOut(streak, TRACER_FADE)

	if tracer.primary then
		self:spawnMuzzleFlash(origin, tracer.direction)
	end

	if tracer.impacted then
		self:spawnImpact(endPosition, tracer.normal)
	end
end

function EffectsController:spawnMuzzleFlash(position, direction)
	local flash = makePart({
		Name = "MuzzleFlash",
		Color = Color3.fromRGB(255, 220, 150),
		Size = Vector3.new(0.5, 0.5, 0.5),
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
		CFrame = CFrame.new(position) * (direction and CFrame.lookAt(Vector3.zero, direction) or CFrame.identity),
		Parent = self.folder,
	})

	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Range = 12
	light.Color = Color3.fromRGB(255, 210, 150)
	light.Parent = flash

	self:fadeOut(flash, 0.05)
end

function EffectsController:spawnImpact(position, normal)
	local impact = makePart({
		Name = "Impact",
		Color = Color3.fromRGB(255, 190, 90),
		Size = Vector3.new(0.18, 0.18, 0.18),
		Shape = Enum.PartType.Ball,
		Transparency = 0.1,
		CFrame = CFrame.new(position),
		Parent = self.folder,
	})

	if normal then
		impact.CFrame = CFrame.lookAt(position + normal * 0.05, position + normal * 2)
	end

	self:fadeOut(impact, Settings.Effects.ImpactLifetime * 0.25)

	table.insert(self.impacts, impact)
	while #self.impacts > Settings.Effects.MaxActiveImpacts do
		local oldest = table.remove(self.impacts, 1)
		if oldest and oldest.Parent then
			oldest:Destroy()
		end
	end
end

function EffectsController:spawnSwing(payload)
	local position = payload.position
	local direction = payload.direction or Vector3.new(0, 0, -1)
	if not position then
		return
	end

	local arc = makePart({
		Name = "MeleeArc",
		Color = Color3.fromRGB(240, 240, 255),
		Size = Vector3.new(0.12, 2.4, 2.4),
		CFrame = CFrame.lookAt(position + direction * 2.2, position + direction * 6),
		Transparency = 0.35,
		Parent = self.folder,
	})

	self:fadeOut(arc, 0.12)
end

-- Единая точка входа для пакетов Effect-канала.
function EffectsController:handle(payload)
	if type(payload) ~= "table" then
		return
	end

	if payload.type == "Tracer" then
		self:spawnTracer(payload)
	elseif payload.type == "MeleeSwing" then
		self:spawnSwing(payload)
	end
end

return EffectsController

--!nonstrict
-- Модель оружия в руках. Если модели нет (PS12/AS12/R700) — собирается болванка
-- по классу оружия, чтобы можно было тестировать механику до моделлера.
-- Модель живёт в камере: её видит только владелец, репликация не тратится.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Settings = require(ReplicatedStorage.Shared.Config.Settings)

local ViewModelController = {}
ViewModelController.__index = ViewModelController

local VIEW_MODEL = Settings.ViewModel

local function makeGunPart(name, size, color, offset, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = offset
	part.Parent = parent
	return part
end

-- Болванка по классу оружия: форма хоть как-то узнаваемая.
local function buildPlaceholder(stats)
	local model = Instance.new("Model")
	model.Name = "Viewmodel_" .. tostring(stats.Id)

	local class = stats.Class or "SMG"
	local bodyColor = Color3.fromRGB(52, 55, 60)
	local accentColor = Color3.fromRGB(30, 32, 36)
	local woodColor = Color3.fromRGB(94, 66, 44)

	local bodyLength = 1.0
	local barrelLength = 0.7
	if class == "Shotgun" then
		bodyLength = 1.2
		barrelLength = 1.3
	elseif class == "Sniper" then
		bodyLength = 1.4
		barrelLength = 1.9
	end

	local body = makeGunPart(
		"Body",
		Vector3.new(0.24, 0.3, bodyLength),
		bodyColor,
		CFrame.new(0, 0, 0),
		model
	)

	local barrel = makeGunPart(
		"Barrel",
		Vector3.new(0.12, 0.12, barrelLength),
		accentColor,
		CFrame.new(0, 0.04, -(bodyLength * 0.5 + barrelLength * 0.5)),
		model
	)

	makeGunPart("Magazine", Vector3.new(0.16, 0.52, 0.26), accentColor, CFrame.new(0, -0.38, -0.08), model)
	makeGunPart("Grip", Vector3.new(0.16, 0.38, 0.22), bodyColor, CFrame.new(0, -0.3, 0.36), model)

	if class == "Sniper" then
		makeGunPart("Stock", Vector3.new(0.3, 0.22, 0.9), woodColor, CFrame.new(0, -0.05, bodyLength * 0.5 + 0.45), model)
		makeGunPart("Scope", Vector3.new(0.16, 0.16, 0.7), accentColor, CFrame.new(0, 0.28, -0.1), model)
	end

	local muzzle = makeGunPart(
		"Muzzle",
		Vector3.new(0.14, 0.14, 0.14),
		Color3.fromRGB(20, 20, 20),
		barrel.CFrame * CFrame.new(0, 0, -(barrelLength * 0.5 + 0.07)),
		model
	)
	muzzle.Transparency = 1

	model.PrimaryPart = body
	return model
end

-- Приводит модель к виду viewmodel: без физики, без коллизий, без репликации.
local function prepareModel(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			descendant.Massless = true
		end
	end

	if not model.PrimaryPart then
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				model.PrimaryPart = descendant
				break
			end
		end
	end
end

local function findMuzzle(model)
	for _, name in ipairs({ "Muzzle", "muzzle", "MuzzlePoint", "BarrelTip", "Tip" }) do
		local part = model:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function buildMeleePlaceholder(config)
	local model = Instance.new("Model")
	model.Name = "Viewmodel_" .. tostring(config.Id or "Melee")

	local handle = makeGunPart("Handle", Vector3.new(0.12, 0.12, 0.45), Color3.fromRGB(40, 40, 44), CFrame.new(0, -0.2, 0), model)
	makeGunPart("Guard", Vector3.new(0.3, 0.06, 0.08), Color3.fromRGB(20, 20, 22), CFrame.new(0, -0.05, -0.2), model)
	makeGunPart("Blade", Vector3.new(0.04, 0.18, 1.1), Color3.fromRGB(205, 205, 210), CFrame.new(0, -0.02, -0.85), model)

	model.PrimaryPart = handle
	return model
end

function ViewModelController.new(cameraController)
	local self = setmetatable({}, ViewModelController)
	self.cameraController = cameraController
	self.model = nil
	self.muzzle = nil
	self.stats = nil
	self.pose = nil
	return self
end

function ViewModelController:clear()
	if self.model then
		self.model:Destroy()
	end
	self.model = nil
	self.muzzle = nil
	self.stats = nil
	self.pose = nil
end

function ViewModelController:setWeapon(stats)
	self:clear()
	if not stats then
		return
	end

	local template = nil
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local weapons = assets and assets:FindFirstChild("Weapons")
	if weapons and stats.Model then
		template = weapons:FindFirstChild(stats.Model)
	end

	local model
	if template and template:IsA("Model") then
		model = template:Clone()
		prepareModel(model)
	else
		model = buildPlaceholder(stats)
	end

	model.Parent = workspace.CurrentCamera
	self.model = model
	self.stats = stats
	self.muzzle = findMuzzle(model)
end

function ViewModelController:setMelee(config)
	self:clear()

	local model = buildMeleePlaceholder(config or {})
	model.Parent = workspace.CurrentCamera
	self.model = model
	self.stats = config
	self.muzzle = nil
end

function ViewModelController:getMuzzlePosition()
	local model = self.model
	if not model or not model.Parent then
		return nil
	end

	if self.muzzle and self.muzzle.Parent then
		return self.muzzle.Position
	end

	local _, size = model:GetBoundingBox()
	return (model:GetPivot() * CFrame.new(0, 0, -size.Z * 0.5)).Position
end

function ViewModelController:getWeaponCFrame()
	local model = self.model
	return model and model:GetPivot() or nil
end

function ViewModelController:update(deltaTime)
	local model = self.model
	if not model then
		return
	end

	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))

	if not camera or not hand or not character.Parent then
		if model.Parent then
			model.Parent = nil
		end
		self.pose = nil
		return
	end

	if model.Parent ~= camera then
		model:PivotTo(self.pose or camera.CFrame)
		model.Parent = camera
	end

	local aiming = self.cameraController:isAiming()
	local target
	if self.cameraController:getMode() == "FirstPerson" then
		target = camera.CFrame * (aiming and VIEW_MODEL.FirstPersonAim or VIEW_MODEL.FirstPersonHip)
	else
		target = hand.CFrame * VIEW_MODEL.ThirdPersonGrip
	end

	self.pose = self.pose and self.pose:Lerp(target, math.min(deltaTime * VIEW_MODEL.BlendSpeed, 1)) or target
	model:PivotTo(self.pose)
end

function ViewModelController:start()
	RunService.RenderStepped:Connect(function(deltaTime)
		self:update(deltaTime)
	end)
end

return ViewModelController


--!nonstrict
-- Тестовый полигон: платформа, стены, мишени на 25/70/140/240 studs.
-- Нужен, чтобы проверять механику до готовности карты и моделей.
-- Отключается флагом Settings.BuildTestRange.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Config.Settings)

local TestRange = {}

local function newPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	for key, value in pairs(props) do
		part[key] = value
	end

	return part
end

local function weld(parent, part0, part1)
	local motor = Instance.new("Motor6D")
	motor.Name = "Joint"
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = part0.CFrame:Inverse() * part1.CFrame
	motor.C1 = CFrame.identity
	motor.Parent = parent
	return motor
end

local function createDummy(position)
	local model = Instance.new("Model")
	model.Name = "Dummy"

	local skin = Color3.fromRGB(196, 40, 40)
	local torsoPosition = position + Vector3.new(0, 3, 0)

	local function limb(name, size, offset, color)
		local part = newPart({
			Name = name,
			Size = size,
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Anchored = false,
			CanCollide = false,
			Parent = model,
		})
		part.CFrame = CFrame.new(torsoPosition + offset)
		return part
	end

	local torso = newPart({
		Name = "Torso",
		Size = Vector3.new(2, 2, 1),
		Color = skin,
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	torso.CFrame = CFrame.new(torsoPosition)

	local head = limb("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.6, 0), Color3.fromRGB(230, 200, 120))
	local leftArm = limb("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), skin)
	local rightArm = limb("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), skin)
	local leftLeg = limb("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), Color3.fromRGB(60, 70, 110))
	local rightLeg = limb("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), Color3.fromRGB(60, 70, 110))

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.DisplayName = "Мишень"
	humanoid.Parent = model

	weld(torso, torso, head)
	weld(torso, torso, leftArm)
	weld(torso, torso, rightArm)
	weld(torso, torso, leftLeg)
	weld(torso, torso, rightLeg)

	model.PrimaryPart = torso
	model.Parent = workspace

	humanoid.Died:Connect(function()
		local origin = torsoPosition
		task.delay(2.5, function()
			if model.Parent then
				model:Destroy()
			end
			createDummy(origin - Vector3.new(0, 3, 0))
		end)
	end)

	return model
end

function TestRange.build()
	local origin = Settings.TestRange.Origin

	local platform = newPart({
		Name = "RangeFloor",
		Size = Vector3.new(420, 4, 460),
		Position = origin + Vector3.new(0, -2, -110),
		Color = Color3.fromRGB(72, 74, 76),
		Material = Enum.Material.Concrete,
		Parent = workspace,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "RangeSpawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(origin + Vector3.new(0, 0.5, 6))
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Parent = workspace

	-- Стены для проверки попаданий в геометрию (рикошет/искры).
	local wallMaterials = {
		{ Distance = 30, Material = Enum.Material.Concrete, Offset = -18 },
		{ Distance = 80, Material = Enum.Material.Metal, Offset = 22 },
		{ Distance = 165, Material = Enum.Material.Brick, Offset = -26 },
	}

	for index, wall in ipairs(wallMaterials) do
		newPart({
			Name = "RangeWall" .. index,
			Size = Vector3.new(18, 14, 2),
			CFrame = CFrame.new(origin + Vector3.new(wall.Offset, 7, -wall.Distance)),
			Color = Color3.fromRGB(120, 118, 112),
			Material = wall.Material,
			Parent = workspace,
		})
	end

	-- Мишени разной дальности.
	for index, distance in ipairs(Settings.TestRange.DummyDistances) do
		createDummy(origin + Vector3.new((index % 2 == 0) and 6 or -6, 0, -distance))
	end

	-- Тонкая пластина для проверки оптики на дальней дистанции.
	newPart({
		Name = "RangeScopeTarget",
		Size = Vector3.new(3, 3, 0.4),
		CFrame = CFrame.new(origin + Vector3.new(0, 4, -Settings.TestRange.DummyDistances[#Settings.TestRange.DummyDistances] - 60)),
		Color = Color3.fromRGB(200, 60, 40),
		Material = Enum.Material.Neon,
		Parent = workspace,
	})

	if Settings.Debug then
		print("[TestRange] Полигон готов: platform=", platform.Name)
	end

	return platform
end

return TestRange

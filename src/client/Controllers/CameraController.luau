--!nonstrict
-- Камера: вид от третьего/первого лица, прицеливание, отдача.
-- Персонаж всегда развёрнут туда, куда смотрит камера (как в шутерах),
-- поэтому стрельба и модель оружия живут в одной системе координат.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Config.Settings)

local CameraController = {}
CameraController.__index = CameraController

local VIEW = Settings.View

function CameraController.new()
	local self = setmetatable({}, CameraController)

	self.Mode = VIEW.DefaultMode
	self.Aiming = false
	self.Zoom = 1
	self.Pitch = 0
	self.Yaw = 0
	self.RecoilPitch = 0
	self.RecoilYaw = 0

	return self
end

function CameraController:getMode()
	return self.Mode
end

function CameraController:setMode(mode)
	if mode ~= "FirstPerson" and mode ~= "ThirdPerson" then
		return
	end
	if self.Mode == mode then
		return
	end

	self.Mode = mode
	self:applyVisibility()
end

function CameraController:setAiming(aiming)
	self.Aiming = aiming and true or false
end

function CameraController:isAiming()
	return self.Aiming
end

function CameraController:setZoom(zoom)
	self.Zoom = zoom or 1
end

-- Отдача: подброс камеры за выстрел (в градусах), возвращается экспоненциально.
function CameraController:addRecoil(vertical, horizontal)
	self.RecoilPitch += math.rad(vertical or 0)
	local sign = math.random() < 0.5 and -1 or 1
	self.RecoilYaw += math.rad((horizontal or 0) * sign)
end

function CameraController:getEyePosition()
	local character = Players.LocalPlayer.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return nil
	end
	return head.Position + VIEW.FirstPersonEyeOffset
end

-- Луч из центра экрана: им пользуется стрельба.
function CameraController:getAimRay()
	local camera = workspace.CurrentCamera
	if not camera then
		return nil, nil
	end
	return camera.CFrame.Position, camera.CFrame.LookVector
end

function CameraController:applyVisibility()
	local character = Players.LocalPlayer.Character
	if not character then
		return
	end

	local hide = self.Mode == "FirstPerson"
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if descendant.Name ~= "HumanoidRootPart" then
				descendant.LocalTransparencyModifier = hide and 1 or 0
			end
		elseif descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = hide and 1 or 0
		end
	end
end

function CameraController:start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == VIEW.ToggleModeKey then
			self:setMode(self.Mode == "FirstPerson" and "ThirdPerson" or "FirstPerson")
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
			return
		end

		local sensitivity = math.rad(VIEW.Sensitivity)
		self.Yaw = (self.Yaw - input.Delta.X * sensitivity + math.pi) % (math.pi * 2) - math.pi
		self.Pitch = math.clamp(self.Pitch - input.Delta.Y * sensitivity, -VIEW.MaxPitch, VIEW.MaxPitch)
	end)

	local function onCharacter(character)
		self.Pitch = 0
		self.Yaw = 0
		self.RecoilPitch = 0
		self.RecoilYaw = 0

		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid.AutoRotate = false
		end

		task.defer(function()
			self:applyVisibility()
		end)
	end

	Players.LocalPlayer.CharacterAdded:Connect(onCharacter)

	-- Скрипт может стартовать уже после спавна персонажа — обрабатываем и этот случай.
	if Players.LocalPlayer.Character then
		task.spawn(onCharacter, Players.LocalPlayer.Character)
	end

	RunService.RenderStepped:Connect(function(deltaTime)
		self:step(deltaTime)
	end)
end

function CameraController:resolveCameraCollision(eye, desired, character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true

	local result = workspace:Spherecast(eye, VIEW.CameraCollisionRadius, desired - eye, params)
	if result then
		return result.Position
	end

	return desired
end

function CameraController:step(deltaTime)
	local player = Players.LocalPlayer
	local character = player.Character
	local camera = workspace.CurrentCamera
	if not character or not camera then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not head or not root or humanoid.Health <= 0 then
		return
	end

	if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end

	local recovery = math.exp(-Settings.Recoil.Recovery * deltaTime)
	self.RecoilPitch *= recovery
	self.RecoilYaw *= recovery

	local rotation = CFrame.fromEulerAnglesYXZ(self.Pitch + self.RecoilPitch, self.Yaw + self.RecoilYaw, 0)

	-- Персонаж разворачивается по горизонтали вслед за камерой.
	root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, self.Yaw, 0)

	local eye = head.Position + VIEW.FirstPersonEyeOffset
	local targetFov = self.Aiming and VIEW.BaseFov / math.max(self.Zoom, 0.1) or VIEW.BaseFov
	camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(deltaTime * 12, 1)
	camera.CameraType = Enum.CameraType.Scriptable

	if self.Mode == "FirstPerson" then
		camera.CFrame = CFrame.new(eye) * rotation
		return
	end

	local offset = self.Aiming and VIEW.ThirdPersonAimOffset or VIEW.ThirdPersonOffset
	local desired = self:resolveCameraCollision(eye, eye + rotation * offset.Position, character)
	local aimPoint = eye + rotation.LookVector * 200
	local target = CFrame.lookAt(desired, aimPoint)

	camera.CFrame = camera.CFrame:Lerp(target, math.min(deltaTime * VIEW.CameraLerp, 1))
end

return CameraController


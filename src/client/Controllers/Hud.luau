--!nonstrict
-- HUD: прицел, патроны, режим огня, перезарядка, маркер попадания.
-- Всё строится кодом — не нужен отдельный .rbxm интерфейса.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Hud = {}
Hud.__index = Hud

local FONT = Enum.Font.GothamMedium
local ACCENT = Color3.fromRGB(255, 208, 120)

local function label(parent, size, position, textSize, alignment)
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = size
	textLabel.Position = position
	textLabel.Font = FONT
	textLabel.TextSize = textSize
	textLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
	textLabel.TextStrokeTransparency = 0.6
	textLabel.TextXAlignment = alignment or Enum.TextXAlignment.Right
	textLabel.Text = ""
	textLabel.Parent = parent
	return textLabel
end

function Hud.new()
	local self = setmetatable({}, Hud)

	local gui = Instance.new("ScreenGui")
	gui.Name = "WeaponHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.gui = gui

	-- Прицел: четыре линии + точка.
	local crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Size = UDim2.fromOffset(0, 0)
	crosshair.BackgroundTransparency = 1
	crosshair.Parent = gui
	self.crosshair = crosshair

	local function line(name, size, anchor, position)
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.Size = size
		frame.AnchorPoint = anchor
		frame.Position = position
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		frame.BackgroundTransparency = 0.15
		frame.BorderSizePixel = 0
		frame.Parent = crosshair
		return frame
	end

	self.lines = {
		Top = line("Top", UDim2.fromOffset(2, 10), Vector2.new(0.5, 1), UDim2.new(0.5, 0, 0.5, -4)),
		Bottom = line("Bottom", UDim2.fromOffset(2, 10), Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0.5, 4)),
		Left = line("Left", UDim2.fromOffset(10, 2), Vector2.new(1, 0.5), UDim2.new(0.5, -4, 0.5, 0)),
		Right = line("Right", UDim2.fromOffset(10, 2), Vector2.new(0, 0.5), UDim2.new(0.5, 4, 0.5, 0)),
	}

	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(2, 2)
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.BorderSizePixel = 0
	dot.Parent = crosshair
	self.dot = dot

	-- Оптический прицел: чёрная виньетка с «линзой» по центру и крестом.
	-- Включается для модулей со ScopeOverlay (ACOG, Оптика 8x) при прицеливании.
	local scope = Instance.new("Frame")
	scope.Name = "ScopeOverlay"
	scope.Size = UDim2.fromScale(1, 1)
	scope.BackgroundTransparency = 1
	scope.Visible = false
	scope.ZIndex = 10
	scope.Parent = gui
	self.scope = scope

	self.scopeBorders = {}
	for _, side in ipairs({ "Top", "Bottom", "Left", "Right" }) do
		local border = Instance.new("Frame")
		border.Name = side
		border.BackgroundColor3 = Color3.new(0, 0, 0)
		border.BorderSizePixel = 0
		border.Parent = scope
		self.scopeBorders[side] = border
	end

	local scopeCrosshair = Instance.new("Frame")
	scopeCrosshair.Name = "ScopeCrosshair"
	scopeCrosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	scopeCrosshair.Position = UDim2.fromScale(0.5, 0.5)
	scopeCrosshair.Size = UDim2.fromOffset(0, 0)
	scopeCrosshair.BackgroundTransparency = 1
	scopeCrosshair.ZIndex = 11
	scopeCrosshair.Parent = scope
	self.scopeCrosshair = scopeCrosshair

	for _, axis in ipairs({ "H", "V" }) do
		local scopeLine = Instance.new("Frame")
		scopeLine.AnchorPoint = Vector2.new(0.5, 0.5)
		scopeLine.Position = UDim2.fromScale(0.5, 0.5)
		scopeLine.BackgroundColor3 = Color3.new(0.03, 0.03, 0.03)
		scopeLine.BorderSizePixel = 0
		if axis == "H" then
			scopeLine.Size = UDim2.fromOffset(360, 1)
		else
			scopeLine.Size = UDim2.fromOffset(1, 360)
		end
		scopeLine.Parent = scopeCrosshair
	end

	-- Панель оружия.
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -24, 1, -20)
	panel.Size = UDim2.fromOffset(260, 116)
	panel.BackgroundTransparency = 1
	panel.Parent = gui

	self.weaponName = label(panel, UDim2.fromOffset(260, 20), UDim2.fromOffset(0, 0), 18)
	self.fireMode = label(panel, UDim2.fromOffset(260, 16), UDim2.fromOffset(0, 22), 13)
	self.fireMode.TextColor3 = ACCENT
	self.ammo = label(panel, UDim2.fromOffset(260, 34), UDim2.fromOffset(0, 40), 30)
	self.attachments = label(panel, UDim2.fromOffset(260, 14), UDim2.fromOffset(0, 96), 12)
	self.attachments.TextColor3 = Color3.fromRGB(170, 170, 170)

	-- Полоса перезарядки.
	local reloadBar = Instance.new("Frame")
	reloadBar.Name = "ReloadBar"
	reloadBar.AnchorPoint = Vector2.new(0.5, 1)
	reloadBar.Position = UDim2.new(0.5, 0, 1, -120)
	reloadBar.Size = UDim2.fromOffset(180, 4)
	reloadBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	reloadBar.BorderSizePixel = 0
	reloadBar.Visible = false
	reloadBar.Parent = gui

	local reloadFill = Instance.new("Frame")
	reloadFill.Name = "Fill"
	reloadFill.Size = UDim2.fromScale(0, 1)
	reloadFill.BackgroundColor3 = ACCENT
	reloadFill.BorderSizePixel = 0
	reloadFill.Parent = reloadBar

	self.reloadBar = reloadBar
	self.reloadFill = reloadFill

	self.hitmarkerFrame = Instance.new("Frame")
	self.hitmarkerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	self.hitmarkerFrame.Position = UDim2.fromScale(0.5, 0.5)
	self.hitmarkerFrame.Size = UDim2.fromOffset(26, 26)
	self.hitmarkerFrame.BackgroundTransparency = 1
	self.hitmarkerFrame.Visible = false
	self.hitmarkerFrame.Parent = gui

	local function hitLine(rotation)
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.5)
		frame.Size = UDim2.fromOffset(2, 12)
		frame.Rotation = rotation
		frame.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
		frame.BorderSizePixel = 0
		frame.Parent = self.hitmarkerFrame
		return frame
	end

	self.hitLines = { hitLine(45), hitLine(-45) }

	self.hitmarkerToken = 0
	return self
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Attachments = require(ReplicatedStorage.Shared.Config.Attachments)

function Hud:setWeapon(identifier, stats, attachments)
	if not stats or stats.Class == "Melee" then
		self.weaponName.Text = (stats and stats.DisplayName) or identifier or "Ближний бой"
		self.fireMode.Text = "БЛИЖНИЙ БОЙ"
		self.ammo.Text = ""
		self.attachments.Text = ""
		return
	end

	self.weaponName.Text = stats.DisplayName or identifier
	self:setFireMode(stats.FireModes and stats.FireModes[1])

	local names = {}
	for _, category in ipairs(Attachments.Categories or {}) do
		local attachmentId = attachments and attachments[category]
		local item = attachmentId and Attachments.get(attachmentId)
		if item then
			table.insert(names, item.DisplayName or attachmentId)
		end
	end

	self.attachments.Text = table.concat(names, " · ")
end

function Hud:setFireMode(mode)
	local names = { Auto = "АВТО", Semi = "ОДИНОЧНЫЙ", Burst = "ОЧЕРЕДЬ" }
	self.fireMode.Text = names[mode] or (mode or "")
end

function Hud:setAmmo(ammo, reserve, reloading)
	ammo = ammo or 0
	reserve = reserve or 0
	self.ammo.Text = string.format("%d / %d", ammo, reserve)
	self.ammo.TextColor3 = ammo <= 0 and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(240, 240, 240)
	if reloading then
		self.fireMode.Text = "ПЕРЕЗАРЯДКА"
	end
end

-- Прицел «раскрывается» вместе с разбросом.
function Hud:setSpread(degrees)
	local gap = math.clamp(4 + (degrees or 0) * 3.5, 4, 60)
	self.lines.Top.Position = UDim2.new(0.5, 0, 0.5, -gap)
	self.lines.Bottom.Position = UDim2.new(0.5, 0, 0.5, gap)
	self.lines.Left.Position = UDim2.new(0.5, -gap, 0.5, 0)
	self.lines.Right.Position = UDim2.new(0.5, gap, 0.5, 0)
end

function Hud:setCrosshairVisible(visible)
	self.crosshair.Visible = visible
end

function Hud:setReloading(duration)
	if not duration or duration <= 0 then
		self.reloadBar.Visible = false
		return
	end

	self.reloadToken = (self.reloadToken or 0) + 1
	local token = self.reloadToken

	self.reloadBar.Visible = true
	self.reloadFill.Size = UDim2.fromScale(0, 1)
	local tween = TweenService:Create(
		self.reloadFill,
		TweenInfo.new(duration, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(1, 1) }
	)
	tween:Play()

	task.delay(duration, function()
		if self.reloadToken == token then
			self.reloadBar.Visible = false
		end
	end)
end

function Hud:hitmarker()
	self.hitmarkerToken += 1
	local token = self.hitmarkerToken
	self.hitmarkerFrame.Visible = true

	task.delay(0.12, function()
		if self.hitmarkerToken == token then
			self.hitmarkerFrame.Visible = false
		end
	end)
end

-- Оптический прицел: по центру остаётся «линза», вокруг — чёрная виньетка.
function Hud:updateScopeLayout()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local width = camera.ViewportSize.X
	local height = camera.ViewportSize.Y
	local lens = math.min(360, math.floor(width * 0.5), math.floor(height * 0.5))
	local top = math.floor((height - lens) / 2)
	local left = math.floor((width - lens) / 2)

	self.scopeBorders.Top.Size = UDim2.fromOffset(width, math.max(0, top))
	self.scopeBorders.Top.Position = UDim2.fromOffset(0, 0)

	self.scopeBorders.Bottom.Size = UDim2.fromOffset(width, math.max(0, top))
	self.scopeBorders.Bottom.Position = UDim2.fromOffset(0, top + lens)

	self.scopeBorders.Left.Size = UDim2.fromOffset(math.max(0, left), lens)
	self.scopeBorders.Left.Position = UDim2.fromOffset(0, top)

	self.scopeBorders.Right.Size = UDim2.fromOffset(math.max(0, left), lens)
	self.scopeBorders.Right.Position = UDim2.fromOffset(left + lens, top)
end

function Hud:setScopeVisible(visible)
	self.scope.Visible = visible and true or false
	if visible then
		self:updateScopeLayout()
	end
end

return Hud


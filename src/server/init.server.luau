--!nonstrict
-- Точка входа сервера: сеть, сервисы, тестовый полигон.
-- Порядок важен: Net.serverInit() должен создать ремоуты до запуска сервисов.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Settings = require(Shared.Config.Settings)
local Net = require(Shared.Net)

Net.serverInit()

local Services = script:WaitForChild("Services")
local HitboxHistory = require(Services.HitboxHistory)
local MeleeService = require(Services.MeleeService)
local WeaponService = require(Services.WeaponService)
local TestRange = require(Services.TestRange)

if Settings.BuildTestRange then
	TestRange.build()
end

HitboxHistory.start()
MeleeService.start()
WeaponService.start()

local function onCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.WalkSpeed = Settings.Character.WalkSpeed
	end
end

local function onPlayer(player)
	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end

if Settings.Debug then
	print("[Server] RobloxStrike запущен")
end

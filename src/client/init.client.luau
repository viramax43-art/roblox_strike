--!nonstrict
-- Клиентский вход: собирает контроллеры, связывает их между собой и запускает.
-- Порядок важен: Net первым (он дождётся ремоутов), затем визуал/HUD,
-- и только потом ввод и предсказание стрельбы.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Settings = require(Shared.Config.Settings)
local Net = require(Shared.Net)

local Controllers = script:WaitForChild("Controllers")
local CameraController = require(Controllers:WaitForChild("CameraController"))
local EffectsController = require(Controllers:WaitForChild("EffectsController"))
local Hud = require(Controllers:WaitForChild("Hud"))
local ViewModelController = require(Controllers:WaitForChild("ViewModelController"))
local WeaponController = require(Controllers:WaitForChild("WeaponController"))

local player = Players.LocalPlayer
player:WaitForChild("PlayerGui")

local cameraController = CameraController.new()
local effects = EffectsController.new()
local hud = Hud.new()
local viewModel = ViewModelController.new(cameraController)
local weapons = WeaponController.new(cameraController, viewModel, effects, hud)

-- Камера и модель в руках не зависят от сети — запускаем сразу.
cameraController:start()
viewModel:start()

-- Визуал от сервера: трейсеры чужих выстрелов, вспышки, взмахи.
Net.onEffect(function(payload)
	effects:handle(payload)
end)

weapons:start()

if Settings.Debug then
	print("[Client] контроллеры запущены")
end

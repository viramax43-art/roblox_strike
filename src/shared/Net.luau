--!nonstrict
-- Сетевой слой: три канала вместо россыпи ремоутов.
-- Action  — клиент -> сервер (надёжный)
-- State   — сервер -> клиент (надёжный: патроны, экипировка, подтверждение попаданий)
-- Effect  — сервер -> клиент (ненадёжный: трейсеры, вспышки; потеря не критична)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Settings = require(ReplicatedStorage.Shared.Config.Settings)

local Net = {}

local REMOTES = {
	Action = { Key = Settings.Net.ActionRemote, Unreliable = false },
	State = { Key = Settings.Net.StateRemote, Unreliable = false },
	Effect = { Key = Settings.Net.EffectRemote, Unreliable = true },
}

local cache = {}

local function createRemote(definition)
	if definition.Unreliable then
		local ok, instance = pcall(Instance.new, "UnreliableRemoteEvent")
		if ok and instance then
			return instance
		end
	end
	return Instance.new("RemoteEvent")
end

local function findOrCreate(folder, definition)
	local existing = folder:FindFirstChild(definition.Key)
	if existing then
		return existing
	end

	local remote = createRemote(definition)
	remote.Name = definition.Key
	remote.Parent = folder
	return remote
end

local function getFolder()
	return ReplicatedStorage:FindFirstChild(Settings.Net.FolderName)
end

-- Вызывается один раз на сервере, до подключения игроков.
function Net.serverInit()
	local folder = getFolder()
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Settings.Net.FolderName
		folder.Parent = ReplicatedStorage
	end

	for key, definition in pairs(REMOTES) do
		cache[key] = findOrCreate(folder, definition)
	end
end

function Net.get(key)
	local cached = cache[key]
	if cached then
		return cached
	end

	local definition = REMOTES[key]
	assert(definition, "Net: неизвестный канал " .. tostring(key))

	local folder = getFolder() or ReplicatedStorage:WaitForChild(Settings.Net.FolderName, 30)
	assert(
		folder,
		"Net: нет папки " .. Settings.Net.FolderName .. " (сервер не инициализирован?)"
	)

	local remote = folder:FindFirstChild(definition.Key)
	if not remote then
		remote = folder:WaitForChild(definition.Key, 30)
	end
	assert(remote, "Net: нет ремоута " .. definition.Key)

	cache[key] = remote
	return remote
end

local function safeFire(fireFn, ...)
	local ok, err = pcall(fireFn, ...)
	if not ok and Settings.Debug then
		warn("Net: не удалось отправить пакет — " .. tostring(err))
	end
end

-- client -> server
function Net.toServer(payload)
	local remote = Net.get("Action")
	safeFire(function()
		remote:FireServer(payload)
	end)
end

-- server -> client
function Net.toClient(player, payload)
	if not player or not player.Parent then
		return
	end
	local remote = Net.get("State")
	safeFire(function()
		remote:FireClient(player, payload)
	end)
end

function Net.toAll(payload, excluded)
	local remote = Net.get("State")
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= excluded then
			safeFire(function()
				remote:FireClient(player, payload)
			end)
		end
	end
end

-- server -> client, ненадёжный канал (визуал)
function Net.effectToAll(payload, excluded)
	local remote = Net.get("Effect")
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= excluded then
			safeFire(function()
				remote:FireClient(player, payload)
			end)
		end
	end
end

function Net.effectToClient(player, payload)
	if not player or not player.Parent then
		return
	end
	local remote = Net.get("Effect")
	safeFire(function()
		remote:FireClient(player, payload)
	end)
end

function Net.onAction(callback)
	Net.get("Action").OnServerEvent:Connect(function(player, payload)
		callback(player, payload)
	end)
end

function Net.onState(callback)
	Net.get("State").OnClientEvent:Connect(callback)
end

function Net.onEffect(callback)
	Net.get("Effect").OnClientEvent:Connect(callback)
end

return Net

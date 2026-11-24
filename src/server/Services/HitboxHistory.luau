--!nonstrict
-- Лаг-компенсация: храним историю положений хитбоксов персонажей.
-- Перед выстрелом откатываем чужие хитбоксы на момент выстрела клиента,
-- стреляем, сразу возвращаем всё назад. Так попадания честные для игрока с пингом.
--
-- Важно: откат двигает реальные части на сервере, но ровно на один кадр
-- и только на сервере, клиенты видят это как обычную репликацию движения.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Settings = require(ReplicatedStorage.Shared.Config.Settings)

local HitboxHistory = {}

local history = {} -- [player] = { Samples = { { Time, Parts, Frames } }, Parts = {BasePart} }
local lastSampleTime = {}

local function collectParts(character)
	local parts = {}
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function sample(player)
	local character = player.Character
	if not character or not character.Parent then
		history[player] = nil
		return
	end

	local entry = history[player]
	if not entry then
		entry = { Samples = {}, Parts = {} }
		history[player] = entry
	end

	local parts = collectParts(character)
	local frames = {}
	for _, part in ipairs(parts) do
		frames[part] = part.CFrame
	end

	table.insert(entry.Samples, {
		Time = workspace:GetServerTimeNow(),
		Parts = parts,
		Frames = frames,
	})
	entry.Parts = parts

	local cutoff = workspace:GetServerTimeNow() - Settings.LagCompensation.HistorySeconds
	while #entry.Samples > 2 and entry.Samples[1].Time < cutoff do
		table.remove(entry.Samples, 1)
	end
end

local function findSample(player, timestamp)
	local entry = history[player]
	if not entry or #entry.Samples == 0 then
		return nil
	end

	local best = entry.Samples[1]
	for index = #entry.Samples, 1, -1 do
		local candidate = entry.Samples[index]
		if candidate.Time <= timestamp then
			best = candidate
			break
		end
	end

	return best
end

function HitboxHistory.start()
	local interval = Settings.LagCompensation.SampleInterval
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			local last = lastSampleTime[player] or 0
			if now - last >= interval then
				lastSampleTime[player] = now
				sample(player)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		history[player] = nil
		lastSampleTime[player] = nil
	end)
end

-- Сколько откатывать: половина RTT (пинг игрока) + один серверный кадр.
function HitboxHistory.getRewindSeconds(player)
	if not Settings.LagCompensation.Enabled then
		return 0
	end

	local ping = 0
	local ok, value = pcall(function()
		return player:GetNetworkPing()
	end)
	if ok and type(value) == "number" then
		ping = value
	end

	local rewind = ping + 1 / 60
	return math.clamp(rewind, 0, Settings.LagCompensation.MaxRewindSeconds)
end

-- Откатывает хитбоксы всех, кроме самого стрелка.
-- Возвращает функцию восстановления — её нужно вызвать сразу после трассировки.
function HitboxHistory.beginRewind(shooter, rewindSeconds)
	local restores = {}
	if rewindSeconds <= 0 then
		return function() end
	end

	local targetTime = workspace:GetServerTimeNow() - rewindSeconds
	local shooterCharacter = shooter.Character

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= shooter and player.Character and player.Character ~= shooterCharacter then
			local sampleData = findSample(player, targetTime)
			if sampleData then
				for part, cframe in pairs(sampleData.Frames) do
					if part.Parent and part.CFrame ~= cframe then
						restores[part] = part.CFrame
						part.CFrame = cframe
					end
				end
			end
		end
	end

	return function()
		for part, cframe in pairs(restores) do
			if part.Parent then
				part.CFrame = cframe
			end
		end
	end
end

function HitboxHistory.clear(player)
	history[player] = nil
	lastSampleTime[player] = nil
end

return HitboxHistory

--!nonstrict
-- Баллистика пуль: полёт с гравитацией, разброс, трассировка по сегментам.
-- Модуль общий для сервера и клиента: сервер считает попадания, клиент — предсказание.
-- Это ключевое свойство: одинаковая математика = одинаковый результат при одном seed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Config.Settings)
local SeededRandom = require(ReplicatedStorage.Shared.SeededRandom)

local Ballistics = {}

local UP = Vector3.new(0, 1, 0)
local FALLBACK_UP = Vector3.new(0, 0, 1)

function Ballistics.getGravity(gravityScale)
	return Vector3.new(0, -Settings.Ballistics.Gravity * (gravityScale or 1), 0)
end

-- Ортонормированный базис вокруг направления полёта.
function Ballistics.basis(direction)
	local forward = direction.Unit
	local up = UP
	if math.abs(forward:Dot(up)) > 0.999 then
		up = FALLBACK_UP
	end

	local right = forward:Cross(up).Unit
	local realUp = right:Cross(forward).Unit
	return forward, right, realUp
end

-- Отклонение направления внутри конуса. Угол задан в градусах.
-- Порядок вызовов rng фиксирован: сначала угол, потом радиус.
function Ballistics.applySpread(direction, spreadDegrees, rng)
	local forward = direction.Unit
	if not spreadDegrees or spreadDegrees <= 0 then
		return forward
	end

	local _, right, up = Ballistics.basis(forward)
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = math.tan(math.rad(spreadDegrees)) * math.sqrt(rng:NextNumber(0, 1))
	local offset = right * (math.cos(angle) * radius) + up * (math.sin(angle) * radius)

	return (forward + offset).Unit
end

-- Один шаг интегрирования: позиция и скорость через dt.
function Ballistics.step(position, velocity, gravity, dt)
	local nextPosition = position + velocity * dt + gravity * (0.5 * dt * dt)
	local nextVelocity = velocity + gravity * dt
	return nextPosition, nextVelocity
end

-- Трассировка пули.
-- raycastFn(origin, target) -> RaycastResult?  (обёртка над workspace:Raycast)
-- Возвращает Trace: путь (точки), конечную точку, нормаль, время полёта, дистанцию.
function Ballistics.trace(params, raycastFn)
	local origin = params.Origin
	local direction = params.Direction.Unit
	local muzzleVelocity = params.MuzzleVelocity
	local gravity = Ballistics.getGravity(params.GravityScale)
	local stepTime = params.StepTime or Settings.Ballistics.StepTime
	local maxSteps = params.MaxSteps or Settings.Ballistics.MaxSteps
	local maxRange = params.MaxRange or math.huge

	local position = origin
	local velocity = direction * muzzleVelocity
	local points = { position }

	local travelled = 0
	local elapsed = 0
	local hit = nil
	local impacted = false
	local normal = UP

	for _ = 1, maxSteps do
		local nextPosition = Ballistics.step(position, velocity, gravity, stepTime)
		local segment = (nextPosition - position).Magnitude

		if segment > 1e-4 then
			local result = raycastFn(position, nextPosition)
			if result then
				local hitDistance = (result.Position - position).Magnitude
				elapsed += (hitDistance / segment) * stepTime
				travelled += hitDistance
				position = result.Position
				table.insert(points, position)

				hit = result
				impacted = true
				normal = result.Normal
				break
			end
		end

		elapsed += stepTime
		travelled += segment
		position = nextPosition
		velocity += gravity * stepTime
		table.insert(points, position)

		if travelled >= maxRange then
			break
		end
	end

	return {
		Origin = origin,
		Direction = direction,
		Points = points,
		End = position,
		Normal = normal,
		Hit = hit,
		Impacted = impacted,
		Distance = travelled,
		Time = math.max(elapsed, stepTime),
	}
end

-- Точка на траектории по коэффициенту 0..1 (для визуализации трейсера).
function Ballistics.pointOnPath(points, alpha)
	local count = #points
	if count == 0 then
		return Vector3.zero
	end
	if count == 1 then
		return points[1]
	end

	local clamped = math.clamp(alpha, 0, 1)
	local scaled = clamped * (count - 1)
	local index = math.floor(scaled)
	local fraction = scaled - index
	local first = points[math.clamp(index + 1, 1, count)]
	local second = points[math.clamp(index + 2, 1, count)]

	return first:Lerp(second, fraction)
end

-- Разброс для конкретного выстрела: учитывает стойку и состояние движения.
function Ballistics.getSpread(stats, stance, movement)
	local base = stats.Spread.Hip
	if stance == "Aim" then
		base = stats.Spread.Ads
	end

	movement = movement or {}
	local multiplier = 1
	if movement.Moving then
		multiplier *= Settings.Spread.MoveMultiplier
	end
	if movement.Sprinting then
		multiplier *= Settings.Spread.SprintMultiplier
	end
	if movement.Airborne then
		multiplier *= Settings.Spread.AirMultiplier
	end
	if movement.Crouching then
		multiplier *= Settings.Spread.CrouchMultiplier
	end

	return base * multiplier
end

-- Детерминированный разброс для одного патрона (дробь/пуля).
function Ballistics.spreadDirection(baseDirection, spreadDegrees, rng)
	return Ballistics.applySpread(baseDirection, spreadDegrees, rng)
end

function Ballistics.newRng(seed)
	return SeededRandom.new(seed)
end

return Ballistics

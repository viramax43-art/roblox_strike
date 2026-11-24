--!nonstrict
-- Детерминированный ГПСЧ.
-- Клиент и сервер получают одинаковые разбросы, если создают Random с одним seed
-- и вызывают методы в одинаковом порядке.

local SeededRandom = {}
SeededRandom.__index = SeededRandom

function SeededRandom.new(seed)
	local safeSeed = math.floor(tonumber(seed) or 0) % 2147483647
	if safeSeed <= 0 then
		safeSeed = safeSeed + 2147483646
	end

	return setmetatable({
		_rng = Random.new(safeSeed),
		Seed = safeSeed,
	}, SeededRandom)
end

function SeededRandom:NextNumber(minimum, maximum)
	return self._rng:NextNumber(minimum or 0, maximum or 1)
end

function SeededRandom:NextInteger(minimum, maximum)
	return self._rng:NextInteger(minimum, maximum)
end

return SeededRandom

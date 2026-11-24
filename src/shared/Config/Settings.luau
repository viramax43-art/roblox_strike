--!nonstrict
-- Глобальные настройки проекта.
-- Всё, что может понадобиться менять без правки логики, живёт здесь.

local Settings = {}

Settings.Debug = true

-- Порядок слотов = порядок клавиш 1, 2, 3.
Settings.DefaultLoadout = { "MAC10", "SPAS12", "Machete" }

-- Тестовый полигон (стенд, мишени). На проде выключить.
Settings.BuildTestRange = true
Settings.TestRange = {
	Origin = Vector3.new(0, 0, 0),
	DummyDistances = { 25, 70, 140, 240 },
	-- Высота глаз стрелка для замеров на стенде
	EyeHeight = 5,
}

Settings.Net = {
	FolderName = "WeaponRemotes",
	ActionRemote = "WeaponAction", -- client -> server, reliable
	StateRemote = "WeaponState", -- server -> client, reliable (патроны, экипировка, хиты)
	EffectRemote = "WeaponEffect", -- server -> client, unreliable (трейсеры, вспышки)
}

Settings.Character = {
	WalkSpeed = 16,
	SprintSpeed = 24,
	SprintKey = Enum.KeyCode.LeftShift,
}

-- Камера и режимы обзора.
Settings.View = {
	DefaultMode = "ThirdPerson", -- "ThirdPerson" | "FirstPerson"
	ToggleModeKey = Enum.KeyCode.V,

	-- Плечевая камера (TPS)
	ThirdPersonOffset = CFrame.new(1.9, 2.1, 6.8),
	ThirdPersonAimOffset = CFrame.new(1.0, 1.5, 3.4),
	-- Глаза (FPS)
	FirstPersonEyeOffset = Vector3.new(0, 0.3, 0),

	BaseFov = 70,
	MaxPitch = math.rad(85),
	Sensitivity = 0.35, -- градусов на пиксель движения мыши
	CameraCollisionRadius = 0.8,
	CameraLerp = 18,
}

-- Разброс: множители к базовому разбросу оружия.
Settings.Spread = {
	MoveMultiplier = 1.9,
	SprintMultiplier = 3.2,
	AirMultiplier = 2.6,
	CrouchMultiplier = 0.7,
}

Settings.Recoil = {
	Recovery = 9, -- скорость возврата камеры
	ShakeDecay = 7,
}

Settings.Ballistics = {
	StepTime = 1 / 90,
	MaxSteps = 600,
	Gravity = 196.2, -- studs/s^2, масштабируется полем GravityScale у оружия
}

-- Ограничения, чтобы клиент не мог стрелять быстрее/дальше, чем позволено.
Settings.AntiCheat = {
	MaxOriginDistance = 8, -- насколько точка выстрела может быть от персонажа
	FireRateSlack = 0.85, -- допуск по скорострельности (0.85 = на 15% быстрее)
	MinFireInterval = 0.02,
	MaxShotsPerSecond = 40,
	MaxPelletsPerShot = 16,
}

Settings.LagCompensation = {
	Enabled = true,
	MaxRewindSeconds = 0.2,
	HistorySeconds = 1,
	SampleInterval = 1 / 30,
}

Settings.Prediction = {
	Enabled = true, -- локальный трейсер и попадания до ответа сервера
	MaxTracers = 32,
}

Settings.FriendlyFire = false

-- Модель оружия в руках (viewmodel). Крепления подбираются под конкретные модели,
-- поэтому все смещения вынесены сюда.
Settings.ViewModel = {
	BlendSpeed = 14, -- плавность перехода между позами
	-- От третьего лица: оружие крепится к правой руке
	ThirdPersonGrip = CFrame.new(0, -0.2, 0),
	-- От первого лица: оружие в кадре справа снизу
	FirstPersonHip = CFrame.new(0.55, -0.45, -1.2) * CFrame.Angles(0, math.rad(-4), 0),
	FirstPersonAim = CFrame.new(0, -0.22, -0.85),
}

Settings.Effects = {
	TracerLifetime = 1.2,
	ImpactLifetime = 1.5,
	MaxActiveImpacts = 48,
}

return Settings

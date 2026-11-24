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

	-- Плечевая камера (TPS), как в GTA: ближе к плечу, персонаж чуть левее центра.
	ThirdPersonOffset = CFrame.new(1.7, 1.9, 5.4),
	ThirdPersonAimOffset = CFrame.new(0.9, 1.4, 2.8),
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
	-- От третьего лица: оружие в руках персонажа, ствол целится в крестик.
	ThirdPersonHipDrop = -0.45, -- ниже руки при стрельбе от бедра
	ThirdPersonAimSide = 0.35, -- правее головы (плечо) при прицеливании
	ThirdPersonAimHeight = -0.35, -- ниже глаз при прицеливании
	-- От первого лица: оружие в кадре справа снизу.
	FirstPersonHip = CFrame.new(0.55, -0.45, -1.2),
	FirstPersonAim = CFrame.new(0, -0.22, -0.85),
}

Settings.Effects = {
	TracerLifetime = 1.2,
	ImpactLifetime = 1.5,
	MaxActiveImpacts = 48,
}

return Settings

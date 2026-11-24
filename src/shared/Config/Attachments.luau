--!nonstrict
-- Модули (обвесы). Каждый модуль — отдельный объект с набором модификаторов.
-- Новый модуль добавляется сюда, код менять не нужно.
--
-- Поддерживаемые модификаторы (все опциональны):
--   HipSpreadMultiplier, AdsSpreadMultiplier, SpreadMultiplier
--   RecoilMultiplier, MuzzleVelocityMultiplier, DamageMultiplier, RangeMultiplier
--   MagCapacityAdd, ReloadTimeMultiplier, ReloadTimeAdd
--   Zoom (множитель зума при прицеливании), ScopeOverlay (bool)
--   Sound = "Default" | "Suppressed"

local Attachments = {
	Categories = { "Scope", "Muzzle", "Underbarrel", "Magazine" },

	Items = {
		-- Прицелы
		IronSight = {
			Id = "IronSight",
			DisplayName = "Штатный прицел",
			Category = "Scope",
			AllowedClasses = { "*" },
			Modifiers = { Zoom = 1.15 },
		},
		RedDot = {
			Id = "RedDot",
			DisplayName = "Коллиматор",
			Category = "Scope",
			AllowedClasses = { "SMG", "AR", "Shotgun", "Pistol" },
			Modifiers = { Zoom = 1.3, AdsSpreadMultiplier = 0.9 },
		},
		Holo = {
			Id = "Holo",
			DisplayName = "Голографический",
			Category = "Scope",
			AllowedClasses = { "SMG", "AR", "Shotgun" },
			Modifiers = { Zoom = 1.45, AdsSpreadMultiplier = 0.88 },
		},
		Acog = {
			Id = "Acog",
			DisplayName = "ACOG 4x",
			Category = "Scope",
			AllowedClasses = { "AR", "Sniper" },
			Modifiers = { Zoom = 3.2, ScopeOverlay = true, AdsSpreadMultiplier = 0.75 },
		},
		SniperScope = {
			Id = "SniperScope",
			DisplayName = "Оптика 8x",
			Category = "Scope",
			AllowedClasses = { "Sniper" },
			Modifiers = { Zoom = 6, ScopeOverlay = true, AdsSpreadMultiplier = 0.5 },
		},

		-- Дульные
		Suppressor = {
			Id = "Suppressor",
			DisplayName = "Глушитель",
			Category = "Muzzle",
			AllowedClasses = { "SMG", "AR", "Pistol", "Sniper" },
			Modifiers = {
				MuzzleVelocityMultiplier = 0.82,
				RecoilMultiplier = 0.9,
				RangeMultiplier = 0.85,
				Sound = "Suppressed",
			},
		},
		MuzzleBrake = {
			Id = "MuzzleBrake",
			DisplayName = "Дульный тормоз",
			Category = "Muzzle",
			AllowedClasses = { "AR", "Sniper", "Shotgun" },
			Modifiers = { RecoilMultiplier = 0.8 },
		},
		Compensator = {
			Id = "Compensator",
			DisplayName = "Компенсатор",
			Category = "Muzzle",
			AllowedClasses = { "SMG", "AR", "Pistol" },
			Modifiers = { RecoilMultiplier = 0.85, AdsSpreadMultiplier = 0.92 },
		},

		-- Подствольные
		VerticalGrip = {
			Id = "VerticalGrip",
			DisplayName = "Вертикальная рукоятка",
			Category = "Underbarrel",
			AllowedClasses = { "SMG", "AR", "Shotgun" },
			Modifiers = { RecoilMultiplier = 0.8, AdsSpreadMultiplier = 0.9 },
		},
		AngledGrip = {
			Id = "AngledGrip",
			DisplayName = "Наклонная рукоятка",
			Category = "Underbarrel",
			AllowedClasses = { "SMG", "AR" },
			Modifiers = { HipSpreadMultiplier = 0.85, AdsSpreadMultiplier = 0.95 },
		},
		Laser = {
			Id = "Laser",
			DisplayName = "ЛЦУ",
			Category = "Underbarrel",
			AllowedClasses = { "*" },
			Modifiers = { HipSpreadMultiplier = 0.7 },
		},

		-- Магазины
		ExtendedMag = {
			Id = "ExtendedMag",
			DisplayName = "Увеличенный магазин",
			Category = "Magazine",
			AllowedClasses = { "SMG", "AR", "Pistol" },
			Modifiers = { MagCapacityAdd = 15, ReloadTimeMultiplier = 1.15 },
		},
		DrumMag = {
			Id = "DrumMag",
			DisplayName = "Барабан",
			Category = "Magazine",
			AllowedClasses = { "SMG", "AR" },
			Modifiers = { MagCapacityAdd = 45, ReloadTimeMultiplier = 1.45, RecoilMultiplier = 1.05 },
		},
		QuickMag = {
			Id = "QuickMag",
			DisplayName = "Быстрый магазин",
			Category = "Magazine",
			AllowedClasses = { "*" },
			Modifiers = { ReloadTimeMultiplier = 0.8 },
		},
	},
}

function Attachments.get(attachmentId)
	if not attachmentId then
		return nil
	end
	return Attachments.Items[attachmentId]
end

return Attachments

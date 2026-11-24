--!nonstrict
-- Ближний бой — отдельная механика (не стрельба), но живёт в той же системе слотов.

return {
	Machete = {
		Id = "Machete",
		DisplayName = "Мачете",
		Class = "Melee",
		Model = nil,
		Damage = 45,
		Rpm = 75,
		Range = 7,
		ConeAngle = 60, -- градусов: половина угла конуса удара
		BodyMultipliers = { Head = 1.6, Torso = 1, Arms = 0.9, Legs = 0.9 },
		Sounds = { Swing = "", Hit = "" },
	},

	Bita = {
		Id = "Bita",
		DisplayName = "Бита",
		Class = "Melee",
		Model = nil,
		Damage = 38,
		Rpm = 85,
		Range = 8,
		ConeAngle = 70,
		BodyMultipliers = { Head = 1.5, Torso = 1, Arms = 0.9, Legs = 0.9 },
		Sounds = { Swing = "", Hit = "" },
	},
}

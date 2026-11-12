-- ModuleScript: ReplicatedStorage > MapData
-- Configuração dos mapas. Para criar um mapa novo, copie o bloco "Ninja" e mude os valores.
-- Cada onda tem uma lista de tipos de inimigo. A última onda (a 5ª) é sempre o boss.

local MapData = {}

MapData.StartCountdown = 8      -- segundos de contagem antes de começar
MapData.PauseBetweenWaves = 4   -- segundos de descanso entre ondas

MapData.Maps = {
	Ninja = {
		Name = "Snake's Den",

		-- Count = quantos nascem; Extra = quantos a mais para cada jogador além do primeiro
		Waves = {
			{ Name = "Den Scientists", Enemies = {
				{ Look = "Cientista", Name = "Lab Scientist", Color = Color3.fromRGB(190, 225, 190), Health = 35, Damage = 4, Speed = 11, Count = 4, Extra = 2 },
			} },
			{ Name = "Sound Ninjas", Enemies = {
				{ Look = "Som", Name = "Sound Ninja", Color = Color3.fromRGB(85, 55, 120), Health = 50, Damage = 5, Speed = 15, Count = 5, Extra = 2 },
			} },
			{ Name = "Kab Clones", Enemies = {
				{ Look = "Clone", Name = "Kab Clone", Color = Color3.fromRGB(135, 145, 175), Health = 55, Damage = 6, Speed = 14, Count = 6, Extra = 2 },
			} },
			{ Name = "Team Taka", Enemies = {
				{ Look = "Taka", Name = "Taka: Blade", Color = Color3.fromRGB(210, 80, 40), Health = 85, Damage = 8, Speed = 16, Count = 1 },
				{ Look = "Taka", Name = "Taka: Brute", Color = Color3.fromRGB(150, 60, 40), Health = 170, Damage = 10, Speed = 10, Scale = 1.4, Count = 1 },
				{ Look = "Taka", Name = "Taka: Tracker", Color = Color3.fromRGB(225, 130, 60), Health = 60, Damage = 6, Speed = 18, Scale = 0.95, Count = 1 },
				{ Look = "Taka", Name = "Taka: Venomous", Color = Color3.fromRGB(125, 165, 60), Health = 75, Damage = 7, Speed = 14, Count = 1 },
			} },
		},

		-- Onda 5: o boss
		BossName = "White Snake",
		BossColor = Color3.fromRGB(45, 105, 60),
		BossHealth = 1000,
		BossDamage = 20,
		BossSlamEvery = 7,                         -- Golpe Venenoso (área em volta dele + poça de veneno)
		BossBiteEvery = 11,                        -- Mordidas de cobra (mira em cada jogador)
		BossSummonEvery = 13,                      -- invoca cobras
		SnakeName = "White Snake's Serpent",
		SnakeHealth = 25,
		SnakeDamage = 6,
		SnakeColor = Color3.fromRGB(50, 130, 70),

		RewardXP = 250,
		RewardCoins = 200,
	},

	-- Arena flutuante do Exame Ninja (mapa Mapa_ExameNinja). Boss sem tema de cobra.
	ExameNinja = {
		Name = "Ninja Exam",
		Arena = "Ninja", -- luta na arena Mapa_Ninja

		Waves = {
			{ Name = "Exam Candidates", Enemies = {
				{ Name = "Exam Candidate", Color = Color3.fromRGB(235, 215, 170), Health = 40, Damage = 4, Speed = 12, Count = 5, Extra = 2 },
			} },
			{ Name = "Rival Squads", Enemies = {
				{ Name = "Rival Genin", Color = Color3.fromRGB(60, 100, 170), Health = 55, Damage = 5, Speed = 15, Count = 5, Extra = 2 },
				{ Name = "Rival Scout", Color = Color3.fromRGB(95, 160, 210), Health = 40, Damage = 5, Speed = 18, Scale = 0.95, Count = 2, Extra = 1 },
			} },
			{ Name = "Masked Examiners", Enemies = {
				{ Name = "Masked Examiner", Color = Color3.fromRGB(90, 90, 105), Health = 70, Damage = 6, Speed = 16, Count = 6, Extra = 2 },
			} },
			{ Name = "Elite Jonin Squad", Enemies = {
				{ Name = "Jonin: Fang", Color = Color3.fromRGB(200, 200, 220), Health = 95, Damage = 8, Speed = 17, Count = 1 },
				{ Name = "Jonin: Bulwark", Color = Color3.fromRGB(120, 125, 140), Health = 190, Damage = 10, Speed = 10, Scale = 1.4, Count = 1 },
				{ Name = "Jonin: Whisper", Color = Color3.fromRGB(160, 190, 235), Health = 70, Damage = 7, Speed = 19, Scale = 0.95, Count = 1 },
				{ Name = "Jonin: Spark", Color = Color3.fromRGB(235, 205, 90), Health = 80, Damage = 8, Speed = 15, Count = 1 },
			} },
		},

		-- Onda 5: o boss
		BossName = "Grand Proctor",
		BossColor = Color3.fromRGB(70, 60, 95),
		BossHealth = 1400,
		BossDamage = 22,
		PlainBoss = true,                          -- sem enfeites de cobra
		BossScale = 2.3,
		BossSlamEvery = 8,
		BossBiteEvery = 12,
		BossSummonEvery = 14,
		SlamLabel = "Shockwave!",
		SlamColor = Color3.fromRGB(120, 170, 255),
		SlamPool = false,
		BiteLabel = "Watch out: kunai rain!",
		BiteColor = Color3.fromRGB(255, 200, 90),
		SummonLabel = " summons shadow shades!",
		Minion = { Name = "Proctor Shade", Color = Color3.fromRGB(45, 40, 60), Health = 30, Damage = 6, Speed = 20 },

		RewardXP = 400,
		RewardCoins = 300,
	},
}

return MapData

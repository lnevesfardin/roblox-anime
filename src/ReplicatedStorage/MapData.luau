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
			{ Name = "Lab Guinea Pigs", Enemies = {
				{ Name = "Lab Guinea Pig", Color = Color3.fromRGB(190, 225, 190), Health = 35, Damage = 4, Speed = 11, Count = 4, Extra = 2 },
			} },
			{ Name = "Sound Ninjas", Enemies = {
				{ Name = "Sound Ninja", Color = Color3.fromRGB(85, 55, 120), Health = 50, Damage = 5, Speed = 15, Count = 5, Extra = 2 },
			} },
			{ Name = "Kab Clones", Enemies = {
				{ Name = "Kab Clone", Color = Color3.fromRGB(135, 145, 175), Health = 55, Damage = 6, Speed = 14, Count = 6, Extra = 2 },
			} },
			{ Name = "Red Cloud Team", Enemies = {
				{ Name = "Red Cloud: Blade", Color = Color3.fromRGB(210, 80, 40), Health = 85, Damage = 8, Speed = 16, Count = 1 },
				{ Name = "Red Cloud: Brute", Color = Color3.fromRGB(150, 60, 40), Health = 170, Damage = 10, Speed = 10, Scale = 1.4, Count = 1 },
				{ Name = "Red Cloud: Tracker", Color = Color3.fromRGB(225, 130, 60), Health = 60, Damage = 6, Speed = 18, Scale = 0.95, Count = 1 },
				{ Name = "Red Cloud: Venomous", Color = Color3.fromRGB(125, 165, 60), Health = 75, Damage = 7, Speed = 14, Count = 1 },
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
}

return MapData

-- ModuleScript: ReplicatedStorage > MapData
-- Configuração dos mapas. Para criar um mapa novo, copie o bloco "Ninja" e mude os valores.
-- Cada onda tem uma lista de tipos de inimigo. A última onda (a 5ª) é sempre o boss.

local MapData = {}

MapData.StartCountdown = 8      -- segundos de contagem antes de começar
MapData.PauseBetweenWaves = 4   -- segundos de descanso entre ondas

-- Dificuldades das ondas: multiplicam a vida e o dano dos inimigos e as recompensas
MapData.Dificuldades = {
	{ Id = "Facil", Nome = "EASY", Vida = 1, Dano = 1, XP = 1, Moedas = 1, Cor = Color3.fromRGB(80, 190, 100) },
	{ Id = "Medio", Nome = "MEDIUM", Vida = 1.6, Dano = 1.35, XP = 1.6, Moedas = 2, Cor = Color3.fromRGB(240, 170, 50) },
	{ Id = "Dificil", Nome = "HARD", Vida = 2.4, Dano = 1.8, XP = 2.5, Moedas = 3.5, Cor = Color3.fromRGB(220, 60, 60) },
}
function MapData.GetDificuldade(id)
	for _, d in ipairs(MapData.Dificuldades) do
		if d.Id == id then return d end
	end
	return MapData.Dificuldades[1]
end

MapData.Maps = {
	Ninja = {
		Name = "Snake's Den",

		-- Count = quantos nascem; Extra = quantos a mais para cada jogador além do primeiro
		Waves = {
			{ Name = "Guinea Pigs", Enemies = {
				{ Look = "Cientista", Skin = "guinea pig", Name = "Guinea Pig", Color = Color3.fromRGB(190, 225, 190), Health = 35, Damage = 4, Speed = 11, Count = 4, Extra = 2 },
			} },
			{ Name = "Sound Ninjas", Enemies = {
				{ Look = "Som", Skin = "ninjas do som", Name = "Sound Ninja", Color = Color3.fromRGB(85, 55, 120), Health = 50, Damage = 5, Speed = 15, Count = 5, Extra = 2 },
			} },
			{ Name = "Kab Clones", Enemies = {
				{ Look = "Clone", Skin = "kab", Name = "Kab Clone", Color = Color3.fromRGB(135, 145, 175), Health = 55, Damage = 6, Speed = 14, Count = 6, Extra = 2 },
			} },
			{ Name = "Team Taka", Enemies = {
				{ Look = "Taka", Skin = "taka", SkinIdx = 1, Name = "Taka: Blade", Color = Color3.fromRGB(210, 80, 40), Health = 85, Damage = 8, Speed = 16, Count = 1 },
				{ Look = "Taka", Skin = "taka", SkinIdx = 3, Name = "Taka: Brute", Color = Color3.fromRGB(150, 60, 40), Health = 170, Damage = 10, Speed = 10, Scale = 1.4, Count = 1 },
				{ Look = "Taka", Skin = "taka", SkinIdx = 2, Name = "Taka: Tracker", Color = Color3.fromRGB(225, 130, 60), Health = 60, Damage = 6, Speed = 18, Scale = 0.95, Count = 1 },
				{ Look = "Taka", Skin = "taka", SkinIdx = 1, Name = "Taka: Venomous", Color = Color3.fromRGB(125, 165, 60), Health = 75, Damage = 7, Speed = 14, Count = 1 },
			} },
		},

		-- Onda 5: o boss
		BossName = "White Snake",
		BossSkin = "Mahito_Orochimaru_Verified",   -- modelo em ServerStorage.Aparencias
		BossScale = 1.6,
		BossColor = Color3.fromRGB(45, 105, 60),
		BossHealth = 1000,
		BossDamage = 20,
		BossKit = "WhiteSnake",                    -- ataques próprios (WaveServer: wsCobrasSombra, wsKusanagi, wsInvocar)
		BossSlamEvery = 7,                         -- Striking Shadow Snakes (faixa até o jogador mais próximo)
		BossBiteEvery = 10,                        -- Kusanagi Sword (some e reaparece cortando em volta de um jogador)
		BossSummonEvery = 18,                      -- invoca uma cobra gigante
		SlamLabel = "Striking Shadow Snakes!",
		BiteLabel = "Watch out: Kusanagi Sword!",
		SummonLabel = " summons a giant snake!",
		SnakeName = "White Snake's Serpent",
		SnakeHealth = 25,
		SnakeDamage = 6,
		SnakeColor = Color3.fromRGB(50, 130, 70),

		RewardXP = 250,
		RewardCoins = 200,
	},

	-- Exame Ninja (vira Genin): duelo contra o Sensei Kaito (modelo do Kakashi), sem ondas.
	ExameNinja = {
		Name = "Ninja Exam",
		Arena = "Ninja", -- luta na arena Mapa_Ninja

		Waves = {},

		-- o duelo
		BossName = "Sensei Kaito",
		BossSkin = "Kakashi",                      -- modelo em ServerStorage.Aparencias (cópia do NPC)
		BossColor = Color3.fromRGB(70, 80, 95),
		BossHealth = 900,
		BossDamage = 14,
		PlainBoss = true,                          -- sem enfeites de cobra
		BossScale = 1.15,
		BossSlamEvery = 8,
		BossBiteEvery = 11,
		BossSummonEvery = 16,
		SlamLabel = "Lightning Blade!",
		SlamColor = Color3.fromRGB(120, 190, 255),
		SlamPool = false,
		BiteLabel = "Watch out: kunai rain!",
		BiteColor = Color3.fromRGB(255, 200, 90),
		SummonLabel = " uses Shadow Clones!",
		Minion = { Name = "Shadow Clone", Skin = "Kakashi", Color = Color3.fromRGB(70, 80, 95), Health = 35, Damage = 5, Speed = 18 },

		RewardXP = 400,
		RewardCoins = 300,
	},

	-- Portal perto do prédio do Hokage: ninjas renegados atacando a vila (luta na arena Mapa_Ninja)
	Hokage = {
		Name = "Rogue Ninja Raid",
		Arena = "Ninja",

		Waves = {
			{ Name = "Rogue Genin", Enemies = {
				{ Look = "Renegado", Name = "Rogue Genin", Color = Color3.fromRGB(110, 120, 95), Health = 45, Damage = 5, Speed = 13, Count = 5, Extra = 2 },
			} },
			{ Name = "Mist Assassins", Enemies = {
				{ Look = "Nevoa", Name = "Mist Assassin", Color = Color3.fromRGB(150, 165, 185), Health = 50, Damage = 6, Speed = 18, Count = 5, Extra = 2 },
			} },
			{ Name = "Puppet Squad", Enemies = {
				{ Look = "Marionete", Name = "Battle Puppet", Color = Color3.fromRGB(160, 120, 80), Health = 65, Damage = 7, Speed = 14, Count = 6, Extra = 2 },
			} },
			{ Name = "Rogue Jonin", Enemies = {
				{ Look = "Renegado", Name = "Rogue Jonin: Blade", Health = 100, Color = Color3.fromRGB(90, 100, 80), Damage = 9, Speed = 17, Count = 1 },
				{ Look = "Nevoa", Name = "Rogue Jonin: Mist", Health = 80, Color = Color3.fromRGB(150, 165, 185), Damage = 8, Speed = 19, Scale = 0.95, Count = 1 },
				{ Look = "Marionete", Name = "Rogue Jonin: Puppeteer", Health = 180, Color = Color3.fromRGB(160, 120, 80), Damage = 10, Speed = 10, Scale = 1.4, Count = 1 },
				{ Look = "Renegado", Name = "Rogue Jonin: Hunter", Health = 85, Color = Color3.fromRGB(90, 100, 80), Damage = 8, Speed = 16, Count = 1 },
			} },
		},

		-- Onda 5: o boss
		BossName = "Rogue Commander",
		BossColor = Color3.fromRGB(70, 75, 60),
		BossHealth = 1250,
		BossDamage = 21,
		PlainBoss = true,
		BossScale = 2.3,
		BossSlamEvery = 8,
		BossBiteEvery = 12,
		BossSummonEvery = 14,
		SlamLabel = "Earth Shockwave!",
		SlamColor = Color3.fromRGB(190, 150, 90),
		SlamPool = false,
		BiteLabel = "Watch out: shuriken storm!",
		BiteColor = Color3.fromRGB(200, 220, 255),
		SummonLabel = " calls rogue shadows!",
		Minion = { Name = "Rogue Shadow", Color = Color3.fromRGB(40, 45, 40), Health = 30, Damage = 6, Speed = 20 },

		RewardXP = 320,
		RewardCoins = 250,
	},
}

return MapData

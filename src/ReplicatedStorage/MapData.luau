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
				{ Look = "Cientista", Skin = "guinea pig", Name = "Guinea Pig", Color = Color3.fromRGB(190, 225, 190), Health = 35, Damage = 4, Speed = 11, Count = 4, Extra = 2, Kin = "Selo", KinCada = 16 },
			} },
			{ Name = "Sound Ninjas", Enemies = {
				{ Look = "Som", Skin = "ninjas do som", Name = "Sound Ninja", Color = Color3.fromRGB(85, 55, 120), Health = 50, Damage = 5, Speed = 15, Count = 5, Extra = 2, Kin = "Maldicao", KinCada = 12 },
			} },
			{ Name = "Kab Clones", Enemies = {
				{ Look = "Clone", Skin = "kab", Name = "Kab Clone", Color = Color3.fromRGB(135, 145, 175), Health = 55, Damage = 6, Speed = 14, Count = 6, Extra = 2, Kin = "Veneno", KinCada = 12 },
			} },
			{ Name = "Team Taka", Enemies = {
				{ Look = "Taka", Skin = "taka", SkinIdx = 1, Name = "Taka: Blade", Color = Color3.fromRGB(210, 80, 40), Health = 85, Damage = 8, Speed = 16, Count = 1, Kin = "Chamas", KinCada = 9 },
				{ Look = "Taka", Skin = "taka", SkinIdx = 3, Name = "Taka: Brute", Color = Color3.fromRGB(150, 60, 40), Health = 170, Damage = 10, Speed = 10, Scale = 1.4, Count = 1, Kin = "Selo", KinCada = 10 },
				{ Look = "Taka", Skin = "taka", SkinIdx = 2, Name = "Taka: Tracker", Color = Color3.fromRGB(225, 130, 60), Health = 60, Damage = 6, Speed = 18, Scale = 0.95, Count = 1, Kin = "Maldicao", KinCada = 9 },
				{ Look = "Taka", Skin = "taka", SkinIdx = 1, Name = "Taka: Venomous", Color = Color3.fromRGB(125, 165, 60), Health = 75, Damage = 7, Speed = 14, Count = 1, Kin = "Veneno", KinCada = 9 },
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
		Arena = "ExameNinja", -- luta na arena Mapa_ExameNinja: gramado no centro e floresta em volta

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

	-- Portal na Vila Destruída (Konoha em ruínas depois do ataque do Pain): ondas dos Pains e o Deva Path no fim.
	-- Luta na arena própria Mapa_Hokage. Os Pains usam o visual por código (Look "Pain..."); troque por skins em Aparencias quando quiser.
	Hokage = {
		Name = "Pain's Assault",
		Arena = "Hokage",

		Waves = {
			{ Name = "Animal Path", Enemies = {
				{ Look = "PainAnimal", Name = "Animal Path", Color = Color3.fromRGB(235, 125, 40), Health = 50, Damage = 6, Speed = 19, Count = 5, Extra = 2, Kin = "Veneno", KinCada = 12 },
			} },
			{ Name = "Asura Path", Enemies = {
				{ Look = "PainAsura", Name = "Asura Path", Color = Color3.fromRGB(150, 45, 35), Health = 65, Damage = 7, Speed = 15, Count = 5, Extra = 2, Kin = "Chamas", KinCada = 12 },
			} },
			{ Name = "Human & Preta Paths", Enemies = {
				{ Look = "PainHumano", Name = "Human Path", Color = Color3.fromRGB(215, 150, 70), Health = 55, Damage = 6, Speed = 16, Count = 3, Extra = 1, Kin = "Maldicao", KinCada = 12 },
				{ Look = "PainPreta", Name = "Preta Path", Color = Color3.fromRGB(30, 25, 25), Health = 70, Damage = 7, Speed = 14, Count = 3, Extra = 1, Kin = "Selo", KinCada = 11 },
			} },
			{ Name = "The Five Paths", Enemies = {
				{ Look = "PainAnimal", Name = "Animal Path", Color = Color3.fromRGB(235, 125, 40), Health = 90, Damage = 8, Speed = 19, Count = 1, Kin = "Veneno", KinCada = 9 },
				{ Look = "PainAsura", Name = "Asura Path", Color = Color3.fromRGB(150, 45, 35), Health = 110, Damage = 9, Speed = 16, Count = 1, Kin = "Chamas", KinCada = 9 },
				{ Look = "PainHumano", Name = "Human Path", Color = Color3.fromRGB(215, 150, 70), Health = 95, Damage = 8, Speed = 17, Count = 1, Kin = "Maldicao", KinCada = 9 },
				{ Look = "PainPreta", Name = "Preta Path", Color = Color3.fromRGB(30, 25, 25), Health = 100, Damage = 8, Speed = 15, Count = 1, Kin = "Selo", KinCada = 9 },
				{ Look = "PainNaraka", Name = "Naraka Path", Color = Color3.fromRGB(35, 30, 30), Health = 200, Damage = 10, Speed = 10, Scale = 1.35, Count = 1, Kin = "Selo", KinCada = 10 },
			} },
		},

		-- Onda 5: o boss
		BossName = "Deva Path",
		BossLook = "PainDeva",
		BossColor = Color3.fromRGB(24, 24, 30),
		BossHealth = 1300,
		BossDamage = 22,
		PlainBoss = true,
		BossScale = 2.2,
		BossSlamEvery = 8,
		BossBiteEvery = 12,
		BossSummonEvery = 15,
		SlamLabel = "Shinra Tensei!",
		SlamColor = Color3.fromRGB(150, 190, 255),
		SlamPool = false,
		BiteLabel = "Watch out: Bansho Ten'in!",
		BiteColor = Color3.fromRGB(255, 150, 60),
		SummonLabel = " calls the other Paths!",
		Minion = { Name = "Summoned Path", Look = "PainAnimal", Color = Color3.fromRGB(235, 125, 40), Health = 30, Damage = 6, Speed = 20 },

		RewardXP = 350,
		RewardCoins = 280,
	},
}

return MapData

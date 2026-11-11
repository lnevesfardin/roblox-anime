-- ModuleScript: ReplicatedStorage > MissionData
-- Ranks ninja, personagens (NPCs) que dão missões, missões e lugares do mapa.
-- Tipos de objetivo:
--   falar    = conversar com o NPC Alvo
--   ir       = chegar ao lugar Alvo (Lugares)
--   treinar  = treinar N vezes nas estações da Academia
--   derrotar = derrotar N bandidos no acampamento
--   coletar  = coletar N ervas na floresta
--   exame    = vencer a partida do Exame Ninja (vira Genin)

local MissionData = {}

MissionData.COOLDOWN = 8 * 60 -- segundos até a mesma missão repetível poder ser feita de novo

MissionData.Ranks = {
	{ Id = "Estudante", Name = "Academy Student", Level = 1 },
	{ Id = "Genin", Name = "Genin", Level = 10, Exame = true }, -- só com o Exame Ninja
	{ Id = "Chunin", Name = "Chunin", Level = 25 },
	{ Id = "Jonin", Name = "Jonin", Level = 45 },
	{ Id = "Elite", Name = "Elite Jonin", Level = 65 },
	{ Id = "Kage", Name = "Kage", Level = 85 },
}

-- lugares usados pelas missões "ir" e pelo marcador na tela
MissionData.Lugares = {
	Mercado = { Name = "Market Street", Pos = Vector3.new(-26, 3, -560), Raio = 18 },
	Academia = { Name = "Ninja Academy", Pos = Vector3.new(-120, 3, -530), Raio = 20 },
	Oeste = { Name = "West District", Pos = Vector3.new(-295, 3, -280), Raio = 20 },
	Praca = { Name = "Village Square", Pos = Vector3.new(63, 3, -12), Raio = 18 },
	Acampamento = { Name = "Bandit Camp", Pos = Vector3.new(300, 3, 100), Raio = 30 },
	Floresta = { Name = "Forest", Pos = Vector3.new(63, 3, 330), Raio = 120 },
}

-- NPCs: chave = nome do modelo no workspace (tag "NPC"). Name = nome mostrado no jogo.
MissionData.NPCs = {
	["Kakashi"] = { Name = "Sensei Kaito", Titulo = "Academy Instructor", Fala = "A ninja's path starts with small steps. Ready?" },
	["Might guy"] = { Name = "Coach Gaien", Titulo = "Taijutsu Coach", Fala = "Youth is about sweat! Train with me!" },
	["Naruto"] = { Name = "Kenta", Titulo = "Ramen Lover", Fala = "Hey! You look hungry. Wanna help me out?" },
	["Sakura (Naruto Shippuden)"] = { Name = "Hana", Titulo = "Medic in Training", Fala = "I need herbs for the hospital. Can you help?" },
	["Sasuke"] = { Name = "Ryo", Titulo = "Lone Genin", Fala = "Bandits again... Don't slow me down." },
	["Hinata"] = { Name = "Yumi", Titulo = "Shy Villager", Fala = "U-um... have you seen my cat?" },
	["Tsunade"] = { Name = "Lady Tsuna", Titulo = "Village Elder", Fala = "Strong ninjas protect the village. Prove yourself." },
	["Pain"] = { Name = "Stranger", Titulo = "???", Fala = "This village... is quieter than I expected." },
	["StarterCharacter"] = { Name = "Villager", Titulo = "Konoha Resident", Fala = "Nice weather today, isn't it?" },
}

-- Missões. Historia = cadeia principal (feita uma vez, na ordem). As outras repetem depois do COOLDOWN.
-- Nivel = nível mínimo. Recompensa: XP, Coins, Pontos (pontos de atributo).
MissionData.Missoes = {
	-- História (Sensei Kaito)
	{ Id = "H1", Npc = "Kakashi", Historia = 1, Rank = "D", Name = "First Day",
		Desc = "Go meet Coach Gaien. He will teach you the basics.",
		Tipo = "falar", Alvo = "Might guy", N = 1, Recompensa = { XP = 300, Coins = 100 } },
	{ Id = "H2", Npc = "Kakashi", Historia = 2, Rank = "D", Name = "Basic Training",
		Desc = "Train twice at the Ninja Academy stations.",
		Tipo = "treinar", N = 2, Recompensa = { XP = 500, Coins = 120, Pontos = 1 } },
	{ Id = "H3", Npc = "Kakashi", Historia = 3, Rank = "D", Name = "Village Patrol",
		Desc = "Patrol the village: go to Market Street.",
		Tipo = "ir", Alvo = "Mercado", N = 1, Recompensa = { XP = 600, Coins = 150 } },
	{ Id = "H4", Npc = "Kakashi", Historia = 4, Rank = "D", Name = "Bandits Nearby",
		Desc = "Bandits set up a camp outside the village. Defeat 4 of them.",
		Tipo = "derrotar", Alvo = "Acampamento", N = 4, Recompensa = { XP = 1200, Coins = 250, Pontos = 2 } },
	{ Id = "H5", Npc = "Kakashi", Historia = 5, Rank = "C", Name = "The Ninja Exam", Nivel = 10,
		Desc = "Pass the Ninja Exam to become a Genin.",
		Tipo = "exame", Mapa = "ExameNinja", N = 1, Recompensa = { XP = 1500, Coins = 500, Pontos = 3 }, Promove = "Genin" },

	-- Repetíveis
	{ Id = "R_Ramen", Npc = "Naruto", Rank = "D", Name = "Ramen Delivery",
		Desc = "Deliver a bowl of ramen to Market Street.",
		Tipo = "ir", Alvo = "Mercado", N = 1, Recompensa = { XP = 400, Coins = 60 } },
	{ Id = "R_Ervas", Npc = "Sakura (Naruto Shippuden)", Rank = "D", Name = "Medicinal Herbs",
		Desc = "Collect 5 glowing herbs in the forest.",
		Tipo = "coletar", Alvo = "Floresta", N = 5, Recompensa = { XP = 450, Coins = 70 } },
	{ Id = "R_Bandidos", Npc = "Sasuke", Rank = "D", Name = "Bandit Hunt",
		Desc = "Defeat 6 bandits at the camp.",
		Tipo = "derrotar", Alvo = "Acampamento", N = 6, Recompensa = { XP = 500, Coins = 90 } },
	{ Id = "R_Treino", Npc = "Might guy", Rank = "D", Name = "Extra Training",
		Desc = "Train once at the Ninja Academy.",
		Tipo = "treinar", N = 1, Recompensa = { XP = 350, Coins = 40 } },
	{ Id = "R_Gato", Npc = "Hinata", Rank = "D", Name = "Lost Cat",
		Desc = "Search for the cat in the West District.",
		Tipo = "ir", Alvo = "Oeste", N = 1, Recompensa = { XP = 400, Coins = 60 } },
	{ Id = "R_Elder", Npc = "Tsunade", Rank = "C", Name = "Camp Raid", Nivel = 10,
		Desc = "Defeat 10 bandits at the camp.",
		Tipo = "derrotar", Alvo = "Acampamento", N = 10, Recompensa = { XP = 1500, Coins = 200, Pontos = 1 } },
}

function MissionData.Get(id)
	for _, m in ipairs(MissionData.Missoes) do
		if m.Id == id then
			return m
		end
	end
	return nil
end

function MissionData.RankIndex(id)
	for i, r in ipairs(MissionData.Ranks) do
		if r.Id == id then
			return i
		end
	end
	return 1
end

function MissionData.RankName(id)
	return MissionData.Ranks[MissionData.RankIndex(id)].Name
end

return MissionData

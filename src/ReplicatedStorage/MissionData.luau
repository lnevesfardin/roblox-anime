-- ModuleScript: ReplicatedStorage > MissionData
-- Ranks ninja, personagens (NPCs) que dão missões, missões e lugares do mapa.
-- Tipos de objetivo:
--   falar    = conversar com o NPC Alvo
--   ir       = chegar ao lugar Alvo (Lugares)
--   treinar  = treinar N vezes nas estações da Academia
--   derrotar = derrotar N bandidos nos esconderijos
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
	Acampamento = { Name = "Bandit Hideouts", Pos = Vector3.new(220, 3, 140), Raio = 30 },
	Floresta = { Name = "Forest", Pos = Vector3.new(63, 3, 330), Raio = 120 },
}

-- esconderijos dos bandidos dentro da floresta murada (missões "derrotar")
MissionData.Esconderijos = {
	{ Name = "HIDDEN CAVE", Tipo = "Caverna", Pos = Vector3.new(-80, 0, 505), Giro = 0 },
	{ Name = "BANDIT HIDEOUT", Tipo = "Cabana", Pos = Vector3.new(220, 0, 140), Giro = 90 },
	{ Name = "RUINED SHED", Tipo = "Ruina", Pos = Vector3.new(215, 0, 292), Giro = 180 },
}

-- NPCs: chave = nome do modelo no workspace (tag "NPC"). Name = nome mostrado no jogo.
MissionData.NPCs = {
	["Kakashi"] = { Name = "Sensei Kaito", Titulo = "Academy Instructor", Fala = "A ninja's path starts with small steps. Ready?" },
	["Might guy"] = { Name = "Coach Gaien", Titulo = "Taijutsu Coach", Fala = "Youth is about sweat! Train with me!" },
	["Naruto"] = { Name = "Kenta", Titulo = "Ramen Lover", Fala = "Hey! You look hungry. Wanna help me out?" },
	["Sakura (Naruto Shippuden)"] = { Name = "Hana", Titulo = "Medic in Training", Fala = "I need herbs for the hospital. Can you help?" },
	["Sasuke"] = { Name = "Ryo", Titulo = "Lone Genin", Fala = "Bandits again... Don't slow me down." },
	["Hinata"] = { Name = "Yumi", Titulo = "Mission Desk", Quadro = true, Fala = "W-welcome! The mission board is right here... and, um, have you seen my cat?" },
	["Tsunade"] = { Name = "Lady Tsuna", Titulo = "Village Elder", Fala = "Strong ninjas protect the village. Prove yourself." },
	["Pain"] = { Name = "Stranger", Titulo = "???", Fala = "This village... is quieter than I expected." },
	["Ino (PTS)"] = { Name = "Stranger", Titulo = "Wandering Grappler", Fala = "Strength is nothing if you can't control it. Want to learn?" },
	["StarterCharacter"] = { Name = "Villager", Titulo = "Konoha Resident", Fala = "Nice weather today, isn't it?" },
}

-- Missões. Historia = cadeia principal (feita uma vez, na ordem). As outras repetem depois do COOLDOWN.
-- Nivel = nível mínimo. Recompensa: XP, Coins, Pontos (pontos de atributo).
MissionData.Missoes = {
	-- História = o caminho do ninja (feita na ordem, uma vez).
	-- Parte 1: conhecer as pessoas importantes da vila. Cada uma apresenta a próxima.
	{ Id = "H1", Npc = "Kakashi", Historia = 1, Rank = "D", Name = "Meet the Coach",
		Desc = "Coach Gaien trains every student. Go introduce yourself.",
		Tipo = "falar", Alvo = "Might guy", N = 1, Recompensa = { XP = 150, Coins = 50 } },
	{ Id = "H2", Npc = "Might guy", Historia = 2, Rank = "D", Name = "The Mission Desk",
		Desc = "Yumi runs the QUESTS desk in the square. Every mission passes through her.",
		Tipo = "falar", Alvo = "Hinata", N = 1, Recompensa = { XP = 150, Coins = 50 } },
	{ Id = "H3", Npc = "Hinata", Historia = 3, Rank = "D", Name = "The Village Medic",
		Desc = "Hana heals the village ninjas. Go meet her.",
		Tipo = "falar", Alvo = "Sakura (Naruto Shippuden)", N = 1, Recompensa = { XP = 150, Coins = 50 } },
	{ Id = "H4", Npc = "Sakura (Naruto Shippuden)", Historia = 4, Rank = "D", Name = "The Village Elder",
		Desc = "Lady Tsuna leads the village and knows the secrets of every clan. Pay your respects.",
		Tipo = "falar", Alvo = "Tsunade", N = 1, Recompensa = { XP = 200, Coins = 80, Pontos = 1 } },
	-- Parte 2: virar Genin (obrigatório para as missões de rank C e para sair da vila pelo portão leste).
	{ Id = "H5", Npc = "Tsunade", Historia = 5, Rank = "D", Name = "Basic Training",
		Desc = "Train twice at the Ninja Academy stations.",
		Tipo = "treinar", N = 2, Recompensa = { XP = 500, Coins = 120, Pontos = 1 } },
	{ Id = "H6", Npc = "Kakashi", Historia = 6, Rank = "D", Name = "Bandits Nearby",
		Desc = "Bandits are hiding in the forest outside the village. Defeat 4 of them.",
		Tipo = "derrotar", Alvo = "Acampamento", N = 4, Recompensa = { XP = 1200, Coins = 250, Pontos = 2 } },
	{ Id = "H7", Npc = "Kakashi", Historia = 7, Rank = "C", Name = "The Ninja Exam", Nivel = 10,
		Desc = "Pass the Ninja Exam to become a Genin.",
		Tipo = "exame", Mapa = "ExameNinja", N = 1, Recompensa = { XP = 1500, Coins = 500, Pontos = 3 }, Promove = "Genin" },
	-- (Chunin e Jonin: continuação do caminho, a definir)

	-- Repetíveis
	{ Id = "R_Ramen", Npc = "Naruto", Rank = "D", Name = "Ramen Delivery",
		Desc = "Deliver a bowl of ramen to Market Street.",
		Tipo = "ir", Alvo = "Mercado", N = 1, Recompensa = { XP = 400, Coins = 60 } },
	{ Id = "R_Ervas", Npc = "Sakura (Naruto Shippuden)", Rank = "D", Name = "Medicinal Herbs",
		Desc = "Collect 5 glowing herbs in the forest.",
		Tipo = "coletar", Alvo = "Floresta", N = 5, Recompensa = { XP = 450, Coins = 70 } },
	{ Id = "R_Bandidos", Npc = "Sasuke", Rank = "D", Name = "Bandit Hunt",
		Desc = "Defeat 6 bandits at the hideouts.",
		Tipo = "derrotar", Alvo = "Acampamento", N = 6, Recompensa = { XP = 500, Coins = 90 } },
	{ Id = "R_Treino", Npc = "Might guy", Rank = "D", Name = "Extra Training",
		Desc = "Train once at the Ninja Academy.",
		Tipo = "treinar", N = 1, Recompensa = { XP = 350, Coins = 40 } },
	{ Id = "R_Gato", Npc = "Hinata", Rank = "D", Name = "Lost Cat",
		Desc = "Search for the cat in the West District.",
		Tipo = "ir", Alvo = "Oeste", N = 1, Recompensa = { XP = 400, Coins = 60 } },
	{ Id = "R_Elder", Npc = "Tsunade", Rank = "C", Name = "Camp Raid", Nivel = 10, RankMin = "Genin",
		Desc = "Defeat 10 bandits at the hideouts.",
		Tipo = "derrotar", Alvo = "Acampamento", N = 10, Recompensa = { XP = 1500, Coins = 200, Pontos = 1 } },
}

-- Missões do clã (Fase 4): liberam o 2º e o 3º poder do clã. Dadas pela Lady Tsuna,
-- só aparecem para quem é daquele clã (Cla), feitas uma vez só (Unica).
-- RankMin = rank mínimo. Requer = missão que precisa estar feita antes. Recompensa.Poder = posição do poder liberado.
do
	local ClanPowers = require(script.Parent:WaitForChild("ClanPowers"))
	for _, clan in ipairs({ "Uzu", "Uchiwa", "Mokuton", "Byakugan", "Lee", "Shirokiba", "Enma", "Inu" }) do
		local c = ClanPowers.Clans[clan]
		local nivel2, rank2 = ClanPowers.Requisito(clan, 2)
		local nivel3, rank3 = ClanPowers.Requisito(clan, 3)
		table.insert(MissionData.Missoes, { Id = "C2_" .. clan, Npc = "Tsunade", Rank = "C", Cla = clan, Unica = true,
			Name = "Clan Secret: " .. c.Powers[2].Name, Nivel = nivel2, RankMin = rank2,
			Desc = "The Elder knows your clan's secret. Defeat 8 bandits at the hideouts to prove you are ready.",
			Tipo = "derrotar", Alvo = "Acampamento", N = 8, Recompensa = { XP = 800, Coins = 150, Poder = 2 } })
		table.insert(MissionData.Missoes, { Id = "C3_" .. clan, Npc = "Tsunade", Rank = "B", Cla = clan, Unica = true, Requer = "C2_" .. clan,
			Name = "Clan Trial: " .. c.Powers[3].Name, Nivel = nivel3, RankMin = rank3,
			Desc = "The final trial of your clan. Defeat 15 bandits at the hideouts to master your strongest technique.",
			Tipo = "derrotar", Alvo = "Acampamento", N = 15, Recompensa = { XP = 2500, Coins = 400, Poder = 3 } })
	end
end

-- Missões dos mestres (Fase 5): ensinam um estilo de luta (Recompensa.Estilo). Feitas uma vez.
table.insert(MissionData.Missoes, { Id = "E_Boxe", Npc = "Might guy", Rank = "D", Unica = true, Nivel = 5,
	Name = "Boxing Lessons", Desc = "Coach Gaien will teach you Boxing. Train 5 times at the Ninja Academy.",
	Tipo = "treinar", N = 5, Recompensa = { XP = 500, Coins = 100, Estilo = "Boxe" } })
table.insert(MissionData.Missoes, { Id = "E_Karate", Npc = "Kakashi", Rank = "C", Unica = true, Nivel = 10,
	Name = "Karate Discipline", Desc = "Sensei Kaito teaches Karate to the disciplined. Defeat 10 bandits at the hideouts.",
	Tipo = "derrotar", Alvo = "Acampamento", N = 10, Recompensa = { XP = 900, Coins = 150, Estilo = "Karate" } })
table.insert(MissionData.Missoes, { Id = "E_MuayThai", Npc = "Sasuke", Rank = "C", Unica = true, Nivel = 15, RankMin = "Genin",
	Name = "Art of Eight Limbs", Desc = "Ryo only trains Genin. Defeat 12 bandits and he will teach you Muay Thai.",
	Tipo = "derrotar", Alvo = "Acampamento", N = 12, Recompensa = { XP = 1300, Coins = 200, Estilo = "MuayThai" } })
table.insert(MissionData.Missoes, { Id = "E_JiuJitsu", Npc = "Ino (PTS)", Rank = "B", Unica = true, Nivel = 20,
	Name = "The Gentle Art", Desc = "The Stranger wants 8 glowing herbs from the forest before teaching Jiu-Jitsu.",
	Tipo = "coletar", Alvo = "Floresta", N = 8, Recompensa = { XP = 1800, Coins = 250, Estilo = "JiuJitsu" } })

-- quantas missões tem a história e qual é a de número n
MissionData.TotalHistoria = 0
for _, m in ipairs(MissionData.Missoes) do
	if m.Historia then MissionData.TotalHistoria = math.max(MissionData.TotalHistoria, m.Historia) end
end
function MissionData.DaHistoria(n)
	for _, m in ipairs(MissionData.Missoes) do
		if m.Historia == n then return m end
	end
	return nil
end

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

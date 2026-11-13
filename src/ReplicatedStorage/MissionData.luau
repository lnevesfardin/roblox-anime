-- ModuleScript: ReplicatedStorage > MissionData
-- Ranks ninja, personagens (NPCs) que dão missões, missões e lugares do mapa.
-- Tipos de objetivo:
--   falar    = conversar com o NPC Alvo
--   ir       = chegar ao lugar Alvo (Lugares)
--   treinar  = treinar N vezes nas estações da Academia
--   derrotar = derrotar N bandidos nos esconderijos
--   coletar  = coletar N ervas na floresta
--   exame    = vencer a partida do Exame Ninja (vira Genin)
-- Recompensas especiais: PrimeiroJutsu (1º jutsu do clã), Poder (2º/3º do clã), Estilo (estilo de luta),
-- Jutsu (jutsu de natureza), NovaNatureza (mais uma natureza de chakra).

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
	-- Conversa = conversa com opções de resposta. Nas missões "falar" ela acontece com o NPC Alvo
	-- (a missão conclui quando a conversa termina); nas outras, ao aceitar a missão.
	-- Cada passo: Fala do NPC + Opcoes { T = resposta do jogador, R = reação do NPC, Bom = dá XP extra }.
	-- Parte 1: conhecer as pessoas importantes da vila. Cada uma apresenta a próxima.
	{ Id = "H1", Npc = "Kakashi", Historia = 1, Rank = "D", Name = "Meet the Coach",
		Desc = "Coach Gaien trains every student. Go introduce yourself.",
		Tipo = "falar", Alvo = "Might guy", N = 1, Recompensa = { XP = 150, Coins = 50 },
		Conversa = {
			{ Fala = "A NEW STUDENT! I can see the fire of youth in your eyes! Tell me, why do you want to be a ninja?", Opcoes = {
				{ T = "To protect the people I care about.", R = "YES! That is the answer of a true shinobi! Hold on to it when training gets hard.", Bom = true },
				{ T = "To become the strongest ninja ever.", R = "HA! Big dream! Strength without a reason is empty, but we can work with that fire." },
				{ T = "Honestly? I'm not sure yet.", R = "An honest heart! Sweat will give you the answer. It always does." } } },
			{ Fala = "Before any jutsu, a ninja needs a body that obeys. What do you do when your arms can't take one more push-up?", Opcoes = {
				{ T = "I do one more anyway.", R = "THAT'S IT! One more is where growth lives!", Bom = true },
				{ T = "I rest and come back tomorrow.", R = "Rest matters too... but not before the last one! We'll fix that." },
				{ T = "I ask Sensei Kaito for a shortcut.", R = "Kaito and his shortcuts... There are none here. Only sweat!" } } },
			{ Fala = "Good talk! Go see Yumi at the QUESTS desk in the square. Every mission in this village passes through her hands." },
		} },
	{ Id = "H2", Npc = "Might guy", Historia = 2, Rank = "D", Name = "The Mission Desk",
		Desc = "Yumi runs the QUESTS desk in the square. Every mission passes through her.",
		Tipo = "falar", Alvo = "Hinata", N = 1, Recompensa = { XP = 150, Coins = 50 },
		Conversa = {
			{ Fala = "Oh! A-a new face... Coach Gaien sent you? Um, do you know how missions are ranked?", Opcoes = {
				{ T = "D is the easiest, S is the hardest.", R = "Y-yes, exactly! D, C, B, A and S. You already know more than most students.", Bom = true },
				{ T = "No idea. Can you explain?", R = "Of course! D is for students, C for Genin, then B, A and S. Start small, okay?" },
				{ T = "Just give me an S rank already.", R = "S-rank?! You would not last a minute... Please start with D." } } },
			{ Fala = "One more thing... You can only carry one mission at a time. If you were me, what would you never forget?", Opcoes = {
				{ T = "Finishing what I accepted.", R = "That is what makes people trust a ninja. I'll remember your name.", Bom = true },
				{ T = "Getting paid.", R = "W-well, the reward matters too, I guess..." } } },
			{ Fala = "If you get hurt out there, Hana is the one who patches everyone up. You should meet her." },
		} },
	{ Id = "H3", Npc = "Hinata", Historia = 3, Rank = "D", Name = "The Village Medic",
		Desc = "Hana heals the village ninjas. Go meet her.",
		Tipo = "falar", Alvo = "Sakura (Naruto Shippuden)", N = 1, Recompensa = { XP = 150, Coins = 50 },
		Conversa = {
			{ Fala = "A new student? Good. Quick test: your teammate is hurt in the middle of a fight. What do you do?", Opcoes = {
				{ T = "Get them to safety first.", R = "Right. A ninja who abandons a teammate is worse than trash. Remember that.", Bom = true },
				{ T = "Finish the enemy, then help.", R = "Sometimes that works. Sometimes your friend doesn't have that long." },
				{ T = "Call for you!", R = "Ha! I can't be everywhere. Learn the basics yourself." } } },
			{ Fala = "I always need medicinal herbs from the forest. They glow green, you can't miss them. Would you bring me some one day?", Opcoes = {
				{ T = "Count on me.", R = "I will. Come back when you want the herb mission.", Bom = true },
				{ T = "Only if it pays well.", R = "It pays. Not much, but it saves lives." } } },
			{ Fala = "Now go pay your respects to Lady Tsuna. She leads the village and knows the secrets of every clan." },
		} },
	{ Id = "H4", Npc = "Sakura (Naruto Shippuden)", Historia = 4, Rank = "D", Name = "The Village Elder",
		Desc = "Lady Tsuna leads the village and knows the secrets of every clan. Pay your respects.",
		Tipo = "falar", Alvo = "Tsunade", N = 1, Recompensa = { XP = 200, Coins = 80, Pontos = 1 },
		Conversa = {
			{ Fala = "So you are the new student everyone is talking about. Look at me. What is a ninja's most important weapon?", Opcoes = {
				{ T = "The will to never give up.", R = "Hm. Good. Jutsu can be copied. Will cannot.", Bom = true },
				{ T = "A powerful jutsu.", R = "Jutsu? You don't even have one yet. Power comes later, and only to those who earn it." },
				{ T = "A sharp kunai.", R = "A kunai is a tool. The hand that holds it is what matters." } } },
			{ Fala = "In this village nobody is handed a jutsu. Your clan technique, your chakra natures, all of it is earned through training and missions. Does that scare you?", Opcoes = {
				{ T = "No. I'll earn every one of them.", R = "Then we will get along. Come to me when you are ready for your clan's secrets.", Bom = true },
				{ T = "A little. Where do I start?", R = "Honest. You start with your fists, like everyone else." } } },
			{ Fala = "Enough talk. Take the Basic Training from me and show the Academy what you are made of." },
		} },
	-- Parte 2: virar Genin (obrigatório para as missões de rank C e para sair da vila pelo portão leste).
	{ Id = "H5", Npc = "Tsunade", Historia = 5, Rank = "D", Name = "Basic Training",
		Desc = "Train twice at the Ninja Academy stations.",
		Tipo = "treinar", N = 2, Recompensa = { XP = 500, Coins = 120, Pontos = 1 } },
	-- o jogador nasce só com os socos: o 1º jutsu do clã vem aqui (ClanPowers.HIST_PRIMEIRO = 6)
	{ Id = "H6", Npc = "Kakashi", Historia = 6, Rank = "D", Name = "Your First Jutsu",
		Desc = "Prove yourself with only your fists: defeat 2 bandits. Sensei Kaito will teach you your clan's first jutsu.",
		Tipo = "derrotar", Alvo = "Acampamento", N = 2, Recompensa = { XP = 600, Coins = 150, PrimeiroJutsu = true },
		Conversa = {
			{ Fala = "You met everyone. Good. Now tell me: you have no jutsu yet. Why do you think that is?", Opcoes = {
				{ T = "Because I have to earn it first.", R = "Exactly. A jutsu in untrained hands only hurts its owner.", Bom = true },
				{ T = "Because you are all too slow to teach me.", R = "Maybe. Or maybe you are too fast to listen." } } },
			{ Fala = "There are bandits in the forest outside the village. Beat two of them with nothing but your fists, and I will teach you the first technique of your clan." },
		} },
	{ Id = "H7", Npc = "Kakashi", Historia = 7, Rank = "D", Name = "Bandits Nearby",
		Desc = "Now use what you learned. Defeat 4 bandits in the forest outside the village.",
		Tipo = "derrotar", Alvo = "Acampamento", N = 4, Recompensa = { XP = 1200, Coins = 250, Pontos = 2 } },
	{ Id = "H8", Npc = "Kakashi", Historia = 8, Rank = "C", Name = "The Ninja Exam", Nivel = 10,
		Desc = "The Ninja Exam is a duel: defeat Sensei Kaito to become a Genin.",
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

-- Missões de natureza: o mestre de cada natureza ensina os jutsus (Recompensa.Jutsu). Só aparecem para quem
-- tem aquela natureza (Natureza) e já aprendeu o 1º jutsu do clã (HistoriaMin). Feitas uma vez.
do
	local NatureData = require(script.Parent:WaitForChild("NatureData"))
	local ClanPowers = require(script.Parent:WaitForChild("ClanPowers"))
	local prova = {
		Fogo = { "derrotar", "Acampamento", 5, "Fire answers to fighting spirit. Defeat 5 bandits at the hideouts." },
		Vento = { "ir", "Oeste", 1, "Wind is felt, not seen. Run to the West District and feel it move." },
		Raio = { "treinar", nil, 2, "Lightning needs a precise body. Train twice at the Ninja Academy." },
		Terra = { "derrotar", "Acampamento", 6, "Earth does not move. Stand your ground against 6 bandits." },
		Agua = { "coletar", "Floresta", 4, "Water gives life. Bring 4 glowing herbs from the forest." },
	}
	for _, id in ipairs(NatureData.Order) do
		local t = NatureData.Tipos[id]
		local mestre = MissionData.NPCs[t.Mestre].Name
		local p = prova[id]
		table.insert(MissionData.Missoes, { Id = "N1_" .. id, Npc = t.Mestre, Rank = "D", Natureza = id, Unica = true, HistoriaMin = ClanPowers.HIST_PRIMEIRO,
			Name = t.Name .. " Nature: " .. t.Jutsus[1].Name,
			Desc = p[4] .. " " .. mestre .. " will teach you " .. t.Jutsus[1].Name .. ".",
			Tipo = p[1], Alvo = p[2], N = p[3], Recompensa = { XP = 700, Coins = 120, Jutsu = t.Jutsus[1].Id },
			Conversa = {
				{ Fala = "I can feel it. You carry the " .. t.Name .. " nature. Most people never notice their own chakra. How does it feel to you?", Opcoes = {
					{ T = "Like something that wants to get out.", R = "Then it is awake. Good. Now it needs a shape.", Bom = true },
					{ T = "I don't feel anything yet.", R = "You will. It always starts quiet." } } },
				{ Fala = p[4] .. " Do that, and I will teach you " .. t.Jutsus[1].Name .. "." },
			} })
		table.insert(MissionData.Missoes, { Id = "N2_" .. id, Npc = t.Mestre, Rank = "C", Natureza = id, Unica = true, Requer = "N1_" .. id, Nivel = 18, RankMin = "Genin",
			Name = t.Name .. " Mastery: " .. t.Jutsus[2].Name,
			Desc = "Only a Genin can handle this. Defeat 12 bandits at the hideouts and " .. mestre .. " will teach you " .. t.Jutsus[2].Name .. ".",
			Tipo = "derrotar", Alvo = "Acampamento", N = 12, Recompensa = { XP = 1800, Coins = 300, Jutsu = t.Jutsus[2].Id },
			Conversa = {
				{ Fala = "You handle " .. t.Jutsus[1].Name .. " well. The next technique burns a lot more chakra. What will you do when it runs out mid-fight?", Opcoes = {
					{ T = "Fall back on my fists until it returns.", R = "Good. A ninja with one plan is a dead ninja.", Bom = true },
					{ T = "It won't run out.", R = "It always runs out. Remember this talk when it does." } } },
				{ Fala = "Defeat 12 bandits at the hideouts. Come back alive and " .. t.Jutsus[2].Name .. " is yours." },
			} })
	end
	-- Naturezas extras: a 4ª e a 5ª (e as que faltarem até lá) só por missões raras da Lady Tsuna.
	-- NovaNatureza = só aparece para quem ainda tem menos de NatureData.MAX naturezas.
	local extras = {
		{ "NX1", "C", 15, "Genin", nil, "derrotar", "Acampamento", 15, "Second Awakening" },
		{ "NX2", "C", 25, "Genin", "NX1", "coletar", "Floresta", 12, "Third Awakening" },
		{ "NX3", "B", 35, "Chunin", "NX2", "derrotar", "Acampamento", 25, "Fourth Awakening" },
		{ "NX4", "A", 45, "Chunin", "NX3", "derrotar", "Acampamento", 40, "Fifth Awakening" },
	}
	for _, e in ipairs(extras) do
		table.insert(MissionData.Missoes, { Id = e[1], Npc = "Tsunade", Rank = e[2], Nivel = e[3], RankMin = e[4], Requer = e[5], Unica = true, NovaNatureza = true,
			Name = "Chakra Awakening: " .. e[9],
			Desc = "Very few ninjas awaken a new chakra nature. Complete Lady Tsuna's trial to awaken another one.",
			Tipo = e[6], Alvo = e[7], N = e[8], Recompensa = { XP = 1500 + e[3] * 40, Coins = 300, NovaNatureza = true },
			Conversa = {
				{ Fala = "You want another chakra nature? Most ninjas live and die with the ones they were born with. Why should you be different?", Opcoes = {
					{ T = "Because I will work harder than all of them.", R = "Words are cheap. But I have seen that look before. Prove it.", Bom = true },
					{ T = "Because I was born special.", R = "Nobody is born special. Special is built." } } },
				{ Fala = "Finish my trial. If your chakra survives it, a new nature will answer you." },
			} })
	end
end

-- Kekkei Genkai: o poder da tecla V é ensinado pela Lady Tsuna (só para quem nasceu com uma linhagem).
do
	local KekkeiData = require(script.Parent:WaitForChild("KekkeiData"))
	local ClanPowers = require(script.Parent:WaitForChild("ClanPowers"))
	table.insert(MissionData.Missoes, { Id = KekkeiData.MISSAO, Npc = "Tsunade", Rank = "C", Kekkei = true, Unica = true,
		Nivel = KekkeiData.NIVEL_PODER, HistoriaMin = ClanPowers.HIST_PRIMEIRO,
		Name = "Bloodline Awakening",
		Desc = "Your blood carries a Kekkei Genkai. Defeat 6 bandits at the hideouts and Lady Tsuna will awaken its power.",
		Tipo = "derrotar", Alvo = "Acampamento", N = 6, Recompensa = { XP = 900, Coins = 180, KekkeiPoder = true },
		Conversa = {
			{ Fala = "I felt it the day you arrived. Your blood is different. A Kekkei Genkai sleeps in you. Do you know what that means?", Opcoes = {
				{ T = "A power only my bloodline has.", R = "Yes. And a power nobody else can teach you to control. Only you can.", Bom = true },
				{ T = "That I'm stronger than everyone.", R = "It means you are a bigger target. Strength comes from control." } } },
			{ Fala = "Defeat 6 bandits at the hideouts using only what you know. When your chakra is pushed to the limit, the bloodline will wake up." },
		} })
end

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

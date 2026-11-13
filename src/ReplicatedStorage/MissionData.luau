-- ModuleScript: ReplicatedStorage > MissionData
-- Ranks ninja, personagens (NPCs) que dão missões, missões e lugares do mapa.
-- Tipos de objetivo:
--   falar    = conversar com o NPC Alvo
--   ir       = chegar ao lugar Alvo (Lugares)
--   treinar  = treinar N vezes nas estações da Academia
--   derrotar = derrotar N bandidos nos esconderijos
--   coletar  = coletar N ervas na floresta
--   exame    = vencer a partida do Exame Ninja (vira Genin)
--   praticar = praticar N vezes no ponto de treino da natureza (Alvo = "Pratica_<Natureza>", um dos Lugares)
-- Missões com Quadro = true são as do balcão QUESTS: aleatórias, por rank (D, C, B, A), sem dono.
-- Recompensas especiais: PrimeiroJutsu (1º jutsu do clã), Poder (2º/3º do clã), Estilo (estilo de luta),
-- Jutsu (jutsu de natureza), NovaNatureza (mais uma natureza de chakra).

local MissionData = {}

MissionData.COOLDOWN = 8 * 60 -- segundos até a mesma missão repetível poder ser feita de novo
-- Quadro de missões (balcão QUESTS)
-- (sem limite de missões do quadro por hora ou por dia: dá para fazer quantas quiser)
MissionData.QUADRO_OFERTAS = 4   -- quantas aparecem de cada vez
MissionData.QUADRO_MEMORIA = 8   -- no mínimo, as últimas N concluídas não voltam a aparecer
MissionData.QUADRO_HISTORICO = 60 -- ids guardados no save para o rodízio (ranks com poucas missões usam mais memória)
-- rank da missão que cada rank ninja pode pegar
MissionData.QuadroRank = { Estudante = { "D" }, Genin = { "D", "C" }, Chunin = { "C", "B" }, Jonin = { "B", "A" }, Elite = { "B", "A" }, Kage = { "A" } }

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
	Acampamento = { Name = "Rogue Ninja Hideouts", Pos = Vector3.new(220, 3, 140), Raio = 30 },
	Floresta = { Name = "Forest", Pos = Vector3.new(63, 3, 330), Raio = 120 },
	Escritorio = { Name = "Elder's Office", Pos = Vector3.new(45, 3, -650), Raio = 16 },
	Trilha = { Name = "Forest Trail", Pos = Vector3.new(63, 3, 330), Raio = 22 },
	Cemiterio = { Name = "Old Cemetery", Pos = Vector3.new(160, 3, 305), Raio = 26 }, -- no miolo da floresta, longe da trilha
	-- floresta de fora (só Genin sai da vila)
	Mundo = { Name = "Outer Forest", Pos = Vector3.new(830, 3, -520), Raio = 150 },
	Lago = { Name = "Waterfall Lake", Pos = Vector3.new(950, 3, -450), Raio = 30 },
	Ruinas = { Name = "Forest Ruins", Pos = Vector3.new(805, 3, -685), Raio = 26 },
	ArvoreGigante = { Name = "Great Tree", Pos = Vector3.new(740, 3, -600), Raio = 20 },
	Santuario = { Name = "Meditation Shrine", Pos = Vector3.new(700, 3, -740), Raio = 18 },
	-- pontos de prática das naturezas (construídos pelo script MundoExtras)
	Pratica_Agua = { Name = "Waterfall Lake", Pos = Vector3.new(936, 3, -466), Raio = 10 },
	Pratica_Fogo = { Name = "Lake Shore Fire Pit", Pos = Vector3.new(936, 3, -434), Raio = 10 },
	Pratica_Terra = { Name = "Stone Field", Pos = Vector3.new(850, 3, -600), Raio = 10 },
	Pratica_Raio = { Name = "Storm Rock", Pos = Vector3.new(770, 3, -560), Raio = 10 },
	Pratica_Vento = { Name = "Windy Clearing", Pos = Vector3.new(800, 3, -640), Raio = 10 },
}
-- segundo ponto de fogo (o fogo também pode ser praticado fora do lago)
MissionData.PraticaExtra = { Fogo = { Vector3.new(760, 3, -640) } }

-- esconderijos dos bandidos dentro da floresta murada (missões "derrotar")
MissionData.Esconderijos = {
	{ Name = "HIDDEN CAVE", Tipo = "Caverna", Pos = Vector3.new(-80, 0, 505), Giro = 0 },
	{ Name = "ROGUE HIDEOUT", Tipo = "Cabana", Pos = Vector3.new(220, 0, 140), Giro = 90 },
	{ Name = "RUINED SHED", Tipo = "Ruina", Pos = Vector3.new(215, 0, 292), Giro = 180 },
}

-- NPCs: chave = nome do modelo no workspace (tag "NPC"). Name = nome mostrado no jogo.
MissionData.NPCs = {
	["Kakashi"] = { Name = "Sensei Kaito", Titulo = "Academy Instructor", Fala = "A ninja's path starts with small steps. Ready?" },
	["Might guy"] = { Name = "Coach Gaien", Titulo = "Taijutsu Coach", Fala = "Youth is about sweat! Train with me!" },
	["Naruto"] = { Name = "Kenta", Titulo = "Ramen Lover", Fala = "Hey! You look hungry. Wanna help me out?" },
	["Sakura (Naruto Shippuden)"] = { Name = "Hana", Titulo = "Medic in Training", Fala = "I need herbs for the hospital. Can you help?" },
	["Sasuke"] = { Name = "Ryo", Titulo = "Lone Genin", Fala = "Rogue ninjas again... Don't slow me down." },
	["Hinata"] = { Name = "Yumi", Titulo = "Mission Desk", Quadro = true, Fala = "W-welcome! The mission board is right here... and, um, have you seen my cat?" },
	["Tsunade"] = { Name = "Lady Tsuna", Titulo = "Village Elder", Fala = "Strong ninjas protect the village. Prove yourself." },
	["Pain"] = { Name = "Stranger", Titulo = "???", Fala = "This village... is quieter than I expected." },
	["Ino (PTS)"] = { Name = "Stranger", Titulo = "Wandering Grappler", Fala = "Strength is nothing if you can't control it. Want to learn?" },
	["StarterCharacter"] = { Name = "Villager", Titulo = "Konoha Resident", Fala = "Nice weather today, isn't it?" },
	-- mestres de clã (ClanPowers.Mestres). Onde = dica de onde encontrar
	["Neji"] = { Name = "Seiji", Titulo = "Gentle Fist Prodigy", Onde = "near the village square", Fala = "Fate does not hand out techniques. Earn them." },
	["MestreLee"] = { Name = "Rokuro", Titulo = "Taijutsu Genius", Onde = "near Market Street", Fala = "Hard work beats talent! Show me your sweat!" },
	["MestreInu"] = { Name = "Kiro", Titulo = "Beast Tamer", Onde = "in the village square, with his dog", Fala = "Aka can smell a real ninja. He likes you... I think." },
	["Mahito_Orochimaru_Verified"] = { Name = "Master Jakou", Titulo = "Serpent Sage", Alcance = 45, Onde = "on top of the giant snake in the forest", Fala = "Ssso... the monkey clan still sends children to me." },
	["TumuloPrimeiro"] = { Name = "Grave of Hashiro", Titulo = "The First · Wood Sage", Rezar = true, Onde = "in the old cemetery in the forest", Fala = "(The wood of the grave feels warm. Something is listening.)" },
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
	-- o jogador nasce só com os socos: depois deste passo (ClanPowers.HIST_PRIMEIRO = 6) o mestre do clã ensina o 1º jutsu
	{ Id = "H6", Npc = "Kakashi", Historia = 6, Rank = "D", Name = "Prove Your Fists",
		Desc = "Prove yourself with only your fists: defeat 2 rogue ninjas. Then Sensei Kaito will send you to your clan's master.",
		Tipo = "derrotar", Alvo = "Acampamento", N = 2, Recompensa = { XP = 600, Coins = 150 },
		Conversa = {
			{ Fala = "You met everyone. Good. Now tell me: you have no jutsu yet. Why do you think that is?", Opcoes = {
				{ T = "Because I have to earn it first.", R = "Exactly. A jutsu in untrained hands only hurts its owner.", Bom = true },
				{ T = "Because you are all too slow to teach me.", R = "Maybe. Or maybe you are too fast to listen." } } },
			{ Fala = "There are rogue ninjas in the forest outside the village. Beat two of them with nothing but your fists, and I will tell you who can teach you the first technique of your clan." },
		} },
	-- (não repete o "derrotar" do H6: aqui o aluno só reconhece os esconderijos, sem lutar de novo)
	{ Id = "H7", Npc = "Kakashi", Historia = 7, Rank = "D", Name = "Rogue Ninjas Nearby",
		Desc = "Rogue ninjas keep coming. Scout the Rogue Ninja Hideouts in the forest and report what you see.",
		Tipo = "ir", Alvo = "Acampamento", N = 1, Obj = "Scout the Rogue Ninja Hideouts",
		Recompensa = { XP = 1200, Coins = 250, Pontos = 2 } },
	{ Id = "H8", Npc = "Kakashi", Historia = 8, Rank = "C", Name = "The Ninja Exam", Nivel = 10,
		Desc = "The Ninja Exam is a duel: defeat Sensei Kaito to become a Genin.",
		Tipo = "exame", Mapa = "ExameNinja", N = 1, Recompensa = { XP = 1500, Coins = 500, Pontos = 3 }, Promove = "Genin" },
	-- (Chunin e Jonin: continuação do caminho, a definir)
}

-- Missões do QUADRO (balcão QUESTS): não são de nenhum personagem. O servidor sorteia MissionData.QUADRO_OFERTAS
-- de cada vez entre as do rank do jogador, sem repetir as últimas concluídas.
do
	local PREMIO = { D = { XP = 380, Coins = 60 }, C = { XP = 950, Coins = 150 }, B = { XP = 2100, Coins = 320, Pontos = 1 }, A = { XP = 4200, Coins = 650, Pontos = 2 } }
	-- { id, rank, nome, tipo, alvo, n, descrição, objetivo (texto opcional do rastreador) }
	-- 50 missões: levar algo a alguém ("falar" com o NPC), achar algo ("ir"/"coletar") e derrotar bandidos ("derrotar")
	local lista = {
		{ "Ramen", "D", "Ramen Delivery", "ir", "Mercado", 1, "A hot bowl of ramen must reach Market Street before it gets cold." },
		{ "Gato", "D", "Lost Cat", "ir", "Oeste", 1, "A cat ran off again. It was last seen in the West District." },
		{ "Pergaminho", "D", "Scroll Delivery", "ir", "Academia", 1, "Take a sealed scroll to the Ninja Academy." },
		{ "Recado", "D", "Message for the Elder", "ir", "Escritorio", 1, "Carry a message to the Elder's Office." },
		{ "Trilha", "D", "Trail Check", "ir", "Trilha", 1, "Walk the forest trail and check that it is clear." },
		{ "Flores", "D", "Flowers for the Graves", "ir", "Cemiterio", 1, "Leave flowers at the old cemetery in the forest." },
		{ "Ervas", "D", "Herbs for the Hospital", "coletar", "Floresta", 4, "The hospital is low on medicine. Collect 4 glowing herbs." },
		{ "Treino", "D", "Morning Drill", "treinar", nil, 1, "Train once at the Ninja Academy." },
		{ "Ladroes", "D", "Thieves by the Wall", "derrotar", "Acampamento", 3, "Rogue ninjas are robbing travelers. Defeat 3 of them." },
		{ "Patrulha", "D", "Hideout Patrol", "derrotar", "Acampamento", 5, "Thin out the rogue ninjas at the hideouts. Defeat 5." },
		{ "Varredura", "C", "Hideout Sweep", "derrotar", "Acampamento", 9, "Clear the hideouts. Defeat 9 rogue ninjas." },
		{ "ErvasRaras", "C", "Rare Herbs", "coletar", "Floresta", 8, "A hard medicine needs 8 glowing herbs." },
		{ "Cachoeira", "C", "Waterfall Report", "ir", "Lago", 1, "Something was seen at the Waterfall Lake in the outer forest. Go check." },
		{ "Ruinas", "C", "Scout the Ruins", "ir", "Ruinas", 1, "Scout the ruins in the outer forest and come back alive." },
		{ "Arvore", "C", "Signal from the Great Tree", "ir", "ArvoreGigante", 1, "A signal flare went up near the Great Tree. Investigate." },
		{ "Feras", "C", "Road Clearing", "derrotar", "Mundo", 6, "The roads of the outer forest are unsafe. Defeat 6 enemies out there." },
		{ "TreinoDuplo", "C", "Double Drill", "treinar", nil, 2, "Train twice at the Ninja Academy." },
		{ "Santuario", "C", "Shrine Offering", "ir", "Santuario", 1, "Take an offering to the Meditation Shrine in the outer forest." },
		{ "Cerco", "B", "Break the Siege", "derrotar", "Acampamento", 16, "The hideouts are full again. Defeat 16 rogue ninjas." },
		{ "Cacada", "B", "Outer Forest Hunt", "derrotar", "Mundo", 14, "Hunt down 14 enemies in the outer forest." },
		{ "Estoque", "B", "Hospital Stockpile", "coletar", "Floresta", 12, "The hospital wants a full stock: 12 glowing herbs." },
		{ "RondaRuinas", "B", "Night Watch at the Ruins", "ir", "Ruinas", 1, "Stand watch at the forest ruins." },
		{ "TreinoPesado", "B", "Heavy Drill", "treinar", nil, 3, "Train three times at the Ninja Academy." },
		{ "Limpeza", "A", "Forest Purge", "derrotar", "Mundo", 28, "The outer forest must be safe by dawn. Defeat 28 enemies." },
		{ "Queda", "A", "Fall of the Hideouts", "derrotar", "Acampamento", 26, "Wipe out the hideouts. Defeat 26 rogue ninjas." },
		{ "Colheita", "A", "Great Harvest", "coletar", "Floresta", 18, "A whole village needs medicine. Collect 18 glowing herbs." },
		{ "Mestre", "A", "Master Drill", "treinar", nil, 5, "Train five times at the Ninja Academy." },
		-- levar algo a alguém (D)
		{ "EntregaKenta", "D", "Ramen for Kenta", "falar", "Naruto", 1, "Kenta left his lunch at the stand again. Bring him a fresh bowl.", "Deliver the ramen to Kenta" },
		{ "EntregaHana", "D", "Herb Bundle for Hana", "falar", "Sakura (Naruto Shippuden)", 1, "Hana is waiting on a bundle of dried herbs. Deliver it before she runs out.", "Deliver the herbs to Hana" },
		{ "EntregaGaien", "D", "Gaien's Weights", "falar", "Might guy", 1, "Coach Gaien left his training weights by the gate. Carry them to him.", "Bring the weights to Coach Gaien" },
		{ "EntregaKaito", "D", "Attendance Scroll", "falar", "Kakashi", 1, "Sensei Kaito needs the class attendance scroll signed today.", "Deliver the scroll to Sensei Kaito" },
		{ "EntregaRyo", "D", "Letter for Ryo", "falar", "Sasuke", 1, "A sealed letter is addressed to Ryo, the lone genin. Find him and hand it over.", "Deliver the letter to Ryo" },
		{ "EntregaTsuna", "D", "Tea for Lady Tsuna", "falar", "Tsunade", 1, "The Elder's tea is getting cold. Hurry to her office.", "Deliver the tea to Lady Tsuna" },
		-- achar algo (D)
		{ "AcharKunai", "D", "Lost Kunai", "ir", "Trilha", 1, "A student dropped a kunai on the forest trail. Find it.", "Find the lost kunai on the forest trail" },
		{ "AcharBandana", "D", "Missing Headband", "ir", "Praca", 1, "Someone lost a headband in the village square. Look around and find it.", "Search the village square for the headband" },
		{ "AcharFilhote", "D", "Lost Puppy", "ir", "Floresta", 1, "A puppy wandered into the forest. Find it before dark.", "Find the puppy in the forest" },
		-- rank C
		{ "EntregaKiro", "C", "Treats for Aka", "falar", "MestreInu", 1, "Kiro's dog Aka has run out of treats. Bring a bag to Kiro.", "Deliver the treats to Kiro" },
		{ "EntregaRokuro", "C", "Weights for Rokuro", "falar", "MestreLee", 1, "Rokuro trains with heavy wrist weights and lost a pair. Bring him new ones.", "Deliver the weights to Rokuro" },
		{ "EntregaJakou", "C", "Medicine for Master Jakou", "falar", "Mahito_Orochimaru_Verified", 1, "Master Jakou is out of medicine on top of the giant snake. Take him a case.", "Deliver the medicine to Master Jakou" },
		{ "AcharJoia", "C", "Family Heirloom", "ir", "Cemiterio", 1, "A widow lost an heirloom while visiting the old cemetery. Search the graves.", "Find the heirloom in the old cemetery" },
		{ "AcharCaravana", "C", "Lost Caravan", "ir", "Mundo", 1, "A merchant caravan vanished in the outer forest. Find where it went.", "Search the outer forest for the caravan" },
		{ "Batedores", "C", "Rogue Scouts", "derrotar", "Acampamento", 7, "Rogue scouts are watching the village gates. Defeat 7 of them." },
		-- rank B
		{ "EntregaSeiji", "B", "Sealed Message for Seiji", "falar", "Neji", 1, "A sealed message must reach the Gentle Fist prodigy. Do not let anyone read it.", "Deliver the message to Seiji" },
		{ "EntregaUrgente", "B", "Urgent Report", "falar", "Tsunade", 1, "A scout report says the hideouts are moving. Get it to Lady Tsuna now.", "Deliver the report to Lady Tsuna" },
		{ "AcharEscoteiro", "B", "Missing Scout", "ir", "Santuario", 1, "A scout went silent near the Meditation Shrine. Find out what happened.", "Search the Meditation Shrine for the scout" },
		{ "Invasao", "B", "Night Raid", "derrotar", "Acampamento", 22, "The hideouts plan a raid on the village. Defeat 22 rogue ninjas first." },
		-- rank A
		{ "EntregaOrdem", "A", "Sealed Order", "falar", "Tsunade", 1, "A sealed order from the capital must reach Lady Tsuna unopened.", "Deliver the sealed order to Lady Tsuna" },
		{ "EntregaProibido", "A", "Forbidden Scroll", "falar", "Ino (PTS)", 1, "A dangerous scroll must be handed to the Wandering Grappler. Trust no one on the way.", "Deliver the scroll to the Wandering Grappler" },
		{ "AcharArtefato", "A", "Lost Artifact", "ir", "Ruinas", 1, "An ancient artifact is hidden in the forest ruins. Recover it.", "Recover the artifact in the forest ruins" },
		{ "Guardas", "A", "Bandit King's Guards", "derrotar", "Mundo", 34, "The Bandit King's guards roam the outer forest. Defeat 34 of them." },
	}
	for _, q in ipairs(lista) do
		local pr = PREMIO[q[2]]
		table.insert(MissionData.Missoes, { Id = "Q_" .. q[1], Npc = "Quadro", Quadro = true, Rank = q[2], Name = q[3],
			Tipo = q[4], Alvo = q[5], N = q[6], Desc = q[7], Obj = q[8], Recompensa = { XP = pr.XP, Coins = pr.Coins, Pontos = pr.Pontos } })
	end
end

-- Missões do clã (Fase 4): liberam o 2º e o 3º poder do clã. Dadas pela Lady Tsuna,
-- só aparecem para quem é daquele clã (Cla), feitas uma vez só (Unica).
-- RankMin = rank mínimo. Requer = missão que precisa estar feita antes. Recompensa.Poder = posição do poder liberado.
do
	local ClanPowers = require(script.Parent:WaitForChild("ClanPowers"))
	for _, clan in ipairs({ "Uzu", "Uchiwa", "Mokuton", "Byakugan", "Lee", "Shirokiba", "Enma", "Inu" }) do
		local c = ClanPowers.Clans[clan]
		local mestre = ClanPowers.Mestres[clan]
		local nivel2, rank2 = ClanPowers.Requisito(clan, 2)
		local nivel3, rank3 = ClanPowers.Requisito(clan, 3)
		table.insert(MissionData.Missoes, { Id = "C1_" .. clan, Npc = mestre.Npc, Rank = "D", Cla = clan, Unica = true, HistoriaMin = ClanPowers.HIST_PRIMEIRO,
			Name = "Clan Lesson: " .. c.Powers[1].Name,
			Desc = "Your clan's master will teach you your first jutsu. Defeat 3 rogue ninjas at the hideouts to show you are ready.",
			Tipo = "derrotar", Alvo = "Acampamento", N = 3, Recompensa = { XP = 500, Coins = 120, Poder = 1 },
			Conversa = {
				{ Fala = "So you carry the blood of the " .. clan .. " clan. A technique is not a gift, it is a debt. Why should I teach you?", Opcoes = {
					{ T = "Because I will honor the clan with it.", R = "Good. That is the only answer I accept.", Bom = true },
					{ T = "Because I need to get stronger fast.", R = "Fast is how ninjas die. But the fire is there." } } },
				{ Fala = "Defeat 3 rogue ninjas at the hideouts. Come back, and " .. c.Powers[1].Name .. " is yours." },
			} })
		table.insert(MissionData.Missoes, { Id = "C2_" .. clan, Npc = mestre.Npc, Rank = "C", Cla = clan, Unica = true, Requer = "C1_" .. clan,
			Name = "Clan Secret: " .. c.Powers[2].Name, Nivel = nivel2, RankMin = rank2,
			Desc = "Your master knows your clan's secret. Defeat 8 rogue ninjas at the hideouts to prove you are ready.",
			Tipo = "derrotar", Alvo = "Acampamento", N = 8, Recompensa = { XP = 800, Coins = 150, Poder = 2 } })
		table.insert(MissionData.Missoes, { Id = "C3_" .. clan, Npc = mestre.Npc, Rank = "B", Cla = clan, Unica = true, Requer = "C2_" .. clan,
			Name = "Clan Trial: " .. c.Powers[3].Name, Nivel = nivel3, RankMin = rank3,
			Desc = "The final trial of your clan. Defeat 15 rogue ninjas at the hideouts to master your strongest technique.",
			Tipo = "derrotar", Alvo = "Acampamento", N = 15, Recompensa = { XP = 2500, Coins = 400, Poder = 3 } })
	end
end

-- Missões dos mestres (Fase 5): ensinam um estilo de luta (Recompensa.Estilo). Feitas uma vez.
-- Estilos guardados (sem missão, não aparecem no jogo): Boxe, Karatê, Muay Thai e Jiu-Jitsu.
MissionData.Desativadas = {}
table.insert(MissionData.Desativadas, { Id = "E_Boxe", Npc = "Might guy", Rank = "D", Unica = true, Nivel = 5,
	Name = "Boxing Lessons", Desc = "Coach Gaien will teach you Boxing. Train 5 times at the Ninja Academy.",
	Tipo = "treinar", N = 5, Recompensa = { XP = 500, Coins = 100, Estilo = "Boxe" } })
table.insert(MissionData.Desativadas, { Id = "E_Karate", Npc = "Kakashi", Rank = "C", Unica = true, Nivel = 10,
	Name = "Karate Discipline", Desc = "Sensei Kaito teaches Karate to the disciplined. Defeat 10 rogue ninjas at the hideouts.",
	Tipo = "derrotar", Alvo = "Acampamento", N = 10, Recompensa = { XP = 900, Coins = 150, Estilo = "Karate" } })
table.insert(MissionData.Desativadas, { Id = "E_MuayThai", Npc = "Sasuke", Rank = "C", Unica = true, Nivel = 15, RankMin = "Genin",
	Name = "Art of Eight Limbs", Desc = "Ryo only trains Genin. Defeat 12 rogue ninjas and he will teach you Muay Thai.",
	Tipo = "derrotar", Alvo = "Acampamento", N = 12, Recompensa = { XP = 1300, Coins = 200, Estilo = "MuayThai" } })
table.insert(MissionData.Desativadas, { Id = "E_JiuJitsu", Npc = "Ino (PTS)", Rank = "B", Unica = true, Nivel = 20,
	Name = "The Gentle Art", Desc = "The Stranger wants 8 glowing herbs from the forest before teaching Jiu-Jitsu.",
	Tipo = "coletar", Alvo = "Floresta", N = 8, Recompensa = { XP = 1800, Coins = 250, Estilo = "JiuJitsu" } })

-- Único estilo extra no jogo: Lee (Coach Gaien). Exige nível, treinos na Academia e kills só com taijutsu
-- (golpes de punho/chute; sem jutsu). "Treinos" é conferido em MissionServer (data.Estilos.Treinos).
table.insert(MissionData.Missoes, { Id = "E_Lee", Npc = "Might guy", Rank = "C", Unica = true, Nivel = 25, Treinos = 30,
	Name = "Path of the Green Beast",
	Desc = "Coach Gaien will teach you the Lee style and the Eight Inner Gates. Train 30 times at the Academy first, then defeat 100 enemies using only taijutsu: no jutsu!",
	Tipo = "taijutsu", N = 100, Recompensa = { XP = 3000, Coins = 500, Estilo = "Lee" } })

-- Missões de natureza: o mestre de cada natureza ensina os jutsus (Recompensa.Jutsu). Só aparecem para quem
-- tem aquela natureza (Natureza) e já aprendeu o 1º jutsu do clã (HistoriaMin). Feitas uma vez.
do
	local NatureData = require(script.Parent:WaitForChild("NatureData"))
	local ClanPowers = require(script.Parent:WaitForChild("ClanPowers"))
	-- cada natureza é praticada no seu lugar da floresta de fora (pontos construídos pelo script MundoExtras)
	local prova = {
		Agua = "Water must be felt. Go to the Waterfall Lake in the outer forest and practice shaping water",
		Fogo = "Fire needs air and room. Practice at the fire pit by the lake, or at the old fire pit deeper in the forest,",
		Terra = "Earth answers to patience. Practice at the Stone Field in the outer forest",
		Raio = "Lightning is born in your own chakra. Go to Storm Rock and try to form electricity in your hands",
		Vento = "Wind has to be gathered. Go to the Windy Clearing and gather the wind in your palms",
	}
	for _, id in ipairs(NatureData.Order) do
		local t = NatureData.Tipos[id]
		local mestre = MissionData.NPCs[t.Mestre].Name
		local p = prova[id]
		-- 4 etapas por natureza; em cada uma o jogador escolhe 1 entre 2 jutsus (Recompensa.Escolha)
		local conversa = {
			{ { Fala = "I can feel it. You carry the " .. t.Name .. " nature. Most people never notice their own chakra. How does it feel to you?", Opcoes = {
				{ T = "Like something that wants to get out.", R = "Then it is awake. Good. Now it needs a shape.", Bom = true },
				{ T = "I don't feel anything yet.", R = "You will. It always starts quiet." } } },
			  { Fala = p .. " 3 times. Do that, and you will choose your first " .. t.Name .. " technique." } },
			{ { Fala = "You handle your first technique well. The next one burns a lot more chakra. What will you do when it runs out mid-fight?", Opcoes = {
				{ T = "Fall back on my fists until it returns.", R = "Good. A ninja with one plan is a dead ninja.", Bom = true },
				{ T = "It won't run out.", R = "It always runs out. Remember this talk when it does." } } },
			  { Fala = "Go back to where you first shaped it and practice 6 more times. Then you choose your second technique." } },
			{ { Fala = "A Chunin must know when to hold back and when to let everything out. Which one are you?", Opcoes = {
				{ T = "I protect my team first.", R = "Then your power has a reason. That is rare.", Bom = true },
				{ T = "I just want to win.", R = "Winning is easy to want. Surviving the next fight is harder." } } },
			  { Fala = "Practice 9 more times. Your third technique is a powerful one: choose it well." } },
			{ { Fala = "Few reach this point. The last technique of " .. t.Name .. " can turn a battle. It can also empty you. Are you ready?", Opcoes = {
				{ T = "I am ready for what it costs.", R = "Then show me with 12 more practices. Only then.", Bom = true },
				{ T = "I only want the power.", R = "Power without control destroys the one who holds it. Prove you can control it." } } },
			  { Fala = "Practice 12 more times. Then choose the technique that will define your " .. t.Name .. "." } },
		}
		local titulos = { "Nature", "Mastery", "Advanced", "Ultimate" }
		for k, tinfo in ipairs(NatureData.TIERS) do
			local nomeA, nomeB = t.Tiers[k][1].Name, t.Tiers[k][2].Name
			local descs = {
				p .. " 3 times. " .. mestre .. " will let you choose: " .. nomeA .. " or " .. nomeB .. ".",
				"The next technique burns far more chakra. Practice 6 more times and " .. mestre .. " will let you choose: " .. nomeA .. " or " .. nomeB .. ".",
				"Only a Chunin can learn this. Practice 9 more times and choose: " .. nomeA .. " or " .. nomeB .. ".",
				"The ultimate technique of " .. t.Name .. ". Practice 12 more times and choose: " .. nomeA .. " or " .. nomeB .. ".",
			}
			table.insert(MissionData.Missoes, { Id = "N" .. k .. "_" .. id, Npc = t.Mestre, Rank = "C", Natureza = id, Unica = true,
				Requer = k > 1 and ("N" .. (k - 1) .. "_" .. id) or nil, HistoriaMin = k == 1 and ClanPowers.HIST_PRIMEIRO or nil,
				Nivel = tinfo.Nivel > 0 and tinfo.Nivel or nil, RankMin = tinfo.Rank,
				Name = t.Name .. " " .. titulos[k] .. ": " .. nomeA .. " / " .. nomeB,
				Desc = descs[k],
				Tipo = "praticar", Alvo = "Pratica_" .. id, N = tinfo.Pratica,
				Recompensa = { XP = ({ 700, 1800, 3500, 6000 })[k], Coins = ({ 120, 300, 600, 1000 })[k], Escolha = { Natureza = id, Tier = k } },
				Conversa = conversa[k] })
		end
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
		Desc = "Your blood carries a Kekkei Genkai. Defeat 6 rogue ninjas at the hideouts and Lady Tsuna will awaken its power.",
		Tipo = "derrotar", Alvo = "Acampamento", N = 6, Recompensa = { XP = 900, Coins = 180, KekkeiPoder = true },
		Conversa = {
			{ Fala = "I felt it the day you arrived. Your blood is different. A Kekkei Genkai sleeps in you. Do you know what that means?", Opcoes = {
				{ T = "A power only my bloodline has.", R = "Yes. And a power nobody else can teach you to control. Only you can.", Bom = true },
				{ T = "That I'm stronger than everyone.", R = "It means you are a bigger target. Strength comes from control." } } },
			{ Fala = "Defeat 6 rogue ninjas at the hideouts using only what you know. When your chakra is pushed to the limit, the bloodline will wake up." },
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

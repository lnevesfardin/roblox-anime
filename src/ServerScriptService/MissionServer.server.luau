-- Script: ServerScriptService > MissionServer
-- Fase 3: missões, NPCs que conversam, ranks ninja e o Exame Ninja.
-- MissionAction (RemoteFunction): "estado" | "aceitar", idDaMissao | "desistir" | "conversou", { escolhas }
-- Duas missões ao mesmo tempo: m.Ativa = missão principal (história) e m.Lado = missão lateral (as outras).
-- Só a lateral pode ser abandonada.
-- MissionEvent  (RemoteEvent, servidor -> cliente): { tipo = "dialogo" | "concluida" | "aviso" | "estado" ... }
-- Outros scripts avisam progresso pelo BindableEvent ServerStorage.MissaoProgresso: Fire(player, tipo, quantidade)
-- A partida do Exame começa pelo BindableEvent ServerStorage.IniciarPartida (WaveServer) e
-- a vitória chega pelo ServerStorage.PartidaVencida (player, mapId).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local MissionData = require(ReplicatedStorage:WaitForChild("MissionData"))
local ClanPowers = require(ReplicatedStorage:WaitForChild("ClanPowers"))
local NatureData = require(ReplicatedStorage:WaitForChild("NatureData"))
local KekkeiData = require(ReplicatedStorage:WaitForChild("KekkeiData"))
local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))
local InimigoGolpe = require(ServerStorage:WaitForChild("InimigoGolpe"))

local action = Instance.new("RemoteFunction")
action.Name = "MissionAction"
action.Parent = ReplicatedStorage
local evento = Instance.new("RemoteEvent")
evento.Name = "MissionEvent"
evento.Parent = ReplicatedStorage
local progressoEv = Instance.new("BindableEvent")
progressoEv.Name = "MissaoProgresso"
progressoEv.Parent = ServerStorage

---------------------------------------------------------------
-- Estado do jogador
---------------------------------------------------------------
local function dados(player)
	local data = PlayerData.Get(player)
	if not data then return nil end
	if type(data.Missoes) ~= "table" then
		data.Missoes = {}
	end
	local m = data.Missoes
	m.Historia = tonumber(m.Historia) or 0
	-- a história mudou de 5 para 7 passos: converte o progresso antigo uma vez
	if (tonumber(m.V) or 0) < 2 then
		local antigo = { [0] = 0, 1, 5, 5, 6, 7 }
		m.Historia = antigo[math.clamp(m.Historia, 0, 5)]
		if type(m.Ativa) == "table" and tostring(m.Ativa.Id):sub(1, 1) == "H" then m.Ativa = nil end
		m.V = 2
	end
	-- a história ganhou o passo 6 (Your First Jutsu): quem já tinha passado dele avança um
	if (tonumber(m.V) or 0) < 3 then
		if m.Historia >= 6 then m.Historia += 1 end
		if type(m.Ativa) == "table" and tostring(m.Ativa.Id):match("^H%d") then m.Ativa = nil end
		m.V = 3
	end
	if type(data.Rank) == "string" and data.Rank ~= "Estudante" then m.Historia = MissionData.TotalHistoria end
	if type(m.Cool) ~= "table" then m.Cool = {} end
	if type(m.Feitas) ~= "table" then m.Feitas = {} end -- missões únicas já feitas
	-- o 1º jutsu do clã passou a vir do mestre do clã (C1_<Clã>): quem já tinha aprendido na história continua com ele
	if (tonumber(m.V) or 0) < 4 then
		local clan = data.Cla and data.Cla.Id
		if clan and m.Historia >= ClanPowers.HIST_PRIMEIRO then m.Feitas["C1_" .. clan] = true end
		m.V = 4
	end
	-- quadro de missões: Of = ofertas atuais, Rec = últimas concluídas, H = início da hora, N = concluídas nesta hora
	if type(m.Q) ~= "table" then m.Q = {} end
	local q = m.Q
	if type(q.Of) ~= "table" then q.Of = {} end
	if type(q.Rec) ~= "table" then q.Rec = {} end
	q.N = tonumber(q.N) or 0
	ClanPowers.Sincronizar(data) -- trocou de clã: missões do clã antigo somem
	if type(m.Ativa) ~= "table" or not MissionData.Get(m.Ativa.Id) then m.Ativa = nil end
	if type(m.Lado) ~= "table" or not MissionData.Get(m.Lado.Id) then m.Lado = nil end
	-- saves antigos: missão que não é da história ia no espaço único; passa para o lado
	if m.Ativa and not MissionData.Get(m.Ativa.Id).Historia then
		if not m.Lado then m.Lado = m.Ativa end
		m.Ativa = nil
	end
	if type(data.Rank) ~= "string" then data.Rank = "Estudante" end
	return data, m
end

-- Quadro: completa as ofertas do jogador com missões do rank dele, sem repetir as últimas concluídas
-- nem dois pedidos iguais (mesmo tipo e lugar) ao mesmo tempo.
local rngQuadro = Random.new()
local function encherQuadro(data, m)
	local q = m.Q
	local ranks = MissionData.QuadroRank[data.Rank] or MissionData.QuadroRank.Estudante
	-- tira ofertas que não existem mais ou saíram do rank do jogador
	for i = #q.Of, 1, -1 do
		local missao = MissionData.Get(q.Of[i])
		if not (missao and missao.Quadro and table.find(ranks, missao.Rank)) then table.remove(q.Of, i) end
	end
	local function pedido(x) return x.Tipo .. "/" .. tostring(x.Alvo) end
	local usados = {}
	for _, id in ipairs(q.Of) do usados[pedido(MissionData.Get(id))] = true end
	for _, esp in ipairs({ "Ativa", "Lado" }) do
		local x = m[esp] and MissionData.Get(m[esp].Id)
		if x and x.Quadro then usados[pedido(x)] = true end
	end
	-- rodízio: nenhuma missão volta antes de todas as outras do rank terem aparecido. A memória cresce com o
	-- tamanho do rank (rank com poucas missões = memória maior), então só repete quando já passou por todas.
	local pool = 0
	for _, missao in ipairs(MissionData.Missoes) do
		if missao.Quadro and table.find(ranks, missao.Rank) then pool += 1 end
	end
	local memoria = math.max(MissionData.QUADRO_MEMORIA, pool - MissionData.QUADRO_OFERTAS)
	local recentes = {}
	for i = math.max(1, #q.Rec - memoria + 1), #q.Rec do recentes[q.Rec[i]] = true end
	local candidatas = {}
	for _, missao in ipairs(MissionData.Missoes) do
		if missao.Quadro and table.find(ranks, missao.Rank) and not table.find(q.Of, missao.Id) and not recentes[missao.Id]
			and not (m.Lado and m.Lado.Id == missao.Id) then
			table.insert(candidatas, missao)
		end
	end
	-- duas passadas: primeiro sem pedidos repetidos; se faltar, aceita repetir o tipo
	for passada = 1, 2 do
		while #q.Of < MissionData.QUADRO_OFERTAS and #candidatas > 0 do
			local escolhida
			local ordem = {}
			for i = 1, #candidatas do ordem[i] = i end
			for i = #ordem, 2, -1 do
				local j = rngQuadro:NextInteger(1, i)
				ordem[i], ordem[j] = ordem[j], ordem[i]
			end
			for _, i in ipairs(ordem) do
				if passada == 2 or not usados[pedido(candidatas[i])] then escolhida = i break end
			end
			if not escolhida then break end
			local missao = table.remove(candidatas, escolhida)
			usados[pedido(missao)] = true
			table.insert(q.Of, missao.Id)
		end
	end
	-- rank com poucas missões: se ainda faltar, voltam as concluídas há mais tempo
	for _, id in ipairs(q.Rec) do
		if #q.Of >= MissionData.QUADRO_OFERTAS then break end
		local missao = MissionData.Get(id)
		if missao and missao.Quadro and table.find(ranks, missao.Rank) and not table.find(q.Of, id) and not (m.Lado and m.Lado.Id == id) then
			table.insert(q.Of, id)
		end
	end
end

local function disponivel(data, m, missao)
	if (m.Ativa and m.Ativa.Id == missao.Id) or (m.Lado and m.Lado.Id == missao.Id) then return false end
	if missao.Quadro then
		return table.find(m.Q.Of, missao.Id) ~= nil
	end
	if missao.Historia and m.Historia ~= missao.Historia - 1 then return false end -- história: só o próximo passo aparece
	if missao.Cla and not (data.Cla and data.Cla.Id == missao.Cla) then return false end
	if missao.Unica and m.Feitas[missao.Id] then return false end
	if missao.Requer and not m.Feitas[missao.Requer] then return false end
	if missao.Natureza and not NatureData.Tem(data, missao.Natureza) then return false end
	if missao.NovaNatureza and (NatureData.Contar(data) == 0 or NatureData.Contar(data) >= NatureData.MAX) then return false end
	if missao.HistoriaMin and m.Historia < missao.HistoriaMin then return false end
	if missao.Kekkei and not KekkeiData.DoSave(data) then return false end
	if missao.Nivel and data.Level < missao.Nivel then return false, "Requires level " .. missao.Nivel end
	if missao.Treinos then
		local feitos = require(ReplicatedStorage:WaitForChild("FightStyles")).Garantir(data).Treinos
		if feitos < missao.Treinos then return false, ("Requires %d trainings at the Academy (%d done)"):format(missao.Treinos, feitos) end
	end
	if missao.RankMin and MissionData.RankIndex(data.Rank) < MissionData.RankIndex(missao.RankMin) then
		return false, "Requires rank " .. MissionData.RankName(missao.RankMin)
	end
	if missao.Historia then
		return m.Historia == missao.Historia - 1
	end
	return os.time() >= (m.Cool[missao.Id] or 0)
end

local function estado(player)
	local data, m = dados(player)
	if not data then return nil end
	local disp = {}
	for _, missao in ipairs(MissionData.Missoes) do
		if not missao.Quadro and disponivel(data, m, missao) then
			disp[missao.Npc] = true
		end
	end
	local function resumo(e)
		if not e then return nil end
		local missao = MissionData.Get(e.Id)
		return { Id = missao.Id, P = e.P, N = missao.N }
	end
	-- a atendente do balcão sempre mostra o aviso: o quadro não tem limite de missões
	for key, info in pairs(MissionData.NPCs) do
		if info.Quadro then disp[key] = true end
	end
	return { Ativa = resumo(m.Ativa), Lado = resumo(m.Lado), Rank = data.Rank, NpcsComMissao = disp, Historia = m.Historia }
end

local ESPACOS = { "Ativa", "Lado" }
local function espacoDe(missao)
	return missao.Historia and "Ativa" or "Lado"
end
-- primeira missão ativa (principal ou lateral) que passa no teste. Devolve espaço, missão
local function acharAtiva(m, teste)
	for _, esp in ipairs(ESPACOS) do
		local e = m[esp]
		local missao = e and MissionData.Get(e.Id)
		if missao and teste(missao) then return esp, missao end
	end
	return nil
end

local function enviarEstado(player)
	evento:FireClient(player, { tipo = "estado", estado = estado(player) })
end

local function aviso(player, texto, bom)
	evento:FireClient(player, { tipo = "aviso", texto = texto, bom = bom })
end

---------------------------------------------------------------
-- Ranks
---------------------------------------------------------------
local function atualizarRank(player)
	local data = dados(player)
	if not data then return end
	local i = MissionData.RankIndex(data.Rank)
	while MissionData.Ranks[i + 1] do
		local prox = MissionData.Ranks[i + 1]
		if prox.Exame or data.Level < prox.Level then break end
		i += 1
		data.Rank = prox.Id
		aviso(player, "RANK UP!  You are now " .. prox.Name, true)
	end
	player:SetAttribute("Rank", data.Rank)
end

-- rank ninja em cima da cabeça do jogador (todos veem); muda de cor a cada rank
local COR_RANK = { Estudante = Color3.fromRGB(200, 200, 205), Genin = Color3.fromRGB(110, 220, 130), Chunin = Color3.fromRGB(90, 170, 255),
	Jonin = Color3.fromRGB(190, 120, 255), Elite = Color3.fromRGB(255, 170, 60), Kage = Color3.fromRGB(255, 80, 80) }
local function placaRank(player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then return end
	local rank = player:GetAttribute("Rank") or "Estudante"
	local b = head:FindFirstChild("PlacaRank")
	if not b then
		b = Instance.new("BillboardGui")
		b.Name = "PlacaRank"
		b.Size = UDim2.fromOffset(180, 22)
		b.StudsOffset = Vector3.new(0, 2.9, 0)
		b.MaxDistance = 70
		b.LightInfluence = 0
		local t = Instance.new("TextLabel")
		t.Name = "Texto"
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextSize = 15
		t.TextStrokeTransparency = 0.25
		t.Parent = b
		b.Parent = head
	end
	b.Texto.Text = "[ " .. string.upper(MissionData.RankName(rank)) .. " ]"
	b.Texto.TextColor3 = COR_RANK[rank] or COR_RANK.Estudante
end

---------------------------------------------------------------
-- Concluir e progredir
---------------------------------------------------------------
local function concluir(player, esp)
	local data, m = dados(player)
	esp = esp or "Ativa"
	if not data or not m[esp] then return end
	local missao = MissionData.Get(m[esp].Id)
	m[esp] = nil
	if missao.Historia then
		m.Historia = math.max(m.Historia, missao.Historia)
	elseif missao.Quadro then
		-- sai das ofertas e entra na memória (não repete tão cedo); q.N só conta quantas já foram feitas
		local q = m.Q
		local i = table.find(q.Of, missao.Id)
		if i then table.remove(q.Of, i) end
		local antiga = table.find(q.Rec, missao.Id)
		if antiga then table.remove(q.Rec, antiga) end -- a ordem mostra a última vez que cada missão foi feita
		table.insert(q.Rec, missao.Id)
		while #q.Rec > MissionData.QUADRO_HISTORICO do table.remove(q.Rec, 1) end
		q.N += 1
		encherQuadro(data, m)
		aviso(player, "Board mission complete! New missions are waiting at the board.", true)
	elseif missao.Unica then
		m.Feitas[missao.Id] = true
	else
		m.Cool[missao.Id] = os.time() + MissionData.COOLDOWN
	end
	local r = missao.Recompensa or {}
	if r.XP then PlayerData.AddXP(player, r.XP * PlayerData.GetBoostMult(player, "XP")) end
	if r.Coins then PlayerData.AddCoins(player, r.Coins * PlayerData.GetBoostMult(player, "Coins")) end
	if r.Pontos then
		data.Atributos.Pontos += r.Pontos
		PlayerData.Refresh(player)
	end
	if r.PrimeiroJutsu then
		local clan = ClanPowers.Sincronizar(data)
		local c = clan and ClanPowers.Clans[clan]
		if c then aviso(player, ("NEW JUTSU: %s  [%s]"):format(c.Powers[1].Name, ClanPowers.TEXTO[1]), true) end
	end
	if r.KekkeiPoder then
		local k = KekkeiData.DoSave(data)
		if k then aviso(player, ("NEW JUTSU: %s  [%s]"):format(KekkeiData.Tipos[k].Poder.Name, KekkeiData.TECLA), true) end
		local atualizar = ServerStorage:FindFirstChild("AtualizarPoderes")
		if atualizar then atualizar:Fire(player) end
	end
	if r.Jutsu then
		local j = NatureData.Jutsu(r.Jutsu)
		local n = NatureData.Garantir(data)
		if j then
			n.Jutsus[j.Id] = true
			-- já equipa numa tecla livre (G ou H)
			for i = 1, #NatureData.KEYS do
				if not n.Equip[i] then n.Equip[i] = j.Id break end
			end
			aviso(player, ("NEW JUTSU: %s!  Equip it in NATURES"):format(j.Name), true)
		end
	end
	local diaria = ServerStorage:FindFirstChild("DiariaEvento") -- missoes diarias: "complete uma missao"
	if diaria then diaria:Fire(player, "missao", 1) end
	if r.Escolha then
		-- libera a escolha entre 2 jutsus da natureza (o jogador escolhe no painel NATURES)
		local n = NatureData.Garantir(data)
		local e = r.Escolha
		if not NatureData.EhPendente(n, e.Natureza, e.Tier) and not NatureData.Escolhido(n, e.Natureza, e.Tier) then
			table.insert(n.Pendente, { Natureza = e.Natureza, Tier = e.Tier })
		end
		aviso(player, ("CHOOSE YOUR %s JUTSU!  Open NATURES"):format(NatureData.Tipos[e.Natureza].Name:upper()), true)
	end
	if r.NovaNatureza then
		local n = NatureData.Garantir(data)
		local nova = NatureData.Nova(data, Random.new())
		if nova then
			table.insert(n.Lista, nova)
			aviso(player, ("NEW CHAKRA NATURE: %s!  Its master has something to teach you."):format(NatureData.Tipos[nova].Name), true)
		end
	end
	if r.Jutsu or r.Escolha or r.NovaNatureza then
		local an = ServerStorage:FindFirstChild("AtualizarNatureza")
		if an then an:Fire(player) end
	end
	if missao.Id == "H6" then
		-- depois de provar os punhos, o Sensei manda o jogador para o mestre do clã
		local clan = ClanPowers.Sincronizar(data)
		local mestre = clan and ClanPowers.Mestres[clan]
		local info = mestre and MissionData.NPCs[mestre.Npc]
		if info then aviso(player, ("Your clan master is %s, %s. Go learn your first jutsu!"):format(info.Name, info.Onde or "in the village"), true) end
	end
	if r.PrimeiroJutsu or missao.Historia then
		local atualizar = ServerStorage:FindFirstChild("AtualizarPoderes")
		if atualizar then atualizar:Fire(player) end
	end
	if r.Poder and missao.Cla then
		local c = ClanPowers.Clans[missao.Cla]
		local poder = c and c.Powers[r.Poder]
		if poder then
			aviso(player, ("NEW POWER: %s  [%s]"):format(poder.Name, ClanPowers.TEXTO[r.Poder]), true)
		end
		local atualizar = ServerStorage:FindFirstChild("AtualizarPoderes")
		if atualizar then atualizar:Fire(player) end
	end
	if r.Estilo then
		local FightStyles = require(ReplicatedStorage:WaitForChild("FightStyles"))
		local e = FightStyles.Garantir(data)
		e.Liberados[r.Estilo] = true
		aviso(player, ("NEW STYLE: %s!  Equip it in POWERS > STYLES"):format(FightStyles.Get(r.Estilo).Name), true)
		local atualizar = ServerStorage:FindFirstChild("AtualizarEstilos")
		if atualizar then atualizar:Fire(player) end
	end
	if missao.Promove then
		data.Rank = missao.Promove
		aviso(player, "RANK UP!  You are now " .. MissionData.RankName(missao.Promove), true)
	end
	atualizarRank(player)
	evento:FireClient(player, { tipo = "concluida", nome = missao.Name, recompensa = r })
	enviarEstado(player)
end

-- conta progresso nas duas missões (principal e lateral) que forem desse tipo
local function progredir(player, tipo, qtd, alvo, soEspaco)
	local data, m = dados(player)
	if not data then return end
	if tipo == "treinar" then -- conta todos os treinos da Academia (requisito do estilo Lee)
		local e = require(ReplicatedStorage:WaitForChild("FightStyles")).Garantir(data)
		e.Treinos += qtd or 1
	end
	local mudou = false
	for _, esp in ipairs(ESPACOS) do
		local e = m[esp]
		local missao = e and MissionData.Get(e.Id)
		if missao and missao.Tipo == tipo and (not soEspaco or soEspaco == esp)
			and not (alvo ~= nil and missao.Alvo ~= nil and missao.Alvo ~= alvo) then
			e.P = math.min(missao.N, e.P + (qtd or 1))
			if e.P >= missao.N then
				concluir(player, esp)
			else
				mudou = true
			end
		end
	end
	if mudou then enviarEstado(player) end
end
progressoEv.Event:Connect(progredir)

---------------------------------------------------------------
-- Exame Ninja (usa a partida de ondas do WaveServer)
---------------------------------------------------------------
local function iniciarExame(player, missao)
	local ini = ServerStorage:FindFirstChild("IniciarPartida")
	if not ini then
		aviso(player, "The exam is not available right now.", false)
		return
	end
	aviso(player, "The Ninja Exam begins! Defeat Sensei Kaito in a duel.", true)
	ini:Fire(player, missao.Mapa)
end
task.spawn(function()
	local venc = ServerStorage:WaitForChild("PartidaVencida", 30)
	if venc then
		venc.Event:Connect(function(player, mapId)
			local data, m = dados(player)
			if not data then return end
			if acharAtiva(m, function(x) return x.Tipo == "exame" and x.Mapa == mapId end) then
				progredir(player, "exame", 1)
			end
		end)
	end
end)

---------------------------------------------------------------
-- Ações do cliente
---------------------------------------------------------------
local ultimoNpc = {} -- [player] = nome do NPC da última conversa (ou "Quadro")
local atendenteDe = {} -- [player] = nome do modelo da atendente quando a conversa foi no balcão (ela também entrega missões da história)
local conversaDe = {} -- [player] = { Id = missão "falar" cuja conversa está aberta, Npc = chave, Modelo = modelo }
local conversar
local BONUS_RESPOSTA = 25 -- XP por resposta boa numa conversa

action.OnServerInvoke = function(player, acao, id)
	local data, m = dados(player)
	if not data then return { ok = false, erro = "Loading..." } end
	if acao == "aceitar" then
		if id == "__exame" then
			local _, missao = acharAtiva(m, function(x) return x.Tipo == "exame" end)
			if missao then
				iniciarExame(player, missao)
				return { ok = true, estado = estado(player) }
			end
			return { ok = false, erro = "No exam active." }
		end
		local missao = MissionData.Get(id)
		if not missao then return { ok = false, erro = "Unknown mission." } end
		local de = ultimoNpc[player]
		if de ~= missao.Npc and not (de == "Quadro" and atendenteDe[player] == missao.Npc) then
			return { ok = false, erro = "Talk to the right person first." }
		end
		local esp = espacoDe(missao)
		if m[esp] then
			return { ok = false, erro = esp == "Ativa" and "Finish your main mission first." or "Finish or drop your side mission first." }
		end
		local ok, porque = disponivel(data, m, missao)
		if not ok then return { ok = false, erro = porque or "Not available now." } end
		m[esp] = { Id = missao.Id, P = 0 }
		enviarEstado(player)
		if missao.Tipo == "exame" then
			iniciarExame(player, missao)
		end
		return { ok = true, estado = estado(player) }
	elseif acao == "conversou" then
		-- terminou a conversa com opções: conclui a missão "falar" e dá o bônus das respostas boas
		local c = conversaDe[player]
		conversaDe[player] = nil
		local espConversa, missao = acharAtiva(m, function(x) return c ~= nil and x.Id == c.Id end)
		if not c or not missao or missao.Tipo ~= "falar" or not missao.Conversa then
			return { ok = false, erro = "No conversation." }
		end
		local boas = 0
		if type(id) == "table" then
			for i, passo in ipairs(missao.Conversa) do
				local op = passo.Opcoes and passo.Opcoes[tonumber(id[i]) or 0]
				if op and op.Bom then boas += 1 end
			end
		end
		if boas > 0 then
			PlayerData.AddXP(player, boas * BONUS_RESPOSTA)
			aviso(player, ("Good answers!  +%d XP"):format(boas * BONUS_RESPOSTA), true)
		end
		progredir(player, "falar", 1, nil, espConversa)
		-- o NPC já mostra o que tem a oferecer (o próximo passo do caminho)
		task.defer(conversar, player, c.Npc, c.Modelo)
		return { ok = true, estado = estado(player) }
	elseif acao == "desistir" then
		m.Lado = nil -- só a missão lateral pode ser abandonada
		enviarEstado(player)
		return { ok = true, estado = estado(player) }
	end
	return { ok = true, estado = estado(player) }
end

---------------------------------------------------------------
-- Conversa com NPCs e quadro de missões
---------------------------------------------------------------
local function ofertasDe(player, npcKey)
	local data, m = dados(player)
	local lista = {}
	if npcKey == "Quadro" then encherQuadro(data, m) end
	for _, missao in ipairs(MissionData.Missoes) do
		if missao.Npc == npcKey and (npcKey ~= "Quadro" or table.find(m.Q.Of, missao.Id)) then
			local ok, porque = disponivel(data, m, missao)
			local bloqueio = nil
			if not ok then
				if porque then
					bloqueio = porque
				elseif not missao.Historia and m.Cool[missao.Id] and os.time() < m.Cool[missao.Id] then
					bloqueio = ("Available again in %d min"):format(math.ceil((m.Cool[missao.Id] - os.time()) / 60))
				end
			end
			if ok or bloqueio then
				local giver = MissionData.NPCs[missao.Npc]
				table.insert(lista, {
					Id = missao.Id, Name = missao.Name, Rank = missao.Rank, Desc = missao.Desc,
					Recompensa = missao.Recompensa, Bloqueio = bloqueio,
					Conversa = (ok and missao.Tipo ~= "falar") and missao.Conversa or nil,
					De = giver and giver.Name or nil,
				})
			end
		end
	end
	return lista
end

conversar = function(player, npcKey, modelo)
	local data, m = dados(player)
	if not data then return end
	ultimoNpc[player] = npcKey
	atendenteDe[player] = (npcKey == "Quadro" and modelo) and modelo.Name or nil
	conversaDe[player] = nil
	-- missão "falar com" este NPC (principal ou lateral)
	local espFalar, missaoFalar = acharAtiva(m, function(x)
		return x.Tipo == "falar" and (x.Alvo == npcKey or (modelo ~= nil and x.Alvo == modelo.Name))
	end)
	if missaoFalar then
		local missao = missaoFalar
		do
			if missao.Conversa then
				-- conversa com opções: a missão só conclui quando o jogador terminar de conversar
				local quem = MissionData.NPCs[missao.Alvo] or MissionData.NPCs.StarterCharacter
				conversaDe[player] = { Id = missao.Id, Npc = npcKey, Modelo = modelo }
				evento:FireClient(player, { tipo = "dialogo", npc = npcKey, nome = quem.Name, titulo = quem.Titulo,
					fala = "", ofertas = {}, conversa = missao.Conversa, modelo = modelo })
				return
			end
			progredir(player, "falar", 1, nil, espFalar)
		end
	end
	local info = MissionData.NPCs[npcKey] or MissionData.NPCs.StarterCharacter
	local atendente = npcKey == "Quadro" and modelo and MissionData.NPCs[modelo.Name]
	local ofertas = ofertasDe(player, npcKey)
	-- a atendente do balcão (Yumi) também entrega as missões da história que são dela: vêm antes das do quadro
	if npcKey == "Quadro" and modelo and modelo.Name ~= "Quadro" then
		local dela = ofertasDe(player, modelo.Name)
		for i = #dela, 1, -1 do table.insert(ofertas, 1, dela[i]) end
	end
	local fala = info.Fala
	-- o Sensei relança o Exame se ele estiver ativo
	if m.Ativa then
		local missao = MissionData.Get(m.Ativa.Id)
		if missao.Tipo == "exame" and missao.Npc == npcKey then
			table.insert(ofertas, 1, { Id = "__exame", Name = "Start the Ninja Exam", Rank = missao.Rank, Desc = "A duel against me. Defeat me to become a Genin.", Recompensa = missao.Recompensa })
			fala = "The exam is simple: fight me. Show me everything you learned."
		end
	end
	evento:FireClient(player, {
		tipo = "dialogo", npc = npcKey, nome = npcKey == "Quadro" and (atendente and atendente.Name or "Mission Board") or info.Name,
		titulo = npcKey == "Quadro" and ("Rank missions  ·  %d done"):format(m.Q.N) or info.Titulo,
		fala = npcKey == "Quadro" and "These are the missions of your rank. New ones come in when you finish one." or fala,
		ofertas = ofertas, temAtiva = m.Ativa ~= nil, modelo = modelo,
	})
end

local function prepararNpc(modelo)
	local root = modelo:FindFirstChild("HumanoidRootPart") or modelo.PrimaryPart
	if not root or root:FindFirstChild("ConversaPrompt") then return end
	local info = MissionData.NPCs[modelo.Name] or MissionData.NPCs.StarterCharacter
	local p = Instance.new("ProximityPrompt")
	p.Name = "ConversaPrompt"
	p.ActionText = info.Quadro and "Missions" or info.Rezar and "Pray" or "Talk"
	p.ObjectText = info.Name
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.MaxActivationDistance = info.Alcance or 10
	p.RequiresLineOfSight = false
	p.Parent = root
	p.Triggered:Connect(function(player)
		-- atendente do balcão QUESTS abre o quadro com todas as missões
		conversar(player, info.Quadro and "Quadro" or modelo.Name, modelo)
	end)
	-- nome e função em cima da cabeça (todos os jogadores veem)
	local head = modelo:FindFirstChild("Head") or root
	if not head:FindFirstChild("NomeNPC") then
		local b = Instance.new("BillboardGui")
		b.Name = "NomeNPC"
		b.Size = UDim2.fromOffset(170, 40)
		b.StudsOffset = Vector3.new(0, 2.3, 0)
		b.MaxDistance = 80
		b.LightInfluence = 0
		b.Parent = head
		local n = Instance.new("TextLabel")
		n.Size = UDim2.new(1, 0, 0, 22)
		n.BackgroundTransparency = 1
		n.Text = info.Name
		n.TextSize = 16
		n.Font = Enum.Font.GothamBlack
		n.TextColor3 = Color3.new(1, 1, 1)
		n.TextStrokeTransparency = 0.3
		n.Parent = b
		local t = Instance.new("TextLabel")
		t.Position = UDim2.fromOffset(0, 22)
		t.Size = UDim2.new(1, 0, 0, 14)
		t.BackgroundTransparency = 1
		t.Text = info.Titulo
		t.TextSize = 12
		t.Font = Enum.Font.GothamBold
		t.TextColor3 = Color3.fromRGB(255, 205, 120)
		t.TextStrokeTransparency = 0.4
		t.Parent = b
	end
	local hum = modelo:FindFirstChildOfClass("Humanoid")
	if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
end
for _, mdl in ipairs(CollectionService:GetTagged("NPC")) do prepararNpc(mdl) end
CollectionService:GetInstanceAddedSignal("NPC"):Connect(prepararNpc)
for _, mdl in ipairs(CollectionService:GetTagged("NPCParado")) do prepararNpc(mdl) end
CollectionService:GetInstanceAddedSignal("NPCParado"):Connect(prepararNpc) -- mestres criados pelo script MundoExtras

-- quadro de missões no balcão QUESTS da praça
task.spawn(function()
	local centro = workspace:WaitForChild("Vila_Shinobi", 20)
	centro = centro and centro:WaitForChild("Centro", 20)
	local balcao = centro and centro:WaitForChild("BalcaoNPC_Quests", 20)
	local peca = balcao and balcao:FindFirstChildWhichIsA("BasePart", true)
	if not peca then return end
	-- se a atendente (Hinata) estiver no balcão, o quadro abre por ela
	for _, mdl in ipairs(CollectionService:GetTagged("NPCParado")) do
		local info = MissionData.NPCs[mdl.Name]
		if info and info.Quadro then return end
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = "QuadroPrompt"
	p.ActionText = "Missions"
	p.ObjectText = "Mission Board"
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = peca
	p.Triggered:Connect(function(player)
		conversar(player, "Quadro")
	end)
end)

---------------------------------------------------------------
-- Missões "ir": confere a distância do jogador ao lugar
---------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(0.5)
		for _, player in ipairs(Players:GetPlayers()) do
			local data, m = dados(player)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if data and root and not root.Anchored then
				for _, esp in ipairs(ESPACOS) do
					local missao = m[esp] and MissionData.Get(m[esp].Id)
					local lugar = missao and missao.Tipo == "ir" and MissionData.Lugares[missao.Alvo]
					if lugar then
						local d = (root.Position - lugar.Pos) * Vector3.new(1, 0, 1)
						if d.Magnitude <= lugar.Raio then
							progredir(player, "ir", 1, missao.Alvo, esp)
						end
					end
				end
			end
		end
	end
end)

---------------------------------------------------------------
-- Acampamento de bandidos (missões "derrotar")
---------------------------------------------------------------
local CAMP = MissionData.Lugares.Acampamento
local ESCONDERIJOS = MissionData.Esconderijos
local pastaCamp = Instance.new("Folder")
pastaCamp.Name = "EsconderijosBandidos"
pastaCamp.Parent = workspace
local POR_ESCONDERIJO = 3
local rng = Random.new()

local function montarEsconderijo(e)
	local pasta = Instance.new("Model")
	pasta.Name = "Esconderijo_" .. e.Tipo
	pasta.Parent = pastaCamp
	local base = CFrame.new(e.Pos.X, 0, e.Pos.Z) * CFrame.Angles(0, math.rad(e.Giro or 0), 0)
	local function p(nome, size, cf, cor, mat, forma)
		local x = Instance.new("Part")
		x.Name = nome
		x.Anchored = true
		x.Size = size
		x.CFrame = base * cf
		x.Color = cor
		x.Material = mat
		if forma then x.Shape = forma end
		x.TopSurface, x.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		x.Parent = pasta
		return x
	end
	local pedra = Color3.fromRGB(95, 90, 85)
	local madeira = Color3.fromRGB(95, 65, 40)
	if e.Tipo == "Caverna" then
		-- morro de pedra com uma boca de caverna virada para +Z
		p("Rocha", Vector3.new(34, 18, 26), CFrame.new(0, 9, -10), pedra, Enum.Material.Slate)
		p("Rocha", Vector3.new(12, 22, 14), CFrame.new(-14, 11, 6) * CFrame.Angles(0, math.rad(15), math.rad(6)), pedra, Enum.Material.Slate)
		p("Rocha", Vector3.new(12, 22, 14), CFrame.new(14, 11, 6) * CFrame.Angles(0, math.rad(-15), math.rad(-6)), pedra, Enum.Material.Slate)
		p("Teto", Vector3.new(30, 6, 18), CFrame.new(0, 20, 4), pedra, Enum.Material.Slate)
		p("Musgo", Vector3.new(32, 1, 20), CFrame.new(0, 23.5, 2), Color3.fromRGB(70, 110, 55), Enum.Material.Grass)
		p("Escuro", Vector3.new(14, 14, 1), CFrame.new(0, 7, -2.5), Color3.fromRGB(15, 12, 10), Enum.Material.SmoothPlastic)
	elseif e.Tipo == "Cabana" then
		-- cabana de madeira escondida com rede de camuflagem
		p("Chao", Vector3.new(22, 1, 18), CFrame.new(0, 0.5, 0), madeira, Enum.Material.WoodPlanks)
		p("Parede", Vector3.new(22, 10, 1), CFrame.new(0, 6, -8.5), madeira, Enum.Material.WoodPlanks)
		p("Parede", Vector3.new(1, 10, 18), CFrame.new(-10.5, 6, 0), madeira, Enum.Material.WoodPlanks)
		p("Parede", Vector3.new(1, 10, 18), CFrame.new(10.5, 6, 0), madeira, Enum.Material.WoodPlanks)
		p("Telhado", Vector3.new(26, 1, 22), CFrame.new(0, 11.5, 0) * CFrame.Angles(math.rad(8), 0, 0), Color3.fromRGB(60, 45, 30), Enum.Material.Wood)
		local rede = p("Camuflagem", Vector3.new(30, 0.4, 28), CFrame.new(0, 12.6, 0) * CFrame.Angles(math.rad(8), 0, 0), Color3.fromRGB(55, 85, 45), Enum.Material.Grass)
		rede.CanCollide = false
		for _, x in ipairs({ -8, 8 }) do
			p("Caixote", Vector3.new(3, 3, 3), CFrame.new(x, 2.5, -5), Color3.fromRGB(130, 95, 55), Enum.Material.WoodPlanks)
		end
	else
		-- galpão em ruínas: paredes quebradas de pedra e tábuas
		p("Base", Vector3.new(26, 1, 22), CFrame.new(0, 0.5, 0), pedra, Enum.Material.Cobblestone)
		p("Parede", Vector3.new(26, 12, 1.5), CFrame.new(0, 6, -10), pedra, Enum.Material.Brick)
		p("Parede", Vector3.new(1.5, 8, 14), CFrame.new(-12, 4, -3), pedra, Enum.Material.Brick)
		p("Parede", Vector3.new(1.5, 5, 10), CFrame.new(12, 2.5, -5), pedra, Enum.Material.Brick)
		p("Viga", Vector3.new(1, 1, 24), CFrame.new(-5, 12, 0) * CFrame.Angles(math.rad(-12), 0, 0), madeira, Enum.Material.Wood)
		p("Viga", Vector3.new(1, 1, 24), CFrame.new(5, 11, 0) * CFrame.Angles(math.rad(-20), 0, math.rad(10)), madeira, Enum.Material.Wood)
		p("Tabuas", Vector3.new(12, 0.6, 10), CFrame.new(-4, 11, -5) * CFrame.Angles(math.rad(10), 0, math.rad(-6)), madeira, Enum.Material.WoodPlanks)
	end
	-- fogueira na frente
	p("Fogueira", Vector3.new(0.6, 4, 4), CFrame.new(0, 0.3, 14) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(70, 60, 55), Enum.Material.Slate, Enum.PartType.Cylinder)
	local fogo = p("Fogo", Vector3.new(1.4, 2, 1.4), CFrame.new(0, 1.3, 14), Color3.fromRGB(255, 140, 40), Enum.Material.Neon)
	fogo.CanCollide = false
	local luz = Instance.new("PointLight")
	luz.Color = Color3.fromRGB(255, 150, 70)
	luz.Range = 20
	luz.Brightness = 1.4
	luz.Parent = fogo
	-- placa
	local placa = p("Placa", Vector3.new(7, 2.5, 0.4), CFrame.new(9, 4, 20), Color3.fromRGB(110, 80, 55), Enum.Material.WoodPlanks)
	p("Poste", Vector3.new(0.5, 4, 0.5), CFrame.new(9, 2, 20.3), madeira, Enum.Material.Wood)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.Parent = placa
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = e.Name
		t.TextScaled = true
		t.Font = Enum.Font.GothamBlack
		t.TextColor3 = Color3.fromRGB(240, 220, 190)
		t.Parent = sg
	end
	-- ponto de onde os bandidos saem (na frente da entrada)
	e.Saida = (base * CFrame.new(0, 3.5, 9)).Position
end

local function montarAcampamento()
	for _, e in ipairs(ESCONDERIJOS) do
		montarEsconderijo(e)
	end
end

-- Nukenin (ninja renegado): usa a aparência guardada em ServerStorage.Aparencias.Nukenin (capuz azul, máscara,
-- chifres vermelhos e espada). Se ela não existir, monta um boneco simples.
local modeloBase
local function bandidoBase()
	if modeloBase then return modeloBase end
	local ap = ServerStorage:FindFirstChild("Aparencias")
	local skin = ap and ap:FindFirstChild("Nukenin")
	if skin and skin:FindFirstChildOfClass("Humanoid") and skin:FindFirstChild("HumanoidRootPart") then
		local m = skin:Clone()
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanTouch = false
				if d.Name ~= "HumanoidRootPart" and d.Name ~= "Torso" and d.Name ~= "Head" and not d.Name:find("Leg") then d.CanCollide = false end
			elseif d:IsA("LuaSourceContainer") then
				d:Destroy()
			end
		end
		modeloBase = m
		return m
	end
	local ok, m = pcall(function()
		local d = Instance.new("HumanoidDescription")
		d.HeadColor = Color3.fromRGB(215, 170, 130)
		d.TorsoColor = Color3.fromRGB(35, 45, 80)
		d.LeftArmColor, d.RightArmColor = d.TorsoColor, d.TorsoColor
		d.LeftLegColor, d.RightLegColor = Color3.fromRGB(25, 28, 45), Color3.fromRGB(25, 28, 45)
		return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end)
	if ok and m then
		modeloBase = m
	else
		warn("[MissionServer] Não deu para criar o nukenin: " .. tostring(m))
	end
	return modeloBase
end

-- tipos de nukenin: o comum, o batedor (rápido e fraco) e o bruto (grande, lento e forte)
local TIPOS_NUKENIN = {
	{ Nome = "Rogue Ninja", Peso = 60, Vida = 70, Vel = 12, Dano = 6, Escala = 1, XP = 18 },
	{ Nome = "Rogue Scout", Peso = 25, Vida = 50, Vel = 16, Dano = 5, Escala = 0.9, XP = 10 },
	{ Nome = "Rogue Brute", Peso = 15, Vida = 130, Vel = 10, Dano = 10, Escala = 1.25, XP = 36 },
}
local function tipoNukenin()
	local r = rng:NextNumber(0, 100)
	for _, t in ipairs(TIPOS_NUKENIN) do
		if r < t.Peso then return t end
		r -= t.Peso
	end
	return TIPOS_NUKENIN[1]
end

-- quem está perto ganha o progresso da missão e o XP do tipo de bandido (o bruto vale mais que o batedor)
local function creditar(posicao, nome, xp)
	local fb = ReplicatedStorage:FindFirstChild("AbilityFeedback")
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - posicao).Magnitude < 70 then
			progredir(player, "derrotar", 1, "Acampamento")
			PlayerData.AddXP(player, xp * PlayerData.GetBoostMult(player, "XP"))
			if fb then fb:FireClient(player, { msg = ("%s defeated  +%d XP"):format(nome, xp) }) end
		end
	end
end

local function novoBandido(e)
	local base = bandidoBase()
	if not base then return end
	local tipo = tipoNukenin()
	local m = base:Clone()
	m.Name = "Bandit"
	local hum = m:FindFirstChildOfClass("Humanoid")
	local root = m:FindFirstChild("HumanoidRootPart")
	hum.MaxHealth = tipo.Vida
	hum.Health = tipo.Vida
	hum.WalkSpeed = tipo.Vel
	hum.DisplayName = tipo.Nome
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	hum.NameDisplayDistance = 60
	hum.HealthDisplayDistance = 50
	m:SetAttribute("Raio", 0)
	m:SetAttribute("Esconderijo", e.Name)
	local casa = e.Saida or e.Pos
	local ang = rng:NextNumber(0, math.pi * 2)
	local pos = casa + Vector3.new(math.cos(ang), 0, math.sin(ang)) * rng:NextNumber(1, 6)
	m.Parent = pastaCamp
	-- escala depois de estar no mundo (antes disso as peças soltas da roupa crescem duas vezes)
	if tipo.Escala ~= 1 then pcall(function() m:ScaleTo(tipo.Escala) end) end
	m:PivotTo(CFrame.new(pos.X, 3.5 * tipo.Escala, pos.Z))
	pcall(function() root:SetNetworkOwner(nil) end)
	CollectionService:AddTag(m, "Inimigo")
	local morto = false
	hum.Died:Connect(function()
		if morto then return end
		morto = true
		CollectionService:RemoveTag(m, "Inimigo")
		creditar(root.Position, tipo.Nome, tipo.XP)
		task.delay(2, function() m:Destroy() end)
	end)
	-- IA simples: persegue quem chega perto e bate
	task.spawn(function()
		local golpe = InimigoGolpe.Novo()
		while m.Parent and hum.Health > 0 do
			local alvo, dist = nil, 45
			for _, player in ipairs(Players:GetPlayers()) do
				local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if r and h and h.Health > 0 and not r.Anchored then
					local d = (r.Position - root.Position).Magnitude
					if d < dist then alvo, dist = h, d end
				end
			end
			if (m:GetAttribute("Atordoado") or 0) > os.clock() then
				-- levou um golpe: fica travado e não revida enquanto o combo conecta
				hum:MoveTo(root.Position)
				InimigoGolpe.Interromper(golpe)
			elseif alvo then
				local r = alvo.Parent.HumanoidRootPart
				hum:MoveTo(r.Position)
				if dist < 5 * tipo.Escala then
					-- combo de 3 golpes com os efeitos de soco do jogador, depois uma pausa
					InimigoGolpe.Tentar(golpe, m, root, alvo, tipo.Dano, { Escala = tipo.Escala })
				end
			elseif (root.Position - casa).Magnitude > 16 then
				hum:MoveTo(casa)
			end
			task.wait(0.3)
		end
	end)
end

task.spawn(function()
	montarAcampamento()
	while true do
		local faltou = false
		for _, e in ipairs(ESCONDERIJOS) do
			local vivos = 0
			for _, c in ipairs(pastaCamp:GetChildren()) do
				if c.Name == "Bandit" and c:GetAttribute("Esconderijo") == e.Name then
					local h = c:FindFirstChildOfClass("Humanoid")
					if h and h.Health > 0 then vivos += 1 end
				end
			end
			if vivos < POR_ESCONDERIJO then
				novoBandido(e)
				faltou = true
			end
		end
		task.wait(faltou and 4 or 2)
	end
end)

---------------------------------------------------------------
-- Ervas na floresta (missões "coletar")
---------------------------------------------------------------
local FLORESTA = MissionData.Lugares.Floresta
local pastaErvas = Instance.new("Folder")
pastaErvas.Name = "ErvasFloresta"
pastaErvas.Parent = workspace
local paramsChao = RaycastParams.new()
paramsChao.FilterType = Enum.RaycastFilterType.Exclude
paramsChao.FilterDescendantsInstances = { pastaErvas }

local function novaErva()
	for _ = 1, 15 do
		local ang = rng:NextNumber(0, math.pi * 2)
		local pos = FLORESTA.Pos + Vector3.new(math.cos(ang), 0, math.sin(ang)) * rng:NextNumber(10, FLORESTA.Raio)
		local hit = workspace:Raycast(pos + Vector3.new(0, 40, 0), Vector3.new(0, -60, 0), paramsChao)
		if hit and hit.Position.Y < 3 and hit.Normal.Y > 0.8 then
			local e = Instance.new("Part")
			e.Name = "Erva"
			e.Shape = Enum.PartType.Ball
			e.Size = Vector3.new(1.4, 1.4, 1.4)
			e.Anchored = true
			e.CanCollide = false
			e.Material = Enum.Material.Neon
			e.Color = Color3.fromRGB(120, 255, 150)
			e.Position = hit.Position + Vector3.new(0, 0.8, 0)
			local l = Instance.new("PointLight")
			l.Color = e.Color
			l.Range = 8
			l.Brightness = 1
			l.Parent = e
			local p = Instance.new("ProximityPrompt")
			p.ActionText = "Collect"
			p.ObjectText = "Medicinal Herb"
			p.HoldDuration = 0.6
			p.MaxActivationDistance = 8
			p.RequiresLineOfSight = false
			p.Parent = e
			p.Triggered:Connect(function(player)
				local data, m = dados(player)
				local _, missao = nil, nil
				if data then _, missao = acharAtiva(m, function(x) return x.Tipo == "coletar" end) end
				if not missao then
					aviso(player, "Someone needs these herbs. Take a herb mission first (QUESTS board).", false)
					return
				end
				if not e.Parent then return end
				e:Destroy()
				progredir(player, "coletar", 1, "Floresta")
				task.delay(20, novaErva)
			end)
			e.Parent = pastaErvas
			return
		end
	end
end
task.spawn(function()
	for _ = 1, 14 do
		novaErva()
	end
end)

---------------------------------------------------------------
-- Gancho de teste (só existe dentro do Studio; no jogo publicado não é criado)
-- ServerStorage.MissaoTeste:Invoke(player, "falar", npc) | "estado" | "nivel", n
---------------------------------------------------------------
if game:GetService("RunService"):IsStudio() then
	local teste = Instance.new("BindableFunction")
	teste.Name = "MissaoTeste"
	teste.OnInvoke = function(player, acao, valor)
		local data, m = dados(player)
		if not data then return "sem dados" end
		if acao == "falar" then
			conversar(player, valor)
		elseif acao == "nivel" then
			data.Level = valor
			PlayerData.Refresh(player)
		elseif acao == "cla" then
			data.Cla.Id = valor
			player:SetAttribute("Cla", valor)
		elseif acao == "rank" then
			data.Rank = valor
			player:SetAttribute("Rank", valor)
		elseif acao == "feita" then
			m.Feitas[valor] = true
		elseif acao == "historia" then
			m.Historia = valor
		elseif acao == "jutsu" then
			-- dá o jutsu de natureza (e a natureza dele) e equipa na tecla G
			local j = NatureData.Jutsu(valor)
			local n = NatureData.Garantir(data)
			if j then
				if not table.find(n.Lista, j.Natureza) then table.insert(n.Lista, j.Natureza) end
				n.Rolou = true
				n.Jutsus[j.Id] = true
				n.Equip[1] = j.Id
				local an = ServerStorage:FindFirstChild("AtualizarNatureza")
				if an then an:Fire(player) end
			end
		elseif acao == "estilo" then
			local e = require(ReplicatedStorage:WaitForChild("FightStyles")).Garantir(data)
			e.Liberados[valor] = true
			e.Equipado = valor
			local ae = ServerStorage:FindFirstChild("AtualizarEstilos")
			if ae then ae:Fire(player) end
		end
		local atualizar = ServerStorage:FindFirstChild("AtualizarPoderes")
		if atualizar then atualizar:Fire(player) end
		return {
			Historia = m.Historia, Ativa = m.Ativa and (m.Ativa.Id .. " " .. m.Ativa.P) or "-",
			Lado = m.Lado and (m.Lado.Id .. " " .. m.Lado.P) or "-",
			Rank = data.Rank, Level = data.Level, XP = data.XP, Coins = data.Coins,
			Pontos = data.Atributos and data.Atributos.Pontos,
		}
	end
	teste.Parent = ServerStorage
end

---------------------------------------------------------------
-- Jogadores
---------------------------------------------------------------
local function setup(player)
	task.spawn(function()
		for _ = 1, 60 do
			if PlayerData.Get(player) then break end
			task.wait(0.2)
		end
		atualizarRank(player)
		enviarEstado(player)
		placaRank(player)
		player.CharacterAdded:Connect(function(char)
			char:WaitForChild("Head", 10)
			placaRank(player)
		end)
		player:GetAttributeChangedSignal("Rank"):Connect(function() placaRank(player) end)
		local ls = player:WaitForChild("leaderstats", 10)
		local lv = ls and ls:WaitForChild("Level", 10)
		if lv then
			lv.Changed:Connect(function()
				atualizarRank(player)
				enviarEstado(player) -- novas missões podem liberar com o nível
			end)
		end
	end)
end
Players.PlayerAdded:Connect(setup)
for _, p in ipairs(Players:GetPlayers()) do setup(p) end
Players.PlayerRemoving:Connect(function(player)
	ultimoNpc[player] = nil
	atendenteDe[player] = nil
	conversaDe[player] = nil
end)

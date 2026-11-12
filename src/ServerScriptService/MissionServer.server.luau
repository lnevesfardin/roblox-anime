-- Script: ServerScriptService > MissionServer
-- Fase 3: missões, NPCs que conversam, ranks ninja e o Exame Ninja.
-- MissionAction (RemoteFunction): "estado" | "aceitar", idDaMissao | "desistir"
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
local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))

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
	if type(m.Cool) ~= "table" then m.Cool = {} end
	if type(m.Feitas) ~= "table" then m.Feitas = {} end -- missões únicas já feitas
	ClanPowers.Sincronizar(data) -- trocou de clã: missões do clã antigo somem
	if type(m.Ativa) ~= "table" or not MissionData.Get(m.Ativa.Id) then m.Ativa = nil end
	if type(data.Rank) ~= "string" then data.Rank = "Estudante" end
	return data, m
end

local function disponivel(data, m, missao)
	if m.Ativa and m.Ativa.Id == missao.Id then return false end
	if missao.Cla and not (data.Cla and data.Cla.Id == missao.Cla) then return false end
	if missao.Unica and m.Feitas[missao.Id] then return false end
	if missao.Requer and not m.Feitas[missao.Requer] then return false end
	if missao.Nivel and data.Level < missao.Nivel then return false, "Requires level " .. missao.Nivel end
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
		if disponivel(data, m, missao) then
			disp[missao.Npc] = true
		end
	end
	local ativa
	if m.Ativa then
		local missao = MissionData.Get(m.Ativa.Id)
		ativa = { Id = missao.Id, P = m.Ativa.P, N = missao.N }
	end
	return { Ativa = ativa, Rank = data.Rank, NpcsComMissao = disp, Historia = m.Historia }
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

---------------------------------------------------------------
-- Concluir e progredir
---------------------------------------------------------------
local function concluir(player)
	local data, m = dados(player)
	if not data or not m.Ativa then return end
	local missao = MissionData.Get(m.Ativa.Id)
	m.Ativa = nil
	if missao.Historia then
		m.Historia = math.max(m.Historia, missao.Historia)
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
	if r.Poder and missao.Cla then
		local c = ClanPowers.Clans[missao.Cla]
		local poder = c and c.Powers[r.Poder]
		if poder then
			aviso(player, ("NEW POWER: %s  [%s]"):format(poder.Name, ClanPowers.KEYS[r.Poder]), true)
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

local function progredir(player, tipo, qtd, alvo)
	local data, m = dados(player)
	if not data or not m.Ativa then return end
	local missao = MissionData.Get(m.Ativa.Id)
	if missao.Tipo ~= tipo then return end
	if alvo ~= nil and missao.Alvo ~= nil and missao.Alvo ~= alvo then return end
	m.Ativa.P = math.min(missao.N, m.Ativa.P + (qtd or 1))
	if m.Ativa.P >= missao.N then
		concluir(player)
	else
		enviarEstado(player)
	end
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
	aviso(player, "The Ninja Exam begins! Survive the waves and defeat the boss.", true)
	ini:Fire(player, missao.Mapa)
end
task.spawn(function()
	local venc = ServerStorage:WaitForChild("PartidaVencida", 30)
	if venc then
		venc.Event:Connect(function(player, mapId)
			local data, m = dados(player)
			if not data or not m.Ativa then return end
			local missao = MissionData.Get(m.Ativa.Id)
			if missao.Tipo == "exame" and missao.Mapa == mapId then
				progredir(player, "exame", 1)
			end
		end)
	end
end)

---------------------------------------------------------------
-- Ações do cliente
---------------------------------------------------------------
local ultimoNpc = {} -- [player] = nome do NPC da última conversa (ou "Quadro")

action.OnServerInvoke = function(player, acao, id)
	local data, m = dados(player)
	if not data then return { ok = false, erro = "Loading..." } end
	if acao == "aceitar" then
		if id == "__exame" then
			local missao = m.Ativa and MissionData.Get(m.Ativa.Id)
			if missao and missao.Tipo == "exame" then
				iniciarExame(player, missao)
				return { ok = true, estado = estado(player) }
			end
			return { ok = false, erro = "No exam active." }
		end
		local missao = MissionData.Get(id)
		if not missao then return { ok = false, erro = "Unknown mission." } end
		local de = ultimoNpc[player]
		if de ~= "Quadro" and de ~= missao.Npc then
			return { ok = false, erro = "Talk to the right person first." }
		end
		if m.Ativa then return { ok = false, erro = "Finish or drop your current mission first." } end
		local ok, porque = disponivel(data, m, missao)
		if not ok then return { ok = false, erro = porque or "Not available now." } end
		m.Ativa = { Id = missao.Id, P = 0 }
		enviarEstado(player)
		if missao.Tipo == "exame" then
			iniciarExame(player, missao)
		end
		return { ok = true, estado = estado(player) }
	elseif acao == "desistir" then
		m.Ativa = nil
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
	for _, missao in ipairs(MissionData.Missoes) do
		if npcKey == "Quadro" or missao.Npc == npcKey then
			local ok, porque = disponivel(data, m, missao)
			local bloqueio = nil
			if not ok then
				if porque then
					bloqueio = porque
				elseif not missao.Historia and m.Cool[missao.Id] and os.time() < m.Cool[missao.Id] then
					bloqueio = ("Available again in %d min"):format(math.ceil((m.Cool[missao.Id] - os.time()) / 60))
				end
			end
			if ok or (bloqueio and npcKey ~= "Quadro") then
				local giver = MissionData.NPCs[missao.Npc]
				table.insert(lista, {
					Id = missao.Id, Name = missao.Name, Rank = missao.Rank, Desc = missao.Desc,
					Recompensa = missao.Recompensa, Bloqueio = bloqueio,
					De = giver and giver.Name or "?",
				})
			end
		end
	end
	return lista
end

local function conversar(player, npcKey, modelo)
	local data, m = dados(player)
	if not data then return end
	ultimoNpc[player] = npcKey
	-- missão "falar com" este NPC
	if m.Ativa then
		local missao = MissionData.Get(m.Ativa.Id)
		if missao.Tipo == "falar" and missao.Alvo == npcKey then
			progredir(player, "falar", 1)
		end
	end
	local info = MissionData.NPCs[npcKey] or MissionData.NPCs.StarterCharacter
	local ofertas = ofertasDe(player, npcKey)
	local fala = info.Fala
	-- o Sensei relança o Exame se ele estiver ativo
	if m.Ativa then
		local missao = MissionData.Get(m.Ativa.Id)
		if missao.Tipo == "exame" and missao.Npc == npcKey then
			table.insert(ofertas, 1, { Id = "__exame", Name = "Start the Ninja Exam", Rank = missao.Rank, Desc = "Survive the waves and defeat the boss.", Recompensa = missao.Recompensa })
			fala = "Are you ready? The exam will test everything you learned."
		end
	end
	evento:FireClient(player, {
		tipo = "dialogo", npc = npcKey, nome = npcKey == "Quadro" and "Mission Board" or info.Name,
		titulo = npcKey == "Quadro" and "All available missions" or info.Titulo,
		fala = npcKey == "Quadro" and "Pick a mission. You can only do one at a time." or fala,
		ofertas = ofertas, temAtiva = m.Ativa ~= nil,
	})
end

local function prepararNpc(modelo)
	local root = modelo:FindFirstChild("HumanoidRootPart") or modelo.PrimaryPart
	if not root or root:FindFirstChild("ConversaPrompt") then return end
	local info = MissionData.NPCs[modelo.Name] or MissionData.NPCs.StarterCharacter
	local p = Instance.new("ProximityPrompt")
	p.Name = "ConversaPrompt"
	p.ActionText = "Talk"
	p.ObjectText = info.Name
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.Parent = root
	p.Triggered:Connect(function(player)
		conversar(player, modelo.Name, modelo)
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

-- quadro de missões no balcão QUESTS da praça
task.spawn(function()
	local centro = workspace:WaitForChild("Vila_Shinobi", 20)
	centro = centro and centro:WaitForChild("Centro", 20)
	local balcao = centro and centro:WaitForChild("BalcaoNPC_Quests", 20)
	local peca = balcao and balcao:FindFirstChildWhichIsA("BasePart", true)
	if not peca then return end
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
			if data and m.Ativa then
				local missao = MissionData.Get(m.Ativa.Id)
				local lugar = missao.Tipo == "ir" and MissionData.Lugares[missao.Alvo]
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if lugar and root and not root.Anchored then
					local d = (root.Position - lugar.Pos) * Vector3.new(1, 0, 1)
					if d.Magnitude <= lugar.Raio then
						progredir(player, "ir", 1)
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

local modeloBase
local function bandidoBase()
	if modeloBase then return modeloBase end
	local ok, m = pcall(function()
		local d = Instance.new("HumanoidDescription")
		d.HeadColor = Color3.fromRGB(215, 170, 130)
		d.TorsoColor = Color3.fromRGB(70, 60, 55)
		d.LeftArmColor, d.RightArmColor = d.HeadColor, d.HeadColor
		d.LeftLegColor, d.RightLegColor = Color3.fromRGB(45, 40, 38), Color3.fromRGB(45, 40, 38)
		return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end)
	if ok and m then
		modeloBase = m
		-- lenço vermelho no rosto
		local head = m:FindFirstChild("Head")
		if head then
			local l = Instance.new("Part")
			l.Name = "Lenco"
			l.Size = Vector3.new(head.Size.X * 1.05, head.Size.Y * 0.35, head.Size.Z * 1.05)
			l.CFrame = head.CFrame * CFrame.new(0, -head.Size.Y * 0.2, 0)
			l.Color = Color3.fromRGB(170, 40, 40)
			l.Material = Enum.Material.Fabric
			l.CanCollide, l.Massless = false, true
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = head, l
			w.Parent = l
			l.Parent = m
		end
	else
		warn("[MissionServer] Não deu para criar o bandido: " .. tostring(m))
	end
	return modeloBase
end

local function creditar(posicao)
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - posicao).Magnitude < 70 then
			progredir(player, "derrotar", 1, "Acampamento")
			PlayerData.AddXP(player, 15)
		end
	end
end

local function novoBandido(e)
	local base = bandidoBase()
	if not base then return end
	local m = base:Clone()
	m.Name = "Bandit"
	local hum = m:FindFirstChildOfClass("Humanoid")
	local root = m:FindFirstChild("HumanoidRootPart")
	hum.MaxHealth = 70
	hum.Health = 70
	hum.WalkSpeed = 12
	hum.DisplayName = "Bandit"
	m:SetAttribute("Raio", 0)
	m:SetAttribute("Esconderijo", e.Name)
	local casa = e.Saida or e.Pos
	local ang = rng:NextNumber(0, math.pi * 2)
	local pos = casa + Vector3.new(math.cos(ang), 0, math.sin(ang)) * rng:NextNumber(1, 6)
	m:PivotTo(CFrame.new(pos.X, 3.5, pos.Z))
	m.Parent = pastaCamp
	CollectionService:AddTag(m, "Inimigo")
	local morto = false
	hum.Died:Connect(function()
		if morto then return end
		morto = true
		CollectionService:RemoveTag(m, "Inimigo")
		creditar(root.Position)
		task.delay(2, function() m:Destroy() end)
	end)
	-- IA simples: persegue quem chega perto e bate
	task.spawn(function()
		local ultimoGolpe = 0
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
			if alvo then
				local r = alvo.Parent.HumanoidRootPart
				hum:MoveTo(r.Position)
				if dist < 5 and os.clock() - ultimoGolpe > 1.3 then
					ultimoGolpe = os.clock()
					alvo:TakeDamage(6)
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
				local missao = data and m.Ativa and MissionData.Get(m.Ativa.Id)
				if not missao or missao.Tipo ~= "coletar" then
					aviso(player, "Someone needs these herbs. Take a mission first (Hana or the Stranger).", false)
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
end)

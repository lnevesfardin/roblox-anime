-- Script: ServerScriptService > AttributeServer
-- Atributos do jogador: gastar pontos, treinar na Academia e aplicar os efeitos (vida, velocidade, chakra).
-- AttributeAction (RemoteFunction): "estado" | "gastar", idDoAtributo
-- AttributeNotice (RemoteEvent): aviso curto para o cliente (ex.: resultado do treino)
-- Estações de treino: qualquer modelo/peça com a tag "Treino" e o atributo "Atributo" = id (Forca, Ninjutsu...).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local AttributeData = require(ReplicatedStorage:WaitForChild("AttributeData"))
local MissionData = require(ReplicatedStorage:WaitForChild("MissionData"))
local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))

local action = Instance.new("RemoteFunction")
action.Name = "AttributeAction"
action.Parent = ReplicatedStorage
local notice = Instance.new("RemoteEvent")
notice.Name = "AttributeNotice"
notice.Parent = ReplicatedStorage

local function hoje()
	return os.date("!%Y-%m-%d")
end

local function treinoRestante(data)
	if data.Treino.Dia ~= hoje() then
		return AttributeData.TRAIN_PER_DAY
	end
	return math.max(0, AttributeData.TRAIN_PER_DAY - data.Treino.Feitos)
end

local function aplicar(player)
	local data = PlayerData.Get(player)
	if not data then return end
	local a = data.Atributos
	player:SetAttribute("BonusAgilidade", AttributeData.Speed(a.Agilidade))
	player:SetAttribute("ChakraMax", math.floor(AttributeData.Chakra(a.Chakra) * (1 + (player:GetAttribute("BonusChakra") or 0))))
	player:SetAttribute("PontosAtributo", a.Pontos)
	if not player:GetAttribute("InRun") then
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			local vida = PlayerData.GetCombatStats(player).Health
			hum.MaxHealth = vida
			hum.Health = vida
		end
	end
end

local function estado(player)
	local data = PlayerData.Get(player)
	if not data then return nil end
	local a = data.Atributos
	local valores = {}
	for _, info in ipairs(AttributeData.List) do
		valores[info.Id] = a[info.Id]
	end
	return {
		Level = data.Level,
		Pontos = a.Pontos,
		Cap = AttributeData.Cap(data.Level),
		Valores = valores,
		Treino = treinoRestante(data),
		Vida = AttributeData.Health(a.Vigor),
		Chakra = player:GetAttribute("ChakraMax") or AttributeData.Chakra(a.Chakra),
		Golpe = AttributeData.MeleeMult(a.Forca),
		Poder = AttributeData.PowerMult(a.Ninjutsu),
		Velocidade = AttributeData.Speed(a.Agilidade),
	}
end

action.OnServerInvoke = function(player, acao, id)
	local data = PlayerData.Get(player)
	if not data then
		return { ok = false, erro = "Loading..." }
	end
	if acao == "gastar" then
		local a = data.Atributos
		if not AttributeData.Get(id) then
			return { ok = false, erro = "Invalid attribute.", estado = estado(player) }
		end
		if a.Pontos < 1 then
			return { ok = false, erro = "No points left.", estado = estado(player) }
		end
		if a[id] >= AttributeData.Cap(data.Level) then
			return { ok = false, erro = "At the cap for your level.", estado = estado(player) }
		end
		a.Pontos -= 1
		a[id] += 1
		aplicar(player)
	end
	return { ok = true, estado = estado(player) }
end

---------------------------------------------------------------
-- Treino na Academia
---------------------------------------------------------------
local function treinar(player, id)
	local data = PlayerData.Get(player)
	local info = AttributeData.Get(id)
	if not data or not info then return end
	if treinoRestante(data) <= 0 then
		notice:FireClient(player, "No training left today. Come back tomorrow.", false)
		return
	end
	if data.Atributos[id] >= AttributeData.Cap(data.Level) then
		notice:FireClient(player, info.Name .. " is at the cap for your level.", false)
		return
	end
	if not PlayerData.SpendCoins(player, AttributeData.TRAIN_COST) then
		notice:FireClient(player, "Training costs " .. AttributeData.TRAIN_COST .. " coins.", false)
		return
	end
	if data.Treino.Dia ~= hoje() then
		data.Treino.Dia = hoje()
		data.Treino.Feitos = 0
	end
	data.Treino.Feitos += 1
	-- missões de treino contam este treino
	local prog = ServerStorage:FindFirstChild("MissaoProgresso")
	if prog then prog:Fire(player, "treinar", 1) end
	data.Atributos[id] += 1
	aplicar(player)
	notice:FireClient(player, ("+1 %s  (%d trainings left today)"):format(info.Name, treinoRestante(data)), true)
end

-- Minigame de tempo (Sensei Kaito): acertar 10 socos no alvo de madeira na hora certa.
-- O servidor confere se dá para treinar, abre uma sessão e só dá o ponto se o cliente terminar o minigame.
local minigame = Instance.new("RemoteEvent")
minigame.Name = "TreinoMinigame"
minigame.Parent = ReplicatedStorage
local ACERTOS = 10
local TEMPO_MINIMO = 6 -- segundos: ninguém acerta 10 socos mais rápido que isso
-- modo "teclas" (Coach Gaien e estações que não são alvo de madeira): 4 séries de sequências W A S D
local SERIES = 8
local TEMPO_MINIMO_TECLAS = 6
local sessoes = {} -- [player] = { id, inicio, alvo }

-- tem missão de treino ativa (principal ou lateral)?
local function temMissaoTreino(data)
	local m = data.Missoes
	if type(m) ~= "table" then return false end
	for _, esp in ipairs({ "Ativa", "Lado" }) do
		local e = m[esp]
		local missao = type(e) == "table" and MissionData.Get(e.Id)
		if missao and missao.Tipo == "treinar" then return true end
	end
	return false
end

local function iniciarTreino(player, id, alvo, modo)
	local data = PlayerData.Get(player)
	local info = AttributeData.Get(id)
	if not data or not info or sessoes[player] then return end
	-- limite do dia ou teto do atributo: ainda dá para treinar só para a missão (sem ponto e sem pagar)
	local soMissao = false
	if treinoRestante(data) <= 0 or data.Atributos[id] >= AttributeData.Cap(data.Level) then
		if temMissaoTreino(data) then
			soMissao = true
		elseif treinoRestante(data) <= 0 then
			notice:FireClient(player, "No training left today. Come back tomorrow.", false)
			return
		else
			notice:FireClient(player, info.Name .. " is at the cap for your level.", false)
			return
		end
	end
	if not soMissao and data.Coins < AttributeData.TRAIN_COST then
		notice:FireClient(player, "Training costs " .. AttributeData.TRAIN_COST .. " coins.", false)
		return
	end
	local teclas = modo == "teclas"
	sessoes[player] = { id = id, inicio = os.clock(), alvo = alvo, acertos = teclas and SERIES or ACERTOS, minimo = teclas and TEMPO_MINIMO_TECLAS or TEMPO_MINIMO, soMissao = soMissao }
	if soMissao then
		notice:FireClient(player, "Mission training: counts for your mission, but no stat point (daily limit reached).", true)
	end
	-- treino de chakra (atributo Chakra ou estação com Meditar = true): cena de meditação no cliente
	local cena = (id == "Chakra" or (alvo and alvo:GetAttribute("Meditar") == true)) and "chakra" or nil
	minigame:FireClient(player, { acao = "comecar", id = id, nome = info.Name, acertos = sessoes[player].acertos, alvo = alvo, modo = teclas and "teclas" or "socos", cena = cena,
		titulo = alvo and alvo:GetAttribute("Titulo"), dica = alvo and alvo:GetAttribute("Dica") })
end

-- Prática de natureza: pontos com a tag "Pratica" e o atributo "Natureza" (criados pelo script MundoExtras).
-- Só quem tem a missão do mestre daquela natureza pratica; cada sessão concluída conta 1 na missão.
local NatureData = require(ReplicatedStorage:WaitForChild("NatureData"))
local PRATICA = {
	Agua = { Series = { "FEEL THE WATER", "SHAPE IT", "HOLD THE FLOW", "RELEASE!" }, Dica = "Pull the water of the lake into your chakra." },
	Fogo = { Series = { "BREATHE IN", "IGNITE", "FEED THE FLAME", "RELEASE!" }, Dica = "Turn your breath into fire." },
	Terra = { Series = { "ROOT YOURSELF", "FEEL THE GROUND", "RAISE THE STONE", "RELEASE!" }, Dica = "Push your chakra into the ground." },
	Raio = { Series = { "SPARK", "BUILD THE CHARGE", "HOLD THE CURRENT", "RELEASE!" }, Dica = "Try to form electricity between your hands." },
	Vento = { Series = { "FEEL THE WIND", "GATHER IT", "SPIN IT", "RELEASE!" }, Dica = "Gather the wind in your palms." },
}
local function iniciarPratica(player, nat, alvo)
	local data = PlayerData.Get(player)
	local t = NatureData.Tipos[nat]
	if not data or not t or sessoes[player] then return end
	local tem = false
	local m = data.Missoes
	for _, esp in ipairs({ "Ativa", "Lado" }) do
		local e = type(m) == "table" and m[esp]
		local missao = type(e) == "table" and MissionData.Get(e.Id)
		if missao and missao.Tipo == "praticar" and missao.Alvo == "Pratica_" .. nat then tem = true end
	end
	if not tem then
		local mestre = MissionData.NPCs[t.Mestre]
		notice:FireClient(player, NatureData.Tem(data, nat) and ("Ask " .. (mestre and mestre.Name or "the master") .. " for the " .. t.Name .. " mission first.")
			or ("You do not have the " .. t.Name .. " nature."), false)
		return
	end
	sessoes[player] = { pratica = nat, inicio = os.clock(), alvo = alvo, acertos = SERIES, minimo = TEMPO_MINIMO_TECLAS }
	minigame:FireClient(player, { acao = "comecar", id = "Chakra", nome = t.Name, acertos = SERIES, alvo = alvo, modo = "teclas", cena = "natureza",
		cor = t.Color, series = PRATICA[nat].Series, dica = PRATICA[nat].Dica })
end
local function pontoPratica(inst)
	local nat = inst:GetAttribute("Natureza")
	local t = nat and NatureData.Tipos[nat]
	local peca = inst:IsA("BasePart") and inst or inst:FindFirstChildWhichIsA("BasePart", true)
	if not t or not peca or peca:FindFirstChild("PraticaPrompt") then return end
	local p = Instance.new("ProximityPrompt")
	p.Name = "PraticaPrompt"
	p.ActionText = "Practice"
	p.ObjectText = t.Name .. " nature"
	p.HoldDuration = 0
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.Parent = peca
	p.Triggered:Connect(function(player) iniciarPratica(player, nat, inst) end)
end
for _, inst in ipairs(CollectionService:GetTagged("Pratica")) do pontoPratica(inst) end
CollectionService:GetInstanceAddedSignal("Pratica"):Connect(pontoPratica)

minigame.OnServerEvent:Connect(function(player, resultado, acertos)
	local s = sessoes[player]
	if not s then return end
	sessoes[player] = nil
	if s.pratica then
		if resultado == "ok" and acertos == s.acertos and os.clock() - s.inicio >= s.minimo then
			local prog = ServerStorage:FindFirstChild("MissaoProgresso")
			if prog then prog:Fire(player, "praticar", 1, "Pratica_" .. s.pratica) end
			notice:FireClient(player, "Practice complete! Your control is growing.", true)
		else
			notice:FireClient(player, "You lost control. Try again!", false)
		end
		return
	end
	if resultado == "ok" and acertos == s.acertos and os.clock() - s.inicio >= s.minimo then
		if s.soMissao then
			local prog = ServerStorage:FindFirstChild("MissaoProgresso")
			if prog then prog:Fire(player, "treinar", 1) end
			notice:FireClient(player, "Mission progress! (no stat point today)", true)
		else
			treinar(player, s.id)
		end
	elseif resultado == "ok" then
		notice:FireClient(player, "Training failed. Try again!", false)
	else
		notice:FireClient(player, "Too many mistakes! Try again.", false)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	sessoes[player] = nil
end)

local function estacao(inst)
	local id = inst:GetAttribute("Atributo")
	local info = id and AttributeData.Get(id)
	local peca = inst:IsA("BasePart") and inst or inst:FindFirstChildWhichIsA("BasePart", true)
	if not info or not peca or peca:FindFirstChild("TreinoPrompt") then return end
	local p = Instance.new("ProximityPrompt")
	p.Name = "TreinoPrompt"
	p.ActionText = "Train"
	p.ObjectText = info.Name .. "  (" .. AttributeData.TRAIN_COST .. " coins)"
	-- alvos de madeira (PosteTreino) usam o minigame de socos; as outras estações usam o de teclas (W A S D)
	-- treinos na natureza (mundo aberto) marcam o atributo Minigame = true e usam o minigame de socos
	-- treinos de chakra (atributo Chakra ou Meditar = true) sempre usam a cena de meditação com teclas
	local meditar = id == "Chakra" or inst:GetAttribute("Meditar") == true
	local alvoMadeira = (inst.Name == "PosteTreino" or inst:GetAttribute("Minigame") == true) and not meditar
	p.HoldDuration = 0
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
	p.Parent = peca
	p.Triggered:Connect(function(player)
		iniciarTreino(player, id, inst, alvoMadeira and "socos" or "teclas")
	end)
end
for _, inst in ipairs(CollectionService:GetTagged("Treino")) do
	estacao(inst)
end
CollectionService:GetInstanceAddedSignal("Treino"):Connect(estacao)

---------------------------------------------------------------
-- Jogadores
---------------------------------------------------------------
local function setup(player)
	local function quandoPronto()
		for _ = 1, 50 do
			if PlayerData.Get(player) then break end
			task.wait(0.2)
		end
		task.wait(0.3) -- deixa o ClanServer marcar o bônus do clã primeiro
		aplicar(player)
	end
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Humanoid", 10)
		quandoPronto()
	end)
	player:GetAttributeChangedSignal("BonusChakra"):Connect(function()
		aplicar(player)
	end)
	task.spawn(quandoPronto)
end
Players.PlayerAdded:Connect(setup)
for _, p in ipairs(Players:GetPlayers()) do setup(p) end

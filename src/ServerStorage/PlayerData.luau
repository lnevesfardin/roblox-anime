-- ModuleScript: ServerStorage > PlayerData
-- Guarda e salva os dados de cada jogador (nível, XP, moedas, gemas, personagens, garantia,
-- Battle Pass, itens, acessórios, boosts e configurações). Tudo num DataStore só.
-- Outros scripts do servidor usam as funções daqui; não precisam mexer no DataStore.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterData = require(ReplicatedStorage:WaitForChild("CharacterData"))
local EconomyData = require(ReplicatedStorage:WaitForChild("EconomyData"))
local AttributeData = require(ReplicatedStorage:WaitForChild("AttributeData"))

-- Se o jogo não estiver publicado (ou a API estiver desligada), o DataStore falha.
-- Nesse caso o jogo continua funcionando, mas sem salvar o progresso.
local okStore, store = pcall(function()
	return DataStoreService:GetDataStore("RPGCarreira_v1") -- store novo da fase de carreira (os saves de teste do RPGAnime_v2 ficaram para trás)
end)
if not okStore then
	warn("[PlayerData] Salvamento desligado: publique o jogo e ative a API (Game Settings > Security). Progresso NÃO será salvo nesta sessão.")
	store = nil
end
local MAX_TRIES = 3

local PlayerData = {}

local cache = {} -- [player] = { Data = {...}, CanSave = bool, Saving = bool }

local function keyFor(player)
	return "player_" .. player.UserId
end

local function defaultData()
	return {
		Level = 1,
		XP = 0,
		Coins = CharacterData.StartingCoins,
		Owned = {},      -- [idDoPersonagem] = quantidade de cópias
		Equipped = nil,
		Pity = 0,
		Gems = 0,                         -- Gemas do Rikudou (só Robux ou Battle Pass)
		BattlePass = { XP = 0, Claimed = {} }, -- Claimed["7"] = true
		Items = {},                       -- [idDoItem] = quantidade
		Cosmetics = {},                   -- [slot] = idDoItem equipado
		Boosts = {},                      -- [XP/Coins] = os.time() em que acaba
		Settings = {},                    -- configurações do jogador
		Purchases = {},                   -- IDs de compras em Robux já entregues
		Cla = nil,                        -- clã (preenchido em withDefaults)
		Altura = 1,                       -- estatura do personagem (0.9 a 1.1)
		Atributos = nil,                  -- 5 atributos + Pontos livres (preenchido em withDefaults)
		Treino = nil,                     -- treinos do dia: { Dia = "2026-11-11", Feitos = 0 }
		Missoes = nil,                    -- missão ativa, história e recargas (MissionServer)
		Rank = "Estudante",               -- rank ninja (Estudante, Genin, Chunin...)
	}
end

local DEFAULT_SETTINGS = {
	Music = 0.5, MusicOn = true,
	SFX = 0.8, SFXOn = true,
	Sensitivity = 1, FOV = 70,
	LowGraphics = false,
}
PlayerData.DEFAULT_SETTINGS = DEFAULT_SETTINGS

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in pairs(t) do
		c[k] = deepCopy(v)
	end
	return c
end

-- Completa campos que faltarem em dados salvos de versões antigas
local function withDefaults(loaded)
	local data = defaultData()
	if type(loaded) ~= "table" then
		loaded = {}
	end
	for key, value in pairs(loaded) do
		data[key] = value
	end
	for _, key in ipairs({ "Owned", "Items", "Cosmetics", "Boosts", "Settings", "Purchases" }) do
		if type(data[key]) ~= "table" then
			data[key] = {}
		end
	end
	if type(data.BattlePass) ~= "table" then
		data.BattlePass = { XP = 0, Claimed = {} }
	end
	data.BattlePass.XP = tonumber(data.BattlePass.XP) or 0
	if type(data.BattlePass.Claimed) ~= "table" then
		data.BattlePass.Claimed = {}
	end
	data.Gems = tonumber(data.Gems) or 0
	-- clã: Id (nil até escolher), giros grátis, opções sorteadas à espera de escolha, contadores de garantia e caminho do clã
	if type(data.Cla) ~= "table" then
		data.Cla = { Giros = 3 }
	end
	local c = data.Cla
	c.Giros = tonumber(c.Giros) or 0
	c.Pity10 = tonumber(c.Pity10) or 0
	c.Pity100 = tonumber(c.Pity100) or 0
	c.Etapa = tonumber(c.Etapa) or 0
	if type(c.Opcoes) ~= "table" then c.Opcoes = {} end
	if type(c.Progresso) ~= "table" then c.Progresso = {} end
	data.Altura = math.clamp(tonumber(data.Altura) or 1, 0.9, 1.1)
	-- atributos: quem nunca teve começa com os pontos do nível atual
	if type(data.Atributos) ~= "table" then
		data.Atributos = { Pontos = AttributeData.POINTS_PER_LEVEL * (tonumber(data.Level) or 1) }
	end
	for _, info in ipairs(AttributeData.List) do
		data.Atributos[info.Id] = math.max(0, math.floor(tonumber(data.Atributos[info.Id]) or 0))
	end
	data.Atributos.Pontos = math.max(0, math.floor(tonumber(data.Atributos.Pontos) or 0))
	if type(data.Treino) ~= "table" then
		data.Treino = {}
	end
	data.Treino.Dia = tostring(data.Treino.Dia or "")
	data.Treino.Feitos = tonumber(data.Treino.Feitos) or 0
	for k, v in pairs(DEFAULT_SETTINGS) do
		if type(data.Settings[k]) ~= type(v) then
			data.Settings[k] = v
		end
	end
	return data
end

local function loadData(player)
	if not store then
		return withDefaults(nil), false
	end
	for attempt = 1, MAX_TRIES do
		local ok, result = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			return withDefaults(result), true
		end
		warn("[PlayerData] Falha ao carregar " .. player.Name .. " (tentativa " .. attempt .. "): " .. tostring(result))
		task.wait(1)
	end
	-- Se não conseguiu ler, NÃO salva depois, para não apagar o progresso real.
	return withDefaults(nil), false
end

-- Atualiza os números que aparecem no canto da tela
local function refreshStats(player)
	local entry = cache[player]
	local folder = player:FindFirstChild("leaderstats")
	if not entry or not folder then
		return
	end
	local d = entry.Data
	folder.Level.Value = d.Level
	folder.XP.Value = d.XP
	folder.Coins.Value = d.Coins
	-- valores que o HUD lê (só leitura no cliente; quem muda é o servidor)
	player:SetAttribute("Gems", d.Gems)
	player:SetAttribute("PontosAtributo", d.Atributos.Pontos)
	player:SetAttribute("BPXP", d.BattlePass.XP)
	player:SetAttribute("BoostXP", d.Boosts.XP or 0)
	player:SetAttribute("BoostCoins", d.Boosts.Coins or 0)
	player:SetAttribute("ItemsRev", (player:GetAttribute("ItemsRev") or 0) + 1)
end

local function setupPlayer(player)
	if cache[player] then
		return
	end

	local data, canSave = loadData(player)
	cache[player] = { Data = data, CanSave = canSave, Saving = false }

	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	for _, name in ipairs({ "Level", "XP", "Coins" }) do
		local v = Instance.new("IntValue")
		v.Name = name
		v.Parent = folder
	end
	folder.Parent = player

	refreshStats(player)
	player:SetAttribute("Equipped", data.Equipped)
	player:SetAttribute("OwnedRev", 0)
end

---------------------------------------------------------------
-- API pública
---------------------------------------------------------------

function PlayerData.Get(player)
	local entry = cache[player]
	return entry and entry.Data or nil
end

function PlayerData.Refresh(player)
	refreshStats(player)
end

function PlayerData.AddCoins(player, amount)
	local data = PlayerData.Get(player)
	if not data or amount <= 0 then
		return
	end
	data.Coins += math.floor(amount)
	refreshStats(player)
end

-- Retorna true se tinha moedas suficientes e descontou
function PlayerData.SpendCoins(player, amount)
	local data = PlayerData.Get(player)
	if not data or amount < 0 or data.Coins < amount then
		return false
	end
	data.Coins -= amount
	refreshStats(player)
	return true
end

function PlayerData.AddXP(player, amount)
	local data = PlayerData.Get(player)
	if not data or amount <= 0 then
		return
	end
	-- o XP do Battle Pass sobe junto
	local bp = EconomyData.BattlePass
	data.BattlePass.XP = math.min(data.BattlePass.XP + math.floor(amount), bp.MaxLevel * bp.XPPerLevel)
	data.XP += math.floor(amount)
	while data.Level < CharacterData.MaxLevel do
		local needed = CharacterData.XPForLevel(data.Level)
		if data.XP < needed then
			break
		end
		data.XP -= needed
		data.Level += 1
		data.Atributos.Pontos += AttributeData.POINTS_PER_LEVEL -- pontos de atributo por nível
	end
	if data.Level >= CharacterData.MaxLevel then
		data.XP = 0
	end
	refreshStats(player)
end

---------------------------------------------------------------
-- Gemas do Rikudou
---------------------------------------------------------------
function PlayerData.AddGems(player, amount)
	local data = PlayerData.Get(player)
	if not data or amount <= 0 then
		return
	end
	data.Gems += math.floor(amount)
	refreshStats(player)
end

function PlayerData.SpendGems(player, amount)
	local data = PlayerData.Get(player)
	if not data or amount < 0 or data.Gems < amount then
		return false
	end
	data.Gems -= amount
	refreshStats(player)
	return true
end

---------------------------------------------------------------
-- Itens (boosts, acessórios e caixas grátis)
---------------------------------------------------------------
function PlayerData.AddItem(player, itemId, amount)
	local data = PlayerData.Get(player)
	if not data or not EconomyData.Items[itemId] then
		return
	end
	data.Items[itemId] = (data.Items[itemId] or 0) + (amount or 1)
	refreshStats(player)
end

function PlayerData.TakeItem(player, itemId, amount)
	local data = PlayerData.Get(player)
	amount = amount or 1
	if not data or (data.Items[itemId] or 0) < amount then
		return false
	end
	data.Items[itemId] -= amount
	if data.Items[itemId] <= 0 then
		data.Items[itemId] = nil
	end
	refreshStats(player)
	return true
end

-- Multiplicador de boost ativo (1 ou 2)
function PlayerData.GetBoostMult(player, stat)
	local data = PlayerData.Get(player)
	if data and (data.Boosts[stat] or 0) > os.time() then
		return 2
	end
	return 1
end

-- Usa um boost do inventário. Se já tiver um ativo, o tempo soma.
function PlayerData.UseBoost(player, itemId)
	local item = EconomyData.Items[itemId]
	local data = PlayerData.Get(player)
	if not data or not item or item.Type ~= "Boost" then
		return false
	end
	if not PlayerData.TakeItem(player, itemId, 1) then
		return false
	end
	local now = os.time()
	data.Boosts[item.Stat] = math.max(now, data.Boosts[item.Stat] or 0) + item.Minutes * 60
	refreshStats(player)
	return true
end

-- Entrega uma recompensa do Battle Pass (ou de qualquer outro lugar no futuro)
function PlayerData.GrantReward(player, reward)
	local data = PlayerData.Get(player)
	if not data or type(reward) ~= "table" then
		return false
	end
	if reward.Coins then
		PlayerData.AddCoins(player, reward.Coins)
	end
	if reward.Gems then
		PlayerData.AddGems(player, reward.Gems)
	end
	if reward.Crates then
		PlayerData.AddItem(player, "caixa_gratis", reward.Crates)
	end
	if reward.Item then
		PlayerData.AddItem(player, reward.Item, 1)
	end
	if reward.Character and CharacterData.GetCharacter(reward.Character) then
		PlayerData.GiveCharacter(player, reward.Character)
	end
	refreshStats(player)
	return true
end

-- Dá um personagem ao jogador. Retorna (éNovo, totalDeCópias)
function PlayerData.GiveCharacter(player, characterId)
	local data = PlayerData.Get(player)
	if not data then
		return false, 0
	end
	local before = data.Owned[characterId] or 0
	data.Owned[characterId] = before + 1
	-- O primeiro personagem que o jogador ganha já vem equipado
	if not data.Equipped then
		data.Equipped = characterId
		player:SetAttribute("Equipped", characterId)
	end
	player:SetAttribute("OwnedRev", (player:GetAttribute("OwnedRev") or 0) + 1)
	return before == 0, data.Owned[characterId]
end

-- Equipa um personagem que o jogador possui. Retorna true se deu certo.
function PlayerData.Equip(player, characterId)
	local data = PlayerData.Get(player)
	if not data or type(characterId) ~= "string" then
		return false
	end
	if (data.Owned[characterId] or 0) < 1 or not CharacterData.GetCharacter(characterId) then
		return false
	end
	data.Equipped = characterId
	player:SetAttribute("Equipped", characterId)
	return true
end

-- Vida e dano de combate. Se o jogador tiver um personagem equipado, usa os dele.
function PlayerData.GetCombatStats(player)
	local data = PlayerData.Get(player)
	if not data then
		return { Health = 100, Damage = 10, PowerDamage = 10 }
	end
	-- vem dos atributos: Vigor dá vida, Força dá dano de golpe, Ninjutsu dá dano de poder
	local a = data.Atributos
	return {
		Health = AttributeData.Health(a.Vigor),
		Damage = math.floor(10 * AttributeData.MeleeMult(a.Forca) + 0.5),
		PowerDamage = math.floor(10 * AttributeData.PowerMult(a.Ninjutsu) + 0.5),
	}
end

-- Salva. Retorna true se salvou. force = salva mesmo se outro salvamento estiver rodando
-- (usado nas compras com Robux, que precisam confirmar o salvamento).
function PlayerData.Save(player, force)
	local entry = cache[player]
	if not entry or not entry.CanSave then
		return false
	end
	if entry.Saving and not force then
		return false
	end
	entry.Saving = true
	-- Copia os dados no momento do salvamento
	local snapshot = deepCopy(entry.Data)
	local saved = false

	for attempt = 1, MAX_TRIES do
		local ok, err = pcall(function()
			store:SetAsync(keyFor(player), snapshot)
		end)
		if ok then
			saved = true
			break
		end
		warn("[PlayerData] Falha ao salvar " .. player.Name .. " (tentativa " .. attempt .. "): " .. tostring(err))
		task.wait(1)
	end
	entry.Saving = false
	return saved
end

function PlayerData.CanSave(player)
	local entry = cache[player]
	return entry ~= nil and entry.CanSave
end

-- Liga tudo. Chamado uma vez pelo script ProgressionServer.
function PlayerData.Init()
	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(setupPlayer, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		PlayerData.Save(player)
		cache[player] = nil
	end)

	-- Salvamento automático a cada 60 segundos
	task.spawn(function()
		while true do
			task.wait(60)
			for player in pairs(cache) do
				PlayerData.Save(player)
			end
		end
	end)

	-- Salva todos quando o servidor for desligado
	game:BindToClose(function()
		for player in pairs(cache) do
			PlayerData.Save(player)
		end
	end)
end

return PlayerData

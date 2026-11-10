-- ModuleScript: ServerStorage > PlayerData
-- Guarda e salva os dados de cada jogador (nível, XP, moedas, personagens, garantia).
-- Outros scripts do servidor usam as funções daqui; não precisam mexer no DataStore.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterData = require(ReplicatedStorage:WaitForChild("CharacterData"))

-- Se o jogo não estiver publicado (ou a API estiver desligada), o DataStore falha.
-- Nesse caso o jogo continua funcionando, mas sem salvar o progresso.
local okStore, store = pcall(function()
	return DataStoreService:GetDataStore("RPGAnime_v2")
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
	}
end

-- Completa campos que faltarem em dados salvos de versões antigas
local function withDefaults(loaded)
	local data = defaultData()
	if type(loaded) ~= "table" then
		return data
	end
	for key, value in pairs(loaded) do
		data[key] = value
	end
	if type(data.Owned) ~= "table" then
		data.Owned = {}
	end
	return data
end

local function loadData(player)
	if not store then
		return defaultData(), false
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
	return defaultData(), false
end

-- Atualiza os números que aparecem no canto da tela
local function refreshStats(player)
	local entry = cache[player]
	local folder = player:FindFirstChild("leaderstats")
	if not entry or not folder then
		return
	end
	folder.Level.Value = entry.Data.Level
	folder.XP.Value = entry.Data.XP
	folder.Coins.Value = entry.Data.Coins
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
	data.XP += math.floor(amount)
	while data.Level < CharacterData.MaxLevel do
		local needed = CharacterData.XPForLevel(data.Level)
		if data.XP < needed then
			break
		end
		data.XP -= needed
		data.Level += 1
	end
	if data.Level >= CharacterData.MaxLevel then
		data.XP = 0
	end
	refreshStats(player)
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
		return { Health = 100, Damage = 10 }
	end
	if data.Equipped then
		local s = CharacterData.GetStats(data.Equipped, data.Level)
		if s then
			return s
		end
	end
	local mult = 1 + 0.05 * (data.Level - 1)
	return { Health = math.floor(100 * mult), Damage = math.floor(10 * mult) }
end

function PlayerData.Save(player)
	local entry = cache[player]
	if not entry or not entry.CanSave or entry.Saving then
		return
	end
	entry.Saving = true
	-- Copia os dados no momento do salvamento
	local snapshot = table.clone(entry.Data)
	snapshot.Owned = table.clone(entry.Data.Owned)

	for attempt = 1, MAX_TRIES do
		local ok, err = pcall(function()
			store:SetAsync(keyFor(player), snapshot)
		end)
		if ok then
			break
		end
		warn("[PlayerData] Falha ao salvar " .. player.Name .. " (tentativa " .. attempt .. "): " .. tostring(err))
		task.wait(1)
	end
	entry.Saving = false
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

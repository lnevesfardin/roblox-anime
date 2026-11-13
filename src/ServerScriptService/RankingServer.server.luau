-- Script: ServerScriptService > RankingServer
-- Ranking global por nivel (OrderedDataStore, todos os servidores). Pontuacao = nivel x 1.000.000 + XP (o XP desempata).
-- Cliente: RemoteFunction GetRanking -> { lista = { { pos, id, nome, nivel } }, voce = { pos?, id, nome, nivel } }
-- Sem DataStore (Studio): mostra so quem esta neste servidor.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))

local TOP = 50
local store
pcall(function() store = DataStoreService:GetOrderedDataStore("RankingNivel_v1") end)

local getRank = Instance.new("RemoteFunction")
getRank.Name = "GetRanking"
getRank.Parent = ReplicatedStorage

local nomes = {}
local function nomeDe(id)
	if nomes[id] then return nomes[id] end
	local p = Players:GetPlayerByUserId(id)
	local n = p and p.Name
	if not n then
		local ok, r = pcall(Players.GetNameFromUserIdAsync, Players, id)
		n = ok and r or ("Player " .. id)
	end
	nomes[id] = n
	return n
end

local function pontos(player)
	local data = PlayerData.Get(player)
	if not data then return nil end
	return (data.Level or 1) * 1000000 + math.min(999999, data.XP or 0)
end

local publicado = {}
local function publicar(player)
	local s = pontos(player)
	if not (store and s) or publicado[player.UserId] == s then return end
	local ok = pcall(function() store:SetAsync(tostring(player.UserId), s) end)
	if ok then publicado[player.UserId] = s end
end

task.spawn(function()
	while true do
		task.wait(90)
		for _, p in ipairs(Players:GetPlayers()) do publicar(p) end
	end
end)
Players.PlayerRemoving:Connect(publicar)
game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do publicar(p) end
end)

local cache, validoAte = nil, 0
local function topo()
	if cache and os.clock() < validoAte then return cache end
	local lista = {}
	if store then
		local ok, pag = pcall(function() return store:GetSortedAsync(false, TOP):GetCurrentPage() end)
		if ok then
			for i, e in ipairs(pag) do
				local id = tonumber(e.key)
				if id then table.insert(lista, { pos = i, id = id, nome = nomeDe(id), nivel = math.floor(e.value / 1000000), pontos = e.value }) end
			end
		end
	end
	if #lista == 0 then
		for _, p in ipairs(Players:GetPlayers()) do
			local s = pontos(p)
			if s then table.insert(lista, { id = p.UserId, nome = p.Name, nivel = math.floor(s / 1000000), pontos = s }) end
		end
		table.sort(lista, function(a, b) return a.pontos > b.pontos end)
		for i, e in ipairs(lista) do e.pos = i end
	end
	cache, validoAte = lista, os.clock() + 45
	return lista
end

getRank.OnServerInvoke = function(player)
	local lista = topo()
	local meu = pontos(player)
	local voce = { id = player.UserId, nome = player.Name, nivel = meu and math.floor(meu / 1000000) or 1 }
	for _, e in ipairs(lista) do
		if e.id == player.UserId then voce.pos = e.pos end
	end
	return { lista = lista, voce = voce }
end

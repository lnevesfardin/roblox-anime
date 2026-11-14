-- Script: ServerScriptService > NatureServer
-- Naturezas de chakra: roleta do nascimento (1 a 3), girar de novo com gemas e escolher 1 de 2 jutsus a cada etapa e equipar nas teclas G, H, J e K.
-- NaturezaAcao (RemoteFunction): "estado" | "girar" | "regirar" | "equipar", posicao, idDoJutsu (ou false) | "escolher", natureza, etapa, opcao
-- Atributos do jogador: "NaturezaRolou" (bool) e "NaturezaEstado" (JSON: Rolou, Afinidade, Lista, Jutsus, Equip, Pendente)
-- Outros scripts pedem para reenviar o estado pelo BindableEvent ServerStorage.AtualizarNatureza.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local NatureData = require(ReplicatedStorage:WaitForChild("NatureData"))
local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))

local acao = Instance.new("RemoteFunction")
acao.Name = "NaturezaAcao"
acao.Parent = ReplicatedStorage

local rng = Random.new()

local function dados(player)
	local data = PlayerData.Get(player)
	if not data then return nil end
	return data, NatureData.Garantir(data)
end

local function estado(player)
	local data, n = dados(player)
	if not data then return nil end
	local jutsus = {}
	for id in pairs(n.Jutsus) do
		if NatureData.Jutsu(id) then table.insert(jutsus, id) end
	end
	return { Rolou = n.Rolou == true, Afinidade = n.Afinidade or false, Lista = n.Lista, Jutsus = jutsus, Equip = { n.Equip[1] or false, n.Equip[2] or false, n.Equip[3] or false, n.Equip[4] or false }, Pendente = n.Pendente, Fichas = n.Fichas or 0 }
end

local function aplicar(player)
	local e = estado(player)
	if not e then return end
	player:SetAttribute("NaturezaRolou", e.Rolou)
	player:SetAttribute("NaturezaEstado", HttpService:JSONEncode(e))
end

local atualizar = Instance.new("BindableEvent")
atualizar.Name = "AtualizarNatureza"
atualizar.Parent = ServerStorage
atualizar.Event:Connect(aplicar)

local function sortear(player, data, n)
	n.Lista = NatureData.Roll(rng)
	n.Afinidade = n.Lista[1] -- a primeira sorteada e a afinidade
	n.Rolou = true
	-- jutsus de naturezas que o jogador nao tem mais se perdem
	for id in pairs(n.Jutsus) do
		local j = NatureData.Jutsu(id)
		if not j or not table.find(n.Lista, j.Natureza) then n.Jutsus[id] = nil end
	end
	NatureData.Garantir(data)
	task.spawn(function() pcall(PlayerData.Save, player) end)
	aplicar(player)
end

local ocupado = {}
acao.OnServerInvoke = function(player, pedido, a, b, c)
	local data, n = dados(player)
	if not data then return { ok = false, erro = "Loading..." } end
	if pedido == "girar" or pedido == "regirar" then
		if ocupado[player] then return { ok = false, erro = "Wait..." } end
		if pedido == "girar" and n.Rolou then
			return { ok = false, erro = "You already know your natures.", estado = estado(player) }
		end
		if pedido == "regirar" then
			if not n.Rolou then return { ok = false, erro = "Spin first." } end
			if (n.Fichas or 0) > 0 then
				n.Fichas -= 1 -- ficha de re-giro (premio do pergaminho): gira de graca
			elseif not PlayerData.SpendGems(player, NatureData.CUSTO_REGIRAR) then
				return { ok = false, erro = "You need " .. NatureData.CUSTO_REGIRAR .. " gems.", estado = estado(player) }
			end
		end
		ocupado[player] = true
		sortear(player, data, n)
		ocupado[player] = nil
		return { ok = true, estado = estado(player) }
	elseif pedido == "equipar" then
		local pos = tonumber(a)
		if not pos or pos < 1 or pos > NatureData.SLOTS or pos % 1 ~= 0 then return { ok = false, erro = "Invalid slot." } end
		if b == false or b == nil then
			n.Equip[pos] = false
		else
			local j = type(b) == "string" and NatureData.Jutsu(b)
			if not j or not n.Jutsus[b] or not NatureData.Tem(data, j.Natureza) then
				return { ok = false, erro = "You have not learned this jutsu.", estado = estado(player) }
			end
			for outra = 1, NatureData.SLOTS do
				if outra ~= pos and n.Equip[outra] == b then n.Equip[outra] = n.Equip[pos] or false end
			end
			n.Equip[pos] = b
		end
		aplicar(player)
		return { ok = true, estado = estado(player) }
	end
	if pedido == "escolher" then
		-- a = natureza, b = etapa, c = opcao (1 ou 2): so vale para uma escolha liberada por missao
		local tier, opcao = tonumber(b), tonumber(c)
		local t = type(a) == "string" and NatureData.Tipos[a]
		local par = t and tier and t.Tiers[tier]
		local j = par and opcao and par[opcao]
		local idx
		for i, p in ipairs(n.Pendente) do
			if p.Natureza == a and p.Tier == tier then idx = i break end
		end
		if not j or not idx or not NatureData.Tem(data, a) then
			return { ok = false, erro = "This choice is not available.", estado = estado(player) }
		end
		table.remove(n.Pendente, idx)
		n.Jutsus[j.Id] = true
		for i = 1, NatureData.SLOTS do -- ja equipa numa tecla livre
			if not n.Equip[i] then n.Equip[i] = j.Id break end
		end
		task.spawn(function() pcall(PlayerData.Save, player) end)
		aplicar(player)
		return { ok = true, estado = estado(player), jutsu = j.Name }
	end
	return { ok = true, estado = estado(player) }
end

local function setup(player)
	for _ = 1, 60 do
		if PlayerData.Get(player) then break end
		task.wait(0.25)
	end
	if not player.Parent then return end
	aplicar(player)
end
Players.PlayerAdded:Connect(setup)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(setup, p) end
Players.PlayerRemoving:Connect(function(p) ocupado[p] = nil end)

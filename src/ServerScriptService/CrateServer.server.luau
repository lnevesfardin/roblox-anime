-- Script: ServerScriptService > CrateServer
-- Abre caixas: cobra moedas, sorteia a raridade (com garantia) e entrega o personagem.
-- Toda a lógica fica no servidor para o jogador não conseguir trapacear.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CharacterData = require(ReplicatedStorage:WaitForChild("CharacterData"))
local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))

-- O cliente chama este "telefone" para pedir a abertura de uma caixa
local openCrate = Instance.new("RemoteFunction")
openCrate.Name = "OpenCrate"
openCrate.Parent = ReplicatedStorage

local busy = {} -- impede abrir duas caixas ao mesmo tempo

-- Sorteia o índice de uma raridade. minIndex limita ao mínimo (usado pela garantia).
local function rollRarityIndex(minIndex)
	local total = 0
	for i, r in ipairs(CharacterData.Rarities) do
		if i >= minIndex then
			total += r.Weight
		end
	end
	local pick = math.random() * total
	local acc = 0
	for i, r in ipairs(CharacterData.Rarities) do
		if i >= minIndex then
			acc += r.Weight
			if pick <= acc then
				return i
			end
		end
	end
	return #CharacterData.Rarities
end

-- Escolhe um personagem da raridade sorteada.
-- Se ainda não existir nenhum dessa raridade (MVP), desce para a raridade abaixo.
local function pickCharacter(rarityIndex)
	for i = rarityIndex, 1, -1 do
		local rarityId = CharacterData.Rarities[i].Id
		local pool = {}
		for _, c in ipairs(CharacterData.Characters) do
			if c.Rarity == rarityId then
				table.insert(pool, c)
			end
		end
		if #pool > 0 then
			return pool[math.random(1, #pool)]
		end
	end
	return nil
end

openCrate.OnServerInvoke = function(player, crateId)
	if player:GetAttribute("InRun") then
		return { ok = false, reason = "Crates can only be opened in the lobby." }
	end
	if busy[player] then
		return { ok = false, reason = "Wait for the previous crate." }
	end
	busy[player] = true

	local result
	local success, err = pcall(function()
		local crate = CharacterData.Crates[crateId]
		local data = PlayerData.Get(player)
		if type(crateId) ~= "string" or not crate then
			result = { ok = false, reason = "Invalid crate." }
			return
		end
		if not data then
			result = { ok = false, reason = "Your data is still loading." }
			return
		end
		if not PlayerData.SpendCoins(player, crate.Cost) then
			result = { ok = false, reason = "Not enough coins." }
			return
		end

		-- Garantia
		data.Pity += 1
		local pityIndex = CharacterData.GetRarityIndex(CharacterData.PityMinRarity)
		local minIndex = 1
		if data.Pity >= CharacterData.PityLimit then
			minIndex = pityIndex
		end

		local rarityIndex = rollRarityIndex(minIndex)
		if rarityIndex >= pityIndex then
			data.Pity = 0
		end

		local character = pickCharacter(rarityIndex)
		if not character then
			-- Não deveria acontecer, mas devolve as moedas por segurança
			PlayerData.AddCoins(player, crate.Cost)
			result = { ok = false, reason = "No character available." }
			return
		end

		local isNew, copies = PlayerData.GiveCharacter(player, character.Id)
		result = {
			ok = true,
			id = character.Id,
			name = character.Name,
			rarity = character.Rarity,
			isNew = isNew,
			copies = copies,
		}
	end)

	busy[player] = nil

	if not success then
		warn("[CrateServer] Erro ao abrir caixa: " .. tostring(err))
		return { ok = false, reason = "Internal error." }
	end
	return result
end

game.Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)

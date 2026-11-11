-- Script: ServerScriptService > CrateServer
-- Abre caixas: cobra moedas ou gemas (ou usa uma caixa grátis do Battle Pass),
-- sorteia a raridade (com garantia na caixa básica) e entrega o personagem.
-- Toda a lógica fica no servidor: o cliente só pede e mostra a animação do resultado.

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
local function rollRarityIndex(crateId, minIndex)
	local total = 0
	for i = minIndex, #CharacterData.Rarities do
		total += CharacterData.GetWeight(crateId, i)
	end
	local pick = math.random() * total
	local acc = 0
	for i = minIndex, #CharacterData.Rarities do
		local w = CharacterData.GetWeight(crateId, i)
		acc += w
		if w > 0 and pick <= acc then
			return i
		end
	end
	return #CharacterData.Rarities
end

-- Escolhe um personagem da raridade sorteada.
-- Se ainda não existir nenhum dessa raridade, desce para a raridade abaixo
-- (as chances mostradas no jogo já levam isso em conta: CharacterData.GetCrateOdds).
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

-- useFree = true: usa uma "caixa grátis" do inventário (só a caixa básica)
openCrate.OnServerInvoke = function(player, crateId, useFree)
	if player:GetAttribute("InRun") then
		return { ok = false, reason = "Crates can only be opened in the lobby." }
	end
	if busy[player] then
		return { ok = false, reason = "Wait for the previous crate." }
	end
	busy[player] = true

	local result
	local success, err = pcall(function()
		local crate = type(crateId) == "string" and CharacterData.Crates[crateId]
		local data = PlayerData.Get(player)
		if not crate then
			result = { ok = false, reason = "Invalid crate." }
			return
		end
		if not data then
			result = { ok = false, reason = "Your data is still loading." }
			return
		end

		-- pagamento
		local refund
		if useFree == true then
			if crateId ~= "Basica" or not PlayerData.TakeItem(player, "caixa_gratis", 1) then
				result = { ok = false, reason = "You have no free crates." }
				return
			end
			refund = function() PlayerData.AddItem(player, "caixa_gratis", 1) end
		elseif crate.Currency == "Gems" then
			if not PlayerData.SpendGems(player, crate.Cost) then
				result = { ok = false, reason = "Not enough Rikudou Gems." }
				return
			end
			refund = function() PlayerData.AddGems(player, crate.Cost) end
		else
			if not PlayerData.SpendCoins(player, crate.Cost) then
				result = { ok = false, reason = "Not enough coins." }
				return
			end
			refund = function() PlayerData.AddCoins(player, crate.Cost) end
		end

		-- Garantia (só nas caixas com Pity)
		local pityIndex = CharacterData.GetRarityIndex(CharacterData.PityMinRarity)
		local minIndex = 1
		if crate.Pity then
			data.Pity += 1
			if data.Pity >= CharacterData.PityLimit then
				minIndex = pityIndex
			end
		end

		local rarityIndex = rollRarityIndex(crateId, minIndex)
		local character = pickCharacter(rarityIndex)
		if not character then
			-- Não deveria acontecer, mas devolve o pagamento por segurança
			refund()
			result = { ok = false, reason = "No character available." }
			return
		end
		if crate.Pity and CharacterData.GetRarityIndex(character.Rarity) >= pityIndex then
			data.Pity = 0
		end

		local isNew, copies = PlayerData.GiveCharacter(player, character.Id)
		result = {
			ok = true,
			id = character.Id,
			name = character.Name,
			rarity = character.Rarity,
			isNew = isNew,
			copies = copies,
			pity = data.Pity,
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

-- Script: ServerScriptService > CrateServer
-- Abre caixas: cobra moedas ou gemas (ou usa uma caixa grátis do Battle Pass),
-- sorteia a raridade (com garantia na caixa básica) e depois um prêmio da lista daquela raridade:
-- moedas, gemas, boosts, acessórios ou fichas de re-giro (ver CharacterData.CrateRewards).
-- Toda a lógica fica no servidor: o cliente só pede e mostra a animação do resultado.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CharacterData = require(ReplicatedStorage:WaitForChild("CharacterData"))
local EconomyData = require(ReplicatedStorage:WaitForChild("EconomyData"))
local NatureData = require(ReplicatedStorage:WaitForChild("NatureData"))
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

-- Entrega moedas/gemas e devolve { reward, nome, simbolo } para a tela de resultado.
local function entregarDinheiro(player, p)
	if p.Gems then
		local n = math.random(p.Gems[1], p.Gems[2])
		PlayerData.AddGems(player, n)
		return { Gems = n }, "+" .. n .. " GEMS", "💎"
	end
	local n = math.random(p.Coins[1], p.Coins[2])
	PlayerData.AddCoins(player, n)
	return { Coins = n }, "+" .. n .. " COINS", "💰"
end

-- Sorteia um premio da lista (pesos W) e entrega. Retorna reward, nome, simbolo.
local function sortearPremio(player, data, lista)
	local total = 0
	for _, p in ipairs(lista) do total += p.W end
	local pick = math.random() * total
	local escolhido = lista[#lista]
	local acc = 0
	for _, p in ipairs(lista) do
		acc += p.W
		if pick <= acc then escolhido = p break end
	end
	local p = escolhido

	if p.Item then
		local item = EconomyData.Items[p.Item]
		if item then
			PlayerData.AddItem(player, p.Item, 1)
			return { Item = p.Item }, item.Name:upper(), item.Stat == "Coins" and "💰" or "⚡"
		end
	elseif p.Cosmetic then
		-- sorteia um acessorio que o jogador ainda nao tem
		local livres = {}
		for _, id in ipairs(p.Cosmetic) do
			if EconomyData.Items[id] and (data.Items[id] or 0) < 1 then table.insert(livres, id) end
		end
		if #livres > 0 then
			local id = livres[math.random(1, #livres)]
			PlayerData.AddItem(player, id, 1)
			local simbolo = ({ Cabeca = "🥷", Pescoco = "🧣", Aura = "✨", Rastro = "💨" })[EconomyData.Items[id].Slot] or "🎁"
			return { Item = id }, EconomyData.Items[id].Name:upper(), simbolo
		end
		return entregarDinheiro(player, p.Fallback) -- ja tem todos: vira dinheiro
	elseif p.Ficha then
		local n = p.N and math.random(p.N[1], p.N[2]) or 1
		if p.Ficha == "cla" then
			data.Cla.Giros = (tonumber(data.Cla.Giros) or 0) + n
			return { Ficha = "cla", N = n }, "+" .. n .. " CLAN SPIN", "🌀"
		end
		local nat = NatureData.Garantir(data)
		nat.Fichas += n
		local av = ServerStorage:FindFirstChild("AtualizarNatureza")
		if av then av:Fire(player) end
		return { Ficha = "natureza", N = n }, "+" .. n .. " NATURE SPIN", "🍃"
	end
	return entregarDinheiro(player, p.Gems and p or p.Coins and p or { Coins = { 30, 60 } })
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
		local rarityId = CharacterData.Rarities[rarityIndex].Id
		local tabela = CharacterData.CrateRewards[crateId]
		local rw = tabela and tabela[rarityId]
		if not rw or #rw == 0 then
			-- Não deveria acontecer, mas devolve o pagamento por segurança
			refund()
			result = { ok = false, reason = "No reward available." }
			return
		end
		if crate.Pity and rarityIndex >= pityIndex then
			data.Pity = 0
		end

		-- o pergaminho entrega um premio variado (moedas, gemas, boosts, acessorios ou fichas de re-giro)
		local okPremio, reward, nome, simbolo = pcall(sortearPremio, player, data, rw)
		if not okPremio then
			warn("[CrateServer] Erro ao sortear o premio: " .. tostring(reward))
			refund()
			result = { ok = false, reason = "No reward available." }
			return
		end
		result = {
			ok = true,
			name = nome,
			symbol = simbolo,
			rarity = rarityId,
			reward = reward,
			isNew = false,
			copies = 0,
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

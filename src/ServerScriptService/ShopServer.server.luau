-- Script: ServerScriptService > ShopServer
-- Loja: pacotes de Gemas do Rikudou comprados com Robux (Developer Products)
-- e personagens fortes comprados com gemas.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CharacterData = require(ReplicatedStorage:WaitForChild("CharacterData"))
local EconomyData = require(ReplicatedStorage:WaitForChild("EconomyData"))
local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))

local buyWithGems = Instance.new("RemoteFunction")
buyWithGems.Name = "BuyWithGems"
buyWithGems.Parent = ReplicatedStorage

local purchaseDone = Instance.new("RemoteEvent")
purchaseDone.Name = "PurchaseDone"
purchaseDone.Parent = ReplicatedStorage

local MAX_RECEIPTS = 200

local function trimReceipts(data)
	local list = {}
	for id, t in pairs(data.Purchases) do
		table.insert(list, { id = id, t = t })
	end
	if #list <= MAX_RECEIPTS then
		return
	end
	table.sort(list, function(a, b) return a.t < b.t end)
	for i = 1, #list - MAX_RECEIPTS do
		data.Purchases[list[i].id] = nil
	end
end

-- Chamado pelo Roblox sempre que uma compra com Robux precisa ser entregue.
-- Só responde "entregue" depois de salvar, para o jogador nunca perder o que pagou.
MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data
	for _ = 1, 40 do
		data = PlayerData.Get(player)
		if data then break end
		task.wait(0.25)
	end
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local pack = EconomyData.GetPack(info.ProductId)
	if not pack then
		warn("[ShopServer] Produto desconhecido: " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receipt = tostring(info.PurchaseId)
	if data.Purchases[receipt] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- já entregue antes
	end

	data.Purchases[receipt] = os.time()
	PlayerData.AddGems(player, pack.Gems)
	trimReceipts(data)

	if PlayerData.CanSave(player) and not PlayerData.Save(player, true) then
		-- não conseguiu salvar: desfaz e o Roblox tenta de novo depois
		data.Purchases[receipt] = nil
		data.Gems -= pack.Gems
		PlayerData.Refresh(player)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	purchaseDone:FireClient(player, { gems = pack.Gems })
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

buyWithGems.OnServerInvoke = function(player, characterId)
	local entry = type(characterId) == "string" and EconomyData.GetShopEntry(characterId)
	local character = entry and CharacterData.GetCharacter(characterId)
	if not character then
		return { ok = false, reason = "This item is not for sale." }
	end
	if not PlayerData.Get(player) then
		return { ok = false, reason = "Your data is still loading." }
	end
	if not PlayerData.SpendGems(player, entry.Price) then
		return { ok = false, reason = "Not enough Rikudou Gems." }
	end
	local isNew, copies = PlayerData.GiveCharacter(player, characterId)
	return { ok = true, id = characterId, name = character.Name, rarity = character.Rarity, isNew = isNew, copies = copies }
end

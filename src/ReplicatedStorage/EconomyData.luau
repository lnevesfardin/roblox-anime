-- ModuleScript: ReplicatedStorage > EconomyData
-- Economia do jogo: Gemas do Rikudou (moeda premium), pacotes em Robux,
-- loja de gemas, Battle Pass, itens (boosts e acessórios) e moedas por repetido.
-- Para mudar um valor, mude aqui: servidor e telas leem deste arquivo.

local EconomyData = {}

---------------------------------------------------------------
-- Gemas do Rikudou: só se ganham comprando com Robux ou no Battle Pass
---------------------------------------------------------------
EconomyData.Gems = {
	Name = "Rikudou Gems",
	-- Quando o ícone for enviado ao Roblox (Creator Hub > Decals), cole a ID aqui,
	-- ex.: "rbxassetid://123456". Enquanto estiver vazio, o HUD desenha o ícone por código.
	IconId = "",
}

-- Pacotes vendidos com Robux. ProductId = ID do Developer Product criado no Creator Hub.
EconomyData.GemPacks = {
	{ Id = "gems_100", Gems = 100, Robux = 80, ProductId = 0 },
	{ Id = "gems_550", Gems = 550, Robux = 400, ProductId = 0 },
	{ Id = "gems_1200", Gems = 1200, Robux = 800, ProductId = 0 },
}

-- Personagens fortes à venda por gemas
EconomyData.GemShop = {
	{ Character = "kenji_arashi", Price = 250 }, -- Karutto (Épico)
}

---------------------------------------------------------------
-- Moedas recebidas por cada cópia repetida excluída.
-- Média por caixa ≈ 50 moedas (metade do preço), para nunca valer mais que jogar.
---------------------------------------------------------------
EconomyData.DupeCoins = {
	Comum = 15,
	Raro = 35,
	Epico = 100,
	Lendario = 300,
	Mistico = 1000,
}

---------------------------------------------------------------
-- Itens. Boost = usa e some (dura X minutos). Cosmetic = acessório permanente.
-- Slot do acessório: Cabeca, Pescoco, Aura, Rastro (um por slot).
---------------------------------------------------------------
EconomyData.Items = {
	caixa_gratis = { Name = "Free Basic Crate", Type = "Crate", Crate = "Basica" },

	boost_xp_15 = { Name = "2x XP (15 min)", Type = "Boost", Stat = "XP", Minutes = 15 },
	boost_xp_30 = { Name = "2x XP (30 min)", Type = "Boost", Stat = "XP", Minutes = 30 },
	boost_coins_15 = { Name = "2x Coins (15 min)", Type = "Boost", Stat = "Coins", Minutes = 15 },
	boost_coins_30 = { Name = "2x Coins (30 min)", Type = "Boost", Stat = "Coins", Minutes = 30 },

	bandana_vermelha = { Name = "Red Headband", Type = "Cosmetic", Slot = "Cabeca", Color = Color3.fromRGB(190, 40, 40) },
	cachecol_shinobi = { Name = "Shinobi Scarf", Type = "Cosmetic", Slot = "Pescoco", Color = Color3.fromRGB(230, 200, 60) },
	aura_azul = { Name = "Blue Chakra Aura", Type = "Cosmetic", Slot = "Aura", Color = Color3.fromRGB(70, 160, 255) },
	rastro_fogo = { Name = "Fire Trail", Type = "Cosmetic", Slot = "Rastro", Color = Color3.fromRGB(255, 120, 30) },
	aura_dourada = { Name = "Golden Rikudou Aura", Type = "Cosmetic", Slot = "Aura", Color = Color3.fromRGB(255, 200, 60) },
}

---------------------------------------------------------------
-- Battle Pass: 50 níveis, 400 XP por nível. O XP do Passe sobe junto com o XP das partidas.
-- Tipos de recompensa: Coins, Gems, Crates (caixas básicas grátis), Character, Item.
---------------------------------------------------------------
EconomyData.BattlePass = {
	MaxLevel = 50,
	XPPerLevel = 400,
	Rewards = {},
}

do
	local R = EconomyData.BattlePass.Rewards
	for lv = 1, 50 do
		local coins
		if lv <= 9 then
			coins = 50
		elseif lv <= 19 then
			coins = 75
		elseif lv <= 29 then
			coins = 100
		elseif lv <= 39 then
			coins = 125
		else
			coins = 150
		end
		R[lv] = { Coins = coins }
	end
	R[5] = { Crates = 1 }
	R[10] = { Gems = 100 }
	R[12] = { Item = "boost_xp_15" }
	R[15] = { Crates = 1 }
	R[17] = { Item = "bandana_vermelha" }
	R[20] = { Crates = 2 }
	R[22] = { Item = "boost_coins_15" }
	R[25] = { Gems = 150 }
	R[27] = { Item = "aura_azul" }
	R[30] = { Crates = 2 }
	R[32] = { Item = "boost_xp_30" }
	R[35] = { Crates = 2 }
	R[37] = { Item = "cachecol_shinobi" }
	R[40] = { Crates = 3 }
	R[42] = { Item = "boost_coins_30" }
	R[45] = { Crates = 3 }
	R[47] = { Item = "rastro_fogo" }
	-- Nível 50: o personagem exclusivo (Madera) entra aqui quando for criado
	R[50] = { Coins = 1000, Crates = 5, Gems = 300, Item = "aura_dourada" }
end

function EconomyData.GetPack(productId)
	for _, p in ipairs(EconomyData.GemPacks) do
		if p.ProductId == productId and productId ~= 0 then
			return p
		end
	end
	return nil
end

function EconomyData.GetShopEntry(characterId)
	for _, s in ipairs(EconomyData.GemShop) do
		if s.Character == characterId then
			return s
		end
	end
	return nil
end

return EconomyData

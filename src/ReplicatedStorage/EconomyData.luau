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

	-- vendidos pelo Konohamaru (moedas)
	bandana_azul = { Name = "Blue Headband", Type = "Cosmetic", Slot = "Cabeca", Color = Color3.fromRGB(40, 90, 200) },
	bandana_preta = { Name = "Black Headband", Type = "Cosmetic", Slot = "Cabeca", Color = Color3.fromRGB(35, 35, 40) },
	cachecol_vermelho = { Name = "Red Scarf", Type = "Cosmetic", Slot = "Pescoco", Color = Color3.fromRGB(180, 35, 35) },
	cachecol_verde = { Name = "Green Scarf", Type = "Cosmetic", Slot = "Pescoco", Color = Color3.fromRGB(60, 140, 70) },
	aura_roxa = { Name = "Purple Chakra Aura", Type = "Cosmetic", Slot = "Aura", Color = Color3.fromRGB(150, 80, 230) },
	rastro_raio = { Name = "Lightning Trail", Type = "Cosmetic", Slot = "Rastro", Color = Color3.fromRGB(120, 220, 255) },
}

-- Loja de personalização do Konohamaru: itens e preço em moedas
EconomyData.LojaKonohamaru = {
	{ Id = "bandana_azul", Preco = 250 },
	{ Id = "bandana_vermelha", Preco = 250 },
	{ Id = "bandana_preta", Preco = 400 },
	{ Id = "cachecol_shinobi", Preco = 350 },
	{ Id = "cachecol_vermelho", Preco = 350 },
	{ Id = "cachecol_verde", Preco = 350 },
	{ Id = "rastro_fogo", Preco = 900 },
	{ Id = "rastro_raio", Preco = 1100 },
	{ Id = "aura_azul", Preco = 1200 },
	{ Id = "aura_roxa", Preco = 1500 },
}

---------------------------------------------------------------
-- Battle Pass: 50 níveis, 1200 XP por nível na trilha grátis e uma trilha Premium (gamepass). O XP do Passe sobe junto com o XP do jogador.
-- Tipos de recompensa: Coins, Gems, Crates (caixas básicas grátis), Character, Item.
---------------------------------------------------------------
EconomyData.BattlePass = {
	MaxLevel = 50,
	XPPerLevel = 1200,
	PremiumPassId = 0, -- ID do gamepass "Passe Premium": crie no Creator Dashboard e cole aqui (0 = ainda nao vendido; no Studio a trilha Premium abre para teste)
	Rewards = {},
	PremiumRewards = {},
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

-- Trilha Premium: o dobro de moedas em todo nivel, gemas e caixas a cada 5 niveis e acessorios exclusivos
do
	local P = EconomyData.BattlePass.PremiumRewards
	local extras = { [3] = "boost_xp_15", [8] = "rastro_raio", [13] = "boost_coins_15", [18] = "cachecol_verde", [23] = "rastro_fogo",
		[28] = "boost_xp_30", [33] = "aura_roxa", [38] = "boost_coins_30", [43] = "boost_xp_30" }
	for lv = 1, 50 do
		local base = lv <= 9 and 50 or lv <= 19 and 75 or lv <= 29 and 100 or lv <= 39 and 125 or 150
		local p = { Coins = base * 2 }
		if lv % 5 == 0 and lv < 50 then
			p.Gems = 50
			p.Crates = lv % 10 == 0 and 2 or 1
		end
		if extras[lv] then p.Item = extras[lv] end
		P[lv] = p
	end
	P[50] = { Coins = 2500, Gems = 500, Crates = 5 }
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

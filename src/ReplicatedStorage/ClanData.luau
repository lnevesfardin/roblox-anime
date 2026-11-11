-- ModuleScript: ReplicatedStorage > ClanData
-- Clãs do jogo: raridade, chance na roleta, símbolo e traço inicial.
-- O jogador não escolhe o clã: ele nasce por roleta (3 giros grátis) e pode girar de novo com gemas.

local ClanData = {}

ClanData.RESPIN_GEMS = 50      -- preço de um giro extra
ClanData.FREE_SPINS = 3        -- giros grátis ao nascer
ClanData.PITY_RARE = 10        -- raro ou melhor garantido em até 10 giros
ClanData.PITY_LEGENDARY = 100  -- lendário garantido em até 100 giros
ClanData.HEIGHT_MIN = 0.9      -- estatura: limites e passo dos botões - e +
ClanData.HEIGHT_MAX = 1.1
ClanData.HEIGHT_STEP = 0.02

ClanData.Rarities = {
	Common = { Order = 1, Name = "Common", Color = Color3.fromRGB(170, 176, 186) },
	Rare = { Order = 2, Name = "Rare", Color = Color3.fromRGB(80, 160, 255) },
	Epic = { Order = 3, Name = "Epic", Color = Color3.fromRGB(180, 100, 255) },
	Legendary = { Order = 4, Name = "Legendary", Color = Color3.fromRGB(255, 190, 60) },
}

-- Weight = chance em % (a soma dá 100). Symbol é provisório até existirem imagens próprias.
ClanData.Clans = {
	Uzu = { Name = "Uzu", Rarity = "Legendary", Weight = 1, Symbol = "🌊", Color = Color3.fromRGB(230, 90, 60), Trait = "+30% max chakra" },
	Uchiwa = { Name = "Uchiwa", Rarity = "Legendary", Weight = 1, Symbol = "🔥", Color = Color3.fromRGB(210, 40, 50), Trait = "Red eyes that awaken in battle" },
	Mokuton = { Name = "Mokuton", Rarity = "Legendary", Weight = 1, Symbol = "🌳", Color = Color3.fromRGB(90, 170, 80), Trait = "Slowly regenerates health" },
	Byakugan = { Name = "Byakugan", Rarity = "Epic", Weight = 7, Symbol = "👁", Color = Color3.fromRGB(200, 190, 240), Trait = "Sees enemies from afar and through walls" },
	Lee = { Name = "Lee", Rarity = "Rare", Weight = 15, Symbol = "🥋", Color = Color3.fromRGB(70, 180, 110), Trait = "Fighting styles cost 20% less energy" },
	Shirokiba = { Name = "Shirokiba", Rarity = "Rare", Weight = 15, Symbol = "⚡", Color = Color3.fromRGB(225, 230, 240), Trait = "White hair and faster running" },
	Enma = { Name = "Enma", Rarity = "Common", Weight = 30, Symbol = "🐒", Color = Color3.fromRGB(200, 150, 80), Trait = "Clan path starts early (2nd power at level 3)" },
	Inu = { Name = "Inu", Rarity = "Common", Weight = 30, Symbol = "🐕", Color = Color3.fromRGB(190, 120, 80), Trait = "A dog companion follows you" },
}

-- Kit de poderes provisório de cada clã (até a Fase 4 trazer o caminho de poderes de cada um).
-- Os ids são os kits que já existem no AbilityServer.
ClanData.Kit = {
	Uzu = "kenji_arashi", Enma = "kenji_arashi", Inu = "kenji_arashi", Lee = "kenji_arashi",
	Uchiwa = "ren_kuroba",
	Shirokiba = "hana_midori", Mokuton = "hana_midori", Byakugan = "hana_midori",
}

ClanData.Order = { "Uzu", "Uchiwa", "Mokuton", "Byakugan", "Lee", "Shirokiba", "Enma", "Inu" }

function ClanData.RarityOrder(clanId)
	local c = ClanData.Clans[clanId]
	return c and ClanData.Rarities[c.Rarity].Order or 0
end

-- Sorteia um clã. minOrder = raridade mínima (1 comum, 2 raro, 4 lendário) usada pelas garantias.
function ClanData.Roll(rng, minOrder)
	minOrder = minOrder or 1
	local total = 0
	for _, id in ipairs(ClanData.Order) do
		if ClanData.RarityOrder(id) >= minOrder then
			total += ClanData.Clans[id].Weight
		end
	end
	local r = rng:NextNumber(0, total)
	local acc = 0
	local ultimo
	for _, id in ipairs(ClanData.Order) do
		if ClanData.RarityOrder(id) >= minOrder then
			acc += ClanData.Clans[id].Weight
			ultimo = id
			if r <= acc then
				return id
			end
		end
	end
	return ultimo
end

return ClanData

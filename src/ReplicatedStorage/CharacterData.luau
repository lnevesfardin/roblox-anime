-- ModuleScript: ReplicatedStorage > CharacterData
-- Aqui ficam TODOS os dados do jogo: raridades, personagens, caixas.
-- Para adicionar um personagem novo, copie uma linha de Characters e mude os valores.

local CharacterData = {}

-- Ordem importa: do mais comum ao mais raro.
-- Weight = chance relativa de sair na caixa. StatMult = multiplicador de força.
CharacterData.Rarities = {
	{ Id = "Comum",    Name = "Common",    Weight = 60, StatMult = 1.0 },
	{ Id = "Raro",     Name = "Rare",     Weight = 25, StatMult = 1.4 },
	{ Id = "Epico",    Name = "Epic",    Weight = 10, StatMult = 2.0 },
	{ Id = "Lendario", Name = "Legendary", Weight = 4,  StatMult = 3.0 },
	{ Id = "Mistico",  Name = "Mythic",  Weight = 1,  StatMult = 4.5 },
}

-- Temas: Ninja, Ceifador, Pirata, Normal (pessoa com manifestação espiritual)
-- Por enquanto só há personagens do tema Ninja (MVP).
-- Health e Damage são valores BASE, antes da raridade e do nível.
CharacterData.Characters = {
	-- Look = descrição visual para você montar o modelo.
	-- Abilities = poderes na ordem Q, E, R (R é o forte). Cooldown em segundos.
	-- O que cada poder faz fica em ServerScriptService > AbilityServer.
	{ Id = "kenji_arashi",  Name = "Karutto",  Theme = "Ninja", Rarity = "Epico",  Health = 100, Damage = 10,
		Ability = "Spiral Orb · Leaf Clones · Storm Shuriken",
		Abilities = {
			{ Name = "Spiral Orb", Cooldown = 6 },        -- esfera de energia azul na mão
			{ Name = "Leaf Clones", Cooldown = 14 },      -- 2 clones lutam por 8s
			{ Name = "Storm Shuriken", Cooldown = 30 },   -- shuriken gigante que explode
		},
		Look = "Energetic young guy, zip-up jacket, baggy pants, leg pouch, headband, spiky hair. Colors: green and white." },
	{ Id = "ren_kuroba",    Name = "Kakuse",    Theme = "Ninja", Rarity = "Raro",  Health = 90,  Damage = 12,
		Ability = "Fireball · Black Flame · Thunder Dragon",
		Abilities = {
			{ Name = "Fireball", Cooldown = 6 },          -- bola de fogo que explode
			{ Name = "Black Flame", Cooldown = 12 },      -- fogo preto queima o alvo por 5s
			{ Name = "Thunder Dragon", Cooldown = 35 },   -- dragão de raios desce do céu
		},
		Look = "Serious young guy, straight dark hair, short-sleeve shirt, shorts, wraps on arms and legs, hands in pockets. Colors: dark gray and cream." },
	{ Id = "hana_midori",   Name = "Tatashi",   Theme = "Ninja", Rarity = "Comum",   Health = 95,  Damage = 14,
		Ability = "Lightning Hand · Water Dragon · Vanish",
		Abilities = {
			{ Name = "Lightning Hand", Cooldown = 7 },    -- relâmpago na mão + investida
			{ Name = "Water Dragon", Cooldown = 12 },     -- dragão de água avança e empurra
			{ Name = "Vanish", Cooldown = 30 },           -- inimigo some 5s e volta com menos vida
		},
		Look = "Confident young fighter, short hair, sleeveless top with shorts, gloves, attack pose. Colors: turquoise and white." },
}

-- Caixas. Currency = "Coins" (moedas do jogo) ou "Gems" (Gemas do Rikudou).
-- Weights opcional: chance de cada raridade só nessa caixa (senão usa a das raridades).
CharacterData.Crates = {
	Basica = { Name = "Basic Crate", Cost = 100, Currency = "Coins", Pity = true },
	Rikudou = {
		Name = "Rikudou Crate", Cost = 50, Currency = "Gems", Pity = false,
		Weights = { Comum = 0, Raro = 50, Epico = 30, Lendario = 15, Mistico = 5 },
	},
}

-- O que cada caixa entrega por raridade: moedas ou gemas (mínimo, máximo). As caixas não dão mais personagens.
CharacterData.CrateRewards = {
	Basica = {
		Comum = { Coins = { 30, 60 } }, Raro = { Coins = { 80, 100 } }, Epico = { Coins = { 200, 240 } },
		Lendario = { Gems = { 8, 8 } }, Mistico = { Gems = { 25, 25 } },
	},
	Rikudou = {
		Raro = { Coins = { 1500, 1500 } }, Epico = { Coins = { 4000, 4000 } },
		Lendario = { Gems = { 80, 80 } }, Mistico = { Gems = { 250, 250 } },
	},
}

-- Garantia: depois de PityLimit aberturas sem Épico ou melhor, a próxima vem Épico ou melhor.
CharacterData.PityLimit = 20
CharacterData.PityMinRarity = "Epico"

CharacterData.MaxLevel = 100
CharacterData.StartingCoins = 500

---------------------------------------------------------------
-- Funções de ajuda
---------------------------------------------------------------

function CharacterData.GetRarityIndex(rarityId)
	for i, r in ipairs(CharacterData.Rarities) do
		if r.Id == rarityId then
			return i
		end
	end
	return nil
end

function CharacterData.GetCharacter(id)
	for _, c in ipairs(CharacterData.Characters) do
		if c.Id == id then
			return c
		end
	end
	return nil
end

-- Peso de uma raridade numa caixa
function CharacterData.GetWeight(crateId, rarityIndex)
	local crate = CharacterData.Crates[crateId]
	local r = CharacterData.Rarities[rarityIndex]
	if crate and crate.Weights and crate.Weights[r.Id] ~= nil then
		return crate.Weights[r.Id]
	end
	return r.Weight
end

function CharacterData.HasRarity(rarityId)
	for _, c in ipairs(CharacterData.Characters) do
		if c.Rarity == rarityId then
			return true
		end
	end
	return false
end

-- Chances REAIS que aparecem para o jogador (em %). Se uma raridade ainda não tem
-- personagem, a chance dela passa para a raridade abaixo que tem, igual ao sorteio do servidor.
function CharacterData.GetCrateOdds(crateId)
	local n = #CharacterData.Rarities
	local w = {}
	local total = 0
	for i = 1, n do
		w[i] = CharacterData.GetWeight(crateId, i)
		total += w[i]
	end
	local eff = table.create(n, 0)
	for i = n, 1, -1 do
		eff[i] += w[i] -- toda raridade tem recompensa (CrateRewards), então a chance mostrada é a do sorteio
	end
	local out = {}
	for i = 1, n do
		out[i] = { Id = CharacterData.Rarities[i].Id, Name = CharacterData.Rarities[i].Name, Percent = total > 0 and eff[i] / total * 100 or 0 }
	end
	return out
end

-- XP necessário para subir do nível informado para o próximo
function CharacterData.XPForLevel(level)
	return math.floor(160 * level ^ 1.6) -- (era 80: evolução 2x mais lenta)
end

-- Vida e dano finais de um personagem para um dado nível do jogador
function CharacterData.GetStats(characterId, level)
	local c = CharacterData.GetCharacter(characterId)
	if not c then
		return nil
	end
	local rarity = CharacterData.Rarities[CharacterData.GetRarityIndex(c.Rarity)]
	local levelMult = 1 + 0.05 * (level - 1)
	return {
		Health = math.floor(c.Health * rarity.StatMult * levelMult),
		Damage = math.floor(c.Damage * rarity.StatMult * levelMult),
	}
end

return CharacterData

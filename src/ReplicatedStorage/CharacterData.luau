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
	-- Look = descrição visual para você montar o modelo. Ability = "TBD" até você me dizer.
	{ Id = "kenji_arashi",  Name = "Karutto",  Theme = "Ninja", Rarity = "Epico",  Health = 100, Damage = 10, Ability = "TBD",
		Look = "Energetic young guy, zip-up jacket, baggy pants, leg pouch, headband, spiky hair. Colors: green and white." },
	{ Id = "ren_kuroba",    Name = "Kakuse",    Theme = "Ninja", Rarity = "Raro",  Health = 90,  Damage = 12, Ability = "TBD",
		Look = "Serious young guy, straight dark hair, short-sleeve shirt, shorts, wraps on arms and legs, hands in pockets. Colors: dark gray and cream." },
	{ Id = "hana_midori",   Name = "Tatashi",   Theme = "Ninja", Rarity = "Comum",   Health = 95,  Damage = 14, Ability = "TBD",
		Look = "Confident young fighter, short hair, sleeveless top with shorts, gloves, attack pose. Colors: turquoise and white." },
}

-- Caixas. Cost em moedas do jogo. Depois você pode criar caixas pagas com Robux.
CharacterData.Crates = {
	Basica = { Name = "Basic Crate", Cost = 100 },
}

-- Garantia: depois de PityLimit aberturas sem Épico ou melhor, a próxima vem Épico ou melhor.
CharacterData.PityLimit = 20
CharacterData.PityMinRarity = "Epico"

CharacterData.MaxLevel = 60
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

-- XP necessário para subir do nível informado para o próximo
function CharacterData.XPForLevel(level)
	return math.floor(100 * level ^ 1.5)
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

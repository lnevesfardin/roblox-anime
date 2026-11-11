-- ModuleScript: ReplicatedStorage > AttributeData
-- Os 5 atributos do jogador, as fórmulas e os limites.
-- Pontos: 3 por nível. Teto de cada atributo: 10 + 2 x nível. Treino na Academia: até 5 pontos extras por dia.

local AttributeData = {}

AttributeData.POINTS_PER_LEVEL = 3
AttributeData.TRAIN_PER_DAY = 5
AttributeData.TRAIN_COST = 50 -- moedas por sessão de treino

AttributeData.List = {
	{ Id = "Forca", Name = "Strength", Desc = "Punch and kick damage" },
	{ Id = "Ninjutsu", Name = "Ninjutsu", Desc = "Power damage" },
	{ Id = "Chakra", Name = "Chakra", Desc = "Chakra reserve" },
	{ Id = "Vigor", Name = "Vitality", Desc = "Max health" },
	{ Id = "Agilidade", Name = "Agility", Desc = "Movement speed" },
}

function AttributeData.Get(id)
	for _, a in ipairs(AttributeData.List) do
		if a.Id == id then
			return a
		end
	end
	return nil
end

function AttributeData.Cap(level)
	return 10 + 2 * level
end
function AttributeData.Health(vigor)
	return 100 + 12 * vigor
end
function AttributeData.MeleeMult(forca)
	return 1 + 0.02 * forca
end
function AttributeData.PowerMult(ninjutsu)
	return 1 + 0.02 * ninjutsu
end
function AttributeData.Chakra(chakra)
	return 100 + 10 * chakra
end
function AttributeData.Speed(agilidade) -- studs/s a mais (máximo +8)
	return math.min(8, 0.08 * agilidade)
end

return AttributeData

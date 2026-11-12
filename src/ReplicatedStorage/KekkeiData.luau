-- ModuleScript: ReplicatedStorage > KekkeiData
-- Kekkei Genkai (linhagem). No primeiro acesso, antes da roleta do clã, o jogador tem UM único giro
-- (não dá para girar de novo, nem com gemas). A maioria nasce sem nenhuma.
-- Quem nasce com uma ganha um passivo pequeno e um poder extra na tecla V (libera no nível 5).
-- Passivos (onde estão no código):
--   Gelo / Lava -> CombatServer (socos deixam lento / queimam)
--   Fervura     -> AbilityServer (chakra volta mais rápido)
--   Tempestade  -> KekkeiServer (atributo BonusVelKekkei, lido pelo Corrida)
--   Explosao / Osso / Calor / Poeira -> PlayerData.GetCombatStats (dano / vida)

local KekkeiData = {}

KekkeiData.CHANCE_NADA = 70 -- % de nascer sem kekkei genkai
KekkeiData.NIVEL_PODER = 5   -- nível mínimo da missão que ensina o poder da tecla V
KekkeiData.MISSAO = "KG_Despertar" -- missão da Lady Tsuna que ensina o poder (nada destrava sozinho)
KekkeiData.TECLA = "V"

KekkeiData.Order = { "Gelo", "Lava", "Fervura", "Tempestade", "Explosao", "Osso", "Calor", "Poeira" }

-- Weight = chance em % (somando com CHANCE_NADA dá 100)
KekkeiData.Tipos = {
	Gelo = { Name = "Ice Release", Weight = 6, Rarity = "Epic", Color = Color3.fromRGB(150, 220, 255),
		Passivo = "Your punches slow enemies down",
		Poder = { Id = "kg_gelo", Name = "Ice Spears", Cooldown = 12, Chakra = 30, Desc = "Ice spears burst from the ground and freeze enemies in place." } },
	Lava = { Name = "Lava Release", Weight = 5, Rarity = "Epic", Color = Color3.fromRGB(255, 110, 40),
		Passivo = "Your punches burn enemies",
		Poder = { Id = "kg_lava", Name = "Lava Globs", Cooldown = 12, Chakra = 30, Desc = "Spit globs of lava that explode and keep burning." } },
	Fervura = { Name = "Boil Release", Weight = 5, Rarity = "Epic", Color = Color3.fromRGB(240, 240, 220),
		Passivo = "Chakra recovers 50% faster",
		Poder = { Id = "kg_fervura", Name = "Scalding Mist", Cooldown = 14, Chakra = 30, Desc = "A cloud of boiling mist burns everyone around you." } },
	Tempestade = { Name = "Storm Release", Weight = 4, Rarity = "Legendary", Color = Color3.fromRGB(120, 200, 255),
		Passivo = "+2 movement speed",
		Poder = { Id = "kg_tempestade", Name = "Laser Circus", Cooldown = 14, Chakra = 35, Desc = "Beams of storm lightning strike up to 6 enemies." } },
	Explosao = { Name = "Explosion Release", Weight = 4, Rarity = "Legendary", Color = Color3.fromRGB(255, 230, 160),
		Passivo = "+10% power damage",
		Poder = { Id = "kg_explosao", Name = "Clay Bombs", Cooldown = 14, Chakra = 35, Desc = "Clay bombs fly to nearby enemies and explode." } },
	Osso = { Name = "Bone Release", Weight = 3, Rarity = "Legendary", Color = Color3.fromRGB(235, 230, 215),
		Passivo = "+20% max health",
		Poder = { Id = "kg_osso", Name = "Bone Spikes", Cooldown = 13, Chakra = 30, Desc = "A ring of bone spikes erupts around you." } },
	Calor = { Name = "Scorch Release", Weight = 2, Rarity = "Legendary", Color = Color3.fromRGB(255, 150, 60),
		Passivo = "+10% punch damage",
		Poder = { Id = "kg_calor", Name = "Scorching Orbs", Cooldown = 16, Chakra = 35, Desc = "Burning orbs spin around you and scorch anyone close." } },
	Poeira = { Name = "Dust Release", Weight = 1, Rarity = "Mythic", Color = Color3.fromRGB(255, 255, 255),
		Passivo = "+15% power damage",
		Poder = { Id = "kg_poeira", Name = "Atomic Cube", Cooldown = 25, Chakra = 60, Desc = "A cube of dust erases everything inside it." } },
}

KekkeiData.Rarities = {
	Epic = Color3.fromRGB(180, 100, 255),
	Legendary = Color3.fromRGB(255, 190, 60),
	Mythic = Color3.fromRGB(255, 80, 120),
}

-- sorteio: devolve o id ou false (nasceu sem)
function KekkeiData.Roll(rng)
	local r = rng:NextNumber(0, 100)
	if r < KekkeiData.CHANCE_NADA then
		return false
	end
	local acc = KekkeiData.CHANCE_NADA
	for _, id in ipairs(KekkeiData.Order) do
		acc += KekkeiData.Tipos[id].Weight
		if r < acc then
			return id
		end
	end
	return KekkeiData.Order[1]
end

-- id da kekkei genkai do jogador no save (ou nil)
function KekkeiData.DoSave(data)
	local k = data and data.Kekkei
	if type(k) == "table" and type(k.Id) == "string" and KekkeiData.Tipos[k.Id] then
		return k.Id
	end
	return nil
end

return KekkeiData

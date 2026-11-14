-- ModuleScript: ReplicatedStorage > NatureData
-- Naturezas de chakra. No nascimento a roleta sorteia de 1 a 3 naturezas; a 4a e a 5a so chegam por missoes raras.
-- Cada natureza tem 4 ETAPAS de jutsus e, em cada etapa, 2 opcoes: o jogador ESCOLHE 1 das 2 (a outra fica de fora).
-- Nenhum vem de graca: o mestre da natureza libera a escolha por missao (MissionData, ids N1_..N4_<Natureza>).
-- O jogador equipa ate 4 jutsus nas teclas G, H, J e K.
-- Afinidade: a roleta tambem sorteia a natureza principal do jogador (a 1a da lista). Os jutsus dela
-- dao mais dano (AFIN_DANO) e gastam menos chakra (AFIN_CHAKRA).
-- Save: data.Natureza = { Rolou = bool, Afinidade = id, Lista = { ids }, Jutsus = { [id] = true }, Equip = { 4 x (id ou false) },
--   Pendente = { { Natureza = id, Tier = n }, ... } escolhas liberadas por missao e ainda nao feitas }

local NatureData = {}

NatureData.MAX = 5
NatureData.KEYS = { "G", "H", "J", "K" } -- F ja e o soco
NatureData.SLOTS = #NatureData.KEYS
NatureData.CUSTO_REGIRAR = 50 -- gemas para girar de novo as naturezas do nascimento
NatureData.AFIN_DANO = 1.25   -- multiplicador de dano dos jutsus da natureza de afinidade
NatureData.AFIN_CHAKRA = 0.8  -- multiplicador do custo de chakra desses jutsus
-- etapas: nivel minimo e rank minimo da missao de cada uma
NatureData.TIERS = {
	{ Nivel = 0, Rank = "Genin", Pratica = 3 },
	{ Nivel = 18, Rank = "Genin", Pratica = 6 },
	{ Nivel = 35, Rank = "Chunin", Pratica = 9 },
	{ Nivel = 50, Rank = "Jonin", Pratica = 12 },
}

NatureData.Order = { "Fogo", "Vento", "Raio", "Terra", "Agua" }

-- quantas naturezas nascem com o jogador (pesos em %)
NatureData.Quantidade = { { N = 1, Weight = 60 }, { N = 2, Weight = 30 }, { N = 3, Weight = 10 } }

-- Jutsu: J(id, nome, recarga, chakra, descricao, resumo do dano, efeito)
-- Efeito (Ef) = usado pelo AbilityServer para os jutsus novos (os 10 originais tem codigo proprio, Ef = nil):
--   t = "proj"   n, spread, speed, range, hit, blast, size, mult, force, burn, burnT, stun
--   t = "area"   r, mult, force, burn, burnT, stun
--   t = "cone"   range, deg (metade), mult, force, burn, burnT, stun
--   t = "line"   len, width, mult, force, burn, burnT, stun
--   t = "target" range, count, mult, burn, burnT, stun, col
--   t = "rain"   ahead, r, n, delay, blast, mult, force, burn, burnT, stun
--   cor = cor propria (senao a cor da natureza). stun = segura o inimigo parado por N segundos.
local function J(id, nome, cd, chakra, desc, info, ef)
	return { Id = id, Name = nome, Cooldown = cd, Chakra = chakra, Desc = desc, Info = info, Ef = ef }
end

-- Mestre = nome do modelo do NPC (chave de MissionData.NPCs)
NatureData.Tipos = {
	Fogo = { Name = "Fire", Color = Color3.fromRGB(255, 110, 50), Mestre = "Sasuke", Tiers = {
		{ J("nat_fogo1", "Phoenix Flames", 7, 18, "Three small fireballs fly forward and burn on hit.", "3 x 1.3 dmg + burn"),
		  J("nat_fogo1b", "Fireball", 8, 20, "One huge fireball that explodes and burns everything near.", "2.4 dmg, big blast + burn",
			{ t = "proj", n = 1, size = 3.6, speed = 60, range = 50, blast = 8, mult = 2.4, burn = 0.2, burnT = 3, force = 20 }) },
		{ J("nat_fogo2", "Dragon Flame", 16, 38, "A stream of fire scorches everything in a long line.", "3.2 dmg in a line + burn"),
		  J("nat_fogo2b", "Flame Barrier", 14, 34, "Fire erupts all around you, burning everything close.", "2.8 dmg around you + burn",
			{ t = "area", r = 14, mult = 2.8, force = 25, burn = 0.35, burnT = 4 }) },
		{ J("nat_fogo3a", "Great Fire Annihilation", 22, 55, "A wall of flames sweeps a wide cone in front of you.", "4.8 dmg in a cone + strong burn",
			{ t = "cone", range = 40, deg = 35, mult = 4.8, force = 30, burn = 0.4, burnT = 5 }),
		  J("nat_fogo3b", "Ash Pile Burner", 24, 58, "A slow giant fireball with a massive explosion.", "5.2 dmg, huge blast + burn",
			{ t = "proj", n = 1, size = 5, speed = 50, range = 60, blast = 13, mult = 5.2, burn = 0.5, burnT = 4, force = 35 }) },
		{ J("nat_fogo4a", "Meteor Rain", 40, 85, "Flaming meteors crash down in the area ahead of you.", "8 strikes x 2.6 dmg + burn",
			{ t = "rain", ahead = 26, r = 22, n = 8, delay = 2.4, blast = 8, mult = 2.6, burn = 0.3, burnT = 3 }),
		  J("nat_fogo4b", "Black Flame", 42, 85, "Black fire that never goes out marks up to 3 enemies.", "4 dmg x3 targets + very strong burn",
			{ t = "target", range = 45, count = 3, mult = 4.0, burn = 1.0, burnT = 8, stun = 1, cor = Color3.fromRGB(45, 30, 60) }) } } },
	Vento = { Name = "Wind", Color = Color3.fromRGB(170, 240, 200), Mestre = "Naruto", Tiers = {
		{ J("nat_vento1", "Gale Palm", 6, 15, "A gust of wind hits enemies in front and throws them back.", "2 dmg + strong knockback"),
		  J("nat_vento1b", "Wind Bullets", 6, 16, "Three fast air bullets that push enemies away.", "3 x 1.1 dmg + knockback",
			{ t = "proj", n = 3, spread = 6, size = 1.4, speed = 110, range = 55, hit = 2, blast = 4, mult = 1.1, force = 30, gap = 0.05 }) },
		{ J("nat_vento2", "Vacuum Blades", 15, 36, "Blades of wind slice through enemies all around you.", "3.4 dmg around you"),
		  J("nat_vento2b", "Cyclone", 14, 34, "A cyclone blasts everything around you and holds it for a moment.", "2.4 dmg around you + hold 1.2s",
			{ t = "area", r = 18, mult = 2.4, force = 70, stun = 1.2 }) },
		{ J("nat_vento3a", "Great Breakthrough", 22, 52, "A giant gale tears through a wide cone.", "4.6 dmg in a cone + huge knockback",
			{ t = "cone", range = 45, deg = 40, mult = 4.6, force = 90 }),
		  J("nat_vento3b", "Rasengan", 22, 55, "A spinning sphere of compressed wind chakra that bursts on impact.", "4.8 dmg, big blast + knockback",
			{ t = "proj", n = 1, size = 3, speed = 90, range = 60, blast = 10, mult = 4.8, force = 50 }) },
		{ J("nat_vento4a", "Typhoon Wall", 40, 85, "A towering wall of wind races forward and crushes everything.", "7 dmg in a wide line + huge knockback",
			{ t = "line", len = 55, width = 16, mult = 7, force = 80 }),
		  J("nat_vento4b", "Storm Spiral", 44, 90, "A huge storm explodes around you and traps enemies.", "7.5 dmg around you + hold 2s",
			{ t = "area", r = 26, mult = 7.5, force = 60, stun = 2 }) } } },
	Raio = { Name = "Lightning", Color = Color3.fromRGB(150, 210, 255), Mestre = "Kakashi", Tiers = {
		{ J("nat_raio1", "Lightning Bolt", 7, 18, "A bolt strikes the nearest enemy and stuns it.", "2.6 dmg + stun"),
		  J("nat_raio1b", "Static Needles", 6, 16, "Five electric needles shoot forward in a fan.", "5 x 0.9 dmg",
			{ t = "proj", n = 5, spread = 5, size = 0.9, speed = 140, range = 50, hit = 1.8, blast = 3, mult = 0.9, gap = 0.04 }) },
		{ J("nat_raio2", "Thunder Chain", 16, 38, "Lightning jumps between up to 5 enemies.", "2.2 dmg x up to 5 enemies"),
		  J("nat_raio2b", "Thunder Clap", 15, 36, "A thunderclap around you shocks and freezes enemies in place.", "2.6 dmg around you + hold 1.5s",
			{ t = "area", r = 16, mult = 2.6, stun = 1.5 }) },
		{ J("nat_raio3a", "Raikiri", 22, 55, "A blade of lightning in your hand: dash in a straight line, piercing and stunning.", "5 dmg in a line + hold 1.5s",
			{ t = "line", len = 50, width = 8, mult = 5, stun = 1.5 }),
		  J("nat_raio3b", "Storm Cage", 22, 55, "Bolts lock up to 4 enemies in place.", "3.4 dmg x4 targets + hold 2s",
			{ t = "target", range = 40, count = 4, mult = 3.4, stun = 2 }) },
		{ J("nat_raio4a", "Thousand Birds", 40, 85, "A flock of lightning birds covers a huge cone.", "8 dmg in a cone + hold 1s",
			{ t = "cone", range = 40, deg = 30, mult = 8, stun = 1 }),
		  J("nat_raio4b", "Heavenly Judgment", 42, 88, "Lightning falls from the sky over the area ahead.", "7 strikes x 3 dmg + hold",
			{ t = "rain", ahead = 20, r = 18, n = 7, delay = 2, blast = 7, mult = 3, stun = 0.8 }) } } },
	Terra = { Name = "Earth", Color = Color3.fromRGB(180, 140, 90), Mestre = "Tsunade", Tiers = {
		{ J("nat_terra1", "Rock Pillars", 8, 18, "Stone pillars rise in front of you and launch enemies.", "2.4 dmg + launch"),
		  J("nat_terra1b", "Stone Fist", 8, 18, "A boulder flies forward and shatters on impact.", "2.6 dmg + knockback",
			{ t = "proj", n = 1, size = 3, speed = 65, range = 45, blast = 6, mult = 2.6, force = 40 }) },
		{ J("nat_terra2", "Earth Quake", 17, 38, "The ground cracks around you, hurting and holding enemies.", "3 dmg around you + hold"),
		  J("nat_terra2b", "Mud Wall Crush", 16, 36, "A rolling wall of mud holds everything in its path.", "3 dmg in a line + hold 2s",
			{ t = "line", len = 30, width = 12, mult = 3, stun = 2 }) },
		{ J("nat_terra3a", "Boulder Storm", 24, 56, "Boulders fall over the area in front of you.", "6 strikes x 2.4 dmg",
			{ t = "rain", ahead = 18, r = 14, n = 6, delay = 1.6, blast = 7, mult = 2.4 }),
		  J("nat_terra3b", "Earth Dragon", 22, 55, "A dragon of rock charges forward and throws enemies.", "5 dmg in a line + knockback",
			{ t = "line", len = 48, width = 9, mult = 5, force = 60 }) },
		{ J("nat_terra4a", "Gaia's Fall", 42, 85, "A huge shower of rocks falls on a wide area.", "9 strikes x 2.6 dmg + knockback",
			{ t = "rain", ahead = 24, r = 20, n = 9, delay = 2.6, blast = 8, mult = 2.6, force = 30 }),
		  J("nat_terra4b", "Golem Smash", 44, 90, "A stone giant smashes the ground and holds everything near.", "8 dmg around you + hold 2.5s",
			{ t = "area", r = 24, mult = 8, force = 50, stun = 2.5 }) } } },
	Agua = { Name = "Water", Color = Color3.fromRGB(70, 150, 255), Mestre = "Kakashi", Tiers = {
		{ J("nat_agua1", "Water Bullet", 6, 16, "A fast ball of water that splashes on hit.", "2.4 dmg + splash"),
		  J("nat_agua1b", "Water Fan", 7, 16, "Three water shots spread out in a fan.", "3 x 1.2 dmg",
			{ t = "proj", n = 3, spread = 12, size = 1.8, speed = 95, range = 45, blast = 4, mult = 1.2, gap = 0.05 }) },
		{ J("nat_agua2", "Great Wave", 16, 38, "A wave rolls forward, dragging enemies with it.", "3.2 dmg in a line + drag"),
		  J("nat_agua2b", "Water Prison", 15, 34, "Spheres of water trap up to 3 enemies.", "2.4 dmg x3 targets + hold 3s",
			{ t = "target", range = 35, count = 3, mult = 2.4, stun = 3 }) },
		{ J("nat_agua3a", "Water Dragon", 22, 55, "A dragon of water charges forward and throws enemies.", "5 dmg in a line + knockback",
			{ t = "line", len = 50, width = 10, mult = 5, force = 55 }),
		  J("nat_agua3b", "Tidal Burst", 22, 52, "A burst of water explodes around you.", "4.6 dmg around you + knockback",
			{ t = "area", r = 20, mult = 4.6, force = 80 }) },
		{ J("nat_agua4a", "Tsunami", 42, 88, "A gigantic wave sweeps across the whole field ahead.", "8 dmg in a huge line + knockback",
			{ t = "line", len = 60, width = 30, mult = 8, force = 90 }),
		  J("nat_agua4b", "Rain of Needles", 40, 85, "A downpour of water needles falls ahead of you.", "12 strikes x 1.9 dmg + hold",
			{ t = "rain", ahead = 22, r = 20, n = 12, delay = 2.5, blast = 5, mult = 1.9, stun = 0.8 }) } } },
}

-- lista plana de jutsus de cada natureza (etapa por etapa, opcao A e depois B) e indice por id
for _, t in pairs(NatureData.Tipos) do
	t.Jutsus = {}
	for tier, par in ipairs(t.Tiers) do
		for opcao, j in ipairs(par) do
			j.Tier = tier
			j.Opcao = opcao
			table.insert(t.Jutsus, j)
		end
	end
end

local porId = {}
for id, t in pairs(NatureData.Tipos) do
	for i, j in ipairs(t.Jutsus) do
		j.Natureza = id
		j.Nivel = j.Tier
		porId[j.Id] = j
	end
end
function NatureData.Jutsu(id)
	return porId[id]
end

-- garante o formato do save (servidor). Devolve data.Natureza
function NatureData.Garantir(data)
	if type(data.Natureza) ~= "table" then
		data.Natureza = { Rolou = false }
	end
	local n = data.Natureza
	if type(n.Lista) ~= "table" then n.Lista = {} end
	if type(n.Jutsus) ~= "table" then n.Jutsus = {} end
	if type(n.Equip) ~= "table" then n.Equip = {} end
	if type(n.Pendente) ~= "table" then n.Pendente = {} end
	n.Fichas = math.max(0, math.floor(tonumber(n.Fichas) or 0)) -- fichas de re-giro (vem do pergaminho)
	for i = 1, #NatureData.KEYS do
		if n.Equip[i] == nil then n.Equip[i] = false end
	end
	if not (type(n.Afinidade) == "string" and table.find(n.Lista, n.Afinidade)) then n.Afinidade = n.Lista[1] or false end
	for i = 1, #NatureData.KEYS do
		local id = n.Equip[i]
		local j = type(id) == "string" and porId[id]
		if not (j and n.Jutsus[id] and NatureData.Tem(data, j.Natureza)) then n.Equip[i] = false end
	end
	return n
end

-- jutsu que o jogador escolheu numa etapa da natureza (ou nil se ainda nao escolheu)
function NatureData.Escolhido(n, natureza, tier)
	local t = NatureData.Tipos[natureza]
	local par = t and t.Tiers[tier]
	if not par then return nil end
	for _, j in ipairs(par) do
		if n.Jutsus[j.Id] then return j end
	end
	return nil
end

-- a escolha dessa etapa esta liberada e ainda nao foi feita?
function NatureData.EhPendente(n, natureza, tier)
	for _, p in ipairs(n.Pendente) do
		if p.Natureza == natureza and p.Tier == tier then return true end
	end
	return false
end

function NatureData.Tem(data, natureza)
	local n = data and data.Natureza
	if type(n) ~= "table" or type(n.Lista) ~= "table" then return false end
	return table.find(n.Lista, natureza) ~= nil
end

function NatureData.Contar(data)
	local n = data and data.Natureza
	return (type(n) == "table" and type(n.Lista) == "table") and #n.Lista or 0
end

-- sorteio do nascimento: devolve a lista de naturezas (1 a 3, sem repetir)
function NatureData.Roll(rng)
	local r, acc, qtd = rng:NextNumber(0, 100), 0, 1
	for _, q in ipairs(NatureData.Quantidade) do
		acc += q.Weight
		if r < acc then qtd = q.N break end
	end
	local resto = table.clone(NatureData.Order)
	local lista = {}
	for _ = 1, qtd do
		table.insert(lista, table.remove(resto, rng:NextInteger(1, #resto)))
	end
	return lista
end

-- uma natureza que o jogador ainda nao tem (ou nil se ja tem todas)
function NatureData.Nova(data, rng)
	local faltam = {}
	for _, id in ipairs(NatureData.Order) do
		if not NatureData.Tem(data, id) then table.insert(faltam, id) end
	end
	if #faltam == 0 then return nil end
	return faltam[rng:NextInteger(1, #faltam)]
end

return NatureData

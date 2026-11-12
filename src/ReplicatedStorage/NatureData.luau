-- ModuleScript: ReplicatedStorage > NatureData
-- Naturezas de chakra. No nascimento a roleta sorteia de 1 a 3 naturezas; a 4a e a 5a so chegam por missoes raras.
-- Cada natureza tem 2 jutsus. Nenhum vem de graca: o mestre da natureza ensina por missao
-- (MissionData, ids N1_<Natureza> e N2_<Natureza>). O jogador equipa ate 2 jutsus nas teclas G e H.
-- Afinidade: a roleta tambem sorteia a natureza principal do jogador (a 1a da lista). Os jutsus dela
-- dao mais dano (AFIN_DANO) e gastam menos chakra (AFIN_CHAKRA).
-- Save: data.Natureza = { Rolou = bool, Afinidade = id, Lista = { ids }, Jutsus = { [id] = true }, Equip = { id ou false, id ou false } }

local NatureData = {}

NatureData.MAX = 5
NatureData.KEYS = { "G", "H" } -- F ja e o soco
NatureData.CUSTO_REGIRAR = 50 -- gemas para girar de novo as naturezas do nascimento
NatureData.AFIN_DANO = 1.25   -- multiplicador de dano dos jutsus da natureza de afinidade
NatureData.AFIN_CHAKRA = 0.8  -- multiplicador do custo de chakra desses jutsus

NatureData.Order = { "Fogo", "Vento", "Raio", "Terra", "Agua" }

-- quantas naturezas nascem com o jogador (pesos em %)
NatureData.Quantidade = { { N = 1, Weight = 60 }, { N = 2, Weight = 30 }, { N = 3, Weight = 10 } }

-- Mestre = nome do modelo do NPC (chave de MissionData.NPCs)
NatureData.Tipos = {
	Fogo = { Name = "Fire", Color = Color3.fromRGB(255, 110, 50), Mestre = "Sasuke",
		Jutsus = {
			{ Id = "nat_fogo1", Name = "Phoenix Flames", Cooldown = 7, Chakra = 18, Desc = "Three small fireballs fly forward and burn on hit." },
			{ Id = "nat_fogo2", Name = "Dragon Flame", Cooldown = 16, Chakra = 38, Desc = "A stream of fire scorches everything in a long line." },
		} },
	Vento = { Name = "Wind", Color = Color3.fromRGB(170, 240, 200), Mestre = "Naruto",
		Jutsus = {
			{ Id = "nat_vento1", Name = "Gale Palm", Cooldown = 6, Chakra = 15, Desc = "A gust of wind hits enemies in front and throws them back." },
			{ Id = "nat_vento2", Name = "Vacuum Blades", Cooldown = 15, Chakra = 36, Desc = "Blades of wind slice through enemies all around you." },
		} },
	Raio = { Name = "Lightning", Color = Color3.fromRGB(150, 210, 255), Mestre = "Kakashi",
		Jutsus = {
			{ Id = "nat_raio1", Name = "Lightning Bolt", Cooldown = 7, Chakra = 18, Desc = "A bolt strikes the nearest enemy and stuns it." },
			{ Id = "nat_raio2", Name = "Thunder Chain", Cooldown = 16, Chakra = 38, Desc = "Lightning jumps between up to 5 enemies." },
		} },
	Terra = { Name = "Earth", Color = Color3.fromRGB(180, 140, 90), Mestre = "Tsunade",
		Jutsus = {
			{ Id = "nat_terra1", Name = "Rock Pillars", Cooldown = 8, Chakra = 18, Desc = "Stone pillars rise in front of you and launch enemies." },
			{ Id = "nat_terra2", Name = "Earth Quake", Cooldown = 17, Chakra = 38, Desc = "The ground cracks around you, hurting and holding enemies." },
		} },
	Agua = { Name = "Water", Color = Color3.fromRGB(70, 150, 255), Mestre = "Sakura (Naruto Shippuden)",
		Jutsus = {
			{ Id = "nat_agua1", Name = "Water Bullet", Cooldown = 6, Chakra = 16, Desc = "A fast ball of water that splashes on hit." },
			{ Id = "nat_agua2", Name = "Great Wave", Cooldown = 16, Chakra = 38, Desc = "A wave rolls forward, dragging enemies with it." },
		} },
}

local porId = {}
for id, t in pairs(NatureData.Tipos) do
	for i, j in ipairs(t.Jutsus) do
		j.Natureza = id
		j.Nivel = i
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
	if type(n.Equip) ~= "table" then n.Equip = { false, false } end
	if not (type(n.Afinidade) == "string" and table.find(n.Lista, n.Afinidade)) then n.Afinidade = n.Lista[1] or false end
	for i = 1, #NatureData.KEYS do
		local id = n.Equip[i]
		local j = type(id) == "string" and porId[id]
		if not (j and n.Jutsus[id] and NatureData.Tem(data, j.Natureza)) then n.Equip[i] = false end
	end
	return n
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

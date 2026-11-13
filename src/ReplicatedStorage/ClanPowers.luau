-- ModuleScript: ReplicatedStorage > ClanPowers
-- Caminho de poderes de cada clã (Fase 4). Cada clã tem 3 poderes: Q, E e R.
-- Poderes nunca são comprados: o jogador nasce só com os socos. Os 3 poderes vêm por missões do MESTRE do clã
-- (ClanPowers.Mestres): a 1ª depois do passo HIST_PRIMEIRO da história; 2ª e 3ª por nível + rank.
-- As missões do clã ficam em MissionData (ids C1_<Clã>, C2_<Clã> e C3_<Clã>).
-- Ao trocar de clã, o caminho do clã antigo se perde.

local ClanPowers = {}

ClanPowers.KEYS = { "Q", "E", "R" }

-- Requisitos de cada posição. Missao = precisa concluir a missão do clã daquela posição.
-- passo da história (MissionData) que ensina o 1º jutsu do clã
ClanPowers.HIST_PRIMEIRO = 6

ClanPowers.REQ = {
	{ Level = 1, Missao = true },
	{ Level = 15, Rank = "Genin", Missao = true },
	{ Level = 35, Rank = "Chunin", Missao = true },
}

-- Mestre de cada clã: Npc = chave em MissionData.NPCs (nome do modelo), Nome = nome mostrado no jogo
ClanPowers.Mestres = {
	Uzu = { Npc = "Naruto", Nome = "Kenta" },
	Uchiwa = { Npc = "Sasuke", Nome = "Ryo" },
	Mokuton = { Npc = "TumuloPrimeiro", Nome = "the First's Grave" },
	Byakugan = { Npc = "Neji", Nome = "Seiji" },
	Lee = { Npc = "MestreLee", Nome = "Rokuro" },
	Shirokiba = { Npc = "Kakashi", Nome = "Sensei Kaito" },
	Enma = { Npc = "Mahito_Orochimaru_Verified", Nome = "Master Jakou" },
	Inu = { Npc = "MestreInu", Nome = "Kiro" },
}

-- Chakra: regenera sozinho (fração do máximo por segundo)
ClanPowers.CHAKRA_REGEN = 0.04

-- Campos de cada poder:
--   Cooldown (s), Chakra (custo), Desc (texto do jogo)
--   Dash = { Speed, Time, Delay } -> o cliente faz o personagem avançar
--   Seek = true -> o cliente corre até o inimigo mais próximo
ClanPowers.Clans = {
	Uzu = {
		Color = Color3.fromRGB(230, 90, 60),
		Powers = {
			{ Id = "uzu_correntes", Name = "Chakra Chains", Cooldown = 8, Chakra = 20, Desc = "Golden chains shoot forward and hold enemies in place." },
			{ Id = "uzu_selamento", Name = "Sealing Wave", Cooldown = 13, Chakra = 30, Desc = "A seal spreads on the ground and blasts everyone around you." },
			{ Id = "uzu_espiral", Name = "Giant Spiral Sphere", Cooldown = 24, Chakra = 55, Desc = "Charge a huge spiral sphere and slam it into the nearest enemy.", Seek = true },
		},
	},
	Uchiwa = {
		Color = Color3.fromRGB(210, 40, 50),
		Powers = {
			{ Id = "uchiwa_fogo", Name = "Fireball", Cooldown = 7, Chakra = 20, Desc = "A big ball of fire that explodes on hit." },
			{ Id = "uchiwa_sharingan", Name = "Sharingan", Cooldown = 20, Chakra = 30, Desc = "Your eyes awaken: more damage and speed for 8 seconds." },
			{ Id = "uchiwa_chidori", Name = "Chidori", Cooldown = 22, Chakra = 50, Desc = "Lightning in your hand: dash forward and pierce the enemy.", Dash = { Speed = 105, Time = 0.22, Delay = 0.35 } },
		},
	},
	Mokuton = {
		Color = Color3.fromRGB(90, 170, 80),
		Powers = {
			{ Id = "moku_estacas", Name = "Wood Spikes", Cooldown = 8, Chakra = 20, Desc = "Sharp wooden spikes burst from the ground in a line." },
			{ Id = "moku_muro", Name = "Wood Wall", Cooldown = 15, Chakra = 30, Desc = "A wooden dome protects you and pushes enemies away." },
			{ Id = "moku_floresta", Name = "Binding Forest", Cooldown = 26, Chakra = 55, Desc = "Trees grow all around, trapping and crushing enemies." },
		},
	},
	Byakugan = {
		Color = Color3.fromRGB(200, 190, 240),
		Powers = {
			{ Id = "byaku_punho", Name = "Gentle Fist", Cooldown = 6, Chakra = 15, Desc = "A burst of precise palm strikes on the enemy in front.", Dash = { Speed = 60, Time = 0.15, Delay = 0 } },
			{ Id = "byaku_palma", Name = "Air Palm", Cooldown = 11, Chakra = 25, Desc = "A wave of air that blasts enemies far away." },
			{ Id = "byaku_rotacao", Name = "Rotation", Cooldown = 22, Chakra = 45, Desc = "Spin and release a dome of chakra that hits everyone around you." },
		},
	},
	Lee = {
		Color = Color3.fromRGB(70, 180, 110),
		Powers = {
			{ Id = "lee_furacao", Name = "Leaf Hurricane", Cooldown = 6, Chakra = 10, Desc = "A spinning kick that hits all enemies around you." },
			{ Id = "lee_lotus", Name = "Primary Lotus", Cooldown = 14, Chakra = 25, Desc = "Kick the enemy into the air and slam them down.", Seek = true },
			{ Id = "lee_portoes", Name = "Gate Opening", Cooldown = 30, Chakra = 40, Desc = "Open the inner gates: huge damage and speed for 9 seconds, but it hurts." },
		},
	},
	Shirokiba = {
		Color = Color3.fromRGB(225, 230, 240),
		Powers = {
			{ Id = "shiro_presa", Name = "White Fang Slash", Cooldown = 7, Chakra = 18, Desc = "A fast white slash in front of you.", Dash = { Speed = 70, Time = 0.12, Delay = 0 } },
			{ Id = "shiro_passo", Name = "Lightning Step", Cooldown = 10, Chakra = 20, Desc = "Flash forward in a bolt of lightning, hitting everyone in the way.", Dash = { Speed = 140, Time = 0.18, Delay = 0.05 } },
			{ Id = "shiro_trovao", Name = "Thunder Blade", Cooldown = 24, Chakra = 50, Desc = "A long blade of lightning cuts through everything in a line." },
		},
	},
	Enma = {
		Color = Color3.fromRGB(200, 150, 80),
		Cedo = { Level = 3 }, -- traço do clã: o caminho começa cedo (2º poder já no nível 3, sem rank)
		Powers = {
			{ Id = "enma_bastao", Name = "Staff Strike", Cooldown = 6, Chakra = 12, Desc = "Swing the Monkey King's staff in a wide arc." },
			{ Id = "enma_cinzas", Name = "Ash Cloud", Cooldown = 13, Chakra = 28, Desc = "Breathe a cloud of burning ash that hurts enemies over time." },
			{ Id = "enma_gigante", Name = "Giant Staff", Cooldown = 25, Chakra = 50, Desc = "The staff grows huge and crashes down in front of you." },
		},
	},
	Inu = {
		Color = Color3.fromRGB(190, 120, 80),
		Powers = {
			{ Id = "inu_presa", Name = "Fang Over Fang", Cooldown = 8, Chakra = 18, Desc = "You and your dog spin like drills through the enemies.", Dash = { Speed = 80, Time = 0.35, Delay = 0.1 } },
			{ Id = "inu_mordida", Name = "Dog Bite", Cooldown = 9, Chakra = 15, Desc = "Your dog leaps at the nearest enemy and bites hard." },
			{ Id = "inu_fera", Name = "Beast Mimicry", Cooldown = 28, Chakra = 35, Desc = "Fight like a beast: more damage and speed for 10 seconds." },
		},
	},
}

-- poder pelo id
local porId = {}
for clan, c in pairs(ClanPowers.Clans) do
	for slot, p in ipairs(c.Powers) do
		p.Slot = slot
		p.Clan = clan
		porId[p.Id] = p
	end
end
function ClanPowers.Get(id)
	return porId[id]
end

-- requisitos da posição para este clã: nível, rank (ou nil) e se precisa de missão
-- (o Enma começa cedo: 2º poder no nível 3, sem rank)
function ClanPowers.Requisito(clan, slot)
	local r = ClanPowers.REQ[slot]
	local c = ClanPowers.Clans[clan]
	if slot == 2 and c and c.Cedo then
		return c.Cedo.Level, nil, r.Missao
	end
	return r.Level, r.Rank, r.Missao
end

-- Rank: índice na lista de ranks (sem depender do MissionData, que já depende deste módulo)
local RANKS = { Estudante = 1, Genin = 2, Chunin = 3, Jonin = 4, Elite = 5, Kage = 6 }
local NOMES = { Genin = "Genin", Chunin = "Chunin", Jonin = "Jonin", Elite = "Elite Jonin", Kage = "Kage" }

-- Mantém o caminho do clã atual (servidor). Se o jogador trocou de clã, as missões de clã
-- feitas no clã antigo são apagadas: o progresso do clã antigo se perde.
function ClanPowers.Sincronizar(data)
	local clan = data.Cla and data.Cla.Id
	if type(data.Missoes) ~= "table" then data.Missoes = {} end
	local m = data.Missoes
	if type(m.Feitas) ~= "table" then m.Feitas = {} end
	if type(data.Poderes) ~= "table" then data.Poderes = {} end
	if data.Poderes.Cla ~= clan then
		for id in pairs(m.Feitas) do
			if type(id) == "string" and id:match("^C[123]_") then
				m.Feitas[id] = nil
			end
		end
		data.Poderes.Cla = clan
	end
	return clan
end

-- O poder da posição está liberado? Devolve ok, motivo (texto para o jogador)
function ClanPowers.Liberado(data, slot)
	local clan = ClanPowers.Sincronizar(data)
	if not clan or not ClanPowers.Clans[clan] then
		return false, "Get a clan first"
	end
	local nivel, rank, missao = ClanPowers.Requisito(clan, slot)
	local falta = {}
	if (data.Level or 1) < nivel then table.insert(falta, "Level " .. nivel) end
	if rank and (RANKS[data.Rank] or 1) < RANKS[rank] then table.insert(falta, NOMES[rank] .. " rank") end
	if missao and not data.Missoes.Feitas[("C%d_%s"):format(slot, clan)] then table.insert(falta, "clan mission (" .. ClanPowers.Mestres[clan].Nome .. ")") end
	if #falta > 0 then
		return false, "Needs " .. table.concat(falta, " + ")
	end
	return true
end

return ClanPowers

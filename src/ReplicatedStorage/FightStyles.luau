-- ModuleScript: ReplicatedStorage > FightStyles
-- Estilos de luta (Fase 5). O jogador usa um estilo por vez; ele muda o combo (clique / F)
-- e os golpes X, Y e C. Estilos nunca são comprados: cada um vem de um mestre da vila
-- (missões E_<Estilo> em MissionData). Maestria 1 a 5 sobe acertando golpes com o estilo.
--
-- Combo: 4 golpes { mult, range, force, wait, kick = chute, up = força para cima, prender = s }
-- X (segurar e soltar): Tipo "carregado" (Base + Extra conforme a carga) ou "estrangular"
-- Y: Tipo "aereo" (pula e bate no ar), "uppercut" (joga para cima) ou "arremesso" (joga para trás)
-- C: investida (Speed, Time); Prender = segura quem for atingido por alguns segundos
-- Chakra = custo do golpe (o clã Lee paga 20% menos)

local FightStyles = {}

-- Só o Básico e o estilo Lee aparecem no jogo. Boxe, Karatê, Muay Thai e Jiu-Jitsu continuam definidos abaixo
-- (guardados, fora da lista Order e sem missão) caso queiramos trazê-los de volta.
FightStyles.Order = { "Basico", "Lee" }

-- 8 Portões Internos (estilo Lee): tecla Z abre o próximo portão. Cada portão soma dano e velocidade, mas gasta
-- chakra e vida por segundo. A maestria libera mais portões: Mastery 1..5 = 2, 3, 5, 6 e 8 portões.
FightStyles.PORTOES = {
	MAX_POR_MAESTRIA = { 2, 3, 5, 6, 8 },
	DANO = 0.12,      -- +12% de dano por portão aberto
	VELOCIDADE = 1.6, -- +1,6 studs/s por portão
	CHAKRA_SEG = 1.2, -- chakra por segundo = 1,2 x portões
	VIDA_SEG = 0.005, -- vida por segundo = 0,5% da vida máxima x portões (nunca mata: para em 1 de vida)
	CHAKRA_ABRIR = 8, -- chakra para abrir cada portão
	CANSACO = 4,      -- segundos de cansaço (lento) depois de fechar o 8º portão
	NOMES = { "Gate of Opening", "Gate of Healing", "Gate of Life", "Gate of Pain", "Gate of Limit", "Gate of View", "Gate of Wonder", "Gate of Death" },
}
FightStyles.MAESTRIA = { 0, 150, 400, 800, 1500 } -- golpes acertados para chegar a cada nível
FightStyles.BONUS_MAESTRIA = 0.06 -- dano extra por nível de maestria acima do 1
FightStyles.COMBO_RESET = 1.1

FightStyles.Styles = {
	Basico = {
		Name = "Basic", Color = Color3.fromRGB(255, 255, 255),
		Combo = {
			{ mult = 1.0, range = 9, force = 12, wait = 0.28 },
			{ mult = 1.0, range = 9, force = 12, wait = 0.28 },
			{ mult = 1.3, range = 9, force = 20, wait = 0.34 },
			{ mult = 2.2, range = 11, force = 55, wait = 0.6, kick = true, up = 30 },
		},
		X = { Name = "Charge", Tipo = "carregado", Cd = 3, Chakra = 6, Base = 2, Extra = 4, Range = 11, RangeExtra = 6, Force = 40, ForceExtra = 60 },
		Y = { Name = "Air", Tipo = "aereo", Cd = 3, Chakra = 6, Mult = 2.5, Range = 13 },
		C = { Name = "Dash", Cd = 4, Chakra = 6, Mult = 2.2, Speed = 85, Time = 0.28 },
	},
	Boxe = {
		Name = "Boxing", Color = Color3.fromRGB(235, 70, 60),
		Mestre = "Coach Gaien", Req = "Level 5 + train 5 times",
		Combo = {
			{ mult = 0.85, range = 8, force = 8, wait = 0.2 },
			{ mult = 0.85, range = 8, force = 8, wait = 0.2 },
			{ mult = 1.15, range = 8, force = 14, wait = 0.24 },
			{ mult = 2.0, range = 9, force = 25, wait = 0.5, up = 45 },
		},
		X = { Name = "Haymaker", Tipo = "carregado", Cd = 3.5, Chakra = 8, Base = 2.5, Extra = 4.5, Range = 9, RangeExtra = 4, Force = 55, ForceExtra = 60 },
		Y = { Name = "Uppercut", Tipo = "uppercut", Cd = 3, Chakra = 8, Mult = 2.6, Range = 8 },
		C = { Name = "Dash Jab", Cd = 3.5, Chakra = 7, Mult = 2.0, Speed = 95, Time = 0.2 },
	},
	Karate = {
		Name = "Karate", Color = Color3.fromRGB(245, 245, 235),
		Mestre = "Sensei Kaito", Req = "Level 10 + defeat 10 rogue ninjas",
		Combo = {
			{ mult = 1.05, range = 9, force = 14, wait = 0.27 },
			{ mult = 1.05, range = 9, force = 14, wait = 0.27 },
			{ mult = 1.4, range = 9, force = 24, wait = 0.32 },
			{ mult = 2.4, range = 11, force = 60, wait = 0.55, kick = true, up = 25 },
		},
		X = { Name = "Seiken", Tipo = "carregado", Cd = 3, Chakra = 8, Base = 2.6, Extra = 5.4, Range = 12, RangeExtra = 6, Force = 45, ForceExtra = 65 },
		Y = { Name = "Flying Kick", Tipo = "aereo", Cd = 3, Chakra = 8, Mult = 2.8, Range = 14 },
		C = { Name = "Rush Palm", Cd = 4, Chakra = 8, Mult = 2.4, Speed = 85, Time = 0.3 },
	},
	Lee = {
		Name = "Lee", Color = Color3.fromRGB(60, 200, 90),
		Mestre = "Coach Gaien", Req = "Lv 25 + 30 trainings + defeat 100 enemies with taijutsu only",
		Combo = {
			{ mult = 0.9, range = 9, force = 10, wait = 0.2, kick = true },
			{ mult = 0.9, range = 9, force = 10, wait = 0.2, kick = true },
			{ mult = 1.2, range = 9, force = 18, wait = 0.24 },
			{ mult = 2.6, range = 11, force = 60, wait = 0.55, kick = true, up = 35 },
		},
		X = { Name = "Leaf Whirlwind", Tipo = "carregado", Cd = 3.5, Chakra = 8, Base = 2.6, Extra = 5.0, Range = 11, RangeExtra = 5, Force = 50, ForceExtra = 60 },
		Y = { Name = "Front Lotus", Tipo = "uppercut", Cd = 3.5, Chakra = 9, Mult = 3.0, Range = 9 },
		C = { Name = "Leaf Rush", Cd = 3.5, Chakra = 7, Mult = 2.2, Speed = 100, Time = 0.25 },
	},
	MuayThai = {
		Name = "Muay Thai", Color = Color3.fromRGB(255, 170, 60),
		Mestre = "Ryo", Req = "Level 15 + Genin + defeat 12 rogue ninjas",
		Combo = {
			{ mult = 1.25, range = 11, force = 18, wait = 0.36, kick = true },
			{ mult = 1.25, range = 11, force = 18, wait = 0.36, kick = true },
			{ mult = 1.6, range = 11, force = 28, wait = 0.42 },
			{ mult = 2.9, range = 13, force = 70, wait = 0.7, kick = true, up = 25 },
		},
		X = { Name = "Knee Strike", Tipo = "carregado", Cd = 3.5, Chakra = 9, Base = 2.4, Extra = 5.2, Range = 10, RangeExtra = 4, Force = 50, ForceExtra = 70 },
		Y = { Name = "Jump Knee", Tipo = "aereo", Cd = 3.5, Chakra = 9, Mult = 3.0, Range = 12 },
		C = { Name = "Teep Rush", Cd = 4.5, Chakra = 9, Mult = 2.6, Speed = 80, Time = 0.32 },
	},
	JiuJitsu = {
		Name = "Jiu-Jitsu", Color = Color3.fromRGB(90, 140, 255),
		Mestre = "Stranger", Req = "Level 20 + collect 8 herbs",
		Combo = {
			{ mult = 0.9, range = 8, force = 6, wait = 0.3 },
			{ mult = 0.9, range = 8, force = 6, wait = 0.3 },
			{ mult = 1.2, range = 8, force = 10, wait = 0.34 },
			{ mult = 1.8, range = 9, force = 10, wait = 0.55, prender = 1.2 },
		},
		X = { Name = "Chokehold", Tipo = "estrangular", Cd = 5, Chakra = 10, Mult = 4.5, Range = 8, Tempo = 1.6 },
		Y = { Name = "Hip Throw", Tipo = "arremesso", Cd = 3.5, Chakra = 8, Mult = 2.4, Range = 8 },
		C = { Name = "Takedown", Cd = 4, Chakra = 8, Mult = 1.6, Speed = 85, Time = 0.28, Prender = 2.2 },
	},
}

function FightStyles.Get(id)
	return FightStyles.Styles[id] or FightStyles.Styles.Basico
end

-- nível de maestria a partir dos golpes acertados
function FightStyles.Nivel(xp)
	local n = 1
	for i, req in ipairs(FightStyles.MAESTRIA) do
		if (xp or 0) >= req then n = i end
	end
	return n
end

-- garante a parte dos estilos no save (servidor)
function FightStyles.Garantir(data)
	if type(data.Estilos) ~= "table" then data.Estilos = {} end
	local e = data.Estilos
	if type(e.Liberados) ~= "table" then e.Liberados = {} end
	if type(e.XP) ~= "table" then e.XP = {} end
	e.Treinos = tonumber(e.Treinos) or 0 -- treinos feitos na Academia (requisito do estilo Lee)
	e.Liberados.Basico = true
	if not FightStyles.Styles[e.Equipado or ""] or not e.Liberados[e.Equipado] or not table.find(FightStyles.Order, e.Equipado) then
		e.Equipado = "Basico"
	end
	return e
end

return FightStyles

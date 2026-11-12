-- ModuleScript: ReplicatedStorage > WorldData
-- Fase 6: mundo aberto. Zonas fora da vila, inimigos que voltam a aparecer,
-- chefe da zona e o evento do chefe do mundo.
-- A aparência dos inimigos vem de ServerStorage.InimigosMundo.<Nome> (um Model com Humanoid e
-- HumanoidRootPart, sem âncora). Para trocar a skin, troque o Model lá mantendo o nome.

local WorldData = {}

WorldData.Zonas = {
	{
		Id = "Floresta",
		Name = "Fire Country Woods",
		Faixa = "Lv 10-30",
		NivelMin = 10,
		-- retângulo da zona no chão (X e Z)
		Min = Vector3.new(652, 0, -800),
		Max = Vector3.new(1010, 0, -220),
		Entrada = Vector3.new(705, 3, -508), -- onde o jogador aparece ao entrar
		Volta = Vector3.new(570, 3, -508), -- de volta para dentro da vila (quem não tem o nível)
		Areas = {
			{ Id = "Camp", Name = "Bandit Camp", Centro = Vector3.new(800, 0, -330), Raio = 50, Inimigo = "Bandit Thug", Quantos = 6 },
			{ Id = "Ruinas", Name = "Old Ruins", Centro = Vector3.new(810, 0, -690), Raio = 55, Inimigo = "Rogue Ninja", Quantos = 6 },
			{ Id = "Mata", Name = "Deep Woods", Centro = Vector3.new(950, 0, -620), Raio = 40, Inimigo = "Rogue Chunin", Quantos = 4 },
		},
	},
}

-- Nivel = {min, max}: cada inimigo nasce com um nível sorteado; vida, dano e recompensa crescem 6% por nível acima do mínimo.
WorldData.Inimigos = {
	["Bandit Thug"] = { Nivel = { 10, 14 }, Vida = 120, Dano = 7, Velocidade = 13, XP = 22, Moedas = 12, Alcance = 40,
		Cor = Color3.fromRGB(110, 80, 60) },
	["Rogue Ninja"] = { Nivel = { 16, 22 }, Vida = 220, Dano = 11, Velocidade = 16, XP = 40, Moedas = 22, Alcance = 45,
		Cor = Color3.fromRGB(60, 65, 80) },
	["Rogue Chunin"] = { Nivel = { 24, 30 }, Vida = 380, Dano = 16, Velocidade = 17, XP = 70, Moedas = 38, Alcance = 50,
		Cor = Color3.fromRGB(70, 95, 70) },
}

-- Chefe da zona: volta Respawn segundos depois de derrotado.
WorldData.ChefeZona = {
	Name = "Bandit King", Nivel = 30, Vida = 2500, Dano = 20, Velocidade = 14, Escala = 1.5,
	Pos = Vector3.new(935, 0, -290), Respawn = 300, Alcance = 55,
	XP = 300, Moedas = 250, Cor = Color3.fromRGB(150, 60, 40),
}

-- Evento do chefe do mundo: aparece a cada 20 a 30 minutos, com aviso para todo o servidor.
-- A vida cresce com o número de jogadores. Cada um ganha pela parte do dano que causou.
WorldData.ChefeMundo = {
	Name = "Rogue Warlord", Nivel = 40, VidaBase = 4000, VidaPorJogador = 2000, Dano = 26, Velocidade = 15, Escala = 2,
	Pos = Vector3.new(880, 0, -500), Alcance = 70,
	IntervaloMin = 20 * 60, IntervaloMax = 30 * 60,
	Aviso = 60, -- segundos de aviso antes de aparecer
	Duracao = 10 * 60, -- some se não for derrotado nesse tempo
	XP = 250, XPExtra = 1200, -- XP + XPExtra * (sua parte do dano)
	Moedas = 200, MoedasExtra = 1500,
	GemasTop = 10, -- quem causou mais dano
	ParteMinima = 0.01, -- precisa ter causado ao menos 1% do dano
	Lacaio = "Rogue Ninja", -- chama ajudantes com metade da vida
	Cor = Color3.fromRGB(60, 30, 70),
}

-- À noite os inimigos do mundo ficam mais fortes e dão mais recompensa.
WorldData.Noite = { Vida = 1.3, Dano = 1.2, Recompensa = 1.25 }

function WorldData.ZonaEm(pos)
	for _, z in ipairs(WorldData.Zonas) do
		if pos.X >= z.Min.X and pos.X <= z.Max.X and pos.Z >= z.Min.Z and pos.Z <= z.Max.Z then
			return z
		end
	end
	return nil
end

return WorldData

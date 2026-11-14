-- ModuleScript: ReplicatedStorage > SegredosData
-- Easter eggs do lado LESTE da vila. Para mudar um lugar, um texto ou um poder, mude aqui:
-- servidor (SegredosServer) e cliente (SegredosClient) leem deste arquivo.
--
-- Como funciona:
--   1. Tres SELOS ficam escondidos em cantos do leste. Cada jogador acha os seus (tecla E) e o progresso fica salvo.
--   2. Com os tres selos, aparece SO PARA ELE um santuario secreto com um pilar de luz (SegredosClient desenha).
--   3. No santuario ha um pedestal por poder. Pegar um (tecla E) libera o poder para sempre; usa-se pela tecla do poder.
--      Poderes com "Cla" so funcionam para esse cla (o id do cla e o mesmo de ClanData).
--      Poderes com "RankMin" exigem esse rank ninja ou maior (RankOrdem).
--   Os poderes dos easter eggs sao SEPARADOS dos jutsus: teclas, botoes e recarga proprios, e o dano nao depende de
--   Ninjutsu, buffs nem dos jutsus equipados (e uma fatia da vida do inimigo). Os Tesouros ainda gastam chakra.
-- Para criar mais um easter egg: acrescente em "Poderes" + "Ordem" e escreva o efeito em SegredosServer (EFEITOS).

local SegredosData = {}

SegredosData.Pasta = "Segredos_Leste" -- pasta criada no Workspace com os selos

-- Selos escondidos (x, z no mapa; o servidor acha a altura do chao sozinho)
SegredosData.Simbolos = {
	{ Id = 1, Nome = "Wood Seal", Emoji = "🌳", Cor = Color3.fromRGB(110, 215, 110), Pos = Vector3.new(480, 0, -375) },
	{ Id = 2, Nome = "Eye Seal", Emoji = "👁", Cor = Color3.fromRGB(235, 60, 70), Pos = Vector3.new(475, 0, -175) },
	{ Id = 3, Nome = "Leaf Seal", Emoji = "🍃", Cor = Color3.fromRGB(245, 205, 90), Pos = Vector3.new(580, 0, -485) },
}

-- Santuario secreto (centro) e distancia maxima para pegar um poder
SegredosData.Altar = Vector3.new(575, 0, -245)
SegredosData.DistAltar = 30

-- Ordem dos ranks ninja (o atributo "Rank" do jogador usa estes ids)
SegredosData.RankOrdem = { Estudante = 1, Genin = 2, Chunin = 3, Jonin = 4, Elite = 5, Kage = 6 }

-- Poderes. Tecla = tecla de uso; Cooldown/Duracao em segundos; Cla = id do cla exigido (nil = qualquer um);
-- RankMin = rank ninja minimo (nil = qualquer um); Chakra = fracao do chakra maximo que o uso gasta (precisa ter tudo).
SegredosData.Poderes = {
	gene = {
		Nome = "Hashirama's Gene", Emoji = "🌳", Cor = Color3.fromRGB(110, 215, 110), Tecla = "B",
		Cooldown = 60, Duracao = 10, Cura = 0.04, -- cura 4% da vida maxima por segundo
		Desc = "Wood regeneration: recover 40% of your health over 10 seconds.",
	},
	olho = {
		Nome = "Shisui's Eye", Emoji = "👁", Cor = Color3.fromRGB(235, 60, 70), Tecla = "N",
		Cooldown = 75, Duracao = 6, Alcance = 45, Alvos = 6, Dreno = 0.05, -- 5% da vida maxima por segundo
		Cla = "Uchiwa", ClaNome = "Uchiwa",
		Desc = "Genjutsu: nearby enemies freeze for 6 seconds and keep losing health.",
	},

	-- Tesouros do Sabio dos Seis Caminhos (so Jonin ou maior; gastam muito chakra, sem chakra o poder nao dispara)
	bashosen = {
		Nome = "Bashosen", Emoji = "🌿", Cor = Color3.fromRGB(120, 220, 140), Tecla = "M",
		Cooldown = 45, Alcance = 35, Alvos = 12, Dano = 0.35, -- 35% da vida maxima de cada inimigo atingido (boss: 20% disso)
		Chakra = 0.8, RankMin = "Jonin", RankNome = "Jonin",
		-- um elemento por uso, em ordem; o botao mostra o proximo. Burn = % da vida por s durante 4 s; Force = empurrao; Stun = segundos; Mult = dano extra
		Elementos = {
			{ Nome = "Fire", Emoji = "🔥", Cor = Color3.fromRGB(255, 120, 40), Burn = 0.05 },
			{ Nome = "Water", Emoji = "💧", Cor = Color3.fromRGB(70, 150, 255), Force = 70, Stun = 1.5 },
			{ Nome = "Wind", Emoji = "🌪", Cor = Color3.fromRGB(170, 240, 200), Force = 110 },
			{ Nome = "Lightning", Emoji = "⚡", Cor = Color3.fromRGB(150, 210, 255), Stun = 3 },
			{ Nome = "Earth", Emoji = "🪨", Cor = Color3.fromRGB(180, 140, 90), Stun = 2, Mult = 1.3 },
		},
		Desc = "Sage's fan: a huge blast of Fire, Water, Wind, Lightning or Earth (one per use, in turn). Costs 80% of your chakra. Jonin or higher.",
	},
	kohaku = {
		Nome = "Kohaku no Johei", Emoji = "🏺", Cor = Color3.fromRGB(255, 190, 70), Tecla = "L",
		Cooldown = 60, Alcance = 50, Duracao = 3, DanoBoss = 0.12, -- chefe resiste: so perde 12% da vida e fica preso menos tempo
		Chakra = 0.6, RankMin = "Jonin", RankNome = "Jonin",
		Desc = "Amber pot: seals the soul of the strongest enemy nearby; it freezes and is gone after 3 seconds. Bosses resist. Costs 60% of your chakra. Jonin or higher.",
	},
}
SegredosData.Ordem = { "gene", "olho", "bashosen", "kohaku" }

return SegredosData

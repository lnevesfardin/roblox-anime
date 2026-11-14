-- ModuleScript: ReplicatedStorage > SegredosData
-- Easter eggs do lado LESTE da vila. Para mudar um lugar, um texto ou um poder, mude aqui:
-- servidor (SegredosServer) e cliente (SegredosClient) leem deste arquivo.
--
-- Como funciona:
--   1. Tres SELOS ficam escondidos em cantos do leste. Cada jogador acha os seus (tecla E) e o progresso fica salvo.
--   2. Com os tres selos, aparece SO PARA ELE um santuario secreto com um pilar de luz (SegredosClient desenha).
--   3. No santuario ha um pedestal por poder. Pegar um (tecla E) libera o poder para sempre; usa-se pela tecla do poder.
--      Poderes com "Cla" so funcionam para esse cla (o id do cla e o mesmo de ClanData).
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

-- Poderes. Tecla = tecla de uso; Cooldown/Duracao em segundos; Cla = id do cla exigido (nil = qualquer um)
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
}
SegredosData.Ordem = { "gene", "olho" }

return SegredosData

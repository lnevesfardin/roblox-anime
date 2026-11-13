-- ModuleScript: ReplicatedStorage > IconesData
-- Icone (emoji) de cada jutsu de cla e de Kekkei Genkai, usado nos slots Q E R V e nas listas do painel POWERS.
-- Os jutsus de natureza usam o emoji do elemento (NatureClient). Id sem icone usa "✨".

local I = {}

I.PADRAO = "✨"
I.BLOQUEADO = "❓"

I.Poder = {
	-- Uzumaki
	uzu_correntes = "🔗", uzu_selamento = "⭕", uzu_espiral = "🌀",
	-- Uchiwa
	uchiwa_fogo = "🔥", uchiwa_sharingan = "🔴", uchiwa_chidori = "⚡",
	-- Mokuton (Senju)
	moku_estacas = "🌱", moku_muro = "🛡", moku_floresta = "🌲",
	-- Byakugan (Hyuga)
	byaku_punho = "✋", byaku_palma = "💨", byaku_rotacao = "🔄",
	-- Lee
	lee_furacao = "🌪", lee_lotus = "🌸", lee_portoes = "🚪",
	-- Hatake
	shiro_presa = "🐺", shiro_passo = "⚡", shiro_trovao = "⚔",
	-- Sarutobi
	enma_bastao = "🐒", enma_cinzas = "💨", enma_gigante = "🔨",
	-- Inuzuka
	inu_presa = "🐕", inu_mordida = "🦷", inu_fera = "🐾",
	-- Kekkei Genkai
	kg_gelo = "❄", kg_lava = "🌋", kg_fervura = "♨", kg_tempestade = "🌩",
	kg_explosao = "💥", kg_osso = "🦴", kg_calor = "🌞", kg_poeira = "🔲",
}

function I.De(id)
	return I.Poder[id] or I.PADRAO
end

return I

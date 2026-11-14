-- ModuleScript: ReplicatedStorage > HudEscala
-- Tamanho do HUD. Para deixar tudo MAIOR ou MENOR, mude so o FATOR (1 = cheio; 0.78 = compacto antigo).
-- Usado por: HUD (barra de nivel e menu da esquerda), STATS, DAILY, RANK, HELP, cla, barras de golpes/poderes/naturezas
-- e os botoes dos easter eggs. Assim tudo muda junto e nada sobrepoe nada.

local GuiService = game:GetService("GuiService")

local HudEscala = {}

HudEscala.Fator = 0.85

-- botoes do topo, barra de nivel e menu da esquerda.
-- Alem da largura, limita pela altura: o menu da esquerda (5 botoes) precisa caber ABAIXO da fileira de botoes do topo,
-- senao o menu sobe e passa por cima deles em janelas baixas.
function HudEscala.Hud(v)
	local inset = GuiService:GetGuiInset().Y
	local porLargura = v.X / 1150
	local porAltura = (v.Y - 2 * inset) / 726
	return math.clamp(math.min(porLargura, porAltura) * HudEscala.Fator, 0.45, 1.1 * HudEscala.Fator)
end

-- barras de baixo (golpes X Y C, poderes Q E R V, naturezas G H J K) e botoes dos easter eggs
function HudEscala.Barras(v)
	return math.clamp((v.X / 2 + 111) / 864 * HudEscala.Fator, 0.5, 0.95 * HudEscala.Fator)
end

return HudEscala

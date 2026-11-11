-- LocalScript: StarterPlayerScripts > HUD
-- Telas do jogo: barra de nível/moedas/gemas + menu com Caixas, Coleção, Battle Pass, Loja e Configurações.
-- Substitui os antigos PainelCaixa e PainelColecao.
-- O cliente só MOSTRA: toda recompensa, compra e sorteio é decidido no servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local CharacterData = require(ReplicatedStorage:WaitForChild("CharacterData"))
local EconomyData = require(ReplicatedStorage:WaitForChild("EconomyData"))
local IconeGema = require(ReplicatedStorage:WaitForChild("IconeGema"))

local R = {}
for _, name in ipairs({ "OpenCrate", "GetCollection", "EquipCharacter", "DeleteDuplicates", "GetInventory", "UseItem",
	"EquipCosmetic", "GetBattlePass", "ClaimBattlePass", "BuyWithGems", "PurchaseDone", "GetSettings", "SaveSettings" }) do
	R[name] = ReplicatedStorage:WaitForChild(name)
end
local stats = player:WaitForChild("leaderstats")
local Sons = SoundService:WaitForChild("Sons", 10)

---------------------------------------------------------------
-- Visual
---------------------------------------------------------------
local COR = {
	fundo = Color3.fromRGB(12, 12, 14),
	painel = Color3.fromRGB(20, 20, 23),
	card = Color3.fromRGB(30, 30, 34),
	linha = Color3.fromRGB(58, 58, 64),
	texto = Color3.fromRGB(240, 240, 244),
	fraco = Color3.fromRGB(140, 140, 150),
	laranja = Color3.fromRGB(255, 140, 40),
	ouro = Color3.fromRGB(255, 205, 70),
	verde = Color3.fromRGB(70, 190, 110),
	vermelho = Color3.fromRGB(215, 70, 70),
	azul = Color3.fromRGB(70, 120, 220),
	roxo = Color3.fromRGB(140, 80, 230),
}
local RAR = {
	Comum = Color3.fromRGB(200, 200, 200),
	Raro = Color3.fromRGB(80, 160, 255),
	Epico = Color3.fromRGB(180, 90, 255),
	Lendario = Color3.fromRGB(255, 190, 40),
	Mistico = Color3.fromRGB(255, 70, 120),
}
local RARNOME = { Comum = "Common", Raro = "Rare", Epico = "Epic", Lendario = "Legendary", Mistico = "Mythic" }

-- toda peça de tela ganha LayoutOrder na ordem em que foi criada,
-- e as listas ordenam por LayoutOrder (assim renomear algo não muda a ordem)
local ordem = 0
local function new(class, props, children)
	local o = Instance.new(class)
	if o:IsA("GuiObject") then
		ordem += 1
		o.LayoutOrder = ordem
	elseif o:IsA("UIGridStyleLayout") then
		o.SortOrder = Enum.SortOrder.LayoutOrder
	end
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			o[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = o
	end
	if props and props.Parent then
		o.Parent = props.Parent
	end
	return o
end
local function corner(p, r) return new("UICorner", { CornerRadius = UDim.new(0, r or 10), Parent = p }) end
local function stroke(p, c, t, tr)
	return new("UIStroke", { Color = c or COR.linha, Thickness = t or 2, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p })
end
local function grad(p, c1, c2, rot)
	return new("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rot or 90, Parent = p })
end
local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function label(parent, text, size, color, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Text = text, TextSize = size or 16, TextColor3 = color or COR.texto,
		Font = Enum.Font.GothamBold, TextWrapped = true, Parent = parent,
	})
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end

local function som(nome, velocidade)
	local s = Sons and Sons:FindFirstChild(nome)
	if not s then return end
	local c = s:Clone()
	c.Looped = false
	if velocidade then c.PlaybackSpeed = velocidade end
	c.Parent = SoundService
	c:Play()
	c.Ended:Once(function() c:Destroy() end)
	task.delay(10, function() if c.Parent then c:Destroy() end end)
end

local function botao(parent, text, color, size, pos)
	local b = new("TextButton", {
		Size = size or UDim2.fromOffset(140, 40), Position = pos or UDim2.new(), BackgroundColor3 = color or COR.laranja,
		Text = text, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBlack, TextSize = 16, AutoButtonColor = false,
		Parent = parent,
	})
	corner(b, 10)
	grad(b, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190), 90)
	local sc = new("UIScale", { Parent = b })
	b.MouseEnter:Connect(function() tween(sc, 0.12, { Scale = 1.05 }) end)
	b.MouseLeave:Connect(function() tween(sc, 0.12, { Scale = 1 }) end)
	b.MouseButton1Down:Connect(function() tween(sc, 0.06, { Scale = 0.95 }) end)
	b.MouseButton1Up:Connect(function() tween(sc, 0.1, { Scale = 1.03 }) end)
	b.Activated:Connect(function() som("Clique") end)
	return b
end

-- ícone das gemas: imagem enviada (EconomyData.Gems.IconId) ou desenho por código
local function iconeGema(parent, size, pos)
	local img = new("ImageLabel", {
		Size = size, Position = pos or UDim2.new(), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Parent = parent,
	})
	if EconomyData.Gems.IconId ~= "" then
		img.Image = EconomyData.Gems.IconId
	else
		task.spawn(function()
			local content = IconeGema.Get()
			if content then
				img.ImageContent = content
			else
				-- reserva: losango dourado
				local d = new("Frame", { Size = UDim2.fromScale(0.62, 0.62), Position = UDim2.fromScale(0.19, 0.19), Rotation = 45, BackgroundColor3 = COR.laranja, Parent = img })
				grad(d, COR.ouro, Color3.fromRGB(200, 80, 10), 45)
				stroke(d, Color3.fromRGB(90, 25, 5), 2)
			end
		end)
	end
	return img
end

local function iconeMoeda(parent, size, pos)
	local m = new("Frame", { Size = size, Position = pos or UDim2.new(), BackgroundColor3 = COR.ouro, Parent = parent })
	corner(m, 999)
	grad(m, Color3.fromRGB(255, 230, 120), Color3.fromRGB(220, 150, 20), 90)
	stroke(m, Color3.fromRGB(150, 90, 10), 2)
	label(m, "$", 14, Color3.fromRGB(150, 90, 10), { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack, TextScaled = true })
	return m
end

---------------------------------------------------------------
-- Tela base
---------------------------------------------------------------
local gui = new("ScreenGui", { Name = "HUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
-- raiz centralizada: com UIScale s e tamanho 1/s ela continua cobrindo a tela toda
local raiz = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
local escala = new("UIScale", { Parent = raiz })
local function ajustarEscala()
	local v = workspace.CurrentCamera.ViewportSize
	local sc = math.clamp(math.min(v.X / 1150, v.Y / 680), 0.5, 1.1)
	escala.Scale = sc
	raiz.Size = UDim2.fromScale(1 / sc, 1 / sc)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajustarEscala)
ajustarEscala()

-- aviso rápido na parte de baixo
local avisoAtual
local function aviso(texto, cor)
	if avisoAtual then avisoAtual:Destroy() end
	local f = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(420, 46),
		BackgroundColor3 = COR.painel, Parent = raiz, ZIndex = 50,
	})
	corner(f, 12)
	stroke(f, cor or COR.laranja, 2)
	label(f, texto, 16, COR.texto, { Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0), ZIndex = 51 })
	avisoAtual = f
	f.Position = UDim2.new(0.5, 0, 1, -80)
	tween(f, 0.25, { Position = UDim2.new(0.5, 0, 1, -110) }, Enum.EasingStyle.Back)
	task.delay(2.6, function()
		if f.Parent then
			tween(f, 0.3, { BackgroundTransparency = 1 })
			task.wait(0.3)
			f:Destroy()
		end
	end)
end

---------------------------------------------------------------
-- Estilo do HUD: placas escuras inclinadas e ícones de linha brancos com brilho
---------------------------------------------------------------
local INCLINA = 9 -- graus de inclinação das placas
local PLACA = Color3.fromRGB(24, 24, 27)
local PLACA_ESC = Color3.fromRGB(17, 17, 19)
local BORDA = Color3.fromRGB(58, 58, 64)
local VERMELHO_HUD = Color3.fromRGB(140, 22, 22)
local BRANCO = Color3.fromRGB(255, 255, 255)
local BRILHO = Color3.fromRGB(255, 236, 210)

-- placa em forma de paralelogramo: CanvasGroup recorta uma faixa inclinada.
-- Devolve (quadro, faixa, conteúdo, borda): o conteúdo fica por cima e não é recortado.
local function placa(parent, w, h, cor, props)
	local quadro = new("Frame", { Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, Parent = parent })
	for k, v in pairs(props or {}) do quadro[k] = v end
	local grupo = new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = quadro })
	local ang = math.rad(INCLINA)
	local desloc = h * math.tan(ang)
	local faixa = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset((w - desloc) * math.cos(ang), h * 3), Rotation = INCLINA,
		BackgroundColor3 = cor or PLACA, BackgroundTransparency = 0.04, BorderSizePixel = 0, Parent = grupo,
	})
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(175, 175, 180)), Rotation = 90 - INCLINA, Parent = faixa })
	local borda = new("UIStroke", { Color = BORDA, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = faixa })
	local conteudoPlaca = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = quadro })
	return quadro, faixa, conteudoPlaca, borda
end

-- ícones desenhados com linhas: cada traço tem uma cópia mais grossa e transparente atrás (brilho)
local function contorno(parent, size, pos, rot, raio)
	for _, camada in ipairs({ { 5, 0.82, BRILHO }, { 2, 0, BRANCO } }) do
		local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = size, Rotation = rot or 0, BackgroundTransparency = 1, Parent = parent })
		if raio then corner(f, raio) end
		new("UIStroke", { Color = camada[3], Thickness = camada[1], Transparency = camada[2], Parent = f })
	end
end
local function traco(parent, size, pos, rot)
	local brilho = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = size + UDim2.fromOffset(4, 4), Rotation = rot or 0, BackgroundColor3 = BRILHO, BackgroundTransparency = 0.82, BorderSizePixel = 0, Parent = parent })
	corner(brilho, 3)
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = size, Rotation = rot or 0, BackgroundColor3 = BRANCO, BorderSizePixel = 0, Parent = parent })
end
local function P(x, y) return UDim2.new(0.5, x, 0.5, y) end

local DESENHOS = {
	caixas = function(f) -- caixa de presente / pacote
		contorno(f, UDim2.fromOffset(24, 20), P(0, 3), 0, 3)
		traco(f, UDim2.fromOffset(24, 2), P(0, -2))
		traco(f, UDim2.fromOffset(2, 20), P(0, 3))
		contorno(f, UDim2.fromOffset(9, 6), P(-5, -10), -25, 3)
		contorno(f, UDim2.fromOffset(9, 6), P(5, -10), 25, 3)
	end,
	colecao = function(f) -- livro
		contorno(f, UDim2.fromOffset(20, 26), P(0, 0), 0, 3)
		traco(f, UDim2.fromOffset(20, 2), P(0, 7))
	end,
	passe = function(f) -- troféu
		contorno(f, UDim2.fromOffset(16, 15), P(0, -5), 0, 7)
		traco(f, UDim2.fromOffset(20, 2), P(0, -12))
		contorno(f, UDim2.fromOffset(7, 8), P(-10, -6), 0, 4)
		contorno(f, UDim2.fromOffset(7, 8), P(10, -6), 0, 4)
		traco(f, UDim2.fromOffset(2, 7), P(0, 6))
		traco(f, UDim2.fromOffset(14, 2), P(0, 11))
	end,
	loja = function(f) -- diamante
		contorno(f, UDim2.fromOffset(17, 17), P(0, 0), 45, 2)
	end,
	config = function(f) -- engrenagem
		for i = 0, 7 do
			local a = math.rad(i * 45)
			traco(f, UDim2.fromOffset(5, 6), P(math.sin(a) * 11, -math.cos(a) * 11), i * 45)
		end
		contorno(f, UDim2.fromOffset(19, 19), P(0, 0), 0, 999)
		contorno(f, UDim2.fromOffset(7, 7), P(0, 0), 0, 999)
	end,
}

-- texto com letras espaçadas (como no estilo de jogo)
local function espacado(txt)
	return (txt:upper():gsub("(.)", "%1 ")):sub(1, -2)
end

---------------------------------------------------------------
-- Barra de cima: nível, XP, moedas, gemas
---------------------------------------------------------------
local topo = new("Frame", { Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(720, 60), BackgroundTransparency = 1, Parent = raiz })
new("UIScale", { Scale = 0.8, Parent = topo }) -- HUD mais compacto
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), Parent = topo })

local blocoNivel, _, cNivel = placa(topo, 330, 60)
local _, faixaNum, cNum = placa(cNivel, 76, 60, Color3.fromRGB(44, 44, 48))
new("Frame", { Position = UDim2.fromOffset(4, 0), Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = VERMELHO_HUD, BorderSizePixel = 0, Rotation = 0, Parent = faixaNum })
local txtNivel = label(cNum, "1", 24, BRANCO, { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack })
local txtNivelNome = label(cNivel, "LEVEL 1", 12, BRANCO, { Position = UDim2.fromOffset(92, 10), Size = UDim2.fromOffset(110, 18), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold })
local txtXP = label(cNivel, "0 / 100 XP", 12, Color3.fromRGB(150, 150, 158), { Position = UDim2.fromOffset(190, 10), Size = UDim2.fromOffset(112, 18), TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBold })
local barraXP = new("Frame", { Position = UDim2.fromOffset(92, 34), Size = UDim2.fromOffset(206, 8), BackgroundColor3 = Color3.fromRGB(8, 8, 9), BorderSizePixel = 0, Parent = cNivel })
local fillXP = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = VERMELHO_HUD, BorderSizePixel = 0, Parent = barraXP })
grad(fillXP, Color3.fromRGB(255, 120, 120), Color3.fromRGB(160, 60, 60), 90)

local _, _, cMoedas = placa(topo, 150, 52)
local moeda = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 26, 0.5, 0), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1, Parent = cMoedas })
corner(moeda, 999)
new("UIStroke", { Color = Color3.fromRGB(230, 130, 30), Thickness = 2, Parent = moeda })
label(moeda, "$", 15, Color3.fromRGB(240, 145, 40), { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack })
local txtMoedas = label(cMoedas, "0", 22, BRANCO, { Position = UDim2.fromOffset(62, 0), Size = UDim2.new(1, -78, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack })

local _, _, cGemas = placa(topo, 124, 52)
if EconomyData.Gems.IconId ~= "" then
	-- ícone oficial das Gemas do Rikudou (imagem enviada ao Roblox)
	iconeGema(cGemas, UDim2.fromOffset(34, 34), UDim2.new(0, 19, 0.5, -17))
else
	local hexa = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 24, 0.5, 0), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, Parent = cGemas })
	for i = 0, 2 do -- hexágono = 3 retângulos girados
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(13, 22), Rotation = i * 60, BackgroundColor3 = Color3.fromRGB(150, 24, 24), BorderSizePixel = 0, Parent = hexa })
	end
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(7, 12), BackgroundColor3 = Color3.fromRGB(215, 60, 50), BorderSizePixel = 0, Parent = hexa })
end
local txtGemas = label(cGemas, "0", 22, BRANCO, { Position = UDim2.fromOffset(60, 0), Size = UDim2.new(1, -72, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack })

local quadroMais, _, cMais = placa(topo, 52, 44, Color3.fromRGB(42, 42, 46))
local maisGemas = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = cMais })
traco(cMais, UDim2.fromOffset(16, 2), P(0, 0))
traco(cMais, UDim2.fromOffset(2, 16), P(0, 0))
maisGemas.Activated:Connect(function() som("Clique") end)

local function contar(n)
	if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
	if n >= 1e4 then return string.format("%.1fK", n / 1e3) end
	return tostring(n)
end

local function atualizarTopo()
	local lv = stats.Level.Value
	local xp = stats.XP.Value
	local need = lv >= CharacterData.MaxLevel and 1 or CharacterData.XPForLevel(lv)
	txtNivel.Text = tostring(lv)
	txtNivelNome.Text = "LEVEL " .. lv
	txtXP.Text = lv >= CharacterData.MaxLevel and "MAX" or ("%s / %s XP"):format(contar(xp), contar(need))
	tween(fillXP, 0.3, { Size = UDim2.fromScale(math.clamp(xp / need, 0, 1), 1) })
	txtMoedas.Text = contar(stats.Coins.Value)
	txtGemas.Text = contar(player:GetAttribute("Gems") or 0)
end
for _, v in ipairs(stats:GetChildren()) do v.Changed:Connect(atualizarTopo) end
player:GetAttributeChangedSignal("Gems"):Connect(atualizarTopo)
atualizarTopo()

---------------------------------------------------------------
-- Menu lateral e painel central
---------------------------------------------------------------
local menu = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 26, 0.5, 44), Size = UDim2.fromOffset(120, 500), BackgroundTransparency = 1, Parent = raiz })
new("UIListLayout", { Padding = UDim.new(0, 12), VerticalAlignment = Enum.VerticalAlignment.Center, Parent = menu })
new("UIScale", { Scale = 0.8, Parent = menu })

-- seta ao lado do menu: esconde e mostra os botões
local MENU_X = 26
-- fica em cima do primeiro botão do menu, pequena; só gira ao esconder/mostrar
local setaQuadro, _, cSeta = placa(raiz, 30, 20, PLACA, { Name = "SetaMenu", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, MENU_X + 2, 0.5, 44 - 196) })
local chevron = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(12, 14), BackgroundTransparency = 1, Parent = cSeta })
traco(chevron, UDim2.fromOffset(7, 2), UDim2.new(0.5, 0, 0.5, -2), -45)
traco(chevron, UDim2.fromOffset(7, 2), UDim2.new(0.5, 0, 0.5, 2), 45)
local botaoSeta = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = cSeta })
local menuAberto = true
botaoSeta.Activated:Connect(function()
	som("Clique")
	menuAberto = not menuAberto
	tween(menu, 0.25, { Position = UDim2.new(0, menuAberto and MENU_X or -110, 0.5, 44) })
	tween(chevron, 0.25, { Rotation = menuAberto and 0 or 180 })
end)

local painel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53), Size = UDim2.fromOffset(800, 500),
	BackgroundColor3 = COR.painel, BackgroundTransparency = 0.03, Visible = false, Parent = raiz, ZIndex = 5,
})
corner(painel, 6)
stroke(painel, COR.linha, 1.5)
new("Frame", { Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = VERMELHO_HUD, BorderSizePixel = 0, Parent = painel })
local painelEscala = new("UIScale", { Parent = painel })
local tituloPainel = label(painel, "", 18, COR.texto, { Position = UDim2.fromOffset(24, 14), Size = UDim2.new(1, -100, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold, ZIndex = 6 })
local fecharPainel = new("TextButton", { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -52, 0, 12), BackgroundColor3 = Color3.fromRGB(38, 38, 42), Text = "", AutoButtonColor = false, Parent = painel, ZIndex = 6 })
corner(fecharPainel, 4)
stroke(fecharPainel, COR.linha, 1.5)
traco(fecharPainel, UDim2.fromOffset(18, 2), P(0, 0), 45)
traco(fecharPainel, UDim2.fromOffset(18, 2), P(0, 0), -45)
fecharPainel.Activated:Connect(function() som("Clique") end)
local conteudo = new("Frame", { Position = UDim2.fromOffset(20, 62), Size = UDim2.new(1, -40, 1, -80), BackgroundTransparency = 1, Parent = painel, ZIndex = 6 })

local telas = {}
local telaAtual
local botoesMenu = {}

local function realcar(nome)
	for n, b in pairs(botoesMenu) do
		local ativo = n == nome
		tween(b.borda, 0.15, { Color = ativo and Color3.fromRGB(200, 60, 50) or BORDA, Thickness = ativo and 2 or 1.5 })
		tween(b.texto, 0.15, { TextColor3 = ativo and BRANCO or Color3.fromRGB(120, 120, 128) })
	end
end

local function abrirTela(nome)
	if telaAtual == nome and painel.Visible then
		painel.Visible = false
		telaAtual = nil
		realcar(nil)
		return
	end
	for n, t in pairs(telas) do
		t.frame.Visible = (n == nome)
	end
	telaAtual = nome
	tituloPainel.Text = espacado(telas[nome].titulo)
	painel.Visible = true
	painelEscala.Scale = 0.9
	tween(painelEscala, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	realcar(nome)
	if telas[nome].abrir then
		task.spawn(telas[nome].abrir)
	end
end
fecharPainel.Activated:Connect(function()
	painel.Visible = false
	telaAtual = nil
	realcar(nil)
end)

local function novaTela(nome, titulo)
	local f = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = conteudo })
	telas[nome] = { frame = f, titulo = titulo }
	local quadro, _, c, borda = placa(menu, 106, 86, PLACA, { Name = "Menu_" .. nome })
	local area = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 3, 0, 14), Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1, Parent = c })
	DESENHOS[nome](area)
	local texto = label(c, espacado(titulo), 9, Color3.fromRGB(120, 120, 128), { Position = UDim2.new(0, 4, 1, -30), Size = UDim2.new(1, -4, 0, 20), Font = Enum.Font.GothamMedium })
	local badge = new("Frame", { Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -18, 0, -6), BackgroundColor3 = Color3.fromRGB(190, 30, 30), Visible = false, Parent = c })
	corner(badge, 10)
	local badgeTxt = label(badge, "", 11, BRANCO, { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack })
	local b = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = c })
	local sc = new("UIScale", { Parent = quadro })
	b.MouseEnter:Connect(function() tween(sc, 0.12, { Scale = 1.06 }) end)
	b.MouseLeave:Connect(function() tween(sc, 0.12, { Scale = 1 }) end)
	b.Activated:Connect(function()
		som("Clique")
		abrirTela(nome)
	end)
	botoesMenu[nome] = { borda = borda, badge = badge, badgeTxt = badgeTxt, texto = texto }
	return f
end

local function marcar(nome, n)
	local b = botoesMenu[nome]
	if not b then return end
	b.badge.Visible = n > 0
	b.badgeTxt.Text = n > 9 and "9+" or tostring(n)
end

local function rolagem(parent, size, pos)
	local s = new("ScrollingFrame", {
		Size = size, Position = pos or UDim2.new(), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		ScrollBarImageColor3 = COR.linha, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = parent,
	})
	return s
end

local function limpar(f)
	for _, c in ipairs(f:GetChildren()) do
		if not c:IsA("UIGridLayout") and not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

-- janela de confirmação
local function confirmar(texto, simTexto, callback)
	local fundo = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Text = "", AutoButtonColor = false, Parent = raiz, ZIndex = 40 })
	local caixa = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(420, 190), BackgroundColor3 = COR.painel, Parent = fundo, ZIndex = 41 })
	corner(caixa, 16)
	stroke(caixa, COR.ouro, 3)
	label(caixa, texto, 18, COR.texto, { Position = UDim2.fromOffset(20, 16), Size = UDim2.new(1, -40, 0, 100), ZIndex = 42 })
	local sim = botao(caixa, simTexto or "Confirm", COR.verde, UDim2.fromOffset(160, 44), UDim2.new(0.5, 10, 1, -62))
	local nao = botao(caixa, "Cancel", COR.vermelho, UDim2.fromOffset(160, 44), UDim2.new(0.5, -170, 1, -62))
	sim.ZIndex, nao.ZIndex = 42, 42
	sim.Activated:Connect(function() fundo:Destroy(); callback() end)
	nao.Activated:Connect(function() fundo:Destroy() end)
end

---------------------------------------------------------------
-- Pergaminho de invocação (no lugar do baú), todo desenhado por código.
-- abertura: 0 = enrolado (rolos juntos, com fita), 1 = todo aberto.
---------------------------------------------------------------
local PAPEL = Color3.fromRGB(242, 228, 190)
local PAPEL_ESC = Color3.fromRGB(200, 176, 128)
local TINTA = Color3.fromRGB(70, 42, 28)
local MADEIRA = Color3.fromRGB(105, 60, 32)
local FAIXA_BASICA = Color3.fromRGB(180, 40, 35)
local FAIXA_RIKUDOU = Color3.fromRGB(120, 50, 200)

local function rolo(parent, h, corFaixa)
	local rw = math.max(8, h * 0.14)
	local r = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(rw, h), BackgroundTransparency = 1, Parent = parent })
	for _, y in ipairs({ 0, 1 }) do -- pontas de madeira
		local ponta = new("Frame", { AnchorPoint = Vector2.new(0.5, y), Position = UDim2.fromScale(0.5, y), Size = UDim2.fromOffset(rw * 0.5, h * 0.08), BackgroundColor3 = MADEIRA, Parent = r })
		corner(ponta, 4)
		new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, MADEIRA:Lerp(Color3.new(0, 0, 0), 0.4)), ColorSequenceKeypoint.new(0.45, MADEIRA:Lerp(Color3.new(1, 1, 1), 0.25)), ColorSequenceKeypoint.new(1, MADEIRA:Lerp(Color3.new(0, 0, 0), 0.5)) }), Parent = ponta })
	end
	local corpo = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, rw * 0.88, 1, -h * 0.14), BackgroundColor3 = PAPEL, Parent = r })
	corner(corpo, math.floor(rw * 0.25))
	new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, PAPEL_ESC:Lerp(Color3.new(0, 0, 0), 0.25)), ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 250, 232)), ColorSequenceKeypoint.new(1, PAPEL_ESC:Lerp(Color3.new(0, 0, 0), 0.35)) }), Parent = corpo })
	for _, y in ipairs({ 0.13, 0.87 }) do -- faixas coloridas com fio dourado
		local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, y), Size = UDim2.fromOffset(rw, math.max(3, h * 0.05)), BackgroundColor3 = corFaixa, Parent = r })
		corner(f, 3)
		new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, corFaixa:Lerp(Color3.new(0, 0, 0), 0.45)), ColorSequenceKeypoint.new(0.45, corFaixa:Lerp(Color3.new(1, 1, 1), 0.3)), ColorSequenceKeypoint.new(1, corFaixa:Lerp(Color3.new(0, 0, 0), 0.5)) }), Parent = f })
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, math.max(1, h * 0.008)), BackgroundColor3 = COR.ouro, BorderSizePixel = 0, Parent = f })
	end
	return r, rw
end

local function desenharPergaminho(parent, W, H, corFaixa, pos, abertura)
	local root = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos or UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, Parent = parent })
	-- brilho atrás (3 círculos suaves)
	local brilhos = {}
	for i, f in ipairs({ 1.5, 1.15, 0.8 }) do
		local b = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(H * f, H * f), BackgroundColor3 = corFaixa, BackgroundTransparency = 0.88 + i * 0.01, Parent = root })
		corner(b, 999)
		table.insert(brilhos, b)
	end
	local rwRef = math.max(8, H * 0.14)
	local largura = W - rwRef
	local hp = H * 0.74
	local papel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, hp), BackgroundColor3 = PAPEL, BorderSizePixel = 0, ClipsDescendants = true, Parent = root })
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 250, 234), PAPEL_ESC), Rotation = 90, Parent = papel })
	local miolo = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(largura, hp), BackgroundTransparency = 1, Parent = papel })
	for _, y in ipairs({ 0, 1 }) do -- bordas vermelhas
		new("Frame", { AnchorPoint = Vector2.new(0, y), Position = UDim2.new(0, 0, y, y == 0 and hp * 0.05 or -hp * 0.05), Size = UDim2.new(1, 0, 0, math.max(1, hp * 0.015)), BackgroundColor3 = Color3.fromRGB(170, 40, 35), BorderSizePixel = 0, Parent = miolo })
	end
	-- selo de invocação no centro
	local tam = hp * 0.66
	local selo = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(tam, tam), BackgroundTransparency = 1, Parent = miolo })
	local aneis = {}
	for i, f in ipairs({ 1, 0.74, 0.4 }) do
		local a = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(f, f), BackgroundTransparency = 1, Parent = selo })
		corner(a, 999)
		table.insert(aneis, new("UIStroke", { Color = TINTA, Thickness = math.max(1, (i == 1 and 3 or 2) * H / 250), Parent = a }))
	end
	local giro = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = selo })
	local marcas = {}
	for i = 0, 11 do
		local ang = math.rad(i * 30)
		local m = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.sin(ang) * tam * 0.435, 0.5, -math.cos(ang) * tam * 0.435), Size = UDim2.fromOffset(math.max(1, tam * 0.03), tam * 0.1), Rotation = i * 30, BackgroundColor3 = TINTA, BorderSizePixel = 0, Parent = giro })
		table.insert(marcas, m)
	end
	local centro = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.14, 0.14), BackgroundColor3 = TINTA, Parent = selo })
	corner(centro, 999)
	-- colunas de escrita (invocação) dos dois lados
	if H >= 80 then
		local escrita = { "召\n喚\n之\n術", "封\n印\n解\n放", "忍\n之\n巻\n物", "天\n命\n力\n与" }
		for i, t in ipairs(escrita) do
			local x = ({ 0.09, 0.21, 0.79, 0.91 })[i]
			label(miolo, t, 14, TINTA, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.5), Size = UDim2.new(0, hp * 0.16, 0.74, 0), TextScaled = true, Font = Enum.Font.GothamBold })
		end
	end
	local esq, rw = rolo(root, H, corFaixa)
	local dir = rolo(root, H, corFaixa)
	-- fita que prende o pergaminho enrolado
	local fita = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(rw * 2.6, math.max(3, H * 0.06)), BackgroundColor3 = Color3.fromRGB(200, 35, 35), Parent = root })
	corner(fita, 3)
	for _, sx in ipairs({ -1, 1 }) do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, sx * rw * 0.25, 0.5, 0), Size = UDim2.fromOffset(math.max(2, H * 0.03), H * 0.28), Rotation = sx * 18, BackgroundColor3 = Color3.fromRGB(200, 35, 35), BorderSizePixel = 0, Parent = fita })
	end
	local obj = { root = root, papel = papel, esq = esq, dir = dir, fita = fita, selo = selo, aneis = aneis, marcas = marcas, centro = centro, giro = giro, brilhos = brilhos }
	function obj.abrir(t, dur, estilo)
		local w = largura * t
		local off = math.max(rw / 2, w / 2)
		local alvoPapel = { Size = UDim2.fromOffset(w, hp) }
		local alvoE = { Position = UDim2.new(0.5, -off, 0.5, 0) }
		local alvoD = { Position = UDim2.new(0.5, off, 0.5, 0) }
		if dur then
			tween(papel, dur, alvoPapel, estilo)
			tween(esq, dur, alvoE, estilo)
			tween(dir, dur, alvoD, estilo)
		else
			papel.Size, esq.Position, dir.Position = alvoPapel.Size, alvoE.Position, alvoD.Position
		end
	end
	obj.abrir(abertura or 0)
	fita.Visible = (abertura or 0) <= 0
	return obj
end

---------------------------------------------------------------
-- 1) CAIXAS
---------------------------------------------------------------
local telaCaixas = novaTela("caixas", "Crates", "🎁", COR.laranja)
local caixasGratis = 0
local animando = false
local abrirCaixa -- definida abaixo

local function cardCaixa(crateId, x, corA, corB, desc)
	local crate = CharacterData.Crates[crateId]
	local card = new("Frame", { Position = UDim2.new(x, x == 0 and 0 or 10, 0, 0), Size = UDim2.new(0.5, -10, 1, 0), BackgroundColor3 = COR.card, Parent = telaCaixas })
	corner(card, 16)
	stroke(card, corA, 3)
	label(card, crate.Name, 24, corA:Lerp(Color3.new(1, 1, 1), 0.3), { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 10), Font = Enum.Font.GothamBlack })
	label(card, desc, 13, COR.fraco, { Size = UDim2.new(1, -30, 0, 34), Position = UDim2.fromOffset(15, 42) })
	local arte = desenharPergaminho(card, 250, 118, crateId == "Rikudou" and FAIXA_RIKUDOU or FAIXA_BASICA, UDim2.new(0.5, 0, 0, 160), 0.6).root
	-- flutuar
	task.spawn(function()
		local t = 0
		while card.Parent do
			t += RunService.Heartbeat:Wait()
			arte.Position = UDim2.new(0.5, 0, 0, 160 + math.sin(t * 2 + x * 3) * 6)
			arte.Rotation = math.sin(t * 1.3 + x) * 3
		end
	end)
	-- chances reais
	local odds = CharacterData.GetCrateOdds(crateId)
	local linhaOdds = new("Frame", { Position = UDim2.new(0, 12, 0, 238), Size = UDim2.new(1, -24, 0, 50), BackgroundTransparency = 1, Parent = card })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4), Parent = linhaOdds })
	for _, o in ipairs(odds) do
		if o.Percent > 0 then
			local chip = new("Frame", { Size = UDim2.fromOffset(66, 46), BackgroundColor3 = COR.fundo, Parent = linhaOdds })
			corner(chip, 8)
			stroke(chip, RAR[o.Id], 2)
			label(chip, o.Name, 11, RAR[o.Id], { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 3), TextScaled = true })
			label(chip, string.format("%g%%", math.floor(o.Percent * 10 + 0.5) / 10), 15, COR.texto, { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 22), Font = Enum.Font.GothamBlack })
		end
	end
	local preco = botao(card, "", crate.Currency == "Gems" and COR.roxo or COR.verde, UDim2.new(1, -40, 0, 50), UDim2.new(0, 20, 1, -120))
	preco.Text = ""
	local icone = crate.Currency == "Gems" and iconeGema(preco, UDim2.fromOffset(40, 40), UDim2.new(0.5, -70, 0, 5)) or iconeMoeda(preco, UDim2.fromOffset(28, 28), UDim2.new(0.5, -64, 0, 11))
	icone.ZIndex = preco.ZIndex + 1
	label(preco, "OPEN  ·  " .. crate.Cost, 18, Color3.new(1, 1, 1), { Size = UDim2.new(1, 0, 1, 0), Position = UDim2.fromOffset(22, 0), Font = Enum.Font.GothamBlack })
	preco.Activated:Connect(function() abrirCaixa(crateId, false) end)
	local gratis
	if crateId == "Basica" then
		gratis = botao(card, "OPEN FREE", COR.ouro, UDim2.new(1, -40, 0, 44), UDim2.new(0, 20, 1, -62))
		gratis.TextColor3 = Color3.fromRGB(80, 40, 0)
		gratis.Activated:Connect(function() abrirCaixa(crateId, true) end)
	else
		label(card, "Rikudou Gems: Robux or Battle Pass only", 12, COR.fraco, { Size = UDim2.new(1, -30, 0, 40), Position = UDim2.new(0, 15, 1, -58) })
	end
	return gratis
end

local botaoGratis = cardCaixa("Basica", 0, Color3.fromRGB(230, 120, 40), Color3.fromRGB(150, 60, 20), "Spend coins earned in runs. Epic or better guaranteed every 20 crates.")
cardCaixa("Rikudou", 0.5, Color3.fromRGB(255, 170, 50), Color3.fromRGB(120, 50, 200), "Never Common. Shown chances already count only characters that exist.")

local function atualizarGratis()
	botaoGratis.Text = caixasGratis > 0 and ("OPEN FREE  (x%d)"):format(caixasGratis) or "NO FREE CRATES"
	botaoGratis.BackgroundColor3 = caixasGratis > 0 and COR.ouro or Color3.fromRGB(90, 85, 110)
	marcar("caixas", caixasGratis)
end

-- animação da abertura: o pergaminho balança enrolado, a fita arrebenta, ele se desenrola
-- e o selo acende na cor da raridade antes de revelar o personagem
local function animarAbertura(crateId, r, deNovo)
	animando = true
	local cor = RAR[r.rarity] or Color3.new(1, 1, 1)
	local idx = CharacterData.GetRarityIndex(r.rarity) or 1
	local corFaixa = crateId == "Rikudou" and FAIXA_RIKUDOU or FAIXA_BASICA

	-- tela própria por cima de tudo, cobrindo também a faixa do topo
	local telaAbertura = new("ScreenGui", { Name = "HUD_Abertura", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20, Parent = gui.Parent })
	local fundo = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 10, 16), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = telaAbertura })
	local palco = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1 / escala.Scale, 1 / escala.Scale), BackgroundTransparency = 1, Parent = fundo })
	new("UIScale", { Scale = escala.Scale, Parent = palco })
	tween(fundo, 0.3, { BackgroundTransparency = 0.45 })
	local acabou = false
	local function fechar()
		if acabou then return end
		acabou = true
		telaAbertura:Destroy()
		animando = false
	end

	-- raios girando atrás (aparecem quando o selo acende)
	local raios = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(760, 760), BackgroundTransparency = 1, Parent = palco })
	local listaRaios = {}
	for i = 0, 11 do
		local rr = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 760), Rotation = i * 15, BackgroundColor3 = cor, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = raios })
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 1) }), Rotation = 90, Parent = rr })
		table.insert(listaRaios, rr)
	end
	task.spawn(function()
		while not acabou do
			raios.Rotation += RunService.RenderStepped:Wait() * (idx >= 4 and 60 or 30)
		end
	end)

	local perg = desenharPergaminho(palco, 580, 250, corFaixa, UDim2.fromScale(0.5, 0.45), 0)
	local escPerg = new("UIScale", { Scale = 0.2, Parent = perg.root })
	tween(escPerg, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	task.wait(0.45)

	-- balança enrolado, cada vez mais forte; o brilho vai pegando a cor da raridade
	for i = 1, 10 do
		local forca = 3 + i * 0.9
		local dur = math.max(0.05, 0.13 - i * 0.007)
		som("Giro", 0.9 + i * 0.06)
		tween(perg.root, dur, { Rotation = (i % 2 == 0) and forca or -forca })
		if i > 4 then
			for k, b in ipairs(perg.brilhos) do
				b.BackgroundColor3 = b.BackgroundColor3:Lerp(cor, 0.3)
				b.BackgroundTransparency = math.max(0.55 + k * 0.08, b.BackgroundTransparency - 0.05)
			end
		end
		task.wait(dur)
	end
	tween(perg.root, 0.12, { Rotation = 0 })

	-- a fita arrebenta e voa
	som("Giro", 1.7)
	tween(perg.fita, 0.45, { Position = UDim2.new(0.5, 40, 0.5, -170), Rotation = 50, BackgroundTransparency = 1 })
	for _, d in ipairs(perg.fita:GetChildren()) do
		if d:IsA("Frame") then tween(d, 0.45, { BackgroundTransparency = 1 }) end
	end
	task.wait(0.2)

	-- desenrola de verdade: os rolos se afastam e o papel aparece do meio para fora
	perg.abrir(1, 0.8, Enum.EasingStyle.Quart)
	task.wait(0.7)

	-- o selo acende na cor da raridade e começa a girar
	som(idx >= 3 and "RevelarRaro" or "Revelar")
	for _, st in ipairs(perg.aneis) do
		tween(st, 0.35, { Color = cor, Thickness = st.Thickness + 2 })
	end
	for _, m in ipairs(perg.marcas) do tween(m, 0.35, { BackgroundColor3 = cor }) end
	tween(perg.centro, 0.35, { BackgroundColor3 = cor })
	task.spawn(function()
		while not acabou do
			perg.giro.Rotation += RunService.RenderStepped:Wait() * 90
		end
	end)
	for _, rr in ipairs(listaRaios) do
		tween(rr, 0.4, { BackgroundTransparency = idx >= 4 and 0.2 or 0.45 })
	end
	-- partículas saindo do selo
	for i = 1, (idx >= 4 and 36 or 20) do
		local p = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(9, 9), Rotation = math.random(0, 90), BackgroundColor3 = (i % 3 == 0) and Color3.new(1, 1, 1) or cor, Parent = palco })
		local ang = math.random() * math.pi * 2
		local dist = math.random(170, 400)
		tween(p, math.random(60, 110) / 100, { Position = UDim2.new(0.5, math.cos(ang) * dist, 0.45, math.sin(ang) * dist), BackgroundTransparency = 1, Rotation = p.Rotation + 360 }, Enum.EasingStyle.Quart)
		task.delay(1.2, function() if p.Parent then p:Destroy() end end)
	end
	if idx >= 4 then -- lendário e místico: a tela treme
		task.spawn(function()
			for _ = 1, 12 do
				palco.Position = UDim2.new(0.5, math.random(-9, 9), 0.5, math.random(-7, 7))
				task.wait(0.03)
			end
			palco.Position = UDim2.fromScale(0.5, 0.5)
		end)
	end
	task.wait(0.45)

	-- o personagem surge do selo, na frente do pergaminho
	local card = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(290, 340), BackgroundColor3 = COR.card, Parent = palco })
	corner(card, 10)
	local borda = stroke(card, cor, 4)
	grad(card, cor:Lerp(COR.card, 0.6), COR.fundo, 90)
	local escCard = new("UIScale", { Scale = 0, Parent = card })
	tween(escCard, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	task.spawn(function()
		while card.Parent do
			tween(borda, 0.6, { Transparency = 0.5 })
			task.wait(0.6)
			tween(borda, 0.6, { Transparency = 0 })
			task.wait(0.6)
		end
	end)
	label(card, (RARNOME[r.rarity] or r.rarity):upper(), 26, cor, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 12), Font = Enum.Font.GothamBlack })
	local retrato = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.fromOffset(130, 130), BackgroundColor3 = cor, Parent = card })
	corner(retrato, 999)
	grad(retrato, cor:Lerp(Color3.new(1, 1, 1), 0.35), cor:Lerp(Color3.new(0, 0, 0), 0.4), 120)
	stroke(retrato, Color3.new(1, 1, 1), 4)
	label(retrato, r.name:sub(1, 1), 70, Color3.new(1, 1, 1), { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack })
	label(card, r.name, 28, COR.texto, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 196), Font = Enum.Font.GothamBlack })
	local tag = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 240), Size = UDim2.fromOffset(160, 32), BackgroundColor3 = r.isNew and COR.verde or COR.azul, Parent = card })
	corner(tag, 6)
	label(tag, r.isNew and "NEW!" or ("COPY  x" .. tostring(r.copies)), 17, Color3.new(1, 1, 1), { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack })
	if not r.isNew then
		label(card, ("Duplicates can be converted in Collection (+%d coins each)"):format(EconomyData.DupeCoins[r.rarity] or 0), 12, COR.fraco, { Size = UDim2.new(1, -30, 0, 34), Position = UDim2.fromOffset(15, 282) })
	end

	task.wait(0.5)
	local ok = botao(palco, "OK", COR.verde, UDim2.fromOffset(160, 48), UDim2.new(0.5, -170, 0.45, 200))
	local outra = botao(palco, "OPEN AGAIN", COR.laranja, UDim2.fromOffset(170, 48), UDim2.new(0.5, 10, 0.45, 200))
	ok.Activated:Connect(fechar)
	outra.Activated:Connect(function()
		fechar()
		deNovo()
	end)
end

abrirCaixa = function(crateId, gratis)
	if animando then return end
	if gratis and caixasGratis <= 0 then
		aviso("You have no free crates. Earn them in the Battle Pass!", COR.vermelho)
		return
	end
	animando = true
	local r = R.OpenCrate:InvokeServer(crateId, gratis)
	if not r or not r.ok then
		animando = false
		aviso(r and r.reason or "Error", COR.vermelho)
		return
	end
	if gratis then
		caixasGratis = math.max(0, caixasGratis - 1)
		atualizarGratis()
	end
	animarAbertura(crateId, r, function() abrirCaixa(crateId, gratis) end)
end

---------------------------------------------------------------
-- 2) COLEÇÃO (personagens e itens)
---------------------------------------------------------------
local telaColecao = novaTela("colecao", "Collection", "📖", COR.azul)
local abaPers = botao(telaColecao, "CHARACTERS", COR.azul, UDim2.fromOffset(170, 36), UDim2.fromOffset(0, 0))
local abaItens = botao(telaColecao, "ITEMS", Color3.fromRGB(90, 85, 110), UDim2.fromOffset(130, 36), UDim2.fromOffset(180, 0))
local resumo = label(telaColecao, "", 15, COR.fraco, { Position = UDim2.fromOffset(330, 0), Size = UDim2.new(1, -330, 0, 36), TextXAlignment = Enum.TextXAlignment.Right })
local gradePers = rolagem(telaColecao, UDim2.new(1, 0, 1, -46), UDim2.fromOffset(0, 46))
new("UIGridLayout", { CellSize = UDim2.fromOffset(176, 236), CellPadding = UDim2.fromOffset(12, 12), Parent = gradePers })
new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), Parent = gradePers })
local listaItens = rolagem(telaColecao, UDim2.new(1, 0, 1, -46), UDim2.fromOffset(0, 46))
listaItens.Visible = false
new("UIListLayout", { Padding = UDim.new(0, 8), Parent = listaItens })
local abaAtual = "pers"
local carregarColecao, carregarItens

local function trocarAba(a)
	abaAtual = a
	gradePers.Visible = a == "pers"
	listaItens.Visible = a == "itens"
	abaPers.BackgroundColor3 = a == "pers" and COR.azul or Color3.fromRGB(90, 85, 110)
	abaItens.BackgroundColor3 = a == "itens" and COR.azul or Color3.fromRGB(90, 85, 110)
	if a == "pers" then carregarColecao() else carregarItens() end
end
abaPers.Activated:Connect(function() trocarAba("pers") end)
abaItens.Activated:Connect(function() trocarAba("itens") end)

carregarColecao = function()
	local r = R.GetCollection:InvokeServer()
	if not r or not r.ok then
		resumo.Text = r and r.reason or ""
		return
	end
	resumo.Text = ("Owned: %d / %d characters   ·   %d copies in total"):format(r.kinds, r.total, r.copiesTotal)
	limpar(gradePers)
	for _, c in ipairs(r.list) do
		local cor = RAR[c.rarity] or Color3.new(1, 1, 1)
		local tem = c.copies > 0
		local card = new("Frame", { BackgroundColor3 = COR.card, Parent = gradePers })
		corner(card, 14)
		stroke(card, tem and cor or COR.linha, 3)
		if tem then grad(card, cor:Lerp(COR.card, 0.7), COR.card, 90) end
		local faixa = new("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = tem and cor or COR.linha, Parent = card })
		corner(faixa, 14)
		label(faixa, (RARNOME[c.rarity] or c.rarity):upper(), 13, Color3.fromRGB(20, 20, 30), { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack })
		local ret = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 34), Size = UDim2.fromOffset(70, 70), BackgroundColor3 = tem and cor or COR.fundo, Parent = card })
		corner(ret, 999)
		stroke(ret, Color3.new(1, 1, 1), tem and 3 or 1, tem and 0 or 0.7)
		label(ret, tem and c.name:sub(1, 1) or "?", 38, Color3.new(1, 1, 1), { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack })
		label(card, tem and c.name or "???", 18, tem and COR.texto or COR.fraco, { Position = UDim2.fromOffset(0, 108), Size = UDim2.new(1, 0, 0, 24), Font = Enum.Font.GothamBlack })
		if tem then
			label(card, ("x%d   ·   HP %d   DMG %d"):format(c.copies, c.health, c.damage), 12, COR.fraco, { Position = UDim2.fromOffset(4, 132), Size = UDim2.new(1, -8, 0, 18) })
			local eq = botao(card, r.equipped == c.id and "EQUIPPED" or "EQUIP", r.equipped == c.id and COR.verde or COR.azul, UDim2.new(1, -20, 0, 32), UDim2.fromOffset(10, 156))
			eq.TextSize = 14
			eq.Activated:Connect(function()
				if r.equipped == c.id then return end
				local e = R.EquipCharacter:InvokeServer(c.id)
				if e and e.ok then
					aviso(c.name .. " equipped!", COR.verde)
					carregarColecao()
				else
					aviso(e and e.reason or "Error", COR.vermelho)
				end
			end)
			if c.copies > 1 then
				local n = c.copies - 1
				local conv = botao(card, ("CONVERT x%d  +%d"):format(n, n * c.dupeCoins), COR.ouro, UDim2.new(1, -20, 0, 32), UDim2.fromOffset(10, 194))
				conv.TextColor3 = Color3.fromRGB(80, 40, 0)
				conv.TextSize = 13
				conv.Activated:Connect(function()
					confirmar(("Delete %d duplicate copies of %s for %d coins?\nYou keep 1 copy."):format(n, c.name, n * c.dupeCoins), "Convert", function()
						local d = R.DeleteDuplicates:InvokeServer(c.id, n)
						if d and d.ok then
							som("Revelar", 1.4)
							aviso(("+%d coins!"):format(d.coins), COR.ouro)
							carregarColecao()
						else
							aviso(d and d.reason or "Error", COR.vermelho)
						end
					end)
				end)
			else
				label(card, "No duplicates", 12, COR.fraco, { Position = UDim2.fromOffset(0, 198), Size = UDim2.new(1, 0, 0, 24) })
			end
		else
			label(card, "Get it in crates", 13, COR.fraco, { Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, 0, 0, 24) })
		end
	end
end

local function tempo(seg)
	seg = math.max(0, seg)
	return string.format("%d:%02d", seg // 60, seg % 60)
end

carregarItens = function()
	local r = R.GetInventory:InvokeServer()
	if not r or not r.ok then return end
	limpar(listaItens)
	caixasGratis = 0
	for _, it in ipairs(r.items) do
		if it.id == "caixa_gratis" then caixasGratis = it.count end
	end
	atualizarGratis()
	-- boosts ativos
	for _, stat in ipairs({ "XP", "Coins" }) do
		local fim = r.boosts[stat]
		if fim > r.now then
			local f = new("Frame", { Size = UDim2.new(1, -10, 0, 40), BackgroundColor3 = COR.verde, BackgroundTransparency = 0.6, Parent = listaItens })
			corner(f, 10)
			local l = label(f, "", 16, COR.texto, { Size = UDim2.fromScale(1, 1) })
			local fimLocal = os.time() + (fim - r.now)
			task.spawn(function()
				while l.Parent and os.time() < fimLocal do
					l.Text = ("2x %s ACTIVE  ·  %s left"):format(stat == "XP" and "XP" or "COINS", tempo(fimLocal - os.time()))
					task.wait(1)
				end
				if f.Parent then f:Destroy() end
			end)
		end
	end
	if #r.items == 0 then
		label(listaItens, "No items yet. Claim Battle Pass rewards to get boosts and accessories!", 16, COR.fraco, { Size = UDim2.new(1, -10, 0, 60) })
	end
	local SLOTNOME = { Cabeca = "Head", Pescoco = "Neck", Aura = "Aura", Rastro = "Trail" }
	for _, it in ipairs(r.items) do
		local f = new("Frame", { Size = UDim2.new(1, -10, 0, 58), BackgroundColor3 = COR.card, Parent = listaItens })
		corner(f, 12)
		local tipo = it.type == "Boost" and "BOOST" or it.type == "Cosmetic" and ("ACCESSORY · " .. (SLOTNOME[it.slot] or "")) or "CRATE"
		local corTipo = it.type == "Boost" and COR.verde or it.type == "Cosmetic" and COR.roxo or COR.laranja
		local chip = new("Frame", { Position = UDim2.fromOffset(10, 14), Size = UDim2.fromOffset(150, 30), BackgroundColor3 = corTipo, Parent = f })
		corner(chip, 8)
		label(chip, tipo, 12, Color3.new(1, 1, 1), { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack, TextScaled = true })
		label(f, it.name .. (it.count > 1 and ("   x" .. it.count) or ""), 18, COR.texto, { Position = UDim2.fromOffset(172, 0), Size = UDim2.new(1, -350, 1, 0), TextXAlignment = Enum.TextXAlignment.Left })
		if it.type == "Boost" then
			local b = botao(f, "USE", COR.verde, UDim2.fromOffset(150, 40), UDim2.new(1, -160, 0, 9))
			b.Activated:Connect(function()
				local u = R.UseItem:InvokeServer(it.id)
				if u and u.ok then
					aviso(it.name .. " activated!", COR.verde)
					carregarItens()
				else
					aviso(u and u.reason or "Error", COR.vermelho)
				end
			end)
		elseif it.type == "Cosmetic" then
			local usando = r.cosmetics[it.slot] == it.id
			local b = botao(f, usando and "REMOVE" or "EQUIP", usando and COR.vermelho or COR.roxo, UDim2.fromOffset(150, 40), UDim2.new(1, -160, 0, 9))
			b.Activated:Connect(function()
				local e = usando and R.EquipCosmetic:InvokeServer(nil, it.slot) or R.EquipCosmetic:InvokeServer(it.id)
				if e and e.ok then
					aviso(usando and "Accessory removed" or (it.name .. " equipped!"), COR.roxo)
					carregarItens()
				else
					aviso(e and e.reason or "Error", COR.vermelho)
				end
			end)
		elseif it.type == "Crate" then
			local b = botao(f, "OPEN", COR.laranja, UDim2.fromOffset(150, 40), UDim2.new(1, -160, 0, 9))
			b.Activated:Connect(function() abrirCaixa("Basica", true) end)
		end
	end
end
telas.colecao.abrir = function() trocarAba(abaAtual) end
telas.caixas.abrir = function()
	local r = R.GetInventory:InvokeServer()
	if r and r.ok then
		caixasGratis = 0
		for _, it in ipairs(r.items) do
			if it.id == "caixa_gratis" then caixasGratis = it.count end
		end
		atualizarGratis()
	end
end

---------------------------------------------------------------
-- 3) BATTLE PASS
---------------------------------------------------------------
local telaPasse = novaTela("passe", "Battle Pass", "🏆", COR.ouro)
local BP = EconomyData.BattlePass
local passeNivel = label(telaPasse, "Level 0 / 50", 22, COR.ouro, { Size = UDim2.fromOffset(260, 30), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack })
local passeBarra = new("Frame", { Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, -220, 0, 22), BackgroundColor3 = COR.fundo, Parent = telaPasse })
corner(passeBarra, 11)
stroke(passeBarra, COR.linha, 2)
local passeFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = COR.ouro, Parent = passeBarra })
corner(passeFill, 11)
grad(passeFill, Color3.fromRGB(255, 230, 120), COR.laranja, 90)
local passeXP = label(passeBarra, "", 13, COR.texto, { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack, ZIndex = 8 })
local resgatarTudo = botao(telaPasse, "CLAIM ALL", COR.verde, UDim2.fromOffset(200, 50), UDim2.new(1, -200, 0, 6))
label(telaPasse, "Earn Battle Pass XP by finishing runs (same XP as your level). Click a glowing reward to claim it.", 13, COR.fraco, { Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, -220, 0, 22), TextXAlignment = Enum.TextXAlignment.Left })
local trilha = new("ScrollingFrame", {
	Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 1, -96), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 8, ScrollBarImageColor3 = COR.ouro, ScrollingDirection = Enum.ScrollingDirection.X,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, Parent = telaPasse,
})
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), VerticalAlignment = Enum.VerticalAlignment.Center, Parent = trilha })
new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = trilha })

local function textoRecompensa(rw)
	local t = {}
	if rw.Character then
		local c = CharacterData.GetCharacter(rw.Character)
		table.insert(t, (c and c.Name or rw.Character) .. " (" .. (c and RARNOME[c.Rarity] or "") .. ")")
	end
	if rw.Gems then table.insert(t, rw.Gems .. " Gems") end
	if rw.Crates then table.insert(t, rw.Crates .. (rw.Crates > 1 and " Crates" or " Crate")) end
	if rw.Item then
		local it = EconomyData.Items[rw.Item]
		table.insert(t, it and it.Name or rw.Item)
	end
	if rw.Coins then table.insert(t, rw.Coins .. " Coins") end
	return table.concat(t, "\n")
end

local function iconeRecompensa(parent, rw)
	local area = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 42), Size = UDim2.fromOffset(60, 60), BackgroundTransparency = 1, Parent = parent })
	if rw.Character then
		local c = CharacterData.GetCharacter(rw.Character)
		local cor = c and RAR[c.Rarity] or COR.ouro
		local f = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = cor, Parent = area })
		corner(f, 999)
		stroke(f, Color3.new(1, 1, 1), 3)
		label(f, c and c.Name:sub(1, 1) or "★", 30, Color3.new(1, 1, 1), { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack })
	elseif rw.Gems then
		iconeGema(area, UDim2.fromScale(1.2, 1.2), UDim2.fromScale(-0.1, -0.1))
	elseif rw.Crates then
		desenharPergaminho(area, 70, 42, FAIXA_BASICA, UDim2.fromScale(0.5, 0.5), 0.5)
	elseif rw.Item then
		local it = EconomyData.Items[rw.Item]
		local f = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = it and it.Type == "Boost" and COR.verde or (it and it.Color) or COR.roxo, Parent = area })
		corner(f, 14)
		stroke(f, Color3.new(1, 1, 1), 3)
		label(f, it and it.Type == "Boost" and "2x" or "✨", 28, Color3.new(1, 1, 1), { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack })
	else
		iconeMoeda(area, UDim2.fromScale(0.85, 0.85), UDim2.fromScale(0.075, 0.075))
	end
end

local celulas = {}
local estadoPasse
local function desenharPasse(s)
	estadoPasse = s
	passeNivel.Text = ("Level %d / %d"):format(s.level, BP.MaxLevel)
	tween(passeFill, 0.4, { Size = UDim2.fromScale(math.clamp(s.xpInLevel / s.perLevel, 0, 1), 1) })
	passeXP.Text = s.level >= BP.MaxLevel and "COMPLETE!" or ("%d / %d XP to level %d"):format(s.xpInLevel, s.perLevel, s.level + 1)
	local pendentes = 0
	for lv = 1, BP.MaxLevel do
		local cel = celulas[lv]
		local liberado = lv <= s.level
		local pego = s.claimed[lv]
		if liberado and not pego then pendentes += 1 end
		cel.estado.Text = pego and "✔ CLAIMED" or (liberado and "CLAIM!" or ("🔒 " .. ((lv * s.perLevel) - s.xp) .. " XP"))
		cel.estado.TextColor3 = pego and COR.verde or (liberado and COR.ouro or COR.fraco)
		cel.escuro.Visible = not liberado
		cel.borda.Color = pego and COR.verde or (liberado and COR.ouro or COR.linha)
		cel.pronto = liberado and not pego
	end
	marcar("passe", pendentes)
	resgatarTudo.Visible = pendentes > 0
end

for lv = 1, BP.MaxLevel do
	local rw = BP.Rewards[lv]
	local especial = rw.Character or rw.Gems or lv == BP.MaxLevel
	local cel = new("TextButton", { Size = UDim2.fromOffset(124, 250), BackgroundColor3 = especial and Color3.fromRGB(62, 46, 30) or COR.card, Text = "", AutoButtonColor = false, LayoutOrder = lv, Parent = trilha })
	corner(cel, 14)
	local borda = stroke(cel, COR.linha, 3)
	local num = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(46, 30), BackgroundColor3 = especial and COR.ouro or COR.linha, Parent = cel })
	corner(num, 10)
	label(num, tostring(lv), 17, especial and Color3.fromRGB(60, 30, 0) or Color3.new(1, 1, 1), { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack })
	iconeRecompensa(cel, rw)
	label(cel, textoRecompensa(rw), 13, COR.texto, { Position = UDim2.fromOffset(6, 110), Size = UDim2.new(1, -12, 0, 90), TextYAlignment = Enum.TextYAlignment.Top })
	local estado = label(cel, "", 13, COR.fraco, { Position = UDim2.new(0, 4, 1, -36), Size = UDim2.new(1, -8, 0, 30), Font = Enum.Font.GothamBlack, TextScaled = true })
	local escuro = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, Parent = cel, ZIndex = 9 })
	corner(escuro, 14)
	estado.ZIndex = 10
	local c = { estado = estado, escuro = escuro, borda = borda, pronto = false }
	celulas[lv] = c
	cel.Activated:Connect(function()
		if not c.pronto then return end
		som("Clique")
		local r = R.ClaimBattlePass:InvokeServer(lv)
		if r and r.ok then
			som("Revelar", 1.2)
			aviso("Claimed: " .. textoRecompensa(rw):gsub("\n", ", "), COR.ouro)
			desenharPasse(r)
		else
			aviso(r and r.reason or "Error", COR.vermelho)
		end
	end)
	-- pulso nas recompensas prontas
	task.spawn(function()
		while cel.Parent do
			if c.pronto then
				tween(borda, 0.5, { Thickness = 5 })
				task.wait(0.5)
				tween(borda, 0.5, { Thickness = 3 })
				task.wait(0.5)
			else
				task.wait(0.5)
			end
		end
	end)
end

resgatarTudo.Activated:Connect(function()
	local r = R.ClaimBattlePass:InvokeServer("all")
	if r and r.ok then
		som("RevelarRaro")
		aviso(("Claimed %d rewards!"):format(#r.granted), COR.ouro)
		desenharPasse(r)
	else
		aviso(r and r.reason or "Error", COR.vermelho)
	end
end)

local function carregarPasse(rolar)
	local s = R.GetBattlePass:InvokeServer()
	if s and s.ok then
		desenharPasse(s)
		if rolar then
			task.wait()
			local alvo = math.max(0, (s.level - 2) * 134)
			trilha.CanvasPosition = Vector2.new(alvo, 0)
		end
	end
end
telas.passe.abrir = function() carregarPasse(true) end
player:GetAttributeChangedSignal("BPXP"):Connect(function() task.spawn(carregarPasse, false) end)

---------------------------------------------------------------
-- 4) LOJA
---------------------------------------------------------------
local telaLoja = novaTela("loja", "Shop", "💎", COR.roxo)
label(telaLoja, "RIKUDOU GEMS", 18, Color3.fromRGB(255, 180, 90), { Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack })
local pacotes = new("Frame", { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 200), BackgroundTransparency = 1, Parent = telaLoja })
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = pacotes })
for i, p in ipairs(EconomyData.GemPacks) do
	local card = new("Frame", { Size = UDim2.fromOffset(230, 200), BackgroundColor3 = COR.card, Parent = pacotes })
	corner(card, 16)
	stroke(card, Color3.fromRGB(255, 170, 60), 3)
	grad(card, Color3.fromRGB(90, 50, 120), COR.card, 90)
	if i == #EconomyData.GemPacks then
		local fita = new("Frame", { Position = UDim2.new(1, -96, 0, 8), Size = UDim2.fromOffset(88, 24), BackgroundColor3 = COR.vermelho, Parent = card })
		corner(fita, 8)
		label(fita, "BEST VALUE", 11, Color3.new(1, 1, 1), { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack })
	end
	local tam = 64 + i * 10
	iconeGema(card, UDim2.fromOffset(tam, tam), UDim2.new(0.5, -tam / 2, 0, 50 - tam / 2 + 24))
	label(card, "+" .. p.Gems, 30, Color3.fromRGB(255, 200, 110), { Position = UDim2.fromOffset(0, 106), Size = UDim2.new(1, 0, 0, 34), Font = Enum.Font.GothamBlack })
	local b = botao(card, "R$ " .. p.Robux, COR.verde, UDim2.new(1, -30, 0, 42), UDim2.new(0, 15, 1, -52))
	b.Activated:Connect(function()
		if p.ProductId == 0 then
			aviso("Gem packs are coming soon!", COR.laranja)
			return
		end
		MarketplaceService:PromptProductPurchase(player, p.ProductId)
	end)
end
label(telaLoja, "STRONG CHARACTERS", 18, COR.ouro, { Position = UDim2.fromOffset(0, 244), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack })
local listaLoja = rolagem(telaLoja, UDim2.new(1, 0, 1, -276), UDim2.fromOffset(0, 274))
new("UIListLayout", { Padding = UDim.new(0, 8), Parent = listaLoja })
for _, s in ipairs(EconomyData.GemShop) do
	local c = CharacterData.GetCharacter(s.Character)
	if c then
		local cor = RAR[c.Rarity]
		local f = new("Frame", { Size = UDim2.new(1, -10, 0, 64), BackgroundColor3 = COR.card, Parent = listaLoja })
		corner(f, 12)
		stroke(f, cor, 2)
		local ret = new("Frame", { Position = UDim2.fromOffset(10, 7), Size = UDim2.fromOffset(50, 50), BackgroundColor3 = cor, Parent = f })
		corner(ret, 999)
		label(ret, c.Name:sub(1, 1), 26, Color3.new(1, 1, 1), { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack })
		label(f, c.Name .. "   ·   " .. RARNOME[c.Rarity], 18, COR.texto, { Position = UDim2.fromOffset(72, 6), Size = UDim2.new(1, -280, 0, 26), TextXAlignment = Enum.TextXAlignment.Left })
		label(f, c.Ability, 12, COR.fraco, { Position = UDim2.fromOffset(72, 32), Size = UDim2.new(1, -280, 0, 24), TextXAlignment = Enum.TextXAlignment.Left })
		local b = botao(f, "", COR.roxo, UDim2.fromOffset(180, 44), UDim2.new(1, -190, 0, 10))
		iconeGema(b, UDim2.fromOffset(38, 38), UDim2.fromOffset(12, 3))
		label(b, tostring(s.Price), 20, Color3.new(1, 1, 1), { Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -40, 1, 0), Font = Enum.Font.GothamBlack })
		b.Activated:Connect(function()
			confirmar(("Buy %s (%s) for %d Rikudou Gems?"):format(c.Name, RARNOME[c.Rarity], s.Price), "Buy", function()
				local r = R.BuyWithGems:InvokeServer(s.Character)
				if r and r.ok then
					som("RevelarRaro")
					aviso(c.Name .. (r.isNew and " unlocked!" or (" copy x" .. r.copies)), COR.ouro)
				else
					aviso(r and r.reason or "Error", COR.vermelho)
				end
			end)
		end)
	end
end
maisGemas.Activated:Connect(function() abrirTela("loja") end)
R.PurchaseDone.OnClientEvent:Connect(function(info)
	som("RevelarRaro")
	aviso(("+%d Rikudou Gems! Thank you!"):format(info.gems or 0), COR.ouro)
end)

---------------------------------------------------------------
-- 5) CONFIGURAÇÕES
---------------------------------------------------------------
local telaConfig = novaTela("config", "Settings", "⚙", Color3.fromRGB(110, 110, 130))
local cfg = R.GetSettings:InvokeServer() or {}
local padrao = { Music = 0.5, MusicOn = true, SFX = 0.8, SFXOn = true, Sensitivity = 1, FOV = 70, LowGraphics = false }
for k, v in pairs(padrao) do
	if type(cfg[k]) ~= type(v) then cfg[k] = v end
end

local efeitosOriginais = {}
local function aplicarConfig()
	local gm = SoundService:FindFirstChild("Musica")
	local ge = SoundService:FindFirstChild("Efeitos")
	if gm then gm.Volume = cfg.MusicOn and cfg.Music or 0 end
	if ge then ge.Volume = cfg.SFXOn and cfg.SFX or 0 end
	UserInputService.MouseDeltaSensitivity = cfg.Sensitivity
	player:SetAttribute("FOVBase", math.floor(cfg.FOV + 0.5))
	if not player:GetAttribute("Correndo") then
		workspace.CurrentCamera.FieldOfView = cfg.FOV
	end
	-- gráficos leves: desliga efeitos de pós-processamento e sombras
	for _, lugar in ipairs({ Lighting, workspace }) do
		for _, e in ipairs(lugar:GetChildren()) do
			if e:IsA("PostEffect") then
				if efeitosOriginais[e] == nil then efeitosOriginais[e] = e.Enabled end
				e.Enabled = (not cfg.LowGraphics) and efeitosOriginais[e]
			end
		end
	end
	if efeitosOriginais.sombras == nil then efeitosOriginais.sombras = Lighting.GlobalShadows end
	Lighting.GlobalShadows = (not cfg.LowGraphics) and efeitosOriginais.sombras
end

local salvarPendente = false
local function salvar()
	aplicarConfig()
	if salvarPendente then return end
	salvarPendente = true
	task.delay(0.8, function()
		salvarPendente = false
		R.SaveSettings:FireServer(cfg)
	end)
end

local linhasCfg = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = telaConfig })
new("UIListLayout", { Padding = UDim.new(0, 12), Parent = linhasCfg })

local function linhaCfg(titulo, desc)
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = COR.card, Parent = linhasCfg })
	corner(f, 12)
	label(f, titulo, 18, COR.texto, { Position = UDim2.fromOffset(16, 6), Size = UDim2.fromOffset(260, 28), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack })
	label(f, desc, 12, COR.fraco, { Position = UDim2.fromOffset(16, 32), Size = UDim2.fromOffset(260, 24), TextXAlignment = Enum.TextXAlignment.Left })
	return f
end

local function interruptor(parent, chave, pos, onChange)
	local b = new("TextButton", { Position = pos, Size = UDim2.fromOffset(70, 34), Text = "", AutoButtonColor = false, Parent = parent })
	corner(b, 17)
	local bola = new("Frame", { Size = UDim2.fromOffset(28, 28), BackgroundColor3 = Color3.new(1, 1, 1), Parent = b })
	corner(bola, 14)
	local txt = label(b, "", 11, Color3.new(1, 1, 1), { Size = UDim2.new(1, -8, 1, 0), Font = Enum.Font.GothamBlack })
	local function desenhar()
		local on = cfg[chave]
		tween(b, 0.15, { BackgroundColor3 = on and COR.verde or Color3.fromRGB(90, 85, 110) })
		tween(bola, 0.15, { Position = on and UDim2.fromOffset(39, 3) or UDim2.fromOffset(3, 3) })
		txt.Text = on and "ON" or "OFF"
		txt.Position = on and UDim2.fromOffset(4, 0) or UDim2.fromOffset(30, 0)
		txt.Size = UDim2.new(0, 36, 1, 0)
	end
	b.Activated:Connect(function()
		som("Clique")
		cfg[chave] = not cfg[chave]
		desenhar()
		if onChange then onChange() end
		salvar()
	end)
	desenhar()
end

local function deslizante(parent, chave, minV, maxV, pos, largura, fmt)
	local trilho = new("Frame", { Position = pos, Size = UDim2.fromOffset(largura, 10), BackgroundColor3 = COR.fundo, Parent = parent })
	corner(trilho, 5)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = COR.laranja, Parent = trilho })
	corner(fill, 5)
	local pino = new("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = Color3.new(1, 1, 1), Text = "", AutoButtonColor = false, Parent = trilho })
	corner(pino, 13)
	stroke(pino, COR.laranja, 3)
	local valor = label(parent, "", 16, COR.ouro, { Position = pos + UDim2.fromOffset(largura + 14, -10), Size = UDim2.fromOffset(70, 30), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left })
	local function desenhar()
		local t = (cfg[chave] - minV) / (maxV - minV)
		fill.Size = UDim2.fromScale(t, 1)
		pino.Position = UDim2.fromScale(t, 0.5)
		valor.Text = fmt(cfg[chave])
	end
	local arrastando = false
	local function mover(x)
		local t = math.clamp((x - trilho.AbsolutePosition.X) / trilho.AbsoluteSize.X, 0, 1)
		cfg[chave] = minV + (maxV - minV) * t
		desenhar()
		salvar()
	end
	local function comecar(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			arrastando = true
			mover(input.Position.X)
		end
	end
	pino.InputBegan:Connect(comecar)
	trilho.InputBegan:Connect(comecar)
	UserInputService.InputChanged:Connect(function(input)
		if arrastando and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			mover(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			arrastando = false
		end
	end)
	desenhar()
end

local pct = function(v) return math.floor(v * 100 + 0.5) .. "%" end
local l1 = linhaCfg("Music", "Background music in the village and in runs")
interruptor(l1, "MusicOn", UDim2.fromOffset(290, 15))
deslizante(l1, "Music", 0, 1, UDim2.fromOffset(390, 27), 250, pct)
local l2 = linhaCfg("Sound effects", "Crates, buttons and rewards")
interruptor(l2, "SFXOn", UDim2.fromOffset(290, 15))
deslizante(l2, "SFX", 0, 1, UDim2.fromOffset(390, 27), 250, pct)
local l3 = linhaCfg("Camera sensitivity", "How fast the camera turns with the mouse")
deslizante(l3, "Sensitivity", 0.2, 2, UDim2.fromOffset(390, 27), 250, function(v) return string.format("%.1fx", v) end)
local l4 = linhaCfg("Field of view", "Wider view shows more of the battle")
deslizante(l4, "FOV", 60, 90, UDim2.fromOffset(390, 27), 250, function(v) return tostring(math.floor(v + 0.5)) end)
local l5 = linhaCfg("Low graphics", "Turns off glow, blur and shadows (faster on phones)")
interruptor(l5, "LowGraphics", UDim2.fromOffset(290, 15))

---------------------------------------------------------------
-- Música: vila no lobby, batalha durante a partida (com transição suave)
---------------------------------------------------------------
local musicaLobby = Sons and Sons:FindFirstChild("MusicaLobby")
local musicaBatalha = Sons and Sons:FindFirstChild("MusicaBatalha")
local volLobby = musicaLobby and musicaLobby.Volume or 0.5
local volBatalha = musicaBatalha and musicaBatalha.Volume or 0.5
local function trocarMusica()
	local emPartida = player:GetAttribute("InRun") == true
	local liga, desliga, volLiga = musicaLobby, musicaBatalha, volLobby
	if emPartida then
		liga, desliga, volLiga = musicaBatalha, musicaLobby, volBatalha
	end
	if desliga and desliga.IsPlaying then
		local tw = tween(desliga, 1.2, { Volume = 0 })
		tw.Completed:Once(function()
			if desliga.Volume == 0 then desliga:Stop() end
		end)
	end
	if liga then
		if not liga.IsPlaying then
			liga.Volume = 0
			liga:Play()
		end
		tween(liga, 1.5, { Volume = volLiga })
	end
end

---------------------------------------------------------------
-- Lobby x partida: menu e painel somem durante a partida
---------------------------------------------------------------
local function aplicarLobby()
	local emPartida = player:GetAttribute("InRun") == true
	menu.Visible = not emPartida
	setaQuadro.Visible = not emPartida
	if emPartida then
		painel.Visible = false
		telaAtual = nil
	end
	trocarMusica()
end
player:GetAttributeChangedSignal("InRun"):Connect(aplicarLobby)

aplicarConfig()
aplicarLobby()
task.spawn(function()
	carregarPasse(false)
	telas.caixas.abrir()
end)
player:GetAttributeChangedSignal("ItemsRev"):Connect(function()
	task.spawn(telas.caixas.abrir)
	if telaAtual == "colecao" and abaAtual == "itens" then task.spawn(carregarItens) end
end)
player:GetAttributeChangedSignal("OwnedRev"):Connect(function()
	if telaAtual == "colecao" and abaAtual == "pers" then task.spawn(carregarColecao) end
end)

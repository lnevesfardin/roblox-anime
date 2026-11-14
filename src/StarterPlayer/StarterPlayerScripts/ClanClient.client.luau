-- LocalScript: StarterPlayerScripts > ClanClient
-- Sala de criação do ninja (abre sozinha para quem ainda não tem clã, Kekkei Genkai ou natureza): abas CLAN,
-- BLOODLINE (Kekkei Genkai, giro único) e NATURE (naturezas de chakra), todas no mesmo painel; escolha de estatura,
-- botão do clã na lateral e a visão do clã Byakugan (inimigos destacados através das paredes).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local ClanData = require(ReplicatedStorage:WaitForChild("ClanData"))
local KekkeiData = require(ReplicatedStorage:WaitForChild("KekkeiData"))
local NatureData = require(ReplicatedStorage:WaitForChild("NatureData"))
local HttpService = game:GetService("HttpService")
local kekkeiAcao = ReplicatedStorage:WaitForChild("KekkeiAcao")
local naturezaAcao = ReplicatedStorage:WaitForChild("NaturezaAcao")
local Vinheta = require(ReplicatedStorage:WaitForChild("Vinheta"))
local MissionDataOk, MissionData = pcall(require, ReplicatedStorage:WaitForChild("MissionData"))
local action = ReplicatedStorage:WaitForChild("ClanAction")
local player = Players.LocalPlayer

local COR = {
	painel = Color3.fromRGB(20, 20, 23),
	card = Color3.fromRGB(30, 30, 34),
	linha = Color3.fromRGB(58, 58, 64),
	texto = Color3.fromRGB(240, 240, 244),
	fraco = Color3.fromRGB(176, 176, 188),
	laranja = Color3.fromRGB(255, 140, 40),
	verde = Color3.fromRGB(70, 190, 110),
	vermelho = Color3.fromRGB(215, 70, 70),
}

local function new(classe, props)
	local o = Instance.new(classe)
	for k, v in pairs(props) do
		if k ~= "Parent" then o[k] = v end
	end
	o.Parent = props.Parent
	return o
end
local function corner(o, r) new("UICorner", { CornerRadius = UDim.new(0, r), Parent = o }) end
local function stroke(o, cor, t) return new("UIStroke", { Color = cor, Thickness = t or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o }) end
local function label(parent, texto, tam, cor, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = texto, TextSize = tam, TextColor3 = cor or COR.texto, Font = Enum.Font.GothamBold, TextWrapped = true, Parent = parent })
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end
local function botao(parent, texto, cor, size, pos)
	local b = new("TextButton", { Size = size, Position = pos, BackgroundColor3 = cor, Text = texto, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBlack, TextSize = 16, AutoButtonColor = true, Parent = parent })
	corner(b, 10)
	return b
end

local gui = new("ScreenGui", { Name = "ClaUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 15, Parent = player:WaitForChild("PlayerGui") })

-- espera os dados do jogador carregarem no servidor
local estado
repeat
	local r = action:InvokeServer("estado")
	estado = r and r.estado
	if not estado then task.wait(0.5) end
until estado

---------------------------------------------------------------
-- Botão do clã (lateral esquerda)
---------------------------------------------------------------
local badge = new("TextButton", { Size = UDim2.fromOffset(132, 40), BackgroundColor3 = COR.painel, Text = "", AutoButtonColor = true, Parent = gui })
corner(badge, 10)
local badgeStroke = stroke(badge, COR.linha, 2)
-- fica logo abaixo da barra de nível do HUD (mesma escala do HUD)
local badgeEscala = new("UIScale", { Parent = badge })
local function posicionarBadge()
	local v = workspace.CurrentCamera.ViewportSize
	local sc = require(game:GetService("ReplicatedStorage"):WaitForChild("HudEscala")).Hud(v) -- mesma escala do HUD
	badgeEscala.Scale = sc
	badge.Position = UDim2.fromOffset(16 * sc, game:GetService("GuiService"):GetGuiInset().Y + 80 * sc)
end
posicionarBadge()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(posicionarBadge)
local badgeSimbolo = label(badge, "?", 20, COR.texto, { Size = UDim2.fromOffset(36, 40) })
local badgeNome = label(badge, "CLAN", 14, COR.texto, { Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -42, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack })

---------------------------------------------------------------
-- Painel
---------------------------------------------------------------
local fundo = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Text = "", AutoButtonColor = false, Visible = false, Parent = gui })
-- painel encostado na esquerda: o lado direito da tela fica livre para o personagem dentro da sala
local painel = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 20, 0.5, 0), Size = UDim2.fromOffset(660, 506), BackgroundColor3 = COR.painel, Parent = fundo })
corner(painel, 18)
stroke(painel, COR.laranja, 3)
local escala = new("UIScale", { Parent = painel })
local function ajustarEscala()
	local vp = workspace.CurrentCamera.ViewportSize
	escala.Scale = math.clamp(math.min(vp.X * 0.52 / 660, vp.Y / 560), 0.4, 1.1) -- ocupa no máximo metade da largura
end
ajustarEscala()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajustarEscala)

local tituloPainel = label(painel, "CLAN ROULETTE", 26, COR.texto, { Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 32), Font = Enum.Font.GothamBlack })
local sub = label(painel, "", 14, COR.fraco, { Position = UDim2.fromOffset(20, 84), Size = UDim2.new(1, -40, 0, 20) })
local fechar = botao(painel, "X", COR.card, UDim2.fromOffset(36, 36), UDim2.new(1, -48, 0, 12))

-- cada aba tem um "conteúdo" do tamanho do painel; só o da aba aberta fica visível
local function conteudo(nome)
	return new("Frame", { Name = nome, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = painel })
end
local contCla, contKekkei, contNatureza = conteudo("AbaCla"), conteudo("AbaKekkei"), conteudo("AbaNatureza")
contKekkei.Visible, contNatureza.Visible = false, false

-- cartão grande do resultado
local grande = new("Frame", { Position = UDim2.fromOffset(20, 112), Size = UDim2.fromOffset(250, 250), BackgroundColor3 = COR.card, Parent = contCla })
corner(grande, 14)
local grandeStroke = stroke(grande, COR.linha, 3)
local gSimbolo = label(grande, "?", 86, COR.texto, { Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 110) })
local gNome = label(grande, "", 26, COR.texto, { Position = UDim2.fromOffset(0, 128), Size = UDim2.new(1, 0, 0, 30), Font = Enum.Font.GothamBlack })
local gRaridade = label(grande, "", 15, COR.fraco, { Position = UDim2.fromOffset(0, 158), Size = UDim2.new(1, 0, 0, 20) })
local gTraco = label(grande, "", 14, COR.texto, { Position = UDim2.fromOffset(12, 182), Size = UDim2.new(1, -24, 0, 56) })

-- lista de opções sorteadas
local lista = new("Frame", { Position = UDim2.fromOffset(286, 112), Size = UDim2.fromOffset(354, 250), BackgroundTransparency = 1, Parent = contCla })
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = lista })

local girarBtn = botao(contCla, "SPIN", COR.laranja, UDim2.fromOffset(250, 48), UDim2.fromOffset(20, 374))
local manterBtn = botao(contCla, "KEEP MY CLAN", COR.card, UDim2.fromOffset(354, 48), UDim2.fromOffset(286, 374))
-- CONTINUE: canto inferior direito da tela; aparece quando o clã já foi escolhido
local continuar = botao(fundo, "CONTINUE", COR.laranja, UDim2.fromOffset(230, 58), UDim2.new(1, -24, 1, -24))
continuar.AnchorPoint = Vector2.new(1, 1)
continuar.TextSize = 22
continuar.Visible = false
local faltaTxt = label(fundo, "", 16, COR.texto, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -24), Size = UDim2.fromOffset(420, 58),
	TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBlack, TextStrokeTransparency = 0.4 })
local aviso = label(painel, "", 14, COR.vermelho, { Position = UDim2.fromOffset(20, 426), Size = UDim2.new(1, -40, 0, 18) })

-- estatura
label(painel, "HEIGHT", 14, COR.fraco, { Position = UDim2.fromOffset(20, 456), Size = UDim2.fromOffset(80, 34), TextXAlignment = Enum.TextXAlignment.Left })
local menosBtn = botao(painel, "-", COR.card, UDim2.fromOffset(44, 34), UDim2.fromOffset(100, 456))
local alturaTxt = label(painel, "1.00", 18, COR.texto, { Position = UDim2.fromOffset(150, 456), Size = UDim2.fromOffset(70, 34), Font = Enum.Font.GothamBlack })
local maisBtn = botao(painel, "+", COR.card, UDim2.fromOffset(44, 34), UDim2.fromOffset(226, 456))
menosBtn.TextSize, maisBtn.TextSize = 22, 22
local alturaDica = label(painel, "", 13, COR.fraco, { Position = UDim2.fromOffset(282, 456), Size = UDim2.fromOffset(358, 34), TextXAlignment = Enum.TextXAlignment.Left })
local function mostrarAltura()
	local a = estado.Altura
	alturaTxt.Text = string.format("%.2f", a)
	-- no limite o botão fica apagado
	menosBtn.BackgroundTransparency = a <= ClanData.HEIGHT_MIN + 0.001 and 0.6 or 0
	maisBtn.BackgroundTransparency = a >= ClanData.HEIGHT_MAX - 0.001 and 0.6 or 0
	alturaDica.Text = a <= ClanData.HEIGHT_MIN + 0.001 and "Minimum height" or a >= ClanData.HEIGHT_MAX - 0.001 and "Maximum height" or "Shorter or taller: small effect on gameplay"
end
local function mudarAltura(delta)
	local alvo = math.clamp(estado.Altura + delta, ClanData.HEIGHT_MIN, ClanData.HEIGHT_MAX)
	if math.abs(alvo - estado.Altura) < 0.001 then return end
	local r = action:InvokeServer("altura", alvo)
	if r and r.estado then
		estado = r.estado
		mostrarAltura()
	end
end
menosBtn.MouseButton1Click:Connect(function() mudarAltura(-ClanData.HEIGHT_STEP) end)
maisBtn.MouseButton1Click:Connect(function() mudarAltura(ClanData.HEIGHT_STEP) end)

local girando = false
local confirmar -- índice esperando segundo clique (troca de clã)

local function mostrarGrande(id)
	local c = id and ClanData.Clans[id]
	if not c then
		gSimbolo.Text, gNome.Text, gRaridade.Text, gTraco.Text = "?", "", "", "Spin to discover your clan."
		grandeStroke.Color = COR.linha
		return
	end
	local rar = ClanData.Rarities[c.Rarity]
	gSimbolo.Text = c.Symbol
	gNome.Text = string.upper(c.Name)
	gNome.TextColor3 = c.Color
	gRaridade.Text = string.upper(rar.Name)
	gRaridade.TextColor3 = rar.Color
	gTraco.Text = c.Trait
	grandeStroke.Color = rar.Color
end

local render
local aba = "cla"
local tudoPronto, atualizarAbas -- definidos mais abaixo (abas BLOODLINE e NATURE)
local function pedir(acao, valor)
	local r = action:InvokeServer(acao, valor)
	if r and r.estado then estado = r.estado end
	aviso.Text = (r and not r.ok and r.erro) or ""
	return r
end

function render(destaque)
	local temCla = estado.Id ~= nil
	local c = temCla and ClanData.Clans[estado.Id]
	-- botão lateral
	badgeSimbolo.Text = c and c.Symbol or "?"
	badgeNome.Text = c and string.upper(c.Name) or "CLAN"
	badgeStroke.Color = c and ClanData.Rarities[c.Rarity].Color or COR.linha
	-- textos
	if aba ~= "cla" then
		-- o texto de cima é da outra aba
	elseif not temCla then
		sub.Text = "You are born into a clan. Spin up to " .. ClanData.FREE_SPINS .. " times and keep the one you like most."
	else
		sub.Text = "Your clan: " .. c.Name .. ". Spin again to try another one."
	end
	girarBtn.Text = estado.Giros > 0 and ("SPIN  (" .. estado.Giros .. " free)") or ("SPIN  (" .. ClanData.RESPIN_GEMS .. " gems)")
	fechar.Visible = false -- quem fecha agora é o CONTINUE
	if atualizarAbas then atualizarAbas() end
	manterBtn.Visible = temCla and #estado.Opcoes > 0
	mostrarAltura()
	mostrarGrande(destaque or estado.Opcoes[#estado.Opcoes] or estado.Id)
	-- opções
	for _, f in ipairs(lista:GetChildren()) do
		if f:IsA("Frame") then f:Destroy() end
	end
	for i, id in ipairs(estado.Opcoes) do
		local cl = ClanData.Clans[id]
		local rar = ClanData.Rarities[cl.Rarity]
		local f = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = COR.card, LayoutOrder = i, Parent = lista })
		corner(f, 8)
		stroke(f, rar.Color, 2)
		label(f, cl.Symbol, 20, COR.texto, { Size = UDim2.fromOffset(40, 36) })
		label(f, cl.Name, 16, cl.Color, { Position = UDim2.fromOffset(42, 0), Size = UDim2.fromOffset(110, 36), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack })
		label(f, rar.Name, 13, rar.Color, { Position = UDim2.fromOffset(150, 0), Size = UDim2.fromOffset(80, 36), TextXAlignment = Enum.TextXAlignment.Left })
		local troca = temCla and estado.Id ~= id
		local b = botao(f, confirmar == i and "CONFIRM?" or "CHOOSE", confirmar == i and COR.vermelho or COR.verde, UDim2.fromOffset(104, 28), UDim2.new(1, -110, 0, 4))
		b.TextSize = 13
		b.MouseEnter:Connect(function() mostrarGrande(id) end)
		b.MouseButton1Click:Connect(function()
			if girando then return end
			if troca and confirmar ~= i then
				-- trocar de clã apaga o caminho do clã atual: pede um segundo clique
				confirmar = i
				render(id)
				aviso.Text = "Switching clans erases your current clan's progress. Click again to confirm."
				return
			end
			confirmar = nil
			pedir("escolher", i)
			render()
		end)
	end
end

girarBtn.MouseButton1Click:Connect(function()
	if girando then return end
	girando = true
	confirmar = nil
	local r = pedir("girar")
	if r and r.ok then
		-- animação: passa rápido pelos clãs e vai freando até parar no sorteado
		local espera = 0.05
		for n = 1, 22 do
			mostrarGrande(ClanData.Order[(n - 1) % #ClanData.Order + 1])
			task.wait(espera)
			if n > 12 then espera += 0.025 end
		end
		mostrarGrande(r.clan)
		grande.Size = UDim2.fromOffset(230, 230)
		TweenService:Create(grande, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(250, 250) }):Play()
		render(r.clan)
		-- vinheta de revelação do clã
		local c = ClanData.Clans[r.clan]
		if c then
			Vinheta.Revelar(c.Name .. " Clan", ClanData.Rarities[c.Rarity].Name, c.Color, c.Rarity == "Legendary" or c.Rarity == "Epic")
		end
	else
		render()
		aviso.Text = (r and r.erro) or "Could not spin."
	end
	girando = false
end)

manterBtn.MouseButton1Click:Connect(function()
	if girando then return end
	confirmar = nil
	pedir("manter")
	render()
end)

fechar.MouseButton1Click:Connect(function()
	fundo.Visible = false
end)
continuar.MouseButton1Click:Connect(function()
	if girando then return end
	fundo.Visible = false
end)
badge.MouseButton1Click:Connect(function()
	local r = action:InvokeServer("estado")
	if r and r.estado then estado = r.estado end
	confirmar = nil
	aviso.Text = ""
	render()
	fundo.Visible = true
end)


---------------------------------------------------------------
-- Abas: CLAN | BLOODLINE (Kekkei Genkai) | NATURE (naturezas de chakra)
-- Tudo acontece neste mesmo painel, sem abrir outra tela por cima.
---------------------------------------------------------------
local ABAS = {
	{ Id = "cla", Nome = "CLAN", Titulo = "CLAN ROULETTE", Cont = contCla },
	{ Id = "kekkei", Nome = "BLOODLINE", Titulo = "BLOODLINE", Cont = contKekkei },
	{ Id = "natureza", Nome = "NATURE", Titulo = "CHAKRA NATURE", Cont = contNatureza },
}
local botoesAba = {}
for i, a in ipairs(ABAS) do
	local b = botao(painel, a.Nome, COR.card, UDim2.fromOffset(200, 32), UDim2.fromOffset(20 + (i - 1) * 210, 46))
	b.TextSize = 15
	local st = stroke(b, COR.linha, 2)
	-- bolinha: vermelha = falta fazer, verde = pronto
	local ponto = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = COR.vermelho, Parent = b })
	corner(ponto, 6)
	botoesAba[a.Id] = { Botao = b, Stroke = st, Ponto = ponto, Aba = a }
end

local function kekkeiFeito() return player:GetAttribute("KekkeiRolou") == true end
local function naturezaFeita() return player:GetAttribute("NaturezaRolou") == true end
local function claFeito() return estado.Id ~= nil and #estado.Opcoes == 0 end
local FEITO = { cla = claFeito, kekkei = kekkeiFeito, natureza = naturezaFeita }

tudoPronto = function()
	return claFeito() and kekkeiFeito() and naturezaFeita()
end

local subAba = {} -- texto de cima de cada aba
local function abrirAba(id)
	if girando then return end
	aba = id
	confirmar = nil
	aviso.Text = ""
	for _, a in ipairs(ABAS) do a.Cont.Visible = a.Id == id end
	render()
end

atualizarAbas = function()
	for id, b in pairs(botoesAba) do
		local feito = FEITO[id]()
		local aberta = aba == id
		b.Botao.BackgroundColor3 = aberta and COR.laranja or COR.card
		b.Stroke.Color = feito and COR.verde or (aberta and COR.laranja or COR.linha)
		b.Ponto.BackgroundColor3 = feito and COR.verde or COR.vermelho
	end
	local a = botoesAba[aba].Aba
	tituloPainel.Text = a.Titulo
	if subAba[aba] then sub.Text = subAba[aba]() end
	continuar.Visible = tudoPronto()
	local falta = {}
	for _, x in ipairs(ABAS) do
		if not FEITO[x.Id]() then table.insert(falta, x.Nome) end
	end
	faltaTxt.Visible = not continuar.Visible and fundo.Visible
	faltaTxt.Text = #falta > 0 and ("STILL TO DO:  " .. table.concat(falta, "  +  ")) or ""
end

for id, b in pairs(botoesAba) do
	b.Botao.MouseButton1Click:Connect(function() abrirAba(id) end)
end

-- cartão grande padrão das abas novas (mesmo formato do cartão do clã)
local function cartao(parent)
	local f = new("Frame", { Position = UDim2.fromOffset(20, 112), Size = UDim2.fromOffset(250, 250), BackgroundColor3 = COR.card, Parent = parent })
	corner(f, 14)
	local st = stroke(f, COR.linha, 3)
	local c = {
		Frame = f, Stroke = st,
		Topo = label(f, "", 12, COR.fraco, { Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 16), Font = Enum.Font.GothamBlack }),
		Simbolo = label(f, "?", 70, COR.texto, { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 86) }),
		Nome = label(f, "", 24, COR.texto, { Position = UDim2.fromOffset(8, 114), Size = UDim2.new(1, -16, 0, 30), Font = Enum.Font.GothamBlack, TextScaled = true }),
		Raridade = label(f, "", 14, COR.fraco, { Position = UDim2.fromOffset(0, 144), Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.GothamBlack, RichText = true }),
		Texto = label(f, "", 13, COR.texto, { Position = UDim2.fromOffset(12, 166), Size = UDim2.new(1, -24, 0, 78), Font = Enum.Font.Gotham, TextYAlignment = Enum.TextYAlignment.Top, RichText = true }),
	}
	new("UITextSizeConstraint", { MaxTextSize = 24, Parent = c.Nome })
	return c
end
local function pulo(c)
	c.Frame.Size = UDim2.fromOffset(230, 230)
	TweenService:Create(c.Frame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(250, 250) }):Play()
end
local function hex(c) return ("#%02X%02X%02X"):format(c.R * 255, c.G * 255, c.B * 255) end

---------------------------------------------------------------
-- Aba BLOODLINE (Kekkei Genkai): um único giro, para sempre
---------------------------------------------------------------
local SIMBOLO_KG = { Gelo = "❄", Lava = "🌋", Fervura = "♨", Tempestade = "🌩", Explosao = "💥", Osso = "🦴", Calor = "☀", Poeira = "💠" }
local kCard = cartao(contKekkei)
local kLista = new("Frame", { Position = UDim2.fromOffset(286, 112), Size = UDim2.fromOffset(354, 250), BackgroundTransparency = 1, Parent = contKekkei })
new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = kLista })
local kBtn = botao(contKekkei, "REVEAL MY BLOODLINE", COR.laranja, UDim2.fromOffset(250, 48), UDim2.fromOffset(20, 374))
label(contKekkei, "Only ONE spin, ever. It can never be spun again, not even with gems.", 13, COR.fraco,
	{ Position = UDim2.fromOffset(286, 374), Size = UDim2.fromOffset(354, 48), TextXAlignment = Enum.TextXAlignment.Left })

local function mostrarKekkei(id, final)
	local k = id and KekkeiData.Tipos[id]
	if k then
		local cr = KekkeiData.Rarities[k.Rarity] or k.Color
		kCard.Topo.Text = final and "YOUR BLOODLINE" or "KEKKEI GENKAI"
		kCard.Simbolo.Text = SIMBOLO_KG[id] or "?"
		kCard.Nome.Text = string.upper(k.Name)
		kCard.Nome.TextColor3 = k.Color
		kCard.Raridade.Text = string.upper(k.Rarity)
		kCard.Raridade.TextColor3 = cr
		kCard.Texto.Text = ("<b>Passive:</b> %s\n<b>Power [%s]:</b> %s, taught later by Lady Tsuna in a mission."):format(k.Passivo, KekkeiData.TECLA, k.Poder.Name)
		kCard.Stroke.Color = cr
	elseif id == false then
		kCard.Topo.Text = final and "YOUR BLOODLINE" or ""
		kCard.Simbolo.Text = "-"
		kCard.Nome.Text = "NO KEKKEI GENKAI"
		kCard.Nome.TextColor3 = COR.fraco
		kCard.Raridade.Text = "COMMON BLOOD"
		kCard.Raridade.TextColor3 = COR.fraco
		kCard.Texto.Text = "Your strength will come from your clan, your training and your chakra natures."
		kCard.Stroke.Color = COR.linha
	else
		kCard.Topo.Text = "KEKKEI GENKAI"
		kCard.Simbolo.Text = "?"
		kCard.Nome.Text = "???"
		kCard.Nome.TextColor3 = COR.texto
		kCard.Raridade.Text = ""
		kCard.Texto.Text = "Some ninjas are born with a rare bloodline. Most are not. Spin to find out."
		kCard.Stroke.Color = COR.linha
	end
end

local function kekkeiAtual()
	local id = player:GetAttribute("Kekkei")
	if type(id) == "string" and KekkeiData.Tipos[id] then return id end
	return kekkeiFeito() and false or nil
end

local function renderKekkei()
	for _, f in ipairs(kLista:GetChildren()) do
		if f:IsA("Frame") then f:Destroy() end
	end
	local meu = kekkeiAtual()
	local linhas = { false }
	for _, id in ipairs(KekkeiData.Order) do table.insert(linhas, id) end
	for i, id in ipairs(linhas) do
		local k = id and KekkeiData.Tipos[id]
		local cr = k and (KekkeiData.Rarities[k.Rarity] or k.Color) or COR.fraco
		local eu = kekkeiFeito() and meu == id
		local f = new("Frame", { Size = UDim2.new(1, 0, 0, 25), BackgroundColor3 = eu and Color3.fromRGB(45, 40, 30) or COR.card, LayoutOrder = i, Parent = kLista })
		corner(f, 6)
		if eu then stroke(f, COR.laranja, 2) end
		label(f, k and (SIMBOLO_KG[id] or "") or "-", 15, COR.texto, { Size = UDim2.fromOffset(30, 25) })
		label(f, k and k.Name or "No Kekkei Genkai", 14, k and k.Color or COR.fraco, { Position = UDim2.fromOffset(32, 0), Size = UDim2.fromOffset(170, 25), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack })
		label(f, k and k.Rarity or "Common", 12, cr, { Position = UDim2.fromOffset(204, 0), Size = UDim2.fromOffset(80, 25), TextXAlignment = Enum.TextXAlignment.Left })
		label(f, (k and k.Weight or KekkeiData.CHANCE_NADA) .. "%", 13, eu and COR.laranja or COR.texto, { Position = UDim2.new(1, -60, 0, 0), Size = UDim2.fromOffset(52, 25), TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBlack })
		-- passar o mouse mostra a linhagem no cartão
		local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = f })
		hit.MouseEnter:Connect(function() if not girando then mostrarKekkei(id, false) end end)
		hit.MouseLeave:Connect(function() if not girando then mostrarKekkei(kekkeiAtual(), true) end end)
	end
	if kekkeiFeito() then
		kBtn.Text = "BLOODLINE REVEALED"
		kBtn.BackgroundColor3 = COR.card
		kBtn.AutoButtonColor = false
	else
		kBtn.Text = "REVEAL MY BLOODLINE"
		kBtn.BackgroundColor3 = COR.laranja
		kBtn.AutoButtonColor = true
	end
	if not girando then mostrarKekkei(kekkeiAtual(), true) end
end
subAba.kekkei = function()
	if not kekkeiFeito() then return "Some ninjas are born with a Kekkei Genkai. You only get ONE chance." end
	local id = kekkeiAtual()
	return id and ("Your bloodline: " .. KekkeiData.Tipos[id].Name .. ". Its power is learned later through a mission.") or "No bloodline this time. Your clan and natures will carry you."
end

kBtn.MouseButton1Click:Connect(function()
	if girando or kekkeiFeito() then return end
	girando = true
	aviso.Text = ""
	kBtn.Text = "..."
	local ok, r = pcall(function() return kekkeiAcao:InvokeServer("girar") end)
	if not ok or not r or (not r.ok and not r.Rolou) then
		girando = false
		aviso.Text = (ok and r and r.erro) or "Could not reach the server. Try again."
		renderKekkei()
		return
	end
	-- passa pelas linhagens e vai freando até parar no resultado
	local nomes = { false }
	for _, id in ipairs(KekkeiData.Order) do table.insert(nomes, id) end
	local t, passo, i = 0, 0.05, 1
	while t < 2.6 do
		mostrarKekkei(nomes[(i % #nomes) + 1], false)
		i += 1
		task.wait(passo)
		t += passo
		passo = math.min(passo * 1.09, 0.32)
	end
	local id = r.Id or false
	mostrarKekkei(id, true)
	pulo(kCard)
	local k = id and KekkeiData.Tipos[id]
	if k then
		Vinheta.Revelar(k.Name, k.Rarity .. " bloodline", k.Color, true)
	else
		Vinheta.Revelar("No Kekkei Genkai", "Common blood", Color3.fromRGB(175, 175, 185), false)
	end
	-- o atributo pode chegar um pouco depois da resposta
	for _ = 1, 20 do
		if kekkeiFeito() then break end
		task.wait(0.1)
	end
	girando = false
	render()
end)

---------------------------------------------------------------
-- Aba NATURE: roleta das naturezas de chakra (1 a 3 + afinidade); girar de novo custa gemas
---------------------------------------------------------------
local SIMBOLO_NAT = { Fogo = "🔥", Vento = "🌪", Raio = "⚡", Terra = "⛰", Agua = "💧" }
-- características de cada natureza (como ela luta)
local CARAC = {
	Fogo = { Estilo = "BURN  +  AREA", Texto = "Raw power. Explosive flames that hit groups and keep burning." },
	Vento = { Estilo = "FAST  +  KNOCKBACK", Texto = "Speed and reach. Quick, cheap cuts that throw enemies back." },
	Raio = { Estilo = "STUN  +  CHAIN", Texto = "Precision. Strikes that stun and jump from enemy to enemy." },
	Terra = { Estilo = "HEAVY  +  CONTROL", Texto = "Defense. Slow, heavy blows that launch and hold enemies." },
	Agua = { Estilo = "PUSH  +  CROWD", Texto = "Flow. Waves that drag enemies and control the battlefield." },
}
local function nomeMestre(t)
	local npc = MissionDataOk and MissionData.NPCs[t.Mestre]
	return npc and npc.Name or "a master"
end

local nCard = cartao(contNatureza)
local nLista = new("Frame", { Position = UDim2.fromOffset(286, 112), Size = UDim2.fromOffset(354, 250), BackgroundTransparency = 1, Parent = contNatureza })
new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = nLista })
local nBtn = botao(contNatureza, "REVEAL MY NATURE", COR.laranja, UDim2.fromOffset(250, 48), UDim2.fromOffset(20, 374))
local nInfo = label(contNatureza, "", 13, COR.fraco, { Position = UDim2.fromOffset(286, 374), Size = UDim2.fromOffset(354, 48), TextXAlignment = Enum.TextXAlignment.Left })

local estadoNat
local function lerNatureza()
	local raw = player:GetAttribute("NaturezaEstado")
	if type(raw) == "string" and raw ~= "" then
		local ok, e = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(e) == "table" then estadoNat = e end
	end
	if not estadoNat then
		local ok, r = pcall(function() return naturezaAcao:InvokeServer("estado") end)
		if ok and r and r.estado then estadoNat = r.estado end
	end
	return estadoNat
end

local function mostrarNatureza(id, modo)
	-- modo: "afinidade" (resultado do jogador), "ver" (mouse em cima) ou "giro" (animação)
	local t = id and NatureData.Tipos[id]
	if not t then
		nCard.Topo.Text = "CHAKRA NATURE"
		nCard.Simbolo.Text = "?"
		nCard.Nome.Text = "???"
		nCard.Nome.TextColor3 = COR.texto
		nCard.Raridade.Text = ""
		nCard.Texto.Text = "Every ninja has an affinity for one nature. A few are born with two or even three."
		nCard.Stroke.Color = COR.linha
		return
	end
	local c = CARAC[id]
	nCard.Simbolo.Text = SIMBOLO_NAT[id] or "?"
	nCard.Nome.Text = string.upper(t.Name) .. " RELEASE"
	nCard.Nome.TextColor3 = t.Color
	nCard.Raridade.Text = c.Estilo
	nCard.Raridade.TextColor3 = t.Color
	nCard.Stroke.Color = t.Color
	if modo == "giro" then
		nCard.Topo.Text = ""
		nCard.Texto.Text = ""
		return
	end
	local e = estadoNat
	local tenho = e and e.Rolou and table.find(e.Lista or {}, id)
	if modo == "afinidade" then
		nCard.Topo.Text = "YOUR AFFINITY"
	else
		nCard.Topo.Text = (e and e.Afinidade == id) and "YOUR AFFINITY" or tenho and "YOU HAVE IT" or "NOT YOURS YET"
	end
	nCard.Texto.Text = ("%s\n<b>Master:</b> %s\n<b>Jutsus:</b> %s, %s"):format(c.Texto, nomeMestre(t), t.Jutsus[1].Name, t.Jutsus[2].Name)
end

local confirmarNatAte = 0
local function renderNatureza()
	local e = estadoNat or lerNatureza()
	for _, f in ipairs(nLista:GetChildren()) do
		if f:IsA("Frame") then f:Destroy() end
	end
	for i, id in ipairs(NatureData.Order) do
		local t = NatureData.Tipos[id]
		local afin = e and e.Rolou and e.Afinidade == id
		local tenho = e and e.Rolou and table.find(e.Lista or {}, id)
		local f = new("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = afin and Color3.fromRGB(45, 40, 30) or COR.card, LayoutOrder = i, Parent = nLista })
		corner(f, 8)
		stroke(f, afin and COR.laranja or tenho and t.Color or COR.linha, afin and 2 or tenho and 2 or 1)
		label(f, SIMBOLO_NAT[id] or "", 22, COR.texto, { Size = UDim2.fromOffset(42, 46) })
		label(f, string.upper(t.Name), 16, tenho and t.Color or COR.fraco, { Position = UDim2.fromOffset(44, 4), Size = UDim2.fromOffset(170, 20), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack })
		label(f, CARAC[id].Estilo, 11, COR.fraco, { Position = UDim2.fromOffset(44, 24), Size = UDim2.fromOffset(190, 16), TextXAlignment = Enum.TextXAlignment.Left })
		local tag, corTag
		if afin then tag, corTag = "AFFINITY", COR.laranja
		elseif tenho then tag, corTag = "OWNED", COR.verde
		elseif e and e.Rolou then tag, corTag = "RARE MISSION", COR.fraco
		else tag, corTag = "?", COR.fraco end
		label(f, tag, 12, corTag, { Position = UDim2.new(1, -112, 0, 0), Size = UDim2.fromOffset(104, 46), TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBlack })
		local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = f })
		hit.MouseEnter:Connect(function() if not girando then mostrarNatureza(id, "ver") end end)
		hit.MouseLeave:Connect(function() if not girando then mostrarNatureza(e and e.Rolou and e.Afinidade or nil, "afinidade") end end)
	end
	local feito = e and e.Rolou
	if not feito then
		nBtn.Text = "REVEAL MY NATURE"
		nBtn.BackgroundColor3 = COR.laranja
		nInfo.Text = ("Your affinity's jutsus deal +%d%% damage and cost %d%% less chakra. The 4th and 5th natures come from rare missions."):format(
			(NatureData.AFIN_DANO - 1) * 100 + 0.5, (1 - NatureData.AFIN_CHAKRA) * 100 + 0.5)
	elseif os.clock() < confirmarNatAte then
		nBtn.Text = "SURE? Jutsus may be lost"
		nBtn.BackgroundColor3 = COR.vermelho
	else
		nBtn.Text = (e.Fichas or 0) > 0 and ("SPIN AGAIN  (" .. e.Fichas .. " free)") or ("SPIN AGAIN  (" .. NatureData.CUSTO_REGIRAR .. " gems)")
		nBtn.BackgroundColor3 = Color3.fromRGB(70, 95, 175) -- cor de gemas: destaca do fundo do painel
		nInfo.Text = "You start with no jutsu: each nature's master teaches its jutsus through missions in the village."
	end
	if not girando then mostrarNatureza(feito and e.Afinidade or nil, "afinidade") end
end
subAba.natureza = function()
	local e = estadoNat
	if not (e and e.Rolou) then return "Every ninja is born with an affinity for one chakra nature. A few get two or even three." end
	local outras = {}
	for _, id in ipairs(e.Lista or {}) do
		if id ~= e.Afinidade then table.insert(outras, NatureData.Tipos[id].Name) end
	end
	local afin = NatureData.Tipos[e.Afinidade or ""]
	return "Affinity: " .. (afin and afin.Name or "?") .. (#outras > 0 and (". Also: " .. table.concat(outras, ", ") .. ".") or ". One nature.")
end

nBtn.MouseButton1Click:Connect(function()
	if girando then return end
	local e = estadoNat or lerNatureza()
	local pedido = "girar"
	if e and e.Rolou then
		-- girar de novo custa gemas e pode tirar jutsus já aprendidos: pede um segundo clique
		if os.clock() > confirmarNatAte then
			confirmarNatAte = os.clock() + 4
			renderNatureza()
			task.delay(4.1, function() if not girando then renderNatureza() end end)
			return
		end
		pedido = "regirar"
	end
	confirmarNatAte = 0
	girando = true
	aviso.Text = ""
	nBtn.Text = "..."
	local ok, r = pcall(function() return naturezaAcao:InvokeServer(pedido) end)
	if not ok or not r or not r.ok or not r.estado or not r.estado.Rolou then
		girando = false
		if ok and r and r.estado then estadoNat = r.estado end
		aviso.Text = (ok and r and r.erro) or "Could not reach the server. Try again."
		renderNatureza()
		return
	end
	estadoNat = r.estado
	local t, passo, i = 0, 0.05, 1
	while t < 2.4 do
		mostrarNatureza(NatureData.Order[(i % #NatureData.Order) + 1], "giro")
		i += 1
		task.wait(passo)
		t += passo
		passo = math.min(passo * 1.09, 0.3)
	end
	mostrarNatureza(estadoNat.Afinidade, "afinidade")
	pulo(nCard)
	local afin = NatureData.Tipos[estadoNat.Afinidade or ""]
	if afin then
		local n = #estadoNat.Lista
		Vinheta.Revelar(afin.Name .. " Release", n > 1 and ("Affinity  +  " .. (n - 1) .. " more nature" .. (n > 2 and "s" or "")) or "Your chakra affinity", afin.Color, n >= 2)
	end
	for _ = 1, 20 do
		if naturezaFeita() then break end
		task.wait(0.1)
	end
	girando = false
	render()
end)

player:GetAttributeChangedSignal("NaturezaEstado"):Connect(function()
	estadoNat = nil
	lerNatureza()
	if fundo.Visible and not girando then render() end
end)
for _, at in ipairs({ "Kekkei", "KekkeiRolou", "NaturezaRolou" }) do
	player:GetAttributeChangedSignal(at):Connect(function()
		if fundo.Visible and not girando then render() end
	end)
end

-- o render do clã também atualiza as abas novas
local renderCla = render
render = function(destaque)
	renderCla(destaque)
	renderKekkei()
	renderNatureza()
	atualizarAbas()
end
-- abre na primeira aba que ainda falta fazer
local function abaPendente()
	for _, a in ipairs(ABAS) do
		if not FEITO[a.Id]() then return a.Id end
	end
	return "cla"
end

-- Sala da roleta: enquanto o painel está aberto, a câmera fica dentro do quarto japonês (workspace.SalaRoleta)
local RunService = game:GetService("RunService")
local function cameraSala(ligar)
	local cam = workspace.CurrentCamera
	local sala = workspace:FindFirstChild("SalaRoleta")
	local pos = sala and sala:FindFirstChild("CameraPos")
	local alvo = sala and sala:FindFirstChild("CameraAlvo")
	RunService:UnbindFromRenderStep("CameraSalaRoleta")
	if ligar and pos and alvo then
		fundo.BackgroundTransparency = 1
		cam.CameraType = Enum.CameraType.Scriptable
		-- balanço bem leve para a sala não parecer uma foto parada
		RunService:BindToRenderStep("CameraSalaRoleta", Enum.RenderPriority.Camera.Value + 1, function()
			local t = os.clock()
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = CFrame.lookAt(pos.Position + Vector3.new(math.sin(t * 0.3) * 0.6, math.sin(t * 0.45) * 0.15, 0), alvo.Position)
			cam.FieldOfView = 70
		end)
	else
		fundo.BackgroundTransparency = 0.35
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = player:GetAttribute("FOVBase") or 70
	end
end
local pedidoSala = 0
local function sala(ligar)
	cameraSala(ligar)
	pedidoSala += 1
	local meu = pedidoSala
	task.spawn(function()
		if ligar then
			-- espera o personagem existir (primeira entrada no jogo) e pede ao servidor para colocá-lo no quarto
			for _ = 1, 40 do
				if meu ~= pedidoSala then return end
				local char = player.Character
				if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChildOfClass("Humanoid") then
					task.wait(1)
					if meu ~= pedidoSala then return end
					local r = action:InvokeServer("sala", true)
					if r and r.ok then return end
				end
				task.wait(0.5)
			end
		else
			action:InvokeServer("sala", false)
		end
	end)
end
-- Enquanto a sala está aberta, o resto da interface some (HUD, poderes, viagem, atributos e o botão do clã).
-- Tudo volta só depois do CONTINUE.
local StarterGui = game:GetService("StarterGui")
local OUTRAS = { "HUD", "HudOnda", "HudPoderes", "HudNatureza", "ViagemUI", "AtributosUI", "MissaoUI", "Extras", "TutorialBotao" }
local function outras(ligar)
	local pg = player.PlayerGui
	for _, n in ipairs(OUTRAS) do
		local g = pg:FindFirstChild(n)
		if g and g:IsA("ScreenGui") then g.Enabled = ligar end
	end
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, ligar) end)
	badge.Visible = ligar
end
-- na sala, os outros jogadores ficam invisíveis só nesta tela (todos ficam no mesmo ponto do quarto)
local escondidos = {}
local function esconderOutros(ligar)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then
			for _, d in ipairs(p.Character:GetDescendants()) do
				if d:IsA("BasePart") or d:IsA("Decal") then
					d.LocalTransparencyModifier = ligar and 1 or 0
					escondidos[d] = ligar or nil
				end
			end
			local h = p.Character:FindFirstChildOfClass("Humanoid")
			if h then h.DisplayDistanceType = ligar and Enum.HumanoidDisplayDistanceType.None or Enum.HumanoidDisplayDistanceType.Viewer end
		end
	end
	if not ligar then
		for d in pairs(escondidos) do
			if d.Parent then d.LocalTransparencyModifier = 0 end
		end
		table.clear(escondidos)
	end
end
fundo:GetPropertyChangedSignal("Visible"):Connect(function()
	if fundo.Visible then abrirAba(abaPendente()) else faltaTxt.Visible = false end
	sala(fundo.Visible)
	outras(not fundo.Visible)
	esconderOutros(fundo.Visible)
	if fundo.Visible then
		-- outras telas podem ser criadas depois: esconde de novo enquanto a sala estiver aberta
		task.spawn(function()
			while fundo.Visible do
				outras(false)
				esconderOutros(true) -- pega quem entrou no servidor depois
				task.wait(0.5)
			end
		end)
	end
end)

render()
-- Só aparece depois do PLAY na tela de entrada (script Titulo). Quem ainda não tem clã vai direto para a sala da roleta.
local function aposEntrada()
	gui.Enabled = true
	-- os atributos da Kekkei Genkai e da natureza chegam do servidor logo depois de entrar
	for _ = 1, 50 do
		if player:GetAttribute("KekkeiRolou") ~= nil and player:GetAttribute("NaturezaRolou") ~= nil then break end
		task.wait(0.1)
	end
	lerNatureza()
	if not estado.Id or player:GetAttribute("KekkeiRolou") == false or player:GetAttribute("NaturezaRolou") == false then
		fundo.Visible = true
	end
end
gui.Enabled = false
if player:GetAttribute("Jogando") then
	aposEntrada()
else
	local con
	con = player:GetAttributeChangedSignal("Jogando"):Connect(function()
		if player:GetAttribute("Jogando") then
			con:Disconnect()
			aposEntrada()
		end
	end)
end

---------------------------------------------------------------
-- Byakugan: destaca inimigos de longe e através das paredes
---------------------------------------------------------------
local marcas = {} -- [modelo] = Highlight
task.spawn(function()
	while true do
		task.wait(0.5)
		local ativo = player:GetAttribute("Cla") == "Byakugan"
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local vistos = {}
		if ativo and root then
			for _, m in ipairs(CollectionService:GetTagged("Inimigo")) do
				local r = m:FindFirstChild("HumanoidRootPart")
				if r and (r.Position - root.Position).Magnitude < 220 then
					vistos[m] = true
					if not marcas[m] then
						marcas[m] = new("Highlight", { Adornee = m, FillColor = Color3.fromRGB(200, 190, 255), FillTransparency = 0.75, OutlineColor = Color3.fromRGB(235, 230, 255), DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = gui })
					end
				end
			end
		end
		for m, h in pairs(marcas) do
			if not vistos[m] or not m.Parent then
				h:Destroy()
				marcas[m] = nil
			end
		end
	end
end)

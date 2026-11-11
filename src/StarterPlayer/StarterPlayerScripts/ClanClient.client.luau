-- LocalScript: StarterPlayerScripts > ClanClient
-- Tela da roleta de clã (abre sozinha para quem ainda não tem clã), escolha de estatura,
-- botão do clã na lateral e a visão do clã Byakugan (inimigos destacados através das paredes).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local ClanData = require(ReplicatedStorage:WaitForChild("ClanData"))
local action = ReplicatedStorage:WaitForChild("ClanAction")
local player = Players.LocalPlayer

local COR = {
	painel = Color3.fromRGB(20, 20, 23),
	card = Color3.fromRGB(30, 30, 34),
	linha = Color3.fromRGB(58, 58, 64),
	texto = Color3.fromRGB(240, 240, 244),
	fraco = Color3.fromRGB(140, 140, 150),
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
	local sc = math.clamp(math.min(v.X / 1150, v.Y / 680), 0.5, 1.1) * 0.78 -- HUD compacto: tudo 22% menor
	badgeEscala.Scale = sc
	badge.Position = UDim2.fromOffset(16 * sc, game:GetService("GuiService"):GetGuiInset().Y + 62 * sc)
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
local painel = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 20, 0.5, 0), Size = UDim2.fromOffset(660, 470), BackgroundColor3 = COR.painel, Parent = fundo })
corner(painel, 18)
stroke(painel, COR.laranja, 3)
local escala = new("UIScale", { Parent = painel })
local function ajustarEscala()
	local vp = workspace.CurrentCamera.ViewportSize
	escala.Scale = math.clamp(math.min(vp.X * 0.52 / 660, vp.Y / 520), 0.4, 1.1) -- ocupa no máximo metade da largura
end
ajustarEscala()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajustarEscala)

label(painel, "CLAN ROULETTE", 26, COR.texto, { Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 32), Font = Enum.Font.GothamBlack })
local sub = label(painel, "", 14, COR.fraco, { Position = UDim2.fromOffset(20, 46), Size = UDim2.new(1, -40, 0, 20) })
local fechar = botao(painel, "X", COR.card, UDim2.fromOffset(36, 36), UDim2.new(1, -48, 0, 12))

-- cartão grande do resultado
local grande = new("Frame", { Position = UDim2.fromOffset(20, 76), Size = UDim2.fromOffset(250, 250), BackgroundColor3 = COR.card, Parent = painel })
corner(grande, 14)
local grandeStroke = stroke(grande, COR.linha, 3)
local gSimbolo = label(grande, "?", 86, COR.texto, { Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 110) })
local gNome = label(grande, "", 26, COR.texto, { Position = UDim2.fromOffset(0, 128), Size = UDim2.new(1, 0, 0, 30), Font = Enum.Font.GothamBlack })
local gRaridade = label(grande, "", 15, COR.fraco, { Position = UDim2.fromOffset(0, 158), Size = UDim2.new(1, 0, 0, 20) })
local gTraco = label(grande, "", 14, COR.texto, { Position = UDim2.fromOffset(12, 182), Size = UDim2.new(1, -24, 0, 56) })

-- lista de opções sorteadas
local lista = new("Frame", { Position = UDim2.fromOffset(286, 76), Size = UDim2.fromOffset(354, 250), BackgroundTransparency = 1, Parent = painel })
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = lista })

local girarBtn = botao(painel, "SPIN", COR.laranja, UDim2.fromOffset(250, 48), UDim2.fromOffset(20, 338))
local manterBtn = botao(painel, "KEEP MY CLAN", COR.card, UDim2.fromOffset(354, 48), UDim2.fromOffset(286, 338))
-- CONTINUE: canto inferior direito da tela; aparece quando o clã já foi escolhido
local continuar = botao(fundo, "CONTINUE", COR.laranja, UDim2.fromOffset(230, 58), UDim2.new(1, -24, 1, -24))
continuar.AnchorPoint = Vector2.new(1, 1)
continuar.TextSize = 22
continuar.Visible = false
local aviso = label(painel, "", 14, COR.vermelho, { Position = UDim2.fromOffset(20, 390), Size = UDim2.new(1, -40, 0, 18) })

-- estatura
label(painel, "HEIGHT", 14, COR.fraco, { Position = UDim2.fromOffset(20, 420), Size = UDim2.fromOffset(80, 34), TextXAlignment = Enum.TextXAlignment.Left })
local menosBtn = botao(painel, "-", COR.card, UDim2.fromOffset(44, 34), UDim2.fromOffset(100, 420))
local alturaTxt = label(painel, "1.00", 18, COR.texto, { Position = UDim2.fromOffset(150, 420), Size = UDim2.fromOffset(70, 34), Font = Enum.Font.GothamBlack })
local maisBtn = botao(painel, "+", COR.card, UDim2.fromOffset(44, 34), UDim2.fromOffset(226, 420))
menosBtn.TextSize, maisBtn.TextSize = 22, 22
local alturaDica = label(painel, "", 13, COR.fraco, { Position = UDim2.fromOffset(282, 420), Size = UDim2.fromOffset(358, 34), TextXAlignment = Enum.TextXAlignment.Left })
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
	if not temCla then
		sub.Text = "You are born into a clan. Spin up to " .. ClanData.FREE_SPINS .. " times and keep the one you like most."
	else
		sub.Text = "Your clan: " .. c.Name .. ". Spin again to try another one."
	end
	girarBtn.Text = estado.Giros > 0 and ("SPIN  (" .. estado.Giros .. " free)") or ("SPIN  (" .. ClanData.RESPIN_GEMS .. " gems)")
	fechar.Visible = false -- quem fecha agora é o CONTINUE
	continuar.Visible = temCla and #estado.Opcoes == 0
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
local OUTRAS = { "HUD", "HudOnda", "HudPoderes", "ViagemUI", "AtributosUI" }
local function outras(ligar)
	local pg = player.PlayerGui
	for _, n in ipairs(OUTRAS) do
		local g = pg:FindFirstChild(n)
		if g and g:IsA("ScreenGui") then g.Enabled = ligar end
	end
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, ligar) end)
	badge.Visible = ligar
end
fundo:GetPropertyChangedSignal("Visible"):Connect(function()
	sala(fundo.Visible)
	outras(not fundo.Visible)
	if fundo.Visible then
		-- outras telas podem ser criadas depois: esconde de novo enquanto a sala estiver aberta
		task.spawn(function()
			while fundo.Visible do
				outras(false)
				task.wait(0.5)
			end
		end)
	end
end)

render()
-- Só aparece depois do PLAY na tela de entrada (script Titulo). Quem ainda não tem clã vai direto para a sala da roleta.
local function aposEntrada()
	gui.Enabled = true
	if not estado.Id then
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

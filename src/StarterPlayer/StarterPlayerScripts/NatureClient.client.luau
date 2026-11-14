-- LocalScript: StarterPlayerScripts > NatureClient
-- Naturezas de chakra: tela da roleta (depois da BLOODLINE, para quem ainda nao girou), os dois
-- jutsus de natureza no HUD (teclas G e H, a direita do botao POWERS) e o painel NATURES para equipar.
-- Estado vem do servidor no atributo "NaturezaEstado" (JSON) e "NaturezaRolou".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local ContextActionService = game:GetService("ContextActionService")

local NatureData = require(ReplicatedStorage:WaitForChild("NatureData"))
local Vinheta = require(ReplicatedStorage:WaitForChild("Vinheta"))
local Selos = require(ReplicatedStorage:WaitForChild("SelosDeMao"))
local MissionData = require(ReplicatedStorage:WaitForChild("MissionData"))
local acao = ReplicatedStorage:WaitForChild("NaturezaAcao")
local useEvent = ReplicatedStorage:WaitForChild("UseAbility")
local feedbackEvent = ReplicatedStorage:WaitForChild("AbilityFeedback")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local COR = {
	fundo = Color3.fromRGB(10, 8, 14), painel = Color3.fromRGB(20, 20, 26), card = Color3.fromRGB(32, 30, 40),
	laranja = Color3.fromRGB(255, 140, 40), texto = Color3.new(1, 1, 1), fraco = Color3.fromRGB(180, 175, 190),
	linha = Color3.fromRGB(80, 80, 100), verde = Color3.fromRGB(70, 190, 110), ouro = Color3.fromRGB(255, 205, 70),
}

local function new(cls, props)
	local o = Instance.new(cls)
	for k, v in pairs(props) do
		if k ~= "Parent" then o[k] = v end
	end
	o.Parent = props.Parent
	return o
end
local function label(parent, text, size, color, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, TextColor3 = color or COR.texto,
		Font = Enum.Font.GothamBold, TextWrapped = true, Parent = parent })
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end
local function canto(o, r) new("UICorner", { CornerRadius = UDim.new(0, r), Parent = o }) end

local estado = { Rolou = false, Afinidade = false, Lista = {}, Jutsus = {}, Equip = { false, false, false, false }, Pendente = {} }
-- texto do botao de re-giro: usa a ficha do pergaminho se houver, senao custa gemas
local function textoRegirar()
	if (estado.Fichas or 0) > 0 then return ("RE-SPIN NATURES  (%d free)"):format(estado.Fichas) end
	return ("RE-SPIN NATURES  (%d gems)"):format(NatureData.CUSTO_REGIRAR)
end
local function sabe(id) return table.find(estado.Jutsus, id) ~= nil end
local function tem(nat) return table.find(estado.Lista, nat) ~= nil end

---------------------------------------------------------------
-- Tela da roleta
---------------------------------------------------------------
local roleta = new("ScreenGui", { Name = "NaturezaUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 19, Enabled = false, Parent = pg })
local fundo = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = COR.fundo, BackgroundTransparency = 0.08, Parent = roleta })
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(15, 35, 60), Color3.fromRGB(10, 8, 14)), Parent = fundo })
local caixa = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(560, 430), BackgroundTransparency = 1, Parent = fundo })
local escala = new("UIScale", { Parent = caixa })
local function ajustar()
	local vp = workspace.CurrentCamera.ViewportSize
	escala.Scale = math.clamp(math.min(vp.X / 620, vp.Y / 490), 0.55, 1.2)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajustar)
ajustar()

label(caixa, "CHAKRA NATURE", 40, COR.texto, { Size = UDim2.new(1, 0, 0, 48), Font = Enum.Font.GothamBlack })
label(caixa, "Every ninja is born with an affinity for one chakra nature. A few are born with two or even three. The rest must be earned.", 14, COR.fraco,
	{ Position = UDim2.fromOffset(20, 50), Size = UDim2.new(1, -40, 0, 40) })
local card = new("Frame", { Position = UDim2.fromOffset(80, 104), Size = UDim2.new(1, -160, 0, 200), BackgroundColor3 = COR.card, Parent = caixa })
canto(card, 16)
local borda = new("UIStroke", { Color = COR.linha, Thickness = 3, Parent = card })
local rSub = label(card, "", 13, COR.fraco, { Position = UDim2.fromOffset(10, 12), Size = UDim2.new(1, -20, 0, 16), Font = Enum.Font.GothamBlack })
local rNome = label(card, "?", 54, COR.texto, { Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 0, 64), Font = Enum.Font.GothamBlack })
local rExtra = label(card, "", 15, COR.texto, { Position = UDim2.fromOffset(14, 100), Size = UDim2.new(1, -28, 0, 22), Font = Enum.Font.GothamBlack, RichText = true })
local rDetalhe = label(card, "", 13, COR.fraco, { Position = UDim2.fromOffset(18, 126), Size = UDim2.new(1, -36, 0, 66), Font = Enum.Font.Gotham, TextYAlignment = Enum.TextYAlignment.Top })
local rBotao = new("TextButton", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 328), Size = UDim2.fromOffset(320, 60),
	BackgroundColor3 = COR.laranja, Text = "REVEAL MY NATURE", Font = Enum.Font.GothamBlack, TextSize = 20, TextColor3 = COR.texto, Parent = caixa })
canto(rBotao, 14)
local rAviso = label(caixa, "", 13, Color3.fromRGB(255, 120, 120), { Position = UDim2.fromOffset(20, 394), Size = UDim2.new(1, -40, 0, 20) })

local function hex(c) return ("#%02X%02X%02X"):format(c.R * 255, c.G * 255, c.B * 255) end

local function mostrarResultado(e)
	local afin = NatureData.Tipos[e.Afinidade or ""]
	if not afin then return end
	rSub.Text = "YOUR AFFINITY"
	rNome.Text = afin.Name:upper()
	rNome.TextColor3 = afin.Color
	borda.Color = afin.Color
	local outras = {}
	for _, id in ipairs(e.Lista) do
		if id ~= e.Afinidade then
			local t = NatureData.Tipos[id]
			table.insert(outras, ('<font color="%s">%s</font>'):format(hex(t.Color), t.Name:upper()))
		end
	end
	rExtra.Text = #outras > 0 and ("ALSO BORN WITH:  " .. table.concat(outras, "  +  ")) or "ONE NATURE"
	rDetalhe.Text = ("Affinity jutsus deal +%d%% damage and cost %d%% less chakra.\nYou start with no jutsu: nature masters in the village teach them through missions."):format(
		(NatureData.AFIN_DANO - 1) * 100 + 0.5, (1 - NatureData.AFIN_CHAKRA) * 100 + 0.5)
end

local function rolar(e)
	rSub.Text, rExtra.Text, rDetalhe.Text = "", "", ""
	local t, passo, i = 0, 0.05, 1
	while t < 2.4 do
		local tipo = NatureData.Tipos[NatureData.Order[(i % #NatureData.Order) + 1]]
		rNome.Text = tipo.Name:upper()
		rNome.TextColor3 = tipo.Color
		borda.Color = tipo.Color
		i += 1
		task.wait(passo)
		t += passo
		passo = math.min(passo * 1.09, 0.3)
	end
	mostrarResultado(e)
	card.Size = UDim2.new(1, -150, 0, 210)
	TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.new(1, -160, 0, 200) }):Play()
end

local fase = "girar" -- "girar" -> "girando" -> "fim"
rBotao.MouseButton1Click:Connect(function()
	if fase == "girar" then
		fase = "girando"
		rBotao.Text = "..."
		rAviso.Text = ""
		local ok, r = pcall(function() return acao:InvokeServer("girar") end)
		if not ok or not r or not r.estado or not r.estado.Rolou then
			fase = "girar"
			rBotao.Text = "REVEAL MY NATURE"
			rAviso.Text = (ok and r and r.erro) or "Could not reach the server. Try again."
			return
		end
		estado = r.estado
		rolar(r.estado)
		-- vinheta de revelação da afinidade
		local afin = NatureData.Tipos[r.estado.Afinidade or ""]
		if afin then
			local n = #r.estado.Lista
			Vinheta.Revelar(afin.Name .. " Release", n > 1 and ("Affinity  +  " .. (n - 1) .. " more nature" .. (n > 2 and "s" or "")) or "Your chakra affinity", afin.Color, n >= 2)
		end
		fase = "fim"
		rBotao.Text = "CONTINUE"
	elseif fase == "fim" then
		roleta.Enabled = false
	end
end)

local function checarRoleta()
	-- a roleta agora fica na aba NATURE da sala do clã (ClanClient): esta tela não abre mais sozinha
	local precisa = false
	if fase ~= "fim" and precisa then
		roleta.Enabled = true
	elseif fase == "girar" then
		roleta.Enabled = false
	end
end
player:GetAttributeChangedSignal("NaturezaRolou"):Connect(checarRoleta)
player:GetAttributeChangedSignal("Jogando"):Connect(checarRoleta)
checarRoleta()

---------------------------------------------------------------
-- HUD: jutsus de natureza (G, H, J e K) e botao NATURES
---------------------------------------------------------------
local ICONE_NAT = { Fogo = "🔥", Vento = "💨", Raio = "⚡", Terra = "🌍", Agua = "💧" } -- imagem no lugar de texto
local function escalaHotbar() -- mesma conta da barra de poderes (AbilityClient)
	return math.clamp((workspace.CurrentCamera.ViewportSize.X / 2 + 111) / 864, 0.55, 0.95)
end
local hud = new("ScreenGui", { Name = "HudNatureza", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = pg })
local barra = new("Frame", { AnchorPoint = Vector2.new(0, 1), Size = UDim2.fromOffset(350, 84), BackgroundTransparency = 1, Visible = false, Parent = hud })
local escalaBarra = new("UIScale", { Scale = escalaHotbar(), Parent = barra })

local readyAt, total = { 0, 0, 0, 0 }, { 1, 1, 1, 1 }
local slots = {}
for i = 1, NatureData.SLOTS do
	local f = new("Frame", { Size = UDim2.fromOffset(64, 62), Position = UDim2.fromOffset((i - 1) * 68, 20), BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		BackgroundTransparency = 0.15, ClipsDescendants = true, Parent = barra })
	canto(f, 10)
	local stroke = new("UIStroke", { Thickness = 2, Color = COR.linha, Parent = f })
	label(f, NatureData.KEYS[i], 18, COR.texto, { Size = UDim2.fromOffset(22, 18), Position = UDim2.fromOffset(6, 4), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
	local icone = label(f, "", 24, COR.texto, { Size = UDim2.fromOffset(36, 30), Position = UDim2.fromOffset(26, 1), ZIndex = 3 })
	local nome = label(f, "", 11, COR.texto, { Size = UDim2.new(1, -6, 0, 14), Position = UDim2.fromOffset(3, 30), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3 })
	local custo = label(f, "", 12, Color3.fromRGB(120, 190, 255), { Size = UDim2.new(1, -8, 0, 13), Position = UDim2.new(0, 4, 1, -15), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3 })
	local sombra = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 2, Parent = f })
	local tempo = label(f, "", 17, Color3.fromRGB(255, 220, 120), { Size = UDim2.fromOffset(46, 22), Position = UDim2.new(1, -48, 0, 2), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4 })
	slots[i] = { frame = f, stroke = stroke, icone = icone, nome = nome, custo = custo, sombra = sombra, tempo = tempo }
end
local bNat = new("TextButton", { Name = "BotaoNaturezas", Size = UDim2.fromOffset(70, 62), Position = UDim2.fromOffset(276, 20), BackgroundColor3 = Color3.fromRGB(25, 25, 35),
	BackgroundTransparency = 0.15, Font = Enum.Font.GothamBlack, TextSize = 14, TextWrapped = true, Text = "🌀\nNATURES", TextColor3 = COR.texto, Parent = barra })
canto(bNat, 10)
new("UIStroke", { Color = COR.linha, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = bNat })

-- custo de chakra mostrado (com o desconto da afinidade)
local function custoDe(j)
	return estado.Afinidade == j.Natureza and math.floor(j.Chakra * NatureData.AFIN_CHAKRA + 0.5) or j.Chakra
end

---------------------------------------------------------------
-- Painel NATURES
---------------------------------------------------------------
local painel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, 440), BackgroundColor3 = COR.painel, Visible = false, Parent = hud })
canto(painel, 14)
new("UIStroke", { Color = COR.laranja, Thickness = 2, Parent = painel })
local pEscala = new("UIScale", { Parent = painel })
local function ajustarPainel()
	local vp = workspace.CurrentCamera.ViewportSize
	pEscala.Scale = math.clamp(math.min(vp.X / 560, vp.Y / 500), 0.5, 1)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajustarPainel)
ajustarPainel()
label(painel, "CHAKRA NATURES", 20, COR.laranja, { Position = UDim2.fromOffset(16, 10), Size = UDim2.fromOffset(300, 24), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left })
local pSub = label(painel, "", 12, COR.fraco, { Position = UDim2.fromOffset(16, 34), Size = UDim2.new(1, -70, 0, 16), TextXAlignment = Enum.TextXAlignment.Left })
local pFechar = new("TextButton", { Position = UDim2.new(1, -44, 0, 10), Size = UDim2.fromOffset(32, 28), BackgroundColor3 = COR.card, Text = "X", Font = Enum.Font.GothamBlack, TextSize = 14, TextColor3 = COR.texto, Parent = painel })
canto(pFechar, 6)
pFechar.MouseButton1Click:Connect(function() painel.Visible = false end)
local pLista = new("ScrollingFrame", { Position = UDim2.fromOffset(12, 58), Size = UDim2.new(1, -24, 1, -112), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = painel })
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pLista })
local pAviso = label(painel, "", 12, Color3.fromRGB(255, 120, 120), { Position = UDim2.new(0, 16, 1, -46), Size = UDim2.new(1, -230, 0, 36), TextXAlignment = Enum.TextXAlignment.Left })
local pGirar = new("TextButton", { Position = UDim2.new(1, -206, 1, -46), Size = UDim2.fromOffset(190, 34), BackgroundColor3 = COR.card, Font = Enum.Font.GothamBlack, TextSize = 12,
	TextColor3 = COR.texto, Text = "", Parent = painel })
canto(pGirar, 8)

local atualizar
local mostrarEscolha
local function equipar(pos, id)
	local ok, r = pcall(function() return acao:InvokeServer("equipar", pos, id) end)
	if ok and r then
		if r.estado then estado = r.estado end
		pAviso.Text = r.ok and "" or (r.erro or "")
		atualizar()
	end
end

local function montarPainel()
	for _, c in ipairs(pLista:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	pSub.Text = ("You have %d of %d natures. Lady Tsuna can awaken more through rare missions."):format(#estado.Lista, NatureData.MAX)
	local ordem = 0
	for _, id in ipairs(NatureData.Order) do
		local t = NatureData.Tipos[id]
		local meu = tem(id)
		ordem += 1
		local f = new("Frame", { Size = UDim2.new(1, -6, 0, 172), BackgroundColor3 = COR.card, LayoutOrder = (meu and 0 or 100) + ordem, Parent = pLista })
		canto(f, 8)
		new("Frame", { Position = UDim2.fromOffset(0, 8), Size = UDim2.new(0, 5, 1, -16), BackgroundColor3 = meu and t.Color or COR.linha, BorderSizePixel = 0, Parent = f })
		local mestre = MissionData.NPCs[t.Mestre] and MissionData.NPCs[t.Mestre].Name or "?"
		local titulo = (ICONE_NAT[id] or "") .. "  " .. t.Name:upper()
		if estado.Afinidade == id then titulo ..= "   ★ AFFINITY" end
		label(f, titulo, 15, meu and t.Color or COR.fraco, { Position = UDim2.fromOffset(14, 6), Size = UDim2.fromOffset(240, 20), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left })
		label(f, meu and ("Master: " .. mestre) or "🔒 Not awakened", 12, COR.fraco, { Position = UDim2.new(1, -210, 0, 7), Size = UDim2.fromOffset(200, 16), TextXAlignment = Enum.TextXAlignment.Right })
		for k = 1, #NatureData.TIERS do
			local y = 30 + (k - 1) * 34
			local escolhido
			for _, j in ipairs(t.Tiers[k]) do
				if meu and sabe(j.Id) then escolhido = j end
			end
			local pendente = false
			for _, pd in ipairs(estado.Pendente or {}) do
				if pd.Natureza == id and pd.Tier == k then pendente = true end
			end
			-- bolinha com o numero da etapa
			local bola = new("Frame", { Position = UDim2.fromOffset(12, y + 4), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = (escolhido or pendente) and t.Color or COR.linha, Parent = f })
			canto(bola, 12)
			label(bola, tostring(k), 14, Color3.new(1, 1, 1), { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack })
			if escolhido then
				label(f, escolhido.Name, 14, COR.texto, { Position = UDim2.fromOffset(44, y), Size = UDim2.fromOffset(250, 17), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left })
				label(f, escolhido.Info, 11, COR.fraco, { Position = UDim2.fromOffset(44, y + 16), Size = UDim2.new(1, -190, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false })
				for pos = 1, NatureData.SLOTS do
					local usando = estado.Equip[pos] == escolhido.Id
					local b = new("TextButton", { Position = UDim2.new(1, -132 + (pos - 1) * 31, 0, y + 3), Size = UDim2.fromOffset(28, 26), BackgroundColor3 = usando and t.Color or COR.linha,
						Text = NatureData.KEYS[pos], Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = COR.texto, Parent = f })
					canto(b, 6)
					b.MouseButton1Click:Connect(function() equipar(pos, (not usando) and escolhido.Id or false) end)
				end
			elseif pendente then
				label(f, "Choose 1 of 2 new jutsus!", 13, COR.ouro, { Position = UDim2.fromOffset(44, y + 6), Size = UDim2.fromOffset(250, 18), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left })
				local b = new("TextButton", { Position = UDim2.new(1, -132, 0, y + 3), Size = UDim2.fromOffset(120, 26), BackgroundColor3 = COR.laranja,
					Text = "CHOOSE", Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), Parent = f })
				canto(b, 6)
				b.MouseButton1Click:Connect(function() mostrarEscolha(id, k) end)
			else
				local ti = NatureData.TIERS[k]
				local txt = meu and ((ti.Nivel > 0 and ("Level " .. ti.Nivel .. "  ·  ") or "") .. "Ask " .. mestre) or ""
				label(f, "🔒  " .. (meu and txt or "—"), 12, COR.fraco, { Position = UDim2.fromOffset(44, y + 6), Size = UDim2.new(1, -60, 0, 18), TextXAlignment = Enum.TextXAlignment.Left })
			end
		end
	end
end

---------------------------------------------------------------
-- Escolha de jutsu: 1 entre 2 (aparece quando uma missao de natureza libera uma etapa)
---------------------------------------------------------------
local escolhaGui = new("ScreenGui", { Name = "NaturezaEscolha", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 26, Enabled = false, Parent = pg })
local escolhaFundo = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Parent = escolhaGui })
local escolhaCaixa = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(620, 360), BackgroundColor3 = COR.fundo, Parent = escolhaFundo })
canto(escolhaCaixa, 14)
local escolhaEscala = new("UIScale", { Parent = escolhaCaixa })
local function ajustarEscolha()
	local vp = workspace.CurrentCamera.ViewportSize
	escolhaEscala.Scale = math.clamp(math.min(vp.X / 680, vp.Y / 420), 0.5, 1.2)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajustarEscolha)
ajustarEscolha()
local escolhaTitulo = label(escolhaCaixa, "", 22, COR.laranja, { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -90, 0, 28), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left })
local escolhaSub = label(escolhaCaixa, "Choose ONE. The other one is lost for good.", 13, COR.fraco, { Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -32, 0, 18), TextXAlignment = Enum.TextXAlignment.Left })
local escolhaFechar = new("TextButton", { Position = UDim2.new(1, -90, 0, 10), Size = UDim2.fromOffset(76, 28), BackgroundColor3 = COR.card, Text = "LATER", Font = Enum.Font.GothamBlack, TextSize = 12, TextColor3 = COR.texto, Parent = escolhaCaixa })
canto(escolhaFechar, 6)
escolhaFechar.MouseButton1Click:Connect(function() escolhaGui.Enabled = false end)
local escolhaCards = {}
local escolhaAlvo = nil -- { nat, tier }
local confirmaOpcao, confirmaAte = nil, 0
for op = 1, 2 do
	local card = new("Frame", { Position = UDim2.fromOffset(16 + (op - 1) * 298, 70), Size = UDim2.fromOffset(290, 276), BackgroundColor3 = COR.card, Parent = escolhaCaixa })
	canto(card, 12)
	local faixa = new("Frame", { Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = COR.linha, BorderSizePixel = 0, Parent = card })
	canto(faixa, 4)
	local nome = label(card, "", 20, COR.texto, { Position = UDim2.fromOffset(12, 18), Size = UDim2.new(1, -24, 0, 26), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left })
	local desc = label(card, "", 14, COR.texto, { Position = UDim2.fromOffset(12, 50), Size = UDim2.new(1, -24, 0, 56), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	local dano = label(card, "", 16, COR.ouro, { Position = UDim2.fromOffset(12, 112), Size = UDim2.new(1, -24, 0, 44), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	local cd = label(card, "", 17, Color3.fromRGB(255, 220, 120), { Position = UDim2.fromOffset(12, 164), Size = UDim2.new(0.5, -12, 0, 24), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left })
	local ck = label(card, "", 17, Color3.fromRGB(120, 190, 255), { Position = UDim2.new(0.5, 0, 0, 164), Size = UDim2.new(0.5, -12, 0, 24), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left })
	local botao = new("TextButton", { Position = UDim2.fromOffset(12, 218), Size = UDim2.new(1, -24, 0, 44), BackgroundColor3 = COR.laranja, Text = "CHOOSE", Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), Parent = card })
	canto(botao, 10)
	escolhaCards[op] = { faixa = faixa, nome = nome, desc = desc, dano = dano, cd = cd, ck = ck, botao = botao }
	botao.MouseButton1Click:Connect(function()
		if not escolhaAlvo then return end
		if confirmaOpcao ~= op or os.clock() > confirmaAte then
			confirmaOpcao, confirmaAte = op, os.clock() + 4
			for k, c in ipairs(escolhaCards) do
				c.botao.Text = k == op and "SURE? TAP AGAIN" or "CHOOSE"
				c.botao.BackgroundColor3 = k == op and Color3.fromRGB(170, 50, 50) or COR.laranja
			end
			return
		end
		confirmaOpcao = nil
		local ok, r = pcall(function() return acao:InvokeServer("escolher", escolhaAlvo.nat, escolhaAlvo.tier, op) end)
		if ok and r then
			if r.estado then estado = r.estado end
			escolhaGui.Enabled = false
			atualizar()
		end
	end)
end
local jaMostrou = {}
mostrarEscolha = function(nat, tier)
	local t = NatureData.Tipos[nat]
	local par = t and t.Tiers[tier]
	if not par then return end
	escolhaAlvo = { nat = nat, tier = tier }
	jaMostrou[nat .. tier] = true
	confirmaOpcao = nil
	escolhaTitulo.Text = ("%s %s  ·  STAGE %d"):format(ICONE_NAT[nat] or "", t.Name:upper(), tier)
	escolhaTitulo.TextColor3 = t.Color
	for op, c in ipairs(escolhaCards) do
		local j = par[op]
		c.faixa.BackgroundColor3 = t.Color
		c.nome.Text = j.Name
		c.nome.TextColor3 = t.Color
		c.desc.Text = j.Desc
		c.dano.Text = "💥 " .. j.Info
		c.cd.Text = "⏱ " .. j.Cooldown .. "s"
		c.ck.Text = "🔷 " .. j.Chakra
		c.botao.Text = "CHOOSE"
		c.botao.BackgroundColor3 = COR.laranja
	end
	escolhaGui.Enabled = true
end

local confirmarAte = 0
pGirar.MouseButton1Click:Connect(function()
	if os.clock() > confirmarAte then
		confirmarAte = os.clock() + 4
		pGirar.Text = "SURE? Nature jutsus may be lost"
		pGirar.BackgroundColor3 = Color3.fromRGB(170, 50, 50)
		return
	end
	confirmarAte = 0
	local ok, r = pcall(function() return acao:InvokeServer("regirar") end)
	if ok and r then
		if r.estado then estado = r.estado end
		pAviso.Text = r.ok and "" or (r.erro or "")
		atualizar()
		if r.ok then
			local afin = NatureData.Tipos[estado.Afinidade or ""]
			pAviso.TextColor3 = afin and afin.Color or COR.texto
			pAviso.Text = "New affinity: " .. (afin and afin.Name or "?") .. "  (" .. #estado.Lista .. " nature" .. (#estado.Lista > 1 and "s" or "") .. ")"
		else
			pAviso.TextColor3 = Color3.fromRGB(255, 120, 120)
		end
	end
end)
bNat.MouseButton1Click:Connect(function()
	painel.Visible = not painel.Visible
	if painel.Visible then pAviso.Text = "" end
end)

---------------------------------------------------------------
-- Atualizar
---------------------------------------------------------------
atualizar = function()
	local jogando = player:GetAttribute("Jogando") == true
	-- a barra principal (cla) so aparece com cla; esta acompanha, a direita do botao POWERS
	local pe = {}
	local raw = player:GetAttribute("PoderesEstado")
	if type(raw) == "string" and raw ~= "" then
		local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(t) == "table" then pe = t end
	end
	local temKekkei = type(pe.K) == "string" and pe.K ~= ""
	barra.Visible = jogando and estado.Rolou == true and type(pe.Cla) == "string" and pe.Cla ~= ""
	local S = escalaHotbar()
	escalaBarra.Scale = S
	barra.Position = UDim2.new(0.5, -119 + ((temKekkei and 436 or 327) + 78) * S, 1, -12)
	if not barra.Visible then painel.Visible = false end
	for i = 1, NatureData.SLOTS do
		local j = estado.Equip[i] and NatureData.Jutsu(estado.Equip[i])
		local s = slots[i]
		if j then
			s.icone.Text = ICONE_NAT[j.Natureza] or ""
			s.nome.Text = j.Name
			s.nome.TextColor3 = COR.texto
			s.custo.Text = custoDe(j) .. " CP"
			s.stroke.Color = NatureData.Tipos[j.Natureza].Color
		else
			s.icone.Text = ""
			s.nome.Text = "empty"
			s.nome.TextColor3 = COR.fraco
			s.custo.Text = ""
			s.stroke.Color = Color3.fromRGB(70, 70, 85)
		end
	end
	if os.clock() > confirmarAte then
		pGirar.Text = textoRegirar()
		pGirar.BackgroundColor3 = COR.card
	end
	montarPainel()
	-- escolha liberada por missao: abre sozinha uma vez (depois, pelo botao CHOOSE do painel)
	if jogando then
		for _, pd in ipairs(estado.Pendente or {}) do
			if not jaMostrou[pd.Natureza .. pd.Tier] and not escolhaGui.Enabled then
				mostrarEscolha(pd.Natureza, pd.Tier)
			end
		end
	end
end

local function lerEstado()
	local raw = player:GetAttribute("NaturezaEstado")
	if type(raw) == "string" and raw ~= "" then
		local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(t) == "table" then
			t.Lista = type(t.Lista) == "table" and t.Lista or {}
			t.Jutsus = type(t.Jutsus) == "table" and t.Jutsus or {}
			t.Equip = type(t.Equip) == "table" and t.Equip or { false, false, false, false }
			t.Pendente = type(t.Pendente) == "table" and t.Pendente or {}
			estado = t
		end
	end
	atualizar()
end
player:GetAttributeChangedSignal("NaturezaEstado"):Connect(lerEstado)
player:GetAttributeChangedSignal("PoderesEstado"):Connect(atualizar)
player:GetAttributeChangedSignal("Jogando"):Connect(atualizar)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() atualizar() end)
lerEstado()

RunService.RenderStepped:Connect(function()
	if not barra.Visible then return end
	local now = os.clock()
	for i = 1, NatureData.SLOTS do
		local left = readyAt[i] - now
		slots[i].sombra.Size = UDim2.fromScale(1, left > 0 and math.clamp(left / total[i], 0, 1) or 0)
		slots[i].tempo.Text = left > 0 and tostring(math.ceil(left)) or ""
	end
	if os.clock() > confirmarAte and pGirar.BackgroundColor3 ~= COR.card then
		pGirar.Text = textoRegirar()
		pGirar.BackgroundColor3 = COR.card
	end
end)

---------------------------------------------------------------
-- Usar jutsu (G, H, J e K)
---------------------------------------------------------------
local function usar(i)
	if not barra.Visible then return end
	local j = estado.Equip[i] and NatureData.Jutsu(estado.Equip[i])
	if not j then
		painel.Visible = true
		return
	end
	if os.clock() < readyAt[i] or Selos.Ativo() then return end
	if (player:GetAttribute("Chakra") or 0) < custoDe(j) then
		useEvent:FireServer(4 + i) -- o servidor responde "Not enough chakra."
		return
	end
	readyAt[i] = os.clock() + j.Cooldown
	total[i] = j.Cooldown
	-- selos de mão antes do jutsu de natureza
	local nat = NatureData.Tipos[j.Natureza]
	Selos.Fazer(nat and nat.Color, function()
		useEvent:FireServer(4 + i)
	end)
end
local POS_TOQUE = { UDim2.new(1, -330, 1, -130), UDim2.new(1, -295, 1, -215), UDim2.new(1, -395, 1, -290), UDim2.new(1, -250, 1, -300) }
for i = 1, NatureData.SLOTS do
	ContextActionService:BindAction("Natureza" .. i, function(_, state)
		if state == Enum.UserInputState.Begin then usar(i) end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode[NatureData.KEYS[i]])
	ContextActionService:SetTitle("Natureza" .. i, NatureData.KEYS[i])
	ContextActionService:SetPosition("Natureza" .. i, POS_TOQUE[i])
end

feedbackEvent.OnClientEvent:Connect(function(p)
	local i = p.slot and (p.slot - 4)
	if i and i >= 1 and i <= NatureData.SLOTS then
		readyAt[i] = os.clock() + (p.cooldown or 0)
		if (p.cooldown or 0) > 0 then total[i] = p.cooldown end
	end
end)

-- LocalScript: StarterPlayerScripts > TutorialClient
-- Tour guiado na primeira entrada: cartao com icone e teclas, seta que balanca e foco no elemento da tela.
-- Comeca quando o jogador chega ao mundo (depois da roleta do cla) e o servidor marca TutorialPendente.
-- Botao "HELP" (ao lado de RANK) repete o tour quando quiser. Terminar ou pular avisa o servidor (TutorialServer).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local acaoServidor = ReplicatedStorage:WaitForChild("TutorialAcao")

local COR = {
	fundo = Color3.fromRGB(12, 12, 14), painel = Color3.fromRGB(22, 22, 26), card = Color3.fromRGB(36, 36, 42), linha = Color3.fromRGB(70, 70, 80),
	texto = Color3.new(1, 1, 1), fraco = Color3.fromRGB(180, 180, 192), ouro = Color3.fromRGB(255, 205, 70), verde = Color3.fromRGB(70, 190, 110),
}

local function new(cls, props)
	local o = Instance.new(cls)
	for k, v in pairs(props) do
		if k ~= "Parent" then o[k] = v end
	end
	o.Parent = props.Parent
	return o
end
local function canto(o, r) new("UICorner", { CornerRadius = UDim.new(0, r), Parent = o }) end
local function label(parent, texto, tam, cor, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = texto, TextSize = tam, TextColor3 = cor or COR.texto, Font = Enum.Font.GothamBold, TextWrapped = true, Parent = parent })
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end

---------------------------------------------------------------
-- Como achar cada elemento da tela (nil = passo sem seta, so o cartao)
---------------------------------------------------------------
local function caixa(lista)
	local x0, y0, x1, y1
	for _, o in ipairs(lista) do
		if o and o:IsA("GuiObject") and o.Visible and o.AbsoluteSize.X > 0 then
			local p, s = o.AbsolutePosition, o.AbsoluteSize
			x0, y0 = math.min(x0 or p.X, p.X), math.min(y0 or p.Y, p.Y)
			x1, y1 = math.max(x1 or p.X + s.X, p.X + s.X), math.max(y1 or p.Y + s.Y, p.Y + s.Y)
		end
	end
	if not x0 then return nil end
	return { x = x0, y = y0, w = x1 - x0, h = y1 - y0 }
end
local function tela(nome)
	local g = pg:FindFirstChild(nome)
	return g and g:IsA("ScreenGui") and g.Enabled and g or nil
end
local function achar(gui, pred)
	if not gui then return nil end
	for _, d in ipairs(gui:GetDescendants()) do
		if pred(d) then return d end
	end
end

local ALVO = {
	nivel = function()
		local l = achar(tela("HUD"), function(d) return d:IsA("TextLabel") and string.match(d.Text, "^LEVEL %d+") ~= nil end)
		if not l then return nil end
		local o = l
		while o and o ~= pg do -- sobe ate a barra do topo (720 x 60): nivel, moedas e gemas
			if o:IsA("Frame") and o.Size.X.Offset == 720 and o.Size.Y.Offset == 60 then return caixa({ o }) end
			o = o.Parent
		end
		return caixa({ l.Parent })
	end,
	poderes = function()
		local g = tela("HudPoderes")
		if not g then return nil end
		for _, c in ipairs(g:GetChildren()) do
			if c:IsA("Frame") and c.Visible then return caixa({ c }) end
		end
	end,
	menu = function()
		local g = tela("HUD")
		if not g then return nil end
		local itens = {}
		for _, d in ipairs(g:GetDescendants()) do
			if string.sub(d.Name, 1, 5) == "Menu_" and d:IsA("GuiObject") then table.insert(itens, d) end
		end
		return caixa(itens)
	end,
	botoes = function()
		local itens = {}
		local clan = tela("ClaUI")
		if clan then
			for _, c in ipairs(clan:GetChildren()) do
				if c:IsA("TextButton") and c.Size.X.Offset == 132 and c.Size.Y.Offset == 40 then table.insert(itens, c) end
			end
		end
		local stats = achar(tela("AtributosUI"), function(d) return d:IsA("TextButton") and d.Text == "STATS" end)
		table.insert(itens, stats)
		local extras = tela("Extras")
		if extras then
			table.insert(itens, extras:FindFirstChild("BotaoDaily"))
			table.insert(itens, extras:FindFirstChild("BotaoRank"))
		end
		local ajuda = pg:FindFirstChild("TutorialBotao")
		table.insert(itens, ajuda and ajuda:FindFirstChild("BotaoHelp"))
		return caixa(itens)
	end,
}

---------------------------------------------------------------
-- Passos (icone, titulo, texto, teclas, alvo)
---------------------------------------------------------------
local PASSOS = {
	{ "🍃", "Welcome to Shinobi Legends!", "A quick tour of the game. It takes about a minute, and you can skip it any time." },
	{ "🏃", "Move around", "Walk, jump and run through the village. ALT locks the camera behind you.", { "W", "A", "S", "D", "SPACE", "SHIFT" } },
	{ "👊", "Fight", "Punch enemies and chain your hits into combos. Every enemy you defeat gives XP.", { "F" } },
	{ "⭐", "Level and XP", "Your level, coins and gems are up here. Leveling gets slower as you grow, so every level counts.", nil, "nivel" },
	{ "⚡", "Jutsu hotbar", "Clan powers, your bloodline and your nature jutsu live here. They cost chakra, the blue bar.", { "1", "E", "R", "V", "G", "H", "J", "K" }, "poderes" },
	{ "🎁", "Side menu", "Open crates, your collection, the Battle Pass, the shop and the settings from this menu.", nil, "menu" },
	{ "📅", "Quick buttons", "CLAN: your clan powers.   STATS: spend attribute points.   DAILY: missions and login gifts.   RANK: top players by level.", nil, "botoes" },
	{ "📜", "Missions", "Talk to people with a  !  above their head, or use the QUESTS board in the village square, to get missions and learn new jutsu." },
	{ "🏆", "You are ready!", "Next you will see today's login gift. Press HELP at the top any time to see this tour again. Good luck, shinobi!" },
}

---------------------------------------------------------------
-- Tela do tour
---------------------------------------------------------------
local gui = new("ScreenGui", { Name = "Tutorial", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 40, Enabled = false, Parent = pg })

-- foco: 4 faixas escuras em volta do alvo (sem alvo, a tela inteira fica um pouco escura)
local faixas = {}
for i = 1, 4 do
	faixas[i] = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, Active = true, Parent = gui })
end
local destaque = new("Frame", { BackgroundTransparency = 1, Visible = false, Parent = gui })
canto(destaque, 12)
local destaqueBorda = new("UIStroke", { Color = COR.ouro, Thickness = 4, Parent = destaque })
TweenService:Create(destaqueBorda, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.6 }):Play()
local seta = label(gui, "", 54, COR.ouro, { Size = UDim2.fromOffset(60, 60), AnchorPoint = Vector2.new(0.5, 0.5), Font = Enum.Font.GothamBlack, Visible = false, TextWrapped = false })
new("UIStroke", { Color = Color3.fromRGB(30, 20, 5), Thickness = 3, Parent = seta })
local setaMov = nil

local card = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(600, 212), BackgroundColor3 = COR.painel, ZIndex = 5, Parent = gui })
canto(card, 14)
new("UIStroke", { Color = COR.ouro, Thickness = 3, Parent = card })
local escalaCard = new("UIScale", { Parent = card })
local circ = new("Frame", { Position = UDim2.fromOffset(18, 18), Size = UDim2.fromOffset(76, 76), BackgroundColor3 = COR.card, ZIndex = 6, Parent = card })
canto(circ, 38)
new("UIStroke", { Color = COR.ouro, Thickness = 2, Parent = circ })
local icone = label(circ, "", 42, COR.texto, { Size = UDim2.fromScale(1, 1), ZIndex = 7 })
local titulo = label(card, "", 24, COR.ouro, { Position = UDim2.fromOffset(110, 14), Size = UDim2.fromOffset(470, 32), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6 })
local corpo = label(card, "", 18, COR.texto, { Position = UDim2.fromOffset(110, 48), Size = UDim2.fromOffset(470, 66), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 6 })
local teclasLinha = new("Frame", { Position = UDim2.fromOffset(110, 116), Size = UDim2.fromOffset(470, 36), BackgroundTransparency = 1, ZIndex = 6, Parent = card })
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, Parent = teclasLinha })
local contador = label(card, "", 16, COR.fraco, { Position = UDim2.fromOffset(110, 168), Size = UDim2.fromOffset(110, 30), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6 })
local pular = new("TextButton", { Position = UDim2.fromOffset(226, 164), Size = UDim2.fromOffset(100, 36), BackgroundColor3 = COR.card, Text = "SKIP", TextColor3 = COR.fraco, Font = Enum.Font.GothamBlack, TextSize = 16, ZIndex = 6, Parent = card })
canto(pular, 10)
local proximo = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 162), Size = UDim2.fromOffset(170, 40), BackgroundColor3 = COR.verde, Text = "NEXT ▶", TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBlack, TextSize = 19, ZIndex = 6, Parent = card })
canto(proximo, 10)

local passo, rodando = 0, false
local mostrar

local function teclas(lista)
	for _, c in ipairs(teclasLinha:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	for i, t in ipairs(lista or {}) do
		local k = new("Frame", { Size = UDim2.fromOffset(math.max(38, #t * 13 + 20), 36), BackgroundColor3 = COR.card, LayoutOrder = i, ZIndex = 7, Parent = teclasLinha })
		canto(k, 8)
		new("UIStroke", { Color = COR.linha, Thickness = 2, Parent = k })
		label(k, t, 16, COR.texto, { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack, ZIndex = 8, TextWrapped = false })
	end
end

local function focar(r, v)
	local pad = 8
	if not r then
		faixas[1].Position, faixas[1].Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(v.X, v.Y)
		for i = 2, 4 do faixas[i].Size = UDim2.fromOffset(0, 0) end
		destaque.Visible, seta.Visible = false, false
		return
	end
	local x0, y0, x1, y1 = math.max(0, r.x - pad), math.max(0, r.y - pad), math.min(v.X, r.x + r.w + pad), math.min(v.Y, r.y + r.h + pad)
	faixas[1].Position, faixas[1].Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(v.X, y0)
	faixas[2].Position, faixas[2].Size = UDim2.fromOffset(0, y1), UDim2.fromOffset(v.X, math.max(0, v.Y - y1))
	faixas[3].Position, faixas[3].Size = UDim2.fromOffset(0, y0), UDim2.fromOffset(x0, y1 - y0)
	faixas[4].Position, faixas[4].Size = UDim2.fromOffset(x1, y0), UDim2.fromOffset(math.max(0, v.X - x1), y1 - y0)
	destaque.Position, destaque.Size, destaque.Visible = UDim2.fromOffset(x0, y0), UDim2.fromOffset(x1 - x0, y1 - y0), true
	return x0, y0, x1, y1
end

local function posicionarSeta(x0, y0, x1, y1, v, cardEmBaixo)
	if setaMov then setaMov:Cancel() end
	local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
	local base, desloc
	if (x1 - x0) < (y1 - y0) and cx < v.X * 0.3 then -- coluna na lateral esquerda: seta ao lado, apontando para a esquerda
		seta.Text = "◀"
		base, desloc = Vector2.new(x1 + 34, cy), Vector2.new(14, 0)
	elseif cardEmBaixo then -- o cartao fica embaixo, entao a seta fica embaixo do alvo apontando para cima
		seta.Text = "▲"
		base, desloc = Vector2.new(cx, y1 + 34), Vector2.new(0, 14)
	else
		seta.Text = "▼"
		base, desloc = Vector2.new(cx, y0 - 34), Vector2.new(0, -14)
	end
	seta.Position = UDim2.fromOffset(base.X, base.Y)
	seta.Visible = true
	setaMov = TweenService:Create(seta, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.fromOffset(base.X + desloc.X, base.Y + desloc.Y) })
	setaMov:Play()
end

local function terminar()
	if not rodando then return end
	rodando = false
	gui.Enabled = false
	if setaMov then setaMov:Cancel() end
	player:SetAttribute("TutorialAtivo", false)
	acaoServidor:FireServer("fim")
end

mostrar = function(n)
	local p = PASSOS[n]
	if not p then terminar() return end
	passo = n
	local v = workspace.CurrentCamera.ViewportSize
	escalaCard.Scale = math.clamp(math.min(v.X / 660, v.Y / 460), 0.55, 1.1)
	icone.Text, titulo.Text, corpo.Text = p[1], p[2], p[3]
	teclas(p[4])
	teclasLinha.Visible = p[4] ~= nil
	contador.Text = n .. " / " .. #PASSOS
	proximo.Text = n == #PASSOS and "LET'S GO!" or "NEXT ▶"
	pular.Visible = n < #PASSOS
	local alvo = p[5] and ALVO[p[5]]
	local ok, r = pcall(alvo or function() return nil end)
	r = ok and r or nil
	local x0, y0, x1, y1 = focar(r, v)
	-- o cartao vai para a metade da tela oposta ao alvo
	local emBaixo = true
	if r and (r.y + r.h / 2) > v.Y * 0.55 then emBaixo = false end
	local altura = 212 * escalaCard.Scale
	card.Position = UDim2.fromOffset(v.X / 2, emBaixo and (v.Y - altura / 2 - 24) or (altura / 2 + 24 + GuiService:GetGuiInset().Y))
	if r then posicionarSeta(x0, y0, x1, y1, v, emBaixo) end
end

proximo.Activated:Connect(function() mostrar(passo + 1) end)
pular.Activated:Connect(terminar)
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	if rodando then mostrar(passo) end
end)

local function comecar()
	if rodando then return end
	rodando = true
	player:SetAttribute("TutorialAtivo", true)
	gui.Enabled = true
	mostrar(1)
end

---------------------------------------------------------------
-- Botao HELP (repete o tour) e inicio automatico
---------------------------------------------------------------
local guiBotao = new("ScreenGui", { Name = "TutorialBotao", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 24, Parent = pg })
local botao = new("TextButton", { Name = "BotaoHelp", Size = UDim2.fromOffset(100, 40), BackgroundColor3 = COR.painel, Text = "❓ HELP", TextColor3 = COR.texto, Font = Enum.Font.GothamBlack, TextSize = 17, Visible = false, Parent = guiBotao })
canto(botao, 10)
new("UIStroke", { Color = COR.linha, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = botao })
local escalaBotao = new("UIScale", { Parent = botao })
local function posicionarBotao()
	local v = workspace.CurrentCamera.ViewportSize
	local sc = require(game:GetService("ReplicatedStorage"):WaitForChild("HudEscala")).Hud(v)
	escalaBotao.Scale = sc
	botao.Position = UDim2.fromOffset(512 * sc, GuiService:GetGuiInset().Y + 80 * sc)
end
posicionarBotao()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(posicionarBotao)
botao.Activated:Connect(comecar)

local function noMundo()
	local hud = pg:FindFirstChild("HUD")
	return player:GetAttribute("Jogando") == true and player:GetAttribute("InRun") ~= true and hud and hud:IsA("ScreenGui") and hud.Enabled
end
local function cla()
	local ok, t = pcall(HttpService.JSONDecode, HttpService, (function() local r = player:GetAttribute("PoderesEstado") return type(r) == "string" and r or "{}" end)())
	return ok and type(t) == "table" and type(t.Cla) == "string" and t.Cla ~= ""
end

task.spawn(function()
	while true do
		task.wait(0.5)
		botao.Visible = noMundo() and true or false
		if not rodando and player:GetAttribute("TutorialPendente") == true and noMundo() and cla()
			and player:GetAttribute("KekkeiRolou") ~= false and player:GetAttribute("NaturezaRolou") ~= false then
			task.wait(2) -- deixa a tela assentar depois da roleta
			if noMundo() and player:GetAttribute("TutorialPendente") == true then comecar() end
		end
	end
end)

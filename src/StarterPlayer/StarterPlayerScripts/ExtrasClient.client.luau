-- LocalScript: StarterPlayerScripts > ExtrasClient
-- Botoes DAILY e RANK (ao lado de CLAN e STATS) e as telas: missoes diarias + login de 7 dias, e ranking por nivel.
-- O cliente so MOSTRA: progresso, recompensas e ranking vem do servidor (DiariasServer e RankingServer).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local DiariasData = require(ReplicatedStorage:WaitForChild("DiariasData"))
local acao = ReplicatedStorage:WaitForChild("DiariasAcao")
local getRank = ReplicatedStorage:WaitForChild("GetRanking")

local COR = {
	fundo = Color3.fromRGB(12, 12, 14), painel = Color3.fromRGB(20, 20, 23), card = Color3.fromRGB(32, 32, 38), linha = Color3.fromRGB(70, 70, 80),
	texto = Color3.new(1, 1, 1), fraco = Color3.fromRGB(176, 176, 188), ouro = Color3.fromRGB(255, 205, 70), verde = Color3.fromRGB(70, 190, 110),
	laranja = Color3.fromRGB(255, 140, 40), vermelho = Color3.fromRGB(215, 70, 70),
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
local function borda(o, cor, t) return new("UIStroke", { Color = cor, Thickness = t or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o }) end
local function label(parent, texto, tam, cor, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = texto, TextSize = tam, TextColor3 = cor or COR.texto, Font = Enum.Font.GothamBold, TextWrapped = true, Parent = parent })
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end
local function botao(parent, texto, cor, size, pos)
	local b = new("TextButton", { Size = size, Position = pos, BackgroundColor3 = cor, Text = texto, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBlack, TextSize = 17, AutoButtonColor = true, Parent = parent })
	canto(b, 10)
	return b
end

local gui = new("ScreenGui", { Name = "Extras", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 24, Parent = player:WaitForChild("PlayerGui") })

---------------------------------------------------------------
-- Botoes (mesma escala e mesma linha dos botoes CLAN e STATS)
---------------------------------------------------------------
local botoes = {}
local function criarBotao(nome, texto, x, largura)
	local b = new("TextButton", { Name = nome, Size = UDim2.fromOffset(largura, 40), BackgroundColor3 = COR.painel, Text = texto, TextColor3 = COR.texto, Font = Enum.Font.GothamBlack, TextSize = 17, Visible = false, Parent = gui })
	canto(b, 10)
	borda(b, COR.linha, 2)
	local escala = new("UIScale", { Parent = b })
	local bolinha = label(b, "", 13, COR.texto, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 8, 0, -8), Size = UDim2.fromOffset(28, 22), BackgroundTransparency = 0, BackgroundColor3 = COR.vermelho, Font = Enum.Font.GothamBlack, Visible = false })
	canto(bolinha, 11)
	table.insert(botoes, { b = b, x = x, escala = escala })
	return b, bolinha
end
local bDiaria, pontoDiaria = criarBotao("BotaoDaily", "📅 DAILY", 274, 118)
local bRank = criarBotao("BotaoRank", "🏆 RANK", 400, 100)

local function posicionar()
	local v = workspace.CurrentCamera.ViewportSize
	local sc = math.clamp(math.min(v.X / 1150, v.Y / 680), 0.5, 1.1)
	for _, e in ipairs(botoes) do
		e.escala.Scale = sc
		e.b.Position = UDim2.fromOffset(e.x * sc, GuiService:GetGuiInset().Y + 80 * sc)
	end
end
posicionar()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(posicionar)

---------------------------------------------------------------
-- Janela
---------------------------------------------------------------
local fundo = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Active = true, Visible = false, Parent = gui })
local painel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(780, 540), BackgroundColor3 = COR.painel, Parent = fundo })
canto(painel, 12)
borda(painel, COR.ouro, 2)
local escalaPainel = new("UIScale", { Parent = painel })
local function ajustar()
	local v = workspace.CurrentCamera.ViewportSize
	escalaPainel.Scale = math.clamp(math.min(v.X / 850, v.Y / 600), 0.5, 1.15)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajustar)
ajustar()
local titulo = label(painel, "", 26, COR.texto, { Position = UDim2.fromOffset(20, 10), Size = UDim2.fromOffset(420, 36), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left })
local reset = label(painel, "", 18, COR.fraco, { Position = UDim2.new(1, -330, 0, 14), Size = UDim2.fromOffset(250, 28), TextXAlignment = Enum.TextXAlignment.Right })
local fechar = botao(painel, "X", COR.card, UDim2.fromOffset(44, 36), UDim2.new(1, -60, 0, 10))
local telaD = new("Frame", { Position = UDim2.fromOffset(20, 56), Size = UDim2.new(1, -40, 1, -70), BackgroundTransparency = 1, Parent = painel })
local telaR = new("Frame", { Position = UDim2.fromOffset(20, 56), Size = UDim2.new(1, -40, 1, -70), BackgroundTransparency = 1, Visible = false, Parent = painel })

local avisoAtual
local function aviso(texto, cor)
	if avisoAtual then avisoAtual:Destroy() end
	avisoAtual = label(painel, texto, 18, cor or COR.ouro, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(500, 28), Font = Enum.Font.GothamBlack, ZIndex = 20 })
	local este = avisoAtual
	task.delay(2.5, function() if este.Parent then este:Destroy() end end)
end

local function limpar(f)
	for _, c in ipairs(f:GetChildren()) do c:Destroy() end
end

---------------------------------------------------------------
-- Diarias + login
---------------------------------------------------------------
local estadoAtual, t0 = nil, 0
local desenharDiarias

local function enviar(pedido, a)
	local ok, r = pcall(function() return acao:InvokeServer(pedido, a) end)
	if ok and r then
		if r.estado then
			estadoAtual, t0 = r.estado, os.clock()
			desenharDiarias(r.estado)
		end
		if not r.ok then aviso(r.erro or "Error", COR.vermelho) else aviso("Claimed!", COR.verde) end
	end
end

local function icone(r)
	return r.Gems and "💎" or r.Crates and "📦" or r.Item and "⚡" or "💰"
end

desenharDiarias = function(e)
	limpar(telaD)
	-- login de 7 dias
	label(telaD, "🎁 LOGIN STREAK", 20, COR.ouro, { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(300, 28), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left })
	local pegoHoje = e.Login.Pego
	local bl = botao(telaD, pegoHoje and "✔ Come back tomorrow" or ("🎁 CLAIM DAY " .. e.Login.Proximo), pegoHoje and COR.linha or COR.verde, UDim2.fromOffset(300, 34), UDim2.new(1, -300, 0, -2))
	bl.Activated:Connect(function() if not pegoHoje then enviar("login") end end)
	for i, r in ipairs(DiariasData.LOGIN) do
		local hoje = i == e.Login.Proximo
		local pego = i < e.Login.Proximo or (hoje and pegoHoje)
		local tile = new("Frame", { Position = UDim2.fromOffset((i - 1) * 104, 36), Size = UDim2.fromOffset(98, 92), BackgroundColor3 = (hoje and not pego) and Color3.fromRGB(78, 62, 22) or COR.card, Parent = telaD })
		canto(tile, 10)
		borda(tile, pego and COR.verde or (hoje and COR.ouro or COR.linha), hoje and 3 or 2)
		label(tile, "DAY " .. i, 15, COR.fraco, { Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 20) })
		label(tile, icone(r), 32, COR.texto, { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 38) })
		label(tile, DiariasData.Chips(r), 13, COR.texto, { Position = UDim2.fromOffset(2, 62), Size = UDim2.new(1, -4, 0, 28) })
		if pego then label(tile, "✔", 24, COR.verde, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 2), Size = UDim2.fromOffset(26, 26), Font = Enum.Font.GothamBlack }) end
	end
	-- missoes do dia
	label(telaD, "📅 TODAY'S MISSIONS", 20, COR.ouro, { Position = UDim2.fromOffset(0, 138), Size = UDim2.fromOffset(400, 28), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left })
	for i, m in ipairs(e.Missoes) do
		local pronto = m.Prog >= m.N
		local y = 170 + (i - 1) * 72
		local row = new("Frame", { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 66), BackgroundColor3 = COR.card, Parent = telaD })
		canto(row, 10)
		borda(row, m.Pega and COR.verde or (pronto and COR.ouro or COR.linha), 2)
		local circ = new("Frame", { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(50, 50), BackgroundColor3 = COR.fundo, Parent = row })
		canto(circ, 25)
		label(circ, m.Emoji, 28, COR.texto, { Size = UDim2.fromScale(1, 1) })
		label(row, m.Texto, 18, COR.texto, { Position = UDim2.fromOffset(72, 5), Size = UDim2.fromOffset(360, 26), TextXAlignment = Enum.TextXAlignment.Left })
		local barra = new("Frame", { Position = UDim2.fromOffset(72, 36), Size = UDim2.fromOffset(340, 20), BackgroundColor3 = COR.fundo, Parent = row })
		canto(barra, 10)
		local fill = new("Frame", { Size = UDim2.fromScale(math.clamp(m.Prog / m.N, 0, 1), 1), BackgroundColor3 = pronto and COR.verde or COR.ouro, Parent = barra })
		canto(fill, 10)
		label(barra, ("%d / %d"):format(m.Prog, m.N), 15, COR.texto, { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack, ZIndex = 3 })
		label(row, DiariasData.Chips({ Coins = m.Coins, XP = m.XP }), 17, COR.texto, { Position = UDim2.fromOffset(430, 0), Size = UDim2.fromOffset(170, 66) })
		local b = botao(row, m.Pega and "✔ DONE" or (pronto and "CLAIM" or "🔒"), m.Pega and COR.linha or (pronto and COR.verde or COR.card), UDim2.fromOffset(120, 42), UDim2.new(1, -130, 0, 12))
		b.Activated:Connect(function() if pronto and not m.Pega then enviar("missao", i) end end)
	end
	-- bonus por fazer todas
	local todas = e.Feitas >= #e.Missoes
	local row = new("Frame", { Position = UDim2.fromOffset(0, 392), Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = Color3.fromRGB(62, 48, 22), Parent = telaD })
	canto(row, 10)
	borda(row, e.BonusPego and COR.verde or COR.ouro, 2)
	label(row, ("🎁 ALL DONE BONUS   %d / %d"):format(e.Feitas, #e.Missoes), 19, COR.ouro, { Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(330, 62), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left })
	label(row, DiariasData.Chips(e.Bonus), 18, COR.texto, { Position = UDim2.fromOffset(350, 0), Size = UDim2.fromOffset(250, 62) })
	local b = botao(row, e.BonusPego and "✔ DONE" or (todas and "CLAIM" or "🔒"), e.BonusPego and COR.linha or (todas and COR.verde or COR.card), UDim2.fromOffset(120, 42), UDim2.new(1, -130, 0, 10))
	b.Activated:Connect(function() if todas and not e.BonusPego then enviar("bonus") end end)
end

---------------------------------------------------------------
-- Ranking
---------------------------------------------------------------
local MEDALHA = { "🥇", "🥈", "🥉" }
local function linhaRank(parent, e, y, destaque)
	local row = new("Frame", { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, -8, 0, 56), BackgroundColor3 = destaque and Color3.fromRGB(62, 48, 22) or COR.card, Parent = parent })
	canto(row, 10)
	if destaque then borda(row, COR.ouro, 2) end
	local medalha = e.pos and MEDALHA[e.pos]
	label(row, medalha or (e.pos and ("#" .. e.pos) or "50+"), medalha and 32 or 22, COR.ouro, { Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(70, 56), Font = Enum.Font.GothamBlack })
	local foto = new("ImageLabel", { Position = UDim2.fromOffset(84, 6), Size = UDim2.fromOffset(44, 44), BackgroundColor3 = COR.fundo, Image = "rbxthumb://type=AvatarHeadShot&id=" .. e.id .. "&w=100&h=100", Parent = row })
	canto(foto, 22)
	label(row, destaque and (e.nome .. "  (you)") or e.nome, 21, COR.texto, { Position = UDim2.fromOffset(140, 0), Size = UDim2.new(1, -310, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false })
	label(row, "⭐ " .. e.nivel, 26, COR.ouro, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.fromOffset(150, 56), Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Right })
end

local function desenharRank(r)
	limpar(telaR)
	linhaRank(telaR, r.voce, 0, true)
	local lista = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 1, -66), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8,
		CanvasSize = UDim2.fromOffset(0, #r.lista * 62), Parent = telaR })
	for i, e in ipairs(r.lista) do linhaRank(lista, e, (i - 1) * 62, e.id == r.voce.id) end
	if #r.lista == 0 then label(lista, "No players yet.", 20, COR.fraco, { Size = UDim2.new(1, 0, 0, 60) }) end
end

---------------------------------------------------------------
-- Abrir / fechar
---------------------------------------------------------------
local aberta = nil
local function fecharTudo()
	fundo.Visible = false
	aberta = nil
end
local function abrir(nome)
	if aberta == nome then fecharTudo() return end
	aberta = nome
	fundo.Visible = true
	telaD.Visible, telaR.Visible = nome == "diarias", nome == "rank"
	reset.Visible = nome == "diarias"
	titulo.Text = nome == "diarias" and "📅 DAILY MISSIONS" or "🏆 LEVEL RANKING"
	task.spawn(function()
		if nome == "diarias" then
			local ok, r = pcall(function() return acao:InvokeServer("estado") end)
			if ok and r and r.estado and aberta == nome then
				estadoAtual, t0 = r.estado, os.clock()
				desenharDiarias(r.estado)
			end
		else
			local ok, r = pcall(function() return getRank:InvokeServer() end)
			if ok and r and aberta == nome then desenharRank(r) end
		end
	end)
end
bDiaria.Activated:Connect(function() abrir("diarias") end)
bRank.Activated:Connect(function() abrir("rank") end)
fechar.Activated:Connect(fecharTudo)

task.spawn(function()
	while true do
		task.wait(1)
		if aberta == "diarias" and estadoAtual then
			local s = math.max(0, estadoAtual.Reset - math.floor(os.clock() - t0))
			reset.Text = ("⏳ Resets in %02d:%02d:%02d"):format(s // 3600, (s // 60) % 60, s % 60)
		end
	end
end)

---------------------------------------------------------------
-- Visibilidade, bolinha de pendencias e abertura automatica do login do dia
---------------------------------------------------------------
local function atualizar()
	local ligado = player:GetAttribute("Jogando") == true and player:GetAttribute("InRun") ~= true
	for _, e in ipairs(botoes) do e.b.Visible = ligado end
	if not ligado then fecharTudo() end
	local n = player:GetAttribute("DiariasPendentes") or 0
	pontoDiaria.Visible = n > 0
	pontoDiaria.Text = tostring(n)
end
local autoAbriu = false
local function tentarAuto()
	atualizar()
	if autoAbriu or player:GetAttribute("Jogando") ~= true or player:GetAttribute("InRun") == true then return end
	if player:GetAttribute("TutorialAtivo") == true or player:GetAttribute("TutorialPendente") == true or (player:GetAttribute("DiariasPendentes") or 0) <= 0 then return end
	local raw = player:GetAttribute("PoderesEstado") -- so depois de ter cla (a roleta vem primeiro)
	local ok, t = pcall(HttpService.JSONDecode, HttpService, type(raw) == "string" and raw or "{}")
	if not (ok and type(t) == "table" and type(t.Cla) == "string" and t.Cla ~= "") then return end
	autoAbriu = true
	task.wait(2.5)
	if aberta == nil and player:GetAttribute("TutorialAtivo") ~= true and player:GetAttribute("TutorialPendente") ~= true then abrir("diarias") end
end
for _, nome in ipairs({ "Jogando", "InRun", "DiariasPendentes", "PoderesEstado", "TutorialAtivo", "TutorialPendente" }) do
	player:GetAttributeChangedSignal(nome):Connect(function() task.spawn(tentarAuto) end)
end
task.spawn(tentarAuto)

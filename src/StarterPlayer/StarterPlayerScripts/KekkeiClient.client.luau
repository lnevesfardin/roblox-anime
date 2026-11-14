-- LocalScript: StarterPlayerScripts > KekkeiClient
-- Tela BLOODLINE: aparece depois do PLAY, antes da roleta do clã, para quem ainda não usou
-- o único giro de Kekkei Genkai. Também mostra a kekkei genkai no HUD, na fileira de botões, depois do HELP.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local KekkeiData = require(ReplicatedStorage:WaitForChild("KekkeiData"))
local Vinheta = require(ReplicatedStorage:WaitForChild("Vinheta"))
local acao = ReplicatedStorage:WaitForChild("KekkeiAcao")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local COR = {
	fundo = Color3.fromRGB(10, 8, 14),
	painel = Color3.fromRGB(20, 18, 26),
	card = Color3.fromRGB(32, 28, 40),
	laranja = Color3.fromRGB(255, 140, 40),
	texto = Color3.new(1, 1, 1),
	fraco = Color3.fromRGB(180, 175, 190),
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
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, TextColor3 = color,
		Font = Enum.Font.GothamBold, TextWrapped = true, Parent = parent })
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end

---------------------------------------------------------------
-- Tela BLOODLINE
---------------------------------------------------------------

local gui = new("ScreenGui", { Name = "BloodlineUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20, Enabled = false, Parent = pg })
local fundo = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = COR.fundo, BackgroundTransparency = 0.08, Parent = gui })
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(60, 10, 20), Color3.fromRGB(10, 8, 14)), Parent = fundo })

local caixa = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(560, 420), BackgroundTransparency = 1, Parent = fundo })
local escala = new("UIScale", { Parent = caixa })
local function ajustar()
	local vp = workspace.CurrentCamera.ViewportSize
	escala.Scale = math.clamp(math.min(vp.X / 620, vp.Y / 480), 0.55, 1.2)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajustar)
ajustar()

label(caixa, "BLOODLINE", 40, COR.texto, { Size = UDim2.new(1, 0, 0, 48), Font = Enum.Font.GothamBlack })
label(caixa, "Some ninjas are born with a Kekkei Genkai. You only get ONE chance — choose your moment.", 15, COR.fraco,
	{ Position = UDim2.fromOffset(20, 50), Size = UDim2.new(1, -40, 0, 40) })

local card = new("Frame", { Position = UDim2.fromOffset(80, 104), Size = UDim2.new(1, -160, 0, 190), BackgroundColor3 = COR.card, Parent = caixa })
new("UICorner", { CornerRadius = UDim.new(0, 16), Parent = card })
local borda = new("UIStroke", { Color = Color3.fromRGB(90, 80, 110), Thickness = 3, Parent = card })
local nome = label(card, "?", 54, COR.texto, { Position = UDim2.fromOffset(10, 18), Size = UDim2.new(1, -20, 0, 64), Font = Enum.Font.GothamBlack, TextScaled = true })
new("UITextSizeConstraint", { MaxTextSize = 54, Parent = nome })
local raridade = label(card, "", 14, COR.fraco, { Position = UDim2.fromOffset(10, 86), Size = UDim2.new(1, -20, 0, 18), Font = Enum.Font.GothamBlack })
local detalhe = label(card, "", 14, COR.texto, { Position = UDim2.fromOffset(18, 110), Size = UDim2.new(1, -36, 0, 70), Font = Enum.Font.Gotham, TextYAlignment = Enum.TextYAlignment.Top })

local botao = new("TextButton", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 318), Size = UDim2.fromOffset(320, 60),
	BackgroundColor3 = COR.laranja, Text = "REVEAL MY BLOODLINE", Font = Enum.Font.GothamBlack, TextSize = 20, TextColor3 = COR.texto, Parent = caixa })
new("UICorner", { CornerRadius = UDim.new(0, 14), Parent = botao })
local aviso = label(caixa, "", 13, Color3.fromRGB(255, 120, 120), { Position = UDim2.fromOffset(20, 384), Size = UDim2.new(1, -40, 0, 20) })

local fase = "girar" -- "girar" -> "girando" -> "fim"

local function mostrarResultado(id)
	if id and KekkeiData.Tipos[id] then
		local k = KekkeiData.Tipos[id]
		nome.Text = k.Name
		nome.TextColor3 = k.Color
		raridade.Text = k.Rarity:upper()
		raridade.TextColor3 = KekkeiData.Rarities[k.Rarity] or COR.fraco
		borda.Color = KekkeiData.Rarities[k.Rarity] or k.Color
		detalhe.Text = ("Passive: %s\nPower [%s]: learn it later in a mission with Lady Tsuna"):format(k.Passivo, KekkeiData.TECLA)
	else
		nome.Text = "No Kekkei Genkai"
		nome.TextColor3 = COR.fraco
		raridade.Text = "COMMON BLOOD"
		raridade.TextColor3 = COR.fraco
		borda.Color = Color3.fromRGB(90, 80, 110)
		detalhe.Text = "Your strength will come from your clan, your training and your fighting style."
	end
	detalhe.TextXAlignment = Enum.TextXAlignment.Center
end

-- roleta de nomes que vai desacelerando até parar no resultado
local function rolar(final)
	local nomes = { "None" }
	for _, id in ipairs(KekkeiData.Order) do table.insert(nomes, id) end
	local t, passo = 0, 0.05
	local i = 1
	while t < 2.6 do
		local id = nomes[(i % #nomes) + 1]
		local k = KekkeiData.Tipos[id]
		nome.Text = k and k.Name or "None"
		nome.TextColor3 = k and k.Color or COR.fraco
		borda.Color = k and (KekkeiData.Rarities[k.Rarity] or k.Color) or Color3.fromRGB(90, 80, 110)
		i += 1
		task.wait(passo)
		t += passo
		passo = math.min(passo * 1.09, 0.32)
	end
	mostrarResultado(final)
	card.Size = UDim2.new(1, -150, 0, 200)
	TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.new(1, -160, 0, 190) }):Play()
end

botao.MouseButton1Click:Connect(function()
	if fase == "girar" then
		fase = "girando"
		botao.Text = "..."
		aviso.Text = ""
		local ok, r = pcall(function() return acao:InvokeServer("girar") end)
		if not ok or not r then
			fase = "girar"
			botao.Text = "REVEAL MY BLOODLINE"
			aviso.Text = "Could not reach the server. Try again."
			return
		end
		if not r.ok and not r.Rolou then
			fase = "girar"
			botao.Text = "REVEAL MY BLOODLINE"
			aviso.Text = r.erro or "Try again."
			return
		end
		raridade.Text = ""
		detalhe.Text = ""
		rolar(r.Id)
		-- vinheta de revelação
		local k = r.Id and KekkeiData.Tipos[r.Id]
		if k then
			Vinheta.Revelar(k.Name, k.Rarity .. " bloodline", k.Color, true)
		else
			Vinheta.Revelar("No Kekkei Genkai", "Common blood", Color3.fromRGB(175, 175, 185), false)
		end
		fase = "fim"
		botao.Text = "CONTINUE"
	elseif fase == "fim" then
		gui.Enabled = false
	end
end)

local function precisaGirar()
	-- o giro agora fica na aba BLOODLINE da sala do clã (ClanClient): esta tela não abre mais sozinha
	return false
end
local function checar()
	if fase ~= "fim" and precisaGirar() then
		gui.Enabled = true
	elseif fase == "girar" then
		gui.Enabled = false
	end
end
player:GetAttributeChangedSignal("KekkeiRolou"):Connect(checar)
player:GetAttributeChangedSignal("Jogando"):Connect(checar)
checar()

---------------------------------------------------------------
-- Selo no HUD, na fileira de botões (depois do HELP)
---------------------------------------------------------------

local selo
local function botaoStats()
	local a = pg:FindFirstChild("AtributosUI")
	if not a then return nil end
	for _, d in ipairs(a:GetDescendants()) do
		if d:IsA("TextButton") and d.Text == "STATS" then return d end
	end
	return nil
end

local function atualizarSelo()
	local id = player:GetAttribute("Kekkei")
	local k = id and KekkeiData.Tipos[id]
	local stats = botaoStats()
	if not stats then return end
	if not selo then
		selo = stats:Clone()
		selo.Name = "SeloKekkei"
		for _, c in ipairs(selo:GetChildren()) do
			if not (c:IsA("UICorner") or c:IsA("UIStroke") or c:IsA("UIGradient") or c:IsA("UIPadding")) then
				c:Destroy()
			end
		end
		selo.AutoButtonColor = false
		selo.Size = UDim2.fromOffset(150, stats.Size.Y.Offset)
		selo.TextScaled = true
		new("UITextSizeConstraint", { MaxTextSize = stats.TextSize, Parent = selo })
		new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = selo })
		-- mesma escala e mesma linha dos botões do HUD (clã 16, STATS 158, DAILY 274, RANK 400, HELP 512): vem depois do HELP
		local seloEscala = new("UIScale", { Parent = selo })
		local function posicionarSelo()
			local v = workspace.CurrentCamera.ViewportSize
			local sc = require(ReplicatedStorage:WaitForChild("HudEscala")).Hud(v)
			seloEscala.Scale = sc
			selo.Position = UDim2.fromOffset(624 * sc, game:GetService("GuiService"):GetGuiInset().Y + 80 * sc)
		end
		posicionarSelo()
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(posicionarSelo)
		selo.Parent = stats.Parent
	end
	selo.Visible = k ~= nil
	if k then
		selo.Text = k.Name:upper()
		selo.TextColor3 = k.Color
	end
end
player:GetAttributeChangedSignal("Kekkei"):Connect(atualizarSelo)
task.spawn(function()
	for _ = 1, 40 do
		if botaoStats() then break end
		task.wait(0.5)
	end
	atualizarSelo()
end)

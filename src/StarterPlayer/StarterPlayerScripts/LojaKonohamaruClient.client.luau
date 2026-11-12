-- Konohamaru: diálogo + loja de personalização (comprar com moedas e equipar acessórios)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local abrir = ReplicatedStorage:WaitForChild("AbrirLojaKonohamaru")
local acao = ReplicatedStorage:WaitForChild("LojaKonohamaru")
local equipar = ReplicatedStorage:WaitForChild("EquipCosmetic")

local SLOT = { Cabeca = "HEAD", Pescoco = "NECK", Aura = "AURA", Rastro = "TRAIL" }
local COR = {
	fundo = Color3.fromRGB(28, 24, 34), card = Color3.fromRGB(44, 38, 52), laranja = Color3.fromRGB(255, 140, 40),
	verde = Color3.fromRGB(70, 190, 100), cinza = Color3.fromRGB(90, 85, 100), ouro = Color3.fromRGB(255, 205, 90),
}

local function new(classe, props, filhos)
	local o = Instance.new(classe)
	for k, v in pairs(props) do
		if k ~= "Parent" then o[k] = v end
	end
	for _, f in ipairs(filhos or {}) do f.Parent = o end
	o.Parent = props.Parent
	return o
end
local function canto(r) return new("UICorner", { CornerRadius = UDim.new(0, r or 10) }) end

local gui = new("ScreenGui", { Name = "LojaKonohamaruUI", ResetOnSpawn = false, DisplayOrder = 12, Enabled = false, Parent = player:WaitForChild("PlayerGui") })

-- diálogo
local dialogo = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -130), Size = UDim2.fromOffset(560, 150),
	BackgroundColor3 = COR.fundo, BackgroundTransparency = 0.05, Parent = gui }, { canto(14), new("UIStroke", { Color = COR.laranja, Thickness = 2 }) })
new("TextLabel", { Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -36, 0, 26), BackgroundTransparency = 1, Text = "KONOHAMARU",
	Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = COR.laranja, TextXAlignment = Enum.TextXAlignment.Left, Parent = dialogo })
local fala = new("TextLabel", { Position = UDim2.fromOffset(18, 38), Size = UDim2.new(1, -36, 0, 54), BackgroundTransparency = 1, Text = "",
	Font = Enum.Font.GothamMedium, TextSize = 16, TextWrapped = true, TextColor3 = Color3.new(1, 1, 1),
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = dialogo })
local bLoja = new("TextButton", { Position = UDim2.new(1, -330, 1, -48), Size = UDim2.fromOffset(180, 36), BackgroundColor3 = COR.laranja,
	Text = "GEAR SHOP", Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), Parent = dialogo }, { canto(8) })
local bTchau = new("TextButton", { Position = UDim2.new(1, -140, 1, -48), Size = UDim2.fromOffset(122, 36), BackgroundColor3 = COR.cinza,
	Text = "BYE", Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), Parent = dialogo }, { canto(8) })

-- loja
local loja = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(620, 430),
	BackgroundColor3 = COR.fundo, Visible = false, Parent = gui }, { canto(16), new("UIStroke", { Color = COR.laranja, Thickness = 2 }) })
new("TextLabel", { Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -40, 0, 30), BackgroundTransparency = 1, Text = "KONOHAMARU'S GEAR SHOP",
	Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = COR.laranja, TextXAlignment = Enum.TextXAlignment.Left, Parent = loja })
local moedas = new("TextLabel", { Position = UDim2.new(1, -230, 0, 14), Size = UDim2.fromOffset(170, 26), BackgroundTransparency = 1, Text = "",
	Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = COR.ouro, TextXAlignment = Enum.TextXAlignment.Right, Parent = loja })
local bFechar = new("TextButton", { Position = UDim2.new(1, -48, 0, 12), Size = UDim2.fromOffset(34, 30), BackgroundColor3 = Color3.fromRGB(180, 50, 50),
	Text = "X", Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), Parent = loja }, { canto(8) })
local aviso = new("TextLabel", { Position = UDim2.new(0, 20, 1, -34), Size = UDim2.new(1, -40, 0, 24), BackgroundTransparency = 1, Text = "",
	Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.fromRGB(255, 120, 120), Parent = loja })
local lista = new("ScrollingFrame", { Position = UDim2.fromOffset(16, 52), Size = UDim2.new(1, -32, 1, -92), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = loja })
new("UIGridLayout", { CellSize = UDim2.fromOffset(282, 78), CellPadding = UDim2.fromOffset(10, 10), Parent = lista })

local function mostrarAviso(t, cor)
	aviso.Text = t or ""
	aviso.TextColor3 = cor or Color3.fromRGB(255, 120, 120)
	task.delay(2.5, function()
		if aviso.Text == t then aviso.Text = "" end
	end)
end

local desenhar
local ocupado = false
local function clicar(it)
	if ocupado then return end
	ocupado = true
	local r
	if not it.tem then
		r = acao:InvokeServer("comprar", it.id)
		if r and r.ok then mostrarAviso("Bought " .. it.nome .. "!", COR.verde) end
	elseif it.usando then
		r = equipar:InvokeServer(nil, it.slot)
	else
		r = equipar:InvokeServer(it.id)
	end
	if r and not r.ok and r.reason then mostrarAviso(r.reason) end
	local e = acao:InvokeServer("listar")
	if e and e.ok then desenhar(e.estado) end
	ocupado = false
end

desenhar = function(estado)
	for _, c in ipairs(lista:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	moedas.Text = "Coins: " .. tostring(estado.coins)
	for i, it in ipairs(estado.itens) do
		local card = new("Frame", { LayoutOrder = i, BackgroundColor3 = COR.card, Parent = lista }, { canto(10) })
		new("Frame", { Position = UDim2.fromOffset(10, 14), Size = UDim2.fromOffset(50, 50), BackgroundColor3 = it.cor, Parent = card }, { canto(25) })
		new("TextLabel", { Position = UDim2.fromOffset(70, 10), Size = UDim2.new(1, -80, 0, 22), BackgroundTransparency = 1, Text = it.nome,
			Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
		new("TextLabel", { Position = UDim2.fromOffset(70, 30), Size = UDim2.fromOffset(100, 16), BackgroundTransparency = 1, Text = SLOT[it.slot] or it.slot,
			Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Color3.fromRGB(180, 170, 200), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
		local texto, cor
		if not it.tem then
			texto, cor = tostring(it.preco) .. " COINS", COR.laranja
		elseif it.usando then
			texto, cor = "EQUIPPED", COR.verde
		else
			texto, cor = "EQUIP", COR.cinza
		end
		local b = new("TextButton", { Position = UDim2.new(1, -122, 1, -36), Size = UDim2.fromOffset(112, 28), BackgroundColor3 = cor,
			Text = texto, Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), Parent = card }, { canto(6) })
		b.MouseButton1Click:Connect(function() clicar(it) end)
	end
end

local function fechar()
	gui.Enabled = false
	dialogo.Visible = false
	loja.Visible = false
end

abrir.OnClientEvent:Connect(function(texto)
	fala.Text = texto
	loja.Visible = false
	dialogo.Visible = true
	gui.Enabled = true
end)
bTchau.MouseButton1Click:Connect(fechar)
bFechar.MouseButton1Click:Connect(fechar)
bLoja.MouseButton1Click:Connect(function()
	dialogo.Visible = false
	loja.Visible = true
	moedas.Text = "Loading..."
	local e = acao:InvokeServer("listar")
	if e and e.ok then desenhar(e.estado) else mostrarAviso(e and e.reason or "Try again.") end
end)

-- fecha se o jogador se afastar do Konohamaru
task.spawn(function()
	while true do
		task.wait(0.5)
		if gui.Enabled then
			local k = workspace:FindFirstChild("Konohamaru")
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if k and root and (k:GetPivot().Position - root.Position).Magnitude > 25 then fechar() end
		end
	end
end)

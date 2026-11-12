-- Escolha de dificuldade (Fácil/Médio/Difícil) ao usar um portal de ondas
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local escolher = ReplicatedStorage:WaitForChild("EscolherDificuldade")

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

local gui = new("ScreenGui", { Name = "DificuldadeUI", ResetOnSpawn = false, DisplayOrder = 13, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
local painel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(600, 300),
	BackgroundColor3 = Color3.fromRGB(26, 24, 32), Parent = gui }, { canto(16), new("UIStroke", { Color = Color3.fromRGB(255, 140, 40), Thickness = 2 }) })
local titulo = new("TextLabel", { Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -80, 0, 30), BackgroundTransparency = 1, Text = "",
	Font = Enum.Font.GothamBlack, TextSize = 24, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = painel })
new("TextLabel", { Position = UDim2.fromOffset(20, 44), Size = UDim2.new(1, -40, 0, 20), BackgroundTransparency = 1, Text = "Choose the difficulty. Harder waves give more XP and coins.",
	Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = Color3.fromRGB(190, 185, 200), TextXAlignment = Enum.TextXAlignment.Left, Parent = painel })
local fechar = new("TextButton", { Position = UDim2.new(1, -50, 0, 14), Size = UDim2.fromOffset(34, 30), BackgroundColor3 = Color3.fromRGB(180, 50, 50),
	Text = "X", Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), Parent = painel }, { canto(8) })
local linha = new("Frame", { Position = UDim2.fromOffset(20, 80), Size = UDim2.new(1, -40, 1, -100), BackgroundTransparency = 1, Parent = painel })
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = linha })

local atual
fechar.MouseButton1Click:Connect(function()
	gui.Enabled = false
	atual = nil
end)

escolher.OnClientEvent:Connect(function(info)
	atual = info.mapId
	titulo.Text = string.upper(info.nome)
	for _, c in ipairs(linha:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end
	for i, op in ipairs(info.opcoes) do
		local b = new("TextButton", { LayoutOrder = i, Size = UDim2.fromOffset(176, 196), BackgroundColor3 = op.cor, AutoButtonColor = true, Text = "", Parent = linha }, { canto(12) })
		new("TextLabel", { Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = op.nome,
			Font = Enum.Font.GothamBlack, TextSize = 28, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.6, Parent = b })
		new("TextLabel", { Position = UDim2.fromOffset(10, 66), Size = UDim2.new(1, -20, 0, 20), BackgroundTransparency = 1,
			Text = ("Enemy HP x%.1f"):format(op.vida), Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = Color3.new(1, 1, 1), Parent = b })
		new("TextLabel", { Position = UDim2.fromOffset(10, 100), Size = UDim2.new(1, -20, 0, 22), BackgroundTransparency = 1,
			Text = ("+%d XP"):format(op.xp), Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), Parent = b })
		new("TextLabel", { Position = UDim2.fromOffset(10, 126), Size = UDim2.new(1, -20, 0, 22), BackgroundTransparency = 1,
			Text = ("+%d COINS"):format(op.moedas), Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = Color3.fromRGB(255, 235, 140), Parent = b })
		new("TextLabel", { Position = UDim2.new(0, 10, 1, -36), Size = UDim2.new(1, -20, 0, 24), BackgroundTransparency = 1, Text = "START",
			Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), Parent = b })
		b.MouseButton1Click:Connect(function()
			if atual then
				escolher:FireServer(atual, op.id)
				atual = nil
				gui.Enabled = false
			end
		end)
	end
	gui.Enabled = true
end)

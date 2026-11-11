-- LocalScript: StarterPlayerScripts > ViagemClient
-- Botão TRAVEL (ou tecla T): abre a lista de destinos e pede ao servidor o lançamento do clone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local TravelData = require(ReplicatedStorage:WaitForChild("TravelData"))
local travel = ReplicatedStorage:WaitForChild("Travel")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "ViagemUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 14
gui.Enabled = player:GetAttribute("Jogando") == true
gui.Parent = player:WaitForChild("PlayerGui")
player:GetAttributeChangedSignal("Jogando"):Connect(function()
	gui.Enabled = player:GetAttribute("Jogando") == true
end)

local function canto(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = o
end
local function botao(parent, texto, cor, size, pos)
	local b = Instance.new("TextButton")
	b.Size, b.Position = size, pos
	b.BackgroundColor3 = cor
	b.Text = texto
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 14
	b.Parent = parent
	canto(b, 10)
	return b
end

-- canto inferior esquerdo
local abrir = botao(gui, "🌀 TRAVEL  [T]", Color3.fromRGB(20, 20, 23), UDim2.fromOffset(132, 36), UDim2.new(0, 12, 1, -48))
local borda = Instance.new("UIStroke")
borda.Color = Color3.fromRGB(58, 58, 64)
borda.Thickness = 2
borda.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
borda.Parent = abrir

local lista = Instance.new("Frame")
lista.AnchorPoint = Vector2.new(0, 1)
lista.Position = UDim2.new(0, 12, 1, -56) -- abre para cima do botão
lista.Size = UDim2.fromOffset(190, #TravelData.Destinos * 40 + 34)
lista.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
lista.Visible = false
lista.Parent = gui
canto(lista, 12)
local aviso = Instance.new("TextLabel")
aviso.BackgroundTransparency = 1
aviso.Position = UDim2.new(0, 8, 1, -28)
aviso.Size = UDim2.new(1, -16, 0, 22)
aviso.Font = Enum.Font.GothamBold
aviso.TextSize = 12
aviso.TextColor3 = Color3.fromRGB(140, 140, 150)
aviso.Text = "A clone throws you there"
aviso.Parent = lista

for i, d in ipairs(TravelData.Destinos) do
	local b = botao(lista, d.Name, Color3.fromRGB(30, 30, 34), UDim2.new(1, -16, 0, 34), UDim2.fromOffset(8, 8 + (i - 1) * 40))
	b.MouseButton1Click:Connect(function()
		local r = travel:InvokeServer(d.Id)
		if r and r.ok then
			lista.Visible = false
			aviso.Text = "A clone throws you there"
		else
			aviso.Text = (r and r.erro) or "Could not travel."
		end
	end)
end

abrir.MouseButton1Click:Connect(function()
	lista.Visible = not lista.Visible
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not gui.Enabled then return end
	if input.KeyCode == Enum.KeyCode.T then
		lista.Visible = not lista.Visible
	end
end)

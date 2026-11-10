-- LocalScript: StarterPlayerScripts > PainelCaixa
-- Painel na tela: mostra nível, XP e moedas, e tem o botão de abrir caixa.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local openCrate = ReplicatedStorage:WaitForChild("OpenCrate")
local stats = player:WaitForChild("leaderstats")

local CORES = {
	Comum = Color3.fromRGB(200, 200, 200),
	Raro = Color3.fromRGB(80, 160, 255),
	Epico = Color3.fromRGB(180, 90, 255),
	Lendario = Color3.fromRGB(255, 190, 40),
	Mistico = Color3.fromRGB(255, 70, 120),
}
local NOMES = { Comum = "Common", Raro = "Rare", Epico = "Epic", Lendario = "Legendary", Mistico = "Mythic" }

local gui = Instance.new("ScreenGui")
gui.Name = "PainelCaixa"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local painel = Instance.new("Frame")
painel.Size = UDim2.fromOffset(190, 136)
painel.Position = UDim2.new(0, 12, 0.5, -68)
painel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
painel.BackgroundTransparency = 0.1
painel.Parent = gui
Instance.new("UICorner", painel).CornerRadius = UDim.new(0, 12)

local function texto(y, tamanho, cor)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -20, 0, tamanho + 6)
	t.Position = UDim2.fromOffset(10, y)
	t.BackgroundTransparency = 1
	t.TextColor3 = cor or Color3.new(1, 1, 1)
	t.Font = Enum.Font.GothamBold
	t.TextSize = tamanho
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextWrapped = true
	t.Parent = painel
	return t
end

local info = texto(8, 14)
local moedas = texto(28, 14, Color3.fromRGB(255, 215, 80))

local botao = Instance.new("TextButton")
botao.Size = UDim2.new(1, -20, 0, 32)
botao.Position = UDim2.fromOffset(10, 50)
botao.BackgroundColor3 = Color3.fromRGB(60, 140, 90)
botao.TextColor3 = Color3.new(1, 1, 1)
botao.Font = Enum.Font.GothamBold
botao.TextSize = 14
botao.Text = "Open Crate (100)"
botao.Parent = painel
Instance.new("UICorner", botao).CornerRadius = UDim.new(0, 8)

local resultado = texto(88, 13)
resultado.Size = UDim2.new(1, -20, 0, 42)
resultado.Text = "Click to open a crate"

local function atualizar()
	info.Text = ("Level %d   XP %d"):format(stats.Level.Value, stats.XP.Value)
	moedas.Text = ("Coins: %d"):format(stats.Coins.Value)
end
for _, v in ipairs(stats:GetChildren()) do
	v.Changed:Connect(atualizar)
end
atualizar()

local ocupado = false
botao.Activated:Connect(function()
	if ocupado then return end
	ocupado = true
	botao.Text = "Opening..."
	local r = openCrate:InvokeServer("Basica")
	if r.ok then
		local extra = r.isNew and "  NEW!" or ("  (x" .. r.copies .. ")")
		resultado.Text = r.name .. "\n" .. (NOMES[r.rarity] or r.rarity) .. extra
		resultado.TextColor3 = CORES[r.rarity] or Color3.new(1, 1, 1)
	else
		resultado.Text = r.reason
		resultado.TextColor3 = Color3.fromRGB(255, 90, 90)
	end
	botao.Text = "Open Crate (100)"
	ocupado = false
end)

-- Só aparece no lobby: some durante a partida
local function aplicarLobby()
	gui.Enabled = not player:GetAttribute("InRun")
end
player:GetAttributeChangedSignal("InRun"):Connect(aplicarLobby)
aplicarLobby()

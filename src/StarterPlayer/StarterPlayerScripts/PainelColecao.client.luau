-- LocalScript: StarterPlayerScripts > PainelColecao
-- Botão "Collection" + painel com os personagens (equipar / bloqueados).
-- Só aparece no lobby: some durante a partida.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local getCollection = ReplicatedStorage:WaitForChild("GetCollection")
local equipFunction = ReplicatedStorage:WaitForChild("EquipCharacter")

local CORES = {
	Comum = Color3.fromRGB(200, 200, 200),
	Raro = Color3.fromRGB(80, 160, 255),
	Epico = Color3.fromRGB(180, 90, 255),
	Lendario = Color3.fromRGB(255, 190, 40),
	Mistico = Color3.fromRGB(255, 70, 120),
}
local NOMES = { Comum = "Common", Raro = "Rare", Epico = "Epic", Lendario = "Legendary", Mistico = "Mythic" }

local gui = Instance.new("ScreenGui")
gui.Name = "PainelColecao"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local abrir = Instance.new("TextButton")
abrir.Size = UDim2.fromOffset(190, 30)
abrir.Position = UDim2.new(0, 12, 0.5, 74)
abrir.BackgroundColor3 = Color3.fromRGB(70, 90, 160)
abrir.TextColor3 = Color3.new(1, 1, 1)
abrir.Font = Enum.Font.GothamBold
abrir.TextSize = 14
abrir.Text = "Collection"
abrir.Parent = gui
Instance.new("UICorner", abrir).CornerRadius = UDim.new(0, 8)

local painel = Instance.new("Frame")
painel.Size = UDim2.fromOffset(330, 280)
painel.Position = UDim2.new(0.5, -165, 0.5, -140)
painel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
painel.BackgroundTransparency = 0.05
painel.Visible = false
painel.Parent = gui
Instance.new("UICorner", painel).CornerRadius = UDim.new(0, 12)

local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.new(1, -50, 0, 28)
titulo.Position = UDim2.fromOffset(12, 4)
titulo.BackgroundTransparency = 1
titulo.Font = Enum.Font.GothamBold
titulo.TextSize = 16
titulo.TextColor3 = Color3.new(1, 1, 1)
titulo.TextXAlignment = Enum.TextXAlignment.Left
titulo.Text = "Collection"
titulo.Parent = painel

local fechar = Instance.new("TextButton")
fechar.Size = UDim2.fromOffset(26, 26)
fechar.Position = UDim2.new(1, -34, 0, 4)
fechar.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
fechar.TextColor3 = Color3.new(1, 1, 1)
fechar.Font = Enum.Font.GothamBold
fechar.TextSize = 14
fechar.Text = "X"
fechar.Parent = painel
Instance.new("UICorner", fechar).CornerRadius = UDim.new(0, 8)

local aviso = Instance.new("TextLabel")
aviso.Size = UDim2.new(1, -24, 0, 18)
aviso.Position = UDim2.new(0, 12, 1, -22)
aviso.BackgroundTransparency = 1
aviso.Font = Enum.Font.Gotham
aviso.TextSize = 12
aviso.TextColor3 = Color3.fromRGB(255, 120, 120)
aviso.TextXAlignment = Enum.TextXAlignment.Left
aviso.Text = ""
aviso.Parent = painel

local lista = Instance.new("ScrollingFrame")
lista.Size = UDim2.new(1, -20, 1, -64)
lista.Position = UDim2.fromOffset(10, 36)
lista.BackgroundTransparency = 1
lista.BorderSizePixel = 0
lista.ScrollBarThickness = 5
lista.AutomaticCanvasSize = Enum.AutomaticSize.Y
lista.CanvasSize = UDim2.new()
lista.Parent = painel
local layout = Instance.new("UIListLayout", lista)
layout.Padding = UDim.new(0, 5)
layout.SortOrder = Enum.SortOrder.LayoutOrder

local function texto(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = props.font or Enum.Font.GothamBold
	t.TextSize = props.size or 14
	t.TextColor3 = props.color or Color3.new(1, 1, 1)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Size = props.s
	t.Position = props.p
	t.Text = props.text
	t.Parent = parent
	return t
end

local carregando = false
local function atualizar()
	if carregando then return end
	carregando = true
	local r = getCollection:InvokeServer()
	carregando = false
	for _, c in ipairs(lista:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	if not r or not r.ok then
		aviso.Text = r and r.reason or "Could not load."
		return
	end
	titulo.Text = ("Collection   (Level %d)"):format(r.level)
	for i, c in ipairs(r.list) do
		local dono = c.copies > 0
		local cor = CORES[c.rarity] or Color3.new(1, 1, 1)
		local linha = Instance.new("Frame")
		linha.LayoutOrder = i
		linha.Size = UDim2.new(1, -6, 0, 50)
		linha.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
		linha.Parent = lista
		Instance.new("UICorner", linha).CornerRadius = UDim.new(0, 8)
		local barra = Instance.new("Frame")
		barra.Size = UDim2.new(0, 4, 1, 0)
		barra.BackgroundColor3 = dono and cor or Color3.fromRGB(80, 80, 90)
		barra.BorderSizePixel = 0
		barra.Parent = linha
		Instance.new("UICorner", barra).CornerRadius = UDim.new(0, 8)

		if dono then
			texto(linha, { text = c.name .. (c.copies > 1 and ("  x" .. c.copies) or ""), color = cor, size = 14, s = UDim2.new(1, -100, 0, 18), p = UDim2.fromOffset(12, 4) })
			texto(linha, { text = ("%s  |  HP %d  |  DMG %d"):format(NOMES[c.rarity] or c.rarity, c.health, c.damage), size = 12, font = Enum.Font.Gotham, s = UDim2.new(1, -100, 0, 14), p = UDim2.fromOffset(12, 21) })
			texto(linha, { text = "Ability: " .. tostring(c.ability), size = 11, font = Enum.Font.Gotham, color = Color3.fromRGB(170, 170, 185), s = UDim2.new(1, -100, 0, 14), p = UDim2.fromOffset(12, 34) })
			local b = Instance.new("TextButton")
			b.Size = UDim2.fromOffset(80, 28)
			b.Position = UDim2.new(1, -88, 0.5, -14)
			b.Font = Enum.Font.GothamBold
			b.TextSize = 13
			b.TextColor3 = Color3.new(1, 1, 1)
			b.Parent = linha
			Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
			if r.equipped == c.id then
				b.Text = "Equipped"
				b.BackgroundColor3 = Color3.fromRGB(60, 110, 70)
				b.AutoButtonColor = false
			else
				b.Text = "Equip"
				b.BackgroundColor3 = Color3.fromRGB(60, 140, 90)
				b.Activated:Connect(function()
					aviso.Text = ""
					local e = equipFunction:InvokeServer(c.id)
					if e and e.ok then
						atualizar()
					else
						aviso.Text = e and e.reason or "Could not equip."
					end
				end)
			end
		else
			texto(linha, { text = "???", color = Color3.fromRGB(130, 130, 140), size = 14, s = UDim2.new(1, -20, 0, 18), p = UDim2.fromOffset(12, 6) })
			texto(linha, { text = ("%s  |  Not unlocked yet"):format(NOMES[c.rarity] or c.rarity), size = 12, font = Enum.Font.Gotham, color = Color3.fromRGB(130, 130, 140), s = UDim2.new(1, -20, 0, 14), p = UDim2.fromOffset(12, 28) })
		end
	end
end

abrir.Activated:Connect(function()
	painel.Visible = not painel.Visible
	aviso.Text = ""
	if painel.Visible then atualizar() end
end)
fechar.Activated:Connect(function()
	painel.Visible = false
end)

-- Se ganhar personagem novo com o painel aberto, atualiza sozinho
player:GetAttributeChangedSignal("OwnedRev"):Connect(function()
	if painel.Visible then task.defer(atualizar) end
end)

-- Só aparece no lobby: some durante a partida
local function aplicarLobby()
	local naPartida = player:GetAttribute("InRun")
	gui.Enabled = not naPartida
	if naPartida then painel.Visible = false end
end
player:GetAttributeChangedSignal("InRun"):Connect(aplicarLobby)
aplicarLobby()

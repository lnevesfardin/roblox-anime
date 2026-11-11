-- LocalScript: StarterPlayerScripts > AtributosClient
-- Botão STATS (ao lado do clã, embaixo do nível) e painel para gastar pontos de atributo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local AttributeData = require(ReplicatedStorage:WaitForChild("AttributeData"))
local action = ReplicatedStorage:WaitForChild("AttributeAction")
local notice = ReplicatedStorage:WaitForChild("AttributeNotice")
local player = Players.LocalPlayer

local COR = {
	painel = Color3.fromRGB(20, 20, 23), card = Color3.fromRGB(30, 30, 34), linha = Color3.fromRGB(58, 58, 64),
	texto = Color3.fromRGB(240, 240, 244), fraco = Color3.fromRGB(140, 140, 150), laranja = Color3.fromRGB(255, 140, 40),
	verde = Color3.fromRGB(70, 190, 110), vermelho = Color3.fromRGB(215, 70, 70),
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
local function label(parent, texto, tam, cor, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = texto, TextSize = tam, TextColor3 = cor or COR.texto, Font = Enum.Font.GothamBold, Parent = parent })
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end

local gui = new("ScreenGui", { Name = "AtributosUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 14, Parent = player:WaitForChild("PlayerGui") })
gui.Enabled = player:GetAttribute("Jogando") == true
player:GetAttributeChangedSignal("Jogando"):Connect(function()
	gui.Enabled = player:GetAttribute("Jogando") == true
end)

-- botão: fica na mesma linha do clã, logo abaixo da barra de nível do HUD
local abrir = new("TextButton", { Size = UDim2.fromOffset(104, 40), BackgroundColor3 = COR.painel, Text = "STATS", TextColor3 = COR.texto, Font = Enum.Font.GothamBlack, TextSize = 14, Parent = gui })
corner(abrir, 10)
new("UIStroke", { Color = COR.linha, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = abrir })
local escalaBtn = new("UIScale", { Parent = abrir })
local bolinha = label(abrir, "", 12, Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 8, 0, -8), Size = UDim2.fromOffset(30, 20), BackgroundTransparency = 0, BackgroundColor3 = COR.laranja, Font = Enum.Font.GothamBlack, Visible = false })
corner(bolinha, 10)
local function posicionar()
	local v = workspace.CurrentCamera.ViewportSize
	local sc = math.clamp(math.min(v.X / 1150, v.Y / 680), 0.5, 1.1) * 0.78 -- HUD compacto: tudo 22% menor (mesma escala do HUD)
	escalaBtn.Scale = sc
	abrir.Position = UDim2.fromOffset((16 + 142) * sc, GuiService:GetGuiInset().Y + 62 * sc)
end
posicionar()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(posicionar)

local painel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(500, 430), BackgroundColor3 = COR.painel, Visible = false, Parent = gui })
corner(painel, 16)
new("UIStroke", { Color = COR.laranja, Thickness = 3, Parent = painel })
local escala = new("UIScale", { Parent = painel })
local function ajustar()
	local v = workspace.CurrentCamera.ViewportSize
	escala.Scale = math.clamp(math.min(v.X / 560, v.Y / 480), 0.45, 1.1)
end
ajustar()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajustar)

label(painel, "ATTRIBUTES", 24, COR.texto, { Position = UDim2.fromOffset(20, 12), Size = UDim2.fromOffset(300, 30), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack })
local cabecalho = label(painel, "", 14, COR.laranja, { Position = UDim2.fromOffset(20, 42), Size = UDim2.fromOffset(440, 20), TextXAlignment = Enum.TextXAlignment.Left })
local fechar = new("TextButton", { Position = UDim2.new(1, -46, 0, 10), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = COR.card, Text = "X", TextColor3 = COR.texto, Font = Enum.Font.GothamBlack, TextSize = 16, Parent = painel })
corner(fechar, 8)

local linhas = {}
local estado
local atualizar
for i, info in ipairs(AttributeData.List) do
	local f = new("Frame", { Position = UDim2.fromOffset(20, 70 + (i - 1) * 54), Size = UDim2.fromOffset(460, 48), BackgroundColor3 = COR.card, Parent = painel })
	corner(f, 10)
	label(f, info.Name, 17, COR.texto, { Position = UDim2.fromOffset(14, 5), Size = UDim2.fromOffset(180, 20), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack })
	label(f, info.Desc, 12, COR.fraco, { Position = UDim2.fromOffset(14, 25), Size = UDim2.fromOffset(220, 16), TextXAlignment = Enum.TextXAlignment.Left })
	local valor = label(f, "0 / 12", 17, COR.texto, { Position = UDim2.fromOffset(250, 0), Size = UDim2.fromOffset(130, 48), Font = Enum.Font.GothamBlack })
	local mais = new("TextButton", { Position = UDim2.new(1, -52, 0, 7), Size = UDim2.fromOffset(40, 34), BackgroundColor3 = COR.verde, Text = "+", TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBlack, TextSize = 22, Parent = f })
	corner(mais, 8)
	linhas[info.Id] = { valor = valor, mais = mais }
	mais.MouseButton1Click:Connect(function()
		local r = action:InvokeServer("gastar", info.Id)
		if r and r.estado then estado = r.estado end
		atualizar(r and not r.ok and r.erro or nil)
	end)
end
local resumo = label(painel, "", 13, COR.texto, { Position = UDim2.fromOffset(20, 344), Size = UDim2.fromOffset(460, 36), TextWrapped = true })
local rodape = label(painel, "", 12, COR.fraco, { Position = UDim2.fromOffset(20, 384), Size = UDim2.fromOffset(460, 34), TextWrapped = true })

function atualizar(erro)
	local pontos = player:GetAttribute("PontosAtributo") or 0
	if estado then pontos = estado.Pontos end
	bolinha.Visible = pontos > 0
	bolinha.Text = "+" .. pontos
	if not estado then return end
	cabecalho.Text = ("LEVEL %d   ·   POINTS TO SPEND: %d   ·   CAP: %d"):format(estado.Level, estado.Pontos, estado.Cap)
	for id, l in pairs(linhas) do
		local v = estado.Valores[id] or 0
		l.valor.Text = v .. " / " .. estado.Cap
		local pode = estado.Pontos > 0 and v < estado.Cap
		l.mais.BackgroundColor3 = pode and COR.verde or COR.linha
	end
	resumo.Text = ("Health %d   ·   Chakra %d   ·   Punch x%.2f   ·   Power x%.2f   ·   Speed +%.1f"):format(estado.Vida, estado.Chakra, estado.Golpe, estado.Poder, estado.Velocidade)
	rodape.TextColor3 = erro and COR.vermelho or COR.fraco
	rodape.Text = erro or ("Training at the Ninja Academy: %d left today (%d coins each, +1 point)."):format(estado.Treino, AttributeData.TRAIN_COST)
end

local function carregar()
	local r = action:InvokeServer("estado")
	if r and r.estado then estado = r.estado end
	atualizar()
end
abrir.MouseButton1Click:Connect(function()
	painel.Visible = not painel.Visible
	if painel.Visible then carregar() end
end)
fechar.MouseButton1Click:Connect(function()
	painel.Visible = false
end)
player:GetAttributeChangedSignal("PontosAtributo"):Connect(function()
	estado = nil
	if painel.Visible then carregar() else atualizar() end
end)

-- aviso do treino (aparece embaixo, no meio da tela)
local toast = label(gui, "", 16, Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -150), Size = UDim2.fromOffset(420, 38), BackgroundTransparency = 0.15, BackgroundColor3 = COR.painel, Font = Enum.Font.GothamBlack, Visible = false })
corner(toast, 10)
local vez = 0
notice.OnClientEvent:Connect(function(texto, bom)
	vez += 1
	local minha = vez
	toast.Text = texto
	toast.TextColor3 = bom and COR.verde or COR.vermelho
	toast.Visible = true
	if painel.Visible then carregar() end
	task.delay(3, function()
		if vez == minha then toast.Visible = false end
	end)
end)

atualizar()

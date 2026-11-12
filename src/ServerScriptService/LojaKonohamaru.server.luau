-- Konohamaru: balcão SHOP da praça. Conversa engraçada + loja de personalização (acessórios por moedas).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local EconomyData = require(ReplicatedStorage:WaitForChild("EconomyData"))
local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))

local abrir = Instance.new("RemoteEvent")
abrir.Name = "AbrirLojaKonohamaru"
abrir.Parent = ReplicatedStorage

local acao = Instance.new("RemoteFunction")
acao.Name = "LojaKonohamaru"
acao.Parent = ReplicatedStorage

local FALAS = {
	"Hey! Wanna see my secret transformation jutsu? ...Grandpa banned it in public. Again. Anyway, want some cool gear?",
	"I'm gonna be Hokage one day! But first I need customers. Wanna look cool like me?",
	"Shh! I just invented a new jutsu. It's top secret... so how about a new headband instead?",
}

local PRECO = {}
for _, e in ipairs(EconomyData.LojaKonohamaru) do
	PRECO[e.Id] = e.Preco
end

local function estado(player)
	local data = PlayerData.Get(player)
	if not data then return nil end
	local itens = {}
	for _, e in ipairs(EconomyData.LojaKonohamaru) do
		local item = EconomyData.Items[e.Id]
		table.insert(itens, {
			id = e.Id, nome = item.Name, slot = item.Slot, cor = item.Color, preco = e.Preco,
			tem = (data.Items[e.Id] or 0) > 0, usando = data.Cosmetics[item.Slot] == e.Id,
		})
	end
	return { itens = itens, coins = data.Coins }
end

local ultimoUso = {}
acao.OnServerInvoke = function(player, tipo, itemId)
	local agora = os.clock()
	if ultimoUso[player] and agora - ultimoUso[player] < 0.3 then
		return { ok = false, reason = "Slow down!" }
	end
	ultimoUso[player] = agora
	if tipo == "listar" then
		local e = estado(player)
		return e and { ok = true, estado = e } or { ok = false, reason = "Your data is still loading." }
	elseif tipo == "comprar" then
		local preco = type(itemId) == "string" and PRECO[itemId]
		local data = PlayerData.Get(player)
		if not preco or not data then
			return { ok = false, reason = "Can't buy this." }
		end
		if (data.Items[itemId] or 0) > 0 then
			return { ok = false, reason = "You already have it!" }
		end
		if not PlayerData.SpendCoins(player, preco) then
			return { ok = false, reason = "Not enough coins." }
		end
		PlayerData.AddItem(player, itemId, 1)
		return { ok = true, estado = estado(player) }
	end
	return { ok = false }
end

Players.PlayerRemoving:Connect(function(player)
	ultimoUso[player] = nil
end)

-- prompt e nome em cima da cabeça do Konohamaru
local function preparar(modelo)
	local root = modelo:FindFirstChild("HumanoidRootPart") or modelo.PrimaryPart or modelo:FindFirstChildWhichIsA("BasePart", true)
	if not root or root:FindFirstChild("LojaPrompt") then return end
	local p = Instance.new("ProximityPrompt")
	p.Name = "LojaPrompt"
	p.ActionText = "Talk"
	p.ObjectText = "Konohamaru"
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = root
	p.Triggered:Connect(function(player)
		abrir:FireClient(player, FALAS[math.random(1, #FALAS)])
	end)
	local head = modelo:FindFirstChild("Head") or root
	local b = Instance.new("BillboardGui")
	b.Name = "NomeNPC"
	b.Size = UDim2.fromOffset(170, 40)
	b.StudsOffset = Vector3.new(0, 2.3, 0)
	b.MaxDistance = 80
	b.LightInfluence = 0
	b.Parent = head
	local n = Instance.new("TextLabel")
	n.Size = UDim2.new(1, 0, 0, 22)
	n.BackgroundTransparency = 1
	n.Text = "Konohamaru"
	n.TextSize = 18
	n.Font = Enum.Font.GothamBlack
	n.TextColor3 = Color3.new(1, 1, 1)
	n.TextStrokeTransparency = 0.3
	n.Parent = b
	local t = Instance.new("TextLabel")
	t.Position = UDim2.fromOffset(0, 20)
	t.Size = UDim2.new(1, 0, 0, 16)
	t.BackgroundTransparency = 1
	t.Text = "Gear Shop"
	t.TextSize = 12
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = Color3.fromRGB(255, 205, 120)
	t.TextStrokeTransparency = 0.4
	t.Parent = b
	local hum = modelo:FindFirstChildOfClass("Humanoid")
	if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
end

task.spawn(function()
	local k = workspace:WaitForChild("Konohamaru", 30)
	if k then preparar(k) end
end)

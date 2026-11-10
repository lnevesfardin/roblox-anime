-- Script: ServerScriptService > EquipServer
-- Coleção e troca de personagem. Quando o jogador equipa um personagem:
--  * a vida/dano de combate passam a ser os dele (PlayerData.GetCombatStats)
--  * o corpo ganha um contorno da cor da raridade e o nome do personagem em cima da cabeça
-- (os modelos 3D dos personagens ficam para depois)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CharacterData = require(ReplicatedStorage:WaitForChild("CharacterData"))
local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))

local RARITY_COLORS = {
	Comum = Color3.fromRGB(200, 200, 200),
	Raro = Color3.fromRGB(80, 160, 255),
	Epico = Color3.fromRGB(180, 90, 255),
	Lendario = Color3.fromRGB(255, 190, 40),
	Mistico = Color3.fromRGB(255, 70, 120),
}

local getCollection = Instance.new("RemoteFunction")
getCollection.Name = "GetCollection"
getCollection.Parent = ReplicatedStorage

local equipFunction = Instance.new("RemoteFunction")
equipFunction.Name = "EquipCharacter"
equipFunction.Parent = ReplicatedStorage

local function clearLook(char)
	for _, name in ipairs({ "FormaMarca" }) do
		local old = char:FindFirstChild(name)
		if old then old:Destroy() end
	end
	local head = char:FindFirstChild("Head")
	local oldTag = head and head:FindFirstChild("FormaNome")
	if oldTag then oldTag:Destroy() end
end

-- Aplica contorno + nome e (fora de partida) a vida do personagem equipado
local function applyLook(player)
	local char = player.Character
	if not char then return end
	local hum = char:WaitForChild("Humanoid", 5)
	local head = char:WaitForChild("Head", 5)
	if not hum or not head then return end

	-- espera os dados carregarem (até ~10s)
	for _ = 1, 40 do
		if PlayerData.Get(player) then break end
		task.wait(0.25)
	end
	local data = PlayerData.Get(player)
	if not data then return end

	clearLook(char)
	local c = data.Equipped and CharacterData.GetCharacter(data.Equipped)
	if not c then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		return
	end

	local color = RARITY_COLORS[c.Rarity] or Color3.new(1, 1, 1)

	local hl = Instance.new("Highlight")
	hl.Name = "FormaMarca"
	hl.FillTransparency = 1
	hl.OutlineColor = color
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = char

	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local tag = Instance.new("BillboardGui")
	tag.Name = "FormaNome"
	tag.Size = UDim2.fromOffset(180, 34)
	tag.StudsOffset = Vector3.new(0, 2.6, 0)
	tag.MaxDistance = 90
	tag.Adornee = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 20
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Text = c.Name
	label.Parent = tag
	tag.Parent = head

	if not player:GetAttribute("InRun") then
		local stats = PlayerData.GetCombatStats(player)
		hum.MaxHealth = stats.Health
		hum.Health = stats.Health
	end
end

local function setupPlayer(player)
	player.CharacterAdded:Connect(function()
		applyLook(player)
	end)
	player:GetAttributeChangedSignal("Equipped"):Connect(function()
		task.spawn(applyLook, player)
	end)
	if player.Character then
		task.spawn(applyLook, player)
	end
end

Players.PlayerAdded:Connect(setupPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	setupPlayer(p)
end

getCollection.OnServerInvoke = function(player)
	local data = PlayerData.Get(player)
	if not data then
		return { ok = false, reason = "Your data is still loading." }
	end
	local list = {}
	for _, c in ipairs(CharacterData.Characters) do
		local owned = data.Owned[c.Id] or 0
		local s = CharacterData.GetStats(c.Id, data.Level)
		table.insert(list, {
			id = c.Id,
			name = c.Name,
			rarity = c.Rarity,
			theme = c.Theme,
			ability = c.Ability,
			copies = owned,
			health = s and s.Health or c.Health,
			damage = s and s.Damage or c.Damage,
		})
	end
	table.sort(list, function(a, b)
		local ra, rb = CharacterData.GetRarityIndex(a.rarity), CharacterData.GetRarityIndex(b.rarity)
		if ra ~= rb then return ra > rb end
		return a.name < b.name
	end)
	return { ok = true, equipped = data.Equipped, level = data.Level, list = list }
end

equipFunction.OnServerInvoke = function(player, characterId)
	if player:GetAttribute("InRun") then
		return { ok = false, reason = "You can't switch characters during a run." }
	end
	if not PlayerData.Equip(player, characterId) then
		return { ok = false, reason = "You don't own this character." }
	end
	return { ok = true, equipped = characterId }
end

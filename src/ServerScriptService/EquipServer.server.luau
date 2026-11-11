-- Script: ServerScriptService > EquipServer
-- Coleção e troca de personagem. Quando o jogador equipa um personagem:
--  * a vida/dano de combate passam a ser os dele (PlayerData.GetCombatStats)
--  * o corpo ganha um contorno da cor da raridade e o nome do personagem em cima da cabeça
-- (os modelos 3D dos personagens ficam para depois)
-- Também cuida de: converter repetidos em moedas, inventário de itens, usar boosts
-- e mostrar os acessórios equipados (bandana, cachecol, aura, rastro).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CharacterData = require(ReplicatedStorage:WaitForChild("CharacterData"))
local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))
local EconomyData = require(ReplicatedStorage:WaitForChild("EconomyData"))

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

local function remote(name)
	local f = Instance.new("RemoteFunction")
	f.Name = name
	f.Parent = ReplicatedStorage
	return f
end
local deleteDupes = remote("DeleteDuplicates")
local getInventory = remote("GetInventory")
local useItem = remote("UseItem")
local equipCosmetic = remote("EquipCosmetic")

---------------------------------------------------------------
-- Acessórios (feitos por código, sem modelos de terceiros)
---------------------------------------------------------------
local function weldTo(part, base, offset)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = base.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = base
	w.Part1 = part
	w.Parent = part
end

local function clearCosmetics(char)
	for _, d in ipairs(char:GetDescendants()) do
		if d:GetAttribute("Cosmetico") then
			d:Destroy()
		end
	end
end

local function buildCosmetic(char, itemId)
	local item = EconomyData.Items[itemId]
	if not item or item.Type ~= "Cosmetic" then return end
	local head = char:FindFirstChild("Head")
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not (head and torso and root) then return end
	local function part(name, size, color, mat)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p:SetAttribute("Cosmetico", true)
		return p
	end
	if item.Slot == "Cabeca" then
		local hs = head.Size
		local faixa = part("Bandana", Vector3.new(0.32, hs.X * 1.08, hs.Z * 1.08), item.Color, Enum.Material.Fabric)
		faixa.Shape = Enum.PartType.Cylinder
		weldTo(faixa, head, CFrame.new(0, hs.Y * 0.22, 0) * CFrame.Angles(0, 0, math.rad(90)))
		faixa.Parent = char
		local placa = part("Placa", Vector3.new(hs.X * 0.5, 0.26, 0.06), Color3.fromRGB(190, 195, 205), Enum.Material.Metal)
		weldTo(placa, head, CFrame.new(0, hs.Y * 0.22, -hs.Z * 0.55))
		placa.Parent = char
		for _, sx in ipairs({ -1, 1 }) do
			local ponta = part("Ponta", Vector3.new(0.12, 0.22, 0.9), item.Color, Enum.Material.Fabric)
			weldTo(ponta, head, CFrame.new(sx * 0.12, hs.Y * 0.12, hs.Z * 0.75) * CFrame.Angles(math.rad(-35), 0, math.rad(sx * 8)))
			ponta.Parent = char
		end
	elseif item.Slot == "Pescoco" then
		local ts = torso.Size
		local anel = part("Cachecol", Vector3.new(0.5, ts.X * 0.62, ts.Z * 1.2), item.Color, Enum.Material.Fabric)
		anel.Shape = Enum.PartType.Cylinder
		weldTo(anel, torso, CFrame.new(0, ts.Y * 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)))
		anel.Parent = char
		for i, sx in ipairs({ -0.25, 0.25 }) do
			local cauda = part("Cauda", Vector3.new(0.45, 1.6 + i * 0.25, 0.12), item.Color, Enum.Material.Fabric)
			weldTo(cauda, torso, CFrame.new(sx, ts.Y * 0.05, ts.Z * 0.62) * CFrame.Angles(math.rad(14), 0, 0))
			cauda.Parent = char
		end
	elseif item.Slot == "Aura" then
		local att = Instance.new("Attachment")
		att.Name = "AuraAtt"
		att.Position = Vector3.new(0, -1.5, 0)
		att:SetAttribute("Cosmetico", true)
		att.Parent = root
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(item.Color, Color3.new(1, 1, 1))
		pe.LightEmission = 1
		pe.Rate = 28
		pe.Lifetime = NumberRange.new(0.8, 1.3)
		pe.Speed = NumberRange.new(2, 4)
		pe.SpreadAngle = Vector2.new(25, 25)
		pe.EmissionDirection = Enum.NormalId.Top
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		pe.Shape = Enum.ParticleEmitterShape.Cylinder
		pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		pe.Parent = att
		local luz = Instance.new("PointLight")
		luz.Color = item.Color
		luz.Range = 10
		luz.Brightness = 1.5
		luz.Parent = att
	elseif item.Slot == "Rastro" then
		local a0 = Instance.new("Attachment")
		a0.Name = "RastroA"
		a0.Position = Vector3.new(0, 0.8, 0)
		a0:SetAttribute("Cosmetico", true)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Name = "RastroB"
		a1.Position = Vector3.new(0, -1, 0)
		a1:SetAttribute("Cosmetico", true)
		a1.Parent = root
		local tr = Instance.new("Trail")
		tr.Attachment0 = a0
		tr.Attachment1 = a1
		tr.Color = ColorSequence.new(item.Color, Color3.fromRGB(200, 30, 20))
		tr.LightEmission = 1
		tr.Lifetime = 0.45
		tr.Transparency = NumberSequence.new(0.1, 1)
		tr.Parent = a0
	end
end

local function applyCosmetics(player)
	local char = player.Character
	local data = PlayerData.Get(player)
	if not char or not data then return end
	clearCosmetics(char)
	for _, itemId in pairs(data.Cosmetics) do
		pcall(buildCosmetic, char, itemId)
	end
end

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
	applyCosmetics(player)
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
	local kinds, copiesTotal = 0, 0
	for _, c in ipairs(CharacterData.Characters) do
		local owned = data.Owned[c.Id] or 0
		if owned > 0 then kinds += 1 end
		copiesTotal += owned
		local s = CharacterData.GetStats(c.Id, data.Level)
		table.insert(list, {
			id = c.Id,
			name = c.Name,
			rarity = c.Rarity,
			theme = c.Theme,
			ability = c.Ability,
			copies = owned,
			dupeCoins = EconomyData.DupeCoins[c.Rarity] or 0,
			health = s and s.Health or c.Health,
			damage = s and s.Damage or c.Damage,
		})
	end
	table.sort(list, function(a, b)
		local ra, rb = CharacterData.GetRarityIndex(a.rarity), CharacterData.GetRarityIndex(b.rarity)
		if ra ~= rb then return ra > rb end
		return a.name < b.name
	end)
	return { ok = true, equipped = data.Equipped, level = data.Level, list = list,
		kinds = kinds, total = #CharacterData.Characters, copiesTotal = copiesTotal }
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

-- Exclui cópias repetidas (nunca a última) e dá moedas por cada uma
deleteDupes.OnServerInvoke = function(player, characterId, amount)
	local data = PlayerData.Get(player)
	local c = type(characterId) == "string" and CharacterData.GetCharacter(characterId)
	if not data or not c then
		return { ok = false, reason = "Invalid character." }
	end
	local have = data.Owned[characterId] or 0
	local maxDel = have - 1
	if type(amount) ~= "number" or amount ~= amount then
		amount = maxDel
	end
	amount = math.clamp(math.floor(amount), 0, maxDel)
	if amount <= 0 then
		return { ok = false, reason = "You need at least 2 copies to convert." }
	end
	data.Owned[characterId] = have - amount
	local coins = amount * (EconomyData.DupeCoins[c.Rarity] or 0)
	PlayerData.AddCoins(player, coins)
	player:SetAttribute("OwnedRev", (player:GetAttribute("OwnedRev") or 0) + 1)
	return { ok = true, removed = amount, coins = coins, copies = data.Owned[characterId] }
end

getInventory.OnServerInvoke = function(player)
	local data = PlayerData.Get(player)
	if not data then
		return { ok = false, reason = "Your data is still loading." }
	end
	local items = {}
	for id, n in pairs(data.Items) do
		local it = EconomyData.Items[id]
		if it and n > 0 then
			table.insert(items, { id = id, name = it.Name, type = it.Type, slot = it.Slot, count = n })
		end
	end
	table.sort(items, function(a, b) return a.name < b.name end)
	return {
		ok = true,
		items = items,
		cosmetics = table.clone(data.Cosmetics),
		boosts = { XP = data.Boosts.XP or 0, Coins = data.Boosts.Coins or 0 },
		now = os.time(),
	}
end

useItem.OnServerInvoke = function(player, itemId)
	if type(itemId) ~= "string" or not PlayerData.UseBoost(player, itemId) then
		return { ok = false, reason = "Can't use this item." }
	end
	return { ok = true }
end

-- itemId = acessório para equipar; ou nil + slot para tirar o daquele slot
equipCosmetic.OnServerInvoke = function(player, itemId, slot)
	local data = PlayerData.Get(player)
	if not data then
		return { ok = false, reason = "Your data is still loading." }
	end
	if itemId == nil then
		if type(slot) ~= "string" then
			return { ok = false, reason = "Invalid slot." }
		end
		data.Cosmetics[slot] = nil
	else
		local item = type(itemId) == "string" and EconomyData.Items[itemId]
		if not item or item.Type ~= "Cosmetic" or (data.Items[itemId] or 0) < 1 then
			return { ok = false, reason = "You don't own this item." }
		end
		data.Cosmetics[item.Slot] = itemId
	end
	PlayerData.Refresh(player)
	task.spawn(applyCosmetics, player)
	return { ok = true, cosmetics = table.clone(data.Cosmetics) }
end

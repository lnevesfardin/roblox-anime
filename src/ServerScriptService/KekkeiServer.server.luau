-- Script: ServerScriptService > KekkeiServer
-- Kekkei Genkai: um único giro por jogador, para sempre (data.Kekkei = { Rolou = true, Id = id ou false }).
-- KekkeiAcao (RemoteFunction): "estado" | "girar"
-- Atributos do jogador: "Kekkei" (id ou ""), "KekkeiRolou" (bool), "BonusVelKekkei" (Tempestade)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local KekkeiData = require(ReplicatedStorage:WaitForChild("KekkeiData"))
local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))

local acao = Instance.new("RemoteFunction")
acao.Name = "KekkeiAcao"
acao.Parent = ReplicatedStorage

local rng = Random.new()

local function dados(player)
	local data = PlayerData.Get(player)
	if not data then return nil end
	if type(data.Kekkei) ~= "table" then
		data.Kekkei = { Rolou = false, Id = false }
	end
	return data
end

local function aplicar(player)
	local data = dados(player)
	if not data then return end
	local id = KekkeiData.DoSave(data)
	player:SetAttribute("Kekkei", id or "")
	player:SetAttribute("KekkeiRolou", data.Kekkei.Rolou == true)
	player:SetAttribute("BonusVelKekkei", id == "Tempestade" and 2 or 0)
	-- vida e dano mudam com alguns passivos (PlayerData.GetCombatStats)
	if id and not player:GetAttribute("InRun") then
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			local vida = PlayerData.GetCombatStats(player).Health
			if hum.MaxHealth ~= vida then
				hum.MaxHealth = vida
				hum.Health = vida
			end
		end
	end
	local atualizar = ServerStorage:FindFirstChild("AtualizarPoderes")
	if atualizar then atualizar:Fire(player) end
end

local ocupado = {}
acao.OnServerInvoke = function(player, pedido)
	local data = dados(player)
	if not data then return { ok = false, erro = "Loading..." } end
	if pedido == "girar" then
		if data.Kekkei.Rolou then
			return { ok = false, erro = "You already used your only chance.", Id = KekkeiData.DoSave(data) or false, Rolou = true }
		end
		if ocupado[player] then return { ok = false, erro = "Wait..." } end
		ocupado[player] = true
		local id = KekkeiData.Roll(rng)
		data.Kekkei.Rolou = true
		data.Kekkei.Id = id
		ocupado[player] = nil
		-- salva logo: é um giro único e não pode ser perdido
		task.spawn(function() pcall(PlayerData.Save, player) end)
		aplicar(player)
		return { ok = true, Id = id, Rolou = true }
	end
	return { ok = true, Id = KekkeiData.DoSave(data) or false, Rolou = data.Kekkei.Rolou == true }
end

local function setup(player)
	for _ = 1, 60 do
		if PlayerData.Get(player) then break end
		task.wait(0.25)
	end
	if not player.Parent then return end
	aplicar(player)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		aplicar(player)
	end)
end
Players.PlayerAdded:Connect(setup)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(setup, p) end
Players.PlayerRemoving:Connect(function(p) ocupado[p] = nil end)

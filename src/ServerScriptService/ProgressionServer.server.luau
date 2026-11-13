-- Script: ServerScriptService > ProgressionServer
-- Liga o sistema de dados e cria os "avisos" que outros scripts usam para dar recompensa.

local ServerStorage = game:GetService("ServerStorage")
local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))

PlayerData.Init()

local function makeEvent(name)
	local e = ServerStorage:FindFirstChild(name)
	if not e then
		e = Instance.new("BindableEvent")
		e.Name = name
		e.Parent = ServerStorage
	end
	return e
end

-- Como dar recompensa a partir de outro script do servidor:
--   ServerStorage.AddXP:Fire(jogador, 100)
--   ServerStorage.AddCoins:Fire(jogador, 50)
makeEvent("AddXP").Event:Connect(PlayerData.AddXP)
makeEvent("AddCoins").Event:Connect(PlayerData.AddCoins)

---------------------------------------------------------------
-- Configurações do jogador (som, câmera, gráficos), salvas no mesmo PlayerData
---------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local getSettings = Instance.new("RemoteFunction")
getSettings.Name = "GetSettings"
getSettings.Parent = ReplicatedStorage

local saveSettings = Instance.new("RemoteEvent")
saveSettings.Name = "SaveSettings"
saveSettings.Parent = ReplicatedStorage

-- limites de cada número (o cliente nunca grava valor fora disso)
local LIMITS = {
	Music = { 0, 1 },
	SFX = { 0, 1 },
	Sensitivity = { 0.2, 2 },
	FOV = { 60, 90 },
}

getSettings.OnServerInvoke = function(player)
	for _ = 1, 40 do
		if PlayerData.Get(player) then break end
		task.wait(0.25)
	end
	local data = PlayerData.Get(player)
	return table.clone(data and data.Settings or PlayerData.DEFAULT_SETTINGS)
end

local lastSave = {}
saveSettings.OnServerEvent:Connect(function(player, new)
	local data = PlayerData.Get(player)
	if not data or type(new) ~= "table" then
		return
	end
	if lastSave[player] and os.clock() - lastSave[player] < 0.3 then
		return
	end
	lastSave[player] = os.clock()
	for key, default in pairs(PlayerData.DEFAULT_SETTINGS) do
		local v = new[key]
		if type(v) == type(default) then
			if type(v) == "number" then
				if v == v then -- ignora NaN
					local lim = LIMITS[key]
					data.Settings[key] = lim and math.clamp(v, lim[1], lim[2]) or v
				end
			else
				data.Settings[key] = v
			end
		end
	end
end)

local podeResetar = Instance.new("RemoteFunction")
podeResetar.Name = "PodeResetar"
podeResetar.Parent = ReplicatedStorage
podeResetar.OnServerInvoke = function(player)
	return PlayerData.PodeResetar(player)
end

local resetarProgresso = Instance.new("RemoteFunction")
resetarProgresso.Name = "ResetarProgresso"
resetarProgresso.Parent = ReplicatedStorage
local resetando = {}
resetarProgresso.OnServerInvoke = function(player)
	if resetando[player] then return false, "Already resetting." end
	resetando[player] = true
	local ok, motivo = PlayerData.Resetar(player)
	if not ok then resetando[player] = nil end
	return ok, motivo
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastSave[player] = nil
end)

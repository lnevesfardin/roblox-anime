-- Script: ServerScriptService > TutorialServer
-- Tutorial da primeira entrada. Guarda so se o jogador ja viu (data.Tutorial = true).
-- Atributo do jogador "TutorialPendente" (true ate terminar ou pular): o cliente (TutorialClient) comeca o tour quando ele
-- chega ao mundo, e o ExtrasClient espera o fim para abrir o bonus de login.
-- RemoteEvent TutorialAcao: o cliente manda "fim" ao terminar ou pular.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))

local evento = Instance.new("RemoteEvent")
evento.Name = "TutorialAcao"
evento.Parent = ReplicatedStorage

local function preparar(plr)
	local data
	for _ = 1, 100 do
		data = PlayerData.Get(plr)
		if data or not plr.Parent then break end
		task.wait(0.1)
	end
	if not data or not plr.Parent then return end
	plr:SetAttribute("TutorialPendente", data.Tutorial ~= true)
end

Players.PlayerAdded:Connect(function(plr) task.spawn(preparar, plr) end)
for _, plr in ipairs(Players:GetPlayers()) do task.spawn(preparar, plr) end

evento.OnServerEvent:Connect(function(plr, acao)
	if acao ~= "fim" then return end
	local data = PlayerData.Get(plr)
	if not data then return end
	if data.Tutorial ~= true then
		data.Tutorial = true
		task.spawn(PlayerData.Save, plr)
	end
	plr:SetAttribute("TutorialPendente", false)
end)

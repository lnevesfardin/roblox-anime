-- LocalScript: StarterPlayerScripts > EfeitosClient
-- Tremor de tela dos jutsus fortes. O servidor manda ReplicatedStorage.TremerTela (posição, força)
-- e quem está perto sente o tremor (mais fraco com a distância). Usa o CameraOffset do Humanoid,
-- somado ao deslocamento da trava da câmera (atributo do jogador "OffsetCamera", do TravaCamera).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local ev = ReplicatedStorage:WaitForChild("TremerTela")

local ALCANCE = 90
local intensidade = 0

ev.OnClientEvent:Connect(function(pos, forca)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or typeof(pos) ~= "Vector3" then return end
	local d = (root.Position - pos).Magnitude
	if d > ALCANCE then return end
	local f = (tonumber(forca) or 0.5) * (1 - d / ALCANCE)
	intensidade = math.min(math.max(intensidade, f), 1.6)
end)

RunService.RenderStepped:Connect(function(dt)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local base = player:GetAttribute("OffsetCamera")
	if typeof(base) ~= "Vector3" then base = Vector3.zero end
	if intensidade > 0.01 then
		local a = intensidade * 0.6
		hum.CameraOffset = base + Vector3.new((math.random() * 2 - 1) * a, (math.random() * 2 - 1) * a, (math.random() * 2 - 1) * a * 0.5)
		intensidade = math.max(0, intensidade - dt * 2.2)
	elseif intensidade ~= 0 then
		intensidade = 0
		hum.CameraOffset = base
	end
end)

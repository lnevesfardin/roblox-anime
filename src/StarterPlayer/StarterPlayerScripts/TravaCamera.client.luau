-- LocalScript: StarterPlayerScripts > TravaCamera
-- Trava da câmera (Shift Lock) no Alt, feita pelo próprio jogo: funciona para todos, sem precisar
-- ligar "Shift Lock Switch" nas configurações do Roblox. O Shift fica só para a corrida (script Corrida).
-- Ligada: mouse preso no centro, o personagem vira para onde a câmera olha e a câmera fica de lado.
-- A trava original do Roblox (InputContexts > CameraContext > MouseLockSwitchAction) perde as teclas Shift.
-- O deslocamento da câmera fica no atributo do jogador "OffsetCamera" (o EfeitosClient soma o tremor nele).

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local OFFSET = Vector3.new(1.75, 0.2, 0)

local player = Players.LocalPlayer
local ligada = false

-- tira o Shift da trava original do Roblox (sistema novo de InputAction ou o antigo BoundKeys)
task.spawn(function()
	local ps = player:WaitForChild("PlayerScripts")
	local pm
	for _ = 1, 60 do
		pm = ps:FindFirstChild("PlayerModule") or StarterPlayer:FindFirstChild("PlayerModule")
		if pm then break end
		task.wait(0.5)
	end
	if not pm then return end
	local ctx = pm:WaitForChild("InputContexts", 10)
	local cam = ctx and ctx:WaitForChild("CameraContext", 10)
	local acao = cam and cam:WaitForChild("MouseLockSwitchAction", 10)
	if acao then
		for _, b in ipairs(acao:GetChildren()) do
			if b:IsA("InputBinding") and (b.KeyCode == Enum.KeyCode.LeftShift or b.KeyCode == Enum.KeyCode.RightShift) then
				b.KeyCode = Enum.KeyCode.Unknown
			end
		end
	end
	local cm = pm:FindFirstChild("CameraModule")
	local mlc = cm and cm:FindFirstChild("MouseLockController")
	local bk = mlc and mlc:FindFirstChild("BoundKeys")
	if bk and bk:IsA("StringValue") then bk.Value = "" end
end)

local function aplicar()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	player:SetAttribute("OffsetCamera", ligada and OFFSET or Vector3.zero)
	if hum then
		hum.AutoRotate = not ligada
		hum.CameraOffset = ligada and OFFSET or Vector3.zero
	end
	if not ligada then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

local function alternar(_, estado)
	if estado ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	-- não liga durante telas que precisam do mouse livre (título, roleta, conversa)
	if player:GetAttribute("Jogando") ~= true then return Enum.ContextActionResult.Pass end
	ligada = not ligada
	aplicar()
	return Enum.ContextActionResult.Sink
end
ContextActionService:BindAction("TravaCamera", alternar, false, Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt)

RunService:BindToRenderStep("TravaCamera", Enum.RenderPriority.Camera.Value + 1, function()
	if not ligada then return end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	if hum and root and hum.Health > 0 and not root.Anchored then
		local look = workspace.CurrentCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + look.Unit)
		end
	end
end)

player.CharacterAdded:Connect(function(char)
	char:WaitForChild("Humanoid", 10)
	aplicar()
end)

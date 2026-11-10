-- LocalScript: StarterPlayerScripts > Corrida
-- PC: segure Shift para correr. Celular: botão "Run" liga/desliga. Controle: aperte o analógico esquerdo (L3).

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local WALK_SPEED = 16
local RUN_SPEED = 26
local FOV_NORMAL = 70
local FOV_RUN = 78

local player = Players.LocalPlayer
local correndo = false

local function humanoid()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function aplicar()
	local hum = humanoid()
	if hum then
		hum.WalkSpeed = correndo and RUN_SPEED or WALK_SPEED
	end
	player:SetAttribute("Correndo", correndo)
	local cam = workspace.CurrentCamera
	if cam then
		TweenService:Create(cam, TweenInfo.new(0.25), { FieldOfView = correndo and FOV_RUN or FOV_NORMAL }):Play()
	end
	local botao = ContextActionService:GetButton("Correr")
	if botao then
		ContextActionService:SetTitle("Correr", correndo and "Walk" or "Run")
	end
end

local function acao(_, estado, input)
	if input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonL3 then
		-- toque/controle: alterna
		if estado == Enum.UserInputState.Begin then
			correndo = not correndo
			aplicar()
		end
	else
		-- teclado: correr enquanto segura
		if estado == Enum.UserInputState.Begin then
			correndo = true
		elseif estado == Enum.UserInputState.End or estado == Enum.UserInputState.Cancel then
			correndo = false
		end
		aplicar()
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction("Correr", acao, true, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle("Correr", "Run")
ContextActionService:SetPosition("Correr", UDim2.new(1, -150, 1, -150))

-- ao renascer (ex.: depois de uma partida) volta a andar normal
player.CharacterAdded:Connect(function(char)
	correndo = false
	char:WaitForChild("Humanoid")
	aplicar()
end)

-- ModuleScript: ReplicatedStorage > FocoNPC  (só no cliente)
-- Conversa estilo jogo de história: vira o personagem para o NPC e aproxima a câmera por cima do ombro.
-- FocoNPC.Focar(modelo) ao abrir a conversa, FocoNPC.Soltar() ao fechar.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local FocoNPC = {}
local ativo = false
local tween

function FocoNPC.Focar(modelo)
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not modelo or not modelo.Parent then return end
	local cabeca = modelo:FindFirstChild("Head")
	local alvo = cabeca and cabeca.Position or (modelo:GetPivot().Position + Vector3.new(0, 1.5, 0))
	local chao = Vector3.new(alvo.X, root.Position.Y, alvo.Z)
	local dir = chao - root.Position
	if dir.Magnitude < 0.5 then return end
	dir = dir.Unit
	root.CFrame = CFrame.lookAt(root.Position, chao)
	local lado = dir:Cross(Vector3.yAxis)
	local pos = root.Position - dir * 6 + lado * 3.5 + Vector3.new(0, 3, 0)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	if tween then tween:Cancel() end
	tween = TweenService:Create(cam, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.lookAt(pos, alvo - Vector3.new(0, 2.8, 0)) })
	tween:Play()
	ativo = true
end

function FocoNPC.Soltar()
	if not ativo then return end
	ativo = false
	if tween then tween:Cancel() end
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end

return FocoNPC

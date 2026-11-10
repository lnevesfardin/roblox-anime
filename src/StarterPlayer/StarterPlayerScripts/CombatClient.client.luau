-- LocalScript: StarterPlayerScripts > CombatClient
-- Clique (ou toque, ou tecla F) = atacar. Também mostra o aviso das ondas e a barra do boss.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local attackEvent = ReplicatedStorage:WaitForChild("Attack")
local statusEvent = ReplicatedStorage:WaitForChild("RunStatus")

local gui = Instance.new("ScreenGui")
gui.Name = "HudOnda"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local texto = Instance.new("TextLabel")
texto.Size = UDim2.fromOffset(700, 40)
texto.Position = UDim2.new(0.5, -350, 0, 14)
texto.BackgroundTransparency = 1
texto.Font = Enum.Font.GothamBlack
texto.TextSize = 26
texto.TextColor3 = Color3.new(1, 1, 1)
texto.TextStrokeTransparency = 0.3
texto.Text = ""
texto.Parent = gui

local bossFrame = Instance.new("Frame")
bossFrame.Size = UDim2.fromOffset(420, 24)
bossFrame.Position = UDim2.new(0.5, -210, 0, 62)
bossFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
bossFrame.Visible = false
bossFrame.Parent = gui
Instance.new("UICorner", bossFrame).CornerRadius = UDim.new(0, 6)

local bossBar = Instance.new("Frame")
bossBar.Size = UDim2.new(1, 0, 1, 0)
bossBar.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
bossBar.BorderSizePixel = 0
bossBar.Parent = bossFrame
Instance.new("UICorner", bossBar).CornerRadius = UDim.new(0, 6)

local bossLabel = Instance.new("TextLabel")
bossLabel.Size = UDim2.new(1, 0, 1, 0)
bossLabel.BackgroundTransparency = 1
bossLabel.Font = Enum.Font.GothamBold
bossLabel.TextSize = 14
bossLabel.TextColor3 = Color3.new(1, 1, 1)
bossLabel.Parent = bossFrame

statusEvent.OnClientEvent:Connect(function(p)
	if p.clear then
		texto.Text = ""
		bossFrame.Visible = false
		return
	end
	texto.Text = p.text or ""
	if p.boss then
		bossFrame.Visible = true
		bossBar.Size = UDim2.new(math.clamp(p.boss.hp / p.boss.max, 0, 1), 0, 1, 0)
		bossLabel.Text = ("%s   %d / %d"):format(p.boss.name, math.ceil(p.boss.hp), p.boss.max)
	else
		bossFrame.Visible = false
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.F then
		attackEvent:FireServer()
	end
end)

-- Script: ServerScriptService > DiaNoite
-- Ciclo de dia e noite. O dia (6h às 18h) dura DIA_MIN minutos e a noite (18h às 6h) dura NOITE_MIN.
-- À noite a luz ambiente fica azulada e um pouco mais clara que o padrão, para dar para jogar;
-- as janelas acesas das casas e as lanternas aparecem.
-- workspace:GetAttribute("Noite") fica true à noite (outros scripts podem usar).

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local DIA_MIN = 12
local NOITE_MIN = 6
local HORA_INICIAL = 9

-- cores do ambiente de dia (as do jogo) e de noite
local AMBIENTE_DIA = Lighting.OutdoorAmbient
local AMBIENTE_NOITE = Color3.fromRGB(70, 80, 115)
local BRILHO_DIA = Lighting.Brightness
local BRILHO_NOITE = math.max(0.6, BRILHO_DIA * 0.45)
-- de dia o sol é levemente dourado; à noite a luz da lua fica azulada
local SOL_DIA = Lighting.ColorShift_Top
local SOL_NOITE = Color3.fromRGB(40, 55, 95)
local COBERTO_DIA = Lighting.Ambient
local COBERTO_NOITE = Color3.fromRGB(60, 64, 88)
local atm = Lighting:FindFirstChildOfClass("Atmosphere")
local ATM_DIA = atm and atm.Color
local ATM_NOITE = Color3.fromRGB(70, 80, 115)
local cor = Lighting:FindFirstChild("CorCidade")
local TINTA_DIA = cor and cor.TintColor
local TINTA_NOITE = Color3.fromRGB(220, 228, 255)

local function ehDia(hora)
	return hora >= 6 and hora < 18
end

-- 0 = dia cheio, 1 = noite cheia (transição suave no amanhecer e no anoitecer)
local function fatorNoite(hora)
	if hora >= 7 and hora < 17 then return 0 end
	if hora >= 19 or hora < 5 then return 1 end
	if hora >= 17 and hora < 19 then return (hora - 17) / 2 end
	return 1 - (hora - 5) / 2 -- 5h às 7h amanhece
end

Lighting.ClockTime = HORA_INICIAL
local acumulado = 0
RunService.Heartbeat:Connect(function(dt)
	local hora = Lighting.ClockTime
	-- 12 horas do jogo passam em DIA_MIN (de dia) ou NOITE_MIN (de noite) minutos reais
	local velocidade = 12 / ((ehDia(hora) and DIA_MIN or NOITE_MIN) * 60)
	acumulado += dt * velocidade
	if acumulado < 0.01 then
		return -- atualiza aos pouquinhos para não mandar mudança todo frame
	end
	hora = (hora + acumulado) % 24
	acumulado = 0
	Lighting.ClockTime = hora
	local n = fatorNoite(hora)
	Lighting.OutdoorAmbient = AMBIENTE_DIA:Lerp(AMBIENTE_NOITE, n)
	Lighting.Brightness = BRILHO_DIA + (BRILHO_NOITE - BRILHO_DIA) * n
	Lighting.ColorShift_Top = SOL_DIA:Lerp(SOL_NOITE, n)
	Lighting.Ambient = COBERTO_DIA:Lerp(COBERTO_NOITE, n)
	if atm then atm.Color = ATM_DIA:Lerp(ATM_NOITE, n) end
	if cor then cor.TintColor = TINTA_DIA:Lerp(TINTA_NOITE, n) end
	local noite = n > 0.5
	if workspace:GetAttribute("Noite") ~= noite then
		workspace:SetAttribute("Noite", noite)
	end
end)

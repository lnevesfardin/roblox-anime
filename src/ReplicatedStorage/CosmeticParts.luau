-- ModuleScript: ReplicatedStorage > CosmeticParts
-- Formato dos acessórios (bandana e cachecol), usado pelo servidor (no personagem)
-- e pela loja do Konohamaru (miniatura do item).
-- Pecas(item, hs, ts) devolve a lista de peças: Base = "head" ou "torso", CF = posição relativa à base.

local C = {}
local METAL = Color3.fromRGB(200, 205, 215)
local ESCURO = Color3.fromRGB(45, 45, 52)

function C.Pecas(item, hs, ts)
	local L = {}
	local function add(base, name, size, cf, color, mat, shape, refl)
		table.insert(L, { Base = base, Name = name, Size = size, CF = cf, Color = color, Mat = mat, Shape = shape, Refl = refl })
	end
	local cor = item.Color
	local FAB, CIL, BOLA = Enum.Material.Fabric, Enum.PartType.Cylinder, Enum.PartType.Ball
	if item.Slot == "Cabeca" then
		local y = hs.Y * 0.26
		local deitado = CFrame.Angles(0, 0, math.rad(90))
		local frente = CFrame.Angles(0, math.rad(90), 0)
		add("head", "Bandana", Vector3.new(0.3, hs.X * 1.1, hs.Z * 1.1), CFrame.new(0, y, 0) * deitado, cor, FAB, CIL)
		for _, dy in ipairs({ -0.14, 0.14 }) do -- costura
			add("head", "Costura", Vector3.new(0.04, hs.X * 1.12, hs.Z * 1.12), CFrame.new(0, y + dy, 0) * deitado, cor:Lerp(Color3.new(0, 0, 0), 0.3), FAB, CIL)
		end
		-- placa de metal em 3 partes (acompanha a curva da testa)
		local zf = -hs.Z * 0.56
		add("head", "Placa", Vector3.new(hs.X * 0.42, 0.26, 0.07), CFrame.new(0, y, zf), METAL, Enum.Material.Metal, nil, 0.25)
		for _, sx in ipairs({ -1, 1 }) do
			add("head", "PlacaLado", Vector3.new(hs.X * 0.17, 0.26, 0.07), CFrame.new(sx * hs.X * 0.28, y, zf + 0.04) * CFrame.Angles(0, math.rad(-sx * 28), 0), METAL, Enum.Material.Metal, nil, 0.25)
			add("head", "Rebite", Vector3.new(0.06, 0.06, 0.06), CFrame.new(sx * hs.X * 0.17, y, zf - 0.04), ESCURO, Enum.Material.Metal, BOLA)
		end
		-- símbolo gravado (espiral simples)
		add("head", "Simbolo", Vector3.new(0.02, 0.16, 0.16), CFrame.new(0, y, zf - 0.035) * frente, ESCURO, Enum.Material.SmoothPlastic, CIL)
		add("head", "SimboloMeio", Vector3.new(0.025, 0.08, 0.08), CFrame.new(0, y, zf - 0.035) * frente, METAL, Enum.Material.Metal, CIL)
		add("head", "SimboloCorte", Vector3.new(0.05, 0.05, 0.03), CFrame.new(0.055, y + 0.055, zf - 0.04), METAL, Enum.Material.Metal)
		add("head", "SimboloPonto", Vector3.new(0.03, 0.035, 0.035), CFrame.new(0, y, zf - 0.04) * frente, ESCURO, Enum.Material.SmoothPlastic, CIL)
		-- nó e pontas atrás
		local zt = hs.Z * 0.58
		add("head", "No", Vector3.new(0.26, 0.26, 0.26), CFrame.new(0, y, zt), cor, FAB, BOLA)
		for _, sx in ipairs({ -1, 1 }) do
			add("head", "Ponta", Vector3.new(0.18, 0.05, 1.05), CFrame.new(sx * 0.11, y - 0.3, zt + 0.36) * CFrame.Angles(math.rad(-52), 0, math.rad(sx * 10)), cor, FAB)
		end
	elseif item.Slot == "Pescoco" then
		add("torso", "Cachecol", Vector3.new(0.5, ts.X * 0.62, ts.Z * 1.2), CFrame.new(0, ts.Y * 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), cor, FAB, CIL)
		for i, sx in ipairs({ -0.25, 0.25 }) do
			add("torso", "Cauda", Vector3.new(0.45, 1.6 + i * 0.25, 0.12), CFrame.new(sx, ts.Y * 0.05, ts.Z * 0.62) * CFrame.Angles(math.rad(14), 0, 0), cor, FAB)
		end
	end
	return L
end

function C.Criar(p)
	local part = Instance.new("Part")
	part.Name = p.Name
	part.Size = p.Size
	part.Color = p.Color
	part.Material = p.Mat or Enum.Material.SmoothPlastic
	if p.Shape then part.Shape = p.Shape end
	part.Reflectance = p.Refl or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.Massless = true
	return part
end

return C

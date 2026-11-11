-- ModuleScript: ReplicatedStorage > IconeGema
-- Desenha o ícone das Gemas do Rikudou por código (mesmo desenho de assets/gema_rikudou.svg).
-- Usado enquanto o PNG não é enviado ao Roblox. Quando EconomyData.Gems.IconId tiver uma ID,
-- o HUD usa a imagem enviada e este módulo nem roda.
-- IconeGema.Get() devolve um Content pronto para ImageLabel.ImageContent (ou nil se falhar).

local AssetService = game:GetService("AssetService")

local IconeGema = {}
local cache = nil
local tentou = false

local function render(N)
	local S = N / 512
	local R, G, B, A = table.create(N * N, 0), table.create(N * N, 0), table.create(N * N, 0), table.create(N * N, 0)
	local function hex(h)
		return tonumber(h:sub(2, 3), 16) / 255, tonumber(h:sub(4, 5), 16) / 255, tonumber(h:sub(6, 7), 16) / 255
	end
	local function blend(i, r, g, b, a)
		if a <= 0 then return end
		local da = A[i]
		local oa = a + da * (1 - a)
		if oa <= 0 then return end
		R[i] = (r * a + R[i] * da * (1 - a)) / oa
		G[i] = (g * a + G[i] * da * (1 - a)) / oa
		B[i] = (b * a + B[i] * da * (1 - a)) / oa
		A[i] = oa
	end
	local function inside(poly, x, y)
		local c = false
		local j = #poly
		for i = 1, #poly do
			local xi, yi, xj, yj = poly[i][1], poly[i][2], poly[j][1], poly[j][2]
			if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then
				c = not c
			end
			j = i
		end
		return c
	end
	local SUB = { { 0.25, 0.25 }, { 0.75, 0.25 }, { 0.25, 0.75 }, { 0.75, 0.75 } }
	local function fillPoly(poly512, colorFn)
		local poly = {}
		local minx, miny, maxx, maxy = 1e9, 1e9, -1e9, -1e9
		for _, p in ipairs(poly512) do
			local q = { p[1] * S, p[2] * S }
			table.insert(poly, q)
			minx, maxx = math.min(minx, q[1]), math.max(maxx, q[1])
			miny, maxy = math.min(miny, q[2]), math.max(maxy, q[2])
		end
		for y = math.max(0, math.floor(miny)), math.min(N - 1, math.ceil(maxy)) do
			for x = math.max(0, math.floor(minx)), math.min(N - 1, math.ceil(maxx)) do
				local cov = 0
				for _, s in ipairs(SUB) do
					if inside(poly, x + s[1], y + s[2]) then cov += 1 end
				end
				if cov > 0 then
					local r, g, b, a = colorFn(x + 0.5, y + 0.5, minx, miny, maxx, maxy)
					blend(y * N + x + 1, r, g, b, a * cov / 4)
				end
			end
		end
	end
	local function linGrad(c1, c2)
		local r1, g1, b1 = hex(c1)
		local r2, g2, b2 = hex(c2)
		return function(x, y, minx, miny, maxx, maxy)
			local t = math.clamp(((x - minx) / math.max(1, maxx - minx) + (y - miny) / math.max(1, maxy - miny)) / 2, 0, 1)
			return r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t, 1
		end
	end
	local function solid(c, a)
		local r, g, b = hex(c)
		return function() return r, g, b, a end
	end
	local function radial(cx, cy, rx, ry, fn)
		cx, cy, rx, ry = cx * S, cy * S, rx * S, ry * S
		for y = math.max(0, math.floor(cy - ry)), math.min(N - 1, math.ceil(cy + ry)) do
			for x = math.max(0, math.floor(cx - rx)), math.min(N - 1, math.ceil(cx + rx)) do
				local dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
				local d = math.sqrt(dx * dx + dy * dy)
				if d <= 1 then
					local r, g, b, a = fn(d)
					blend(y * N + x + 1, r, g, b, a)
				end
			end
		end
	end
	local function ring(cx, cy, rr, w, c, a, dashFn)
		local r1, g1, b1 = hex(c)
		cx, cy, rr, w = cx * S, cy * S, rr * S, math.max(1, w * S)
		for y = math.max(0, math.floor(cy - rr - w)), math.min(N - 1, math.ceil(cy + rr + w)) do
			for x = math.max(0, math.floor(cx - rr - w)), math.min(N - 1, math.ceil(cx + rr + w)) do
				local d = math.abs(math.sqrt((x + 0.5 - cx) ^ 2 + (y + 0.5 - cy) ^ 2) - rr)
				local cov = math.clamp(w / 2 + 0.5 - d, 0, 1)
				if cov > 0 and (not dashFn or dashFn(math.atan2(y + 0.5 - cy, x + 0.5 - cx))) then
					blend(y * N + x + 1, r1, g1, b1, a * cov)
				end
			end
		end
	end
	local function line(p, q, w, c, a)
		local r1, g1, b1 = hex(c)
		local ax, ay, bx, by = p[1] * S, p[2] * S, q[1] * S, q[2] * S
		w = math.max(0.8, w * S)
		local vx, vy = bx - ax, by - ay
		local L2 = vx * vx + vy * vy
		for y = math.max(0, math.floor(math.min(ay, by) - w)), math.min(N - 1, math.ceil(math.max(ay, by) + w)) do
			for x = math.max(0, math.floor(math.min(ax, bx) - w)), math.min(N - 1, math.ceil(math.max(ax, bx) + w)) do
				local px, py = x + 0.5 - ax, y + 0.5 - ay
				local t = math.clamp((px * vx + py * vy) / L2, 0, 1)
				local d = math.sqrt((px - vx * t) ^ 2 + (py - vy * t) ^ 2)
				local cov = math.clamp(w / 2 + 0.5 - d, 0, 1)
				if cov > 0 then blend(y * N + x + 1, r1, g1, b1, a * cov) end
			end
		end
	end

	local C = 256
	radial(C, C + 4, 250, 250, function(d)
		local stops = { { 0, "#ffcf5a", 0.95 }, { 0.35, "#ff8a2a", 0.55 }, { 0.65, "#8b3dff", 0.35 }, { 1, "#8b3dff", 0 } }
		for i = 1, #stops - 1 do
			local s1, s2 = stops[i], stops[i + 1]
			if d <= s2[1] then
				local t = (d - s1[1]) / (s2[1] - s1[1])
				local r1, g1, b1 = hex(s1[2])
				local r2, g2, b2 = hex(s2[2])
				return r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t, s1[3] + (s2[3] - s1[3]) * t
			end
		end
		return 0, 0, 0, 0
	end)
	ring(C, C + 4, 196, 9, "#ffd98a", 0.45)
	ring(C, C + 4, 196, 3, "#fff5d6", 1)
	ring(C, C + 4, 214, 2.5, "#b77bff", 0.9, function(ang) return (ang * 214 % 18) < 5 end)
	for i = 0, 11 do
		local a = math.rad(i * 30 + 15)
		local r1, r2, w = 150, 236, 0.07
		fillPoly({
			{ C + r1 * math.cos(a - w), C + 4 + r1 * math.sin(a - w) },
			{ C + r2 * math.cos(a), C + 4 + r2 * math.sin(a) },
			{ C + r1 * math.cos(a + w), C + 4 + r1 * math.sin(a + w) },
		}, solid("#ffe08a", 0.35))
	end
	local top, bot = { C, 52 }, { C, 468 }
	local L1, L2, R1, R2 = { 118, 196 }, { 118, 330 }, { 394, 196 }, { 394, 330 }
	local ML, MR, BL, BR = { 178, 170 }, { 334, 170 }, { 178, 356 }, { 334, 356 }
	local ct, cb = { C, 150 }, { C, 372 }
	local outline = { top, R1, R2, bot, L2, L1 }
	for k = 3, 1, -1 do
		local f = 1 + k * 0.035
		local big = {}
		for _, p in ipairs(outline) do
			table.insert(big, { C + (p[1] - C) * f, 260 + (p[2] - 260) * f })
		end
		fillPoly(big, solid("#ff9a1e", 0.28))
	end
	local facets = {
		{ { top, ML, ct }, "#fff6c8", "#ffd34d" }, { { top, ct, MR }, "#ffe27a", "#ffb42a" },
		{ { top, L1, ML }, "#ffd04a", "#f59a1b" }, { { top, MR, R1 }, "#ffbe3a", "#e7780f" },
		{ { L1, ML, ct, BL, L2 }, "#ffc23d", "#e2660d" }, { { R1, MR, ct, BR, R2 }, "#f08a16", "#b8410a" },
		{ { ct, BL, cb, BR }, "#fff3b0", "#ffa51f" },
		{ { L2, BL, bot }, "#d9580c", "#8f2a0a" }, { { R2, BR, bot }, "#b8400b", "#6d1c08" },
		{ { BL, cb, bot }, "#f07a14", "#a8340a" }, { { BR, cb, bot }, "#c94e0c", "#7a2008" },
	}
	for _, f in ipairs(facets) do
		fillPoly(f[1], linGrad(f[2], f[3]))
	end
	for _, f in ipairs(facets) do
		local p = f[1]
		for i = 1, #p do line(p[i], p[i % #p + 1], 2, "#fff1b8", 0.55) end
	end
	for i = 1, #outline do line(outline[i], outline[i % #outline + 1], 7, "#5a1606", 1) end
	for i = 1, #outline do line(outline[i], outline[i % #outline + 1], 2.5, "#ffe9a3", 1) end
	radial(C, C + 6, 62, 92, function(d)
		if d < 0.5 then
			local t = d / 0.5
			return 1, 1 - 0.05 * t, 1 - 0.34 * t, 0.95 - 0.45 * t
		end
		local t = (d - 0.5) / 0.5
		return 1, 0.95, 0.66, 0.5 * (1 - t)
	end)
	fillPoly({ { 150, 206 }, { 178, 180 }, { 206, 296 }, { 178, 330 } }, solid("#ffffff", 0.55))
	fillPoly({ { 214, 110 }, { 240, 84 }, { 246, 120 } }, solid("#ffffff", 0.8))
	local function star(x, y, r)
		local p = {}
		for i = 0, 7 do
			local a = math.rad(i * 45 - 90)
			local rr = (i % 2 == 0) and r or r * 0.22
			table.insert(p, { x + rr * math.cos(a), y + rr * math.sin(a) })
		end
		fillPoly(p, solid("#ffffff", 1))
	end
	for _, s in ipairs({ { 372, 120, 30 }, { 128, 402, 22 }, { 404, 372, 16 }, { 96, 150, 14 } }) do
		star(s[1], s[2], s[3])
	end

	local buf = buffer.create(N * N * 4)
	for i = 1, N * N do
		local o = (i - 1) * 4
		buffer.writeu8(buf, o, math.floor(math.clamp(R[i], 0, 1) * 255 + 0.5))
		buffer.writeu8(buf, o + 1, math.floor(math.clamp(G[i], 0, 1) * 255 + 0.5))
		buffer.writeu8(buf, o + 2, math.floor(math.clamp(B[i], 0, 1) * 255 + 0.5))
		buffer.writeu8(buf, o + 3, math.floor(math.clamp(A[i], 0, 1) * 255 + 0.5))
	end
	local img = AssetService:CreateEditableImage({ Size = Vector2.new(N, N) })
	img:WritePixelsBuffer(Vector2.zero, Vector2.new(N, N), buf)
	return img
end

function IconeGema.Get()
	if tentou then
		return cache
	end
	tentou = true
	local ok, img = pcall(render, 128)
	if ok and img then
		cache = Content.fromObject(img)
	else
		warn("[IconeGema] Não deu para desenhar o ícone: " .. tostring(img))
	end
	return cache
end

return IconeGema

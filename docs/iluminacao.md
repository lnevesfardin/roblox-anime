# Iluminação da cidade (Lighting no Studio)

As propriedades do Lighting ficam só no place (não são scripts). Estes são os valores atuais.
O estado anterior está guardado em `ServerStorage.Backup_Iluminacao.Lighting_Antes` (atributos + cópias dos efeitos).

| Propriedade | Valor |
|---|---|
| GeographicLatitude | 28 (sol inclinado, sombras mais bonitas) |
| Brightness | 2.6 |
| Ambient | 92, 88, 104 (debaixo de telhado não fica preto) |
| OutdoorAmbient | 122, 118, 132 |
| ColorShift_Top | 150, 118, 84 (sol levemente dourado) |
| EnvironmentSpecularScale | 0.45 (menos cara de plástico) |
| ExposureCompensation | 0.1 |
| ShadowSoftness | 0.35 |

Efeitos em `Lighting`:
- **Sky**: só um (rbxassetid 6444884337, céu com nuvens da Roblox). Os outros 3 céus foram para o backup.
- **Atmosphere**: Density 0.28, Offset 0.2, Color 205,214,230, Decay 118,128,150, Glare 0.35, Haze 1.1.
- **Bloom**: Intensity 0.55, Size 26, Threshold 1.4.
- **SunRays**: Intensity 0.07, Spread 0.55.
- **CorCidade** (ColorCorrection, novo): Brightness 0.02, Contrast 0.12, Saturation 0.15, Tint 255,250,242.
- **Terrain.Clouds** (novo): Cover 0.45, Density 0.55.

Os efeitos soltos no `workspace` (Bloom/Blur/ColorCorrection/SunRays vindos de modelos importados) não faziam nada
lá e foram para o backup.

`ServerScriptService/DiaNoite` lê os valores de dia do Lighting ao iniciar e, à noite, leva suavemente para:
sol/lua 40,55,95 · Ambient 60,64,88 · OutdoorAmbient 70,80,115 · cor da Atmosphere 70,80,115 · tinta da CorCidade 220,228,255.

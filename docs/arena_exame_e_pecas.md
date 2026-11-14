# Arena do Exame Ninja e peças que existem só no Studio

Itens abaixo vivem no place (TeamCreate), não em `src/`. Se o place for recriado, precisam ser refeitos.

## Workspace.Mapa_ExameNinja (arena do Kakashi / Sensei Kaito)

Luta do Exame Ninja: **gramado só no centro, floresta em volta**.

- `MapData.Maps.ExameNinja.Arena = "ExameNinja"` faz o WaveServer usar `workspace.Mapa_ExameNinja`.
  O mapa Ninja (Snake's Den) usa `Mapa_Ninja`; o Hokage (Rogue Ninja Raid) agora tem arena própria, `Mapa_Hokage` (abaixo).
- Contrato exigido pelo WaveServer (`runMap`): filhos `ArenaSpawn` e `Centro`,
  atributos `PisoY` (2.3) e `RaioSpawn` (30).
- Posições: `ArenaSpawn` (-525, 3, -1200), `Centro` (-525, 2, -1230).
  A IA dos inimigos fica presa a ±44-46 studs do `Centro`; o boss nasce em `Centro - 20 Z`, 10 acima do piso.
- Conteúdo (833 filhos, ~320 x 324 studs): `Gramado` (disco no centro), `ChaoFloresta`,
  195 `Tronco`, 585 `Copa`, 36 `Arbusto`, 8 `Pedra`, 4 `Muro` (paredes invisíveis), `LuzArena`.
- Verificado em Play: `[WaveServer] Ninja Exam iniciado com 1 jogador(es)` sem aviso de "Mapa não encontrado".

## Workspace.Mapa_Hokage (arena da Rogue Ninja Raid)

Pátio murado de Konoha sob ataque, **separado** do covil da cobra. `MapData.Maps.Hokage.Arena = "Hokage"`.

- Posição: centro em (-525, 2, -1560), no terreno livre ao sul do `Mapa_ExameNinja`. Piso em y = 2.
- Contrato do WaveServer: filhos `ArenaSpawn` (-525, 3, -1520, lado sul) e `Centro` (-525, 2, -1560); atributos `PisoY` (2) e `RaioSpawn` (40).
- Conteúdo (~240 descendentes): `Chao` e `Praca` (praça redonda com anel vermelho), 4 muros com beiral de telha, pilares, portão fechado ao sul,
  4 `Limite*` invisíveis (paredes altas, ninguém sai), `TorreHokage` e `Penhasco` ao fundo (norte), `CasasFora` (cenário fora dos muros leste e oeste),
  `Decoracao` (9 tochas com fogo e luz, 6 estandartes, caixas e barris nos cantos e perto do portão, entulho com fogo/fumaça, marcas de queimado) e `LuzArena`.
- Obstáculos ficam nas bordas (a IA dos inimigos anda só a ±44-46 studs do `Centro`).
- Verificado em Play: `[WaveServer] Rogue Ninja Raid iniciado com 1 jogador(es)`; o jogador aparece em `ArenaSpawn` e a 1ª onda nasce dentro do pátio.

## ServerStorage.PecasNPC.KibaHair

Accessory usado pelo Kiro (MestreInu) em `MundoExtras.kibaEnfeites`.
Origem: asset 524654418, "KIBA INUZUKA HAIR (NUNS)" (autor minhbelly).
Se faltar, o código cai num fallback (bola + espetos de cabelo).
Colocação: `Handle.CFrame = Head.CFrame * HatAttachment.CFrame * AttachmentPoint:Inverse()` (o AttachmentPoint do
asset tem ~180° de giro em Y; sem ele o cabelo ficava virado para trás). O asset já traz a testeira de Konoha,
então a testeira "@" feita por código só é criada no fallback.

## Workspace.MestreLee

Antigo "StarterCharacter" (modelo Villager enviado pelo usuário, com visual de Rock Lee),
renomeado para `MestreLee` e com a tag `NPC`. Fica perto de (44.7, 3.2, -510.6),
descrito em `MissionData` como "near Market Street". O Rokuro feito de blocos foi removido do `MundoExtras`.

## Criado por script ao iniciar o servidor (não aparece no Edit)

- `MundoExtras`: cemitério (36 peças + `TumuloPrimeiro`), agora no miolo da floresta em `MissionData.Lugares.Cemiterio` = (160, 3, 305), Kiro e o cão Aka.
- No jogo real `AnimationConstraint.C0` é somente leitura: poses estáticas são feitas por CFrame das peças
  e depois todas as peças ficam `Anchored` (ver `posar` em `kibaEnfeites`).

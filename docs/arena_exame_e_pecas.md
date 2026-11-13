# Arena do Exame Ninja e peças que existem só no Studio

Itens abaixo vivem no place (TeamCreate), não em `src/`. Se o place for recriado, precisam ser refeitos.

## Workspace.Mapa_ExameNinja (arena do Kakashi / Sensei Kaito)

Luta do Exame Ninja: **gramado só no centro, floresta em volta**.

- `MapData.Maps.ExameNinja.Arena = "ExameNinja"` faz o WaveServer usar `workspace.Mapa_ExameNinja`.
  Os mapas Ninja e Hokage continuam usando `Mapa_Ninja`.
- Contrato exigido pelo WaveServer (`runMap`): filhos `ArenaSpawn` e `Centro`,
  atributos `PisoY` (2.3) e `RaioSpawn` (30).
- Posições: `ArenaSpawn` (-525, 3, -1200), `Centro` (-525, 2, -1230).
  A IA dos inimigos fica presa a ±44-46 studs do `Centro`; o boss nasce em `Centro - 20 Z`, 10 acima do piso.
- Conteúdo (833 filhos, ~320 x 324 studs): `Gramado` (disco no centro), `ChaoFloresta`,
  195 `Tronco`, 585 `Copa`, 36 `Arbusto`, 8 `Pedra`, 4 `Muro` (paredes invisíveis), `LuzArena`.
- Verificado em Play: `[WaveServer] Ninja Exam iniciado com 1 jogador(es)` sem aviso de "Mapa não encontrado".

## ServerStorage.PecasNPC.KibaHair

Accessory usado pelo Kiro (MestreInu) em `MundoExtras.kibaEnfeites`.
Origem: asset 524654418, "KIBA INUZUKA HAIR (NUNS)" (autor minhbelly).
Se faltar, o código cai num fallback (bola + espetos de cabelo).

## Workspace.MestreLee

Antigo "StarterCharacter" (modelo Villager enviado pelo usuário, com visual de Rock Lee),
renomeado para `MestreLee` e com a tag `NPC`. Fica perto de (44.7, 3.2, -510.6),
descrito em `MissionData` como "near Market Street". O Rokuro feito de blocos foi removido do `MundoExtras`.

## Criado por script ao iniciar o servidor (não aparece no Edit)

- `MundoExtras`: cemitério (36 peças + `TumuloPrimeiro` perto de (50, 0.3, 462)), Kiro e o cão Aka.
- No jogo real `AnimationConstraint.C0` é somente leitura: poses estáticas são feitas por CFrame das peças
  e depois todas as peças ficam `Anchored` (ver `posar` em `kibaEnfeites`).

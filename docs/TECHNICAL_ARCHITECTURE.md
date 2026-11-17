# TECHNICAL ARCHITECTURE

Принципы: сервер — источник истины; один владелец на каждое состояние; прямые вызовы модулей; без циклических зависимостей; NPC-сервисы не меняют Coins напрямую (только через RewardService).

## Размещение
```
ReplicatedStorage
  Configs/   Balance, Rarities, Obstacles, NPCs, Progression      (данные, без секретов)
  Shared/    Net, Util, PlotMath, ObstacleModels, NPCRig, UIKit   (общая логика)
  Remotes/   создаётся сервером из списка Net
ServerScriptService
  Main (Script)                       порядок запуска
  Services/  PlayerDataService, PlotService, BuildService, ObstacleShopService, NPCShopService,
             NPCInventoryService, NPCPlacementService, NPCRunService, NPCBrainService,
             ObstacleTraversalService, CourseValidationService, ManualCourseRunService,
             RewardService, RebirthService, DailyChallengeService, LeaderboardService,
             RatingService, CosmeticService
  Systems/   ObstacleRuntime (анимация препятствий), Collisions, RateLimiter
StarterPlayerScripts/Controllers      StateController, HUDController, BuildController, ShopController,
                                      InventoryController, NPCController, PlayController, ...
Workspace  PlayerPlots, Lobby, DailyChallenges, Leaderboards, WorldAssets, Runtime
```

## Владельцы состояния и контракты (будут уточняться по мере реализации)
| Сервис | Владеет | Публичные методы (вход -> результат / ошибки) |
|---|---|---|
| PlayerDataService | профиль игрока, сессионная блокировка, сохранение | `Get(player)->Profile?`, `Wait(player)`, `Mutate(player, fn)->ok`, `Changed` signal; ошибки: `NoProfile`, `SaveFailed` |
| RewardService | **единственный** менялка Coins/Lifetime | `Grant(player, amount, source, idemKey)->granted:number`; дубль ключа -> 0 |
| PlotService | модели участков, назначение | `GetPlot(player)`, `GetPlotByOwnerId(id)`, `Expand(player)`, `GetStartCFrame(plot)` |
| BuildService | список построек, версия трассы | `Place/Move/Remove(player, req)->{ok,err}`; ошибки: `NotOwner`, `NoItem`, `OutOfBounds`, `Overlap`, `LimitReached`, `Forbidden`, `Rate` |
| CourseValidationService | граф, статусы, сложность | `Analyze(plot)->{playerPlayable, npcPlayable, stages, difficulty, warnings}` |
| ManualCourseRunService | ручные сессии | `Start(player, plot)`, события чекпоинтов/финиша, отмена |
| NPC*Service | коллекция/слоты/площадки/run | см. TASKS T11,T15,T16 |
| ObstacleShopService / NPCShopService | текущая ротация | `GetAssortment()`, `Buy(player, id)` |

## Сеть
- RemoteFunction: Buy, Build*, NPC*, Run*, Rebirth, Rate (всегда проверка типов, диапазонов, владения, rate limit).
- RemoteEvent (сервер->клиент): State (дельты профиля), ShopSync, RunState, Notify, Effects.

## Данные игрока (версия 1)
`{version, coins, lifetime, rebirth, inv={obstacleId=count}, npcs={id=true}, slots={id|false}, plot={objects={{id,gx,gz,lvl,rot}},decor={...},version,name}, stats, daily, ratings, purchases}`

## Тайминг препятствий
`ObstacleRuntime`: один Heartbeat; движущиеся части обновляются через `workspace:BulkMoveTo`; фаза = f(`GetServerTimeNow()`).

## Коллизии
CollisionGroups: `Default` (препятствия), `Players`, `NPC`. NPC не сталкиваются с `NPC` и `Players`.

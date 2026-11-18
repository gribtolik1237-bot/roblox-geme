# 03. Карта кода и документов

## Где живёт код
Код и мир живут ВНУТРИ места Roblox (без Rojo). `../place/` — выгрузка 73 скриптов по дереву Studio: `.server.luau` = Script, `.client.luau` = LocalScript, `.luau` = ModuleScript. Правка в `place/` сама в игру НЕ попадает — её нужно перенести в Studio (MCP `multi_edit`/`execute_luau`) и сохранить место (`save_place`). После правок в Studio — снова выгрузить (`../tools/export-place.cjs`, проверка `../tools/verify-export.cjs`, см. `../place/EXPORT_STATUS.md`).

## Архитектура
- `ServerScriptService/Main.server.luau` — старт: Net.init, запуск всех сервисов.
- `ServerScriptService/Services/` — сервер (единственная власть над монетами/данными):
  - Данные: `PlayerDataService` (профиль, session lock, ретраи, автосейв, DevFreshProfile), `StateSync` (отправка состояния клиенту), `SessionService` (вход/выход, персонаж).
  - Участки/стройка: `PlotService` (участки, зона, площадки, табличка), `BuildService` (Place/Move/Remove, 3 слота сохранения), `CourseValidationService` (граф маршрута старт→финиш, playerPlayable/npcPlayable, точки GAP).
  - Экономика: `RewardService` (единственный, кто меняет монеты), `ShopCore` + `ObstacleShopService` + `NPCShopService` (ротация, покупки), `ShopWorldService` (киоски, телепорт), `RebirthService`, `DailyService`, `LoginRewardService`, `DonateService` (ProcessReceipt).
  - NPC: `NPCPlacementService` (слоты, площадки), `NPCRunService` (забег, оплата этапов, конец), `NPCBrainService` (управление на физике, планировщик опасностей), `ObstacleTraversalService` (маршрут из этапов), `WearService` (одежда каталога).
  - Прочее: `ManualCourseRunService` (ручной забег, анти-чит), `RatingService`, `LeaderboardService`, `HallService` (Зал), `DecorService`.
- `ServerScriptService/Systems/` — чистые модули: `RewardMath` (формулы наград), `ObstacleRuntime` + `Behaviors` (движение ловушек, опасности), `GroundCheck`, `ShopRotation`, `Collisions`, `NPCAnimator`, `AvatarScale`, `NpcTypes` (типы strict).
- `ReplicatedStorage/Configs/` — данные: `Balance` (ВСЕ числа, лимиты remotes), `Obstacles` (27 ловушек), `NPCs` (21), `Progression`, `Rarities`, `Donate`, `Icons`, `NPCWear`, `Decor`, `Strings` (тексты ошибок).
- `ReplicatedStorage/Shared/` — общее: `Net` (реестр remotes, `Net.handle` с rate limit и pcall), `UIKit` (вся визуальная система UI: окна, кнопки, тосты, превью), `ObstacleModels` (процедурные модели ловушек, общие для сервера и призрака), `NPCRig` (сборка аватаров), `PlotMath`, `Util`, `SignKit`, `DecorModels`.
- `StarterPlayer/StarterPlayerScripts/Client.client.luau` — запускает `Controllers/`: `HUDController` (монеты, меню, модальность), `BuildController` (стройка, магнит, GAP), `ShopController`, `NPCController`, `RunController` + `FirstPersonController` (забег), `GuideController` (стрелки обучения), `MetaController` (Daily/Popular/Rate), `RebirthController`, `InventoryController`, `DonateController`, `LoginRewardController`, `CourseSlotsController`, `CameraController`, `SfxController`, `StateController` (зеркало состояния), `DecorController`.
- `ServerStorage/WorldRecipes/ShopRestyle.luau` — воспроизводимый рецепт оформления киосков.

## Правила кода
- Сервер решает всё (монеты, покупки, награды); клиент только показывает. Каждый remote — через `Net.handle(name, Balance.RateLimits.X, fn)`; проверка типов/NaN/диапазонов на сервере.
- Числа — только в `Configs/Balance`; тексты ошибок — `Configs/Strings`.
- Запечённое в мире (Зал, киоски с атрибутом `HandEdited`, таблички) — правка кода без перепекания в мир не попадает.
- Тесты в Studio: `DevFreshProfile=true`, временные скрипты `ZZ_*` (удалять после), `require` из execute_luau = отдельный экземпляр модуля.

## Документы (`../docs/`)
| Нужно | Файл |
|---|---|
| Живое дерево задач | DEVELOPMENT_TREE.md |
| Приёмка качества | QUALITY_REVIEW.md, ART_WORKFLOW.md |
| Стиль и эталоны | ART_DIRECTION.md, ../references/ |
| Решения | DECISIONS.md (D-xxx) |
| История задач/тестов | TASKS.md (T-xx), TESTING_REPORT.md, BUG_TRACKER.md |
| Баланс | BALANCE.md (+ Configs/Balance) |
| Ассеты и их источники | ASSET_REGISTRY.md |
| Передача между чатами | HANDOFF.md (последний раздел), NEXT_CHAT_PROMPT_S9.md |
| Итог сессии 8 | REPORT_AUDIT_S8.txt |

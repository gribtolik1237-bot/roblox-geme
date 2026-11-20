# UI-13: удаление мусора (2026-11-20, слово владельца «удаляй мусор»)

Удалено в Studio (Team Create, до save):
- `StarterPlayerScripts/Controllers/InventoryController` и `DecorController` — окна, которые ничем не открывались после D-031 (инвентарь в хотбаре со страницами, Decor убран владельцем). Убраны из порядка загрузки `Client.client.luau`.
- `StarterGui.ScreenGui` — пустой ScreenGui (0 потомков), копировался в PlayerGui каждому игроку.
- `ServerStorage.Models` и `ReplicatedStorage.UIAssets` — пустые папки (0 потомков), ссылок в коде нет (grep по place/).
- Комментарий в `Configs/Strings` без упоминания DecorController.
Оставлено: `DecorService` (сервер) — показывает уже поставленный декор в старых профилях; `Configs/Decor`, `Shared/DecorModels` — нужны участкам (PlotService props).

Проверки: выгрузка 74/74 PASS; Play (ПК, чистый профиль) — консоль чистая, PlayerGui = TrapLabHUD, CourseSlotsGui(+Reverse), GuideArrows, Freecam (Studio); окна HUD: ObstacleShop, NPCShop, NPCTesters, Rebirth, PopularCourses (доска зала, HallService OpenBoard), Rate this course (после забега), Support (Donate), DailyGift — у каждого есть источник открытия. Хотбар виден.

## После ACCEPT (замечания P3 chief)
- `BuildController.Select`: комментарий исправлен (хотбар, цифры, GuideController).
- Окно Rebirth: убрана строка «Decoration limit» (3 строки вместо 4, блоки ниже подняты на 54 px, окно 660x486 вместо 660x540), текст «You KEEP all Coins, buildings, items and NPCs». Кадры `rebirth_window_r0.jpg` (R0, «сейчас > после») и `rebirth_window_max.jpg` (R10 MAX, профиль владельца — только просмотр, подарок не забирался).
- `Configs/Strings`: удалена неиспользуемая таблица `Strings.Decor`.
- Выгрузка 74/74, Studio совпала с локальной правкой побайтно, линт 2 (UnknownType). Сохранение Team Create 246.

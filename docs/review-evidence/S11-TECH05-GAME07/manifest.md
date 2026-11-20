# S11: TECH-05 (линт) и GAME-07 (стрелка Rebirth)

- Дата: 2026-11-20. PlaceId 135937017652181, Team Create, Studio version 236 (до save_place этого пакета).
- Устройство: окно Studio Play, ПК-раскладка (кадры 1311x620).

## Изменения
1. TECH-05 пакет 1 (коммит 859f548): 12 модулей, удалены неиспользуемые переменные, импорты и функции (`segDist`, `notify` в NPCRunService), явные `return nil` в `findPlot`/`myPlot`.
2. TECH-05 пакет 2 (`s11_batch2_and_guide.diff`): 63 точки с запятой между операторами на одной строке в 18 модулях. Логика не менялась.
3. GAME-07: `StarterPlayer/StarterPlayerScripts/Controllers/GuideController` — новая `shownOnScreen(b)`, стрелка к кнопке HUD показывается, только если кнопка И все её родители видимы (раньше проверялась только сама кнопка).

## Найденный дефект (до правки)
`before_arrow_over_daily_gift.jpg`: при открытом Daily Gift HUD скрывает `MenuColumn` (окна модальные), но кнопка Rebirth внутри оставалась Visible, поэтому стрелка «Rebirth» висела над щитом PLAY в мире и указывала в пустоту.

## После правки
- Открыт Daily Gift: `MenuColumn.Visible=false`, видимых элементов стрелки 0 (проверка в клиенте).
- Окно закрыто кликом по `DailyGiftWindow.Close`: `after_window_closed_arrow_rebirth.jpg`, стрелка указывает на плитку Rebirth.

## Тесты (Play, `DevFreshProfile=true`, затем false; ZZ_* удалены)
- Линт `node tools/luau-lint.cjs`: 79 → 2 (остались 2 UnknownType 'Vector3' — ограничение анализатора без определений Roblox).
- Выгрузка из Studio после каждой правки совпала с локальной правкой побайтно; verify 76/76.
- Сервер стартует без ошибок, 8 участков, PlayRing/PlayDisc на месте; клиентские Gui создаются.
- NPC Starter: Place + Launch на стартовой трассе, финиш за 14 с, монеты 300 → 362. Ручной забег: Start → Active, Cancel → не Active.
- Шаг обучения 5: при lifetime 3000 после шагов 1–4 стрелка «Rebirth» у плитки Rebirth.
- Куст `Plot_1/Prop_Bush` (4 MeshPart, CanCollide у 0 деталей): аватар прошёл по прямой через центр (0.5 стада от центра) и дошёл до цели.
- NOT TESTED: живой тач-ввод на реальном телефоне (эмулятор Studio не принимает клики мышью по окнам; окно Daily Gift на телефоне закрыто через `Visible=false`, это тот же путь `UIKit.WindowChanged`, что и у крестика).

## Раунд 2 (после ответа chief: P2 diff пакета 1, P3 телефон)
- `s11_batch1.diff` — полный diff коммита 859f548.
- Телефон iPhone 17 Pro (viewport 750x381): `phone17_daily_open_no_arrow.jpg` — окно открыто, стрелки нет; `phone17_after_fit_arrow_rebirth.jpg` — окно закрыто, стрелка «Rebirth» у плитки.
- НАЙДЕНО на телефоне: `phone17_before_fit_donate_on_thumb.jpg` — плитка Donate (y 201–263, x 11–73) заходила на покоящийся джойстик (ThumbstickStart y 230–304, x 29–103). Правка `HUDController` (`s11_hud_thumbfit.diff`): на сенсорных экранах `UIScale FitAboveThumb` у MenuColumn уменьшает колонку, чтобы её низ был не ниже высоты экрана минус 100 px (минимум 0.72).
  - iPhone 17 Pro: масштаб 0.79, плитки 49 px, низ колонки 223 < верх джойстика 230.
  - iPhone 7 (666x374, самый маленький телефон в списке): масштаб 0.82, плитки 48 px, низ 215 < 223 (`iphone7_after_fit.jpg`).
  - iPad Pro M5 13": масштаб 1, плитки 96 px, без изменений (`ipad_scale1.jpg`).
  - ПК (TouchEnabled=false): масштаб 1, без изменений.
- Свет ART-10 в других сценах (ПК, высота глаза 10 стад): `pc_light_plaza.jpg` (площадь и доски), `pc_light_ridge.jpg` (стена и круглые деревья на гребне). Пересвета и провалов нет, доски читаются.
- После тестов: `DevFreshProfile=false`, ZZ_* 0, эмулятор `default`.

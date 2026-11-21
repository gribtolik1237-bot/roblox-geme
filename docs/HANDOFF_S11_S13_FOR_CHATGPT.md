# TRAP LAB — сводка работы Claude, сессии S11–S13 (2026-11-20 … 2026-11-21)

Файл для ChatGPT/Codex и любого следующего ассистента. Источник правды для игры — место Roblox (PlaceId 135937017652181, Team Create, последнее сохранение 265); `place/` — точная выгрузка его скриптов (75/75, `node tools/verify-export.cjs` = PASS). Все изменения ниже есть в git (ветка main, последние коммиты до `d4e9b7b`).

## 1. Правила владельца (действуют)
- Говорить с владельцем только по-русски, коротко.
- Получив промт сессии — работать без остановок, пока не выполнено всё; вопросы только о настоящих решениях владельца; стоп у 95–97 % лимита.
- Опираться на `docs/MASTER_PROMPT.md` (таблица сверху важнее), текущий `docs/NEXT_CHAT_PROMPT_S*.md`, `CLAUDE.md`/`AGENTS.md`, `PROJECT_GUIDE/01_GAME.md`.
- Без «нейрослопа»; цветной studs-пластик; дерево допустимо где подходит; Daily Challenges убраны навсегда (подарок за вход остался); киоски компактные, один продавец; обучение только стрелками с 1–2 словами; размеры препятствий не менять (физика NPC); цены доната не менять без владельца.
- Доски лидеров — топ-100 с прокруткой (решение D-039).
- Владелец разрешил автоматические commit+push и (2026-11-21) доступ к окну Studio для настоящих скриншотов.
- Тесты — только на `ServerStorage.DevFreshProfile = true` (иначе грузится НАСТОЯЩИЙ профиль владельца), потом false; временные скрипты `ZZ_*` удалять; эмулятор устройства возвращать на default.

## 2. Как работать с проектом (проверенный процесс)
1. Правка кода: меняешь файл в `place/…` локально, переносишь ту же правку в Studio (через Studio MCP `execute_luau`: сверка исходной строки → замена; в S12 для этого был скрипт-генератор патча по `git diff HEAD`).
2. `node tools/export-place.cjs --mcp "C:/Users/yarik/AppData/Local/Roblox/Versions/version-8d7a1009c17e4ff8/StudioMCP.exe"` и сравнение `git diff` до/после — должно совпасть побайтно; `node tools/verify-export.cjs`.
3. Play-проверка: временный серверный `ZZ_*` Script с живыми модулями (`NPCPlacementService.Place(p,{slot,pad})`, `NPCRunService.Launch(p,{pad})`, `ManualCourseRunService.Start/Cancel`, `BuildService.Place/Remove`, `CourseValidationService.Analyze`, `StateSync.Push`), вывод `print("[TEST] …")`.
4. Визуал: кадр с высоты глаза 9–10 стад. ВНИМАНИЕ: `screen_capture` не рисует частицы и врёт по цветам перекрашиваемых деталей — финальный вид проверять настоящим экраном.
5. Проверка ревьюером `trap-lab-chief` (`.claude/agents/trap-lab-chief.md`, правила `docs/QUALITY_REVIEW.md`): Чекпоинт 1 — образец, Чекпоинт 2 — логика + чистая консоль; «принято» только по его ответу.
6. `save_place`, обновить `docs/DEVELOPMENT_TREE.md`, `PROJECT_GUIDE/02_STATUS.md`, `docs/TESTING_REPORT.md`, уроки в `CLAUDE.md`, commit + push.
Уроки ошибок — `CLAUDE.md`, раздел «БАЗА ОШИБОК И УРОКОВ».

## 3. Что сделано (по сессиям)
### S11 (2026-11-20)
- Линт Luau (TECH-05): 79 → 2 замечания (мёртвый код в 12 модулях, «;» в 18). Остались 2 ложных UnknownType 'Vector3' (анализатор без описаний Roblox). Инструмент: `node tools/luau-lint.cjs`, описание в `docs/TOOLS.md`.
- Стрелка обучения (GAME-07): прячется, когда модальное окно скрыло колонку меню (`GuideController.shownOnScreen`).
- Телефон (UI-12): левая колонка меню на сенсорных экранах уменьшается, чтобы не лежать на джойстике (`HUDController`, UIScale `FitAboveThumb`).
- Свет (ART-10): серия по сценам принята. Go to shop вдали, звуки (14 грузятся), проход сквозь куст — проверены.
### S12 (2026-11-20)
- Удалён мусор (UI-13): окна Inventory/Decorations (не открывались), пустой StarterGui.ScreenGui, пустые папки, `Strings.Decor`, строка «Decoration limit» в окне Rebirth. Серверный DecorService оставлен.
- Препятствия (ART-05): MovingPlatform, RampUp, SpeedPlatform, BouncePad получили studs и кромки как остальные настилы (только материал/декор без коллизии, трение 0.2 сохранено). Таблица 27 препятствий и порядок серии — `docs/review-evidence/S12-ART05-moving/manifest.md`.
### S13 (2026-11-21)
- Доски лидеров топ-100 с прокруткой (D-039): клиентский `BoardController` строит SurfaceGui в PlayerGui с Adornee = щит, сервер (`HallService`) публикует строки JSON-атрибутом `Rows` на щите; `LeaderboardService`: имена пачками по 15 (100 имён за 1.7 с), неудачи повторяются через 90 с, защита от параллельного обновления. Колесо прокручивает, строка «You: #N», Popular открывается по E. Принято chief.
- Курс серии препятствий: Speed → Moving → Ramp → Finish, NPC 4/4; Moving Wall — Runner 6/6.
- Редкие NPC (ART-04): в `NPCController` реестр клиентских эффектов `fx` (один Heartbeat ≤30 Гц, ≤80 стад, частицы ≤60 стад): Spectrum (радуга по сегментам), Shadow (фиолетовое тело, Highlight, дым), Glitch (вспышки сбоя, «пиксели»), Overlord (красная кайма, тлеющие рога, искры), Crystal (ледяной блик, осколки), Galaxy (туманность, мерцающие звёзды). Превью в окне NPC/магазине — `NPCRig.PreviewLook`. Принято chief по снимкам.
- `WearService`: лог «N items in store (M newly loaded, K failed)» вместо вводящего в заблуждение «0 ok».

## 4. ОТКРЫТЫЙ ДЕФЕКТ (делать первым)
На НАСТОЯЩЕМ экране Studio (после перезапуска Studio, Play, чистый профиль, 6 редких NPC на площадках 1–6) Spectrum, Overlord, Glitch и Galaxy рисуются СЕРЫМИ, хотя их свойства Color на клиенте яркие (Glitch торс 20,20,20, голова зелёная на сервере; Overlord 88,28,40; Spectrum розовый; Galaxy синий). Цветные — Shadow (площадка 1) и Crystal. Неон, звёзды, кайма Highlight и волосы видны. Клонов/перекрытий нет. До перезапуска Studio Glitch и Overlord были цветными на снимках.
Кадр: `docs/review-evidence/S13-ART04-npcs/REAL_SCREEN_grey_bug.jpg`; гипотезы и план: там же `manifest.md`, раздел «ДЕФЕКТ на РЕАЛЬНОМ экране». Проверить: обычный NPC (Bacon) на площадке 2; Glitch на площадке 1; у тела R15 (`ReplicatedStorage.Assets.R15Base`) TextureID/SurfaceAppearance; качество графики Studio. Мой прежний вывод «серое — артефакт снимка» был НЕВЕРНЫМ; приёмка эффектов chief'ом из-за этого под вопросом.

## 5. Что ещё не сделано / NOT TESTED
- Частицы эффектов на настоящем экране; телефон для эффектов; карточка редкого NPC на полке NPC Shop.
- Прокрутка досок пальцем и тап по prompt на телефоне.
- ART-04: сверка всех 21 NPC (Common–Legendary не менялись); Crystal близок к Frost.
- ART-08: композиция остальных участков. GAME-05: Prism Spinner, Laser Labyrinth и др. на других трассах.
- TECH-05: ~90 предупреждений видны только на панели Studio Script Analysis (`luau-lsp` — только по слову владельца).
- 8 игроков, переподключение, live DataStore-ошибки, покупка Robux, звук на слух, ночь, геймпад.
- У владельца в тестовой трассе конвейер задом наперёд — только напомнить.

## 6. Где что лежит
- Дерево задач: `docs/DEVELOPMENT_TREE.md`; статус: `PROJECT_GUIDE/02_STATUS.md`; тесты: `docs/TESTING_REPORT.md`; решения: `docs/DECISIONS.md` (D-039).
- Отчёты: `docs/REPORT_S11.txt`, `docs/REPORT_S12.txt`, `docs/REPORT_S13.txt`; промт Claude: `docs/NEXT_CHAT_PROMPT_S14.md`; промт ChatGPT: `docs/NEXT_PROMPT_CHATGPT.md`.
- Доказательства (кадры, diff, манифесты): `docs/review-evidence/S11-*`, `S12-*`, `S13-*`.
- Память Claude (копия): `claude/memory/`.

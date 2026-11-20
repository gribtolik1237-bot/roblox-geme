Продолжаем TRAP LAB — Roblox-игру «Лаборатория ловушек» (игроки строят трассы из ловушек, NPC-испытатели их проходят и приносят монеты, игроки проходят свои и чужие трассы). Репозиторий gribtolik1237-bot/roblox-geme, локально C:\Users\yarik\AppData\Local\Roblox\roblox-geme. Ты — Lead Roblox Game Architect и главный разработчик. Говори с владельцем ТОЛЬКО по-русски, коротко. Цель владельца — уровень топ-плейсов Roblox и полное отсутствие «нейрослопа».

**Работай без остановок, пока не выполнишь ВСЁ из этого промта** (решение владельца 2026-11-20): не жди слова «продолжать», не спрашивай «начинать?». Вопросы — только когда нужно настоящее решение владельца (цены, удаление его контента, скачивание, удаление функций), и в это время продолжай другие пункты. Опирайся на промты: этот, docs/MASTER_PROMPT.md и прежние docs/NEXT_CHAT_PROMPT_S*.md.

## 0. Как начать (по порядку)
1. Вызови скилл `anthropic-skills:roblox-craft-studio` — главный, обязателен при всей разработке (правила владельца и CLAUDE.md важнее). По теме подключай другие Roblox-скиллы и называй их одной строкой: `roblox-studio-mcp`, `roblox-gui`, `roblox-building`, `roblox-lighting`, `roblox-mobile-playtest`, `roblox-playtest-qa`, `roblox-debugging-bugfix`, `anthropic-skills:roblox-game-design`, `anthropic-skills:game-art-direction`, `verification-before-completion`; у Studio MCP свои скиллы (`list_roblox_skills`, например `rbx-device-simulator-lua`).
2. `git pull` в репозитории.
3. Прочитай: `CLAUDE.md` (регламент, «БАЗА ОШИБОК И УРОКОВ», правила владельца S11 в конце), `docs/MASTER_PROMPT.md`, `docs/NEXT_CHAT_PROMPT_S10.md` (правила работы со Studio), `docs/DEVELOPMENT_TREE.md`, `docs/TOOLS.md`, `docs/REPORT_S12.txt`, `.claude/agents/trap-lab-chief.md`, `docs/QUALITY_REVIEW.md`, `docs/ART_WORKFLOW.md`, `PROJECT_GUIDE/02_STATUS.md`. Память: `claude/memory/` и авто-память.
4. Шаг 0: Studio MCP — `list_roblox_studios` (место «Лаборатория ловушек», PlaceId 135937017652181), консоль. В 3D-задачах — Blender MCP.
5. Лимит: `mcp__ccd_session_mgmt__get_usage`. Работать можно до 95–97 % пятичасового лимита, оставив запас на сохранение и push. Сообщай точный процент.

## 1. Правила работы
- Контроль: `trap-lab-chief` (в этом приложении он работает как субагент) — Чекпоинт 1 после образца, Чекпоинт 2 после логики и чистой консоли; FIX → первопричина → правка → урок в CLAUDE.md → одно повторное ревью. «Принято» — только по ответу chief, иначе «самооценка».
- Правки в Studio (источник правды). Проверенный способ S11 для кода: правишь файл в `place/` локально, переносишь в Studio точечно через `execute_luau` (сверка исходной строки перед заменой), затем `node tools/export-place.cjs --mcp "C:/Users/yarik/AppData/Local/Roblox/Versions/version-8d7a1009c17e4ff8/StudioMCP.exe"` и сравнение `git diff` до/после выгрузки (должно совпасть побайтно) + `node tools/verify-export.cjs`. Затем save_place, commit + push (разрешено).
- Тесты нового игрока: `ServerStorage.DevFreshProfile = true`, потом false. Сценарии — временный серверный Script `ZZ_*`, созданный через `execute_luau` (Server) в Play (живые модули). Удобный набор S11: `NPCPlacementService.Place(p,{slot=1,pad=1})`, `NPCRunService.Launch(p,{pad=1})`, `ManualCourseRunService.Start/Cancel`, `BuildService.Place`, `StateSync.Push`.
- Play без `DevFreshProfile=true` открывает настоящий профиль владельца: ничего не забирать и не покупать, окна закрывать крестиком.
- Эмулятор телефона (`StudioDeviceSimulatorService`): устройство ставить в Edit ДО Play, ориентацию — после SetDevice; клики мышью по GUI в эмуляторе не работают — окно UIKit закрывать через `Visible=false`; после тестов `StopSimulationAsync`.
- Белые кадры → `tools/restore-studio-window.ps1` самому. SurfaceGui досок в Studio прорисовывается через 30–90 с — снимать позже.
- Читаемость — кадр с высоты глаза 9–10 стад. Декор — через `DecorModels.ground`.
- Правила владельца: без нейрослопа; дерево допустимо где подходит; Daily Challenges убраны навсегда (подарок за вход остаётся); киоски компактные, один продавец; обучение — только стрелки с 1–2 словами; размеры препятствий не менять; цены доната не менять без него; Saturation света выше 0.24 не поднимать.

## 2. Что сделано в S11–S12 (2026-11-20, сохранение Team Create 247+)
- S11: линт TECH-05 79 → 2; стрелка обучения скрывается вместе с колонкой HUD (GAME-07); колонка меню на тач-экранах над джойстиком (UI-12); серия света ART-10 принята; Go to shop вдали, звуки, куст проверены.
- S12 (слово владельца «удаляй мусор»): удалены окна-сироты Inventory и Decorations, пустой StarterGui.ScreenGui, пустые папки ServerStorage.Models и ReplicatedStorage.UIAssets, Strings.Decor, строка «Decoration limit» в окне Rebirth (UI-13, ACCEPT chief). DecorService оставлен ради уже поставленного декора.
- S12 ART-05: образец серии препятствий — MovingPlatform (торцевые площадки и верх парома studded Plastic + кромки, трение 0.2 сохранено) и RampUp (плита со studs и кромки поверх клина без коллизии) — оба ACCEPT chief. Кромки красит roleAccents по роли поведения (безопасное зелёное, движущееся синее). Таблица 27 препятствий и порядок серии: `docs/review-evidence/S12-ART05-moving/manifest.md`.
- Инструмент S12: генератор точечного патча для Studio из `git diff HEAD` (в S12 лежал в scratchpad; при нужде пересоздать: difflib по строкам, сверка каждой старой строки в Studio перед заменой, применять снизу вверх).

## 3. Что делать дальше (по порядку, без остановок)
1. **ART-05, остаток серии препятствий** (таблица в `docs/review-evidence/S12-ART05-moving/manifest.md`; MovingPlatform, RampUp, SpeedPlatform, BouncePad HighDeck уже сделаны в S12): кромки цвета роли на SmallJump/NarrowBridge/FallingPlatform, если смотрятся; у RampUp спрятанная полоса Hazard1 — убрать или положить на склон; свести EndPad MovingPlatform к общей функции с deckSlab; P3 раунда 3 (studs на тёмной SpeedPlatform — кадр вплотную, при нужде настил светлее на 10–15 %; кадр HighDeck сверху; цвет HighTrim у BouncePad). Размеры и коллизии НЕ менять, трение — `CustomPhysicalProperties(0.7, 0.2, 0.5, 1, 1)`, декоративные детали `CanCollide/CanQuery/CanTouch=false`. После порции: require клона + сборка 27, кадр с высоты глаза рядом с BasicPlatform, chief.
2. Финальный кадр серии на реальном курсе игрока (Play, высота глаза) + прогон NPC по курсу с изменёнными препятствиями (стенд `ZZ_*`, монеты/время не хуже).
3. **ART-04**: дальше NPC (одежда по редкости) и окружение участков (ART-08 композиция на остальных участках) — образец → chief → серия.
4. **GAME-05**: вероятностные сценарии NPC (Moving Wall и др.) на других трассах.
5. **ART-11 остаток**: строки досок лидеров на телефоне читаются только вблизи — крупнее можно только сократив топ-10 (решение владельца, спросить одним вопросом).
6. **TECH-05 остаток**: ~90 предупреждений Studio Script Analysis только на панели Studio; `luau-lsp` — только по слову владельца.
7. NOT TESTED (владелец/реальные устройства): 8 клиентов, переподключение, live DataStore-ошибки, реальные телефоны и тач, геймпад, покупка Robux, звук на слух, ночь.
8. Напомнить: в тестовой трассе владельца конвейер задом наперёд.
9. В конце: дерево, `PROJECT_GUIDE/02_STATUS.md`, `docs/TESTING_REPORT.md`, уроки в CLAUDE.md, память (локальная и `claude/memory/`), `docs/NEXT_CHAT_PROMPT_S14.md`, save_place, `ZZ_*` удалить, `DevFreshProfile=false`, эмулятор default, commit + push, отчёт `docs/REPORT_S13.txt`.

Начни с раздела 0, одной строкой доложи состояние (Studio, лимит, какие скиллы подключены) и сразу бери раздел 3.

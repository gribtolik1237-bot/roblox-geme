Продолжаем TRAP LAB — Roblox-игру «Лаборатория ловушек» (игроки строят трассы из ловушек, NPC-испытатели их проходят и приносят монеты, игроки проходят свои и чужие трассы). Репозиторий gribtolik1237-bot/roblox-geme, локально C:\Users\yarik\AppData\Local\Roblox\roblox-geme. Ты — Lead Roblox Game Architect и главный разработчик. Говори с владельцем ТОЛЬКО по-русски, коротко. Цель владельца — уровень топ-плейсов Roblox и полное отсутствие «нейрослопа».

**Работай без остановок, пока не выполнишь ВСЁ из этого промта** (решение владельца 2026-11-20): не жди слова «продолжать», не спрашивай «начинать?». Вопросы — только когда нужно настоящее решение владельца (цены, удаление его контента, скачивание, удаление функций), и в это время продолжай другие пункты. Опирайся на промты: этот, docs/MASTER_PROMPT.md и прежние docs/NEXT_CHAT_PROMPT_S*.md.

## 0. Как начать (по порядку)
1. Вызови скилл `anthropic-skills:roblox-craft-studio` — главный, обязателен при всей разработке (правила владельца и CLAUDE.md важнее). По теме подключай другие Roblox-скиллы и называй их одной строкой: `roblox-studio-mcp`, `roblox-gui`, `roblox-building`, `roblox-lighting`, `roblox-mobile-playtest`, `roblox-playtest-qa`, `roblox-debugging-bugfix`, `anthropic-skills:roblox-game-design`, `anthropic-skills:game-art-direction`, `verification-before-completion`; у Studio MCP свои скиллы (`list_roblox_skills`, например `rbx-device-simulator-lua`).
2. `git pull` в репозитории.
3. Прочитай: `CLAUDE.md` (регламент, «БАЗА ОШИБОК И УРОКОВ», правила владельца S11 в конце), `docs/MASTER_PROMPT.md`, `docs/NEXT_CHAT_PROMPT_S10.md` (правила работы со Studio), `docs/DEVELOPMENT_TREE.md`, `docs/TOOLS.md`, `docs/REPORT_S11.txt`, `.claude/agents/trap-lab-chief.md`, `docs/QUALITY_REVIEW.md`, `docs/ART_WORKFLOW.md`, `PROJECT_GUIDE/02_STATUS.md`. Память: `claude/memory/` и авто-память.
4. Шаг 0: Studio MCP — `list_roblox_studios` (место «Лаборатория ловушек», PlaceId 135937017652181), консоль. В 3D-задачах — Blender MCP.
5. Лимит: `mcp__ccd_session_mgmt__get_usage`. Работать можно до 95–97 % пятичасового лимита, оставив запас на сохранение и push. Сообщай точный процент.

## 1. Правила работы
- Контроль: `trap-lab-chief` (в этом приложении он работает как субагент) — Чекпоинт 1 после образца, Чекпоинт 2 после логики и чистой консоли; FIX → первопричина → правка → урок в CLAUDE.md → одно повторное ревью. «Принято» — только по ответу chief, иначе «самооценка».
- Правки в Studio (источник правды). Проверенный способ S11 для кода: правишь файл в `place/` локально, переносишь в Studio точечно через `execute_luau` (сверка исходной строки перед заменой), затем `node tools/export-place.cjs --mcp "C:/Users/yarik/AppData/Local/Roblox/Versions/version-8d7a1009c17e4ff8/StudioMCP.exe"` и сравнение `git diff` до/после выгрузки (должно совпасть побайтно) + `node tools/verify-export.cjs`. Затем save_place, commit + push (разрешено).
- Тесты нового игрока: `ServerStorage.DevFreshProfile = true`, потом false. Сценарии — временный серверный Script `ZZ_*`, созданный через `execute_luau` (Server) в Play (живые модули). Удобный набор S11: `NPCPlacementService.Place(p,{slot=1,pad=1})`, `NPCRunService.Launch(p,{pad=1})`, `ManualCourseRunService.Start/Cancel`, `BuildService.Place`, `StateSync.Push`.
- Эмулятор телефона (`StudioDeviceSimulatorService`): устройство ставить в Edit ДО Play, ориентацию — после SetDevice; клики мышью по GUI в эмуляторе не работают — окно UIKit закрывать через `Visible=false`; после тестов `StopSimulationAsync`.
- Белые кадры → `tools/restore-studio-window.ps1` самому. SurfaceGui досок в Studio прорисовывается через 30–90 с — снимать позже.
- Читаемость — кадр с высоты глаза 9–10 стад. Декор — через `DecorModels.ground`.
- Правила владельца: без нейрослопа; дерево допустимо где подходит; Daily Challenges убраны навсегда (подарок за вход остаётся); киоски компактные, один продавец; обучение — только стрелки с 1–2 словами; размеры препятствий не менять; цены доната не менять без него; Saturation света выше 0.24 не поднимать.

## 2. Что сделано в S11 (2026-11-20, сохранение Team Create 242, коммиты 859f548, 86fc0d8 и итоговый)
- TECH-05: локальный линт 79 → 2 (пакет 1 — мёртвый код в 12 модулях; пакет 2 — 63 «;» в 18 модулях). Остались 2 UnknownType 'Vector3' (анализатор без определений Roblox). ACCEPT chief.
- GAME-07: стрелка обучения к кнопке HUD скрывается, если кнопку или её колонку скрыло модальное окно (`GuideController.shownOnScreen`). Шаг 5 «Rebirth» проверен на ПК, iPhone 17 Pro, iPhone 7. ACCEPT chief.
- UI-12: на тач-экранах колонка меню (NPCs/Rebirth/Donate) уменьшается `UIScale FitAboveThumb` (≥ 0.72), чтобы не лежать на джойстике (iPhone 17 Pro 0.79, iPhone 7 0.82, iPad/ПК 1.0). ACCEPT chief.
- ART-10: серия света (участок с трассой, киоск, площадь, телефон, сравнение с `Lighting.S10_Before`) — ACCEPT chief.
- Проверено в Play: NPC-забег +62 монеты, ручной забег, проход сквозь куст, «Go to shop» вдали (телепорт к прилавку), 14 звуков грузятся.
- Находка UI-13: окна Inventory и Decorations ничем не открываются (после D-031), строятся впустую.
- Доказательства: `docs/review-evidence/S11-TECH05-GAME07/`, `docs/review-evidence/S11-ART10-light/`.

## 3. Что делать дальше (по порядку, без остановок)
1. **UI-13**: спросить владельца одним вопросом, удалить ли клиентские окна Inventory и Decorations (DecorService оставить ради уже поставленного декора). Пока ждёшь — следующие пункты. При «да»: убрать контроллеры из порядка `Client.client.luau`, проверить Play на ПК и телефоне, chief.
2. **ART-04 / ART-05**: продолжить оформление по эталонам владельца сериями (NPC, препятствия, окружение участков) — сначала один образец, Чекпоинт 1, потом серия. Читать `docs/ART_WORKFLOW.md`, скилл `game-art-direction`, кадры с высоты глаза.
3. **GAME-05**: повторить вероятностные сценарии NPC (Moving Wall и др.) на других трассах и фазах стендом `ZZ_*`.
4. **UI-09 / UI-10**: всё, что можно проверить в эмуляторе (стройка, слоты, окна магазинов на iPhone 7 и iPad); геймпад — через `user_keyboard_input` нельзя, оставить NOT TESTED.
5. **ART-10 остаток**: ночь/смена времени суток (если в игре есть), иначе записать «не применяется».
6. **TECH-05 остаток**: ~90 предупреждений видны только на панели Studio View → Script Analysis; для полного счёта нужен `luau-lsp` — скачивать только по слову владельца с записью в docs/TOOLS.md.
7. NOT TESTED (требуют владельца/реальных устройств): 8 живых клиентов, переподключение, live DataStore-ошибки, реальные телефоны и тач, геймпад, покупка Robux, звук на слух.
8. В тестовой трассе владельца конвейер задом наперёд — только напомнить.
9. В конце: дерево, `PROJECT_GUIDE/02_STATUS.md`, `docs/TESTING_REPORT.md`, уроки в CLAUDE.md, память (локальная и `claude/memory/`), `docs/NEXT_CHAT_PROMPT_S13.md`, save_place, `ZZ_*` удалить, `DevFreshProfile=false`, эмулятор default, commit + push, отчёт `docs/REPORT_S12.txt`.

Начни с раздела 0, одной строкой доложи состояние (Studio, лимит, какие скиллы подключены) и сразу бери раздел 3.

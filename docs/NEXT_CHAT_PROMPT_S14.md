Продолжаем TRAP LAB — Roblox-игру «Лаборатория ловушек» (игроки строят трассы из ловушек, NPC-испытатели их проходят и приносят монеты, игроки проходят свои и чужие трассы). Репозиторий gribtolik1237-bot/roblox-geme, локально C:\Users\yarik\AppData\Local\Roblox\roblox-geme. Ты — Lead Roblox Game Architect и главный разработчик. Говори с владельцем ТОЛЬКО по-русски, коротко. Цель владельца — уровень топ-плейсов Roblox и полное отсутствие «нейрослопа».

**Работай без остановок, пока не выполнишь ВСЁ из этого промта** (решение владельца 2026-11-20): не жди слова «продолжать», не спрашивай «начинать?». Вопросы — только когда нужно настоящее решение владельца (цены, удаление его контента, скачивание, удаление функций), и в это время продолжай другие пункты. Опирайся на промты: этот, docs/MASTER_PROMPT.md и прежние docs/NEXT_CHAT_PROMPT_S*.md.

## 0. Как начать (по порядку)
1. Вызови скилл `anthropic-skills:roblox-craft-studio` (если Skill пишет Unknown skill — прочитай его файлы с диска по пути из CLAUDE.md, уроки S13) — главный, обязателен при всей разработке (правила владельца и CLAUDE.md важнее). По теме подключай другие Roblox-скиллы и называй их одной строкой: `roblox-studio-mcp`, `roblox-gui`, `roblox-building`, `roblox-lighting`, `roblox-mobile-playtest`, `roblox-playtest-qa`, `roblox-debugging-bugfix`, `anthropic-skills:roblox-game-design`, `anthropic-skills:game-art-direction`, `verification-before-completion`; у Studio MCP свои скиллы (`list_roblox_skills`, например `rbx-device-simulator-lua`).
2. `git pull` в репозитории.
3. Прочитай: `CLAUDE.md` (регламент, «БАЗА ОШИБОК И УРОКОВ», правила владельца S11 в конце), `docs/MASTER_PROMPT.md`, `docs/NEXT_CHAT_PROMPT_S10.md` (правила работы со Studio), `docs/DEVELOPMENT_TREE.md`, `docs/TOOLS.md`, `docs/REPORT_S13.txt`, `.claude/agents/trap-lab-chief.md`, `docs/QUALITY_REVIEW.md`, `docs/ART_WORKFLOW.md`, `PROJECT_GUIDE/02_STATUS.md`. Память: `claude/memory/` и авто-память.
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

## 2. Что сделано в S13 (2026-11-21, сохранение Team Create 262)
- D-039: доски лидеров топ-100 с прокруткой (BoardController в PlayerGui с Adornee на щит, сервер публикует строки атрибутами, имена пачками по 15 с повтором неудач, защита от параллельного обновления). ACCEPT chief.
- ART-05: серия препятствий проверена на настоящем курсе (Speed → Moving → Ramp → Finish), NPC 4/4; EndPad MovingPlatform сведён к deckSlab.
- ART-04: редкие NPC (Spectrum, Shadow, Glitch, Overlord, Crystal, Galaxy) — клиентский реестр эффектов в NPCController (цвет по сегментам, Highlight, частицы, пульс Neon; ≤30 Гц, ≤80 стад, частицы ≤60 стад; тело на сервере не трогается). ACCEPT chief.
- Доказательства: docs/review-evidence/S13-D039-boards, S13-ART04-npcs, S12-ART05-moving.

## 3. Что делать дальше (по порядку, без остановок)
0. **ДЕФЕКТ (найден на реальном экране в конце S13):** редкие NPC Spectrum, Overlord, Glitch, Galaxy на настоящем экране Studio СЕРЫЕ, хотя свойства Color на клиенте яркие (Shadow и Crystal цветные). Описание, гипотезы и план проверки — `docs/review-evidence/S13-ART04-npcs/manifest.md`, раздел «ДЕФЕКТ на РЕАЛЬНОМ экране», кадр REAL_SCREEN_grey_bug.jpg. Владелец разрешил доступ к окну Studio (computer-use) 2026-11-21 — проверять настоящим скриншотом. Починить первым, затем chief.
1. **ART-04 остаток**: сверка всех 21 NPC в игре (Common–Legendary не менялись — проверить, не выглядят ли они бедно рядом с новыми Mythic/Secret); Crystal близок к Frost по палитре — при необходимости чуть затемнить Frost; превью редких NPC в окне NPC и магазине уже сделаны (NPCRig.PreviewLook, S13) — проверить карточку, когда редкий NPC появится на полке NPC Shop.
2. **Реальный экран**: попросить у владельца доступ к окну Studio (computer-use) ОДИН раз, чтобы посмотреть частицы редких NPC и прокрутку досок; без доступа — оставить NOT TESTED.
3. **GAME-05**: Moving Wall в S13 — Runner 6/6; дальше Prism Spinner, Laser Labyrinth и другие вероятностные препятствия на других трассах, стенд `ZZ_*` (пример курса и запуска — TESTING_REPORT S13).
4. **ART-08**: композиция остальных участков (кадры с высоты глаза), образец → chief.
5. **ART-05 остаток**: кромки роли на SmallJump/NarrowBridge/Falling — только если на кадре без них хуже.
6. **TECH-05 остаток**: ~90 предупреждений Studio Script Analysis только на панели Studio; `luau-lsp` — по слову владельца.
7. NOT TESTED (владелец/устройства): 8 клиентов, переподключение, live DataStore-ошибки, реальные телефоны и тач (прокрутка досок пальцем), геймпад, покупка Robux, звук на слух, ночь.
8. Напомнить: в тестовой трассе владельца конвейер задом наперёд.
9. В конце: дерево, `PROJECT_GUIDE/02_STATUS.md`, `docs/TESTING_REPORT.md`, уроки в CLAUDE.md, память, `docs/NEXT_CHAT_PROMPT_S15.md`, save_place, `ZZ_*` удалить, `DevFreshProfile=false`, эмулятор default, commit + push, отчёт `docs/REPORT_S14.txt`.

Начни с раздела 0, одной строкой доложи состояние (Studio, лимит, какие скиллы подключены) и сразу бери раздел 3.

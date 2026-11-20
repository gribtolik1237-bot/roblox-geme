Продолжаем TRAP LAB — Roblox-игру «Лаборатория ловушек» (игроки строят трассы из ловушек, NPC-испытатели их проходят и приносят монеты, игроки проходят свои и чужие трассы). Репозиторий gribtolik1237-bot/roblox-geme, локально C:\Users\yarik\AppData\Local\Roblox\roblox-geme. Ты — Lead Roblox Game Architect и главный разработчик. Отвечай по-русски, коротко. Цель владельца — уровень топ-плейсов Roblox и полное отсутствие «нейрослопа». Работай автономно и без остановок, пока есть что делать и не упёрся в лимит; вопросы задавай только когда нужно решение владельца.

## 0. Как начать (по порядку)
1. Вызови скилл `anthropic-skills:roblox-craft-studio` — обязательно по решению владельца, используй его при всей разработке (правила владельца и CLAUDE.md важнее). По теме подключай и другие: `anthropic-skills:roblox-game-design`, `anthropic-skills:game-art-direction`, `roblox-building`, `roblox-gui`, `roblox-studio-mcp`, `verification-before-completion`; у Studio MCP есть свои скиллы (`list_roblox_skills`).
2. `git pull` в репозитории.
3. Прочитай: `CLAUDE.md` (регламент + «БАЗА ОШИБОК И УРОКОВ», сверяйся перед каждой задачей), `docs/MASTER_PROMPT.md` (полный исходный промт владельца: 10 стандартов, цикл начальника; таблица сверху — где решения владельца новее), `docs/NEXT_CHAT_PROMPT_S10.md` (все правила владельца и уроки работы со Studio), `docs/DEVELOPMENT_TREE.md` (узлы ART-11, UI-11, GAME-07, ART-10), `docs/TOOLS.md` (скачанные инструменты), `docs/REPORT_S10.txt` (итог прошлой сессии), `.claude/agents/trap-lab-chief.md`, `docs/QUALITY_REVIEW.md`, `docs/ART_WORKFLOW.md`. Память: `claude/memory/` и авто-память.
4. Шаг 0: Studio MCP — `list_roblox_studios` (место «Лаборатория ловушек», PlaceId 135937017652181), консоль. В 3D-задачах — Blender MCP (сцена, единицы, объекты).
5. Лимит: проверяй `mcp__ccd_session_mgmt__get_usage`. Владелец разрешил работать до 95–97 % пятичасового лимита, оставив запас на сохранение и push. Сообщай точный процент, не на глаз.

## 1. Правила работы (главное)
- Контроль качества: `trap-lab-chief` — Чекпоинт 1 после образца, Чекпоинт 2 после логики и чистой консоли. FIX → первопричина → правка → урок в CLAUDE.md → одно повторное ревью. «Принято» в дереве — только по реальному ответу chief, иначе «самооценка».
- Правки делаются в Studio (источник правды), затем `node tools/export-place.cjs --mcp "C:/Users/yarik/AppData/Local/Roblox/Versions/version-8d7a1009c17e4ff8/StudioMCP.exe"` + `node tools/verify-export.cjs`, затем commit + push (разрешено). После обновления Studio путь к StudioMCP.exe проверить.
- Тесты нового игрока: `ServerStorage.DevFreshProfile = true`, потом false. PLAY-забег запускается временным серверным Script `ZZ_*` с `ManualCourseRunService.Start` (нажатие E недоступно). `ZZ_*` удалять, эмулятор возвращать (`StopSimulationAsync`).
- Белые кадры `screen_capture` → сам запусти `tools/restore-studio-window.ps1`, владельца не проси.
- Читаемость и перекрытие проверять кадром с высоты глаза игрока (9–10 стад), не сверху. Декор сажать через `DecorModels.ground` (PivotTo ставит центром габарита).
- Загрузка ассетов: `open_cloud_invoke` из одобренной папки `roblox-geme\assets\models` (владелец одобрил). creator userId — из `search_asset` (context).
- Правила владельца: без нейрослопа; дерево допустимо где подходит; Daily Challenges убраны навсегда (подарок за вход остаётся); киоски компактные, один продавец; обучение — только стрелки с 1–2 словами; размеры препятствий не менять; цены доната не менять без него.

## 2. Что сделано в S10 (2026-11-19, сохранение Team Create 235, коммиты до ef36078)
- Торговая площадь (`ServerStorage/WorldRecipes/MarketDress`): плитка со studs, бордюр, бирюзовые диски у киосков, медальон, фонари из Parts, клумбы, кусты. Киоски повёрнуты боком лицом к центру (`ShopRestyle.Definitions`: z=∓58, yaw 0/π), чтобы не закрывать доски. Доски лидеров: `ReplicatedStorage/Shared/BoardSkin`. Принято chief.
- Декор участков: круглые деревья, сосны (3 шара + светящийся кончик), куст из Blender (asset 93309155255799, шаблон `ReplicatedStorage.Assets.RoundBush`, коллизии выключены), круглые цветы; всё посажено на землю. 52 дерева на гребне стены тоже круглые, стоят на шапке стены. Принято chief (кроме гребня — самооценка после правки).
- Окна магазинов: товары по цене, «Go to shop» скрыта у прилавка, в NPC Shop «Runners at once: N (Rebirth for more)». Принято chief.
- Новичок: Daily Gift показывается после первого PLAY; шаг 5 обучения — стрелка «Rebirth» при 3 000 монет; первый порог Rebirth снижен 5 000 → 3 000 (решение владельца). Образец света принят: ColorCorrection Contrast 0.12, Saturation 0.24 (выше не поднимать), Atmosphere Haze 0.4; откат в атрибуте `Lighting.S10_Before`.
- Скачан `luau-analyze` 0.747 (`C:\Users\yarik\tools\luau\0.747\`), линт `node tools/luau-lint.cjs` → 79 замечаний (SameLineStatement 59, LocalUnused 11, ImportUnused 3, FunctionUnused 2, ImplicitReturn 2, UnknownType 2). Подробно `docs/TOOLS.md`.
- Кадры и манифесты: `docs/review-evidence/ART-04-plaza/`.

## 3. Что делать дальше (по порядку)
1. **TECH-05 (владелец: «когда напишу продолжать — продолжай»)**: `node tools/luau-lint.cjs`, исправить LocalUnused, ImportUnused, FunctionUnused, ImplicitReturn, по возможности SameLineStatement — пакетами, в Studio, Play-проверка, выгрузка, коммит на пакет. Остальные ~90 предупреждений Studio видны только на панели View → Script Analysis (MCP её не читает); для полного совпадения нужен `luau-lsp` — скачивать только по слову владельца и с записью в docs/TOOLS.md.
2. Кадр стрелки «Rebirth» с нормальным миром (чистый профиль) и проход аватара сквозь куст — недопроверено.
3. Свет: проверить на телефоне и в других сценах, серию по сценам — через chief.
4. Окна Inventory и Decorations: осмотреть (у них нет кнопок в меню, найти, откуда открываются).
5. NOT TESTED: 8 клиентов, переподключение, live DataStore, реальные телефоны/геймпад, покупка Robux, звук, «Go to shop» вдали от киоска.
6. В тестовой трассе владельца конвейер задом наперёд — только напомнить.
7. В конце: дерево, `PROJECT_GUIDE/02_STATUS.md`, `docs/TESTING_REPORT.md`, память, `docs/NEXT_CHAT_PROMPT_S12.md`, save_place, `ZZ_*` удалить, `DevFreshProfile=false`, эмулятор default, commit + push, отчёт файлом `.txt` в `docs/`.

Начни с раздела 0, затем коротко доложи владельцу состояние (Studio, лимит) и, если он написал «продолжать», сразу бери пункт 1 раздела 3.

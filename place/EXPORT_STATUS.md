# Экспорт скриптов TRAP LAB

2026-11-22 (Codex 3). Сохранение Team Create 281, `game.PlaceVersion` в редакторе 272. Выгружены и сверены 75 скриптов места 135937017652181. Изменены `NPCBrainService`, `ObstacleTraversalService`, `BoardController`, `UIKit` и `BuildController`. [Тесты и кадры](../docs/TESTING_REPORT.md).

2026-11-21 (Codex 2). Сохранение Team Create 270. Выгружены 75 скриптов открытого места, `game.PlaceVersion` в редакторе 264. В `NPCController` скорректировано положение точки выхода клиентских частиц и подключена штатная текстура Glitch. [Тесты и кадры](../docs/TESTING_REPORT.md).

2026-11-21 (Codex 1). Сохранение Team Create 268, `game.PlaceVersion` в открытом редакторе 264. Экспорт 75/75 после изменения клиентского материала четырёх R15 NPC в `NPCController`. Игровые проверки и открытая визуальная приёмка в [отчёте Codex](../docs/REPORT_CHATGPT_1.txt) и [TESTING_REPORT](../docs/TESTING_REPORT.md).

2026-11-21 (S13). Выгружены и сверены 75 из 75 скриптов открытого места 135937017652181 из Studio (сохранение Team Create 264; PlaceVersion 252). D-039: доски лидеров топ-100 с прокруткой (новый BoardController, BoardSkin.buildScroll, HallService публикует строки, LeaderboardService: имена пачками, защита от параллельных обновлений). ObstacleModels: EndPad MovingPlatform через deckSlab. NPCController: реестр клиентских эффектов редких NPC (Spectrum, Shadow, Glitch, Overlord, Crystal, Galaxy) и NPCRig.PreviewLook для превью. Каждая правка сделана в Studio, повторная выгрузка совпала с локальной побайтно. Контрольные суммы в [EXPORT_MANIFEST.json](EXPORT_MANIFEST.json).

Добавлены `BoardSkin` (оформление досок лидеров) и рецепт `MarketDress` (оформление торговой площади). Добавлен `PromenadeController`. Обновлены физические ленты и разметка, геометрия участков, щиты, HUD, мобильная стройка, планирование NPC и защита при загрузке трассы и сохранении профиля. Геометрия сохранена в месте Roblox. Проверки выполнены отдельно в Play и описаны в [TESTING_REPORT.md](../docs/TESTING_REPORT.md).

Повторная выгрузка из корня репозитория

```powershell
node tools/export-place.cjs --mcp "<путь к установленному StudioMCP.exe>"
node tools/verify-export.cjs
```

Способ напрямую читает официальный MCP. HTTP-приёмник и изменение HTTP-allowlist для него не нужны. Требуется ровно одна подключённая Edit-сессия этого PlaceId. Рабочий exe при проверке находился в Versions/version-8d7a1009c17e4ff8. После обновления Studio проверь путь заново.

При изменении состава/кода во время чтения экспорт завершится ошибкой до перезаписи файлов. После стабилизации повтори его. Перед выгрузкой сохрани ещё не перенесённые в Studio локальные правки. После выгрузки проверь manifest и git diff, обнови статус и дерево. Файлы, исчезнувшие из Studio, проверяются отдельно перед удалением из репозитория.

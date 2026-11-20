# Локальные инструменты, скачанные для проекта

Обновлено 2026-11-19 (Claude, по просьбе владельца). Бинарники в репозиторий не кладутся (он публичный), лежат на ПК владельца вне репозитория.

## luau-analyze (анализатор Luau)
- **Скачано:** релиз 0.747 с https://github.com/luau-lang/luau/releases/tag/0.747, файл `luau-windows.zip` (3 271 719 байт, SHA-256 `16bbd26575e9a6a3ecd2bd5fc772a81f3232520b56a40a86f2b47fec576d7cc7`).
- **Где лежит:** `C:\Users\yarik\tools\luau\0.747\` (`luau-analyze.exe`, `luau-ast.exe`, `luau-compile.exe`, `luau.exe`).
- **Описание типов Roblox:** `C:\Users\yarik\tools\luau\0.747\globalTypes.None.d.luau` (713 040 байт, SHA-256 `8aba2dc66d16a620e5dd286129c7cbe45608a5690befa2310d0b8f5b917dc7d3`, из https://github.com/JohnnyMorganz/luau-lsp, папка scripts). Эта сборка анализатора не принимает файл определений (нет ключа `--defs`), поэтому файл пока не используется.
- **Запуск:** `node tools/luau-lint.cjs` из корня репозитория. Скрипт гоняет анализатор по `place/**/*.luau`, отбрасывает ошибки типов и пишет список замечаний линтера в `work/luau-lint.txt` с подсчётом по правилам.
- **Результат 2026-11-19:** 76 файлов, 79 замечаний линтера: SameLineStatement 59, LocalUnused 11, ImportUnused 3, FunctionUnused 2, ImplicitReturn 2, UnknownType 2.
- **Результат 2026-11-20 (S11):** после двух пакетов TECH-05 — 2 замечания, оба UnknownType 'Vector3' (нет определений Roblox, не ошибка кода).
- **Ограничение:** без определений Roblox анализатор не знает `game`, `Vector3`, `Enum`, поэтому полный счёт Studio Script Analysis (169 предупреждений на 2026-11-18) этим не воспроизвести. Для полного совпадения нужен `luau-lsp analyze --definitions=...` (не скачан, спросить владельца).
- Studio MCP не отдаёт диагностику Script Analysis, поэтому остальные 90 предупреждений Studio берутся только с панели Studio (View → Script Analysis), которую может скопировать владелец.

## Скрипты репозитория
- `tools/export-place.cjs`, `tools/verify-export.cjs`: выгрузка скриптов из Studio в `place/` (нужен StudioMCP.exe, путь см. `place/EXPORT_STATUS.md`).
- `tools/restore-studio-window.ps1`: развернуть окно Studio при белых кадрах.
- `tools/luau-lint.cjs`: локальный линт (см. выше).

## Правила
- Ничего нового не скачивать без слова владельца и записи сюда: имя файла, источник, размер, SHA-256, куда положено.
- Исправления по линту вносить в Studio (источник правды) и выгружать, правка файлов в `place/` в игру не попадает. Каждый пакет проверять в Play и отдельным коммитом.
- Когда владелец пишет «продолжать», продолжать TECH-05: `node tools/luau-lint.cjs`, исправить LocalUnused, ImportUnused, FunctionUnused, ImplicitReturn и по возможности SameLineStatement, повторить линт, Play, выгрузка, коммит.

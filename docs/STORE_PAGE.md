# TRAP LAB — страница игры (публикация)

> Текст описывает ЦЕЛЕВОЙ набор механик из ТЗ. Пока игра не готова — публикуй с приватным доступом (Private)
> и открывай для всех только после финальных тестов. Не обещай на странице то, чего ещё нет.

## Название (лимит Roblox: 50 символов)

| Вариант | Комментарий |
|---|---|
| **TRAP LAB** | основной: коротко, запоминается, совпадает с ТЗ |
| TRAP LAB: Build & Test Obby | запасной, если нужно больше «поискового» смысла |

Не добавляй в название [NEW], эмодзи-спам и слова про Robux — режется модерацией и портит доверие.

## Описание EN (лимит Roblox: 1000 символов) — вставляй как есть

```text
Build a trap-filled obstacle course, buy quirky Roblox-style testers and watch them try to survive it!

BUILD: Collect obstacles in 7 rarities - spinning bars, swinging hammers, lava, lasers, bounce pads and more. Snap them onto your plot and shape a course that is tough but fair.

TEST: Buy NPC testers (Noob, Ninja, Knight, Glitch and 17 more) with different speed, jump and balance. Put one on your start pad and watch it run, stumble and fall for real. Every checkpoint it reaches pays you Coins!

PLAY: Hit the PLAY sign next to any course to run it yourself with your own avatar - yours or a friend's.

REBIRTH: Grow your plot, unlock new traps and NPCs, and keep everything you built.

Shops refresh every 5 minutes. Daily Challenges give 2x-3x Coin bonuses. Leaderboards and course ratings show the best builders.

Build a trap. See who survives the TRAP LAB!
```

## Описание RU (для справки / локализации)

```text
Строй полосу препятствий с ловушками, покупай забавных NPC-испытателей в стиле Roblox и смотри, смогут ли они её пройти!

СТРОЙ: Собирай препятствия 7 редкостей - вращающиеся перекладины, молоты, лава, лазеры, батуты и многое другое. Ставь их на свой участок и делай трассу сложной, но честной.

ИСПЫТЫВАЙ: Покупай NPC-испытателей (Noob, Ninja, Knight, Glitch и ещё 17) с разной скоростью, прыжком и балансом. Поставь одного на стартовую площадку и смотри, как он бежит, спотыкается и падает по-настоящему. За каждую достигнутую контрольную точку ты получаешь Coins!

ИГРАЙ: Нажми PLAY на табличке у любой трассы и пройди её сам своим аватаром - на своей или на чужой.

REBIRTH: Расширяй участок, открывай новые ловушки и NPC и сохраняй всё, что построил.

Магазины обновляются каждые 5 минут. Ежедневные испытания дают бонус Coins x2-x3. Таблицы лидеров и оценки трасс покажут лучших строителей.

Построй ловушку. Узнай, кто выживет в TRAP LAB!
```

## Настройки при публикации

- Genre: **Obby & Platformer** (запасной вариант — All genres)
- Devices: Computer, Phone, Tablet (Console включить только после теста геймпада)
- Access: **Private** до финальных тестов
- Max Players: **8** (в игре 8 участков)
- Avatar: R15 (NPC-риги в игре тоже R15)
- Опросник возрастных ограничений заполняет владелец аккаунта (в игре нет жестоких деталей: падение = «puff»-исчезновение)

## Иконка и тумбнейлы (я отрисую их в Blender, когда игра будет готова)

- **Иконка 512x512**: крупный план забавного NPC-«нуба», зависшего в воздухе рядом с красным молотом; фон — яркий лабораторный голубой; читаемо на размере 64 px; без текста или с коротким TRAP LAB.
- **Тумбнейлы 1920x1080** (3-5 шт.): (1) построенная трасса сверху с несколькими NPC на ней, (2) NPC падает у лавы с подписью «+Coins», (3) табличка PLAY и игрок на старте, (4) магазин NPC с редкостями, (5) Rebirth/расширение участка.
- Показывать только реальный геймплей, без вводящих в заблуждение «Robux»-картинок.

## Риски обнаружения (по убыванию влияния на CTR/удержание)

1. Пустое/сырое первое впечатление: до публичного релиза нужен готовый старт (участок + 1 NPC + первая покупка за 30 секунд).
2. Иконка/тумбнейл не совпадают с первым геймплеем — делать их только по реальным скриншотам.
3. Названия-архетипы (Bacon, Noob, Guest) — это отсылки; модели оригинальные, не копируй UGC/бренды.
4. Монетизация: никаких обязательных Robux-покупок; game pass'ы добавляем только после создания настоящих продуктов.
5. Мобильный UI: проверить в Device Emulator до открытия доступа.

## Что нужно сделать тебе (3 минуты)

1. Studio: **File -> Publish to Roblox As...** -> Name `TRAP LAB`, вставь описание EN, Genre `Obby & Platformer`, Creator = твой аккаунт, **Access = Private** -> Create.
2. **Home -> Game Settings -> Security**: включи **Enable Studio Access to API Services** (нужно, чтобы DataStore работал в Studio).
3. **Game Settings -> Players -> Maximum Players = 8.**
4. Напиши мне «опубликовал» — я проверю `PlaceId`, DataStore и сохранение места через MCP, и продолжу.

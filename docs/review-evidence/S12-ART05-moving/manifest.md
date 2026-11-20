# ART-05 (S12): MovingPlatform — образец доработки серии препятствий

- Дата 2026-11-20, PlaceId 135937017652181, Team Create после сохранения 246 (правка ещё не сохранена в момент кадров).
- Карточка: что — Moving Platform (Basic, Uncommon), торцевые площадки 10x5 и паром 8x8 на рельсах. Референс — эталоны владельца в `C:\Users\yarik\AppData\Local\Roblox\TRAP_LAB\references_s5\` и `docs/ART_DIRECTION.md` (§«Эталоны», п.4: «на КАЖДОЙ плоскости микрорельеф — studs, фаска; нет плоских одноцветных плит»; §«Сессия 6»: настил по категории, кромка = цвет редкости). Габариты не менять (правило владельца, физика NPC).
- Способ: Studio Parts (как весь набор `ObstacleModels`), только материал/поверхность и декоративные детали без коллизии.

## Найдено на витрине всех 27 препятствий
`lineup_overview.jpg`, `before_lineup_moving_center.jpg` (передний план — торцевая площадка MovingPlatform): торцевые площадки и верх парома — гладкий SmoothPlastic одним жёлтым тоном, без studs и без кромок редкости, хотя соседние BasicPlatform/RotatingBar и все `deckSlab` — studded Plastic с цветными кромками. Выглядит как плоская заглушка.

## Правка (`moving.diff`)
- `EndPad`: Plastic + TopSurface Studs, `CustomPhysicalProperties(0.7, 0.2, 0.5, 1, 1)` — трение/плотность/упругость как у SmoothPlastic (проверено в Play: friction 0.20, density 0.70, elasticity 0.50).
- `EndPadTrim` x2 на площадку: кромки 0.8x0.3 по краям (как в `deckSlab`), без коллизии/запросов/касаний; цвет перекрашивается в цвет редкости общим циклом `Models.build` (имя содержит «Trim»).
- `FerryTop` (уже без коллизии): Plastic + Studs.
- Размеры, коллизионные детали и движение (`FerryModel`, ObstacleRuntime) не менялись.

## Проверки
- require клона и сборка всех 27 моделей — 27/27 без ошибок; линт 2 (UnknownType); выгрузка 74/74, Studio = локальная правка побайтно.
- Кадры после: `after_pair.jpg`, `after_close.jpg` — слева RampUp, в центре MovingPlatform, справа BasicPlatform (принятый эталон настила). Площадки читаются как тот же studded-пластик, синие кромки Uncommon.
- NOT TESTED: кадр в реальном курсе игрока и движение парома глазами (коллизии не менялись).
- Кандидат следующего шага серии: RampUp — гладкий склон без рельефа (виден слева).

## Раунд 1: ACCEPT chief (этап «настил»). Таблица 27 препятствий (по коду, require клона, Team Create 247)
Колонки: id | категория | редкость | доля studs среди крупных (≥16 кв. стад) коллизионных поверхностей (DeckBase под настилом тоже считается, поэтому ~50 % = настил со studs) | число кромок Trim | гладкие крупные детали.
```
BasicPlatform|Basic|Common|studs 50%|trims 2|DeckBase
SmallJumpPlatform|Basic|Common|— (круглая)|trims 0|
NarrowBridge|Basic|Common|— (узкие доски со studs)|trims 0|
RampUp|Basic|Uncommon|studs 33%|trims 2|Slope:SmoothPlastic  <- следующий шаг
MovingPlatform|Basic|Uncommon|studs 37%|trims 4|Ferry:SmoothPlastic (бок парома; верх studded)
RotatingBar|Moving|Uncommon|48%|2|
LavaFloor|Dangerous|Common|24%|4|Basin:CrackedLava (лава — нарочно)
FallingPlatform|Dangerous|Uncommon|100%|0|
SpeedPlatform|Special|Uncommon|0%|0|Deck:SmoothPlastic  <- кандидат
FinishPad|Special|Common|0%|0|(шашечки — нарочно)
ConveyorBelt / ReverseConveyor|Special|Uncommon|0%|0|Belt:SmoothPlastic (лента — логично гладкая; нет кромок)  <- кандидат на кромки
DisappearingPlatform|Special|Rare|0%|0|T1-3:Glass (нарочно)
BouncePad|Special|Rare|44%|4|HighDeck:SmoothPlastic  <- кандидат
InvisiblePlatform|Special|Epic|—|0|(невидимая — нарочно)
TeleportPlatform, RotatingPlatform, SlidingBlock, MovingWall, SwingingHammer, MovingLaser, SpikePlatform, ElectricFloor, FireTrap, HammerGauntlet, LaserLabyrinth, PrismSpinner — настил studded, 2–4 кромки.
```
Порядок серии: RampUp (накладки со studs поверх клина без коллизии, угол atan(4/12)≈18.4°) → SpeedPlatform → BouncePad HighDeck → кромки редкости на Conveyor/Speed/SmallJump/NarrowBridge/Falling. P3 chief: свести EndPad к общей функции с deckSlab при следующей правке серии.

## Раунд 2: RampUp по рецепту chief (`ramp.diff`, `ramp_after.jpg`; «до» — `after_close.jpg`, слева)
- Клин `Slope` не тронут (размер, материал, коллизия). Поверх склона: `SlopeDeck` 8x0.2x12.65 Plastic+Studs и `SlopeTrim` x2 (0.8x0.3) вдоль склона, угол atan2(4,12)=18.4°, плита на 0.03 над гранью; все CanCollide/CanQuery/CanTouch=false (лучи NPC и касания не видят).
- Цвет кромок — тот же, что у кромок основания рампы (общая система roleAccents/редкости), так у всей модели одна кромка.
- Проверки: 27/27 моделей собираются; аватар (x2 в лобби) прошёл подъём MoveTo от низа до верха за 1.0 с; выгрузка 74/74, Studio = локальная правка; линт 2.
- NOT TESTED: NPC по рампе (в стартовой трассе рампы нет; коллизия и лучи не менялись).

## Раунд 2: ACCEPT chief (RampUp)
P3 (поправлено): кромки красит `roleAccents` по РОЛИ поведения (безопасное — зелёный, движущееся — синий), не по редкости. P3 (сделано S12, сохранение 251: удалена как мусор): `Hazard1` у RampUp (y 2.05, z 4.6) спрятан внутри клина — убрать или положить на склон при следующей правке RampUp. Приём «плита Plastic+Studs без коллизии поверх склона» — для всех клиновых препятствий.

## Раунд 3: серия тем же приёмом (`speed_bounce.diff`, `speed_bounce_after.jpg`; «до» — `lineup_overview.jpg`/`before_lineup_moving_center.jpg`, где Speed — тёмная гладкая плита)
- SpeedPlatform: Deck — Plastic+Studs, трение 0.2 (CustomPhysicalProperties), цвет тот же; добавлены DeckTrim x2 вдоль краёв без коллизии (цвет роли). Шевроны не тронуты.
- BouncePad: HighDeck — Plastic+Studs, трение 0.2; размеры не менялись.
- Ленты Conveyor оставлены гладкими (резина; цветные неоновые бортики Guard уже есть).
- Проверки: 27/27 моделей; ObstacleRuntime.Register(SpeedPlatform) — при ходьбе по настилу WalkSpeed поднимается до 28 (= boost в конфиге), трение настила 0.20; выгрузка 74/74, Studio = локальная правка.
- NOT TESTED: прыжок с BouncePad на HighDeck глазами (коллизия не менялась), NPC по Speed/Bounce.

## Раунд 3: ACCEPT chief. P3 на следующий проход
- Studs на тёмном настиле SpeedPlatform (rgb 66,48,44) почти не читаются — кадр вплотную с высоты глаза; если не видно, поднять яркость настила на 10–15 % (физику не трогать).
- HighDeck BouncePad: кадр с верхней точки прыжка (studs сверху).
- HighTrimL/HighTrimR остаются неоновыми зелёными: имя содержит Trim, но roleAccents перекрашивает их по роли — проверить на кадре и записать решение.
- P3 закрыты (самооценка по кадрам): `speed_close.jpg` — studs на тёмном настиле читаются вблизи с высоты глаза, осветление не нужно; `highdeck_top.jpg` — верх HighDeck со studs; HighTrimL/R после roleAccents синие SmoothPlastic (лог Play: Color 0.23,0.56,1, SmoothPlastic), то есть следуют цвету роли — правка не нужна.

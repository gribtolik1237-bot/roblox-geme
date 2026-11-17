# GAME DESIGN DOCUMENT — TRAP LAB

Полная спецификация: Desktop `промт роблокс игры.txt`. Здесь — выжимка рабочих правил.

## Две независимые системы прохождения
1. **NPC-испытания**: инвентарь/слот -> размещение на NPC-стартовой площадке своего участка -> отдельное действие «запуск» -> автономное прохождение -> Coins за подтверждённые этапы -> падение/финиш -> NPC исчезает с анимацией и остаётся в коллекции.
2. **Ручное прохождение**: табличка у трассы с **одной** кнопкой PLAY, всегда запускает аватар игрока (своя и чужая трасса). Никакого выбора NPC на табличке.

## Участок
8 участков (клетка 260x420). Старт-зона фиксирована у края, дальше зона строительства; растёт вперёд и в стороны при Rebirth, старые постройки не двигаются. 10 NPC-площадок у старта (доступно столько, какой лимит по Rebirth).

## Строительство
Сетка 4 (тонко — 1), уровни по 2 стад. по высоте, поворот на 90°, призрак (зелёный/красный), перенос/удаление/выбор. Сервер проверяет владельца, владение предметом, границы, пересечения, запретные зоны, лимит. Есть один финиш (бесплатный предмет FinishPad).

## Трасса
Граф по точкам entry/exit (D-006). Статусы: **Player-playable** и **NPC-playable** раздельно. Сложность: Easy/Normal/Hard/Very Hard/Extreme (типы препятствий, этапы, расстояния, длительность).

## Каталог препятствий (план; финальный список в Configs.Obstacles)
Basic: Basic Platform, Small Jump Platform, Narrow Bridge, Ramp, Rotating Platform, Moving Platform.
Moving: Sliding Block, Rotating Bar, Swinging Hammer, Moving Wall, Moving Laser.
Dangerous: Lava Floor, Spike Platform, Falling Platform, Electric Floor, Fire Trap.
Special: Disappearing Platform, Speed Platform, Bounce Pad, Conveyor Belt, Invisible Platform (NPC-incompatible), Teleport Platform (NPC-incompatible), Finish Pad.
Premium (комбинации с отдельной механикой): гаунтлеты/спиннеры высших редкостей.
Декорации — отдельный слой (D-007).

## NPC (21): по 3 на редкость
Common: Bacon, Noob, Starter. Uncommon: Guest, Builder, Runner. Rare: Ninja, Astronaut, Knight. Epic: Cyber, Frost, Blaze. Legendary: Golden, Titan, Angel. Mythic: Shadow, Galaxy, Crystal. Secret: Glitch, Overlord, Spectrum.
Характеристики 1..10: Speed, Jump, Balance, Recovery, Control — с компромиссами, редкость не гарантирует победу.

## Экономика
Coins; Lifetime Earned Coins для Rebirth; награды раздельные для ручного и NPC потоков; идемпотентные выплаты; затухание повторов. Подробно: BALANCE.md.

## Rebirth
Не сбрасывает Coins, постройки, инвентарь, NPC, слоты, косметику. Растут участок, лимит объектов, лимит NPC, открываются предметы/NPC.

## Дополнительно
Daily Challenges (Easy x2/10 мин, Hard x2/20 мин, Super Hard x3/15 мин), TOP MONEY / TOP REBIRTHS / TOP OBBY, рейтинг трасс (5 критериев), косметика участка.

# S10 раунд 4: правки после прогона новичка и образец света (ART-10)

- Daily Gift: `LoginRewardController` показывает окно только когда игрок уже нажимал PLAY (`stats.manualRuns > 0`) или это ветеран (`lifetime > 1500`). Причина: окно закрывало первый «ага» после забега NPC.
- NPC Shop: в заголовке окна «Runners at once: N (Rebirth for more)»; текст «Rebirth for more» только пока N меньше числа площадок. Кадр `s10_npc_shop_runners_hint.jpg` (профиль владельца, Rebirth 10: «Runners at once: 10»).
- Образец света (ART-10), яркость не менялась: ColorCorrection Contrast 0.08→0.12, Saturation 0.18→0.24, Atmosphere Haze 0.30→0.40. Кадры до/после: `s10_light_before_*`, `s10_light_after_*` (одинаковые камеры). Откат: те же три значения в атрибуте Lighting.S10_Before.
- Подтверждено в Play на чистом профиле: после первого забега NPC Daily Gift не открывается (canClaim=true, окно скрыто), после первого PLAY открывается. Проверено: Play, консоль чистая, заголовок читается (414 px), «Go to shop» скрыта у прилавка. NOT TESTED: появление Daily Gift у нового игрока после первого PLAY (профиль в Studio не новичок), свет на телефоне.

## Дополнение к раунду 4 (по NEEDS_EVIDENCE chief)
Старый кадр подсказки снят до последней правки, заменён. Новые кадры после правки, Play: `s10_npc_shop_runners_R0_with_hint.jpg` (чистый профиль, Rebirth 0: «Runners at once: 1 (Rebirth for more)», товары по цене 350, 400, 460, дальше замки) и `s10_npc_shop_runners_R10_no_hint.jpg` (Rebirth 10 MAX: «Runners at once: 10», без хвоста). Консоль чистая, DevFreshProfile возвращён в false.

## Раунд 5 (итоговые изменения, окно Studio снова рисует сцену)
Для проверки: круглые сосны (`s10_round_pine_grounded.jpg`), 52 круглых дерева на гребне стены (`s10_final_plaza_cliff_trees.jpg`, `s10_final_plot_spawn_cliff_trees.jpg`), шаг 5 обучения со стрелкой Rebirth (`s10_guide_rebirth_arrow.jpg`, на кадре мир не отрисован из-за сбоя окна, видны только интерфейс и стрелка), куст-меш (`s10_bush_mesh_plaza.jpg`), первый порог Rebirth 3000 (`Balance.RebirthThreshold`, решение владельца), HallService без неиспользуемых переменных.

## Раунд 5, исправления по FIX chief
- P2 деревья гребня: `PlotService` (рецепт) и 52 запечённых `CliffTree` теперь стоят на шапке стены (`DecorModels.ground(m, ROW*2+8)`, ошибка основания 0.000), масштаб снижен (рецепт 1.1–1.5, запечённые ×0.45, высота ~16–20). Кадр `s10_cliff_trees_seated_on_cap.jpg`. Самооценка, повторного ревью не было.
- Куст-меш, коллизии: шаблон `ReplicatedStorage.Assets.RoundBush`, все 4 детали Anchored=true, CanCollide=false, CanQuery=false, CanTouch=false, CollisionFidelity=Box; среди всех размещённых кустов (участки и площадь) 0 деталей с включёнными коллизиями. Чистый кадр куста и клумб в участке: `s10_bush_mesh_plot_closeup.jpg`.
- NOT TESTED: кадр стрелки Rebirth с нормальным миром (нужен ещё один прогон чистого профиля), проход аватара сквозь куст живым персонажем.

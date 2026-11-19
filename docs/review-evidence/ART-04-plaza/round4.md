# S10 раунд 4: правки после прогона новичка и образец света (ART-10)

- Daily Gift: `LoginRewardController` показывает окно только когда игрок уже нажимал PLAY (`stats.manualRuns > 0`) или это ветеран (`lifetime > 1500`). Причина: окно закрывало первый «ага» после забега NPC.
- NPC Shop: в заголовке окна «Runners at once: N (Rebirth for more)»; текст «Rebirth for more» только пока N меньше числа площадок. Кадр `s10_npc_shop_runners_hint.jpg` (профиль владельца, Rebirth 10: «Runners at once: 10»).
- Образец света (ART-10), яркость не менялась: ColorCorrection Contrast 0.08→0.12, Saturation 0.18→0.24, Atmosphere Haze 0.30→0.40. Кадры до/после: `s10_light_before_*`, `s10_light_after_*` (одинаковые камеры). Откат: те же три значения в атрибуте Lighting.S10_Before.
- Подтверждено в Play на чистом профиле: после первого забега NPC Daily Gift не открывается (canClaim=true, окно скрыто), после первого PLAY открывается. Проверено: Play, консоль чистая, заголовок читается (414 px), «Go to shop» скрыта у прилавка. NOT TESTED: появление Daily Gift у нового игрока после первого PLAY (профиль в Studio не новичок), свет на телефоне.

## Дополнение к раунду 4 (по NEEDS_EVIDENCE chief)
Старый кадр подсказки снят до последней правки, заменён. Новые кадры после правки, Play: `s10_npc_shop_runners_R0_with_hint.jpg` (чистый профиль, Rebirth 0: «Runners at once: 1 (Rebirth for more)», товары по цене 350, 400, 460, дальше замки) и `s10_npc_shop_runners_R10_no_hint.jpg` (Rebirth 10 MAX: «Runners at once: 10», без хвоста). Консоль чистая, DevFreshProfile возвращён в false.

# ASSET REGISTRY

Все модели создаются оригинальными (процедурные Parts в Luau или Blender). Сторонние ассеты не используются без записи здесь.

| Ассет | Тип | Источник | Лицензия | Статус |
|---|---|---|---|---|
| Модели препятствий | Parts (Luau) | собственные | — | TODO |
| NPC-риги (21) + аксессуары | Parts + HumanoidDescription | собственные | — | TODO |
| Анимации idle/walk/run/jump/fall | Roblox default R15 animation IDs | Roblox (стандартные) | Roblox Terms | TODO (проверить загрузку в игре) |
| Анимации stumble/recover/fail/despawn | процедурные (Motor6D tween) | собственные | — | TODO |
| Иконки магазина, иконка игры, тумбнейлы | Blender-рендеры | собственные | — | TODO |
| Звуки | — | подбираются только из разрешённых источников | — | TODO |

## Обновление 2026-11-16
| Ассет | Тип | Источник | Лицензия | Статус |
|---|---|---|---|---|
| Иконка игры 512x512 | PNG, Blender 5.2 (EEVEE) | `TRAP_LAB\assets\make_icon.py` -> `icon_512.png`, исходник `trap_lab_icon.blend` | собственная | загружена: `rbxassetid://106113196508515`; назначить иконкой места должен владелец (Creator Hub) |
| Обложка 1920x1080 | PNG, Blender 5.2 | то же (`cover_1920x1080.png`) | собственная | загружена: `rbxassetid://94563561919999`; назначить обложкой — владелец |
| Модели препятствий/NPC/декора/магазины | Parts (Luau) | собственные | — | созданы и осмотрены (цвета/материалы обновлены 2026-11-16) |
| Звуки | встроенные Roblox (`rbxasset://sounds/*`) | Roblox | условия Roblox | ВРЕМЕННЫЕ, оригинальных нет (LIM-001) |
| Иконки меню HUD (10) | PNG 256x256, Blender 5.2 (`TRAP_LAB\assets\make_hud_icons.py` -> `assets\hud\*.png`) | собственные | — | загружены 2026-11-16: shop 107587380007987, npcshop 96905546975275, build 98123178527349, npcs 125184924629797, rebirth 125036462025603, daily 121924738024708, popular 72380017458508, decor 123636416543865, inventory 131502615872712, donate 129249029151000 (все в `Configs/Icons`) |


## Сессия 4 (2026-11-16): ассеты из Blender 5.2 / numpy, загружены `upload_image`
| Ассет | ID | Источник | Где используется |
|---|---|---|---|
| Иконки меню v2 (с контуром): shop, npcshop, build, npcs, rebirth, daily, popular, decor, inventory, donate | 89802119290738, 137857827608734, 93962098105801, 82738309337638, 130666627312155, 98538783917335, 117601866755483, 111566464903387, 104420865239696, 130488048770087 | `assets/make_hud_icons.py` | `Configs/Icons`, плитки HUD и шапки окон |
| Монета, замок | 123805542742795, 117225770149201 | `assets/make_ui_icons.py` | `UIKit.coin/lock`, кнопки цены, замки |
| Иконки донатов: tip_small, tip_medium, tip_big, pass_supporter | 138516205083995, 104195432322290, 76551350873005, 80647395673534 | `assets/make_donate_icons.py` | `Configs/Donate.icon`; те же PNG — миниатюры товаров Roblox |
| Плитка воды бассейна | rbxassetid://126806655453119 | `assets/make_water_tile.py` | `Texture` на `BuildZone` (PlotService) |
| Рельеф кирпичной стены | rbxassetid://93686982618788 | `assets/make_wall_tile.py` | `Texture` на сегментах стены-обрыва |
| Товары Roblox (Open Cloud, вселенная 10776882597) | Developer Product 3732195535 / 3732195569 / 3732195584; Game Pass 2088370955 | — | `Configs/Donate.assetId` |

## Сессия 5
| Ассет | ID | Источник |
|---|---|---|
| Иконка молотка (слот 1 хотбара) | rbxassetid://103378563588929 | Blender, `assets/make_nav_icons.py` (оригинал) |
| Иконка домика (плашка Home) | rbxassetid://72869141540137 | Blender, `make_nav_icons.py` |
| Финишный флажок (кнопка PLAY) | rbxassetid://82700538007035 | Blender, `make_nav_icons.py` |
| Текстура газона (шахматка с шипами) | rbxassetid://108532129961873 | Python, `assets/make_lawn_tile.py` (оригинал) |
| Звук Rebirth | rbxassetid://9116394545 | Creator Store, ProSoundEffects (лицензированная библиотека Roblox), «Magic Glows Soft Clusters Of Chiming Hits 1 (SFX)» || SFX coin (свой, синтез) | rbxassetid://132271313002353 | `assets/make_sfx.py` -> audio/coin.wav, Open Cloud |
| SFX spend | rbxassetid://92084588790572 | make_sfx.py |
| SFX place | rbxassetid://117186539684798 | make_sfx.py |
| SFX open (окно) | rbxassetid://113860525578653 | make_sfx.py |
| SFX checkpoint | rbxassetid://83215067897615 | make_sfx.py |
| SFX clear (фанфара) | rbxassetid://115227221666458 | make_sfx.py |
| SFX fall | rbxassetid://127176778891626 | make_sfx.py |
| Музыка: Spring Weaver (116 с) | rbxassetid://9042623779 | Creator Store, APM Music (лицензированная библиотека Roblox) |
| Музыка: Puzzle Waltz A | rbxassetid://1847525235 | Creator Store, APM Music || Лицо NPC happy | rbxassetid://100335808194876 | `assets/make_faces.py` (оригинал, Python) |
| Лицо NPC grin | rbxassetid://125473485397206 | make_faces.py |
| Лицо NPC determined | rbxassetid://140413707011741 | make_faces.py |
| Лицо NPC cool (очки) | rbxassetid://111355523323234 | make_faces.py |
| Лицо NPC wonder | rbxassetid://80977836453507 | make_faces.py |
| Стрелка обучения (экран + маркер) | rbxassetid://106505602112612 | `assets/make_guide_chevron.py 256 guide_arrow.png` (оригинал, Python) |
| Дорожка стрелок на земле (Beam) | rbxassetid://107943447868244 | `assets/make_guide_arrows.py` (оригинал, Python) |
| Шевроны (тонкие, не используются) | rbxassetid://87060573364779 | `assets/make_guide_chevron.py 384` |

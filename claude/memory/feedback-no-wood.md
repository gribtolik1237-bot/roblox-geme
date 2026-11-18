---
name: feedback-no-wood
description: "TRAP LAB owner rule - do NOT use wood (wooden posts/frames/planks, red-brown timber look) in the game, e.g. on leaderboards; it looks bad and reads as AI-made"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 9a286ce4-52f8-433d-80ce-32df3b2e4e89
  modified: 2026-11-16T08:22:02.021Z
---

**Уточнение владельца от 2026-11-18.** Дерево допустимо там, где подходит объекту и сцене. Киоски выполнены из цветного пластика со studs по референсу. Ниже описано прежнее правило.

В игре TRAP LAB НЕ использовать «дерево» (WoodPlanks, красно-коричневые стойки/рамы/балки, деревянные заборы и т.п.), например на досках лидеров в «Зале».

**Why:** владелец (2026-11-16, сессия 5): «это смотрится плохо и сразу видно, что сделала нейросеть». Это отменяет прежний вывод сессий 3–4 «деревянные каркасы по эталонам» в ART_DIRECTION: он дал именно тот шаблонный вид, который владелец называет нейрослопом.

**How to apply:** новые вывески, рамы, стойки, навесы, заборы, постаменты делать из цветного пластика/камня/металла/кирпичной плитки (насыщенные цвета, шипы, фаски, толстый контур), НЕ из WoodPlanks и не в «коричневом под дерево». Уже существующее дерево (стойки/балка/рамы «Зала», колонны и навес магазинов, рамы табличек участков, заборы участков, `SignKit.WOOD*`, `Material.WoodPlanks`) подлежит замене — не добавлять новое, при правках по возможности заменять. См. [[project-trap-lab]] и [[feedback-art-quality]].

**Decision (2026-11-16):** owner chose COLORED PLASTIC as the replacement: posts/columns red (206,58,50), beams/bases navy (46,58,110), frames/rails/shelves yellow (255,200,44); Material.Plastic (+studs), never WoodPlanks.

---
name: feedback-shopkeeper
description: "TRAP LAB owner rule - every shop has exactly ONE NPC (a shopkeeper behind the counter), never a row of many NPC mannequins"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 9a286ce4-52f8-433d-80ce-32df3b2e4e89
  modified: 2026-11-16T17:54:02.238Z
---

В КАЖДОМ магазине (Obstacle Shop, NPC Shop) стоит ОДИН NPC-продавец за прилавком, а не много NPC-манекенов.

**Why:** владелец (2026-11-16): «в магазинах должен стоять NPC в любых, а не много NPC». Ряд из 6 манекенов в NPC Shop выглядел как склад, а не как лавка с продавцом (как на референсах).

**How to apply:** продавец — риг из NPCRig, анкерный, за прилавком лицом к точке телепорта, в масштабе киоска; товары NPC показывать в окне магазина, не толпой в мире. См. [[feedback-shop-scale]].

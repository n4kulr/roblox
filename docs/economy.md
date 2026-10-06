# THOCK economy and pacing

This page is the pacing contract for the key, upgrade and rebirth numbers. The numbers in `src/shared/Config/*` were tuned with `tools/economy_sim.luau`, which plays the game with the real config and rules modules.

## Rerun

```
rojo sourcemap default.project.json --output sourcemap.json
lune run tools/economy_sim
lune run tools/economy_sim 50 48 docs/economy-latest.md
```

Arguments are optional: number of seeds (default 50), horizon in hours (default 48) and a file to also write the report to. Seeds are 1..N, so a run is deterministic. A full 50 seed, 48 hour run takes a few minutes.

## What the simulated player does

- Rolls at the real rolls per second (Speed upgrades and Speed perk keys included), with the guaranteed Rare roll and a golden roll every N rolls at the golden luck multiplier.
- Keeps the best keys on the board (Equip Best order, plus a search for the best number of Gold Plate income keys) and keeps everything else in the inventory.
- Every 3 seconds: rebirths if it can afford it, otherwise buys the affordable upgrade with the best value per cost. An upgrade is skipped when its payback is longer than the time left until the next rebirth. Walls and Laser Lock (Defense) are never bought.
- After a rebirth the board is cleared into the inventory, the best keys are re-equipped on the base slots, and all upgrades restart at level 0.
- Ignored: stealing, Robux, potions, passes, daily rewards, season, market, selling keys and offline income.

## Rebirth rules

- Rebirth resets Clicks, all upgrades and the board (keys go to the inventory, nothing is lost). Slots return to `BaseSlots`.
- It keeps Rebirths, discovered keys, season, codes, daily and everything else.
- Cost is `BaseCost` times the product of `CostSteps` (one entry per rebirth already done), then `CostGrowth` once the steps run out. Income multiplier is `1 + IncomePerRebirth * rebirths`.

## Targets

| Target | Goal |
| --- | --- |
| First upgrade | 20 to 30 s, then something affordable every 30 to 60 s early |
| First Epic | 6 to 10 min |
| First Legendary | 35 to 50 min |
| Rebirth 1 | 60 to 75 min |
| Rebirth n+1 | about 1.4 times the duration of rebirth n, never shorter |
| First Mythic | 4 to 6 h |
| First Secret | 20 h or more, long tail |
| Rarity income | each tier about 6 to 10 times the one below |
| Mid upgrades | Luck, Speed, Slots, Income and Golden not exhausted in the first 2 to 3 hours |
| Defense upgrades | Walls and Laser Lock stay expensive |

## Final numbers against the targets

Medians over seeds 1 to 50.

| Target | Result | Met |
| --- | --- | --- |
| First upgrade 20 to 30 s | 21 s (p10 18 s, p90 27 s) | yes |
| Something affordable every 30 to 60 s early | gaps of 15 to 27 s in the first 2 minutes and 30 to 42 s up to minute 5, so slightly quicker than the goal at the very start | mostly |
| First Epic 6 to 10 min | 9 min 32 s | yes |
| First Legendary 35 to 50 min | 42 min 52 s | yes |
| Rebirth 1 at 60 to 75 min | 1 h 09 min | yes |
| Rebirth durations grow about 1.4 times each | 1.30, 1.52, 1.29, 1.57 for rebirths 2 to 5, never shorter | yes |
| First Mythic 4 to 6 h | 5 h 00 min | yes |
| First Secret 20 h or more | 25 h 52 min, 29 of 50 seeds within 48 h | yes |
| Income tier steps 6 to 10 times | 6, 6.7, 7.5, 8, 8.3, 8 | yes |
| Mid upgrades last 2 to 3 hours | nothing is maxed in a life before about 5.5 h (Slots first), Speed and Golden not before about 12 h | yes |
| Defense upgrades pricey | Walls 300k, Laser Lock 1M for the first level | yes |

Rebirth durations are measured from the previous rebirth: 1:10, 1:30, 2:18, 2:58, 4:40. The very first Legendary arrives so late in life 1 that rebirth 1 follows it closely, which is why `CostSteps` has a large first step: after rebirth 1 the best keys are kept, so the same cost curve would make rebirth 2 much faster than rebirth 1.

## Changed numbers

| Config | Before | After |
| --- | --- | --- |
| `BaseSlots` | 10 | 6 |
| Rarity chance (1 in) Uncommon, Rare, Epic, Legendary, Mythic, Secret | 8, 50, 500, 5,000, 100,000, 1,000,000 | 10, 150, 16,000, 100,000, 3,200,000, 45,000,000 |
| Rarity income Uncommon, Rare, Epic, Legendary, Mythic, Secret | 4, 20, 150, 1,500, 40,000, 500,000 | 6, 40, 300, 2,400, 20,000, 160,000 |
| `Rebirth.BaseCost` | 1,000,000 | 40,000,000 |
| `Rebirth.CostSteps` | none | 42, 19, 5.5, 3.6 |
| `Rebirth.CostGrowth` (after the steps) | 4 | 3 |
| `Rebirth.IncomePerRebirth` | 0.5 | 1 |
| Luck base cost, growth | 100, 1.22 | 1,500, 1.33 |
| Speed base cost, growth, max level | 250, 1.75, 10 | 12,000, 3, 14 |
| Slots base cost, growth, max level | 500, 1.45, 25 | 15,000, 1.6, 27 |
| Income base cost, growth | 400, 1.25 | 8,000, 1.4 |
| Golden base cost, growth, max level | 1,500, 1.6, 10 | 40,000, 2.5, 15 |
| Walls base cost, growth | 5,000, 3 | 300,000, 3.2 |
| Laser Lock base cost, growth | 20,000, 1.9 | 1,000,000, 2 |

`BaseSlots` plus `Slots` max level times 2 slots is 60, which equals `BoardSlots`. Speed tops out at 12 rolls per second, which is `MaxRollsPerSecond`.

## Notes and caveats

- Selling keys is not simulated. A sell is worth 30 seconds of that key's income, so selling a whole board right after a rebirth is far below the next rebirth cost.
- Results move with the seed: the first Legendary and Mythic are lucky draws, and a single lucky Secret can shorten a life a lot. Judge changes by the medians, and rerun with more seeds when tuning.
- Perk keys are strong. Many Gold Plates stack income additively, so the simulated player searches for the best Gold Plate count instead of trusting Equip Best, which ranks by income only.

## Simulator output

Median seed here means the seed ranked in the middle by first Legendary. Seed 1 is the fixed seed.

### Configuration

| Rarity | 1 in | Income/s |
| --- | ---: | ---: |
| Common | 1 | 1 |
| Uncommon | 10 | 6 |
| Rare | 150 | 40 |
| Epic | 16000 | 300 |
| Legendary | 100000 | 2400 |
| Mythic | 3200000 | 20000 |
| Secret | 45000000 | 160000 |

Rebirth cost 40000000 x3 per rebirth, +1 income multiplier per rebirth. Base slots 6, rolls/s 5, golden roll every 100.

| Upgrade | Base cost | Growth | Per level | Max level | Cost of last level |
| --- | ---: | ---: | ---: | ---: | ---: |
| Luck | 1500 | 1.33 | 0.1 | 75 | 2193373997635 |
| Speed | 12000 | 3 | 0.5 | 14 | 19131876000 |
| Slots | 15000 | 1.6 | 2 | 27 | 3042361440 |
| Income | 8000 | 1.4 | 0.1 | 50 | 115708092798 |
| Golden | 40000 | 2.5 | 5 | 15 | 14901161193 |
| Walls | 300000 | 3.2 | 3 | 5 | 31457280 |
| LockTime | 1000000 | 2 | 10 | 10 | 512000000 |

### Milestones (50 seeds, horizon 48 h)

| Milestone | Seed 1 | Median | p10 | p90 | Reached |
| --- | ---: | ---: | ---: | ---: | ---: |
| First upgrade | 0:00:18 | 0:00:21 | 0:00:18 | 0:00:27 | 50/50 |
| First Uncommon | 0:00:01 | 0:00:02 | 0:00:01 | 0:00:05 | 50/50 |
| First Rare | 0:00:01 | 0:00:01 | 0:00:01 | 0:00:01 | 50/50 |
| First Epic | 0:11:28 | 0:09:32 | 0:02:37 | 0:25:33 | 50/50 |
| First Legendary | 1:10:32 | 0:42:52 | 0:08:18 | 1:53:12 | 50/50 |
| First Mythic | 23:40:33 | 5:00:17 | 0:56:06 | 8:43:06 | 50/50 |
| First Secret | 7:37:09 | 25:51:55 | 6:58:21 | never | 29/50 |
| Rebirth 1 | 1:24:27 | 1:09:48 | 0:40:45 | 1:40:48 | 50/50 |
| Rebirth 2 | 3:18:12 | 2:42:12 | 1:52:39 | 3:41:21 | 50/50 |
| Rebirth 3 | 5:40:36 | 4:57:45 | 3:34:06 | 6:17:51 | 50/50 |
| Rebirth 4 | 8:14:03 | 7:57:00 | 5:45:30 | 10:10:06 | 50/50 |
| Rebirth 5 | 10:58:48 | 12:06:21 | 9:11:06 | 15:25:15 | 50/50 |

| Rebirth | Duration (median) | Ratio to previous |
| --- | ---: | ---: |
| 1 | 1:09:48 | - |
| 2 | 1:30:24 | 1.30 |
| 3 | 2:17:39 | 1.52 |
| 4 | 2:58:03 | 1.29 |
| 5 | 4:39:57 | 1.57 |
| 6 | 8:24:33 | 1.80 |

### Median seed timeline (seed 29, ranked by first Legendary)

Purchases per 5 minutes for the first 2 hours, then per hour. R marks a rebirth.

| Window | Luck | Speed | Slots | Income | Golden | Events |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| 0:00:00-0:05:00 | 8 | 0 | 0 | 2 | 0 | Uncommon, Rare |
| 0:05:00-0:10:00 | 2 | 1 | 2 | 2 | 0 |  |
| 0:10:00-0:15:00 | 2 | 1 | 1 | 1 | 0 |  |
| 0:15:00-0:20:00 | 2 | 0 | 1 | 2 | 1 | Epic |
| 0:20:00-0:25:00 | 2 | 0 | 1 | 1 | 0 |  |
| 0:25:00-0:30:00 | 2 | 1 | 1 | 2 | 0 |  |
| 0:30:00-0:35:00 | 1 | 0 | 1 | 2 | 0 |  |
| 0:35:00-0:40:00 | 1 | 1 | 1 | 1 | 0 |  |
| 0:40:00-0:45:00 | 3 | 0 | 1 | 2 | 0 | Legendary |
| 0:45:00-0:50:00 | 0 | 1 | 1 | 1 | 0 |  |
| 0:50:00-0:55:00 | 0 | 0 | 0 | 0 | 0 |  |
| 0:55:00-1:00:00 | 0 | 0 | 0 | 0 | 0 |  |
| 1:00:00-1:05:00 | 0 | 0 | 0 | 0 | 0 |  |
| 1:05:00-1:10:00 | 0 | 0 | 0 | 0 | 0 |  |
| 1:10:00-1:15:00 | 19 | 3 | 7 | 11 | 2 | R1 |
| 1:15:00-1:20:00 | 6 | 2 | 4 | 5 | 3 |  |
| 1:20:00-1:25:00 | 3 | 1 | 1 | 3 | 0 |  |
| 1:25:00-1:30:00 | 2 | 0 | 2 | 2 | 1 |  |
| 1:30:00-1:35:00 | 2 | 1 | 1 | 1 | 0 |  |
| 1:35:00-1:40:00 | 1 | 0 | 1 | 2 | 0 |  |
| 1:40:00-1:45:00 | 2 | 0 | 0 | 0 | 0 |  |
| 1:45:00-1:50:00 | 0 | 1 | 1 | 1 | 0 |  |
| 1:50:00-1:55:00 | 0 | 0 | 0 | 1 | 0 |  |
| 1:55:00-2:00:00 | 0 | 0 | 0 | 0 | 0 |  |
| 2:00:00-3:00:00 | 34 | 8 | 17 | 25 | 7 | R2 |
| 3:00:00-4:00:00 | 10 | 3 | 6 | 9 | 3 |  |
| 4:00:00-5:00:00 | 43 | 10 | 22 | 32 | 10 | R3, Mythic |
| 5:00:00-6:00:00 | 7 | 2 | 5 | 7 | 2 |  |
| 6:00:00-7:00:00 | 0 | 0 | 0 | 0 | 0 |  |
| 7:00:00-8:00:00 | 54 | 13 | 27 | 41 | 14 | R4 |
| 8:00:00-9:00:00 | 0 | 0 | 0 | 2 | 0 |  |
| 9:00:00-10:00:00 | 0 | 0 | 0 | 0 | 0 |  |
| 10:00:00-11:00:00 | 0 | 0 | 0 | 0 | 0 |  |
| 11:00:00-12:00:00 | 56 | 13 | 27 | 42 | 14 | R5 |

### Median seed first purchases

| Time | Upgrade | Level | Gap |
| --- | --- | ---: | ---: |
| 0:00:18 | Luck | 1 | 18 s |
| 0:00:36 | Luck | 2 | 18 s |
| 0:00:51 | Luck | 3 | 15 s |
| 0:01:09 | Luck | 4 | 18 s |
| 0:01:33 | Luck | 5 | 24 s |
| 0:02:00 | Luck | 6 | 27 s |
| 0:02:33 | Income | 1 | 33 s |
| 0:03:03 | Luck | 7 | 30 s |
| 0:03:45 | Income | 2 | 42 s |
| 0:04:24 | Luck | 8 | 39 s |

### Median seed cash per second

| Time | Cash/s | Rebirths |
| --- | ---: | ---: |
| 0:00:00 | 44 | 0 |
| 0:00:30 | 104 | 0 |
| 0:01:00 | 206 | 0 |
| 0:02:00 | 240 | 0 |
| 0:05:00 | 288 | 0 |
| 0:10:00 | 560 | 0 |
| 0:15:00 | 720 | 0 |
| 0:20:00 | 1394 | 0 |
| 0:30:00 | 3100 | 0 |
| 0:45:00 | 20212 | 0 |
| 1:00:00 | 26117 | 0 |
| 1:30:00 | 165912 | 1 |
| 2:00:00 | 263808 | 1 |
| 3:00:00 | 1541137 | 2 |
| 4:00:00 | 6776550 | 2 |
| 5:00:00 | 10657500 | 3 |
| 6:00:00 | 24562230 | 3 |
| 7:00:00 | 28956550 | 3 |
| 8:00:00 | 37673062 | 4 |
| 9:00:00 | 52334850 | 4 |
| 10:00:00 | 52334850 | 4 |
| 11:00:00 | 52334850 | 4 |
| 12:00:00 | 61616880 | 5 |

### Upgrades maxed within a life (median seed)

| Rebirths so far | Upgrade | Time |
| ---: | --- | ---: |
| 3 | Slots | 5:28:39 |
| 4 | Slots | 7:42:09 |
| 5 | Slots | 11:41:00 |
| 5 | Golden | 12:07:51 |
| 5 | Speed | 12:20:15 |
| 6 | Slots | 19:10:21 |
| 6 | Golden | 19:29:27 |
| 6 | Speed | 19:38:48 |
| 7 | Slots | 33:31:18 |
| 7 | Golden | 33:44:06 |
| 7 | Speed | 33:50:33 |
| 7 | Income | 35:08:15 |

Simulated in 237.2 s.

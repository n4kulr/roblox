# THOCK economy and pacing

This page is the pacing contract for the key, upgrade and rebirth numbers. The numbers in `src/shared/Config/*` were tuned with `tools/economy_sim.luau`, which plays the game with the real config and rules modules.

The design goal is a fast, rewarding start: a player should be hooked for the first 40 minutes (something to buy every few seconds, a new rarity every few minutes, income that jumps in visible steps) and then the pace slows down towards long goals. The first rebirth is the goal that follows the hook.

## Rerun

```
rojo sourcemap default.project.json --output sourcemap.json
lune run tools/economy_sim
lune run tools/economy_sim 50 48 docs/economy-latest.md
```

Arguments are optional: number of seeds (default 50), horizon in hours (default 48) and a file to also write the report to. Seeds are 1..N, so a run is deterministic. A full 50 seed, 48 hour run takes about 10 minutes; 20 seeds and 3 hours is enough to judge the first hour (about 15 seconds).

## What the simulated player does

- Rolls at the real rolls per second (Speed upgrades and Speed perk keys included), with the guaranteed Rare roll and a golden roll every N rolls at the golden luck multiplier.
- Keeps the best keys on the board (Equip Best order, plus a search for the best number of Gold Plate income keys) and keeps everything else in the inventory.
- Every 3 seconds: rebirths if it can afford it, otherwise buys the affordable upgrade with the best value per cost. An upgrade is skipped when its payback is longer than 8 times the time left until the next rebirth (a kid does not optimise perfectly, but does stop buying things that are pointless right before a rebirth). Walls and Laser Lock (Defense) are never bought.
- After a rebirth the board is cleared into the inventory, the best keys are re-equipped on the base slots, and all upgrades restart at level 0.
- Ignored: stealing, Robux, potions, passes, daily rewards, playtime rewards, group chest, season, market, selling keys and offline income.
- The median seed in the reports is the seed closest (in log distance) to the median first Epic, first Legendary, second Legendary and first rebirth, so its log reads like a typical player.

## Slots

A base has 8 key slots in total. A new player starts with `BaseSlots` = 3 and the Slots upgrade adds 1 per level up to level 5 (3 + 5 = `BoardSlots` = 8). Slot upgrades are priced to arrive as milestones during the first 40 minutes (about minute 3, 7, 12, 18 and 28 in the median seed) instead of being a bulk purchase. With only 8 keys the rarity incomes are larger than before so the same pacing holds.

## Rebirth rules

- Rebirth resets Clicks, all upgrades and the board (keys go to the inventory, nothing is lost). Slots return to `BaseSlots`.
- It keeps Rebirths, discovered keys, season, codes, daily and everything else.
- Cost is `BaseCost` times the product of `CostSteps` (one entry per rebirth already done), then `CostGrowth` once the steps run out. Income multiplier is `1 + IncomePerRebirth * rebirths`.

## Targets

| Target | Goal |
| --- | --- |
| First upgrade | 5 to 8 s |
| Upgrade purchases | every 8 to 20 s in minutes 0 to 10, every 20 to 40 s in minutes 10 to 40, slower after |
| First Rare | by roll 3 (guaranteed) |
| First Epic | 2 to 3 min |
| First Legendary | 12 to 20 min, a second one before about 35 min |
| Income steps | each early milestone (new rarity placed, slot unlocked) roughly doubles income or more in the first 40 min |
| Rebirth 1 | 45 to 60 min |
| Rebirth n+1 | 1.3 to 1.5 times the duration of rebirth n, never shorter |
| First Mythic | 2 to 3 h |
| First Secret | 15 to 25 h |
| Rarity income | each tier about 6 to 12 times the one below |
| Upgrades | Luck, Speed, Income and Golden not maxed before about 4 h (Slots is only 5 levels and is meant to finish in the first 30 to 50 minutes) |
| Defense upgrades | Walls and Laser Lock stay expensive |

## Before and after

Medians over seeds 1 to 50.

| Milestone | Before | After | Target met |
| --- | --- | --- | --- |
| First upgrade | 21 s | 6 s | yes |
| First Rare | roll 3 | roll 3 | yes |
| First Epic | 9 min 32 s | 2 min 27 s | yes |
| First Legendary | 42 min 52 s | 14 min 09 s | yes |
| Second Legendary | not tracked | 26 min 44 s | yes |
| First Mythic | 5 h 00 min | 2 h 36 min | yes |
| First Secret | 25 h 52 min | 19 h 00 min (43 of 50 seeds within 48 h) | yes |
| Rebirth 1 | 1 h 10 min | 51 min 54 s | yes |
| Rebirth durations | 1:10, 1:30, 2:18, 2:58, 4:40 | 0:52, 1:11, 1:46, 2:25, 3:36 | yes |
| Duration ratios | 1.30, 1.52, 1.29, 1.57 | 1.36, 1.50, 1.36, 1.49 | yes |
| Purchases, minutes 0 to 10 | one per 15 to 40 s | one per 8.6 s | yes |
| Purchases, minutes 10 to 40 | one per 30 to 60 s | one per 43 s on average, 40 s or less while a rarity is being chased | mostly |

Notes on the misses and caveats:

- Spread between players is wide with only 8 slots: p10 to p90 for the first Legendary is 6 to 35 min and for rebirth 1 is 32 to 71 min. The median is on target.
- A purchase every 20 to 40 s holds until roughly minute 25. From minute 30 to the first rebirth the player is mostly saving, so the gaps stretch to a minute or more. This is the "slower later" part and the rebirth is the goal.
- After a rebirth the best keys are kept, so the first minutes of each later life are very quick; that is intended.

## Changed numbers

| Config | Before | After |
| --- | --- | --- |
| `BaseSlots` | 6 | 3 |
| `BoardSlots` | 60 | 8 |
| Slots upgrade per level, max level, base cost, growth | +2, 27, 15,000, 1.6 | +1, 5, 8,000, 5 |
| Rarity chance (1 in) Rare, Epic, Legendary, Mythic, Secret | 150, 16,000, 100,000, 3,200,000, 45,000,000 | 120, 2,400, 50,000, 2,000,000, 15,000,000 |
| Rarity income Epic, Legendary, Mythic, Secret | 300, 2,400, 20,000, 160,000 | 400, 4,000, 40,000, 400,000 |
| `Rebirth.BaseCost` | 40,000,000 | 125,000,000 |
| `Rebirth.CostSteps` | 42, 19, 5.5, 3.6 | 7, 9, 3.3, 2.8, 3 |
| `Rebirth.CostGrowth` (after the steps) | 3 | 2.6 |
| Luck base cost, growth, max level | 1,500, 1.33, 75 | 150, 1.25, 120 |
| Speed base cost, growth | 12,000, 3 | 3,000, 3 |
| Income base cost, growth, max level | 8,000, 1.4, 50 | 800, 1.27, 100 |
| Golden base cost, growth | 40,000, 2.5 | 4,000, 2.6 |
| Walls, Laser Lock | unchanged | unchanged |

Luck is cheap early and gets steeper later (the first levels cost a few hundred Clicks, level 40 about 1.1 million), which gives a short "beginner luck" ramp with no new mechanic. Speed tops out at 12 rolls per second, which is `MaxRollsPerSecond`.

## Notes and caveats

- Selling keys is not simulated. A sell is worth 30 seconds of that key's income, so selling a whole board right after a rebirth is far below the next rebirth cost.
- Results move with the seed: the first Legendary and Mythic are lucky draws, and a single lucky Secret can shorten a life a lot. Judge changes by the medians, and rerun with more seeds when tuning.
- Perk keys are strong. Many Gold Plates stack income additively, so the simulated player searches for the best Gold Plate count instead of trusting Equip Best, which ranks by income only.
- The tests in `tests/specs/economy.spec.luau` assert relationships (tiers get rarer and richer, steps stay in range, the first upgrade is affordable within seconds, Slots and Speed reach the caps, rebirth stays a long goal), not the literal numbers.

## Simulator output

### Configuration

| Rarity | 1 in | Income/s |
| --- | ---: | ---: |
| Common | 1 | 1 |
| Uncommon | 10 | 6 |
| Rare | 120 | 40 |
| Epic | 2400 | 400 |
| Legendary | 50000 | 4000 |
| Mythic | 2000000 | 40000 |
| Secret | 15000000 | 400000 |

Rebirth cost 125000000 x2.6 per rebirth, +1 income multiplier per rebirth. Base slots 3, rolls/s 5, golden roll every 100.

| Upgrade | Base cost | Growth | Per level | Max level | Cost of last level |
| --- | ---: | ---: | ---: | ---: | ---: |
| Luck | 150 | 1.25 | 0.1 | 120 | 51095518080097 |
| Speed | 3000 | 3 | 0.5 | 14 | 4782969000 |
| Slots | 8000 | 5 | 1 | 5 | 5000000 |
| Income | 800 | 1.27 | 0.1 | 100 | 15123710715283 |
| Golden | 4000 | 2.6 | 5 | 15 | 2580398988 |
| Walls | 300000 | 3.2 | 3 | 5 | 31457280 |
| LockTime | 1000000 | 2 | 10 | 10 | 512000000 |

### Milestones (50 seeds, horizon 48 h)

| Milestone | Seed 1 | Median | p10 | p90 | Reached |
| --- | ---: | ---: | ---: | ---: | ---: |
| First upgrade | 0:00:06 | 0:00:06 | 0:00:06 | 0:00:06 | 50/50 |
| First Uncommon | 0:00:01 | 0:00:02 | 0:00:01 | 0:00:05 | 50/50 |
| First Rare | 0:00:01 | 0:00:01 | 0:00:01 | 0:00:01 | 50/50 |
| First Epic | 0:03:07 | 0:02:27 | 0:00:49 | 0:05:33 | 50/50 |
| First Legendary | 0:05:37 | 0:14:09 | 0:05:37 | 0:35:24 | 50/50 |
| First Mythic | 3:15:47 | 2:36:35 | 0:41:16 | 5:39:15 | 50/50 |
| First Secret | 32:51:32 | 18:59:56 | 2:24:28 | never | 43/50 |
| Second Legendary | 0:18:22 | 0:26:44 | 0:10:54 | 0:55:30 | 50/50 |
| Rebirth 1 | 0:43:15 | 0:51:54 | 0:32:27 | 1:10:57 | 50/50 |
| Rebirth 2 | 1:54:27 | 1:57:54 | 0:54:45 | 2:21:45 | 50/50 |
| Rebirth 3 | 4:20:45 | 3:59:15 | 1:56:42 | 5:48:21 | 50/50 |
| Rebirth 4 | 6:44:06 | 6:39:36 | 3:01:36 | 9:07:45 | 50/50 |
| Rebirth 5 | 10:15:48 | 10:36:18 | 3:50:57 | 14:39:24 | 50/50 |

| Rebirth | Duration (median) | Ratio to previous |
| --- | ---: | ---: |
| 1 | 0:51:54 | - |
| 2 | 1:10:48 | 1.36 |
| 3 | 1:46:27 | 1.50 |
| 4 | 2:24:45 | 1.36 |
| 5 | 3:36:00 | 1.49 |
| 6 | 5:59:24 | 1.66 |

### Purchase cadence (median over seeds)

| Window | Purchases | Average gap | Longest gap |
| --- | ---: | ---: | ---: |
| 0:00:00-0:10:00 | 70 | 8.6 s | 21 s |
| 0:10:00-0:40:00 | 40 | 42.9 s | 105 s |
| 0:40:00-1:00:00 | 1 | 1200.0 s | 48 s |
| 1:00:00-2:00:00 | 0 | 3600.0 s | 0 s |

### First 40 minutes (median seed)

Per minute: purchases (Luck, Speed, Slots, Income, Golden), Clicks per second at the end of the minute and what was found.

| Minute | Buys | Luck | Speed | Slots | Income | Golden | Cash/s | Events |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 1 | 12 | 9 | 0 | 0 | 3 | 0 | 144 | first Uncommon, first Rare |
| 2 | 8 | 3 | 1 | 0 | 4 | 0 | 816 | first Epic |
| 3 | 11 | 6 | 0 | 1 | 3 | 1 | 1040 |  |
| 4 | 6 | 2 | 1 | 0 | 2 | 1 | 1144 |  |
| 5 | 5 | 3 | 0 | 0 | 2 | 0 | 1248 |  |
| 6 | 5 | 1 | 1 | 0 | 2 | 1 | 3224 |  |
| 7 | 5 | 2 | 0 | 1 | 2 | 0 | 3584 |  |
| 8 | 4 | 2 | 0 | 0 | 2 | 0 | 3712 |  |
| 9 | 3 | 1 | 1 | 0 | 0 | 1 | 3840 |  |
| 10 | 2 | 1 | 0 | 0 | 1 | 0 | 3968 |  |
| 11 | 2 | 1 | 0 | 0 | 1 | 0 | 8000 |  |
| 12 | 3 | 1 | 0 | 1 | 1 | 0 | 9900 |  |
| 13 | 3 | 1 | 0 | 0 | 1 | 1 | 10200 |  |
| 14 | 4 | 2 | 1 | 0 | 1 | 0 | 31500 | first Legendary |
| 15 | 4 | 2 | 0 | 0 | 2 | 0 | 33300 |  |
| 16 | 4 | 1 | 0 | 0 | 2 | 1 | 40950 |  |
| 17 | 3 | 1 | 1 | 0 | 1 | 0 | 42000 |  |
| 18 | 3 | 1 | 0 | 1 | 1 | 0 | 45919 |  |
| 19 | 2 | 1 | 0 | 0 | 1 | 0 | 47040 |  |
| 20 | 2 | 1 | 0 | 0 | 0 | 1 | 47040 |  |
| 21 | 2 | 1 | 0 | 0 | 1 | 0 | 48160 |  |
| 22 | 1 | 0 | 0 | 0 | 1 | 0 | 56320 |  |
| 23 | 2 | 1 | 1 | 0 | 0 | 0 | 56320 |  |
| 24 | 1 | 0 | 0 | 0 | 1 | 0 | 90000 | second Legendary |
| 25 | 2 | 1 | 0 | 0 | 0 | 1 | 90000 |  |
| 26 | 1 | 0 | 0 | 0 | 1 | 0 | 125119 |  |
| 27 | 2 | 1 | 0 | 0 | 1 | 0 | 127840 |  |
| 28 | 2 | 1 | 0 | 1 | 0 | 0 | 148050 |  |
| 29 | 1 | 0 | 0 | 0 | 1 | 0 | 151200 |  |
| 30 | 2 | 1 | 1 | 0 | 0 | 0 | 151200 |  |
| 31 | 1 | 1 | 0 | 0 | 0 | 0 | 151200 |  |
| 32 | 1 | 0 | 0 | 0 | 1 | 0 | 154350 |  |
| 33 | 1 | 1 | 0 | 0 | 0 | 0 | 154350 |  |
| 34 | 1 | 0 | 0 | 0 | 1 | 0 | 157500 |  |
| 35 | 1 | 1 | 0 | 0 | 0 | 0 | 176000 |  |
| 36 | 1 | 0 | 0 | 0 | 1 | 0 | 189210 |  |
| 37 | 1 | 0 | 0 | 0 | 1 | 0 | 192920 |  |
| 38 | 0 | 0 | 0 | 0 | 0 | 0 | 192920 |  |
| 39 | 1 | 0 | 1 | 0 | 0 | 0 | 192920 |  |
| 40 | 0 | 0 | 0 | 0 | 0 | 0 | 192920 |  |

### Median seed timeline (seed 6, closest to the median Epic, Legendary, second Legendary and rebirth 1)

Purchases per 5 minutes for the first 2 hours, then per hour. R marks a rebirth.

| Window | Luck | Speed | Slots | Income | Golden | Events |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| 0:00:00-0:05:00 | 23 | 2 | 1 | 14 | 2 | Uncommon, Rare, Epic |
| 0:05:00-0:10:00 | 7 | 2 | 1 | 7 | 2 |  |
| 0:10:00-0:15:00 | 7 | 1 | 1 | 6 | 1 | Legendary |
| 0:15:00-0:20:00 | 5 | 1 | 1 | 5 | 2 |  |
| 0:20:00-0:25:00 | 3 | 1 | 0 | 3 | 1 |  |
| 0:25:00-0:30:00 | 3 | 1 | 1 | 3 | 0 |  |
| 0:30:00-0:35:00 | 3 | 0 | 0 | 2 | 0 |  |
| 0:35:00-0:40:00 | 0 | 1 | 0 | 2 | 0 |  |
| 0:40:00-0:45:00 | 0 | 0 | 0 | 0 | 0 |  |
| 0:45:00-0:50:00 | 38 | 6 | 3 | 28 | 5 | R1 |
| 0:50:00-0:55:00 | 11 | 2 | 2 | 12 | 3 |  |
| 0:55:00-1:00:00 | 4 | 0 | 0 | 3 | 1 |  |
| 1:00:00-1:05:00 | 2 | 1 | 0 | 1 | 1 |  |
| 1:05:00-1:10:00 | 2 | 0 | 0 | 2 | 0 |  |
| 1:10:00-1:15:00 | 1 | 0 | 0 | 1 | 0 |  |
| 1:15:00-1:20:00 | 0 | 1 | 0 | 1 | 0 |  |
| 1:20:00-1:25:00 | 1 | 0 | 0 | 1 | 0 |  |
| 1:25:00-1:30:00 | 0 | 0 | 0 | 1 | 0 |  |
| 1:30:00-1:35:00 | 0 | 0 | 0 | 0 | 0 |  |
| 1:35:00-1:40:00 | 0 | 0 | 0 | 0 | 0 |  |
| 1:40:00-1:45:00 | 0 | 0 | 0 | 0 | 0 |  |
| 1:45:00-1:50:00 | 0 | 0 | 0 | 0 | 0 |  |
| 1:50:00-1:55:00 | 0 | 0 | 0 | 0 | 0 |  |
| 1:55:00-2:00:00 | 0 | 0 | 0 | 0 | 0 |  |
| 2:00:00-3:00:00 | 67 | 11 | 5 | 56 | 13 | R2, Mythic |
| 3:00:00-4:00:00 | 1 | 1 | 0 | 2 | 0 |  |
| 4:00:00-5:00:00 | 70 | 12 | 5 | 59 | 13 | R3 |
| 5:00:00-6:00:00 | 3 | 1 | 0 | 4 | 1 |  |
| 6:00:00-7:00:00 | 0 | 0 | 0 | 0 | 1 |  |
| 7:00:00-8:00:00 | 0 | 0 | 0 | 0 | 0 |  |
| 8:00:00-9:00:00 | 70 | 12 | 5 | 59 | 13 | R4 |
| 9:00:00-10:00:00 | 4 | 1 | 0 | 4 | 1 |  |
| 10:00:00-11:00:00 | 4 | 0 | 0 | 3 | 1 |  |
| 11:00:00-12:00:00 | 0 | 1 | 0 | 1 | 0 |  |

### Median seed cash per second

| Time | Cash/s | Rebirths |
| --- | ---: | ---: |
| 0:00:00 | 42 | 0 |
| 0:00:30 | 120 | 0 |
| 0:05:00 | 1248 | 0 |
| 0:10:00 | 3968 | 0 |
| 0:15:00 | 33300 | 0 |
| 0:20:00 | 47040 | 0 |
| 0:25:00 | 90000 | 0 |
| 0:30:00 | 151200 | 0 |
| 0:35:00 | 176000 | 0 |
| 0:40:00 | 192920 | 0 |
| 0:45:00 | 192920 | 0 |
| 0:50:00 | 193800 | 1 |
| 1:00:00 | 394319 | 1 |
| 1:30:00 | 446400 | 1 |
| 2:00:00 | 446400 | 1 |
| 3:00:00 | 2330460 | 2 |
| 4:00:00 | 2401080 | 2 |
| 5:00:00 | 3248520 | 3 |
| 6:00:00 | 3436840 | 3 |
| 7:00:00 | 3436840 | 3 |
| 8:00:00 | 3436840 | 3 |
| 9:00:00 | 4060650 | 4 |
| 10:00:00 | 7519000 | 4 |
| 11:00:00 | 7828000 | 4 |
| 12:00:00 | 7931000 | 4 |

### Upgrades maxed within a life (median seed)

| Rebirths so far | Upgrade | Time |
| ---: | --- | ---: |
| 0 | Slots | 0:27:51 |
| 1 | Slots | 0:53:06 |
| 2 | Slots | 2:02:15 |
| 3 | Slots | 4:07:18 |
| 3 | Golden | 6:11:51 |
| 4 | Slots | 8:18:06 |
| 4 | Golden | 10:07:21 |
| 4 | Speed | 11:04:03 |
| 5 | Slots | 13:49:12 |
| 5 | Golden | 14:30:33 |
| 5 | Speed | 14:58:48 |
| 6 | Slots | 20:04:00 |
| 6 | Golden | 20:30:51 |
| 6 | Speed | 20:53:57 |
| 7 | Slots | 26:50:51 |
| 7 | Golden | 26:55:06 |
| 7 | Speed | 26:58:45 |

Simulated in 174.5 s.

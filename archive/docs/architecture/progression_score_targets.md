# Progression Score Targets

진행 모드의 레벨별 목표 점수는 별도 데이터 테이블이 아니라
`lib/game/jewel_rank_progression.dart`의 `JewelRankProgression.scoreTargetForLevel`에서 나온다.
검증: `test/jewel_rank_progression_test.dart`.

각 레벨의 목표 점수는 이전 누적 목표가 아니라, 해당 레벨에서 채워야 하는 단계 목표 점수다.

## Formula

현재 코드의 핵심 상수:

```dart
static const int xpStep = 250000;
static const int scoreToXpScale = 100;
static const int scoreTargetScale = 3;
static const int relaxedStageStartLevel = 6;
static const int relaxedScoreIncrement = 5000;
```

```text
xpNeededForNextLevel(level) = level * xpStep
linearTarget(level) = (xpNeededForNextLevel(level) / scoreToXpScale) * scoreTargetScale
                    = level * 7,500

level 1~5:
  scoreTargetForLevel(level) = linearTarget(level)

level 6+:
  scoreTargetForLevel(level) = linearTarget(5) + (level - 5) * 5,000
                             = 37,500 + (level - 5) * 5,000
```

예시: 레벨 6 = 42,500, 레벨 10 = 62,500. 선형식 `level * 7,500`을 6 이후에도 쓰면 안 된다.

## Targets

| Level | Target score |
|------:|-------------:|
| 1 | 7,500 |
| 2 | 15,000 |
| 3 | 22,500 |
| 4 | 30,000 |
| 5 | 37,500 |
| 6 | 42,500 |
| 7 | 47,500 |
| 8 | 52,500 |
| 9 | 57,500 |
| 10 | 62,500 |
| 11 | 67,500 |
| 12 | 72,500 |
| 13 | 77,500 |
| 14 | 82,500 |
| 15 | 87,500 |
| 16 | 92,500 |
| 17 | 97,500 |
| 18 | 102,500 |
| 19 | 107,500 |
| 20 | 112,500 |
| 21 | 117,500 |
| 22 | 122,500 |
| 23 | 127,500 |
| 24 | 132,500 |
| 25 | 137,500 |
| 26 | 142,500 |
| 27 | 147,500 |
| 28 | 152,500 |
| 29 | 157,500 |
| 30 | 162,500 |
| 31 | 167,500 |
| 32 | 172,500 |
| 33 | 177,500 |
| 34 | 182,500 |
| 35 | 187,500 |
| 36 | 192,500 |
| 37 | 197,500 |
| 38 | 202,500 |
| 39 | 207,500 |
| 40 | 212,500 |
| 41 | 217,500 |
| 42 | 222,500 |
| 43 | 227,500 |
| 44 | 232,500 |
| 45 | 237,500 |
| 46 | 242,500 |
| 47 | 247,500 |
| 48 | 252,500 |
| 49 | 257,500 |
| 50 | 262,500 |
| 51 | 267,500 |
| 52 | 272,500 |
| 53 | 277,500 |
| 54 | 282,500 |
| 55 | 287,500 |
| 56 | 292,500 |
| 57 | 297,500 |
| 58 | 302,500 |
| 59 | 307,500 |
| 60 | 312,500 |

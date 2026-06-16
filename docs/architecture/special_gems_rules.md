# Stone Match 특수 보석 룰

이 문서는 현재 코드에 구현된 특수 보석 생성, 발동, 연쇄 처리 규칙을 정리한다.
참고 문서인 `/Users/cheng80/Desktop/Bejeweled_Special_Gems_Guide.md`의 Bejeweled식 개념을 차용하지만, Stone Match의 실제 구현은 일부 조합 규칙이 다르다. Bejeweled식 원본 규칙을 그대로 구현하지 않은 항목은 이 문서에서 “Stone Match식 대체 구현”이라고 명시한다.

## 1. 핵심 원칙

- 보드는 8×8이고 좌표는 0 기반 `(row, col)`이다.
- 일반 매치는 가로 또는 세로로 같은 색 보석이 3개 이상 이어질 때 성립한다.
- `hyper` 보석은 색 매치 스캔에서 제외된다. 즉 `hyper`는 3매치 일부가 되지 않고, 인접 보석과 스왑할 때 별도 규칙으로 발동한다.
- `bomb`, `star`, `supernova`, legacy `row`, `col` 보석은 색을 가진다. 같은 색 일반 보석과 함께 3매치에 포함될 수 있다.
- 특수 보석은 “같은 종류끼리 3개 모아야” 발동하는 방식이 아니다. 특수 보석이 제거 대상에 포함되면 그 보석의 효과가 큐에 들어간다.

관련 구현:

- 생성 판정: `lib/game/match_board_spawn_classifier.dart`
- 특수 발동 범위와 연쇄 큐: `lib/game/match_board_specials.dart`
- 하이퍼 스왑: `lib/game/match_board_input.dart`
- 제거, 점수, 상태 전이: `lib/game/match_board_resolution.dart`
- 보석 종류 모델: `lib/game/match_board_models.dart`

## 2. 특수 보석 종류

| 종류 | 현재 표시 이름 | 생성 조건 | 단독 효과 |
|------|----------------|-----------|-----------|
| `bomb` | Flame 계열 | 같은 색 4개 일렬 | 중심 포함 주변 3×3 제거 |
| `star` | Star 계열 | T/L/+ 교차 매치 | 해당 행 전체 + 해당 열 전체 제거 |
| `hyper` | Hypercube 계열 | 같은 색 5개 일렬 | 스왑한 상대 색 전체 제거 |
| `supernova` | Supernova 계열 | 같은 색 6개 이상 일렬 | 주변 3×3 + 해당 행 전체 + 해당 열 전체 제거 |
| `row` | legacy row | 현재 일반 생성 규칙에서는 만들지 않음 | 해당 행 전체 제거 |
| `col` | legacy col | 현재 일반 생성 규칙에서는 만들지 않음 | 해당 열 전체 제거 |

`row`와 `col`은 이전 저장 상태, QA VFX, 에셋 호환을 위해 남아 있는 종류다. 현재 일반 매치 생성 규칙의 주 대상은 `bomb`, `star`, `hyper`, `supernova`다.

## 3. 생성 우선순위

한 번의 해소 사이클에서 여러 매치 그룹이 잡히면 다음 순서로 특수 보석 생성을 예약한다.

```text
T / L / + 교차 매치
  -> star

6개 이상 일렬
  -> supernova

5개 일렬
  -> hyper

4개 일렬
  -> bomb
```

교차 매치가 먼저 처리되므로, T/L/+ 모양이 총 5칸 이상이어도 `hyper`가 아니라 `star`가 생성된다.

## 4. 생성 위치

특수 보석 생성 위치는 다음 규칙으로 정한다.

1. 유저가 방금 움직인 두 칸 중 매치 그룹에 포함된 칸이 있으면 그 칸을 우선 사용한다.
2. 움직인 칸이 해당 그룹에 없으면 그룹의 가운데 칸을 사용한다.
3. 생성될 특수 보석 칸은 제거 대상에서 제외되어 보드에 남는다.

즉 4개 매치로 `bomb`이 생성되면, 4칸이 모두 제거되는 것이 아니라 생성 위치 1칸은 `bomb`으로 바뀌고 나머지 매치 칸만 제거된다.

## 5. 발동 조건

특수 보석 발동은 “제거 대상에 들어갔는지”로 결정된다.

- `bomb`, `star`, `supernova`, `row`, `col`
  - 같은 색 3매치에 포함되면 발동한다.
  - 다른 특수 보석 효과 범위에 휘말리면 발동한다.
  - 일반 보석과 단순히 스왑하는 것만으로는 발동하지 않는다. 스왑 후 색 매치가 성립해야 한다.
  - non-hyper 특수 보석끼리 인접 스왑하면 색 매치 없이도 조합 효과로 발동한다.
- `hyper`
  - 인접한 아무 보석과 스왑하면 바로 발동한다.
  - `hyper`끼리 스왑하면 보드 전체 제거로 처리한다.
  - 색 매치 스캔에는 참여하지 않는다.

힌트 후보도 같은 규칙을 따른다. `hyper`가 포함된 인접 스왑과 non-hyper 특수 보석끼리의 조합 스왑은 유효 후보가 될 수 있다.

## 6. 발동 효과 범위

| 종류 | 제거 범위 |
|------|-----------|
| `row` | 발동 위치의 행 전체 |
| `col` | 발동 위치의 열 전체 |
| `bomb` | 발동 위치 중심의 3×3. 보드 밖 좌표는 무시 |
| `star` | 발동 위치의 행 전체와 열 전체 |
| `hyper` | `triggerColor`와 같은 색의 모든 non-hyper 보석 |
| `supernova` | 발동 위치 중심의 3×3 + 행 전체 + 열 전체 |

효과 범위 안에 다른 특수 보석이 있으면 그 보석도 큐에 들어간다. 이 때문에 특수 보석은 연쇄적으로 발동할 수 있다.

## 7. 하이퍼 스왑 규칙

### 7-1. Hyper + 일반 보석

```text
hyper + color N
  -> hyper와 상대 보석 제거
  -> color N인 모든 non-hyper 보석 제거
```

같은 색 특수 보석이 범위 안에 있으면 해당 특수 효과도 큐에 들어간다.

### 7-2. Hyper + 특수 보석

```text
hyper + special(color N)
  -> hyper와 상대 특수 보석 제거
  -> color N인 모든 non-hyper 보석 제거
  -> 그 범위에 포함된 특수 보석은 각자의 효과를 추가 발동
```

이 조합은 Stone Match식 대체 구현이다. Bejeweled식 “선택 색 전체를 Flame/Star로 변환한 뒤 발동”은 현재 구현되어 있지 않다. Stone Match는 변환이 아니라 같은 색 보석 제거와 기존 특수 보석의 연쇄 발동으로 처리한다.

### 7-3. Hyper + Hyper

```text
hyper + hyper
  -> 보드 전체 제거
```

이 경우 별도 특수 큐 없이 모든 칸을 제거 대상으로 넣는다.

## 8. Non-hyper 특수 보석 조합

`bomb`, `star`, legacy `row`, `col`, `supernova`처럼 `hyper`가 아닌 특수 보석끼리는 인접 스왑만으로도 발동한다.
현재 전용 조합 범위가 있는 조합은 다음과 같다.

| 조합 | 효과 |
|------|------|
| `bomb + bomb` | 두 발동 위치 각각을 중심으로 5×5 대형 폭발 |
| `bomb + star` | `star` 위치의 행/열 경로를 따라 각 칸 주변 3×3 폭발 |
| `star + star` | 두 `star`의 행 전체와 열 전체 제거 |

이 조합들은 조합 전용 제거 범위를 먼저 만든 뒤, 두 특수 보석 자체도 큐에 넣는다. 따라서 조합 범위 안의 다른 특수 보석도 기존 연쇄 규칙대로 추가 발동할 수 있다.

위 표에 없는 non-hyper 특수 보석 조합은 인접 스왑으로 유효 처리하고, 두 특수 보석의 기본 효과를 각각 큐에 넣는 방식으로 처리한다.

## 9. 연쇄 해소 순서

유효 스왑이 발생하면 `MatchBoardLogic`은 다음 상태를 반복한다.

```text
resolveMatchCascade()
└─ 해소 사이클 시작
   ├─ findAllMatches()
   ├─ classifyMatchGroups()
   ├─ buildRemovalSet()
   ├─ buildSpecialQueue()
   ├─ applySpawnInfo()
   ├─ activateSpecials()
   ├─ removing
   ├─ falling
   ├─ refilling
   └─ checking
      ├─ 새 매치 있음 -> 다음 해소 사이클
      └─ 새 매치 없음 -> idle
```

각 해소 사이클마다 `combo`가 1 증가한다. 제거, 낙하, 리필 뒤 새 매치가 생기면 같은 유저 스왑에서 이어진 콤보로 본다.

## 10. 점수와 시간 보상

제거 단계에서 점수는 다음 방식으로 더한다.

```text
base = 100 + max(0, removed - 3) * 50
score += (base + specialBonus) * max(1, combo)
```

특수 보석 발동 보너스:

| 종류 | 보너스 |
|------|--------|
| `row` / `col` | 300 |
| `bomb` | 500 |
| `star` | 800 |
| `hyper` | 1200 |
| `supernova` | 2000 |

Timed/Progression처럼 시간이 있는 모드에서는 제거 단계마다 시간 보상도 계산한다.

```text
raw = (baseUnits + max(0, combo - 1) * perComboTierUnits) * rewardScale
raw > 0이면 round(raw), 단 0초가 되면 최소 1초
raw <= 0이면 보상 없음
```

실제 가산은 모드별 시간 상한을 넘지 않는 범위까지만 적용한다.

## 11. Bejeweled 참고 문서와의 차이

현재 Stone Match는 Bejeweled식 명칭과 일부 기본 아이디어를 참고하지만, 세부 조합은 Stone Match 보드/VFX 구조에 맞춘다.

| 조합/규칙 | Bejeweled 참고 문서 | Stone Match 현재 구현 |
|-----------|---------------------|------------------------|
| Flame + Flame | 대형 폭발 | 두 `bomb` 위치 각각을 중심으로 5×5 대형 폭발 |
| Flame + Star | 십자 경로마다 폭발 | `star` 행/열 경로의 각 칸 주변 3×3 폭발 |
| Hyper + Flame | 선택 색을 Flame으로 변환 후 폭발 | Stone Match식 대체 구현. 변환 없음. 상대 색 전체 제거 + 범위 내 기존 특수 보석 연쇄 |
| Hyper + Star | 선택 색을 Star로 변환 후 발동 | Stone Match식 대체 구현. 변환 없음. 상대 색 전체 제거 + 범위 내 기존 특수 보석 연쇄 |
| Star + Star | 다수 행/열 제거 | 두 `star`의 행 전체와 열 전체 제거 |
| Hyper + Hyper | 보드 전체 제거 | 구현됨 |

새 조합 효과를 추가하려면 먼저 이 문서를 갱신하고, `match_board_input.dart`, `match_board_special_combos.dart`, `match_board_specials.dart`, 관련 테스트를 함께 수정한다.

## 12. 테스트 기준

현재 특수 보석 규칙은 주로 다음 테스트가 지킨다.

- `test/special_gem_combo_test.dart`
  - `bomb + bomb`, `bomb + star`, `star + star` 조합 발동
- `test/match_board_logic_test.dart`
  - 4/5/6개 매치와 T/L 생성 규칙
  - `star`, `supernova`, `hyper` 발동
  - non-hyper 특수 보석의 일반 스왑/색 매치/힌트 후보 규칙
  - 힌트 후보 규칙
- `test/special_effect_event_test.dart`
  - 특수 보석별 effect descriptor와 흔들림 값
- `test/special_effect_pool_test.dart`
  - 특수 효과 풀 재사용과 line sweep 성능 tier

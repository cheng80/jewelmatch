# Stone Match 특수 보석 룰

이 문서는 현재 코드에 구현된 특수 보석 생성, 발동, 연쇄 처리 규칙을 정리한다.
참고 문서인 `/Users/cheng80/Desktop/Bejeweled_Special_Gems_Guide.md`의 Bejeweled식 개념을 차용하지만, Stone Match의 실제 구현은 일부 조합 규칙이 다르다. Bejeweled식 원본 규칙을 그대로 구현하지 않은 항목은 이 문서에서 “Stone Match식 대체 구현”이라고 명시한다.

## 1. 핵심 원칙

- 보드는 8×8이고 좌표는 0 기반 `(row, col)`이다.
- 일반 매치는 가로 또는 세로로 같은 색 보석이 3개 이상 이어질 때 성립한다.
- 색 매치 스캔은 `GemKind.normal`만 대상으로 삼는다. `bomb`, `star`, `hyper`, `supernova`, legacy `row`, `col`은 더 이상 색상 보석으로 취급하지 않는다.
- 특수 보석은 다른 보석의 3매치 일부가 되지 않는다. 즉 같은 색 일반 보석 2개 사이에 특수 보석이 있어도 3매치가 성립하지 않는다.
- 특수 보석은 “같은 종류끼리 3개 모아야” 발동하는 방식이 아니다. 보드에서 해당 특수 보석을 탭하면 즉시 발동한다.
- 특수 보석 효과 범위 안에 다른 특수 보석이 있으면 연쇄 처리된다. 단, `hyper`는 다른 특수 보석의 범위에 휘말려도 제거만 되고 연쇄 발동 큐에는 들어가지 않는다.

관련 구현:

- 생성 판정: `lib/game/match_board_spawn_classifier.dart`
- 특수 발동 범위와 연쇄 큐: `lib/game/match_board_specials.dart`
- 탭 발동과 스왑 입력: `lib/game/match_board_input.dart`
- 제거, 점수, 상태 전이: `lib/game/match_board_resolution.dart`
- 보석 종류 모델: `lib/game/match_board_models.dart`

## 2. 특수 보석 종류

| 종류 | 현재 표시 이름 | 생성 조건 | 단독 효과 |
|------|----------------|-----------|-----------|
| `bomb` | Bomb 계열 | 같은 색 4개 일렬 | 중심 포함 주변 3×3 제거 |
| `star` | Star 계열 | T/L/+ 교차 매치 | 해당 행 전체 + 해당 열 전체 제거 |
| `hyper` | Hypercube 계열 | 같은 색 5개 일렬 | 기존 normal 보석 색 중 하나를 골라 해당 색 normal 보석 제거 |
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

특수 보석 발동은 기본적으로 “유저가 해당 보석을 탭했는지”로 결정된다.

- `bomb`, `star`, `supernova`, `row`, `col`, `hyper`
  - 보드에서 해당 특수 보석을 탭하면 발동한다.
  - 일반 보석과 단순히 스왑하는 것만으로는 발동하지 않는다.
  - 특수 보석은 색 매치 스캔에 참여하지 않으므로 같은 색 3매치에 포함되어 발동하는 경로가 없다.
- `bomb`, `star`, `supernova`, `row`, `col`
  - 다른 특수 보석 효과 범위에 휘말리면 연쇄 발동 큐에 들어간다.
- `hyper`
  - 직접 탭하면 발동한다.
  - 다른 특수 보석 효과 범위에 휘말리면 제거 대상에는 들어가지만 연쇄 발동 큐에는 들어가지 않는다.

힌트 후보는 일반 매치 스왑만 대상으로 한다. 특수 보석 스왑, `hyper` 스왑, non-hyper 특수 보석끼리의 인접 스왑은 더 이상 힌트 후보가 아니다.

## 6. 발동 효과 범위

| 종류 | 제거 범위 |
|------|-----------|
| `row` | 발동 위치의 행 전체 |
| `col` | 발동 위치의 열 전체 |
| `bomb` | 발동 위치 중심의 3×3. 보드 밖 좌표는 무시 |
| `star` | 발동 위치의 행 전체와 열 전체 |
| `hyper` | `triggerColor`와 같은 색의 모든 normal 보석. `triggerColor`가 없으면 보드에 존재하는 normal 보석 색 중 하나를 고름 |
| `supernova` | 발동 위치 중심의 3×3 + 행 전체 + 열 전체 |

효과 범위 안에 다른 non-hyper 특수 보석이 있으면 그 보석도 큐에 들어간다. 이 때문에 `bomb`, `star`, `supernova`, `row`, `col`은 연쇄적으로 발동할 수 있다. `hyper`는 범위에 들어가도 제거만 되고 연쇄 발동하지 않는다.

발동 VFX는 룰과 별도 레이어에서 처리한다. `row`, `col`, `star`의 선형/십자 라이트닝은 기존 절차형 렌더를 유지하고, `bomb`, `hyper`, `supernova`의 중앙 범위 폭발/마법 발동은 `assets/images/sprites/special_area_effects.json` manifest가 지정하는 4×4 정방형 스프라이트 시트를 캐싱해 렌더한다. manifest에서 효과별 이미지, 프레임 grid, 표시 scale, blend 모드를 조절한다. 프레임별 투명도와 후반 fade는 PNG alpha에 베이크해 런타임 alpha 필터를 추가하지 않는다.

## 7. 하이퍼 발동 규칙

### 7-1. 보드의 `hyper` 직접 탭

```text
tap hyper
  -> hyper 제거
  -> 보드에 존재하는 normal 보석 색 중 하나를 선택
  -> 선택된 색의 normal 보석 모두 제거
```

직접 탭한 `hyper`는 상대 보석이 없으므로 `pickExistingColor()`로 보드에 남아 있는 normal 보석 색 중 하나를 고른다.

### 7-2. 아이템 `hyperCube`

```text
hyperCube item on normal color N
  -> 선택한 normal 보석 제거
  -> color N인 모든 normal 보석 제거
```

아이템 `hyperCube`는 normal 보석을 대상으로만 사용할 수 있다. 특수 보석은 색상 보석이 아니므로 아이템 대상에서 제외된다.

### 7-3. Hyper 스왑

현재 구현에서는 `hyper`를 다른 보석과 스왑해도 발동하지 않는다. `hyper + hyper` 보드 전체 제거도 현재 플레이 규칙에서 비활성화되어 있다.

## 8. 특수 보석 스왑 조합

현재 구현에서는 인접한 특수 보석끼리 스왑해도 조합 효과가 발동하지 않는다.

- `bomb + bomb`
- `bomb + star`
- `star + star`
- `hyper + normal`
- `hyper + special`
- `hyper + hyper`

위 조합들은 과거 또는 Bejeweled 참고 규칙으로는 후보였지만, 현재 Stone Match 플레이 규칙에서는 “특수 보석 직접 탭 발동”으로 대체되어 있다.

특수 보석 간 상호작용은 스왑이 아니라 효과 범위 기반 연쇄로 처리한다. 예를 들어 `bomb` 3×3 범위 안에 `star`가 있으면 `star`가 추가 발동한다. 같은 범위 안에 `hyper`가 있으면 `hyper`는 제거되지만 추가 발동하지 않는다.

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

특수 보석 탭 발동은 매치 스캔 없이 다음 흐름으로 시작한다.

```text
triggerSpecialCell(row, col)
├─ 탭한 특수 보석을 removalSet에 추가
├─ 탭한 특수 보석을 초기 queue에 추가
├─ activateSpecials()
└─ removing → falling → refilling → checking
```

## 10. 점수와 시간 보상

제거 단계에서 점수는 다음 방식으로 더한다.

```text
base = 100 + max(0, removed - 3) * 50
score += (base + specialBonus) * max(1, combo)
```

4개 매치로 특수 보석이 생성되면 생성 위치 1칸은 제거되지 않고 `bomb`으로 남으며, 나머지 3칸만 제거된다. 따라서 기본 점수는 `removed = 3` 기준으로 `100`점이 될 수 있다.

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
| Flame + Flame | 대형 폭발 | 스왑 조합 비활성화. 각 `bomb`은 직접 탭하거나 다른 효과 범위에 들어갈 때 기본 3×3으로 발동 |
| Flame + Star | 십자 경로마다 폭발 | 스왑 조합 비활성화. `bomb` 범위에 `star`가 들어가면 `star` 기본 십자 효과가 연쇄 발동 |
| Hyper + Flame | 선택 색을 Flame으로 변환 후 폭발 | 스왑 조합 비활성화. `hyper`는 직접 탭 또는 `hyperCube` 아이템으로 normal 색 제거 |
| Hyper + Star | 선택 색을 Star로 변환 후 발동 | 스왑 조합 비활성화. 특수 보석은 색상 대상이 아니며 변환 없음 |
| Star + Star | 다수 행/열 제거 | 스왑 조합 비활성화. 두 `star`가 서로 범위에 들어가면 효과 범위 기반으로 연쇄 가능 |
| Hyper + Hyper | 보드 전체 제거 | 현재 플레이 규칙에서는 비활성화 |

새 조합 효과를 다시 추가하려면 먼저 이 문서를 갱신하고, `match_board_input.dart`, `match_board_special_combos.dart`, `match_board_specials.dart`, 관련 테스트를 함께 수정한다.

## 12. 테스트 기준

현재 특수 보석 규칙은 주로 다음 테스트가 지킨다.

- `test/special_gem_combo_test.dart`
  - 특수 보석끼리 스왑해도 발동하지 않음
  - 탭한 `bomb` 범위 안의 `star`는 연쇄 발동
  - 범위 안의 `hyper`는 제거만 되고 연쇄 발동하지 않음
- `test/match_board_logic_test.dart`
  - 4/5/6개 매치와 T/L 생성 규칙
  - `star`, `supernova`, `hyper` 기본 발동 범위
  - 특수 보석의 탭 발동
  - 특수 보석이 색 매치 토큰이 아님
  - 특수 스왑/힌트 후보 제외 규칙
- `test/special_effect_event_test.dart`
  - 특수 보석별 effect descriptor와 보드 전용 지진형 흔들림 값
- `test/special_effect_pool_test.dart`
  - 특수 효과 풀 재사용과 line sweep 성능 tier

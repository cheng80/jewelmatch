# PLAN-008 실험 기능 일괄 도입과 스위치

## Metadata
- Plan ID: `PLAN-008`
- Title: 플레이테스트 전 후보 기능을 모두 넣고 원격 스위치와 URL로 켜고 끈다
- Status: `IN_PROGRESS`
- Related Requirement: `FR-004`, `FR-005`, `BR-050`, `BR-011`, `BR-023`, `BR-053`
- Related ADR: `ADR-008`, `ADR-009`
- Owner:
- Updated: 2026-09-24

## 1. 목표
사용자가 당장 플레이테스트를 할 수 없어(2026-09-24 사용자 결정) 판단이 필요한 후보 기능을 먼저 모두 넣는다. 각 기능은 스위치로만 켜지고, 나중에 다시 빌드하지 않고 Supabase `app_config`나 웹 URL로 켜고 끄며 비교한다.

## 2. 범위
### 포함
| 스위치 | 기능 | 적용 모드 | 근거 |
|---|---|---|---|
| `time_reward_t1` / `t1` | 3개짜리 일반 매치 단독 단계는 시간 보상 0초(D7 후보) | 타임 | Product Spec 6-5 |
| `time_gem` / `tg` | Time 보석: 10개 이상 지운 수 뒤 생김, 지우면 +5초, 최대 2개 | 타임 | 6-5 후속 T2, Lightning |
| `multiplier_gem` / `mg` | Multiplier 보석: 12 + 4 × (m - 1)개 이상 지운 수 뒤 생김, 지우면 점수 배율 +1(최대 ×8) | 타임 | 2-3 Blitz Multiplier Gem |
| `seventh_color_from_level` / `c7:N` | 레벨 N부터 보석 7색(시트의 흰 돌) | 레벨 | r/gamedesign 난이도 조절 |
| `last_hurrah_combo_multiplier` / `nolhc` | Last Hurrah 점수에 연쇄 콤보 배수 적용 여부 | 타임 | 6-4 |

- 스위치 기반: `lib/game/gameplay_flags.dart`(`c1e75a3` 이전 `6aaa88c`). 판 시작 때 `board.flags`로 고정되고, `round_start`와 `round_end`에 `exp` 표시가 남아 켠 판과 끈 판을 나눠 볼 수 있다.
- 그림: Time 보석과 Multiplier 보석 배지는 imagegen 내장 도구로 기존 보석 시트를 스타일 참고 삼아 만들었다(`assets/images/sprites/Gem_Badges.png`, 원본 `assets/design/gem_badges/`). 숫자는 코드로 그린다. 7번째 색은 기존 시트의 쓰지 않던 흰 돌을 쓴다.

### 제외
- 보드 코인 보석: 코인 경제(Phase 6)가 없어 제외
- 설정 화면의 실험 스위치 UI

## 3. 스위치 쓰는 법
- 원격(모든 빌드): Supabase 대시보드 Table Editor `app_config`의 `gameplay` 값 JSON을 고친다. 앱은 다음 실행이나 다음 판부터 반영한다.
- 웹 URL(NAS 테스트): `?exp=`로 원격 값 위에 덮어쓴다. 예: `/match/?exp=all`, `?exp=none`, `?exp=t1,-tg`, `?exp=c7:6`, `?exp=nolhc`.
- 기본값은 모두 꺼짐(기존 동작)이다.

## 4. 구현 계획
- [x] 스위치 모델, 판 고정, 이벤트 표시, 7색 매핑과 팔레트, 배지 이미지(총괄)
- [ ] gems 트랙: T1, Time 보석, Multiplier 보석, 배지 렌더, HUD 배율, QA 훅(Orca 워커)
- [ ] config 트랙: 원격 읽기와 캐시, URL 덮어쓰기, `app_config.gameplay` 마이그레이션, 7색 적용, Last Hurrah 스위치(Orca 워커)
- [ ] 독립 검수, 병합, 원격 적용, 로컬 웹과 폰 검증, NAS 배포

## 5. 위험 / 미해결 사항
- 주간 타임 랭킹에 스위치가 다른 판이 섞인다. 출시 전 최종 값을 정하면 한 주를 새로 시작하면 된다(기록 삭제 불필요).
- Multiplier 보석은 점수 규모를 크게 바꾼다. 서버 점수 상한(10억)은 충분하다.
- 판단 기준은 PLAN-005 플레이테스트 양식과 `game_events`의 `exp` 표시다.


# 랭킹 클라이언트 계약

서버 API는 [`ranking_server.md`](ranking_server.md), PHP는 `matchranking/ranking.php`다.
이 문서는 Flutter 클라이언트가 언제 무엇을 보내는지만 적는다. 코드: `lib/game/match_board_game.dart`의 `rankingScore`, `lib/vm/ranking_notifier.dart`, `lib/views/overlays/pause_menu_overlay.dart`, `lib/views/overlays/time_up_overlay.dart`.

## 제출값

| 모드 | RankingMode | score | 0 이하 |
|---|---|---|---|
| 타임 | time | `board.score` | 제출하지 않음 |
| 레벨 | level | 완료 레벨 수 = `progressionLevel > 1 ? progressionLevel - 1 : 0` | 제출하지 않음 |
| 무한 | 없음 | 없음 | |

레벨 4 진입 중이면 3을 보낸다. HUD의 현재 레벨을 그대로 보내지 않는다.

Apps in Toss는 레벨 제출값을 공식 리더보드에도 보낸다. 게임 내 목록은 기존 랭킹 서버를 유지한다.

## 제출 시점

| 화면 | 동작 |
|---|---|
| TimeUp 진입 | `submit()` fire-and-forget. 결과 패널에 메시지/재제출 |
| TimeUp 나가기 | 제출 완료를 기다리지 않고 타이틀 |
| 일시정지 나가기 | 타임/레벨이면 `submit()`를 await한 뒤 타이틀. 제출 중 재탭 차단 |
| 일시정지 재시도 | 제출하지 않음 |
| 레벨 클리어 | 제출하지 않음. 런이 끝나야 완료 레벨이 확정된다 |

## HUD

- 왕관 버튼과 `RankingService.fetchTop1()`는 타임 모드만. 기본 query mode=time
- 레벨/무한 HUD에는 랭킹 버튼이 없다
- 타이틀 랭킹 팝업에서 타임/레벨 목록을 본다

## 실패

서버 없음, 404, load/save 실패는 문구와 재제출만 제공한다. 보드 진행과 타이틀 복귀를 막지 않는다.

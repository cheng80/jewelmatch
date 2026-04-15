# 작업 세션 시작 — 여기부터 읽기

> **역할:** 새 대화를 열어 작업을 이어갈 때 **가장 먼저** 읽는 문서다.  
> **무엇을 먼저 읽을지 / 바로 다음에 무엇을 할지**만 빠르게 안내한다. 완료 이력·구조 설명·세부 정책은 각 전용 문서에서 확인한다.

---

## 대화 시작 시 한 줄

**「`START_HERE.md`와 `docs/jewel_match_execution_checklist.md`를 읽고, §1 문서 순서대로 훑은 뒤 §3 우선 작업부터 진행하자.」**

---

## 1. 필수 읽기 순서

| 순서 | 문서 | 할 일 |
|:---:|:---|:---|
| 1 | **이 파일** (`START_HERE.md`) | §2 현재 포커스, §3 다음 작업만 먼저 확인 |
| 2 | [`docs/jewel_match_execution_checklist.md`](docs/jewel_match_execution_checklist.md) | 체크 안 된 항목·보류 항목 확인 |
| 3 | [`README.md`](README.md) | 디렉터리 구조, 라우팅, 빌드 명령 |
| 4 | [`docs/game_flow.md`](docs/game_flow.md) | 매치 규칙·모드·오버레이 플로우 |
| 5 | [`docs/code-flow-analysis.md`](docs/code-flow-analysis.md) | `main` → `GameView` → `MatchBoardGame` 초기화·파일 역할 |
| 6 | [`docs/web_build.md`](docs/web_build.md) | Web `--base-href`·배포 시 주의 (서브패스 `/match/` 등) |
| 7 | [`docs/audio_aisfx_prompts.md`](docs/audio_aisfx_prompts.md) | SFX·BGM 파일명·프롬프트·코드 매핑 변경 시 |
| 8 | [`docs/web_audio_flutter_flame.md`](docs/web_audio_flutter_flame.md) | Web 오디오 정책 메모 — 현재는 **최소 unlock 정책**, 고급 대응은 참고용 |

---

## 2. 현재 포커스

- 현재 우선순위는 **최적화 후속 점검과 배포 전 정합 확인**이다.
- 구조·완료 이력은 [`docs/code-flow-analysis.md`](docs/code-flow-analysis.md), [`docs/game_flow.md`](docs/game_flow.md), [`docs/jewel_match_execution_checklist.md`](docs/jewel_match_execution_checklist.md)에 정리되어 있다.
- Web 작업 시 핵심 쟁점은 `base-href`, 에셋 경로, 랭킹 API 경로, 오디오 unlock 정책이다.
- 최근 코드상 주의 포인트:
  - 보석 시트는 `Jewel.png` `128×128` 기준이며 하이퍼는 2번째 프레임이다.
  - 특수 보석 시트는 `Special.png` `128×128` 기준이며 순서는 `col / row / bomb`다.
  - 설정/랭킹 UI는 Riverpod `select` 기반으로 구독 범위를 줄인 상태다.

---

## 3. 지금 가장 중요한 작업 (우선순위)

새 세션에서 바로 확인할 것:

1. **[`docs/jewel_match_execution_checklist.md`](docs/jewel_match_execution_checklist.md)** 의 미체크 항목 확인.
2. **랭킹:** NAS `matchranking/` 경로·`ranking_data.json` 쓰기 권한·`RankingService` base URL이 실제 배포와 일치하는지.
3. 체크리스트의 **후속 최적화 점검** 항목
   - 전체 `ConsumerWidget` / `setState` rebuild 범위 재점검
   - DevTools 기준 rebuild hotspot / frame drop 계측
   - 계측 결과 기반 추가 분리 여부 판단

단기적으로 자주 나오는 작업:

- Web 릴리즈: `docs/web_build.md` 명령으로 빌드 → `build/web/` 업로드 경로와 `base-href` 일치 검증. **`matchranking/`는 플러터 웹 빌드 업로드와 별도 경로에 두기 (배포 시 JSON 유실 방지).**
- 오디오 교체: 파일 추가 후 `AssetPaths`·`SoundManager.preload`·`audio_aisfx_prompts.md` 함께 수정.
- 번역·도움말 문구 추가 시 `assets/translations/*.json` 다국어 동시 반영.

---

## 4. 핵심 코드 위치 (빠른 점프)

| 영역 | 경로 |
|:---|:---|
| 라우팅 | `lib/router.dart` |
| 타이틀·게임·설정 화면 | `lib/views/title_view.dart`, `game_view.dart`, `setting_view.dart` |
| **오버레이 (분리됨)** | `lib/views/overlays/` — `time_up_overlay.dart`, `pause_menu_overlay.dart`, `no_moves_overlay.dart`, `how_to_play_overlay.dart` |
| **ViewModel (Riverpod)** | `lib/vm/settings_notifier.dart`, `ranking_notifier.dart` |
| **공통 위젯** | `lib/widgets/lumina_buttons.dart`, `lumina_overlay_card.dart`, `phone_frame_scaffold.dart` |
| **배경 싱글톤** | `lib/widgets/starry_background.dart` (`StarryBackground.instance`) |
| **반응형 프레임** | `lib/widgets/phone_frame_scaffold.dart` (`PhoneFrameScaffold` + `PhoneFrame`) |
| Flame 게임 엔트리 | `lib/game/match_board_game.dart` |
| 매치 로직 | `lib/game/match_board_logic.dart` |
| HUD | `lib/game/components/match_game_hud.dart` |
| 렌더 | `lib/game/components/match_board_renderer.dart` |
| 파티클 | `lib/game/components/particle_burst.dart` |
| 사운드 | `lib/resources/sound_manager.dart`, `asset_paths.dart` — 웹 이슈는 [`docs/web_audio_flutter_flame.md`](docs/web_audio_flutter_flame.md) |
| 랭킹 API·클라이언트 | `lib/services/ranking_service.dart`, 서버 `matchranking/ranking.php` |

---

## 5. 세션 종료 전 갱신 규칙

작업을 끊기 전에 최소한 아래를 갱신한다.

1. 끝낸 일이 있으면 [`docs/jewel_match_execution_checklist.md`](docs/jewel_match_execution_checklist.md) 체크박스 갱신.
2. 플로우·초기화·큰 책임 변경이 있으면 [`docs/code-flow-analysis.md`](docs/code-flow-analysis.md) 또는 [`docs/game_flow.md`](docs/game_flow.md) 중 해당 부분 수정.
3. 오디오 파일명·용도를 바꿨으면 [`docs/audio_aisfx_prompts.md`](docs/audio_aisfx_prompts.md) 수정.
4. Web 배포 절차·URL 정책이 바뀌었으면 [`docs/web_build.md`](docs/web_build.md) 수정.
5. **다음에 이어질 수 있게 이 파일의 §2·§3을 최신 상태로 유지.**

---

## 6. 한 줄 요약

**다음 세션은 `START_HERE.md` → 체크리스트 → `game_flow` / `code-flow-analysis` 순으로 읽고, Web은 `base-href`·에셋 경로·랭킹 API URL·NAS 배포 분리, 네이티브는 스토어·오디오·문서 동기화를 우선 보면 된다.**

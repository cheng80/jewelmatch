# Stone Match 문서 맵

문서는 목적별로 묶는다. 새 문서를 추가할 때도 같은 기준을 따른다.

## 먼저 읽기

| 문서 | 용도 |
|------|------|
| [`../START_HERE.md`](../START_HERE.md) | 새 세션 시작 순서와 현재 우선순위 |
| [`planning/stone_match_execution_checklist.md`](planning/stone_match_execution_checklist.md) | 진행·배포 체크리스트 |
| [`../README.md`](../README.md) | 프로젝트 개요, 실행, 빌드 명령 |

## 구조·게임 규칙

| 문서 | 용도 |
|------|------|
| [`architecture/code-flow-analysis.md`](architecture/code-flow-analysis.md) | 앱 초기화, 화면, Flame 계층, 주요 파일 역할 |
| [`architecture/game_flow.md`](architecture/game_flow.md) | 매치-3 규칙, 모드, 오버레이 흐름 |
| [`architecture/special_gems_rules.md`](architecture/special_gems_rules.md) | 특수 보석 생성, 탭 발동, 연쇄, 하이퍼 처리 규칙 |
| [`architecture/progression_score_targets.md`](architecture/progression_score_targets.md) | 진행 모드 레벨별 목표 점수 산식 |

## 기획

| 문서 | 용도 |
|------|------|
| [`planning/item_slot_market_plan.md`](planning/item_slot_market_plan.md) | 아이템 슬롯, 인벤토리, 보상형 광고, 선택형 코인/인앱 플랜 |
| [`planning/stage_reward_system.md`](planning/stage_reward_system.md) | 레벨 클리어 후 스테이지 아이템 보상 지급 규칙 |
| [`planning/item_slot_market_implementation_checklist.md`](planning/item_slot_market_implementation_checklist.md) | 아이템 슬롯·인벤토리 플랜의 단계별 상세 구현 체크리스트 |
| [`planning/stone_match_execution_checklist.md`](planning/stone_match_execution_checklist.md) | 진행·배포 체크리스트 |

## 기술·운용 문서

| 문서 | 용도 |
|------|------|
| [`tools/web_build.md`](tools/web_build.md) | Web 릴리즈 빌드, `/match/` base-href, 배포 절차 |
| [`tools/android_gradle_migration.md`](tools/android_gradle_migration.md) | Android Gradle/Kotlin DSL 현재 설정과 변경 체크 |
| [`tools/ios_profile_build.md`](tools/ios_profile_build.md) | iOS 프로필 빌드와 실기기 설치 |
| [`tools/version_display_and_settings.md`](tools/version_display_and_settings.md) | 설정 화면 구조와 타이틀 하단 버전 표시 정책 |
| [`tools/audio_aisfx_prompts.md`](tools/audio_aisfx_prompts.md) | SFX·BGM 생성 프롬프트와 코드 매핑 |
| [`tools/web_audio_flutter_flame.md`](tools/web_audio_flutter_flame.md) | Flutter Web + Flame 오디오 정책과 회귀 대응 |
| [`tools/supertonic_tts_sfx.md`](tools/supertonic_tts_sfx.md) | Supertonic TTS 임시 SFX 생성 방법 |
| [`tools/tutorial_showcaseview_guide.md`](tools/tutorial_showcaseview_guide.md) | 온보딩 튜토리얼 도입 후보와 제약 |

## 릴리즈·스토어

| 문서 | 용도 |
|------|------|
| [`release/release_checklist.md`](release/release_checklist.md) | Google Play / App Store / Web 출시 체크리스트 |
| [`release/release_build.md`](release/release_build.md) | Android AAB/APK, iOS IPA, Web 릴리즈 빌드 |
| [`release/store_metadata_play_appstore_2026.md`](release/store_metadata_play_appstore_2026.md) | Play/App Store 등록 메타데이터 초안 |
| [`release/screenshot_promo_copy_ko_en.md`](release/screenshot_promo_copy_ko_en.md) | 마켓 스크린샷 문구 KO/EN |
| [`release/in_app_review.md`](release/in_app_review.md) | 인앱 리뷰 정책과 현재 구현 |

## 디자인·성능

| 문서 | 용도 |
|------|------|
| [`../DESIGN.md`](../DESIGN.md) | 제품 UI 톤과 디자인 원칙 |
| [`design/new_gem_design_review.md`](design/new_gem_design_review.md) | 새 보석 시각 방향 검토 |
| [`performance/fps_drop_simulation_plan.md`](performance/fps_drop_simulation_plan.md) | FPS 드롭 계측 계획 |

## 참고 이미지

- `design/new_gem_concepts/`: 보석 콘셉트 생성 이미지
- `reference_images/`: 기존 UI 참고 이미지
- `screenshots/`: 문서용 스크린샷

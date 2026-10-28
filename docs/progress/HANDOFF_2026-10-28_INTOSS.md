# 앱인토스 공통 게임 코드 인계

기준일: 2026-10-28. 이 문서는 게임 저장소에 남기는 앱인토스 채널 구현과 검증 범위다.

## 두 프로젝트의 역할

공통 게임 코드, 채널 구현, 테스트/빌드 도구와 게임 명세는 이 저장소에서 관리한다. 앱인토스 등록, 콘솔/광고 운영, 테스트 배포, 출시 자료와 대화 인계는 `/Users/cheng80/Desktop/AppInToss_Flutter`의 별도 저장소에서 관리한다. 이 경로는 관리 자료의 위치이며 게임 개발 문서의 읽기 순서를 바꾸지 않는다.

게임 코드 수정은 이 저장소에서, 관리 자료 수정은 해당 저장소에서 각각 커밋한다. 두 저장소는 별도 Git 이력을 사용하며 게임 소스 복제, submodule이나 symlink를 추가하지 않았다.

## 구현과 유지할 계약

- [채널 설정](../../lib/app_config.dart): `STORE_CHANNEL=appstore|play|onestore|intoss`, 기본값 `play`. 광고 모드는 disabled/mock/test/production이다.
- [광고 서비스](../../lib/ads/intoss_ad_service_web.dart)와 [JS 브리지](../../web/intoss_ads.js): 보상형 이어하기, 아이템 보충과 무한 모드 배너. 보상은 광고 완료 결과에서만 지급하며 NAS 일반 웹에는 광고를 노출하지 않는다.
- [리더보드 서비스](../../lib/services/intoss_leaderboard_service.dart): intoss 채널의 레벨 모드에서만 양수인 완료 레벨 수를 공식 리더보드에 제출한다. 타임 점수는 공식 리더보드에 보내지 않는다.
- [공통 랭킹 제출](../../lib/vm/ranking_notifier.dart)과 [랭킹 팝업](../../lib/widgets/ranking_list_popup.dart): 자체 레벨/타임 랭킹을 유지한다. Pause 나가기는 await, TimeUp 나가기는 기다리지 않으며 장애가 플레이/이탈을 막지 않는다.
- [백엔드 선택](../../lib/services/backend/backend_selector.dart): PocketBase 단독 런타임. 공개 URL은 Git 제외 `config/pocketbase.json`을 통해 빌드에 전달하며 관리자 자격정보는 포함하지 않는다.
- [브리지 주입 도구](../../tools/prepare_intoss_web.mjs)와 [빌드 스크립트](../../package.json): 토스 SDK는 앱인토스 빌드에 주입한다. 일반 NAS 웹 빌드와 구분한다.
- [오디오 관리자](../../lib/resources/sound_manager.dart)와 [웹 SFX](../../web/stone_match_sfx.js): 4슬롯 SFX와 복귀 재생 수정 유지. 성능 측정에서도 BGM/SFX ON을 유지한다.

## 다음 코드 검증

1. [작업 규칙](../AGENTS.md), [현재 상태](PROJECT_STATUS.md), 관련 명세/PLAN을 읽고 현재 Git 상태를 확인한다.
2. 현재 PocketBase 공개 설정으로 관련 Flutter 테스트/analyze와 `INTOSS_APP_NAME=stonematch npm run build:intoss:test`를 검증한다. 이 명령은 게임 저장소 루트에서 실행한다.
3. 새 AIT의 실기기 광고/보상/배너, 자체 랭킹과 공식 레벨 랭킹, 백그라운드/결과창/다시 하기 오디오를 확인한다. 장시간 FPS와 광고/특수효과 A/B는 사운드 ON으로 측정한다.
4. 코드나 계약이 바뀌면 이 저장소의 관련 Spec/Status/Handoff를 갱신한다. 업로드/콘솔/출시 결과는 관리 프로젝트에 기록한다.

빌드와 배포 명령의 코드 기준은 [개발 워크플로](../04_DEVELOPMENT_WORKFLOW.md), 장시간 회귀 기준은 [PLAN-001](../plans/PLAN-001-mobile-web-audio-fps.md)이다. 패키징 성공과 원격 배포/실기기 성공을 구분한다.

## 검증과 분리 이력

2026-10-28 최초 점검에서 Node12테스트와 JS3파일 구문 검사가 통과했다. 이번 문서 분리에서는 링크/코드 펜스/공백/staged diff를 검증하고 Flutter/AIT/실기기와 원격 상태는 재검증하지 않았다. 과거 결과를 최신 빌드 통과로 표시하지 않는다.

앞선 로컬 문서 커밋 `62921ba`는 이력으로 보존한다. 그 커밋의 상세 콘솔/대화 기록은 관리 프로젝트 HANDOFF.md에 보존하고 이 문서를 공통 코드 범위로 정리했다. 제품 코드, 데이터와 빌드 산출물은 변경하지 않았다. push/PR/배포는 수행하지 않는다.

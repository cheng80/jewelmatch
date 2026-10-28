# Stone Match 앱인토스 작업 핸드오프

기준일: 2026-10-28 KST. 현재 로컬 파일, Git 참조와 토스 콘솔을 확인하고, 관련 기존 대화 3개의 전체 100개 턴을 대조했다. 후속 커밋 요청에 따라 이 내용을 실제 게임 저장소에 보존하고 현재 상태 요약도 정합화한다.

**앱인토스 광고와 레벨 리더보드 코드는 구현돼 있다. 실제 개발은 `jewelmatch` 저장소에서 이어가야 하며, 최신 PocketBase 코드의 토스 실기기 검증과 최초 출시 절차가 남아 있다.** 토스 콘솔의 최신 번들은 아직 2026-09-24 Supabase 테스트 버전이다.

## 1. 작업 위치와 Git 상태

| 구분 | 2026-10-28 확인 결과 |
|---|---|
| 현재 채팅 작업 폴더 | `/Users/cheng80/Desktop/AppInToss_Flutter` |
| 점검 시작 시 폴더 상태 | 파일 없음, `.git` 없음. 이번 작업에서 이 `HANDOFF.md`만 추가 |
| 실제 게임 저장소 | `/Users/cheng80/Desktop/Anther_Works/Flutter_Project/FlutterFrame_work/jewelmatch` |
| 제품명 | Stone Match, 한국어 스톤매치. `jewelmatch`는 기존 폴더와 저장소 식별자 |
| Git remote | `https://github.com/cheng80/jewelmatch.git` |
| 게임 브랜치와 HEAD | `main`, `e259e36e3b2d1b3a8c348bbebbb8bbb76f15dadd` |
| 마지막 게임 저장소 커밋 | 2026-10-23, `문서: GA4와 운영 대시보드 완료 상태 정리` |
| 로컬 변경과 워크트리 | 추적/미추적 변경 없음, Git 워크트리는 `main` 1개 |
| 원격 비교 범위 | 로컬 `origin/main` 참조와 HEAD 일치. 이번 점검에서 `git fetch`는 실행하지 않음 |
| 별도 대시보드 저장소 | `/Users/cheng80/Desktop/Anther_Works/Flutter_Project/FlutterFrame_work/stomematch_dashboard` |
| 대시보드 Git | `main`, `8d41a73`, 변경 없음. 로컬 상태 출력상 `origin/main`과 일치 |

현재 폴더가 빈 것은 과거 실험 복제본 `stone_match_intoss`를 제거하고 **단일 게임 코드베이스의 4채널 분기**로 바꾼 결정과 일치한다. 빈 폴더를 게임 코드 유실이나 미구현으로 판단하지 않는다. 과거 대화의 임시 워크트리 경로도 재개 위치가 아니다.

## 2. 토스 콘솔 최신 상태

아래는 과거 대화 인용이 아니라 이번 MCP 읽기 조회 결과다. 앱/광고 설정 변경, 업로드, 테스트 푸시와 검토 요청은 실행하지 않았다.

| 항목 | 확인 결과 |
|---|---|
| 워크스페이스 | 김택권 워크스페이스, `28591` |
| 미니앱 | 스톤매치, `miniAppId=64685`, `appName=stonematch` |
| 유형과 상태 | 게임, `게임>퍼즐`, `PREPARE` |
| 최초 출시 | `firstReleaseDate=null`, 라이브 버전 없음, `isDeployed=false` |
| 앱정보 검토 | `BEFORE_FIRST_REVIEW`, `isInitialRegistrationCompleted=false` |
| 번들 상태 | 등록 번들 있음, 검토 중 번들 없음 |
| 출시 판정 | `WORKSPACE_TERMS_AGREEMENT_REQUIRED` |
| 번들 검토 판정 | `MINI_APP_BEFORE_FIRST_APPROVAL` |
| 광고 그룹 조회 | `인앱광고 약관 동의가 되지 않았어요` 오류. 그룹 유무와 실제 ID는 확인 불가 |

최신 등록 번들:

- 버전 `20260924-16`, deploymentId `01a0cf90-3f74-7371-9055-43700af3daae`.
- 메모: `Supabase 백엔드 적용 테스트 빌드(테스트 광고 ID)`.
- SDK `3.0.3`, `reviewStatus=CREATED`, `isTested=false`, `deployed=false`.
- 따라서 현재 저장소의 PocketBase 이전과 10월 수정이 토스에 올라갔다고 판단하면 안 된다.

이전 `20260816-15` 레벨 리더보드 테스트2와 `20260816-14` 테스트 번들은 `isTested=true`다. 이 표시는 테스트 환경 준비 이력이며 실제 기능 성공, 최신 버전 검증이나 출시 승인의 증거가 아니다.

후속 출시에서는 콘솔 웹에서 대표관리자가 제휴 약관과 광고 약관을 처리해야 한다. 최초 등록이 완료되지 않았으므로 앱정보와 번들의 최초 검토 흐름을 사용한다. 실제 화면에서 등급 증빙, 등록 이미지와 입력값도 확인한다. `requiresFeatureRegistration=true`는 별도 주요기능 등록 상태이며 필수 출시 차단 조건으로 확대하지 않는다.

## 3. 기존 대화에서 확정된 결정

| 시기, 대화 | 최종 결정과 결과 |
|---|---|
| 2026-08-14, 앱인토스 게임 등록 방법 조사 | Flutter/Flame 템플릿과 게임 Web/AIT 패키징을 시험했다. 처음 만든 `stone_match_intoss` 복제본은 이후 제거하고 원본 게임에 채널 분기를 적용했다 |
| 같은 대화 | `STORE_CHANNEL=appstore\|play\|onestore\|intoss` 사용. 사용자 표시명은 Stone Match, 토스 `appName`은 `stonematch` |
| 같은 대화 | Play와 One Store는 `com.cheng80.stonematch`, 공통 JKS `stonematch_keystore.jks`, alias `stonematch_key`를 사용하는 방향으로 정했다. 실제 서명 빌드 완료와 구분한다 |
| 2026-08-14~15, 앱인토스 광고 적용 환경 구축 | 보상형 이어하기, 아이템 보충, 무한 모드 하단 배너와 mock/test/production 환경을 구현하고 main에 반영했다. 테스트 AIT 배포 이력도 있다 |
| 같은 대화 | iPhone 성능 저하와 효과음 중단을 조사했다. 반복 오디오 프라이밍, 플레이어 증가, 자산 경로 문제를 수정하고 고정 4슬롯 SFX로 바꿨다 |
| 같은 대화의 사용자 지시 | 성능 측정에서도 BGM과 효과음 ON을 유지한다. 효과음 OFF를 해결책이나 정식 비교 조건으로 쓰지 않는다. 실제 터치 없이 잠긴 오디오의 무음 측정은 유효한 결과에서 제외한다 |
| 2026-08-16, 앱인토스 리더보드 연동 조사 | 초기 타임 점수 제안은 이후 변경됐다. 최종 계약은 게임 내 레벨/타임 랭킹을 유지하고 토스 공식 랭킹에는 레벨 완료 수만 추가 제출하는 것 |
| 같은 대화 | 공식 레벨 랭킹 안내/열기 버튼, 제출 실패 피드백과 자체 랭킹 재시도 UI를 구현하고 main에 반영했다 |
| 같은 대화 | 결과창에서 백그라운드 복귀 후 다시 하기 때 BGM/SFX가 복구되지 않는 웹 공통 문제를 수정했다. 사용자 NAS 모바일 확인에서 다시 하기 BGM 복구를 확인했고 이식용 성능 문서에도 반영했다 |

8월의 PHP 유지 제안, 세션 로컬 광고 제한, 타임 점수를 토스에 제출한다는 초기 제안은 현재 구현 기준이 아니다. 이후 9월의 게임 방향 개편과 PocketBase 이전 상태를 우선한다.

## 4. 현재 구현과 배포 범위

| 영역 | 현재 확인한 상태 | 남은 확인 |
|---|---|---|
| 채널 분기 | `lib/app_config.dart`의 4채널, 기본값 `play`. 잘못된 광고 모드/채널 조합과 운영 ID 누락을 검증 | 실제 마켓별 출시 빌드 |
| 앱인토스 광고 | `IntossAdService`, JS 브리지, mock/test/production 경로 존재. 운영 빌드는 보상형/배너 ID를 모두 요구 | 약관 동의, 운영 그룹 확인, 최신 토스 실기기 광고와 보상 검증 |
| 광고 정책 | 이어하기, 아이템 보충, 무한 모드 배너. 보상은 완료 결과에서만 지급. NAS 일반 웹은 광고 없음 | 최신 배너 숨김/복귀, 보상 중복 방지, 서버 제한 실기기 확인 |
| 공식 리더보드 | `StoreChannel.intoss`와 `RankingMode.level`에서만 양수 기록 제출. `Game.setLeaderboardScore`, `Game.openLeaderboard` 사용 | 최신 번들에서 실제 제출/조회와 실패 후 복귀 |
| 자체 랭킹 | PocketBase 사용. 토스 공식 랭킹과 별도로 레벨/타임 랭킹 유지 | 토스 Origin 인증/조회/제출 종단 확인 |
| 점수 계약 | 레벨은 완료한 레벨 수. 레벨1 미완료는0, 레벨4 종료는3. 타임은 점수와 주간 랭킹 | 새 버전 실기기 결과값 대조 |
| 제출 시점 | TimeUp 진입 또는 Pause 나가기. Pause 나가기는 await, TimeUp 나가기는 기다리지 않음. 장애가 플레이/이탈을 막지 않음 | 실제 토스 화면 전환 회귀 |
| 백엔드 | `BackendSelector`는 `PocketBaseGateway`. 기본 운영 주소는 `https://stonematch-pb.fastmake.net` | 이번 점검에서 운영 서버 health/데이터를 재조회하지 않음 |
| 게임 개편 | 일일 동일 보드, 주간 타임 랭킹, 도전 스테이지, 실험 스위치와 플레이 중 인벤토리 등이 main 반영 | D7 시간 보상 채택을 위한 사용자 플레이테스트 |
| 오디오/FPS | 4슬롯 SFX, 복귀와 BGM 재시작 수정 존재. 단기 확인 이력 있음 | iPhone 토스 WebView에서 사운드 ON 장시간 회귀, 광고/특수효과 A/B |
| 관측 | 문서상 NAS PocketBase 이벤트, GA4, Sentry와 독립 대시보드 기본 운영 배포 완료 | GA4 상세 리텐션/퍼널 등 확장. GA4 native/intoss는 현재 비활성 |

토스 코드의 주요 연결 위치:

- [앱 설정](../../lib/app_config.dart)
- [광고 Dart 구현](../../lib/ads/intoss_ad_service_web.dart)
- [광고와 리더보드 JS 브리지](../../web/intoss_ads.js)
- [브리지 번들 주입](../../tools/prepare_intoss_web.mjs)
- [공식 리더보드 서비스](../../lib/services/intoss_leaderboard_service.dart)
- [공통 랭킹 제출](../../lib/vm/ranking_notifier.dart)
- [랭킹 팝업](../../lib/widgets/ranking_list_popup.dart)
- [오디오 관리](../../lib/resources/sound_manager.dart)
- [웹 효과음](../../web/stone_match_sfx.js)

## 5. 로컬 빌드 환경과 산출물

- Flutter 캐시 메타데이터: `3.47.6 stable`, Dart `3.13.5`. 버전 명령과 빌드 실행으로 재확인한 값은 아니다.
- Node 실제 실행 버전: `v24.22.1`.
- 프로젝트 버전: `1.0.0+1`, `flame: ^1.35.1`.
- `package.json`과 설치된 Apps in Toss SDK 모두 `3.0.3`.
- `node_modules`와 Git 제외 `config/pocketbase.json`은 존재한다. 공개 백엔드 URL 설정과 관리자 자격정보를 혼동하지 않는다.
- `.env.intoss`와 `build/web`은 현재 없다. 운영 ID가 다른 환경에 있는지는 확인하지 않았다.
- 로컬 `stonematch.ait`: 33,856,736바이트, 수정 시각 2026-09-24 03:38:53 KST.
- 로컬 `match.zip`: 33,285,230바이트, 수정 시각 2026-09-24 11:34:32 KST.
- 위 파일은 10월 수정 이전 산출물이다. 최신 배포용으로 사용하려면 다시 빌드하고 새 해시/버전을 기록한다.
- 과거 최초 첨부 경로의 `flutter_web_apps_in_toss_guide.md`와 `flame_templete_app.zip`은 현재 해당 위치에 없다. 현재 코드와 정본 문서로 작업을 재개할 수 있다.
- 게임 저장소에 `.github/workflows`는 없다. 대시보드의 CI 완료 기록을 게임 CI 실행 결과로 취급하지 않는다.

현재 스크립트 기준 테스트 빌드 명령은 아래와 같다. 이번 점검에서는 실행하지 않았다.

```bash
cd /Users/cheng80/Desktop/Anther_Works/Flutter_Project/FlutterFrame_work/jewelmatch
INTOSS_APP_NAME=stonematch npm run build:intoss:test
shasum -a 256 stonematch.ait
```

이 명령은 테스트 광고 ID로 Flutter Web을 빌드하고 브리지를 주입한 뒤 AIT를 생성한다. **패키징 성공과 원격 테스트 배포 성공을 구분한다.** `config/pocketbase.json`이 없으면 테스트 빌드에서 백엔드 설정이 빠질 수 있으므로 구성도 확인한다.

후속 요청으로 테스트 배포할 때는 다음 명령을 사용한다. 실제 업로드를 만드는 명령이므로 이번 상태 점검에서는 실행하지 않았다.

```bash
npx ait deploy \
  --location ./stonematch.ait \
  --scheme-only \
  --memo "PocketBase 전환 후 광고 및 레벨 리더보드 실기기 확인"
```

운영 광고 빌드는 `.env.intoss`의 `INTOSS_APP_NAME`, `INTOSS_REWARDED_AD_GROUP_ID`, `INTOSS_BANNER_AD_GROUP_ID`와 공개 PocketBase 설정을 준비하고 `npm run build:intoss`를 실행하는 경로다. API 키/관리자 암호를 이 문서나 앱 빌드에 넣지 않는다.

## 6. 기존 상태 문서에서 주의할 충돌

정본은 실제 게임 저장소의 `docs/`다. 다만 상태 문서에 이전 기록이 누적돼 있어 아래 항목을 최신 사실과 구별해야 한다. 최초 조사에서는 충돌을 이 핸드오프에 명시했고, 후속 커밋 작업에서 PROJECT_STATUS의 Active Plan, Blocked / Known Issues와 Next를 최신 사실에 맞췄다. 이전 날짜의 상세 이력과 ADR 원문은 보존했다.

| 남아 있는 표현 | 현재 우선할 사실 |
|---|---|
| `PROJECT_STATUS.md` Active Plan의 PLAN-006 Supabase 진행 중, Next의 Supabase 무료 요금제 | 런타임은 PocketBase이며 PLAN-013 `DONE`. Supabase/PHP는 이전 이력 |
| Active Plan의 PLAN-009 Step4 미완료 | PLAN-009 본문 상태 `DONE`, 9월29일 배포/복원 검증 완료 기록 |
| Active Plan의 PLAN-012 `DRAFT` | PLAN-012와 최신 Status/Roadmap에 NAS 오류 수집 배포 완료 기록 |
| PLAN-005 Step2 연결이 남았다는 표현 | Current Tasks의 TASK-005d와 최신 요약에는 아이템/이어하기 이벤트 연결 완료. D7 플레이테스트가 남음 |
| 초기 ADR-003의 세션 로컬 보충 제한, ISSUE-003의 Supabase 제한 | 현재 PocketBase 서버 제한 계약을 우선. 계정 연결/복구와 영속 인벤토리는 별도 미완료 범위 |
| 8월 대화의 `docs/tools/*`, `docs/release/release_build.md`, `docs/performance/*` | 표준 문서 팩으로 본문 이관. `docs/04_DEVELOPMENT_WORKFLOW.md`, `03_TECH_SPEC.md`, PLAN-001을 먼저 읽음. 원문은 `archive/docs/`에 보존 |
| 과거 테스트/AIT 업로드 성공 | 최신 코드 토스 실기기 성공이나 최초 출시 승인을 의미하지 않음 |

## 7. 최초 상태 점검의 검증과 한계

| 이번 실행/확인 | 결과 |
|---|---|
| 게임/대시보드 Git 상태와 최근 로그 | 둘 다 변경 없음. 게임 HEAD와 로컬 origin/main 일치, 게임 워크트리1개 |
| 토스 콘솔 읽기 | 워크스페이스, 미니앱, 검토/출시 판정, 최신 번들 확인 |
| 광고 그룹 조회 | 약관 미동의 오류로 확인 불가 |
| `node --test test/web/stone_match_sfx_test.mjs tools/play_bot.test.mjs` 해당 테스트 | SFX3개, 플레이 봇4개 통과 |
| `node --test tools/pocketbase/verification_admin.test.mjs` | 원본 저장소에서는 fixture용 `tmp` 생성 권한으로4개 실패. 필요한 모듈/테스트를 `/private/tmp`에 그대로 복사하고 기존 의존성을 연결한 격리 재실행에서5개 모두 통과 |
| 최종 Node 단위 검증 합계 | 12개 통과. 권한 오류와 제품 로직 실패를 구분 |
| JS 구문 검사 | `tools/prepare_intoss_web.mjs`, `web/intoss_ads.js`, `web/stone_match_sfx.js` 통과 |
| 기존 저장소 `git diff --check` | 통과 |

이번 작업은 상태 조사와 문서 작성이다. Flutter 전체 테스트/analyze/Web/AIT 빌드, 브라우저/실기기 플레이, NAS/PocketBase 운영 health/인증/데이터, GA4/Sentry 수집은 재검증하지 않았다. 예전 632개 Flutter 테스트 등은 해당 당시 결과이며 오늘의 통과 수치로 재사용하지 않는다.

최초 상태 점검에서는 게임/대시보드 원본 코드와 정본 문서, 원격 설정/데이터를 변경하지 않았고 커밋, push, 배포와 메시지 발송도 하지 않았다. 이후 문서 커밋 범위는 아래 10절을 따른다.

## 8. 다음 작업 순서

1. 실제 게임 저장소에서 `AGENTS.md` → `docs/AGENTS.md` → PROJECT_STATUS/HANDOFF → 관련 PLAN 순서로 읽고 Git 상태를 다시 확인한다. 현재 폴더에서 Flutter 프로젝트를 새로 만들지 않는다.
2. `PROJECT_STATUS.md`/`HANDOFF.md`의 2026-10-28 요약과 이 문서를 재개 기준으로 삼는다. 상태 충돌은 현재 요약에서 정리했으며 오래된 상세 검증 이력은 보존했다.
3. 사용자 플레이테스트로 D7 시간 보상/실험 스위치 채택을 결정한다. 9월24일의 사용자 결정상 앱 구조 개편 뒤 앱인토스 검증과 AdMob을 진행하는 순서다.
4. 앱인토스 재개 시 현재 main에서 Flutter 분석/관련 회귀 테스트와 새 테스트 AIT 빌드를 먼저 확인한다. 공개 PocketBase 설정과 토스 Origin도 점검한다.
5. 새 테스트 번들을 올린 뒤 토스가 설치된 실기기에서 레벨 완료 수 제출/공식 화면 열기, 자체 레벨/타임 랭킹, 보상 지급/제한, 배너 숨김/복귀를 확인한다. 오래된 9월 Supabase 번들로 최신 검증을 대체하지 않는다.
6. iPhone에서 BGM/SFX ON, 결과창 → 백그라운드 → 복귀 → 다시 하기, 일시정지/리더보드 왕복과 장시간 FPS를 기록한다. 실제 오디오 재생을 확인하고 측정 중 캡처 정지/발열/미러링 영향을 구별한다. GC 단일 원인으로 단정하지 않는다.
7. 출시 단계에서는 제휴/광고 약관, 운영 광고 그룹, 등급/이미지/고객지원/개인정보 입력값과 최초 검토 흐름을 확인한다. 현재 상태는 출시 준비 완료가 아니다.
8. NAS 관측 후속은 기존 GA4/Google Cloud/기본 대시보드를 재구축하지 않고 PLAN-011 상세 보고서 범위를 이어간다. 사용자 계정 연결은 PLAN-010의 별도 결정이다.

## 9. 재개용 문서와 대화 출처

- [실제 게임 작업 규칙](../../AGENTS.md)
- [현재 프로젝트 상태](../../docs/progress/PROJECT_STATUS.md)
- [기존 전체 핸드오프](../../docs/progress/HANDOFF.md)
- [빌드와 배포 워크플로](../../docs/04_DEVELOPMENT_WORKFLOW.md)
- [모바일 웹 오디오와 FPS 계획](../../docs/plans/PLAN-001-mobile-web-audio-fps.md)
- [PocketBase 이전](../../docs/plans/PLAN-013-pocketbase-migration.md)
- [광고 채널 결정](../../docs/decisions/ADR-003-rewarded-ads-only.md)
- [플레이 봇 실행 안내](../../tools/PLAY_BOT.md)

대화는 아래 제목과 ID로 다시 찾는다. 날짜는 개별 턴의 실제 대화일을 기준으로 했으며 채팅 목록의 최근 갱신일을 작업일로 사용하지 않았다.

| 기존 대화 제목 | 채팅 ID | 확인한 턴 |
|---|---|---|
| 앱인토스 게임 등록 방법 조사 | `019ffcc0-0b4c-7b92-ba9d-d02fd9c1f039` | 전체26개 |
| 앱인토스 광고 적용 환경 구축 | `01a00002-06db-7283-b57c-0d8ad04912ed` | 전체51개 |
| 앱인토스 리더보드 연동 조사 | `01a00652-843c-75a2-8494-3386a14f379f` | 전체23개 |

토스 콘솔 근거: `workspace_overview`, `miniapp_list_overview`, `miniapp_meta_status`, `miniapp_release_status`, `bundle_list` 최신5개와 `iaa_placement_group_list` 오류 응답을 2026-10-28에 읽었다.


## 10. 문서 보존과 커밋 범위

- 실제 게임 저장소의 `docs/progress/HANDOFF_2026-10-28_INTOSS.md`에 이 조사 결과를 보존한다. 기존 `HANDOFF.md`와 `PROJECT_STATUS.md` 맨 위에 최신 상태와 상세 문서 링크를 추가하고 현재 진행 표시를 정리했다.
- 기준 게임 HEAD는 `e259e36`이며 문서 커밋의 부모 리비전이다. 문서 커밋 자체의 해시는 Git 이력에서 확인한다. 앞의 clean/원격 일치 표는 문서 수정 전 점검 시점을 뜻한다.
- 후속 작업에서도 토스 앱정보, 출시 판정과 최신 번들을 재조회했고 최초 검토 전/미출시/9월24일 Supabase 테스트 버전 상태가 같았다. 광고 약관 오류는 동의 변경이 없어 재호출하지 않았다.
- 이번 커밋은 문서 3개만 포함한다. 검증은 새 문서의 로컬 링크, 코드 펜스, 공백, 변경 내용과 `git diff --check`로 한다. 7절의 Node 12개 통과는 같은 날 최초 상태 점검 결과이며 문서 편집 후 중복 실행하지 않았다.
- 제품 코드, 데이터, 빌드 산출물과 배포 설정은 변경하지 않았다. 요청 범위는 로컬 커밋이며 push, PR과 배포는 별도다.

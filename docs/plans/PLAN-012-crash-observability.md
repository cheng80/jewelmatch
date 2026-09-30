# PLAN-012 충돌과 오류 관측

## Metadata
- Plan ID: `PLAN-012`
- Status: `DONE` (2026-09-29 승인된 NAS 웹 오류 수집 범위. 네이티브/실기기 성능/알림 운영은 별도 후속 범위)
- Related Requirement: 오류 직전 행동과 판 상태 연결, 채널별 장애 진단
- Related ADR: 도구 선택은 이 플랜 Step 1에서 확정
- Owner: 오류 수집 작업자와 독립 검수자
- Updated: 2026-09-29

## 1. 목표
오류가 발생한 버전, 게임 상태와 직전 행동을 함께 확인하되 실제 충돌과 정상 종료/단순 전송 누락을 구분한다.

## 2. 범위
- 포함: 처리되지 않은 Dart/Flutter 오류, 처리한 주요 서비스 오류, 웹 JS 경계, 직전 행동과 release 식별.
- 제외: 상시 화면 녹화, 모든 OS/브라우저/토스 호스트 충돌 감지 보장. 2026-09-29 사용자 후속 요청으로 Sentry 프로젝트 생성과 연결, 별도 임시 Flutter PoC까지 실행한다.

## 3. 현재 상태 / 전제
- 원격 오류 수집이 없고 로그 일부는 debugPrint만 사용한다.
- 웹과 앱인토스는 같은 `--wasm` 릴리즈 빌드다. 빌드는 `--no-source-maps`다(`package.json` build:flutter:intoss*, `tools/deploy_match_web.sh`는 source map 옵션 없음). NAS는 `COEP require-corp`, `COOP same-origin`을 보낸다.
- 서버는 PocketBase 전용 API다. 랭킹/광고/이벤트 실패는 `BackendFailure`(notConfigured, network, unauthorized, notFound, rateLimited, rejected, server)로 분류되며 이는 치명적 오류가 아니다.
- PLAN-009의 판/이벤트 식별(run_id, round_seq, attempt_seq, session_id)과 PLAN-010의 analytics_id 규칙(원본 식별값 비전송)을 공유한다.

## 4. 공식 문서 기준 제약 (2026-09-29 조회)
| 제약 | 내용 | 근거 |
|---|---|---|
| Wasm 실행 조건 | WasmGC 지원 브라우저만 Wasm으로 실행하고 그 밖에는 같은 빌드의 JS로 실행한다. iOS의 Chrome은 WebKit이라 해당 없음. 따라서 한 배포에서 Wasm과 JS 두 스택 형태가 섞인다 | [Flutter Wasm](https://docs.flutter.dev/platform-integration/web/wasm) |
| 멀티스레드 헤더 | Wasm 멀티스레드는 COEP(credentialless 또는 require-corp)와 COOP same-origin이 필요하다. 외부 SDK 스크립트 로드와 충돌 가능 | Flutter Wasm |
| JS interop | Wasm 빌드는 dart:html, package:js를 쓰는 패키지를 컴파일하지 못한다. package:web, dart:js_interop만 가능. 비Wasm 빌드도 Wasm dry run 경고를 낸다 | Flutter Wasm |
| Wasm 기호 | 릴리즈 Wasm은 기본으로 디버그 기호를 제거하고 source map을 만들지 않는다. `--source-maps`는 `main.dart.wasm.map`, `--no-strip-wasm`은 함수 이름 유지(약 47% 크기 증가, QA용) | Flutter Wasm, Wasm production debugging 절 |
| source map 공개 금지 | `.map`을 공개 호스팅하면 DevTools가 내려받아 심볼과 경로가 노출된다. 오류 서비스에 비공개 업로드하고 배포물에서 제외 | [Flutter 웹 배포 Source maps](https://docs.flutter.dev/deployment/web#source-maps) |
| Crashlytics | `firebase_crashlytics` 5.4.0의 pub.dev 플랫폼 태그는 android, ios, macos뿐이다. 웹과 앱인토스를 수집할 수 없다 | [pub.dev firebase_crashlytics](https://pub.dev/packages/firebase_crashlytics), [FlutterFire](https://github.com/firebase/flutterfire) |
| Sentry Flutter 웹 | `sentry_flutter` 9.30.1(2026-09-22)은 web 플랫폼을 지원하고 웹에서 Sentry JavaScript SDK(10.38.0 반영 기록)를 쓴다. 8.4.0에 dart2wasm 컴파일 지원이 기록돼 있으나 pub.dev 분석 태그에는 wasm-ready가 없다 | [sentry-dart CHANGELOG](https://github.com/getsentry/sentry-dart/blob/main/CHANGELOG.md), [pub.dev sentry_flutter](https://pub.dev/packages/sentry_flutter) |
| Sentry 심볼 업로드 | Sentry Dart Plugin이 source map을 올린다(`upload_source_maps`, 웹 전용). 설명은 JS source map과 `url_prefix` 기준이며 Wasm map 기호화 지원은 문서에 명시되지 않았다. 비루트 배포(`/match/`)는 `url_prefix` 필요 | [Sentry Dart Plugin](https://docs.sentry.io/platforms/dart/guides/flutter/debug-symbols/dart-plugin/) |
| Sentry 난독화 | split-debug-info/obfuscate 사용 시 기호 업로드 필요. 웹에서는 이슈 제목이 runtimeType 기반이라 축약될 수 있다 | [Sentry Flutter 문제 해결](https://docs.sentry.io/platforms/dart/guides/flutter/troubleshooting/) |

결론: 웹/앱인토스 공통 수집 후보는 Sentry가 유일한 공식 경로다(권장안, 확정 아님). 다만 Wasm 실행 경로의 스택 기호화는 공식 features 문서에서 미지원으로 명시한다. 실제 PoC도 원본 파일/줄 복원에 실패했다. 2026-09-29 사용자가 이 제한을 수용하고 Wasm을 유지한 오류 수집만 도입하도록 승인했다. 원본 기호화 실패를 통과로 바꾸지 않으며 수집/보안/중복/성능은 별도로 검증한다. 네이티브 앱만 먼저 출시하면 Crashlytics도 후보가 된다(NEEDS-DECISION).

## 5. PoC 검증 설계 (Step 1, 외부 계정 준비 뒤 실행)
준비물(사용자 제공): Sentry 조직/프로젝트와 DSN(테스트 전용), 업로드용 auth token은 로컬 비밀 파일에만 둔다. 운영 DSN과 분리한다.

| # | 시나리오 | 방법 | 통과 기준 |
|---|---|---|---|
| P1 | 빌드 호환 | 별도 브랜치에서 `flutter build web --release --wasm --source-maps` | 빌드 종료 0, dart:html 경고 없음, `main.dart.wasm.map`과 `main.dart.js.map` 생성 |
| P2 | 헤더 호환 | 로컬 서버에서 `COEP require-corp`와 `credentialless` 각각 | SDK 스크립트 로드, 전송 요청 성공, skwasm 멀티스레드 유지(`crossOriginIsolated` 참) |
| P3 | Dart 동기 오류 | QA 버튼으로 `throw StateError` | 이슈 1건, 원본 Dart 파일/줄 복원 |
| P4 | Dart 비동기 오류 | await 없는 Future 오류, Zone/`PlatformDispatcher.onError` 경로 | 이슈 1건, 중복 없음 |
| P5 | Flutter framework 오류 | 빌드 중 예외(`FlutterError.onError`) | 이슈 1건, 위젯 문맥 |
| P6 | JS 오류 | `web/stone_match_sfx.js`와 같은 JS 경계에서 예외 | JS 이슈로 분리 기록 |
| P7 | Wasm와 JS 경로 비교 | Chrome(WasmGC)과 JS 폴백 브라우저에서 P3~P5 반복 | 두 경로 각각 기호화 결과를 표로 기록. 한쪽 성공을 다른 쪽으로 일반화하지 않음 |
| P8 | 정상 실패 비분류 | 백엔드 URL 비움, 오프라인, 429 | fatal 이슈 0건. 필요하면 breadcrumb만 |
| P9 | 장애 격리 | 잘못된 DSN, 수집 서버 차단 | 게임 시작과 플레이 정상, 첫 프레임 지연 측정 |
| P10 | 민감정보 | 토큰, device_secret, 이름 입력, URL query | 이벤트 원문에 없음 |
| P11 | 성능 | PLAN-001 방식 FPS와 로드 시간 전후 | 차이 기록. 기준은 결과 확인 후 사용자 결정 |

- 배포물 검사: 결과 ZIP에 `*.map` 없음. `tools/deploy_match_web.sh`와 외부 제출 스킬에 제외 규칙이 필요하다(구현 시 해당 소유자와 협의).
- PoC 통과 기준 미달 항목은 한계로 기록하고 실제 수집 완료로 표시하지 않는다.

## 6. 오류 문맥 계약 (도구와 무관)
- ErrorReporter 경계를 둔다. 초기화 실패나 전송 실패가 앱 실행을 막지 않는다.
- 붙일 문맥: release(앱 버전과 빌드 번호), environment(telemetry_env와 같은 값), channel, 모드/레벨, run_id, round_seq, attempt_seq, 실험 스위치 exp, Wasm/JS 실행 경로.
- 사용자 문맥: analytics_id만(PLAN-010 4.4). device_id, player_id, 토큰, 이메일, 표시명, 이름 입력 문자열, URL query 민감값은 전송 전 제거한다.
- 직전 행동: 최근 내부 이벤트 이름과 시각을 20건 이하 링 버퍼로 붙인다. params 전체는 붙이지 않는다.
- `BackendFailure`와 저장 실패는 기본으로 이슈를 만들지 않는다. 연속 실패율 같은 운영 지표는 별도 결정.
- 로그아웃과 계정 전환 시 사용자 문맥을 초기화한다(PLAN-010 4.5).
- 비정상 종료 추정은 별도 상태다. 마지막 이벤트 누락이나 round_end 부재만으로 crash라고 기록하지 않는다.
- telemetry_env가 production이 아닌 빌드는 테스트 프로젝트로만 보내거나 비활성화한다.

## 7. 구현 계획
### Step 1: 지원 범위와 최소 PoC
- [x] 최신 공식 문서의 Flutter/Wasm/JS 오류 수집 제약 확인(4절).
- [x] PoC 시나리오와 통과 기준 설계(5절).
- [x] 사용자 Sentry 가입/CLI 인증 후 조직 tk-media-m3, 팀 tk-media 아래 stone-match Flutter 프로젝트 생성, DSN 로컬 저장과 실제 QA 수신 확인.
- [x] 운영 범위: Wasm 유지, 오류 수집만 연결. tracing/profiling/replay 비활성. 유료 플랜/체험 전환 없음.
- [ ] 운영 사용량을 확인한 이벤트 예산 확정. 초기 구현은 세션 수집 상한과 재전송 폭주 방어를 둔다.
- [x] PoC 실행/실제 수집과 JS 기호화 검증. Wasm 원본 줄 복원 미지원은 사용자 명시 승인으로 수용(13~14절).

### Step 2: 오류와 문맥 연결
- [x] ErrorReporter와 초기화 실패 격리.
- [x] 6절 문맥과 링 버퍼, 민감정보 제거.
- [x] 저장 실패, 랭킹/광고 API 장애와 재시도 결과를 치명적 충돌과 구분.

### Step 3: 배포 관측과 성능
- [ ] release별 source map/네이티브 기호 비공개 업로드, 배포물에서 `.map` 제외. 테스트 알림/그룹화/재발 확인.
- [ ] 로딩과 긴 프레임 요약을 제한적으로 추가하고 모바일 웹 FPS/메모리 전후 비교.
- [x] 앱인토스 호스트/브라우저 강제 종료의 관측 한계와 미검증 기기를 명시한다.

## 8. 병렬 작업과 변경 범위
- 오류 분류/문맥 모델과 기호 업로드 조사는 병렬 가능. main 초기화와 공통 서비스 수정은 한 작업자 소유.
- 통합 뒤 독립 오류 유발 검수를 수행한다. 후속 단계는 사용자가 결과를 확인할 수 있도록 따로 보고한다.
- 예상: lib/main.dart, lib/services 오류 어댑터, 웹 초기화, 빌드 스크립트와 배포 제외 규칙.

## 9. 검증 계획
- 의도한 오류 한 건당 이슈 1건, 정상 실패를 fatal로 오분류하지 않음.
- 잘못된 DSN/오프라인/수집 중지에서도 플레이 정상. 민감정보 제거, 동일 판 추적.
- Wasm과 JS 경로 각각의 원본 파일/줄 복원, 실제 Android/iOS와 토스 WebView는 각각 검증한다.

## 10. 위험 / 미해결 사항
- NEEDS-DECISION: 도구 선택과 콘솔 정보, 운영/테스트 프로젝트 분리, 네이티브 전용 Crashlytics 병행 여부, source map 업로드 위치(로컬 배포 스크립트 vs CI).
- Wasm 스택 기호화가 불가하면 Wasm 경로는 함수 이름 수준으로 남는다. `--no-strip-wasm` 운영 적용은 크기 47% 증가로 권장하지 않는다.
- COEP와 외부 스크립트 충돌 시 헤더 변경(credentialless)은 skwasm과 광고/오디오 회귀 재검증이 필요하다.
- 상시 replay는 기본 도입하지 않는다. 필요성이 확인되면 성능/데이터 범위를 별도 검토한다.

## 11. 완료 조건
- 실제 수집/스택 복원, 중복 억제, 성능 영향, 데이터 범위 확인 후 완료.
- 자료: [Flutter Wasm](https://docs.flutter.dev/platform-integration/web/wasm), [Flutter 웹 배포](https://docs.flutter.dev/deployment/web), [Sentry Flutter](https://docs.sentry.io/platforms/dart/guides/flutter/), [Sentry Dart Plugin](https://docs.sentry.io/platforms/dart/guides/flutter/debug-symbols/dart-plugin/), [sentry-dart](https://github.com/getsentry/sentry-dart/tree/main/packages/flutter), [FlutterFire 지원 범위](https://github.com/firebase/flutterfire).


## 사용자 연결 준비 (2026-09-29)

- Git 제외 `.env.sentry`(권한 0600)를 준비했다. `SENTRY_DSN`, `SENTRY_ORG`, `SENTRY_PROJECT`, `SENTRY_AUTH_TOKEN`을 로컬에서 입력한다. 기존 파일이나 입력값을 덮어쓰지 않는다.
- 사용자는 Sentry 계정과 Flutter 프로젝트를 만들고 DSN/조직/프로젝트 slug를 준비한다. 업로드 인증 토큰은 빌드 도구 전용이며 앱 define, 배포 ZIP과 Git에 넣지 않는다.
- DSN 입력 후 우선 수집 PoC를 검증한다. 연결 값 준비는 SDK 연동이나 운영 수집 완료를 뜻하지 않는다.


## 12. Sentry 생성과 최소 PoC 실측 (2026-09-29)

- 프로젝트: `tk-media-m3/stone-match`, Flutter, id `4512169889038416`. 현재 QA 연결/PoC 용도만 사용한다. 운영 자동 수집은 활성화하지 않았다. CLI 관리 인증은 기존 저장소를 사용하며 `.env.sentry`(0600, Git 제외)에 DSN/ORG/PROJECT만 채웠다. 기존 AUTH_TOKEN은 복사하거나 출력하지 않았다.
- CLI QA info 이벤트 수신 확인: `STONE-MATCH-1`. 환경변수, 사용자 식별자와 게임 데이터를 보내지 않은 합성 이벤트다.
- PoC 소스: `tmp/sentry-poc-20260929/`, sentry_flutter 9.30.1. 게임의 pubspec/main과 배포본을 수정하지 않았다. tracing/profiling 0, 자동 세션 추적/자동 breadcrumb 꺼짐, PII 기본 수집 꺼짐, QA 환경, release `stone-match-poc@20260929`.
- `flutter build web --release --wasm --source-maps --no-web-resources-cdn` 성공. JS/Wasm map 생성. 로컬 서버만 사용하고 map 요청은 404로 막았다. JS map과 대응 JS를 Sentry CLI로 비공개 업로드했다. NAS ZIP에는 이 PoC와 map이 없다.
- ego TaskSpace 9, COOP same-origin/COEP require-corp에서 Wasm과 JS 모두 crossOriginIsolated=true. JS 경로는 같은 Chromium에서 PoC bootstrap의 dart2js build만 선택한 강제 폴백이며 실제 iOS/WebView 검증이 아니다.
- Wasm 처리한 예외 `STONE-MATCH-2` 수신, 원본 Dart 파일/줄 복원 실패(main.dart.wasm/M/line1). 별도 미처리 경로 `STONE-MATCH-3`은 WebAssembly.Exception으로 수집됐다. 의도한 sync/async 각각의 일대일 수집은 아직 통과로 표시하지 않는다.
- JS 처리한 예외 `STONE-MATCH-4` 수신, `lib/main.dart` 27/28행과 handled 함수 복원 확인. sync 경로 `STONE-MATCH-7`은 45행 복원. SDK/engine 프레임 일부는 sourcesContent 부재/매핑 경고가 남는다.
- 접근성 버튼 조작 중 Flutter engine pointer_binding.dart의 별도 TypeError(STONE-MATCH-5/6)도 관찰했다. SDK 버그로 단정하지 않으며 사용자 입력과 자동화 차이를 재현해야 한다. 의도한 오류 한 번당 정확히 1건이라는 전체 기준은 미통과다.
- 최신 공식 근거: [Sentry Flutter features](https://docs.sentry.io/platforms/dart/guides/flutter/features/)의 Wasm 스택 기호화 미지원, 웹 예외 오프라인 캐시 미지원. `sentry docs` 질의 결과와 실제 스택이 일치한다.
- P1 빌드 통과, P2 require-corp/격리 유지 확인(credentialless 미실행), P3 처리 예외는 JS 파일/줄 복원 통과/Wasm 실패, P4~P11 전체 매트릭스와 성능/민감정보 최종 검증은 미완료다. 운영 도입 완료 또는 PLAN-012 DONE으로 표시하지 않는다.
- 결과 근거: `tmp/pocketbase-followup-20260929/sentry-{wasm,js}.json`, sentry-poc-errors.json, sentry-poc-build.log. 다음 단계는 Wasm 미기호화 제한을 수용한 수집 도입 여부를 결정하고 오류 어댑터/문맥/비밀 제거를 검증하는 것이다.


## 13. 오류 수집 도입 승인과 실행 계약 (2026-09-29)

- 사용자 답변: "권장안으로 진행". Wasm 유지, 성능 추적과 화면 녹화 없이 오류 수집만 연결한다. 최소 PoC의 Wasm 원본 줄 미지원은 수용된 제약이며 JS 복원과 별도로 표시한다.
- 운영 프로젝트 stone-match, QA 프로젝트 stone-match-qa를 분리한다. Git 제외 `.env.sentry`의 SENTRY_DSN/SENTRY_TEST_DSN을 각각 사용한다. production 외 실행과 늦은 QA 진입은 운영 DSN으로 보내지 않는다.
- SDK 기본 자동 수집이 정제 경계를 우회하지 않도록 검사한다. 앱 이벤트의 원시 params와 임의 오류 메시지/URL query를 보내지 않고 허용 필드만 구성한다. PLAN-010 analytics_id 준비 전 사용자 식별 문맥은 생략한다.
- 게임 시작은 SDK 초기화/네트워크를 기다리지 않는다. SDK 자체 실패/중복/무한 전송을 막는다. 정상 BackendFailure는 충돌로 수집하지 않는다.
- 코드 소유: Orca Opus/high 오류 서비스/main/이벤트 hook/단위테스트. Sonnet/high 공개 빌드 define/심볼 업로드/패키지 제외. 조정자 docs/브라우저/운영/통합 검증. Run `run_640edb280571`.
- 응답 불가 인계 터미널은 read에서 exited 확인 후 사용자의 정리 요청에 따라 닫았다. 새로 생성한 조정용 handle `term_36c0aec9-0409-406e-adb0-e2d4c08edcc5`를 사용하며 이전 조정자 handle을 사용하지 않는다.

## 14. NAS 웹 오류 수집 배포 완료 (2026-09-29)

- 순수 Dart `sentry 9.30.1` + 자체 zone/FlutterError/window error/unhandledrejection 연결. JS SDK 전역 훅이 전송 전 정제를 우회하지 않는다. 초기화는 게임 시작을 기다리게 하지 않는다.
- 세션 20건 상한/동일 종류와 위치 5초 억제, 최근 행동20건, 정상 ClientException/TimeoutException/BackendFailure 제외. tracing/profiling/replay/metrics 비활성. 실제 장기 사용량 추세 조정은 후속 운영이다.
- 독립 검수 P2 2건(상수 JS 예외 객체로 두 번째 이후 누락, 한 줄 스택 형식 손실)을 수정하고 수정 전 실패/수정 후 통과를 확인했다. 전체 Flutter587, 오류 테스트11, 변경 파일 analyze, 빌드도구13그룹 통과. 기존 사용자 파일 analyze info2는 별개다.
- 실제 Wasm/JS handled/async/FlutterError 각 수집, JS 오류 연속2건/한 줄 프레임 수집, 메시지/사용자/요청/토큰/URL query 비전송을 확인했다. JS `qa_main.dart` 23/27/31행 복원, sourcesContent 보완 후 원본 문맥 조회 확인. Wasm 원본 미복원과 JS 런타임 일부 생성 프레임 map 범위 밖은 남은 한계다.
- 운영 `stone-match`와 QA `stone-match-qa` 분리. Sentry 서버가 원격 주소에서 지역을 파생하는 동작을 실증해 두 프로젝트 `scrubIPAddresses=true`와 `user.geo` 각 필드 제거 규칙을 적용했다. 새 이벤트에서 IP/사용자/지역 값 모두 비어 있음을 확인했다. 기존 합성 검증 이벤트에는 설정 전 지역 정보가 남을 수 있다.
- release `stone-match@1.0.0+1-bd769fb5c599`. NAS 업로드 HTTP200/OK, ZIP SHA256 `107ce4c4d892f55d583a4efe272dcb9ffe5a5c094a1d7dea5200c36ba41e6fc2`. 원격7파일 해시/COOP/COEP/MIME/deep link 일치. 실제 NAS Wasm에서 QA 오류 수신 확인.
- `.map`/`.env`는 ZIP0개, 인증 토큰은 앱에 넣지 않는다. source map은 기존 CLI 로그인으로 운영/QA 프로젝트에 비공개 업로드하며 동일 debug ID를 확인한다. 비공개 map에 Dart 원문을 포함한다.
- 수집 endpoint 차단 상태에서 게임 화면 진입과 단1회 전송 시도 확인. 네이티브/모바일/토스 실기기 FPS/메모리, 호스트 강제종료, 알림 채널/재발 운영은 검증하지 않았다. 성능 추적 기능은 이번 승인 범위에서 제외했다.
- 근거: `tmp/sentry-integration-20260929/`의 review/client-review.md, browser-wasm.json, browser-js-final.json, events-verified.json, geo-removal-verified.json, blocked-game.json/png, browser-nas.json, nas-event-verified.json, release/remote-verification.json.

## 15. Sentry 이슈 분석과 접근성 입력 보호 (2026-09-30)

- 두 프로젝트의 이슈 12개, 이벤트 29건 전체를 조회했다. 모두 09-29의 `environment=qa` 이벤트이며 조회 시점의 production 환경 이슈는 없다. 프로젝트 이름과 이벤트 환경을 구분한다.
- STONE-MATCH-1/2/3/4/7과 STONE-MATCH-QA-1~5는 CLI 연결 확인, handled/sync/async/FlutterError, 합성 JS 예외 검증 10개다. 이전 PoC 소스와 검증 이벤트 ID, release, 스택을 대조한 뒤 resolved 처리했다. 이벤트를 삭제하거나 수집 필터를 추가하지 않았다.
- [STONE-MATCH-5](https://tk-media-m3.sentry.io/issues/150203348/) 6건과 [STONE-MATCH-6](https://tk-media-m3.sentry.io/issues/150203353/) 2건은 구 PoC `stone-match-poc@20260929`의 `ClickDebouncer` 오류다. 현재 Flutter 3.47.5에서도 접근성 버튼의 동기 예외 뒤 후속 탭이 막히고 `null.a`/`null.toString` 오류가 나는 것을 재현했다. 기존 `ErrorReporter.run`만 적용한 경로도 실패한다.
- 원인은 엔진 `onClick`이 `_state`를 비운 뒤 앱 접근성 콜백을 호출하고, 콜백 예외 때문에 뒤의 `reset()`에 도달하지 않는 것이다. 오류 수집 zone이 있어도 같은 zone에서 콜백을 실행하면 예외가 엔진 호출부까지 전파될 수 있다. SDK나 엔진 파일 자체는 수정하지 않는다.
- 앱 바인딩 초기화 직후 `installSemanticsErrorGuard`를 설치한다. 기존 콜백과 이벤트 전달을 유지하고 동기 예외를 `FlutterError.reportError`로 넘긴 뒤 정상 반환한다. Sentry 설정이 없어도 입력 복구가 동작하며 원본 오류는 기존 수집 경로로 보고한다.
- 회귀 테스트 2개를 추가했다. 실제 semantics 노드의 예외 한 번 보고/후속 동작 2회, 이벤트 객체와 인자 보존을 검증한다. 관련 테스트 총30개, 전체 `flutter analyze`, 실제 게임 release Wasm/JS 빌드 통과.
- 브라우저 비교: 수정 전 JS는 오류 뒤 Count 0과 연쇄 TypeError. 수정 후 JS와 Wasm 각각 Count 2/captured 1. 수집 비활성 JS도 오류 뒤 Count 1/captured 0. 런타임은 실제 `main.dart.js`/`main.dart.wasm` 스택으로 확인했다. 가짜 DSN과 메모리 Transport를 사용하여 원격 QA 이벤트를 추가하지 않았다.
- 코드 수정은 로컬 검증 완료, 운영 미배포다. STONE-MATCH-5/6은 배포 후 확인할 수 있도록 unresolved를 유지한다. 커밋/push/배포와 해당 2건의 resolved 처리는 후속 게시 범위다. 실제 VoiceOver/TalkBack 기기는 미검증이며 Wasm 원본 줄 기호화 제한도 그대로다.
- 근거: `tmp/sentry-triage-20260930/`의 issues.json, event-audit.json, browser-comparison.json, resolved-test-issues.json, unresolved-*-project.json, tests.log, analyze.log, game-build.log. 임시 재현 앱/빌드는 같은 폴더에 보관한다.

## 16. 접근성 입력 수정 NAS 배포 (2026-10-01)

- 사용자가 커밋/push와 NAS 웹 배포를 요청했다. 구현 `ff4a030`을 main에 push한 뒤 원격 동기화0/0과 깨끗한 작업 트리에서 `tools/deploy_match_web.sh --output-dir tmp/sentry-nas-20261001`을 실행했다.
- 사전 검사 중 기존 정제 테스트의 `999` 문자열 검사가 임의 event_id와 충돌한 것을 확인해 `"score"` 필드 검사로 바꿨다. 관련30테스트와 전체 analyze 재검증 통과. 이 저장소에는 GitHub Actions 워크플로가 없어 로컬 검증을 사용했다.
- release `stone-match@1.0.0+1-367f2554d66f`, release Wasm/JS 빌드, 2개 프로젝트 소스맵 업로드와 debug ID 일치, ZIP map/env 제외 통과. NAS HTTP200/result=OK, 원격7파일 해시/격리헤더/no-cache/Wasm MIME/직접경로200 확인. ZIP SHA256 `bd873cda8369d151339bf06a31ae1d4ee9fb20054f35f0eda0d9652b36362115`.
- 운영 브라우저에서 첫 화면, 설정 이동/복귀, 새로고침, 무한 모드 보드 렌더링과 콘솔 오류/경고0 확인. 랭킹 화면은 검증 브라우저가 백엔드 접속을 ERR_BLOCKED_BY_CLIENT로 차단해 확인이 제한됐다. curl health/랭킹 API200(5행), CORS 사전 요청204로 서버 응답을 별도 확인했다. 브라우저 접근 제한을 우회하거나 서버 보안 설정을 변경하지 않았다. 음소거 상태의 사운드와 실제 VoiceOver/TalkBack 기기는 미검증이다.
- Sentry 소스맵 업로드만으로 release 객체가 생성되지 않아, 실제 배포 버전과 구현 commit을 연결해 release를 등록했다. STONE-MATCH-5/6을 이 release에서 resolved 처리했다. 기존 합성 검증 이슈10개와 합쳐 분석 대상12개 처리 완료이며, 장시간 재발 여부 검증이나 자동 모니터링을 완료했다는 뜻은 아니다.
- 근거: `tmp/sentry-deploy-20261001/`의 tests-final.log, analyze-final.log, deploy.log, browser-verification.json, sentry-release.json, sentry-resolved.json 및 `tmp/sentry-nas-20261001/remote-verification.json`.

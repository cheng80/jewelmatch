# PLAN-012 충돌과 오류 관측

## Metadata
- Plan ID: `PLAN-012`
- Status: `DRAFT`
- Related Requirement: 오류 직전 행동과 판 상태 연결, 채널별 장애 진단
- Related ADR: 도구 선택은 이 플랜 Step 1에서 확정
- Owner: 오류 수집 작업자와 독립 검수자
- Updated: 2026-09-29

## 1. 목표
오류가 발생한 버전, 게임 상태와 직전 행동을 함께 확인하되 실제 충돌과 정상 종료/단순 전송 누락을 구분한다.

## 2. 범위
- 포함: 처리되지 않은 Dart/Flutter 오류, 처리한 주요 서비스 오류, 웹 JS 경계, 직전 행동과 release 식별.
- 제외: 이번 실행의 SDK 설치/외부 서비스 설정, 상시 화면 녹화, 모든 OS/브라우저/토스 호스트 충돌 감지 보장.

## 3. 현재 상태 / 전제
- 원격 오류 수집이 없고 로그 일부는 debugPrint만 사용한다.
- Flutter Wasm과 앱인토스는 웹 실행이다. Crashlytics 네이티브 지원만으로 이 경로를 커버할 수 없다.
- Sentry 공통 수집을 우선 후보로 두며 실제 Wasm/JS 스택 복원 검증 후 결정한다. GA4와는 별도 서비스다.
- PLAN-009의 판/이벤트 식별과 PLAN-010의 분석 식별 계약을 공유한다.

## 4. 구현 계획
### Step 1: 지원 범위와 최소 PoC
- [ ] 최신 공식 SDK의 Flutter/Wasm/JS 오류 지원과 필요 버전을 확인한다.
- [ ] 테스트 빌드에서 Dart 동기/비동기/Flutter framework/JS 오류를 각각 발생시키고 수집/중복/원본 위치를 확인한다.
- [ ] 프로젝트 DSN, release/environment 정책과 실제 제공자를 확정한다. 비용은 이벤트 예산을 기준으로 확인한다.

### Step 2: 오류와 문맥 연결
- [ ] ErrorReporter 경계를 두고 초기화 실패가 앱 실행을 막지 않도록 한다.
- [ ] 분석용 ID, session/run/round/attempt, 모드/레벨/실험/버전과 최근 행동을 제한된 링 버퍼로 붙인다.
- [ ] 저장 실패, 랭킹/광고 API 장애와 재시도 결과를 치명적 충돌과 구분한다.
- [ ] 토큰, URL query의 민감값, 이메일, 닉네임, 입력 문자열을 제거한다. 로그아웃 시 사용자 문맥을 초기화한다.

### Step 3: 배포 관측과 성능
- [ ] release별 sourcemap/네이티브 심볼 업로드와 비공개 보관. 테스트 알림/그룹화/재발 확인.
- [ ] 로딩과 긴 프레임 요약을 제한적으로 추가하고 모바일 웹 FPS/메모리 전후 비교.
- [ ] 비정상 종료 추정은 별도 상태로 표시. 마지막 이벤트 누락만으로 crash라고 기록하지 않는다.
- [ ] 앱인토스 호스트/브라우저 강제 종료의 관측 한계와 미검증 기기를 명시한다.

## 5. 병렬 작업과 변경 범위
- 오류 분류/문맥 모델과 심볼 업로드 조사 병렬 가능. main 초기화와 공통 서비스 수정은 한 작업자 소유.
- 통합 뒤 독립 오류 유발 검수 수행. 후속 단계는 사용자가 결과를 확인할 수 있도록 따로 보고한다.
- 예상: lib/main.dart, lib/services 오류 어댑터, 웹 초기화, CI/build 설정.

## 6. 검증 계획
- 의도한 오류 한 건당 이슈 1건, 정상 실패를 fatal로 오분류하지 않음.
- 잘못된 DSN/오프라인/수집 중지에서도 플레이 정상. 민감정보 제거, 동일 판 추적.
- Wasm source map 원본 파일/줄 복원, 실제 Android/iOS와 토스 WebView는 각각 검증한다.

## 7. 위험 / 미해결 사항
- 서비스 선택과 콘솔 연결 정보 미정. Wasm/워커/호스트 프로세스 경계의 관측 한계.
- 상시 replay는 기본 도입하지 않는다. 필요성이 확인되면 성능/데이터 범위를 별도 검토한다.

## 8. 완료 조건
- 실제 수집/스택 복원, 중복 억제, 성능 영향, 데이터 범위 확인 후 완료.
- 자료: [FlutterFire 지원 범위](https://github.com/firebase/flutterfire), [Sentry Flutter](https://github.com/getsentry/sentry-dart/tree/main/packages/flutter), [Flutter Wasm](https://docs.flutter.dev/platform-integration/web/wasm).

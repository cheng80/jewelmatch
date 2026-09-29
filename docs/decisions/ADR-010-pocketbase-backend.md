# ADR-010 — Stone Match 전용 PocketBase 인스턴스로 이전한다

- Status: Accepted (배포 진행 상태는 PROJECT_STATUS와 PLAN-013 기준)
- Date: 2026-09-29
- Supersedes: ADR-009의 기본 서버와 사용자 인증 구현. 제품 규칙과 장애 처리는 유지한다.

## Context

사용자가 Supabase 무료 프로젝트 비활성 정지와 모바일 웹 랭킹 문제를 이유로 자체 PocketBase 이전을 요청했다. 조사 시 Supabase 공개 랭킹 API는 정상 응답했으므로 모바일 문제의 원인이 프로젝트 정지라고 확정하지 않는다. 여러 게임의 데이터와 배포를 독립적으로 운영하기 위해 게임별 인스턴스를 구분한다.

## Decision

1. Stone Match 서버는 mac-mini의 `/Users/cheng80/Servers/stonematch`, PocketBase 0.39.7이다. `127.0.0.1:8090`을 Cloudflare Tunnel의 `stonematch.fastmake.net`에 연결한다. 폴더 이름은 인스턴스 식별이며 실행 바이너리 이름은 `pocketbase`로 유지한다.
2. macOS 사용자 LaunchAgent `com.fastmake.stonematch.pocketbase`가 로그인 후 자동 실행하고 종료 시 재시작한다. 로그인 전 실행을 보장하는 LaunchDaemon으로 임의 전환하지 않는다.
3. 기존 컬렉션을 임의 변경하지 않고 게임용 `sm_players`, `sm_rankings`, `sm_ad_claims`, `sm_events`, `sm_config`를 추가한다. SQLite 마이그레이션과 JS 서버 코드는 `pocketbase/pb_migrations`, `pocketbase/pb_hooks`에서 버전 관리한다.
4. 공개 조회와 검증된 쓰기는 `/api/stone-match/` 전용 API로 제공한다. 컬렉션 직접 CRUD는 관리자로 제한한다. 서버 검증, 사용자별 요청 제한과 광고 한도 판정은 트랜잭션에서 수행한다.
5. 사용자 승인으로 기존 Supabase 익명 계정은 이전하지 않는다. 새 설치 식별자 128비트와 비밀값 256비트를 안전한 난수로 만들고 요청 전에 기기에 저장한다. 서버는 비밀값의 비밀번호 해시로 같은 설치의 재인증을 확인한다. 이메일과 가입 UI는 추가하지 않는다. 관리자 계정은 앱에서 사용하지 않는다.
6. 토큰은 7일이며 만료 후 같은 설치 자격정보로 재인증한다. 인증 오류나 네트워크 장애로 설치 자격정보를 새로 만들지 않는다. 90일 비활성 계정 정리 후에는 서버가 새 사용자 ID를 발급할 수 있다. 저장소 삭제/재설치 시에도 새로운 사용자다.
7. 기존 랭킹, 이벤트와 설정은 보존한다. 원본 ID, 시각, 동점 정렬 순서를 유지하고 관리자용 이전 도구는 dry-run, ID 중복 검사, 재실행과 전체 필드 비교를 지원한다. 과거 사용자 ID는 비공개 이력으로만 남기며 새 계정과 연결하지 않는다. Supabase 원본과 설정은 복구용으로 보존한다.
8. 기존 `http` 패키지를 재사용한다. 서비스는 공통 `BackendGateway`에 의존하고 `POCKETBASE_URL`이 설정된 빌드는 PocketBase를 사용한다. 2026-09-29 후속 요청으로 Supabase 경로를 앱/빌드에서 완전히 제거한다. 설정이 없으면 서버기능만 비활성화하고 게임은 유지한다.
9. 앱 공개 URL은 Git 제외 `config/pocketbase.json`, 관리자/SSH 설정은 Git 제외 `.env.pocketbase`로 분리한다. 관리자 파일은 Flutter assets나 dart-define에 넣지 않는다.

## Consequences

- 원격 설정, 주간 순위, 광고 일일 제한, 이벤트 수집 계약과 실패 시 게임 진행 보장은 유지한다.
- 과거/신규 사용자 통계의 연속성은 없다. 로컬 점수와 기록은 유지하고 신규 서버 광고 제한은 새 계정 기준이다.
- 자체 서버의 가동, 백업, 디스크와 업데이트는 직접 관리한다. 재부팅 후 로그인 전에는 현재 LaunchAgent가 실행되지 않는다.
- PocketBase 버전은 실제 0.39.7로 검증하며 향후 업데이트는 별도 검증한다. 서비스 업그레이드와 데이터 이전을 한 번에 묶지 않는다.
- 게임마다 별도 폴더/포트/자동 실행 항목/도메인을 사용한다. 도메인이나 폴더 이름만 바꿔도 DB가 복제되거나 격리되는 것은 아니다.
- PLAN-009 Step 4의 영속 큐와 서버 중복 제거는 이번 이전으로 해결된 것으로 보지 않는다.

## References

- [PLAN-013](../plans/PLAN-013-pocketbase-migration.md)
- [PocketBase 인증](https://pocketbase.io/docs/authentication/)
- [JS 서버 확장](https://pocketbase.io/docs/js-overview/)
- [트랜잭션](https://pocketbase.io/docs/js-database/)
- [운영과 백업](https://pocketbase.io/docs/going-to-production/)

2026-09-29 후속: PLAN-009 Step4의 영속큐/중복제거/장기집계를 별도 실행한다. PostgreSQL 원본과 과거 마이그레이션은 이력/백업이며 현재 운영의 의존성이 아니다.

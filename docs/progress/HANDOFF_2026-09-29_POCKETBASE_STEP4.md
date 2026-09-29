# 신규 세션 인계 (2026-09-29)

> 인수 후 Step4 서버/NAS 배포와 실검증 완료, Sentry 프로젝트 생성/별도 PoC 완료. 이 문서의 미배포 표시는 인계 시점 이력이다. 최신 상태는 [HANDOFF.md](HANDOFF.md)와 [PROJECT_STATUS.md](PROJECT_STATUS.md)를 따른다.

사용자가 신규 세션으로 전체 작업 인계를 요청했다. 기존 조정자는 인계 후 중단한다. 같은 main 체크아웃의 미커밋 변경을 이어서 처리한다.

## 요청과 우선순위

1. Supabase 실행/빌드 의존성을 제거하고 기존 플랜의 미완료 작업을 계속한다.
2. PLAN-009 Step 4 최종 검증 후 PocketBase 서버 선배포, NAS 웹 후배포와 실제 검증을 완료한다.
3. 사용자는 Sentry 가입과 CLI 인증을 완료했지만 프로젝트는 만들지 않았다. 마지막 질문은 CLI로 프로젝트를 만들 수 있는지다. CLI로 조직/팀 확인 후 stone-match Flutter 프로젝트 생성과 연결을 진행한다. `sentry-cli` skill을 먼저 읽는다. 유료 가입/플랜 변경은 하지 않는다.

## 필수 제약

- 한국어 간결한 결과/진행 안내. 브라우저는 `/Users/cheng80/.local/bin/ego-browser` CLI 배경 작업만, 일반 CUA/Chrome/앱 활성화 금지.
- 병렬 작업은 Orca CLI만. 내부 subagent 사용 금지. `orca skills get orca-cli`, `orca skills get orchestration`을 따른다.
- 사용자 변경 보존: in_app_review_service.dart, sfx_play_log.dart, ui_atlas_pixels_test.dart, web/stone_match_sfx.js, test/web. 현재 빌드에도 포함됐다.
- 새 커밋/push/PR은 요청되지 않았다. Supabase 원본 프로젝트/데이터 삭제 금지. 임시 파일은 tmp/ 아래. 비밀정보 출력 금지.

## 완료된 작업

- Supabase gateway/config/fallback 삭제, PocketBase만 선택. lib에 Supabase 호출 없음. 과거 SQL은 supabase/README.md로 이력 표시.
- tools/backend_define.sh 공개 설정 검증 42개, package.json 실패 전파 검증 11개 통과.
- 외부 개인 스킬 `/Users/cheng80/.codex/skills/build-stone-match-submission/`도 PB 설정으로 변경. 백업은 tmp/pocketbase-followup-20260929/submission-skill-backup. 합성 설정 5개 검증, 제출 ZIP 재생성은 안 했다.
- PLAN-002/007/008 완료 상태 정합화, PLAN-006 대체 표시. PLAN-010~012 PB 식별/GA4 측정 사전/Sentry PoC 계약 준비. docs/progress/PLAN_REVIEW_2026-09-29.md 참고.
- 이전 기술 계약 상세는 docs/references/SUPABASE_BACKEND_REFERENCE.md에 보존했다(history 폴더는 gitignore라 references로 옮김).
- 영속 큐 v2: URL+event_id별 SharedPreferences 키, 200행/256KiB/7일, backoff, owner 격리, expectedUserId 재인증 검사, 다중 탭/손상/dispose 방어.
- 서버 신규 migration 1790800000: event_id dedupe, sm_daily_metrics Locked CRUD, KST 집계와 90일 삭제 전 집계. 최종 수정은 실제 mode simple/progression/timed 보존, partial 초기집계, QA 환경변경 분리, 최근 8일 재계산, players purge 전 집계, dedupe index 사용.

## 검증과 아직 미배포인 산출물

- 전체 Flutter 576개 통과. analyze lib test는 사용자 기존 in_app_review_service.dart info 2개만(종료1), 새 오류 없음.
- release Wasm/JS 빌드 성공. `tmp/pocketbase-followup-20260929/nas/match.zip`, SHA256 `9c2a6b039d5f396776208dfa9f29fbdb3ee49d08547d3180b90cc6ce522d425a`.
- ZIP 92파일 CRC/원본 일치, 관리자 이메일/비밀번호와 구 Supabase URL 부재 확인. 패키징 스크립트/로그가 같은 tmp 폴더에 있다.
- 최종 서버 작업자 실제 PB 0.39.7 테스트 24개 통과, importer 실제 호환2개+단위13개 통과. server-fix-report.md 확인. 30만행 첫 집계14.1초(120일), 정상야간0.44~0.9초.
- 독립 server-review.md의 P2 mode는 최종 server-fix에서 수정됨. client-review.md는 P1/P2 없음. 미확정 owner의 이전 실행 이벤트는 타인 귀속 방지를 위해 전송 안 함(정책 한계). 403/404는 배치삭제 정책, 실제 네이티브 UA 검증은 미완료.
- **Step4 서버와 새 NAS ZIP은 아직 배포하지 않았다.** 이전 PLAN013 PB 운영 전환은 이미 배포됐다. 이를 혼동하지 말 것.
- docs/03_TECH_SPEC.md Step4 초안의 최근7일은 최종8일로 정정 필요. 문서 최종 동기화/상태 DONE 처리는 운영 검증 뒤.

## 운영 접근과 배포 준비

- SSH: `ssh -i /Users/cheng80/.ssh/stonematch_macmini_ed25519 -o IdentitiesOnly=yes -o BatchMode=yes cheng80@100.92.43.82`.
- 서버 `/Users/cheng80/Servers/stonematch`, PB0.39.7, LaunchAgent com.fastmake.stonematch.pocketbase(gui/501), localhost8090. 로그인 후 자동 실행, 실제 재부팅 미검증.
- 공개 https://stonematch.fastmake.net, 관리 /_/. .env.pocketbase 관리자값, config/pocketbase.json 공개URL. 내용 출력 금지.
- 이전 운영 baseline rankings11/events361(legacy353+QA8)/config3/players1/ads0. 이번 로컬 브라우저 QA로 신규행이 추가될 수 있다. 임의 일괄삭제하지 말 것.
- tmp/pocketbase-followup-20260929/apply_server.py: 관리자 사전 조회/중복0/원본필드보존 검사 후 SSH deploy_server.py 실행. deploy_server.py는 구 hooks 해시 고정확인, 서비스중지 일관백업+해시검증, 파일교체/재시작/health, 실패시백업복원. 아직 미실행. 읽고 최종 코드/스키마 확인 후 실행.
- live_step4.py 준비됨: QA 임시사용자, 동시중복204/1행, 충돌400원자성, legacy수락,6컬렉션규칙null,집계권한거절,89일backfill/원시수일치,QA삭제. 실행 전 최종 response계약 점검.
- upload_nas.py/verify_nas.py 준비됨. .env의 NAS token 메모리만 사용, 업로드 후 핵심7파일hash/헤더/MIME/deeplink 검증. 이전ZIP 보존.
- 이전 백업 `/Users/cheng80/Servers/backups/stonematch-before-api-20260929-213658` 및 rename전백업 보존.

## 브라우저/로컬 프로세스

- ego TaskSpace **9**, p1, 이름 Stone Match PocketBase Step4 검증. 새 space 만들지 말고 9로 이어서 사용. 사용자 takeover시 중단.
- localhost8879/match/ serve_web.py가 실행 중이었음. 이전 도구 session65809; 현재 도구에서 session ID가 유실될 수 있으므로 포트/프로세스 확인. 임의 전역프로세스종료 금지.
- 실제 Wasm 로딩/crossOriginIsolated=true/타이틀/인증/events204 확인. 현재 p1은 Time 버튼 누른 직후. queue오프라인복원 검증 미완료.
- CDP Network.setBlockedURLs는 ego 호출 종료 후 유지 안 되는 것으로 보임(이벤트204가실제로들어감). 같은 호출 안에서 block→행생성→저장확인 해야 할 수 있다. 새 snapshot refs 필요. credentials/token 출력 금지.
- 완료 시 task.finish({keep:[]}) 정확히1회, 로컬서버 정리. 아직 finish 안 함.

## Sentry

- `/Users/cheng80/.local/bin/sentry` 있음, `sentry-cli` 명령은 없었다. `sentry --help`에 project create/list, org/team, api, auth 포함.
- `.env.sentry` 빈값 템플릿 생성됨(mode0600,gitignored): SENTRY_DSN/ORG/PROJECT=stone-match/AUTH_TOKEN. 기존값 덮어쓰지 말 것.
- auth status/org list/project list 실행 도구 session3703은 모델전환 후 Unknown process id. 결과를 확인 못했으므로 인증/조직조회 다시 읽기전용으로 확인. auth --show-token 금지.
- 사용자 프로젝트 생성 CLI처리 요청이므로 가능한 범위에서 직접 처리. SDK/심볼/Wasm PoC는 PLAN012 기준. 새 skill `/Users/cheng80/.agents/skills/sentry-cli/SKILL.md` 아직 읽지 않았다.

## 사용자 답변 대기

- PLAN003 첫실행1회 기본지급 vs 매판기본보충 정책 질문은 아직 답변 없음. 임의 밸런스변경 금지.
- 로그인 제공자/GA4프로젝트정보 미응답. Sentry는 가입+CLI인증완료로 일부해소.
- PLAN005 D7 플레이테스트, 실기기/Toss광고 검증은 미완. 과거 추가미러링프로파일링 종료결정 유지.

## Orca 작업 정리

- 기존 run run_d0d47915fd77. 마지막 client-review ctx_777e13eef484/server-fix ctx_8e71a63991c0 모두 worker_done 수락 후 release 완료. 마지막 delivery_3ab6956aef3f ack, inbox 비었음.
- 다른 구현자도 완료 후 release 또는 재사용을 거쳐 종료. 조정자 shell handle term_8c5763be-a48e-4528-84eb-fdb2af2b4a08은 남아있다. 새 세션은 이를 자기권한으로 사칭하지 않는다.
- 인계 신규 terminal term_d982990b-9faa-450b-8d98-5f62e67e8b1b. 동일 checkout이므로 dirty변경 그대로 접근. 인계 후 원래 세션은 작업을 중단한다.

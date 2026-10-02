# Project Status

## PocketBase 백업 정리 (2026-10-02)

- Mac mini의 Stone Match DB 백업은 `/Users/cheng80/Servers/backups/stonematch-verify-admin-20261002-072402-6db8fed9/` 1개뿐이었다. 최신 DB2개와 `before.json`을 보존하고, 백업 검증 과정에서 생긴 빈 WAL2개와 SHM2개(합계65536바이트)를 제거했다. 백업을 사용하는 프로세스가 없고 WAL이 비어 있음을 먼저 확인했다.
- 정리 전후 두 DB의 `integrity_check=ok`, 최초 백업 SHA256 일치와8090 health200을 확인했다. pixeltown 백업, 실행 중 DB, 검증 관리자 자격 파일과 기존 이관/배포 근거는 보존했다.
- 등록 도구가 완료된 백업 사본만 `mode=ro&immutable=1`로 검증하도록 수정했다. 실행 중 원본 DB는 기존 `sqlite3 .backup`을 사용한다. 로컬 WAL DB 온라인 백업 실행 검증에서 내용/권한 보존과 WAL/SHM 생성0개, 자격 파일 단위5테스트와 구문 검사 통과. 보고서는 `tmp/backup-cleanup-20261002/`에 있다. 커밋/push 미수행.

## 검증 전용 PocketBase 관리자 적용 (2026-10-02)

- 사용자 요청으로8090의 `verify-admin@stonematch.local`을 생성했다. 작업 PC에서24바이트 무작위 암호를 만든 뒤 Git 제외 `pocketbase/.local/remote-admin.env`의 REMOTE_ADMIN_EMAIL/REMOTE_ADMIN_PASSWORD에만 저장했다. 파일0600, 부모 폴더0700. 암호는 SSH stdin JSON으로만 전달하고 화면/로그/명령 인자에 출력하지 않았다.
- 등록 전 실행 중 data.db/auxiliary.db를 `sqlite3 .backup`으로 `/Users/cheng80/Servers/backups/stonematch-verify-admin-20261002-072402-6db8fed9/`에 백업했다. 각각 integrity_check=ok와 SHA256, 백업 폴더0700/파일0600 확인. 서버 SDK0.26.9가 기존 관리자 권한으로 검증 계정만 생성했다. 기존 소유자는 등록에만 사용했으며 암호와 전체 레코드 해시가 변경되지 않았다. 검증에는 소유자 자격정보를 읽거나 대체하지 않는다.
- 재사용 명령 `pb:verify-admin:provision`, `pb:verify-admin:check`, 파일 권한/계정 분리 단위 테스트와 [실행 안내](../../tools/pocketbase/VERIFICATION_ADMIN.md)를 추가했다. 등록 도구는 이미 있는 검증 계정만 update한다. 실제 운영에서는 create 경로를 검증했으며 update로 암호를 다시 갱신하는 운영 재실행은 하지 않았다.
- 원격11검증 통과: 검증 계정 로그인, 공개 관리자 화면 셸200, 관리자 전용 컬렉션200, 대시보드 관리자 API200, 다른 Origin403, 미로그인/일반 플레이어/잘못된 토큰 각각401, 틀린 암호400(PocketBase 원래 계약), superuser 이메일 목록 확인, 임시 플레이어 정리. 관리자 계정 파일/권한 단위5테스트와 기존 플레이 봇4테스트 통과. 관리자 화면 셸은 공개 SPA이므로200을 로그인 성공으로 간주하지 않고 인증/API를 별도로 확인했다.
- 일반 사용자 거절 검증 때 만든 sm_players 계정은 정확한 ID로 삭제했다. 기존 users/tasks/랭킹 기록, 광고 지급과 서버 훅/서비스/터널 설정은 변경하지 않았다. 현재 저장 전용 서비스 superuser가 없어 관리 화면 로그인 거부 분리는 적용 대상 없음. pixeltown8091/2567은 변경하지 않았다. 이미 설치된 Node 바이너리는 읽기만 해 Stone Match `.local/verification-admin/`에 복사했고 이후에는 해당 사본을 재사용한다.
- 최종 superuser는 `cheng80@gmail.com`, `verify-admin@stonematch.local` 두 명이다. 계정과 로컬 자격 파일은 후속 검증을 위해 보존했다. 폐기 절차는 실행 안내를 따른다. 보고서는 `tmp/verification-admin-20261002/`에 있다. 이번 요청의 코드/문서 변경은 로컬에 준비했으며 커밋/push와 게임/대시보드 재배포는 하지 않았다.

## NAS 운영 배포와 기존 PocketBase 주소 정리 완료 (2026-10-02)

- 사용자 후속 승인으로 깨끗하고 원격과 일치하는 main `d0ee39f`에서 `tools/deploy_match_web.sh --output-dir tmp/pb-nas-production-20261002`를 실행했다. 플레이 자동화 도구는 PR https://github.com/cheng80/jewelmatch/pull/22 로 main 반영 완료다.
- NAS 업로드 HTTP200/result=OK. `TELEMETRY_ENV=production`, PocketBase `https://stonematch-pb.fastmake.net`, release `stone-match@1.0.0+1-3c5c84d8d466`. release Wasm/JS 빌드와 운영/QA Sentry 비공개 JS 소스맵 업로드 완료. ZIP119항목/map/env0개, SHA256 `76a070f2e128b9c8d01ee36e64241d010a457a5eb020282616fdd9ddffb6f02e`.
- 에고의 실제 응답으로 원격7파일 바이트/해시 일치, COOP/COEP, no-cache와 Wasm MIME 확인. 직접 게임 경로200, 새 API health/레벨 랭킹200(6행), NAS Origin CORS204, 대시보드 CSP와 공개 API/session 파일의 main 빌드 일치를 확인했다. 새 PocketBase 관리자 인증/갱신200과 대시보드 서버 관측 경로 인증200도 기존 주소 제거 후 검증했다.
- Cloudflare mac-mini 터널의 `stonematch.fastmake.net` ingress1개와 정확히 해당 CNAME1개를 제거했다. 설정 version9→10. DNS와 터널의 나머지 설정은 직전 백업과 동일하며 새 `stonematch-pb.fastmake.net`은 기존8090 인스턴스를 사용한다. preview, pixeltown, 다른 터널과 DB/서버 파일은 변경하지 않았다. Cloudflare 권한 서버 직접 조회에서 기존 주소 NXDOMAIN, 새 주소 정상 응답을 확인했다.
- 제거 후 새로 로드한 에고 게임의 레벨 랭킹 UI와 새 호스트 설정/랭킹 API200 확인. 레벨 보드와 인벤토리 버튼, 시간 종료 화면 렌더링도 확인했다. 교환 없는 점수0 스모크이며 랭킹 제출/수정/삭제를 하지 않았다. 실제 교환 봇, 실기기, 청취와 장시간 플레이는 이번 배포에서 다시 검증하지 않았다. 기존 세션 저장 키 별칭은 사용자 연속성을 위해 유지한다.
- 산출물 `tmp/pb-nas-production-20261002/`, Cloudflare 직전/직후 백업, API/브라우저/파일 검증은 `tmp/pb-nas-cleanup-20261002/`에 보존한다. 백업 파일은0600, 작업 폴더는0700이다. 검증용 에고 TaskSpace만 종료했다.

## 플레이 자동화 도구 Git 관리 (2026-10-02)

- 사용자 후속 요청으로 타임 모드 플레이 봇, 에고 실행기, 화면 인식/교환 탐색/최종 점수 판정, 회귀 테스트와 실행 안내를 Git 관리 대상으로 게시한다. `package.json` 실행 명령과 AGENTS/Tech Spec/Workflow, 기존 플레이/GA4 검증 기록을 함께 보존한다.
- 직접 사용하는 `playwright-core` 1.63.0, `pngjs` 7.0.0 버전을 고정했다. 기존 정책대로 `node_modules/`, `package-lock.json`, 브라우저 바이너리와 `tmp/`의 실행 보고서/캡처는 Git에서 제외한다. 에고 CLI는 별도 설치가 필요하다.
- 게시용 워크트리에서 npm 설치, `npm run test:play-bot` 4테스트, MJS5파일 구문 검사와 `play:bot`/`play:bot:ego --help` 통과. 이번 Git 게시에서 실제 운영/QA 플레이는 다시 실행하지 않았다. 실제 플레이 근거는 아래 2026-10-01 기록이다.
- 사용자 승인 범위는 커밋/push/PR 스쿼시 main 반영이다. NAS 게임 재배포와 기존 호환 도메인 제거는 포함하지 않는다.

## PocketBase 전용 도메인 변경 (2026-10-02)

- 사용자 요청으로 기본 주소를 `https://stonematch-pb.fastmake.net`으로 전환했다. mac-mini의 기존 8090 인스턴스에 새 Cloudflare ingress와 프록시 CNAME을 연결했다. 기존 DB, 서버 프로세스와 preview/pixeltown 경로는 그대로이며 이전 주소는 현재 배포된 게임/대시보드 호환용으로 유지한다.
- Git 제외 `config/pocketbase.json`, 게임/대시보드 `.env.pocketbase`, 대시보드 API/서버 auth-refresh/CSP와 현행 운영 문서를 갱신했다. 게임의 새 도메인은 이전 운영 저장 키를 공유하여 기존 기기 사용자, 토큰과 광고 한도를 유지한다. 다른 서버와 경로는 격리하며 손상된 기존 자격정보는 덮어쓰지 않는다.
- 검증: 양쪽 주소 health/관리 화면/관리자 인증/컬렉션/레벨 랭킹200, NAS Origin CORS204. 랭킹6행, gameplay 설정과 컬렉션 ID/이름이 일치한다. 랭킹 쓰기/삭제0건. Flutter 관련28테스트(backend/랭킹/telemetry), backend define42사례, 전체 analyze와 새 주소 QA release Wasm/JS 빌드 통과. 대시보드86테스트/빌드 통과, 에고에서 갱신된 CSP의 로컬 대시보드로 새 health/랭킹200 확인.
- 도메인 연결 시점에는 커밋/push, NAS 게임과 Pages 대시보드 재배포를 수행하지 않았다. 다음 게시에서 두 소비자를 함께 전환한 뒤 이전 호스트 정리를 검토한다. 기존 사용자 미커밋 변경을 보존했다. 근거 `tmp/pocketbase-domain-20261002/`, 대시보드 테스트 로그는 해당 저장소 `tmp/pocketbase-domain-*.log`다.
- 도메인 변경은 게임 PR https://github.com/cheng80/jewelmatch/pull/21 (`87077ec`), 대시보드 PR https://github.com/cheng80/stomematch_dashboard/pull/1 (`f5d8796`)을 main에 스쿼시 병합했다. 대시보드 CI와 Pages 자동 배포, 새 CSP/API/session 공개 파일200과 main 빌드 일치를 확인했다. NAS 게임 재배포는 아직 수행하지 않았다. 당시 로컬에 보존한 플레이 봇은 이번 후속 요청으로 별도 게시한다.

## 플레이 자동화와 운영 GA4 수집 확인 (2026-10-01)

- 사용자 요청으로 에고 운영 게임의 사용 통계를 켜고 실제 타임 플레이를 진행했다. 대시보드 production 진단(22:02 KST): 최근 30분 활성 사용자 1명, 이벤트 15건, "최근 수집은 확인됐습니다." 오늘/완료일 보고서는 반환 기록 없음이며 대시보드는 처리 지연과 최대 15분 캐시를 안내했다.
- `tools/play_bot*.mjs`, 에고 launcher와 `tools/PLAY_BOT.md`를 추가했다. 화면 보석 색으로 인접 교환을 찾아 실제 입력하고 보드 변화와 양수 종료 점수까지 확인한다. 에고 네이티브 마우스의 초점/일시정지 문제는 진단 후 CDP mouse 입력으로 해결했다. 운영 빌드와 게임 상태를 직접 변경하지 않았다.
- 에고에서 8회 시도/8회 보드 변화와 결과창 진입을 확인했다. 첫 에고 보고서의 1524는 점수 count-up 중간값이라 최종 점수 근거로 사용하지 않는다. 이후 종료 문구 후 최소 3초, 같은 값 유지 1초 조건을 공통 점수 판정에 추가했으며 회귀 테스트로 검증했다. 수정된 대기 경로의 실제 실행 검증은 별도 브라우저에서 수행했다.
- 검증: Node 4테스트 통과, 수정된 점수 대기 로직으로 운영 별도 브라우저 2판 각 8회 교환과 4500/4400 최종 점수 확인, page_view/level_start/level_end 운영 측정 ID HTTP204, 앱 콘솔 오류0. 최종 근거 `tmp/play-bot/production-stable-20261001/`, 에고 입력 근거 `tmp/play-bot/ego-cdp-20261001/`. GA4 전송 로그에는 204 이후 ERR_ABORTED도 관찰되어 원문을 보존했다.
- 앞으로 "자동화 테스트 돌려줘" 요청 시 관련 스킬과 봇을 실행하고 검증/문제 수정까지 진행하도록 루트 AGENTS와 개발 워크플로에 기록했다. 명시적 운영 수집 확인 외에는 로컬/QA부터 진행하며 사용자 제어 중단을 우회하지 않는다. 커밋/push/배포 없음.

## 플레이 중 인벤토리 NAS 배포 완료 (2026-10-01)

- 사용자 요청에 따라 기능 커밋 `a3dad54`를 push하고 PR https://github.com/cheng80/jewelmatch/pull/20 을 스쿼시 병합했다. main 제품 커밋 `11194c4`, 기존 레벨 랭킹 검증 문서 기록 보존 확인. GitHub Actions 워크플로와 필수 CI는 없으며 전체632테스트 통과(기존2건 skip), 전체 analyze와 release Wasm/JS 빌드를 확인했다.
- 병합 내용과 feature의 파일 일치, clean 상태와 다른 작업 사용 여부를 확인한 뒤 Orca CLI로 워크트리, 로컬 브랜치와 원격 브랜치를 정리했다. 캡처와 로그는 `tmp/inventory-nas-publish-20261001/play-inventory/`에 복사해 보존했다.
- 깨끗하고 원격과 동기화된 main에서 `tools/deploy_match_web.sh --output-dir tmp/inventory-nas-20261001`로 배포했다. HTTP200/result=OK, 운영/QA 프로젝트2곳 비공개 JS source map 업로드 완료. release `stone-match@1.0.0+1-ca7d302b455b`, ZIP SHA256 `d2c08d3084fc4553413a36e35fcfdb038cc0c09b1d886091381f7a75f2b3b942`, ZIP119항목/map/env0개 확인.
- 원격7파일 해시 일치, COOP/COEP, no-cache, Wasm MIME와 직접 게임 경로200 확인. health200, 레벨 랭킹 공개 POST 조회200/5행. 기존 랭킹 기록을 수정하거나 삭제하지 않았다.
- 운영 헤드리스430 화면에서 레벨 보드와 금색 사각 가방, 인벤토리 보드 가림, 일시정지 후0:57 보존, Escape 취소와 장착 변경 없이 적용 후 재개를 확인했다. 실제 장착 변경의 수량/적용/취소는 로컬 Flutter 테스트로 검증했다. 콘솔 오류/경고0. Orca 브라우저는 Electron sandbox preload 오류와 로딩 화면으로 게임 검증이 제한돼 앞서 요청된 헤드리스 방식으로 운영 화면을 비교 검증했다. 실기기와 실제 청취/장시간 플레이는 미검증.
- 배포 산출물은 `tmp/inventory-nas-20261001/`, 검증과 최종 운영 캡처는 `tmp/inventory-nas-publish-20261001/`에 보존한다. 제출용 공모전 ZIP과 앱인토스 빌드는 이번 범위에 포함하지 않았다.

## 레벨 플레이 중 인벤토리 교환 (2026-10-01, 배포 전 기록)

- Orca CLI 워크트리 `codex/play-inventory`에서 구현. 체크아웃 `/Users/cheng80/orca/workspaces/jewelmatch/codex-play-inventory`, base `f094d3b`. 사용자 승인에 따라 하단 패널을 얇게 줄이고 4슬롯과40×40 둥근 사각형 인벤토리 버튼을 한 줄로 정렬했다. 가방 아이콘은 유지하고 버튼은 어두운 청회색 배경, 일반 버튼과 같은 금색 테두리와8px 모서리로 금색 원형 아이템 슬롯과 구별한다. 오른쪽 버튼 앞 얇은 세로 구분선으로 사용/장착 편집을 구별한다. 슬롯 줄 높이를 유지하고 빈 공간을 줄였으며 좁은 화면에서는 슬롯 크기/간격을 너비에 맞춘다. 상단 HUD와 게임 규칙은 유지한다.
- 레벨 모드 idle 상태에서 열면 엔진, 시간, 입력과 BGM을 일시정지하고 불투명 배경으로 보드를 가린다. 적용은 현재/다음 레벨 장착에 반영하며 취소, Escape, 시스템 뒤로가기는 장착을 유지하고 재개한다. 결과창 인벤토리는 기존 다음 레벨 편집 흐름 유지. 수량은 실제 사용 시만 소모하며 플레이 중 광고 보충은 제공하지 않는다.
- 백그라운드 닫기는 PauseMenu 복귀, 중복 닫기/재시작 뒤 콜백 무시. 열린 빈 슬롯을 잠긴 슬롯처럼 그리던 표시도 분리했다. 실제 웹에서 Escape 초점 문제를 확인해 post-frame FocusNode 요청을 추가하고 재검증했다.
- 관련 Flutter87테스트와 전체 analyze, release Wasm/JS 빌드 통과. 실제 헤드리스430×900/375×812에서 슬롯/버튼 겹침 없음, 보드 가림, 장착 적용/취소와 키보드 닫기 확인. 앱 콘솔 오류0. 로컬 서버 격리 헤더가 없어 single-threaded skwasm 안내와 헤드리스 GPU ReadPixels 경고는 남는다. 운영 백엔드 설정 없이 검증했으며 운영 쓰기는 없다. 실기기/장시간 검증은 미수행.
- 헤드리스 요청 화면: `tmp/play-inventory-20261001/gold-play-430.png`, `gold-inventory-430.png`. 좁은 화면과 추가 동작 근거도 같은 폴더에 보존. 상세 계약은 PLAN-014와 Product/UI/Tech Spec에 반영했다.
- 둥근 사각형 변경 후 관련 테스트21개, 전체 analyze와 release Wasm/JS 빌드 통과. 실제430/375 화면에서 원형 슬롯과 구별되는 프레임, 버튼 탭으로 인벤토리 열기와 Escape 재개를 확인했다. 근거는 `rounded-tests.log`, `rounded-analyze.log`, `rounded-build.log`, `rounded-play-375.png`다.
- 사용자 요청으로 둥근 사각형 테두리를 일반 버튼의 외곽 금색 `outlineBright`(alpha0.95)으로 통일했다. 색상 변경 후 analyze와 release Wasm/JS 빌드 통과, 실제430 화면과 버튼 탭 열기를 확인했다. 근거 `gold-analyze.log`, `gold-build.log`. 관련21테스트는 색상 변경 전 검증이며 이번 색상만 변경한 작업에서는 재실행하지 않았다.
- 사용자 커밋/push/병합/정리/NAS 배포 요청으로 게시 검증을 진행한다. 원본 main의 레벨 랭킹 검증 기록을 문서에 보존했다. 전체 테스트에서 인벤토리 아이콘 추가로 이미지 그리기32→33회인 것을 확인해 렌더링 예산 기대값을 갱신했다. 텍스처3장과 전환7회는 유지된다. 게시 전 전체632테스트 통과(기존2건 skip), 전체 analyze 통과.

## 레벨 랭킹 기록 검증 (2026-10-01)

- 코드/계약/운영 공개 조회와 격리 서버에서 검증한 범위는 정상. 완료 레벨 수를 사용하며 레벨1 미완료는0/제출 제외, 레벨4 종료는3이다. Pause 나가기 await와 중복 클릭1회, TimeUp의 양수 레벨 제출/실패 후 같은 값 재시도 확인.
- 운영 공개 레벨 목록5건은 9/3/2/2/2, 모두 양의 정수이며 점수 내림차순/동점 등록 시각 오름차순이다. Flutter 기존 관련42개 + 임시 양수 레벨 결과 테스트1개, 실제 로컬 PocketBase 통합24개 통과.
- 별도 격리 PocketBase에서 레벨1/3/9/3 제출, 조회9/3/3/1, 0과 비인증 거절, 동일 이름 다중 기록, 오래된 주의 레벨 기록 포함, 서버 재시작 후 보존/재인증 확인. 운영 기록 쓰기/삭제와 게임 코드 변경 없음.
- 실제 사용자가 플레이해 운영에 새 기록을 저장하는 전체 실기기 흐름은 미검증. 이전 검증 브라우저의 백엔드 차단 제한을 우회하지 않았다. 근거: `tmp/level-ranking-20261001/`.

## 접근성 입력 수정 NAS 배포 완료 (2026-10-01)

- 사용자 요청으로 구현 `ff4a030`을 main에 커밋/push하고 깨끗한 main에서 NAS 배포 완료. 기존 Sentry 테스트가 임의 event_id의 999를 점수 누출로 오판하는 문제도 필드 검사로 보완했다. 관련30테스트와 전체 analyze 통과, GitHub Actions 워크플로는 없다.
- release `stone-match@1.0.0+1-367f2554d66f`, Wasm/JS 빌드와 운영/QA 비공개 소스맵 업로드 완료. HTTP200/result=OK, 원격7파일 해시/격리헤더/no-cache/Wasm MIME/직접경로 검증 통과. ZIP SHA256 `bd873cda8369d151339bf06a31ae1d4ee9fb20054f35f0eda0d9652b36362115`, map/env 포함0개.
- 실제 브라우저 타이틀/설정 이동/새로고침/게임 보드 렌더링, 콘솔 오류/경고0 확인. 검증 브라우저가 백엔드 도메인을 ERR_BLOCKED_BY_CLIENT로 차단해 랭킹 UI 확인은 제한됐다. 별도 curl의 health/랭킹 API200(5행), CORS 사전 요청204 확인. 기존 사운드 설정은 음소거이며 청취/실기기 접근성 검수는 미수행.
- STONE-MATCH-5/6을 위 배포 release에 연결하여 resolved 처리. 이전 미배포/unresolved 문구는 09-30 시점 이력이다. 근거: `tmp/sentry-deploy-20261001/`, `tmp/sentry-nas-20261001/`, PLAN-012 16절.

## Sentry 이슈 분석과 접근성 입력 멈춤 수정 (2026-09-30)

- 이슈12개/이벤트29건 모두 QA 검증 기록. 합성 검증10개 resolved 처리. STONE-MATCH-5/6은 현재 코드에서도 재현되는 접근성 예외 후 입력 멈춤으로 확인했다.
- 바인딩 초기화 직후 접근성 콜백 예외를 FlutterError로 보고하고 정상 반환하는 보호 코드 추가. 관련30테스트/전체 analyze/게임 release Wasm+JS 빌드 통과. 브라우저 JS/Wasm에서 후속 탭2회와 오류 수집1회, 수집 비활성 JS에서도 입력 복구 확인.
- 로컬 수정 완료, 운영 미배포. 입력 오류2개는 배포 후 확인을 위해 unresolved 유지. 커밋/push 없음. 상세 근거와 한계: [PLAN-012 15절](../plans/PLAN-012-crash-observability.md#15-sentry-이슈-분석과-접근성-입력-보호-2026-09-30).

## 도전 목표 미션 표제 (2026-09-30)

- 사용자 제보에 따라 도전 스테이지 목표 줄 앞에 금색 미션 표제를 상시 표시한다. 색 아이콘/진행도와 함께 가운데 정렬하며 긴 번역은 안전 너비 안에 축소한다. 점수와 클리어 조건은 유지한다.
- 한국어/영어/일본어/중국어 간체/번체 반영. 관련 HUD/도전 테스트26개와 전체 analyze 통과. 구현 c00a235를 main에 push하고 NAS 운영 배포 완료. 실기기 시각 검수는 아직 수행하지 않았다.
- release Wasm/JS 빌드 및 Sentry 비공개 source map 업로드, NAS HTTP200/result=OK, 원격7파일 해시/격리헤더/Wasm MIME/직접경로 검증 통과. release `stone-match@1.0.0+1-a94c27cd0f42`, ZIP SHA256 `57be4b1756a709ad047f1ecf097363cf53557fa2293a1691a2c4a8e10d39bd0f`. 근거 tmp/mission-nas-20260930/.


## Git 게시 및 main 통합 검토 (2026-09-30)

- 사용자 최신 승인으로 기존 커밋/push 금지를 해제하고 배포된 PocketBase/관측 구현과 관련 문서를 통합한다. 이전 금지 문구는 승인 이전 이력이다.
- Flutter622, PB24, importer15, 웹 오디오3, 빌드 도구 검사, 전체 analyze와 release Wasm/JS 빌드 통과. 비밀 설정은 Git 제외 유지.
- 오래된 원격 docs-agent-artifact-cleanup은 현행 문서 체계와 충돌해 적용하지 않고 보존한다. 상세 근거: [Git 통합 검토](GIT_INTEGRATION_2026-09-30.md).


## 대시보드 ECharts 차트 배포 (2026-09-30)

- 사용자 지적으로 직접 SVG 구현에서 Apache ECharts6.1.0으로 전환했다. 라이브러리는 버전/잠금파일 고정, 로컬 vendor와 라이선스 포함, CI npm ci 적용. 외부 CDN과 CSP 완화 없음.
- DAU/세션/이벤트 선택 선그래프, 활동 달력, 상위6+기타 도넛, 원본 시간대 히트맵, 익명 사용자 날짜 추이와 시간대 히트맵 구현. 누락/0/잠정/미래시간/보존경계 구분, 상세보기와 텍스트 표 대체 유지.
- 최종 대시보드 `ac6dac0`, 테스트46개와 CI https://github.com/cheng80/stomematch_dashboard/actions/runs/36598402772 성공. Pages 자동배포/원격8파일 일치/데스크톱과 모바일375 검증. TaskSpace21/22 finish, Dispatch `ctx_8d81974da926` succeeded/retained, 회수대기0.
- 현재 실제 일별 활동 데이터가 적어 대부분0으로 보인다. 원본/서버/게임코드 변경 없음, 게임 커밋/push 없음. 상세 정본은 독립 저장소 docs/PLAN.md와 README.

## 대시보드 이벤트 한글명과 사용자 날짜 상세 배포 (2026-09-30)

- 사용자 요청으로 독립 대시보드 원본 이벤트 읽기 범위를 확장했다. 이벤트23종 한글명, 날짜→익명 설치 사용자→특정 날짜 이벤트 구성, 사용자200명씩 더보기, 오늘 포함 원본 상세 조회 구현.
- 구버전 시작 이벤트와 식별자로 묶인 판 구분, 8일 종료 매칭, 서버 기준 날짜/중복 제거, 표본 이벤트 설명. 원본90일 보존, 설치와 사람 수 구분. 서버/원본 데이터 변경 없음.
- 독립 최종 커밋 `71b7a5b`, 테스트43개/build, 실제 데스크톱/모바일375/450명 더보기/로그아웃 검수 통과. CI https://github.com/cheng80/stomematch_dashboard/actions/runs/36596217935 및 Pages 자동 배포 성공. 원격 파일 일치 확인.
- Dispatch `ctx_2a9c476f1d46` succeeded/retained, TaskSpace18/19/20 finish, 회수 대기0. 게임 코드/커밋/push 변경 없음. 상세 정본은 독립 저장소 README/docs/PLAN.md.

## 대시보드 환경 미기재 원인 확인 (2026-09-30)

- 현재 완료된 집계의 이벤트331건(09-24 135, 09-28 196)은 환경 정보 없는 기존 기록으로 unknown이다. 원본 09-29에는 production9건과 qa30건이 있으며 09-30 KST04:00 집계 전 상태다. 오늘 데이터는 완료일 제외 정책으로 미표시. 원본 재분류 없음.
- 대시보드 환경별 기록 건수 안내, 환경 의미와 오늘 제외/다음 집계 시각 설명 보강. 독립 커밋 `c7d22da`, 테스트35개/CI/Pages 자동 배포 성공. https://github.com/cheng80/stomematch_dashboard/actions/runs/36592923712
- TaskSpace16 종료, Dispatch `ctx_5dd9c5d963d8` succeeded/retained. 04:00 이후 실제 예약 집계는 아직 미검증이며 예약 모니터링은 설정하지 않았다. 게임 app_version이 여러 빌드에서 1.0.0+1인 점은 후속 개선 참고, 이번 게임 코드 변경 없음.

## 대시보드 Cloudflare Pages 배포 완료 (2026-09-30)

- 사용자 승인으로 https://stomematch-dashboard.pages.dev 배포 완료. GitHub main 연결, npm run build, dist, NODE_VERSION=22. 대시보드 커밋 `19c2df8`의 github:push 자동 배포 성공과 CI https://github.com/cheng80/stomematch_dashboard/actions/runs/36591991649 성공 확인.
- 원격 파일 일치와 보안 헤더, 비밀 제외, 실제 pages.dev 관리자 로그인/CORS/집계 조회, 로그인 전 PB 요청0와 비인증 조회403, 새로고침 인증 소거 검증. TaskSpace15 finish 완료.
- 로그인 화면은 공개, 데이터는 PB superuser 인증 필요. Cloudflare Access는 미적용이며 Zero Trust 조직은 권한 부족으로 미확인이다. Access와 읽기 전용 프록시는 후속 범위. 배포 승인 대기라고 적힌 이전 기록은 과거 상태다.
- 전담 Dispatch `ctx_b8a4e74bec21` succeeded/retained, 회수 대기0. 게임 소스/배포/커밋/push 변경 없음.

## 대시보드 GitHub CI 활성화 완료 (2026-09-30)

- 사용자 GitHub workflow 권한 추가 완료 후 대시보드 전담 세션이 `.github/workflows/verify.yml`을 적용했다. push/PR, contents read, Node22, 테스트와 빌드 자동 검증. 비밀이나 운영 데이터 불필요.
- 대시보드 최종 커밋 `c7cfb7c`, GitHub Actions https://github.com/cheng80/stomematch_dashboard/actions/runs/36591383207 성공 확인. 기존 CI 권한 부족/미실행 기록은 과거 이력이다.
- 전담 Dispatch `ctx_23e8964006b7` succeeded/retained. Cloudflare 배포와 운영 인증 결정은 여전히 대기다. 게임 커밋/push 없음.

## 대시보드 시각 검수 후속 완료 (2026-09-30)

- 사용자 계속 요청으로 기존 대시보드 전담 세션을 재개했다. 잠정 배지 모순, 차트 마지막 날짜 겹침과 잘림, 전부 0일 때 최대 DAU 날짜, 모바일 차트 글꼴 문제 4건을 수정하고 실제 데스크톱1280/모바일375 캡처로 재검수했다.
- 독립 저장소 stomematch_dashboard 커밋 `0b0cf4e`를 origin/main에 일반 push 완료. 로컬과 origin/main 일치, 작업 트리 clean, 테스트34개와 빌드6파일 통과. 게임 커밋/push는 하지 않았다.
- TaskSpace13은 로그아웃 후 finish 완료. 전담 터미널은 사용자 요청대로 보존한다. 후속 Dispatch `ctx_242cffe9126d` succeeded/retained. 이전 abandoned 기록은 재개 전 이력이다.
- Cloudflare Pages 배포와 운영 인증 구성은 결정 대기다. GitHub CI는 workflow 권한 부족으로 템플릿만 있으며 실행되지 않았다. 상세 정본은 독립 대시보드 docs/HANDOFF.md다.

## GA4 NAS 최소 연결 배포 완료 (2026-09-30)

- 최종 정리: 실제 NAS QA page_view/level_start 확인, 테스트 동의 off와 게임 GA 쿠키0 복원. ego TaskSpace9 finish 완료, 소유한 로컬 검증 서버6개 종료. 대시보드 전담 세션/브라우저는 별도로 보존한다.
- PLAN-011 Step2 NAS 범위 완료. 운영 G-1D8SDVLZQX, QA G-E942CQ3ZBL 별도 속성. 선택동의 기본off, 쿠키전용범위, 광고목적/신호off, 허용목록 이벤트와 정제URL. native/intoss는 비활성이다.
- 실제Wasm QA4이벤트 각1회와 DebugView수신, 실제게임Wasm/JS 동의설정/전송, 철회후차단과전용쿠키삭제, 외부GA차단시게임보드 검증. Flutter622, 변경7파일analyze clean.
- NAS HTTP200/OK, release stone-match@1.0.0+1-6c84d928ff14, ZIP SHA256 5de3ded63a459b25fc8e3ea7708345016a75112d73c92bdc732249e88627a6b2. 원격7파일/격리헤더/MIME/직접경로통과. 실제NAS동의전Google요청없음/동의후QA수집확인. Sentry source map 새release업로드/공개제외 유지.
- 대시보드는 사용자요청으로 독립 stomematch_dashboard 저장소와 Orca 전담세션으로 분리했다. main 첫push ce2c5cc, 로컬34테스트/빌드/DOM기반브라우저검수통과, 데스크톱 시각 결함3개 수정, 모바일 글꼴 수정 후 재검수는 사용자 브라우저 제어 전환으로 대기 중이다. 마지막 시각 수정은 아직 미커밋이다. GitHub CI는 workflow권한부족으로 실행템플릿만보존했고 실행안됨. Cloudflare Pages 배포는 미실행. 게임변경은커밋/push하지않았다.
- 남은범위: PLAN-011 Step3 보고서/리텐션, native/intoss, 실제기기/장시간성능. SearchConsole/BigQuery는 사용자예시이며착수하지않는다. PLAN-010 외부로그인정책은별도사용자결정대기.
- 증거: tmp/ga4-integration-20260929/와 PLAN-011 11절. 기존 사용자4파일 해시 불변.
- 대시보드 전담 터미널 term_99f828e2-1dd6-4703-9758-3dcc1a3d4614와 TaskSpace13은 사용자 확인용으로 보존했다. 검수 후속 ctx_eddb22ca1133는 사용자 제어 escalation 뒤 최종 turn이 종료돼 fence(abandoned) 처리했으며 프로세스/파일 삭제는 없다. 사용자가 전담 세션에서 계속하면 새 사용자 작업으로 재개하고 예전 lifecycle ID는 재사용하지 않는다. Orca 회수 대기0.


## 대시보드 독립 세션 분리 (2026-09-29)

- 사용자 요청으로 대시보드는 `/Users/cheng80/Desktop/Anther_Works/Flutter_Project/FlutterFrame_work/stomematch_dashboard` 독립 저장소로 이동했다. 비공개 GitHub `cheng80/stomematch_dashboard` 생성, origin 연결 완료. 이 게임 저장소의 커밋/push는 금지 유지한다.
- 대시보드 전담 세션은 해당 저장소 `docs/HANDOFF.md`를 따른다. 기본 구현32테스트/6파일빌드와 실서버89일 집계조회 통과, 브라우저검수와 첫push는 대시보드 세션 담당. 게임 세션은 대시보드 파일을 더 수정하지 않는다.
- 게임 세션은 PLAN-011 GA4를 계속한다. cookie_prefix sm, host-only /match/ 격리 보완, 관련35테스트 통과. 실제 Wasm QA에서 동의 전 태그/요청0, 동의 후 page_view/title_menu_action/level_start/level_end QA전송, URLquery/민감값제거 확인. 동의철회 후 추가전송0, 게임쿠키만삭제와 비관련시험쿠키보존 확인. 운영 향상된측정OFF 확인.
- GA4 DebugView 확인, 실제 게임빌드/배포와 문서마감은 아직 남음. QA요청에서 debug_mode가 ep.debug_mode로 전달되는 점 확인 필요. 운영은 아직 Sentry-only 직전배포본이다.


## Sentry NAS 배포 완료, GA4 연결 진행 (2026-09-29)

- PLAN-012 승인 범위(오류 수집만, Wasm 유지) 배포 완료. release `stone-match@1.0.0+1-bd769fb5c599`, NAS ZIP SHA256 `107ce4c4d892f55d583a4efe272dcb9ffe5a5c094a1d7dea5200c36ba41e6fc2`, HTTP200/OK와 원격7파일 검증. 운영/QA 프로젝트 분리, 실제 NAS QA 오류 수신/민감값과 서버 파생 지역 제거 확인.
- 독립 검수에서 발견한 JS 수집 누락/한 줄 스택 손실을 수정하고 재검증했다. Flutter587/오류11/빌드도구13그룹 통과, Wasm/JS 빌드와 실제 오류 수집, JS 원본 줄/문맥 복원 통과. Wasm 원본 줄 복원, 모바일/토스 실기기와 성능은 검증 한계다. 수집 endpoint 차단 상태에서도 게임 진입 통과.
- 사용자 GA4 운영 ID `G-1D8SDVLZQX` 제공 및 Google 설정 직접 진행 요청. 로그인된 콘솔에서 계정378565797/속성556597456 `Stone Match` 일치 확인. 별도 QA 속성과 웹 전송/설정 구현 진행 중. Search Console/BigQuery/성과 분석은 사용자가 예시라고 명시하여 추가하지 않는다.
- 기존 사용자 변경 보존, 새 커밋/push 없음. Orca 현재 Run `run_640edb280571`, Sentry 작업 완료 후 GA4 매핑/어댑터 위임. ego TaskSpace9 재사용(p1 게임/p2 Analytics), 종료 전 finish 필요. 세부 근거는 PLAN-012 14절과 `tmp/sentry-integration-20260929/`.


## PLAN-009 Step 4 배포 완료와 Sentry PoC (2026-09-29)

- Step 4 서버 선배포/NAS 후배포와 운영 검증을 완료했다. 서버 중지 백업 19파일 해시 확인, 기존 랭킹 11건/이벤트 362건/설정 3건/광고 0건 원본 필드 보존. 백업 `/Users/cheng80/Servers/backups/stonematch-before-step4-20260929-223044`.
- 서버 실제 동시 중복 요청 4회→1행, 충돌 배치 400 원자성, ID 없는 구버전 호환, 6컬렉션 Locked CRUD, 관리자 전용 집계와 89일 backfill/raw 수 일치 통과. 집계 창은 최근 완료일 8개다. 운영 DAU는 env=production을 사용하고 종료 누락은 unknown으로 해석한다.
- NAS 업로드 HTTP200/result=OK, ZIP SHA256 `9c2a6b039d5f396776208dfa9f29fbdb3ee49d08547d3180b90cc6ce522d425a`. 핵심 7파일 원격 해시/격리 헤더/Wasm MIME/no-cache/deep link 통과. 실제 Wasm 타이틀과 큐 전송 확인.
- ego TaskSpace9에서 events 경로 차단→영속 저장→새로고침→동일 event_id/owner 복원→차단 해제 후 큐 비움, 대상 2이벤트 각각 서버 1행 확인. 첫 인증 전 이전 실행의 owner 미확정 이벤트는 수집되지 않을 수 있다. 모바일/앱인토스, 실제 재부팅과 cron 예약 시각 발화는 미검증.
- 인계 최종 소스 검증: Flutter576/PB24/importer15/release Wasm+JS 빌드 통과. analyze는 기존 사용자 파일 info2로 종료1. 이번 세션 제품 소스 추가 수정 없이 배포/운영 검증을 수행했다. 새 커밋/push 없음, 사용자 변경 보존.
- Sentry 조직 tk-media-m3/팀 tk-media에 stone-match Flutter 프로젝트 생성, DSN Git 제외 `.env.sentry`(0600)에 저장, 합성 QA 이벤트 수신 확인. 별도 `tmp/sentry-poc-20260929/`에서 SDK9.30.1 빌드/수집 검증. JS 원본 Dart 파일/줄 복원 성공, Wasm 원본 복원 미지원 확인. 사용자가 Wasm 유지+오류 수집만 연결을 승인했다. Run run_640edb280571에서 Opus/high 오류 연결과 Sonnet/high 빌드 도구를 병렬 구현 중이다. 게임 SDK 운영 배포는 아직 미실행이다.
- Orca 재점검: Run run_d0d47915fd77 Task11 모두 completed, reclaimable0. 최종 client-review/server-fix released. 이전 재사용 dispatch7은 retained/자원 absent 이력이다. 터미널4개 유지: 인계 Codex(재연결 실패 문구), 별도 Codex 대기, 이전 PB 검수 Claude, 이전 coordinator 셸. 추가 사용자 요청에 따라 인계 Codex의 실제 exited를 확인하고 닫았다. 새 조정용 터미널을 생성해 작업자2명의 turn_started를 확인했다. 이전 핸들 사칭 없음.
- 근거: `tmp/pocketbase-followup-20260929/`의 server-deployment.json, live-step4.json, browser-queue.json, nas/remote-verification.json, sentry-js.json, sentry-wasm.json, orca-recheck/summary.json. PLAN-009 DONE, PLAN-012 IN_PROGRESS.

## 기존 플랜 재검토와 PocketBase 단독화 착수 이력 (2026-09-29 22:04 KST)

- 사용자 요청으로 PLAN-009 Step 4를 재개했다. Supabase 앱 구현/설정/fallback을 제거하고 PocketBase만 선택하도록 변경했다. 과거 SQL, 원본 데이터와 Git 제외 설정은 복구 이력으로 보존하며 실행에는 사용하지 않는다.
- Orca Run `run_d0d47915fd77`에서 빌드 설정 검증, 영구 큐, 서버 중복 방지/일별 집계, PLAN-010~012 사전 준비를 병렬 진행 중이다. 브라우저는 ego CLI 배경 작업만 허용한다.
- PLAN-002, PLAN-007, PLAN-008은 코드와 운영 검증상 구현 완료다. PLAN-006은 PLAN-013으로 대체한다. PLAN-003의 최초 지급/매판 보충 정책과 PLAN-010~012의 로그인 제공자/외부 프로젝트 정보는 사용자 답변 대기다. PLAN-005 D7 플레이테스트와 실기기 검증은 완료로 표시하지 않는다.
- Step 4 구현은 아직 통합 검증/운영 배포 전이다. 직전 배포의 성공 결과를 이번 변경의 검증 결과로 재사용하지 않는다.


## PLAN-013 PocketBase 운영 전환 완료 (2026-09-29 21:48 KST)

- 새 NAS 웹은 `https://stonematch.fastmake.net`을 사용한다. 운영 API와 데이터 반영, release Wasm/JS 빌드 및 NAS 업로드(HTTP 200, result=OK), 핵심 파일 7개 원격 해시/격리 헤더/SPA fallback 검증을 마쳤다. 소스는 기존 사용자 변경을 포함한 미커밋 main이며 새 커밋/push는 하지 않았다.
- 원본 랭킹 11건, 이벤트 353건, 설정 3건, 광고 기록 0건을 이전했다. 원본 필드 전수 일치, 가져오기 재실행 변경 0건, 배포 후 최종 원본 차이 0건, 공개 time/level 목록과 원본 일치를 확인했다. 기존 익명 사용자 38명은 승인에 따라 이전하지 않았다. Supabase와 이전 NAS ZIP은 복구용으로 보존한다. 이후 구 탭이 Supabase에 쓸 수 있으므로 자동 동기화가 된다고 간주하지 않는다.
- 서버 `/Users/cheng80/Servers/stonematch`, PocketBase 0.39.7, LaunchAgent `com.fastmake.stonematch.pocketbase`. 로그인 후 자동 실행, 서비스 재시작 후 데이터/동일 사용자/기존 토큰 유지 확인. 실제 Mac 재부팅과 운영 cron 예약 시각 발화는 미검증이다.
- 배포 직전 중지 백업 `/Users/cheng80/Servers/backups/stonematch-before-api-20260929-213658`의 16파일 해시 일치 확인. 이전 폴더 변경 전 백업도 보존한다. 원격 `users`/`tasks`는 조사 이후 외부에서 삭제 마이그레이션이 추가된 상태였으며 이번 배포는 이를 복원하거나 삭제하지 않았다.
- 권한: `sm_players`, `sm_rankings`, `sm_ad_claims`, `sm_events`, `sm_config` 직접 CRUD 5개 규칙은 모두 null(Locked). sm_players authRule/manageRule도 null, password/OAuth2/OTP 비활성. 공식 문서 확인 후 비로그인/플레이어 직접 접근 54건과 공개 도메인 10건 거절 검증. 허용 기능은 전용 API에서 별도 인증/입력 검증한다.
- 검증: 전체 Flutter 561개, 서버 0.39.7 통합 16개, 추가 독립 서버 검증 18개, 최종 importer 15개, 변경 범위 analyze와 release Wasm/JS 빌드 통과. 관리자 이메일/비밀번호가 패키지 92파일에 없음을 확인했다.
- ego CLI 배경 검증: 랭킹 UI 두 모드, 앱 인증 200/이벤트 204, 브라우저 저장 토큰의 실제 랭킹 제출 200과 DB 저장, 새로고침 후 동일 사용자 재사용 확인. 시험 랭킹은 삭제했고 최종 랭킹은 원본 11건이다. 실제 앱 QA 이벤트 8건은 qa 표시로 보존돼 최종 이벤트 361건, 새 플레이어 1명이다. 비밀 토큰을 보고서에 기록하지 않았다.
- 한계: 배경 게임 조작 중 자동 일시정지로 점수 획득→나가기 전체 UI 제출 흐름은 완료하지 못했다. 브라우저 직접 API 제출과 Flutter 단위 테스트 결과를 UI 종단 검증으로 표시하지 않는다. 모바일 실기기/앱인토스 배포는 미실행이다.
- 사용자가 지정한 Orca 방식을 어기고 내부 에이전트를 사용했던 것을 중단하고 3개 모두 종료했다. 최종 검수는 Orca Run `run_ba33fb9f722f`, Task `task_5641fb29505a`, Dispatch `ctx_88134dcaf753`에서 Claude로 수행했다(P1/P2 없음, 실제 모델 버전 미확인). worker_done 처리 및 ack 완료, 회수 대기 0개. worker는 runtime의 user_takeover 판정에 따라 보존했다. 앞으로 내부 subagent로 대체하지 않는다.
- 근거와 빌드: `tmp/pocketbase-migration-20260929/`, ZIP `nas/match.zip`(SHA-256 `8e217e23c2cd1c3225507f2ed578f7c765a55aed9b65fde5d6d53bc88ca14fbd`). ego 작업 공간은 종료했다. 브라우저는 ego CLI만 사용하며 일반 computer-use/앱 활성화 명령은 쓰지 않는다.




> 프로젝트 전체의 NOW. 다음 작업자 인계 문장은 HANDOFF.md에 둔다. 구현 상태와 검증 상태를 섞지 않는다.

Updated: 2026-09-29 21:48 KST

## PocketBase 이전 사전 조사 이력 (2026-09-29, 위 완료 기록으로 갱신)

- 서버 경로는 사용자 확인 `/Users/cheng80/Servers/pocketbase`, Tailscale 호스트는 `mac-mini.tailc386bf.ts.net` / `100.92.43.82`다. 로컬 Tailscale이 Stopped여서 기존 설정 그대로 `tailscale up`으로 연결했다. SSH 22번까지 도달했으나 `cheng80` 인증은 거절됐다. 로컬 SSH 키/agent identity가 없어 공개키 등록 또는 SSH 비밀번호 입력 방법을 사용자에게 문의했다. 새 호스트 키는 accept-new로 등록했으며 원격 파일/프로세스는 아직 읽거나 변경하지 못했다. 서버 위치 변수만 Git 제외 환경변수에 추가했다.

- PLAN-013 PocketBase 이전을 생성하고 Step 1 사전 조사를 진행했다. 서버 파일 배포를 위한 실제 설치 폴더와 접속/복사 방법은 사용자 확인 대기다. 기존 단일 폴더 실행 방식을 유지하며 pb_hooks/pb_migrations를 추가할 계획이다. 앱 구현과 원격 데이터 이전은 아직 수행하지 않았다.
- 원본 읽기 전용 조회: 랭킹 11행, 이벤트 353행, 설정 3행, 광고 기록 0행, 익명 사용자 38명. 공개 랭킹 API는 time/level 모두 200(각 1행)이므로 모바일 장애 원인은 미확정이다. PocketBase NAS 출처 CORS 사전 요청 204 확인. 관리 화면 표시 버전은 0.39.7이며 실제 바이너리 버전은 서버 접근 후 확인한다. 근거: `tmp/pocketbase-migration-20260929/`.
- Orca 병렬 조사 준비는 `no_active_sender_terminal`로 Run 생성 전 거절됐다. 다른 터미널 핸들을 사용하지 않았고 Task/Dispatch/worker는 생성하지 않았다. 직접 조사로 전환했다.

- 사용자 요청으로 PocketBase 주소를 `https://stonematch.fastmake.net`으로 변경했다. mac-mini Tunnel의 기존 8090 서비스를 그대로 연결하고 새 CNAME을 생성한 뒤 관리 페이지/health/관리자 인증/컬렉션 조회 HTTP 200을 확인했다. 기존 pocket 호스트의 ingress와 DNS는 제거했고 preview 경로는 보존했다. `.env.pocketbase` URL도 갱신했다. 인스턴스나 DB를 새로 만들지 않았으며 기존 데이터 변경은 없다. 관리 주소는 `https://stonematch.fastmake.net/_/`. 복구용 기존 설정과 검증 근거는 `tmp/pocketbase-domain-20260929/`다.

- 후속 사전 조사: 공식 문서의 인증, API Rules, 컬렉션, JS 확장/마이그레이션과 운영 백업을 확인했다. 입력한 관리자 정보로 health/인증/컬렉션 목록 HTTP 200 확인. 기존 `users`, `tasks`와 시스템 컬렉션 5개를 보존한다. 실제 서버 버전과 서버 훅 배포 경로는 미확인이다. 기본 Python User-Agent에서 403, Mozilla User-Agent에서 200이었으며 원인과 모바일 CORS는 미확정이다. 비밀정보를 저장하지 않은 조사 근거는 `tmp/pocketbase-discovery-20260929/`다. 아래 환경변수 준비 단계의 로그인 미실행은 이전 이력이며 이번 조사로 갱신한다. 데이터/설정 변경과 제품 구현은 없다.

- 사용자 요청으로 Supabase에서 PocketBase로 이전하는 작업을 기존 PLAN보다 우선한다. 모바일 웹 랭킹 장애와 무료 프로젝트 비활성 정지 문제는 사용자 보고이며 이번에는 원인 검증을 수행하지 않았다.
- Git 제외 `.env.pocketbase`에 `POCKETBASE_URL`, `POCKETBASE_ADMIN_EMAIL`, `POCKETBASE_ADMIN_PASSWORD`를 준비했다. 관리자 자격정보는 사용자가 로컬 파일에 입력한다. 관리 작업에만 사용하며 클라이언트 빌드에 포함하지 않는다.
- 현재는 환경변수 준비 단계다. 관리자 로그인, 데이터 이전, 앱 연결 변경과 원격 변경은 미실행이다. 입력 완료 후 기존 스키마와 인증, 랭킹, 광고 제한, 이벤트 로그 의존성을 조사해 이전 계획을 정한다. PLAN-009 Step 4는 미착수로 유지한다.

## QA 레벨 9999 기록 삭제 (2026-09-29 18:41 KST)

- 사용자 요청으로 Supabase `ranking_entries`의 `id=79`, `mode=level`, `name=QA_OLDLEVEL`, `score=9999` 기록 1건을 삭제했다.
- `private.ranking_entries_backup_20260929_qa9999`에 원본 1건을 백업하고 RLS와 클라이언트 접근 차단을 적용했다. dry-run 1건, 트랜잭션에서 원본과 백업 일치 및 삭제 1건을 검증했다.
- 사후 확인: 원본 잔여 0건, `get_ranking('level',100)` 대상 0건, 백업 1건. 같은 트랜잭션에서 나머지 랭킹 행의 전체 내용 해시가 불변임을 확인했다. 사용자 계정과 다른 기록은 변경하지 않았다.
- 실행 SQL과 결과: `tmp/qa-ranking-cleanup-20260929/`. 제품 코드 변경, 웹 재빌드/재배포, 커밋/push 없음.

## NAS 업로드 완료 (2026-09-29 18:38 KST)

- 사용자 요청에 따라 직전 검증한 `tmp/nas-web-build-20260929/match.zip`을 기존 NAS 배포 API로 업로드했다. HTTP 200, 응답 `result=OK`, 공개 주소 `https://cheng80.myqnapcloud.com/match/` 확인. 재빌드 없이 SHA-256이 일치하는 ZIP을 사용했다.
- 배포 내용은 `752f870`과 로컬 미커밋 오디오 수정 등 기존 변경을 포함한다. 현재 원격 main만으로 재현한 배포본은 아니며 사용자 소스 변경은 보존했다.
- 사후 검증: index, bootstrap, main.dart.js/mjs/wasm, stone_match_sfx.js, skwasm.wasm 7개 원격 SHA-256이 로컬과 일치. COOP/COEP, no-cache, Wasm MIME, `/match/game?mode=simple` HTTP 200과 index fallback 통과.
- ego lite의 새 탭에서 `?qaDeploy=1`로 타이틀 로딩과 메뉴 접근성을 확인했다. 이후 사용자 브라우저 조작으로 추가 플레이/랭킹 확인과 검증 탭 정리를 중단했다. 기존 사용자 탭은 닫지 않았다. 실기기 청취, 장시간 플레이와 원격 이벤트 적재는 이번에 검증하지 않았다.
- 근거: 같은 폴더의 `deploy-response.json`, `remote-verification.json`, `verification.json`. 아래 빌드 생성 항목의 업로드 미실행은 업로드 전 이력이며 이 항목으로 갱신한다. 새 커밋/push와 PLAN-009 Step 4 착수 없음.

## NAS용 웹빌드 생성 (2026-09-29 18:27 KST)

- `752f870`과 현재 로컬 미커밋 변경을 포함해 `/match/`용 release Wasm/JavaScript 폴백을 빌드했다. 메뉴 unlock 무음 수정도 포함하며, 원격 main만으로 만든 산출물과는 다르다.
- `config/supabase.json` 연결 설정과 `TELEMETRY_ENV=production`, `--no-web-resources-cdn`을 적용했다. 기존 배포 스크립트의 `.htaccess`(격리 헤더, no-cache, SPA fallback)와 Flutter Intl 패치를 적용했다.
- 산출물: `tmp/nas-web-build-20260929/match/`, 업로드용 `tmp/nas-web-build-20260929/match.zip`(33,270,989바이트). 이전 루트 `match.zip`, `match/`, `build/web`는 보존했으며 최신 빌드가 아니다.
- 검증: 빌드 성공, 오디오 JS 회귀 테스트 3개 통과, ZIP 92개 파일 CRC와 압축 전후 SHA-256 일치, 필수 Wasm/JS 파일과 base href 확인. 폐기된 ranking.php와 설정 원본은 패키지에 없다. 상세 근거는 같은 폴더의 `build.log`, `verification.json`, `sha256.json`이다.
- NAS 업로드는 하지 않았다. 이번 산출물의 실제 브라우저 실행, NAS 헤더 응답과 모바일 실기기는 미검증이며 이전 Step 3 ego 검증과 구분한다. 새 커밋/push와 PLAN-009 Step 4 착수 없음.

## PLAN-009 Step 3 판별 요약과 행동 측정 (완료)

- schema_version 3. 기존 통계의 round_summary(9필드), 종류별 round_specials(12필드), 신규 round_input(6+선택 1필드)을 시도별 한 번 기록한다. 이어하기는 판 누적값, 새 판/재시작은 초기화, NoMoves는 보존한다.
- 실패 교환, 성공한 탭/드래그 교환, 직접 특수 발동, 첫 성공 active_s, 수동 힌트와 실제 아이템 사용을 측정한다. Last Hurrah 자동 수치 포함 여부와 입력 귀속 규칙은 TECH_SPEC 필드 사전에 명시했다.
- 제목/게임 메뉴와 이름 입력창의 open/confirm/cancel을 표본 기록한다. 입력 이름과 문자열은 보내지 않는다. 세션 기준 10%, 세션당 40건이며 요약은 전수다. 운영/QA/개발/테스트 필드, 늦은 QA 진입과 hash 경로 감지, QA 세션 유지, 재전송 메타데이터 보존을 검증했다.
- 최종 검증: 전체 Flutter 테스트 548개, 변경 범위 analyze, git diff --check 통과. 웹 release 빌드와 Wasm dry run 통과. ego에서 이름 입력 취소/시작, 힌트, 실제 드래그 교환, 통계(100점, 교환 1, 제거 3), 일시정지와 나가기 확인. 원격 적재, NAS 경로 빌드/배포, 실제 Wasm과 모바일 실기기는 미검증이다.
- 독립 검수 P1/P2 없음. 핵심 96개와 최종 집중 38개 테스트 통과. 실제 로그 payload 600개를 로컬 PGlite jsonb 제약으로 모두 저장(최대 1433바이트, 거절 0)했다.
- Orca run `run_ac5cfd8776b3`: 3A Opus/high, 3B/3C Sonnet/high 병렬, 3D Opus/high 검수. 모든 Task 성공. 정확한 모델 버전은 미확인이다. 메뉴 테스트 지연은 캐시 Future를 setUpAll에서 준비하여 해결했다. 신규 메뉴 테스트는 13개, 기존 이름창 1개와 합계 14개다(작업자 초기 보고서의 11개 표기는 정정).
- 보고서와 로그: `tmp/observability-step3-20260929/`. ego 검증 탭과 로컬 서버는 종료했다. 구현/검수 세션은 Orca 소유권 판정에 따라 release하고, 3C 세션은 runtime의 user_takeover 판정으로 보존했다.
- 사용자 승인 범위: Step 3까지만 완료 후 문서 갱신, 관련 변경 커밋/push, 워크트리 점검. 미커밋 Step 1~2는 필수 선행 구현이라 함께 포함한다. 현재 Git 워크트리는 main 1개뿐이라 삭제할 별도 작업 워크트리는 없다. 별도 오디오/포맷 변경은 보존한다.
- 다음: PLAN-009 Step 4 전송과 집계 신뢰성. 이번에는 착수하지 않는다. PLAN-010~012, GA4/Sentry SDK와 가입 개편, NAS 배포도 후속 범위다.

## PLAN-009 Step 2 판 구분과 시간 측정 (완료)

- 새 게임(run_id), 판(round_seq), 이어하기 시도(attempt_seq)를 불변 문맥으로 구분한다. schema_version 2, 레벨마다 시작/종료 이벤트, 시도별 종료 1회, 다음 레벨 중복 콜백 방어를 구현했다.
- 단조 시계로 active/system/paused/background와 총 경과를 측정한다. 이어하기는 판 시작 기준 누적 시간, 새 게임/다음 레벨은 초기화한다. 랭킹/광고 응답은 요청 시점 문맥을 캡처한다. 기존 로컬 기록, 점수와 제한 시간, 광고 키와 랭킹 제출 시점은 유지했다.
- 최종 검증: 전체 Flutter 테스트 494개, 변경 범위 analyze, 웹 release 빌드와 Wasm dry run 통과. 독립 검수 P1/P2 없음(관련 39개와 임시 재현 3개 통과). 원격 적재, Wasm 실제 실행과 모바일 실기기는 미검증이다.
- ego lite에서 로컬 release 타이틀, 게스트 레벨 진입, 일시정지/계속하기/다시하기/나가기 확인. 기존 운영 탭 보존, 검증 탭과 서버 정리. 사용자 지정 이전 Chromium 39개 통과는 별도 과거 이력이며 최종 JS/Wasm 테스트 판별 변경 후에는 VM만 재검증했다. 앞으로 브라우저 검증은 ego만 사용한다.
- Orca run `run_10ebaf784e07`: 2A/2B Sonnet high 병렬, 2C 연결과 후속 수정, 2D 독립 검수는 Opus high. 별칭만 확인했으므로 5.5 등 실제 버전 번호는 미확인이다. 모든 Task 성공, 회수 대기 0개. 구현 세션 1개는 runtime의 external_terminal 판정에 따라 보존했고 나머지 작업자는 release했다.
- 검증과 보고서: `tmp/observability-step2-20260929/`. 브라우저 지정은 DEVELOPMENT_WORKFLOW에도 반영했다. 기존 오디오와 in_app_review_service/sfx_play_log/ui_atlas 관련 별도 작업은 보존했다. 커밋/push/원격 설정/배포 없음.
- 당시 다음: PLAN-009 Step 3 판별 요약과 행동 측정. 기존 게임 통계 재사용, 누적치 해석과 이벤트별 12필드 예산을 먼저 확정한다. Step 4와 PLAN-010~012는 후속이다.

## 관측과 사용자 식별 Step 1 완료 기록 (2026-09-29)

- 사용자 요청: 기존 통계 보완부터 한 단계씩 진행하고 독립 작업은 Orca CLI로 병렬 조정한다. PLAN-009(기반), PLAN-010(사용자 식별과 기록), PLAN-011(GA4), PLAN-012(충돌/오류)을 만들었다. 해당 실행의 제품 변경은 PLAN-009 Step 1이었다.
- EventLogger params에 event_id, event_seq, schema_version을 최초 enqueue 때 추가해 재전송에도 유지한다. 예약 이름 보호, 기존 사용자 필드 12개와 별도 계산, UTF-8 JSON 1500바이트 상한, 크기로 제외한 개수 params_dropped, 비유한 숫자와 NUL/잘못된 surrogate 정제를 넣었다. DB 열/권한/원격 상태는 변경하지 않았다.
- 최신 검증: 전체 Flutter 테스트 453개, 변경한 로거/테스트의 analyze 문제 없음. 로컬 PGlite 실제 payload 600개 저장 성공, jsonb 최대 1352바이트, 거절 0. 빌드/실기기/원격 수집 미실행. 전체 lib/test 분석의 중간 결과에는 별도 작업 중인 in_app_review_service.dart info 2건이 있었고 이 작업에서는 해당 파일을 수정하지 않았다.
- Orca run: run_230dae3fd1cb. 구현 Claude sonnet/high, 독립 생명주기 조사와 검수 Claude 기본 모델. Codex 준비 시간 초과 시도는 작업 전달 전 실패해 release하고 Claude로 대체했다. 결과: tmp/observability-plan-20260929/.
- 독립 검수 P1/P2 없음. 추가 로컬 PGlite 퍼징 3,031행 모두 저장 성공, 최대 jsonb 1540바이트. 구버전 schema_version 누락=v0 해석을 명세에 반영했다. 작업자 3개(준비 실패 1개 포함) release 완료, 회수 대기 0개.
- 진행 표시 규칙: 현재 세션명은 플랜명, Orca 세션은 `플랜명 | Step N 세부 작업명`, 화면 안내는 `플랜명 → 세부 스텝명 → 상태`로 표시한다. 이후 단계와 플랜에도 유지한다.
- 당시 다음 작업: PLAN-009 Step 2에서 run/round/attempt 및 활성/정지/백그라운드 시간 계약과 테스트 주입부터 진행한다. PLAN-009 9절에 병렬 분해와 비동기 결과의 판 문맥 캡처, 광고 키 보존, Last Hurrah 통계 주의점을 남겼다. GA4/Sentry/가입 화면은 아직 연결하지 않는다.
- 서버 중복 제거와 영속 큐는 Step 4 전까지 없다. event_id 추가만으로 중복 삽입/종료 유실이 해결된 것은 아니다. 커밋/push/배포 없음. 기존 오디오 및 별도 작업 변경은 보존한다.

## 메뉴 진입 효과음 중복 경로 수정 (2026-09-29)

- 웹 `unlock()`이 첫 입력과 화면 복귀 뒤 기존 효과음을 4슬롯에서 `volume=0`으로 재생했다. 볼륨 쓰기를 무시하는 모의 환경에서 첫 진입과 복귀의 원치 않는 효과음 재생을 재현했다. 10ms 무음 WAV 데이터로 준비 재생을 교체했다. 사용자 제보 환경과 동일 원인인지는 실기기 확인이 필요하다.
- 검증: `node --test test/web/stone_match_sfx_test.mjs` 3개 통과(수정 전 동일 테스트 2개 실패), `flutter test test/sound_manager_test.dart` 17개 통과, `flutter analyze lib test` 문제 없음. 전체 `flutter analyze`는 기존 `tmp/` 임시 Dart 파일을 포함해 247건으로 실패했다.
- 실제 브라우저와 기기 청취, 웹 빌드 및 배포는 미실행. 다음 확인은 제보 기기에서 첫 메뉴 입력과 화면 복귀 후 중복음 여부 및 정상 효과음 유지다. 커밋과 원격 변경 없음.

## 로컬 임시 자료 정리 (2026-09-28)

- 사용자 요청으로 오래된 웹 빌드 10개, 검증용 `node_modules` 4개, 시험 ZIP, QA 캡처와 PDF 렌더링 이미지 등 2,383개 파일(할당 크기 약 906MiB)을 정리했다. `tmp/`는 약 972MiB에서 67MiB로 줄었다.
- 원본 PDF, 연구 자료, 인계 백업, 패치, 검증 스크립트와 의존성 명세, 결과 로그, 성능 측정 JSON, 연결 설정은 보존했다. 보존 파일 718개의 SHA-256과 파일 속성 일치, 열린 파일 핸들 없음, 삭제 대상 부재를 확인했다.
- 상세 목록과 검증 결과는 `tmp/cleanup-20260928/`에 있다. 제품 코드와 원격 상태 변경 없음. Flutter 테스트와 빌드는 재실행하지 않았다. 기존 검증 기록의 화면 캡처와 빌드 실물 일부는 이번에 삭제됐으므로 다시 확인하려면 새로 생성한다.

## Current Phase
Phase 3 — Stabilization (Phase 4 출시 값은 대기)
Phase 5 게임 방향 개편 진행 중. PLAN-005 Step 1a, 1b, 1c, 3을 main에 반영했고 Step 4(일일 동일 보드, 주간 순위), Step 5(레벨 도전 스테이지)도 main에 반영하고 NAS에 배포했다(`223303e`). 이어서 아이템과 이어하기 이벤트도 연결했다. PLAN-005에 남은 것은 사용자 플레이가 필요한 시간 보상 T1(D7)과 플레이테스트 기록뿐이다. 2026-09-24 사용자 결정: 앱 구조 개편 완료가 우선이고 앱인토스 빌드 확인과 광고(AdMob)는 그 뒤로 미룬다.
이관 단계: 대체 가능(REPLACEABLE). 2026-08-23 표준 팩만으로 대체 가능성 점검 12항 통과. 정본은 docs/. 이전 문서는 archive/docs/. 릴리즈 준비와 분리.

## Active Plan
- `PLAN-009` 기존 게임 통계 기반 보강 — IN_PROGRESS (Step 1~3 완료, 다음 Step 4 전송과 집계 신뢰성)
- `PLAN-010` 최소 사용자 식별과 기록 연결 — DRAFT
- `PLAN-011` GA4와 상세 행동 분석 — DRAFT
- `PLAN-012` 충돌과 오류 관측 — DRAFT
- `PLAN-001` 모바일 웹 오디오/FPS 회귀 — IN_PROGRESS
- `PLAN-004` 보드 연출 보강 — IN_PROGRESS (F1, T1, T2, T3, T4a, T4b, T5, T6 통합 완료, T6 및 독립 리뷰 수정 완료, 합본 HUD 잔상 가설은 픽셀 진단으로 기각, 기존 confetti 겹침)
- `PLAN-005` Bejeweled Blitz 계승 게임 방향 개편 — IN_PROGRESS (ADR-008 Accepted. Step 1a, 1b, 1c, 3, 4, 5 main 반영. Step 2 아이템과 이어하기 이벤트, 1d(D7 플레이테스트) 남음. D8, D9 권장안 결정)
- `PLAN-007` 일일 동일 보드와 주간 순위 — DONE
- `PLAN-008` 실험 기능 일괄 도입과 스위치 — DONE(채택 판단은 플레이테스트 뒤)
- `PLAN-006` Supabase 기반 구축 — IN_PROGRESS (Step 1~3 완료, Step 4 NAS 배포 완료(`b71ba31`). 앱인토스 QR 확인은 사용자 결정으로 보류. 남은 것: 익명 사용자 정리 정책, Supabase 요금제와 일시정지 정책)

## Current Tasks
- [x] TASK-001a HTML Audio 4슬롯/경로/unlock/웹 BGM replay
- [x] TASK-001b 짧은 수동 확인 (복귀 SFX, 다시 하기 BGM)
- [ ] TASK-001c 실기기 30초 이상 카운터 보존 — IN_PROGRESS
- [ ] TASK-001d 무한 모드 배너 표시/미표시 A/B
- [ ] TASK-001e 특수효과 표시/미표시 A/B
- [ ] TASK-001f 결과로 Status/Handoff 갱신
- [x] TASK-004a PLAN-004 Step 1, 2 구현 (보석 물리감, BoardJuiceLayer, HUD 롤업)
- [x] TASK-004b 화면/오버레이 연출, 보석 피드백, 사운드 계층 및 blur 제거 통합, UI_UX 반영
- [x] TASK-004c T6 레벨 클리어 시각 연출, reduced motion 즉시 완료 및 독립 리뷰 수정
- [x] TASK-004d 합본 HUD 잔상 가설 진단: 추가 glyph 없음, 기존 confetti 겹침, 제품 수정 없음
- [x] TASK-004e 다른 계열 교차 리뷰(X2) 결함 6건 수정과 main 병합
- [x] TASK-004f bomb 범위 효과를 정지 그림 + 코드 타임라인 + 구운 글로우로 교체, main 병합
- [x] TASK-004g hyper, supernova 레이어 전환 구현과 데스크톱 검증 완료 (main `c3b64dd` 병합 및 작업 Worktree/Orca 세션 정리 완료)
- [x] TASK-004h 기본 매칭 파편/콤보 별빛의 중력과 위쪽 편향 제거, 방사형 감속/소멸로 조정. 후속 확산1.4배, 수명65%, 유휴 반짝임2/3, 광택 스윕80%/반복10초 (main 반영)
- [ ] TASK-004d 모바일 실기기 FPS 전후 비교, 장시간 WebView와 실제 광고 SDK 확인
- [x] TASK-MIG-001 F1~T6 합본 analyze / test / web build 과거 통과 기록 보존. E2 데스크톱 검증은 완료, 실기기 스모크는 미실행
- [x] TASK-005a 게임 방향 조사와 기획 문서화: Product Spec "게임 방향 기획" 절, ADR-008(Proposed), PLAN-005(DRAFT), ROADMAP Phase 5, 특수 보석 룰 11-1절 원문 대조 정정
- [x] TASK-005b D1~D6 권장안 승인(2026-09-24). D10 해당 없음. D8, D9는 막히면 권장안이라는 사용자 승인에 따라 권장안으로 결정. D7은 플레이테스트 대기
- [x] TASK-005c Step 1a 하이퍼 교환 H1~H3(`f343fad`), 1b Speed Bonus(`936dfee`), 1c Last Hurrah(`a2d78d2`), Step 3 기록과 장기 목표(`baaff7c`), 통합 검수 R-1~R-10 수정(`f8a209d`, `b71ba31`)
- [x] TASK-005d Step 2 아이템, 이어하기 이벤트 연결(Playwright 7/7)과 플레이테스트 기록 양식. 기록 자체는 사용자 플레이 필요
- [x] TASK-005e Step 4 일일 동일 보드와 주간 순위(PLAN-007, `4435ecb`, 조회 계획 보강 `70cad69`, 원격 적용)
- [x] TASK-005f Step 5 레벨 도전 스테이지(`87f50ca`, BR-043)
- [x] TASK-005g 독립 검수 R3(P0 0, P1 1, P2 1, P3 7) 반영(`f2a26ae`, `70cad69`), 비활성 익명 사용자 정리(`cef0acc`)
- [x] TASK-008a 실험 스위치(T1, Time 보석, Multiplier 보석, 7색, Last Hurrah 콤보) 구현, 검수 R4 반영, 원격 적용
- [x] TASK-008b Last Hurrah 권장안 규칙: 마무리 연쇄의 새 특수 보석 생성 금지, Multiplier 배율 동결, 자연 연쇄 20단계 상한, Last Hurrah 콤보 코드 기본값 꺼짐(원격 행은 아직 true, 변경하지 않음)
- [x] TASK-009a 텍스처 아틀라스 통합: board_atlas, ui_atlas, ui_buttons_atlas(무손실 WebP), 쓰지 않던 레거시 시트 번들 제외(TECH_SPEC 3-1 텍스처 아틀라스)
- [x] TASK-009b 웹 로딩 화면을 HTML, CSS로 교체(네이티브는 Flutter 로딩 유지), 웹 hot restart 뒤 BGM 중첩 수정, 이름 입력창이 키보드에 가려 취소와 시작을 누를 수 없던 문제 수정(Android Chrome 실기기 확인)
- [x] TASK-001g ISSUE-007 멀티스레드 skwasm 같은 탭 재로드 멈춤: Flutter 3.44.8 → 3.47.5 업그레이드로 해소(2026-09-24, Android Chrome 같은 탭 연속 6회 모두 정상)
- [x] TASK-006a Supabase 스키마, 익명 로그인 게이트웨이, 랭킹 이전, 보충 광고 서버 확인, 이벤트 로거 구현과 테스트
- [x] TASK-006b Supabase 원격 프로젝트 준비, 마이그레이션 적용, 원격 스모크, NAS 배포(`b71ba31`)

## Completed
- Phase 1 Foundation, Phase 2 Core Features
- 문서 계약을 코드 기준으로 맞춤
- Standard 구조: ROADMAP / PLAN / STATUS
- 기존 주제 본문·문서 자산 Detailed Migration

## Blocked / Known Issues
- PLAN-002: 토스 사용자 식별과 서버 저장 정책 없음
- 앱인토스 QR 확인: 연결된 Android 폰에 토스 앱이 없고, 사용자 결정으로 구조 개편 뒤로 보류. 테스트 빌드는 업로드됨(deploymentId `01a0cf90-3f74-7371-9055-43700af3daae`)
- TASK-004: Apple ID, 개인정보 URL, INTOSS 운영 광고 그룹은 제품 외부 결정
- ISSUE-001: 모바일 웹 오디오 끊김 이력, 장시간 카운터 없음 → PLAN-001
- ISSUE-002: 앱인토스 iPhone FPS 급락, GC 단정 금지 → PLAN-001
- ISSUE-003: refill 3회 → Supabase 익명 사용자 기준으로 원격 적용과 NAS 배포 완료(PLAN-006). 저장소 삭제나 재설치 시 새 사용자라 제한이 새로 시작된다(BR-103)
- ISSUE-004: RunInventory 비영속 → PLAN-003 (2차 범위로는 허용)
- ISSUE-005: 빈 App Store ID
- ISSUE-007(해소, 2026-09-24): 같은 탭에서 게임 문서를 다시 불러오면 멀티스레드 skwasm이 메모리 오류로 멈추던 문제. Flutter 3.47.5로 올린 뒤 격리 헤더를 켠 profile wasm 빌드로 같은 탭 연속 실행 6회(각 25초 자동 플레이) 모두 멈춤 없음(예전에는 1~2회 안에 멈춤). 20초 평균 86.8fps, p95 11.3ms로 이전(89.2fps, 11.2ms)과 같은 수준 → PLAN-001
- ISSUE-006: 미출시로 외부 사용 지표 없음. GA4, Firebase Analytics 미연동. 내부 이벤트 로거는 Supabase `game_events`로 동작한다. 시험 데이터는 매 검증 뒤 지워 현재 수집 데이터는 없다 → PLAN-006, PLAN-005 Step 2

## Implementation Status
- 주요 기능: 3모드 매치-3, 특수 보석 탭 발동, 레벨 런 인벤토리 2차, 선택형 광고, 랭킹, 다국어. F1, T1, T2, T3, T4a, T4b, T5 연출 통합 상태. hyper/supernova 레이어 후속 E2는 main `c3b64dd`에 반영했고 병합 후 데스크톱 검증을 통과했다. 버전 1.0.0+1
- Release Readiness: 스토어 문서 초안과 채널 define은 있음. 운영 광고 그룹, Apple ID, URL, flavor 미입력. 장시간 모바일 웹 회귀 미완

## Verification Status

검증은 구현 완료와 다르다. 과거 결과는 HISTORICAL, 이관 중 재실행만 RECHECKED. 이후 코드가 바뀌면 STALE.

| 항목 | Result | Evidence | Date | Revision | Validity | Source / Gap |
|---|---|---|---|---|---|---|
| Integrated F1-T6 analyze / test / web build | PASS | HISTORICAL | 2026-09-20 15:53 KST | F1~T6 통합 리비전 | STALE | `verify_integrated_final.txt`: analyze exit=0 (1.8s), 262 tests passed, web build exit=0. 이후 X2와 bomb 후속 변경으로 현재 기준이 아님 |
| Bomb E1 layer analyze / test / web build | PASS | HISTORICAL | 2026-09-20 | bomb 레이어 적용 리비전 | STALE | 해당 리비전에서 analyze 0, 274 tests PASS, Web build 0. 이후 E2 hyper/supernova 후속 통합 전 결과 |
| F1 input regression review | PASS | RECHECKED | 2026-09-20 | 동일 | CURRENT | T2 회귀 테스트가 안착/제거 중 드래그, 범프 잔류, geometry stale bump 3건과 pointer flow를 통과 |
| PLAN-004 desktop screen / widget / pixel checks | PASS | RECHECKED | 2026-09-20 | 동일 | CURRENT | F1/T1/T2/T3/T4a/T4b/T5 근거. T4b ego 문자 중복은 headless에서 재현되지 않아 원인 미확정 |
| PLAN-004 mobile device UI / FPS | PARTIAL | RECHECKED | 2026-09-20 22:09 KST | `99622e9` | INCOMPLETE | Android Chrome35초 rAF 평균63.94FPS/GAP55.94ms. iPhone NAS 미러링 탭/드래그 매치, Safari 특수효과6회/30초 AVG46.3/LOW35.3/GAP53ms, 같은 보드 대기47.7/44.1/28ms. Instruments 분석은 디스크 부족으로 미완. 22:20 사용자 요청으로 원시 기록 정리, 결과 문서 보존. 폰 단독/토스/광고A/B/장시간 미완. [iPhone 상세](IPHONE_NAS_FPS_2026-09-20.md), [Android 상세](ANDROID_NAS_FPS_2026-09-20.md) |
| T6 level celebration | PASS | RECHECKED | 2026-09-20 | 동일 | CURRENT | 일반 3000ms / reduced motion 즉시, 점수/시간/보상 불변 테스트와 합본 화면 확인 |
| Independent review fixes | PASS | RECHECKED | 2026-09-20 | 동일 | CURRENT | F1 입력 3건, 게임 이탈 자원 해제와 release snapshot P2 수정 및 재검증. 합본 HUD 추가 진단은 기존 confetti 겹침으로 마감 |
| NAS Web smoke | PASS | RECHECKED | 2026-09-20 21:20 KST | 제품 main `99622e9` | CURRENT | `tmp/nas-deploy-20260920/`: Wasm 배포 HTTP200, index/bootstrap/wasm/MP3 원격 해시 일치, deep route200, 격리 헤더, 두 모드 랭킹 조회 통과. Android 게임 로드 확인 |
| Apps in Toss 재배포 | PASS | HISTORICAL | 2026-08-15 | d777cf0 | STALE | git 문서: 일반 AIT 재배포. 이후 오디오 수정. 현재 리비전 미재검증 |
| Web 장시간 오디오/FPS | INCOMPLETE | HISTORICAL | 2026-08-23 이전 | PLAN-001 / ADR-004 원문 | UNKNOWN | 짧은 수동 확인만 통과. 장시간 카운터 없음. 원문부터 미완 |
| Android/iOS store device | NOT_RUN | NONE | UNKNOWN | UNKNOWN | UNKNOWN | 출시 체크리스트 미완 |
| Release build F1-T6 revision | PASS | HISTORICAL | 2026-09-20 15:53 KST | F1~T6 통합 리비전 | STALE | integrated_final Web build exit=0. 이후 X2와 bomb 후속 변경, 모바일/스토어 실기기 스모크는 별도 미실행 |
| E2 hyper/supernova layer integration | PASS | HISTORICAL | 2026-09-20 19:54 KST | main `c3b64dd` (후속 문서 갱신만 추가) | STALE | `verify_main_after_E2_merge.txt`: main 병합 후 analyze exit=0, 전체 279 tests PASS, Web release build exit=0. 병합 전 독립 78회귀+픽셀4회귀와 실제 보드 캡처도 확인. 실기기 미검증 |
| 매칭 파편 방사형 소멸 | PASS | HISTORICAL | 2026-09-20 20:24 KST | main `9137895` + 미커밋 파편 수정 | STALE | `tmp/match-radial-fx/analyze.log`: analyze exit0, `test.log`: 전체 279 tests PASS. 웹 릴리즈 재빌드와 새 브라우저 캡처는 미실행 |
| 매칭 속도/반짝임/광택 스윕 튜닝 | PASS | RECHECKED | 2026-09-20 21:06 KST | 이 문서를 포함한 main 튜닝 커밋과 동일 제품 코드 | CURRENT | `/Users/cheng80/orca/workspaces/jewelmatch/_fx_orchestration/reports/verify_main_tuning_before_commit.txt`: analyze exit0, 전체279tests PASS, Web release build exit0. 앞선 debug hot reload와 화면 유지 확인. 실기기 미검증 |
| 게임 방향 기획 문서화 | PASS | RECHECKED | 2026-09-23 23:17 KST | 문서만 변경, 제품 코드 `b6a949e`와 동일 | CURRENT | 문서 전용 변경. 변경 문서 8개의 상대 링크 전수 확인(깨진 링크 0), 추가 줄 중간점 0, `git diff --check` 통과. 코드 테스트 대상 아님 |
| Supabase 1단계 analyze / test / wasm build | PASS | RECHECKED | 2026-09-23 23:40 KST | `b6a949e` + 미커밋 PLAN-006 변경 | CURRENT | analyze 0건, 전체 300 tests PASS, `flutter build web --release --wasm`(가짜 연결 값) exit 0. 원격 Supabase 미적용이라 실제 서버 동작은 미검증 |
| Supabase 검수 수정 analyze / test / wasm / SQL | PASS | RECHECKED | 2026-09-24 00:30 KST | `b6a949e` + 미커밋 PLAN-006 변경 | CURRENT | `flutter analyze lib test` 0건, 전체 310 tests PASS, `--wasm` 릴리즈 빌드 exit 0. PGlite 하네스 58건, 20건, 보존 OK(`tmp/orca-plan006/`). 전체 `flutter analyze`는 `tmp/fx-prompt-builder`의 기존 info 1건만 보고. 원격, 브라우저 두 탭 미검증 |
| Supabase 원격 스모크 / RLS (로컬 웹 + 실제 백엔드) | PASS | RECHECKED | 2026-09-24 01:05 KST | `e1a75c5` | CURRENT | Playwright 헤드리스, `tmp/local-verify/live.log` 25항목, `live_edge.log` R-1, R-2, RLS. 백엔드 없는 빌드 흐름 3개 시나리오 통과. 시험 데이터 정리 후 0건. 실기기, 토스 WebView 미검증 |
| PLAN-005 1차 통합 analyze / test / wasm | PASS | RECHECKED | 2026-09-24 04:30 KST | `b71ba31` | CURRENT | `flutter analyze lib test` 0건, 전체 373 tests PASS, `--wasm` 릴리즈 빌드 exit 0 |
| PLAN-005 1차 로컬 웹 + 실제 백엔드 | PASS | RECHECKED | 2026-09-24 04:40 KST | `b71ba31` | CURRENT | Playwright `tmp/local-verify/s8_plan005.js` 15/15(하이퍼 교환, Speed Bonus, Last Hurrah, 기록 화면, 랭킹 제출 1회) |
| Supabase 원격 스모크 재실행(최종 점수 비교) | PASS | RECHECKED | 2026-09-24 05:30 KST | `b71ba31` | CURRENT | `s4_live.js`를 판 도중 점수 대신 제출한 최종 점수와 TimeUp 점수로 비교하게 고친 뒤 26/26 PASS. 시험 데이터 정리 후 사용자, 랭킹, 이벤트, 광고 기록 0건 |
| Android NAS PLAN-005 1차 FPS | PASS | RECHECKED | 2026-09-24 04:50 KST | NAS `b71ba31` | CURRENT | SM-A245N, Android 16, Chrome 153, 90Hz. CDP rAF 20초 플레이 평균 89fps, p95 11.2ms, Last Hurrah 중 약 88fps, 랭킹 제출 200 1회. 장시간, 토스 WebView, 실제 광고 SDK는 미검증 |
| NAS 배포와 캐시 헤더 | PASS | RECHECKED | 2026-09-24 04:45 KST | `b71ba31` | CURRENT | `.htaccess`에 html, js, mjs, wasm, json `Cache-Control: no-cache`. 이전 캐시 파일이 섞여 skwasm이 "function signature mismatch"로 멈추던 문제를 폰에서 재현 뒤 해결 |
| PLAN-005 Step 4, 5 analyze / test / wasm | PASS | RECHECKED | 2026-09-24 05:30 KST | `f2a26ae` | CURRENT | `flutter analyze lib test` 0건, 전체 392 tests PASS, `--wasm` 릴리즈 빌드 exit 0 |
| PLAN-005 Step 4, 5 로컬 웹 + 실제 백엔드 | PASS | RECHECKED | 2026-09-24 05:40 KST | `f2a26ae` | CURRENT | `s10_plan005b.js` 20/20(두 사용자 같은 시작 보드, 같은 이동 4번 뒤 같은 보드와 점수, 지난주 기록 제외 순위, 레벨 전체 기간, 도전 스테이지 판정과 클리어, `daily_key`, `challenge` 이벤트). 회귀 `s8_plan005.js` 14/14, `s4_live.js` 26/26. HUD 스크린샷 확인 |
| 주간 랭킹 SQL과 익명 사용자 정리 | PASS | RECHECKED | 2026-09-24 05:35 KST | 마이그레이션 4개 원격 적용 | CURRENT | PGlite 주간 27/27, 회귀 60/60, 강제 generic 계획에서 time 조회 주간 인덱스 버퍼 4. 익명 정리는 원격 트랜잭션 안에서 가짜 사용자 5명으로 확인 후 되돌림. advisor는 기존 익명 로그인 경고만 |
| Android NAS PLAN-005 Step 4, 5 | PARTIAL | RECHECKED | 2026-09-24 05:50 KST | NAS `223303e` | CURRENT | 폰 시작 보드가 데스크톱과 같음, 20초 평균 89.3~89.6fps, p95 11.2ms, 주간 제출 200 1회, 도전 스테이지 상태 정상. 같은 탭 재로드 뒤 skwasm 멈춤(ISSUE-007, 기존 문제) 확인. 최종 `2889d7e` 배포 뒤 새 Chrome에서 8/8(이번 회차 평균 76.3fps, p95 22.4ms로 앞선 89fps보다 낮아 발열이나 첫 로드 영향 가능성, 장시간 측정은 PLAN-001) |
| PLAN-008 실험 스위치 analyze / test / wasm | PASS | RECHECKED | 2026-09-24 08:00 KST | `4ed725e` | CURRENT | `flutter analyze lib test` 0건, 전체 431 tests PASS, `--wasm` 빌드 exit 0. 스위치 꺼짐은 8c703a6과 날짜 3개 × 120 입력에서 보드, 점수, 시간이 바이트 단위로 같음(검수 R4) |
| PLAN-008 로컬 웹 + 실제 백엔드 | PASS | RECHECKED | 2026-09-24 08:05 KST | `4ed725e` | CURRENT | `s15_plan008.js` 13/13(원격 조회와 캐시, Time +5초, 배율 ×2, exp 이벤트, URL 판 랭킹 제외, exp=none 기존 동작, 레벨 7색, 타임 6색). 회귀 s10 20/20, s8 14/14, s14 7/7. 배지와 7색 스크린샷 확인 |
| Last Hurrah 권장안 analyze / test | PASS | RECHECKED | 2026-09-24 11:30 KST | 이 문서를 포함한 Last Hurrah 권장안 커밋 | CURRENT | `flutter analyze lib test` 0건, 전체 441 tests PASS. 시드 보드 60판(bomb, hyper, star 배치) 비교: 마무리 중 새 특수 보석이 생긴 판 28 → 0, 추가 점수 최대 14,450 → 6,050(원격 현재값인 콤보 켬은 9,500). 저장소 루트 `flutter analyze`는 Git 제외 `tmp/` 옛 Dart 파일 247건이라 범위를 lib, test로 둔다. 웹 빌드와 실기기, NAS 배포는 미실행 |

## Next
1. 사용자 플레이테스트: PLAN-005 하단 양식으로 기록하고 D7(시간 보상 T1)을 정한다. 구조 작업 중 코드로 남은 항목은 없다
2. ISSUE-007은 Flutter 3.47.5 업그레이드로 해소했다. 같은 탭 재로드 멈춤이 다시 보이면 Flutter 이슈로 보고한다
3. 플레이테스트 때 PLAN-008 스위치를 켜고 끄며 비교한다(원격은 모두 켜짐, `?exp=none`으로 기존 동작). Supabase는 무료 요금제 유지(2026-09-24 사용자 결정)
4. 구조 개편 뒤: 앱인토스 QR 확인(토스 앱이 있는 폰 필요), Play와 App Store용 Google AdMob 연결(ADR-003 개정). 웹(NAS)은 테스트 전용이라 광고 없음
5. 출시 값(운영 광고 그룹, Apple ID, URL)이 오면 TASK-004. PLAN-003 영속 인벤토리는 코인 경제 전 단계로 Phase 6
6. PLAN-001 장시간 모바일 웹 오디오/FPS 측정은 별도 승인 작업

- 합본 HUD 최종 진단(16:08 KST): 무손실 PNG의 추가 밝은 glyph 픽셀 0, 변한 픽셀은 confetti 색 합성으로 설명됐다. pause 150프레임 동안 game render/update 증가 0. 제품 소스 변경 없이 가설 기각. 근거: `_fx_orchestration/reports/T6_integrated_visual_fix.md`.

## 최신 NAS 배포와 Android 계측 (2026-09-20 21:20 KST)
- main `99622e9` 푸시, 로컬 웹 산출물 정리, NAS Wasm 배포 완료. 로컬 개발 서버와 scrcpy 미러링은 종료했다.
- 사용자 첫 이펙트 멈춤 제보를 개발자 도구로 조사 중. 35초/유효 입력34회 측정에서 큰 멈춤은 재현되지 않았으나 90Hz 기기 평균63.94FPS/p95 33.57ms로 성능 검증은 미완. GPU/워커 추적을 포함한 원인 확정이 다음 우선 작업이다.
- 원시자료와 제한은 `tmp/android-fps-20260920/RESULT.md`와 `profile.json`. 초기 화면 GAP280ms와 재측정 GAP55.94ms는 조건이 달라 개선 수치로 비교하지 않는다.

## 재접속 확인과 인계 취소 (2026-09-20 21:26 KST)
- 게임 탭 완전 종료 후 재접속 및 첫 매치/특수효과를 재측정했다. 로딩 최대190.2ms, 첫 매치22.4ms, 첫 bomb/hyper/supernova33.6/44.8/44.8ms. 긴 작업은 첫 매치 이전 Wasm 초기화/초기 렌더 구간에 집중됐다. 최초 사용자 멈춤의 동일 원인 여부는 미확정.
- 상세 근거와 한계: [Android NAS FPS 검증](ANDROID_NAS_FPS_2026-09-20.md). 제품 코드 수정 없음.
- 사용자 요청으로 Claude 인계 예약을 취소(PAUSED)했고 현재 Codex가 계속한다. 기존 Claude에 재개 프롬프트를 보내지 않았다.

## 사용 종료 세션과 브랜치 정리 (2026-09-20 21:31 KST)
- jewelmatch Orca Claude main 세션 `term_15b04b61-db10-4b8c-a439-b4a5739056b8`을 닫았다. 개별 close의 ptyKilled=true, 후속 terminal list의0개, 해당 Claude와 자식 프로세스 부재로 종료를 확인했다. 최초 bulk close의 완료 확인 오류는 개별 종료와 후속 검증으로 해소했다.
- Git/Orca 워크트리는 main1개뿐이며 잔여 작업 워크트리나 prune 대상이 없다. main에 조상으로 포함된 `codex/intoss-level-leaderboard-ui`(643781d) 로컬 브랜치를 `git branch -d`로 삭제했다. 로컬 브랜치는 main만 남는다. 원격 브랜치는 변경하지 않았다.
- main 사용자 변경과 미추적 파일 없음. 원본 에셋/보고서/Android 원시 계측/이전 Worktree 백업 보존. 정리 전 터미널 메타데이터/화면과 브랜치/Worktree 목록은 `_fx_orchestration/backups_pre_cleanup/main-session-20260920/`에 보관했다.
- 기존 Claude 재개 기록을 현재 작업의 인계 대상으로 사용하지 않는다. 취소한 인계 예약은 PAUSED 유지. 현재 Codex 작업과 다른 프로젝트 세션은 유지했다.

## QA 임시 산출물 정리 (2026-09-20 22:20 KST)

- 사용자 요청으로 QA 이미지/렌더 결과, Android/iPhone 계측과 압축 추적, 검증 로그, 제출 ZIP 검사본/패키징 중간본, Flutter 테스트 캐시와 이번 Instruments 잔여물533파일(할당 크기797,634,560바이트)을 정리했다. 과거 기록의 해당 임시 경로는 현재 존재하지 않는다.
- 결과 보고서, 소스/에셋, NAS 배포본과 `match.zip`, 인계 백업, 설계 산출물은 보존했다. 원본 경로가 확인되지 않는 BRICK ZERO 참고 PDF2개는 `tmp/qa/` 아래에 남겼다. 측정 재개 시 원시 기록을 새로 수집한다.

## 이번 미러링 검증 종료 (2026-09-20 22:44 KST)

- 사용자 결정으로 미러링 검증을 마감하고 추가 Instruments/CPU/GPU 프로파일링을 진행하지 않는다. 앞선 정밀 분석 재개와 미러링 유무 비교 제안은 이번 작업의 후속 실행 대상에서 제외한다.
- 기존 FPS 수치와 미검증 범위는 그대로 남긴다. 검증 종료를 전체 성능 검증 통과로 바꾸지 않는다. 실행 중인 iPhone 미러링, scrcpy, Instruments, xctrace 프로세스가 없음을 확인했다.


## 게임 방향 기획 정리 (2026-09-23 23:10 KST)

- 사용자 요청으로 게임 방향 조사 결과를 기획 문서로 정리했다. 조사 범위는 요즘 사가형 공식 도움말, Bejeweled 3 원문 PDF 2종(PopCap 공략집 2010, DS 매뉴얼 2011), Fandom 문서 21개, Reddit 스레드다. 제품 코드, 테스트, 배포 변경은 없다.
- 제안 방향: Bejeweled Blitz식 60초 점수 경쟁을 지금 방식으로 다시 만든다. 타임 모드는 얼굴과 실력 경쟁, 레벨 모드는 진행과 수익, 무한 모드는 휴식 모드로 유지한다. 재화보다 재화 없는 장기 목표(누적 랭크, 배지, 기록)를 먼저 넣는다. 특수 보석 탭 발동은 유지한다.
- 산출물: [Product Spec 게임 방향 기획](../01_PRODUCT_SPEC.md), [ADR-008](../decisions/ADR-008-game-direction-blitz-modernized.md)(Proposed), [PLAN-005](../plans/PLAN-005-blitz-modernized-direction.md)(DRAFT), ROADMAP Phase 5 추가와 Economy의 Phase 6 이동, docs/AGENTS.md 제품 계약 1줄, README 문서 구조의 PLAN-004와 PLAN-005 누락 보완.
- 원문 대조로 특수 보석 룰 11절의 비교 대상 오류를 정정했다. 기존 표의 스왑 조합은 Bejeweled 3가 아니라 Bejeweled Stars 규칙이다. 현재 동작은 바뀌지 않는다.
- GA4 확인: 미연동. `pubspec.yaml`에 분석 SDK가 없고, `web/index.html`에 GA 태그가 없으며, Firebase 설정 파일과 Git 이력상 추가 기록도 없다. 내부 이벤트 로거도 미구현이다. NAS 배포 서버 파일은 따로 열어 보지 않았다.
- 조사 원자료(Fandom 수집본, Reddit 수집본, PDF 페이지 렌더링, 요약)는 `tmp/bejeweled-research/`에 있고 Git 추적 대상이 아니다. 원본 PDF는 저작권 자료라 저장소에 넣지 않았다.
- 커밋과 푸시는 하지 않았다.


## Supabase 기반 구축 1단계 (2026-09-23 23:47 KST)

- 사용자 요청으로 랭킹, 원격 설정, 보충 광고 하루 제한, 이벤트 로그를 Supabase로 옮기는 코드를 구현했다. 결정은 [ADR-009](../decisions/ADR-009-supabase-backend.md), 절차는 [PLAN-006](../plans/PLAN-006-supabase-backend.md).
- 사용자 결정: 랭킹을 Supabase로 옮기고 NAS 기록은 유지하지 않는다. Supabase 연결은 Codex의 Supabase 앱을 대상 조직 권한으로 다시 연결하는 방식으로 한다.
- 구현: 익명 로그인 REST 게이트웨이, 랭킹 서비스 교체(공개 API와 실패 유형 유지), 보충 광고 서버 확인과 세션 로컬 대체, EventLogger와 이벤트 7종 연결, 마이그레이션 SQL(테이블 4개, RPC 5개, 빈도 제한 트리거 2개, 전 테이블 RLS), `config/supabase.json`(Git 제외) 빌드 연결, NAS 배포 스크립트와 앱인토스 빌드 스크립트 반영.
- 검증: `flutter analyze` 0건, 전체 `flutter test` 300건 통과, `--wasm` 릴리즈 웹 빌드 통과(가짜 연결 값, 출력은 `tmp/supabase-wasm-check/`). 배포 스크립트 `bash -n` 통과.
- 차단: Codex Supabase 앱 연결 계정에서 조직 목록이 비어 있고 대상 조직은 권한 오류다. 로컬 CLI는 로그인하지 않았다. 원격 프로젝트 생성, 마이그레이션 적용, 익명 로그인 활성화, 원격 스모크는 연결 복구 뒤 진행한다.
- 커밋과 배포는 하지 않았다. 현재 NAS와 앱인토스 배포본은 여전히 NAS 랭킹을 쓴다.

## Supabase 검수, 보존, 개인정보 (2026-09-24 00:34 KST, Orca 오케스트레이션)

- 원격 없이 할 수 있는 PLAN-006 항목을 Orca 워커로 나눠 처리했다. 워커 9개(Opus 5.5 high 검수 3회, Opus 구현 2회, Sonnet 5 medium 구현 4회), 모두 같은 작업 트리에서 파일 소유를 나눴다.
- 독립 검수 결과 P0, P1은 없었다. P2 4건과 주요 P3를 두 차례 수정했다. 핵심은 웹 다중 탭 세션 충돌, 403 처리, 인증 실패 대기, 익명 사용자 삭제 시 랭킹 보존(`on delete set null`), anon 쓰기 RPC 권한 회수, 이름 문자 규칙이다. 순위 계산 비용과 점수 상한 강화는 실측 뒤로 보류했다.
- 새 파일: `supabase/migrations/20260924090000_stone_match_retention.sql`(game_events 90일, ad_refill_claims 35일 pg_cron 정리 초안), `docs/release/PRIVACY_POLICY_DRAFT.md`(법률 검토 전 초안). PRODUCT_SPEC 스토어 문구 4블록을 Supabase 기준으로 바꿨다.
- 검증: 위 표의 "Supabase 검수 수정" 행. 커밋, 원격 적용, 배포는 하지 않았다.

## 이펙트 프롬프트 빌더 (2026-09-24 01:29 KST 갱신)

- 사용자 요청으로 X 글(도트 마법사 프롬프트)과 Claude 공유 대화를 분석해, 단계별 선택으로 Flutter용 이펙트 제작 프롬프트를 만드는 정적 웹 도구 `tools/fx_prompt_builder/`를 만들었다. 첫 버전은 다른 세션 커밋 `e1a75c5`에 함께 들어갔다.
- 01:29 개편(미커밋): 사용자 피드백에 따라 카드 보상 공개와 Stone Match 전용 맥락을 빼고 범용 구조로 바꿨다. 이펙트 17종(마법과 액션, 퍼즐, 공통), 발동 방식 11가지, 범위 9가지, 시점 4가지. 기본 스타일은 도트, 데모 장면은 마법사 글 구성. 퍼즐 이펙트는 Bejeweled(`tmp/bejeweled-research/`), 캔디크러시 공식 도움말, Tetris Effect 자료를 참고했다. 결과 코드는 source, target, hits, unit 좌표만 받는다.
- 검증: 프롬프트 생성 3,114개 조합에서 빈 값과 중간점 없음. 헤드리스 Chromium으로 11단계 이동, 17개 이펙트 전부 최상위 단계 재생(영향 지점 전부 발동), 발동과 범위와 시점 교차 조합, 길게 누르기 충전, 복사, JSON 내보내기와 불러오기, 새로고침 후 유지, 390px 모바일 가로 넘침 0을 확인했고 페이지 오류는 0건이다. 프롬프트가 지시하는 Flutter와 Flame API(새 `play` 시그니처, `onHit`, `GlobalKey`, `Overlay` 포함)는 점검용 Dart 파일로 `dart analyze` 문제 0건을 확인했다. 이 파일이 전체 `flutter analyze`에 남기던 info 1건도 없앴다.
- 한계: 이 도구로 만든 프롬프트를 실제 AI에 넣어 Dart 이펙트를 생성하고 실행해 보는 끝단 확인은 하지 않았다. 점검 스크립트와 스크린샷은 `tmp/fx-prompt-builder/`(Git 제외). 제품 코드는 바꾸지 않았다.


## PLAN-005 구조 개편 1차 (2026-09-24 05:00 KST, Orca 오케스트레이션)

- 사용자가 D1~D6 권장안을 승인했고, 막히면 권장안으로 진행하라고 했다. 앱인토스 빌드 확인과 광고는 구조 개편 뒤로 미뤘다.
- main 반영: 하이퍼 교환 H1~H3(`f343fad`), Speed Bonus(`936dfee`, BR-052), Last Hurrah(`a2d78d2`, ADR-007 개정), 기록과 장기 목표(`baaff7c`, SCREEN-016), QA 특수 보석 배치 훅(`23d64fb`), 통합 검수 R-1~R-10 수정(`f8a209d`, `b71ba31`). 새 이벤트: `hyper_swap`, `speed_bonus_peak`, `last_hurrah`, `badge_earned`, `rank_up`, `round_end`의 reason `restart`.
- 배포: NAS `b71ba31`. `.htaccess`에 코드 파일 no-cache 헤더를 추가했다. `ranking.php`는 저장소에서 지웠고 NAS 사본 삭제는 사용자 수동 작업이다. 공모전 ZIP 스킬은 `config/supabase.json`을 넣고 Supabase 호스트를 검사한다.
- 앱인토스: `.ait` 테스트 빌드를 올렸고(deploymentId `01a0cf90-3f74-7371-9055-43700af3daae`) QR 확인은 보류했다.
- 검증: 위 표의 PLAN-005 1차 행들. 원격 시험 데이터는 모두 지웠다.
- 이어서 Step 4(C1)와 Step 5(V1)를 Orca 워커 2개(`plan005b-daily`, `plan005b-challenge`)가 별도 워크트리에서 구현 중이다. 결정: D8은 앱인토스 공식 리더보드를 레벨 완료 수로 유지하고 주간 타임 순위는 Supabase가 맡는다. D9는 이동 제한 없이 4의 배수 레벨에 시간 제한 도전 목표(색 보석, 특수 보석 발동, 보석 수)를 섞는다.

## PLAN-005 구조 개편 2차 (2026-09-24 05:55 KST, Orca 오케스트레이션)

- Step 4(C1): 타임 모드는 KST 날짜 시드로 같은 날 같은 시작 보드와 난수 흐름을 쓴다(BR-053). 타임 랭킹은 KST 월요일 0시 기준 주간(BR-095)이며 기록은 지우지 않는다. D8은 앱인토스 리더보드를 레벨 완료 수로 유지. [PLAN-007](../plans/PLAN-007-daily-board-weekly-ranking.md)
- Step 5(V1): 4의 배수 레벨은 색 보석, 특수 발동, 보석 수 목표로 클리어하는 도전 스테이지(BR-043). D9는 이동 제한 미혼합.
- PLAN-006: 90일 비활성 익명 사용자 매일 정리(pg_cron, KST 04:20) 원격 적용.
- 진행: Orca 워커 3개(구현 Opus high와 medium, 독립 검수 Opus high). 검수 P1(NoMoves 새 보드가 판 통계를 지움, 기존 타임 모드 결과 통계에도 영향)과 P2(PG17에서 주간 인덱스 미사용)를 고쳤고, P3는 코드 수정(색 목표 순환, Last Hurrah 난수 날짜 시드, 다시 하기 때 1위 재조회)과 명세 기록(비율 보상 없음, 무제한 재도전, 제출 시각 기준 주)으로 처리했다. QA 훅이 릴리즈에서 `?qaPerf=1`로 열리는 기존 패턴(P3-3)은 앱인토스 WebView에서 URL을 바꾸기 어려워 유지했다.
- 배포와 정리: main `223303e` 푸시, NAS 배포, 워커 해제, 워크트리와 브랜치 정리, 원격 시험 데이터 0건.
- 폰 검증 중 ISSUE-007을 찾았다. 같은 조건의 A/B로 `b71ba31`에서도 재현돼 이번 변경의 회귀가 아님을 확인했다.
- 시험 데이터를 지운 직후 1시간 안에는 폰에 남은 옛 세션이 저장을 409로 거절받는다(지워진 사용자의 토큰이 아직 유효). 운영의 90일 정리는 토큰이 만료된 뒤라 새 가입으로 넘어간다. 폰 검증 전에는 `flutter.supabase_session`을 지운다.

## PLAN-008 실험 기능 일괄 도입 (2026-09-24 08:10 KST, Orca 오케스트레이션)

- 사용자가 지금은 플레이테스트를 할 수 없어 넣을 수 있는 후보를 모두 넣고 나중에 판단하기로 했다. Supabase는 무료 요금제 유지, 앱인토스는 뒤로.
- 스위치 5개: T1 시간 보상, Time 보석, Multiplier 보석, 레벨 7색, Last Hurrah 콤보 배수. 코드 기본값은 꺼짐, 원격 `app_config.gameplay`는 모두 켬(7색은 레벨 10부터). 웹은 `?exp=`로 덮어쓰며 그 판은 랭킹에 올리지 않는다. [PLAN-008](../plans/PLAN-008-experiment-flags.md)
- 그림: Time, Multiplier 배지는 imagegen 내장 도구로 기존 보석 시트를 참고해 만들었다(`assets/images/sprites/Gem_Badges.png`, 원본 `assets/design/gem_badges/`). 숫자는 코드로 그린다. 시계는 Material Icons(Apache 2.0)도 후보였으나 보석 질감과 맞추려고 생성 배지를 썼다. 7번째 색은 시트에 있던 흰 돌이다.
- Orca 워커 3개(gems Opus high, config Opus medium, 검수 Opus high). 검수 P1 2건(7번째 색이 주황으로 그려짐, URL 실험 판 랭킹 반영)과 P2 1건(T1 범위)을 고쳤다. 7번째 색 문제는 검수 전에 브라우저 스크린샷으로도 찾았다.
- 코인 보석은 코인 경제가 없어 제외했다.

## 텍스처 아틀라스 통합 (2026-09-24 09:40 KST, Orca 오케스트레이션)

- 사용자 요청: 쓰는 텍스처는 되도록 한 장으로 묶어 드로우콜을 줄이고 쓰지 않는 것은 뺀다.
- 결과: 보드와 이펙트 30칸은 `board_atlas.webp`, UI 24장은 `ui_atlas.webp`와 `ui_buttons_atlas.webp`. 레거시 시트(Special_Area 3장, flame, supernova 오버레이 등)와 원본 PNG는 `assets/design/legacy/`로 옮겨 번들에서 뺐다. 번들에 남은 이미지는 아틀라스 3장과 타이틀, 스플래시, 배경뿐이다.
- 수치는 TECH_SPEC 3-1 텍스처 아틀라스 절. 텍스처 수와 전환은 크게 줄었고, 보드 그리기 호출은 7회에서 5회. HUD는 작은 아이콘이 흐려지지 않게 호출을 묶지 않아 수는 그대로다(같은 텍스처라 GPU에서 합쳐짐).
- 검증: analyze 0, 전체 437 tests, 작업 전 빌드와 스크린샷 픽셀 비교, 회귀 s15 13/13, s10 20/20, s8, s14 통과. 도구 `tools/pack_atlas.py`와 설정 `tools/atlas/*.json`.

- 브라우저 기준(2026-09-29 사용자 지정): 앞으로 검증은 ego 브라우저를 사용한다. Chrome과 캐시 Chromium으로 새 검증을 시작하지 않는다. 이번 Chromium 39개 통과는 이 지정 이전 이력으로만 남긴다.

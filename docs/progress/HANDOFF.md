# Handoff

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

- Sentry 이슈12개/이벤트29건 모두 QA 기록이며 검증용10개 resolved 처리. STONE-MATCH-5/6은 접근성 버튼 예외가 Flutter ClickDebouncer의 reset을 건너뛰어 후속 입력을 막는 문제로 재현했다.
- `lib/utils/semantics_error_guard.dart`와 main 시작 연결, 회귀 테스트2개 추가. 원본 예외는 FlutterError로 보고하고 엔진 입력 상태 정리를 진행한다. Sentry 비활성에도 적용한다.
- 관련30테스트/전체 analyze/게임 release Wasm+JS 빌드 통과. 브라우저 수정 전 실패, 수정 후 JS/Wasm 후속 탭2회/오류1회와 수집 비활성 JS 복구 확인. 원격 테스트 이벤트 추가 없음.
- 로컬 수정 완료이며 커밋/push/배포는 하지 않았다. 입력 오류2개는 unresolved 유지, 게시 후 운영 검증과 resolved 처리가 다음 단계다. 실기기 접근성 검수는 미수행. 상세: PLAN-012 15절, `tmp/sentry-triage-20260930/`.

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

> 아래는 배포 이전 인계 이력이며 최신 상태는 위 완료 기록을 따른다. 2026-09-29 신규 세션 전체 인계: [PocketBase Step4 및 Sentry 인계](HANDOFF_2026-09-29_POCKETBASE_STEP4.md)를 먼저 읽는다. Flutter 576개와 웹 빌드 통과, 최종 서버 24개 통과. Step4 서버/NAS 배포는 아직 미실행이다. 사용자는 Sentry 가입/CLI 인증 완료, 프로젝트 CLI 생성 요청 후 신규 세션 인계를 요청했다.

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




> 다음 작업자가 즉시 시작할 정보만 둔다. 프로젝트 전체 상태는 PROJECT_STATUS.md에 둔다.

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

## 임시 자료 정리 인계 (2026-09-28)

- 사용자 요청으로 과거 웹 빌드, 검증용 의존성, 시험 ZIP, QA 캡처와 PDF 렌더링 이미지 등 약 906MiB를 정리했다. 삭제 목록과 검증 결과는 `tmp/cleanup-20260928/`에 있다. 아래 과거 기록의 빌드와 캡처 보존 설명은 이번 정리 이전 상태다.
- 원본 PDF, 연구 자료, 인계 백업, 패치, 검증 스크립트, 결과 로그와 성능 측정 JSON, 연결 설정은 보존했다. 보존 파일 718개의 내용과 속성 일치를 확인했다.
- 웹 검증 전 필요한 출력 경로에 다시 빌드한다. `tmp/fx-prompt-builder/`, `tmp/orca-plan006/pglite/`, `tmp/orca-plan006/retention/`, `tmp/plan005b/review3/pglite/`는 `package.json`과 `package-lock.json`이 남아 있으므로 각 폴더에서 `npm ci` 후 검증 스크립트를 실행한다. 제품 코드와 원격 상태 변경 없음. Flutter 테스트와 빌드는 재실행하지 않았다.

## Current State
2026-09-24 11:35: Last Hurrah를 권장안 규칙으로 정리했다(Product Spec 6-4). 첫 자동 발동부터 보드에 마무리 규칙을 걸어 연쇄가 새 특수 보석을 만들지 않고, Multiplier 배율은 오르지 않으며, 자연 연쇄는 20단계까지만 해소한다. 시간 0 순간 진행 중이던 마지막 수는 기존 규칙으로 끝낸다. `last_hurrah_combo_multiplier` 코드 기본값은 꺼짐(`exp` 표시는 켰을 때 `lhc`)으로 바꿨지만 원격 `app_config.gameplay`에는 아직 `true`가 있어 원격 설정을 받는 빌드는 콤보 켬으로 돈다. 권장안 기본으로 보려면 원격 값을 false로 바꾸거나 웹에서 `?exp=-lhc`. 원격 값 변경, push, NAS 배포는 하지 않았다. 점수 분포 탐침은 `tmp/last-hurrah-policy/probe_test.dart`(Git 제외, `flutter test tmp/last-hurrah-policy/probe_test.dart`).

2026-09-24 08:10: PLAN-008 실험 스위치(T1, Time 보석, Multiplier 보석, 레벨 7색, Last Hurrah 콤보)를 main에 넣고 원격 `app_config.gameplay`를 모두 켰다. 끄려면 대시보드에서 값을 바꾸거나 웹에서 `?exp=none`. URL 실험 판은 랭킹에 올리지 않는다. 검증 스크립트 `tmp/local-verify/s15_plan008.js`.

2026-09-24 05:55: PLAN-005 Step 4(일일 동일 보드, 주간 순위, PLAN-007)와 Step 5(도전 스테이지)를 main `223303e`에 반영하고 NAS에 배포했다. Supabase 마이그레이션 3개(주간 랭킹, 조회 계획 보강, 익명 사용자 정리)를 원격에 적용했다. 워커와 워크트리는 정리했다. 이어서 아이템과 이어하기 이벤트도 연결했다. 남은 것은 D7 플레이테스트와 ISSUE-007(멀티스레드 skwasm 같은 탭 재로드 멈춤, 기존 문제)이다. 폰 검증 스크립트는 `tmp/local-verify/s11_android_p5b.js`, A/B는 `s12_ab.js`, `s13_fps.js`.

2026-09-24 05:40: PLAN-005 1차(하이퍼 교환, Speed Bonus, Last Hurrah, 기록과 장기 목표)를 main `b71ba31`에 반영하고 NAS에 배포했다. 로컬 웹과 실제 백엔드, Android 폰 NAS 검증을 통과했다. 사용자 결정으로 앱 구조 개편 완료가 우선이고 앱인토스 QR 확인과 광고(AdMob)는 그 뒤다. Step 4(일일 동일 보드, 주간 순위)와 Step 5(레벨 도전 스테이지)는 Orca 워커(`plan005b-daily`, `plan005b-challenge`, run `run_588b87db9418`)가 구현 중이다. D8, D9는 권장안으로 정했다(PROJECT_STATUS 하단).

2026-09-24 01:09: Supabase 원격 프로젝트 `stone-match`(ref `irbdozfwptserldnisew`, 서울)에 마이그레이션 2개와 인증 설정을 적용했고, 로컬 웹 빌드로 실제 백엔드 검수를 마쳤다(PLAN-006 Step 2~3). 시험 데이터는 지웠다. 배포는 하지 않았다.

2026-09-24: PLAN-006 로컬 코드의 독립 검수와 두 차례 수정, 보존 마이그레이션 초안, 개인정보처리방침 초안을 마쳤다. 원격 적용은 여전히 Supabase 연결 대기다.

2026-09-23: Supabase 기반 구축(PLAN-006) 1단계 코드와 스키마를 구현했다. 원격 프로젝트 적용은 Codex Supabase 앱 연결 대기다. 아래 게임 방향 기획 상태도 그대로 유효하다.

2026-09-23: 게임 방향 개편을 기획 문서로 정리했다(ADR-008 Proposed, PLAN-005 DRAFT, Product Spec "게임 방향 기획" 절). 사용자 결정 D1~D10 대기 중이며 제품 코드는 바뀌지 않았다. 아래 기존 상태는 그대로 유효하다.

이번 NAS 미러링 검증은 사용자 요청으로 종료했다. Android/iPhone 측정 결과와 한계는 보고서에 보존했고 QA 원시자료는 정리했다. 추가 프로파일링과 미러링 유무 비교를 자동으로 재개하지 않는다.

최신 추가 변경: 중력을 제거한 매칭 파편의 초기 속도를 1.4배, 수명을 65%로 조정했다. 보석 위 유휴 반짝임 밝기는 2/3, 대각선 광택 스윕 속도는 80%다(한 칸 0.9초, 반복 10초). 최종 튜닝은 main에 반영하며 같은 제품 코드에서 analyze, 전체279tests, Web release build가 모두 통과했다. 개발 서버는 사용자 요청으로 정상 종료했고 8080 포트 리스너가 없음을 확인했다. 추가 실행 중인 구현/검증 프로세스는 없다.

문서 팩은 대체 가능(REPLACEABLE). 정본은 docs/. 이전 문서는 archive/docs/. F1~T6가 통합됐고 독립 리뷰의 입력 3건, 자원 해제와 릴리즈 퇴장 문제 2건을 수정했다. 검증 공백은 표에 남아 있다. 최종 합본 HUD 글자 중복 가설은 PNG 픽셀과 실제 렌더 진단에서 기각됐으며 기존 confetti 겹침으로 확인했다. 실기기 전체 검증은 미완이며 Android 단기 계측 결과는 아래 보고서를 따른다. E2 hyper/supernova 레이어 통합은 main `c3b64dd`에 병합했고 main 분석, 전체 279 tests, Web release build를 통과했다. `fx-g2-sprites` Worktree와 연결된 Orca 터미널 2개는 정리했다. 기존 Claude main 세션은 사용자 정리 요청으로 종료했고, 재인계 예약도 취소 상태다.

## Last Completed
- 마이그레이션 가이드 기준으로 운영 칸을 이 팩에 맞춤
- 기존 주제 본문과 문서 전용 PNG 31장 이관
- 코드와 어긋나던 점수 산식, HUD 랭킹, 시계, 제출 시점을 문서에 반영
- 2026-08-23 대체 가능성 점검 12항을 표준 팩만으로 통과. 이후 정본 경로를 docs/로 옮기고 이전 문서는 archive/docs/로 둠
- 2026-09-20 F1, T1, T2, T3, T4a, T4b, T5, T6 통합 완료. T2가 F1 독립 검수의 입력 회귀 3건을 수정하고 회귀 테스트를 추가했으며 T5가 특수/HUD glow를 baked atlas로 전환
- 과거 합본 검증 `verify_integrated_final.txt`: analyze 0, 262 tests PASS, Web build 0. X2와 bomb 후속 변경으로 HISTORICAL/STALE
- 2026-09-20 다른 계열 교차 리뷰(X2)에서 확정된 결함 6건 수정을 main에 병합: 로딩 오버레이가 1.2초 뒤 멈추던 문제, iOS 15/16 Safari에서 피치 대신 배속만 바뀌던 문제(`webkitPreservesPitch`), 퇴장 고스트 해상도, 광고 결과 배너 위치, 웹 폴백 로그 rate, `CurvedAnimation` 해제
- 2026-09-20 bomb 범위 효과를 16프레임 플립북에서 정지 그림 5장 + 코드 타임라인 + 구운 글로우 밑깔기로 교체(`bomb_layers.png` 1280×256, `bomb_layer_timeline.dart`). 정점 지름 약 3.1칸, 수명 0.52초 그대로, bomb 텍스처 6.00MiB → 1.25MiB. 병합 직전 검증: analyze 0, 274 tests PASS, Web build 0
- G2 hyper/supernova 정지 레이어 PNG 납품과 정량 게이트 PASS를 확인했다. 제품 통합과 실제 Flutter 렌더 검증, main 병합과 병합 후 데스크톱 검증을 완료했다. 실기기 검증은 별도다.

## In Progress
- Plan: `PLAN-004` 보드 연출 보강. F1, T1, T2, T3, T4a, T4b, T5, T6 구현과 통합 완료. 2026-09-20 통합 브랜치를 커밋해 main에 fast-forward 병합했다(로컬). push 여부는 `git status`로 확인한다
- Task: 실기기 검증. 합본 HUD 진단은 glyph 중복 근거 없음으로 마감했다.
- Task: E2는 main 병합 및 작업 세션 정리 완료. Claude 재인계는 취소됐으며 Codex가 현재 main에서 계속한다.
- 주의: T2의 균등 gem atlas 제출은 batch지만 여러 행의 착지 squash는 `drawImageRect` fallback으로 draw call이 9회를 넘을 수 있다. T5 special glow는 약 4.5MiB 공유 이미지이며 T4a HUD interactions와 painters 구조를 유지한다
- 주의: T4b 타임업은 reduced motion에서도 결과를 즉시 읽히게 하되 1900ms 제출과 버튼 활성 시점을 유지한다. ego 캡처 문자 중복은 headless에서 재현되지 않아 원인 미확정
- 주의: Android Chrome 단기 FPS 계측과 iPhone NAS 미러링 검증을 수행했다. 폰 단독 iPhone 성능, 장시간 WebView, 실제 광고 SDK, 실제 기기 오디오 청취는 미검증이다
- E2 검증: 전체279tests와 Web build exit0, 최종 analyze exit0. 독립 관련78회귀와 별도픽셀4회귀 PASS. 고정pivot, tier, 풀 재사용, 종료, bomb 초기픽셀 및 supernova 외곽번개 보존 확인.
- Plan: `PLAN-001`
- Task: TASK-001c 실기기 30초 이상 카운터 보존

## Next Task
1. 이번 NAS 미러링 검증은 종료했다. 추가 프로파일링은 진행하지 않으며 아래 검증 공백은 별도 요청 전까지 남겨 둔다. Claude 재인계는 취소 상태다. 완료된 E2를 재적용하거나 정리된 Worktree를 재생성하지 않는다.
2. 실기기 FPS, 가독성, 오디오와 광고 흐름 확인. iOS 15/16 기기에서 연쇄와 저시간 틱의 피치가 실제로 오르는지 듣는다
3. `?fps=1`로 모바일 실기기 FPS 전후 비교와 장시간 WebView 확인
4. PLAN-001 실기기 장시간 측정 (원문부터 INCOMPLETE. 별도 승인 작업)
5. 이전 문서는 archive/docs/에 있음. 삭제 여부는 별도 결정
6. STALE AIT 재검증과 PLAN-001 실측은 이관 밖 별도 작업
7. 게임 방향 개편: 코드 작업 완료. D7과 플레이테스트 기록은 사용자 플레이 판단. ISSUE-007은 Flutter 3.47.5 업그레이드로 해소
8. Supabase: NAS 배포 완료. 앱인토스 QR 확인은 구조 개편 뒤. 원격 검증 뒤에는 시험 데이터를 지운다(game_events, ad_refill_claims, ranking_entries, 익명 auth.users)
9. 광고는 구조 작업을 끝낸 뒤 손본다(ADR-003 개정). 웹(NAS)은 테스트 전용이라 광고를 넣지 않고, Play와 App Store는 이후 Google AdMob을 `AdService` 구현으로 붙인다. 그 전에는 광고 SDK를 추가하지 않는다

## Blocked
- PLAN-002, TASK-004: 외부 값/정책

## Known Issues
- ISSUE-001, ISSUE-002: 모바일 웹 오디오/FPS. PLAN-001
- ISSUE-003: 광고 3회 세션 로컬
- ISSUE-004: 인벤토리 비영속 (2차 허용)
- ISSUE-005: 빈 App Store ID
- ISSUE-006: 외부 지표 없음(미출시), GA4와 Firebase와 내부 로거 미연동. PLAN-005 Step 2
- PLAN-006: 원격 적용과 검수 완료, 배포 전. 현재 NAS와 앱인토스 배포본은 여전히 NAS 랭킹을 쓴다. `config/supabase.json` 없는 빌드는 랭킹 연결 불가

## Changed Contracts
- PLAN-004: `ParticleBurst`/`ParticlePool` 삭제, `BoardJuiceLayer`로 대체. `hasActiveVisualEffects`는 유휴 반짝임을 포함하지 않음. HUD 점수는 롤업 표시값이고 저장/랭킹은 `board.score` 그대로. F1~T6 통합과 T2 입력 회귀 및 독립 리뷰 P2 수정 완료
- PLAN-004 시각 계약: gem atlas 512×640, 64px 셀, baked sheen, squash fallback, special glow 약 4.5MiB 공유 이미지, T4a HUD 구조 유지
- PLAN-004 화면 계약: T4b 공통 카드/exit/reduced motion, TimeUp 1900ms 제출 및 입력 시점, 레벨 축하 일반 3000ms, reduced motion 즉시 완료
- BR-040: 레벨 1~5는 level*7500, 6부터 37500+(level-5)*5000. ADR-006
- BR-092: HUD 랭킹/top1은 타임 전용
- BR-073: 시계는 인트로, 즉시형 확인, 프리즘 색 선택 중 정지
- BR-093: Pause 나가기는 제출 await, TimeUp 나가기는 기다리지 않음. ADR-007
- BR-072: 하이퍼 큐브는 일반 보석만

## Important Decisions
- ADR-001 특수 보석 탭 발동
- ADR-002 진행 랭킹 = 완료 레벨 수
- ADR-003 선택형 광고만
- ADR-004 웹 HTML Audio 4슬롯
- ADR-005 STORE_CHANNEL define
- ADR-006 목표 점수 완화
- ADR-007 제출 시점과 HUD 범위

## Verification Status

검증은 구현 완료와 다르다. 과거 결과는 HISTORICAL, 이관 중 재실행만 RECHECKED. 이후 코드가 바뀌면 STALE.

| 항목 | Result | Evidence | Date | Revision | Validity | Source / Gap |
|---|---|---|---|---|---|---|
| Integrated F1-T6 analyze / test / web build | PASS | HISTORICAL | 2026-09-20 15:53 KST | F1~T6 통합 리비전 | STALE | `verify_integrated_final.txt`: analyze exit=0 (1.8s), 262 tests passed, web build exit=0. 이후 X2와 bomb 후속 변경으로 현재 기준이 아님 |
| Bomb E1 layer analyze / test / web build | PASS | HISTORICAL | 2026-09-20 | bomb 레이어 적용 리비전 | STALE | 해당 리비전에서 analyze 0, 274 tests PASS, Web build 0. 이후 E2 hyper/supernova 후속 통합 전 결과 |
| F1 input regression review | PASS | RECHECKED | 2026-09-20 | 동일 | CURRENT | T2의 3개 회귀 테스트와 pointer flow 통과 |
| PLAN-004 desktop screen / widget / pixel checks | PASS | RECHECKED | 2026-09-20 | 동일 | CURRENT | T1~T5의 ego/headless, 위젯, 픽셀 근거. T4b ego 문자 중복은 headless 재현 없음, 원인 미확정 |
| PLAN-004 mobile device UI / FPS | PARTIAL | RECHECKED | 2026-09-20 22:09 KST | `99622e9` | INCOMPLETE | Android Chrome35초 rAF 평균63.94FPS, p95 33.57ms, GAP55.94ms. iPhone 미러링 특수효과30초 AVG46.3/LOW35.3/GAP53ms. 첫 멈춤 원인과 폰 단독/토스/광고A/B/장시간 미확인. 원시자료는 정리했고 보고서를 보존했다. [Android 상세](ANDROID_NAS_FPS_2026-09-20.md), [iPhone 상세](IPHONE_NAS_FPS_2026-09-20.md) |
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

## Files to Read First
1. progress/PROJECT_STATUS.md
2. 이 파일
3. plans/PLAN-004-board-juice.md
4. plans/PLAN-001-mobile-web-audio-fps.md
5. decisions/ADR-004-web-html-audio-sfx.md
6. 01_PRODUCT_SPEC.md 의 FR-003, FR-010
7. 게임 방향 작업 시: decisions/ADR-008-game-direction-blitz-modernized.md, plans/PLAN-005-blitz-modernized-direction.md, 01_PRODUCT_SPEC.md 의 "게임 방향 기획" 절
8. Supabase 작업 시: decisions/ADR-009-supabase-backend.md, plans/PLAN-006-supabase-backend.md, 03_TECH_SPEC.md 5절

## Resume Commands
이 팩만 보고 실행한다. 비밀은 넣지 않는다.

    flutter test
    flutter analyze

웹 측정이 필요하면 PLAN-001의 웹 빌드 절과 FPS 패널(`?fps=1` 또는 `?qaPerf=1`)을 쓴다.

## Open Questions
- STALE 배포 증거를 현재 리비전에서 재검증할지는 이관 밖 결정
- 21:20 KST Claude 재인계 예약은 사용자 요청으로 PAUSED 처리했다. 인계 프롬프트 전송 없음.
- PLAN-002 식별 저장 정책
- 게임 방향 개편 미결정 사항 D1~D10 (Product Spec "게임 방향 기획" 9절)

## Constraints / Do Not Change
- BR-001, BR-002
- 특수 보석 탭 발동, 스왑 조합 비활성 (ADR-008 Accepted와 D2, D4 결정 전까지 유지)
- 강제 전면 광고 없음
- ranking.php를 웹 빌드/제출 ZIP에 넣지 않음
- Riverpod codegen 금지
- 사용자 문구 중간점 금지
- ADR-004: Web Audio로 되돌리지 말 것
- STALE/INCOMPLETE를 숨기지 말 것. 이전 문서는 archive/docs/
- 정본 docs/와 archive/docs/를 서로 링크로 묶지 말 것
- 현재 작업 폴더는 `/Users/cheng80/Desktop/Anther_Works/Flutter_Project/FlutterFrame_work/jewelmatch`의 main이다. 정리된 `fx-g2-sprites`나 이전 통합 Worktree를 사용하지 말 것
- 삭제 전 자료 148파일의 SHA256을 확인했고 `/Users/cheng80/orca/workspaces/jewelmatch/_fx_orchestration/backups_pre_cleanup/fx-g2-sprites-20260920-e2`에 보존했다. 보고서와 보드 PNG는 `/Users/cheng80/orca/workspaces/jewelmatch/_fx_orchestration`에도 유지한다.
- 제품 main `99622e9`는 origin/main 푸시 및 NAS 배포 완료. Android 단기 계측과 iPhone 미러링 검증을 수행했으며 전체 실기기 검증 완료로 오인하지 말 것

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

## iPhone NAS 미러링 제어 확인 (2026-09-20 21:41 KST)

- 제품 `99622e9` NAS Wasm 빌드. iPhone14 Pro Max/iOS26.6.2, 사용자가 미리 연 홈 화면 웹 앱을 Mac iPhone 미러링에서 제어했다. 토스 앱 검증은 아니다. 가설은 미러링으로 실제 게임 입력이 가능하다는 것이며, 진입과 매칭 후 보드/점수 변화로 확인했다. 제품/사운드 설정 변경 없음. 배너 없음, 효과 켜짐, 실제 청취 미검증.
- 무한 모드 진입, 인접 보석을 두 번씩 탭하는 교환2회, 첫 매칭 및 후속 연쇄 동작을 확인했다. 점수0→100→4050, 최대 콤보3. 입력/대기가 섞인 약1분 확인이며 마지막30초 내부 패널은 AVG40.2/LOW31.3/GAP75ms. 진입 직후 GAP1375ms는 로딩이 섞인 창으로 별도 취급한다. 마지막 화면은 이 Codex 대화의 21:38 미러링 캡처에 있으며, 연속 프레임 로그/영상 파일은 수집하지 않았다. 미러링 부하를 분리하지 않았으므로 폰 단독 FPS나 원래 제보한 멈춤의 원인으로 일반화하지 않는다.
- Xcode27.0, USB connected/paired, Developer Mode Enabled, DDI contentIsCompatible=true/isUsable=true 확인. `xctrace list devices`는 처음 Offline, 재조회에서 Devices로 변경됐으나 실제 Animation Hitches 5초 기록 시도는 `Timed out waiting for device to boot`(exit13)로 실패했다. 이후 CoreDevice는 booted/connected를 유지했다. 기기가 꺼진 것으로 해석하지 않으며 Instruments 준비 상태 불일치 원인은 미확정. 유효한 trace/CPU/100ms 이상 이벤트 수/프로세스별 분석 결과 없음.
- 다음 비교는 동일 NAS 무한 모드에서 미러링을 끄고 사용자가 직접 같은 입력을 하는30초 측정이다. 먼저 Instruments 실제 기록 가능 상태를 확인해야 한다. 이번에는 제품 코드/배포 변경 없이 문서만 갱신했으며, 프로파일 명령은 종료됐다. 미러링과 게임은 사용자가 이어 볼 수 있게 유지했다.

## iPhone 후속 반복 테스트 (2026-09-20 22:09 KST)

- 위21:41 기록 이후 테스트를 재개했다. 일반 매칭 탭/드래그와 연쇄를 확인했고, 별도 Safari NAS 진단 보드에서 특수효과를5초 간격6회/30.274초 재생했다. 내부 패널 AVG46.3/LOW35.3/GAP53ms. 같은 보드30.404초 대기는47.7/44.1/28ms. 미러링이 켜진 조건이며 폰 단독/토스 결과로 일반화하지 않는다.
- Instruments GUI에서는30초 기록과 원시3.4GiB 생성을 확인했다. 후처리 중 Mac 디스크 부족과 앱 종료로 분석 실패. 축소 추출도 공간 부족으로 중단하고 이번 실행의 임시 캐시만 정리했다. 원시 기록은 압축526MB, SHA256 왕복 검증 후 보존했다. 긴 멈춤 건수/CPU/GPU 분석 완료로 표시하지 않는다.
- [iPhone NAS 검증](IPHONE_NAS_FPS_2026-09-20.md)에 조건, 결과, 차단 상태와 복구 경로를 기록했다. 측정 탭/추적 프로세스 정리, 기존 Safari 탭과 홈 화면 앱 보존. 제품 코드/배포/커밋/푸시 변경 없음.
- 22:11 원래 홈 화면 앱 복귀 시 재로딩 후 타이틀 표시. 이전 보드 복원은 확인되지 않았으며, 백그라운드 복귀/메모리 상황을 분리한 추가 확인 대상으로 남긴다.

## QA 임시 산출물 정리 (2026-09-20 22:20 KST)

- 사용자 요청으로 `tmp/qa/`의 임시 파일, `tmp/android-fps-20260920/`, `tmp/nas-deploy-20260920/`, `tmp/match-radial-fx/`, `tmp/match-radial-tuning/`, `tmp/stone_submission_package/`, `build/test_cache/`, `build/unit_test_assets/`와 이번 Instruments 실행의 잔여 임시 폴더를 정리했다. 총533파일, 할당 크기797,634,560바이트. 실행 중인 계측/개발 서버와 대상 파일의 열린 핸들은 없었다.
- `tmp/qa/`에는 원본 위치가 사라진 BRICK ZERO 참고 PDF2개만 남겼다. 사용자 소스/에셋, 제품 빌드/배포본, 제출 ZIP, 인계 백업, 결과 문서는 유지했다. Git 변경은 보고서/상태 문서뿐이다.
- 위 시간별 기록의 원시자료 보존 설명은22:20 정리 이전 상태다. Android 프레임/CPU 기록과 iPhone 압축 추적은 현재 없으며 재분석하려면 새 측정이 필요하다. 확정된 수치와 미검증 범위는 두 실기기 보고서에 남겼다.

## 미러링 검증 종료 결정 (2026-09-20 22:44 KST)

- 사용자가 미러링 검증을 종료하고 추가 프로파일링을 하지 않기로 했다. 위 과거 항목의 Instruments 재개, 원시 추적 재수집, 미러링 유무 비교를 자동으로 이어서 실행하지 않는다.
- 기존 Android/iPhone 측정 수치와 한계만 보존한다. 전체 성능 검증을 통과한 것으로 해석하지 않는다. iPhone 미러링, scrcpy, Instruments, xctrace 프로세스는 모두 실행 중이지 않다. 제품 코드/배포 변경 없음.


## 게임 방향 기획 정리 (2026-09-23 23:10 KST)

- 게임 방향 개편은 제안 단계다. 본문은 [Product Spec 게임 방향 기획](../01_PRODUCT_SPEC.md) 절, 결정은 [ADR-008](../decisions/ADR-008-game-direction-blitz-modernized.md)(Proposed), 구현 단계는 [PLAN-005](../plans/PLAN-005-blitz-modernized-direction.md)(DRAFT)다.
- 다음 작업자는 사용자 결정(D1~D10) 없이 특수 보석 규칙, TimeUp 제출 시점, 랭킹 정책을 바꾸지 않는다. 결정이 오면 PLAN-005 Step 0 게이트를 체크하고 Step 1a(하이퍼 큐브 교환)부터 시작한다.
- 하이퍼 교환의 코드 진입점은 `lib/game/match_board_input.dart`의 `_triggerSpecialSwapImpl`(현재 항상 false)과 같은 파일의 특수 보석 탭 분기, 연쇄 큐는 `match_board_specials.dart`의 `includeHyper` 조건이다.
- 외부 지표는 미출시라 없고 분석 도구도 없다(ISSUE-006). 출시 전 판단은 Product Spec 8-2 플레이테스트 항목으로 하고 결과를 PLAN-005 하단에 기록한다.
- 조사 원자료는 `tmp/bejeweled-research/`(Git 미추적)에 있다. 원본 PDF는 저장소에 넣지 않는다.
- 제품 코드, 테스트, 배포 변경 없음. 커밋하지 않았다.


## Supabase 기반 구축 인계 (2026-09-23 23:47 KST)

- 2026-09-24 갱신: 원격 연결은 Supabase CLI 로그인으로 한다(Codex Supabase 앱은 조직을 보지 못함). 저장소는 `supabase link`로 `irbdozfwptserldnisew`에 연결돼 있다(`supabase/.temp`, Git 제외). SQL 확인은 `supabase db query --linked`, 권고는 `supabase db advisors --linked`. DB 비밀번호는 `tmp/supabase-remote/db-password`.
- 원격 인증 설정을 바꿀 때는 저장소 `supabase/config.toml`(로컬 개발용 값 포함)을 밀지 않는다. `tmp/supabase-remote/push/supabase/config.toml`처럼 바꿀 값만 적은 파일로 `supabase config diff` 뒤 `config push`한다.
- 실제 백엔드 재검수: `flutter build web --release --wasm --base-href / --dart-define=STORE_CHANNEL=intoss --dart-define=INTOSS_AD_MODE=mock --dart-define-from-file=config/supabase.json -o tmp/local-verify/web-live`, `cd tmp/local-verify && DIR=web-live PORT=8766 node serve.js`, 다른 터미널에서 `BASE=http://127.0.0.1:8766 node s4_live.js`, `node s5_live_edge.js`. 끝나면 시험 사용자와 행을 SQL로 지운다.
- 아직 확인하지 않은 것: 익명 가입 빈도 제한 값(원격 기본값 유지), 실기기와 앱인토스 WebView, pg_cron의 실제 새벽 실행(`cron.job_run_details`).
- 검수 기록과 PGlite 하네스는 `tmp/orca-plan006/`(Git 제외)에 있다. `review/`, `recheck/`, `recheck2/` 보고서와 `pglite/run_fixed.mjs`, `recheck/sql_recheck_fixed.mjs`, `retention/test.mjs`로 SQL을 다시 확인할 수 있다.
- 개인정보처리방침은 `docs/release/PRIVACY_POLICY_DRAFT.md` 초안이다. 문의처, 광고 SDK 수집 항목, 보관 기간, 국외 이전 해석은 [확정 필요]다.
- `config/supabase.json` 없이 만든 빌드는 랭킹이 연결 불가로 표시된다. 운영 앱인토스 빌드(`npm run build:intoss`)는 파일이 없으면 실패한다. 공모전 ZIP 스킬은 아직 config를 넣지 않는다.
- NAS `ranking.php`는 새 빌드 배포 전까지 기존 배포본이 계속 쓴다. 폐기 시점은 사용자 결정 대기.
- 제품 코드와 문서는 `d102ee3`, `a13b121`, `e1a75c5`로 로컬 커밋됐고 push 전이다. 이 인계 갱신은 그 뒤의 미커밋 변경이다.

## 이펙트 프롬프트 빌더 인계 (2026-09-24 01:29 KST 갱신)

- `tools/fx_prompt_builder/index.html`을 브라우저로 열어 쓴다. 구조와 참고 출처는 같은 폴더 `README.md`.
- 01:29 범용 개편은 미커밋이다. 첫 버전은 `e1a75c5`에 들어가 있다. 저장 키가 `fxPromptBuilder.v2`로 바뀌어 첫 버전의 브라우저 저장값은 읽지 않는다.
- 이펙트 종류를 늘리려면 `data.js`의 `FX.EFFECTS`에 추천값 묶음을 추가한다. 새 발동 방식이나 범위는 `FX.DELIVERIES`, `FX.AREAS`와 `preview.js`의 `buildHits`, `hitTimes`, `drawDelivery`, `prompt.js`의 `deliveryText`, `areaText`를 함께 고친다.
- 재검증: 저장소 루트에서 `node tmp/fx-prompt-builder/smoke.js`(조합 생성), `tmp/fx-prompt-builder`에서 `node e2e2.js`(브라우저, `playwright-core`와 사용자 캐시의 헤드리스 Chromium 필요).

- 브라우저 기준(2026-09-29 사용자 지정): 앞으로 검증은 ego 브라우저를 사용한다. Chrome과 캐시 Chromium으로 새 검증을 시작하지 않는다. 이번 Chromium 39개 통과는 이 지정 이전 이력으로만 남긴다.

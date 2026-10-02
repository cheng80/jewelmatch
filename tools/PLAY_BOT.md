# Stone Match 플레이 자동화

타임 모드에서 화면의 보석 색을 읽고 유효한 인접 교환을 실제 포인터로 실행한다. 최대 8회 성공 후 자연스럽게 시간이 끝날 때까지 기다리고, 종료 점수가 양수인지 확인한다. 점수나 시간을 직접 바꾸지 않는다.

## 에고에서 실행

```sh
npm install
npm run test:play-bot
npm run play:bot:ego -- --url https://cheng80.myqnapcloud.com/match/ --out tmp/play-bot/ego
```

한국어 게임 UI에서 1판 실행한다. `ego-browser`가 PATH에 있어야 한다. 다른 위치이면 `EGO_BROWSER_CLI`로 실행 파일을 지정한다. 출력된 TaskSpace ID를 기록한다. 중단된 작업은 사용자 제어 반환 후 같은 ID로 재개한다.

```sh
npm run play:bot:ego -- --space 3 --out tmp/play-bot/ego
```

에고에서는 기존 사용 통계 설정을 유지한다. 운영 분석 검증 전에 설정의 "사용 통계 보내기"를 켜고 기록한다. 활성 에고 공간이 아닌 상태나 사용자 제어 전환은 우회하지 않는다. 성공하면 에이전트가 만든 테스트 공간만 닫고 기존 사용자 탭은 보존한다. 실패하면 공간과 보고서를 보존한다. 기본 네이티브 마우스 래퍼로 교환할 때 게임 일시정지가 관찰되어, 에고 봇은 `page.cdp('Input.dispatchMouseEvent', ...)`로 드래그를 전달한다. 게임의 일반 Flutter/Flame 입력과 매치 해소 경로를 사용하며 점수나 보드를 직접 변경하지 않는다.

## 별도 브라우저에서 반복 검증

```sh
# 로컬/QA 검증: 기존 QA 브리지로 점수와 보드 변화 확인
npm run play:bot -- --url http://127.0.0.1:8765/ --qa --out tmp/play-bot/qa

# 명시적으로 요청된 운영 수집 검증: 화면 인식, 분석 동의, GA4 응답 확인
npm run play:bot -- --url https://cheng80.myqnapcloud.com/match/ --analytics --rounds 2 --out tmp/play-bot/production
```

`package.json`은 검증한 `playwright-core` 1.63.0과 `pngjs` 7.0.0을 고정한다. `playwright-core`에 맞는 Chromium이 필요하다. 기존 설치가 없으면 `npx --package=playwright@1.63.0 playwright install chromium`으로 설치하거나 `--executable`로 사용할 브라우저 실행 파일을 지정한다. `--headed`는 화면을 표시한다. `--moves 1..20`으로 판당 교환 상한을 조절한다. 이 경로는 에고의 사용자 프로필과 별도인 임시 컨텍스트를 사용한다. `--analytics` 없이 실행하면 해당 임시 컨텍스트의 분석 동의는 꺼 둔다.

`--qa`와 `--analytics`를 함께 사용하지 않는다. `qaPerf=1`은 telemetry를 QA로 분류하며 운영 속성 검증에 사용할 수 없다. 일반 테스트 요청에는 로컬/QA URL을 사용한다. 운영 게임의 정상 플레이는 게임 자체의 이벤트와 랭킹 기록을 남길 수 있으므로 대상 환경을 보고서에 명시한다.

## 성공 기준과 보고서

- 안정된 화면 2장을 비교해 낙하/연쇄 중 입력을 피한다. 보석 최소 56칸이 읽힐 때만 알려진 색의 교환을 찾으며 미인식 칸은 매치나 교환에 사용하지 않는다.
- 실제 드래그 후 보드가 바뀌어야 성공 교환으로 센다. QA 경로는 점수 증가도 확인한다. 종료 문구 이후 최소 3초를 기다리고 1초 동안 같은 점수가 유지되어야 최종값으로 기록한다. 결과창의 양수 점수까지 확인해야 실행을 성공 처리한다.
- 같은 보드의 교환이 반복 실패하거나, 종료 제한 시간 150초를 넘거나, 에고가 반복해서 일시정지하면 성공으로 처리하지 않는다. 에고에서는 에이전트 소유 공간의 게임 자동 일시정지만 최대 3회 재개한다.
- `--analytics`는 운영 측정 ID `G-1D8SDVLZQX`의 `page_view`, `level_start`, `level_end`에 성공 HTTP 응답이 있는지 확인한다. 내부 `round_start`/`round_end`가 GA4에서는 `level_start`/`level_end`로 매핑된다. 내부 `session_start`는 직접 보내지 않고 Google이 GA4 세션을 생성한다.
- 수집 HTTP 응답과 GA4 보고서 반영은 별도다. 운영 수집 요청은 대시보드 production 최근 30분 진단까지 확인한다. 대시보드가 최대 15분 캐시하며 완료일 보고서는 처리 지연이 있을 수 있다.

출력 폴더의 `report.json`에 교환 시도/성공 수, 종료 점수, 실행 성공 여부와 오류를 기록한다. 별도 브라우저의 수집 로그에는 측정 ID, 이벤트 이름, HTTP 상태만 저장한다. 쿠키, client ID, 사용자 ID, 관리자 토큰은 저장하지 않는다. 플레이 및 종료 PNG도 보존한다.

보드 좌표는 현재 `PhoneFrame` 390×750과 `MatchBoardGameLayout` 타임 모드 계산을 따른다. UI 레이아웃이나 보석 팔레트가 바뀌면 `play_bot_vision.mjs`와 실제 플레이 검증을 함께 갱신한다. 이 봇은 타임 모드 전용이며 레벨/인벤토리/광고/실기기 검증을 대신하지 않는다.

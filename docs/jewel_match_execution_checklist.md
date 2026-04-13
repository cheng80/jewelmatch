# Jewel Match — 실행·배포 체크리스트

> `START_HERE.md` §3과 함께 쓴다. **끝낸 항목은 `[x]`**, 진행 중·보류는 `[ ]`로 갱신한다.

## 제품·플레이

- [x] 8×8 매치-3 코어 (`MatchBoardLogic` / `MatchBoardRenderer`)
- [x] 심플 모드 / 타임 모드 (`JewelGameMode`, 쿼리 `mode=simple|timed`)
- [x] 일시정지·NoMoves·TimeUp 오버레이 흐름 (`docs/game_flow.md` 기준)
- [x] 타임 모드: 매치 보상 초·저시간 `TimeTic`·타임 오버 `TimeUp` SFX
- [x] 무효 스왑 `Fail` SFX
- [ ] (선택) 밸런스·난이도 튜닝 기록을 `game_flow.md` 또는 별도 GDD에 반영

## 오디오·에셋

- [x] `AssetPaths` + `SoundManager.preload` 정합 (경로 깨지면 앱 기동 실패)
- [x] BGM: 메뉴·메인 경로·포맷(wav/mp3)과 실제 파일 일치 확인
- [x] `docs/audio_aisfx_prompts.md` — AISFX / Soundverse 프롬프트 정리
- [ ] 교체한 `TimeUp` 등 SFX가 의도한 톤인지 인게임에서 최종 청취

## 플랫폼·설정

- [x] 설정: 볼륨·음소거·화면 켜짐·언어
- [x] 웹: `kIsWeb`일 때 설정의「평점 남기기」비표시, 타이틀 자동 리뷰 요청 생략
- [ ] iOS `AppConfig.appStoreId` 등 스토어 연동 값 출시 전 입력 (`docs/STORE_METADATA_*` 참고)

## Web 빌드·배포

- [x] `docs/web_build.md` — `--base-href`와 배포 폴더 관계 문서화
- [ ] 실제 서버 경로(`/jewelmatch/`, `/match/` 등)에 맞춰 **빌드 시 `--base-href`를 동일하게** 맞출 것
- [ ] 배포 후 정적 파일·라우팅·첫 로드·사운드(unlock) 스모크 테스트

## 문서·코드 동기화

- [x] `README.md` — 디렉터리·라우팅·문서 링크
- [ ] 큰 리팩터·기능 추가 시 `docs/code-flow-analysis.md`, `docs/game_flow.md` 갱신
- [ ] 세션 종료 시 **`START_HERE.md` §3·§6** 및 본 체크리스트 갱신

## 테스트·품질

- [x] `flutter test` 기본 위젯/게임 스모크
- [ ] 필요 시 통합 테스트·골든·웹 E2E 범위 확장

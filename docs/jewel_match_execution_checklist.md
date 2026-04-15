# Jewel Match — 실행·배포 체크리스트

> `START_HERE.md` §3과 함께 쓴다. **끝낸 항목은 `[x]`**, 진행 중·보류는 `[ ]`로 갱신한다.

## 제품·플레이

- [x] 8×8 매치-3 코어 (`MatchBoardLogic` / `MatchBoardRenderer`)
- [x] 심플 모드 / 타임 모드 (`JewelGameMode`, 쿼리 `mode=simple|timed`)
- [x] 일시정지·NoMoves·TimeUp 오버레이 흐름 (`docs/game_flow.md` 기준)
- [x] 타임 모드: 매치 보상 초·저시간 `TimeTic`·타임 오버 `TimeUp` SFX
- [x] 무효 스왑 `Fail` SFX
- [x] 매치 이벤트 SFX: `ComboHit`·`BigMatch`·`SpecialGem` — 우선순위 기반 단일 재생
- [x] 매치 파티클: `ParticleBurst` — 3매치(기본) / 4+·콤보·특수(화려) 3단계
- [x] 스프라이트시트 사전 로드 + `FadeTransition` 전환 → 장면 전환 버벅임 제거
- [x] 웹 오디오 정책 단순화: 앱 루트 첫 포인터다운 unlock + pending BGM만 유지
- [x] 보드 크롬/슬롯 배경 `ui.Picture` 캐싱 (`MatchBoardRenderer`)
- [x] 보드 클리핑 최소화: 낙하/리필/인트로 구간에서만 `clipRRect`
- [x] HUD `TextPainter`/`Paint` 재사용 캐싱 (`MatchGameHud`)
- [x] 개발 모드 FPS 오버레이 추가 (`PerformanceOverlay`, debug only)
- [x] 하이퍼 보석 `ColorFilter.matrix` 제거 → 전용 스프라이트 프레임 사용
- [x] 특수 보석 `col / row / bomb` 전용 시트(`Special.png`) 직접 렌더
- [x] 튜토리얼 스프라이트 프리뷰를 원본 픽셀 기준 프레임 크롭으로 통일 (`SpriteSheetFrame`)
- [x] 파티클 퍼짐 반경·입자 수·수명·글로우 강도 축소로 GPU 부담 완화
- [x] MVVM 리팩터링: `flutter_riverpod` 도입, `SettingsNotifier`·`RankingNotifier`, 오버레이 파일 분리, 공통 위젯 추출
- [x] `StarryBackground` GlobalKey 싱글톤 — App 레벨 1개만 배치, 전환 시 재생성 비용 0
- [x] 모든 라우트 `FadeTransition` + `endOfFrame` 대기 패턴 적용 (타이틀·게임·설정)
- [x] `GameView` 비율 프레임: `kIsWeb` 대신 화면 비율 기반 → 태블릿에서도 비율 유지
- [x] `PackageInfo` 캐싱 (`FutureBuilder` 제거)
- [ ] HUD 콤보 스트립 라벨/숫자 세로 간격 미세조정 마무리
- [ ] (선택) 밸런스·난이도 튜닝 기록을 `game_flow.md` 또는 별도 GDD에 반영

## 오디오·에셋

- [x] `AssetPaths` + `SoundManager.preload` 정합 (경로 깨지면 앱 기동 실패)
- [x] BGM: 메뉴·메인 경로·포맷(wav/mp3)과 실제 파일 일치 확인
- [x] 보석 스프라이트 시트 교체: `Juwel.png` → `Jewel.png` (`128×128` 프레임 기준)
- [x] 특수 보석 전용 시트 `Special.png` (`col / row / bomb`) 적용
- [x] `docs/audio_aisfx_prompts.md` — AISFX / Soundverse 프롬프트 정리
- [ ] 교체한 `TimeUp` 등 SFX가 의도한 톤인지 인게임에서 최종 청취

## 플랫폼·설정

- [x] 설정: 볼륨·음소거·화면 켜짐·언어
- [x] 웹: `kIsWeb`일 때 설정의「평점 남기기」비표시, 타이틀 자동 리뷰 요청 생략
- [ ] iOS `AppConfig.appStoreId` 등 스토어 연동 값 출시 전 입력 (App Store Connect 등에서 설정)

## 반응형 프레임·레이아웃

- [x] `PhoneFrameScaffold` + `PhoneFrame` 도입 — 고정 논리 해상도 `390×750` + `FittedBox`
- [x] `TitleView`·`SettingView`에 `PhoneFrameScaffold` 적용 → 비율·폰트·간격 유지
- [x] `GameView`는 Flame 자체 `LayoutBuilder` 스케일링 — `FittedBox` 미적용
- [x] `StarryBackground` GlobalKey 싱글톤 — `App` 레벨 1개만 (Scaffold 바깥·모든 뷰 공유)
- [ ] 웹 브라우저 리사이즈·키보드·분할 화면에서 비율 유지 최종 확인

## Web 빌드·배포

- [x] `docs/web_build.md` — `--base-href`와 배포 폴더 관계 문서화
- [ ] 실제 서버 경로(예: `/match/`)에 맞춰 **빌드 시 `--base-href`를 동일하게** 맞출 것
- [ ] 배포 후 정적 파일·라우팅·첫 로드·사운드(unlock) 스모크 테스트

## 문서·코드 동기화

- [x] `README.md` — 디렉터리·라우팅·문서 링크
- [x] 우주 배경 성능 최적화 리팩터 → `docs/code-flow-analysis.md` §11 갱신
- [x] `PhoneFrameScaffold` 도입·파티클·SFX → `code-flow-analysis.md` §9·§10 갱신
- [x] 렌더링 최적화/에셋 구조 변경 사항을 `START_HERE.md`, `docs/code-flow-analysis.md`에 반영
- [ ] 큰 리팩터·기능 추가 시 `docs/code-flow-analysis.md`, `docs/game_flow.md` 갱신
- [x] 세션 종료 시 **`START_HERE.md` §3·§6** 및 본 체크리스트 갱신

## 테스트·품질

- [x] `flutter test` 기본 위젯/게임 스모크
- [ ] 필요 시 통합 테스트·골든·웹 E2E 범위 확장

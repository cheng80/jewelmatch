# 이펙트 프롬프트 빌더

단계별로 고르면 Flutter(Dart)에서 쓸 수 있는 게임 이펙트 제작 프롬프트를 만드는 정적 웹 도구다. 빌드 없이 `index.html`을 브라우저로 열면 된다.

## 흐름

용도, 스타일, 색, 구성 요소, 타이밍, 강도와 등급, 접근성과 피드백, Flutter 구현, 결과물 순서로 고르면 마지막 단계에 프롬프트가 나온다. 오른쪽 미리보기는 같은 수치로 예고, 정지, 폭발, 여운을 재생하는 근사치다. 선택은 브라우저에 자동 저장되고 JSON으로 내보내고 불러올 수 있다.

## 참고한 방식

- X 글(majidmanzarpour, 2026-09-22)의 픽셀 마법사 프롬프트: 고정 논리 해상도와 정수 배율, 고정 팔레트, IDLE, CHARGE, CAST, RECOVER 상태 머신, 할당 없는 파티클 풀, 고정 60Hz 스텝, 품질 기준.
- Claude 공유 대화 "Building a card reveal animation": 파일 맨 위 제약 시트(FORMAT, PALETTE, MARKS, LIGHT, RULES, SOUND), 등급이 오를수록 강해지고 아래 등급에는 나오지 않는 규칙, 히트스톱과 임팩트 프레임, "더 쥬시하게"와 증상 지적을 반복하는 후속 프롬프트.

## 파일

| 파일 | 역할 |
|---|---|
| `data.js` | 선택지, 용도별 추천값, 등급별 수치 계산(`FX.derive`) |
| `prompt.js` | 선택 상태를 한국어 또는 영어 프롬프트와 후속 프롬프트로 변환 |
| `preview.js` | 캔버스 미리보기. 픽셀 스타일은 저해상도 버퍼와 Bayer 디더, 나머지는 가산광 |
| `app.js` | 단계 화면, 입력 처리, 저장, 복사와 내보내기 |

## Flutter 호환 기준

프롬프트는 Flutter SDK만으로 구현하도록 지시한다(Flame 대상은 Flame 포함). `CustomPainter(repaint:)`와 `Ticker`, 고정 크기 typed 버퍼와 `drawRawAtlas`, 미리 구운 글로우와 `BlendMode.plus`, `MediaQuery.disableAnimationsOf`, 소리 대신 cue 콜백을 쓴다. HTML 프로토타입을 함께 받는 경우에도 Flutter Canvas로 1:1 옮길 수 있는 Canvas 2D 호출만 허용한다.


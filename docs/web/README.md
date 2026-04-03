# Jewel Match 웹 페이지

앱 소개, 개인정보처리방침, 이용약관을 제공하는 정적 웹 페이지입니다.

---

## 폴더 구조

```text
docs/web/
  assets/
    style.css    # 공통 스타일
    i18n.js      # 한/영 전환 (STORAGE_KEY: jewelmatch-lang)
  jewelmatch/
    index.html   # 앱 소개/랜딩
    privacy.html # 개인정보처리방침
    terms.html   # 이용약관
```

---

## 배포 경로

스토어 메타데이터에 사용되는 URL 형식:

- 개인정보처리방침: `https://<도메인>/web/jewelmatch/privacy.html`
- 이용약관: `https://<도메인>/web/jewelmatch/terms.html`
- 앱 소개: `https://<도메인>/web/jewelmatch/index.html`

`docs/web/` 폴더 전체를 서버의 `/web/` 경로에 배포하면 됩니다.

---

## 리소스 참조

`jewelmatch/` 폴더 내 파일에서는:

- CSS: `../assets/style.css`
- JS: `../assets/i18n.js`

---

## 다국어 (한/영)

- `data-ko`, `data-en` 속성으로 짧은 문구 전환
- `data-ko-display`, `data-en-display`로 긴 본문 전환
- 선택 언어는 `localStorage` (`jewelmatch-lang`)에 저장되어 페이지 이동 시에도 유지됨

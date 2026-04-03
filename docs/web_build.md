# Web 릴리즈 빌드

## /jewelmatch/ 서브패스에서 실행

앱을 `https://example.com/jewelmatch/` 같은 서브패스에서 서비스할 때 사용합니다.

### 빌드 명령어

```bash
flutter build web --release --base-href "/jewelmatch/"
```

### 용량 줄이기 옵션

번들 크기를 줄이려면 다음 옵션을 추가할 수 있습니다:

```bash
flutter build web --release --base-href "/jewelmatch/" \
  --tree-shake-icons \
  --no-source-maps
```

| 옵션 | 설명 |
|------|------|
| `--tree-shake-icons` | 사용하지 않는 Material/Cupertino 아이콘 제거 (기본값일 수 있음) |
| `--no-source-maps` | 소스맵 미생성 → 디버깅용 파일 제외로 용량 감소 |
| `--minify` | JS/CSS 압축 (release 빌드에서 기본 적용) |

**용량 분석:**
```bash
flutter build web --release --base-href "/jewelmatch/" --analyze-size
```
빌드 후 `build/web/` 내 `.json` 리포트로 어떤 모듈이 용량을 차지하는지 확인할 수 있습니다.

### 출력 경로

빌드 결과물은 `build/web/` 폴더에 생성됩니다.

### 배포

**방법 A: 정적 호스팅 (GitHub Pages, Netlify 등)**

서버 설정을 할 수 없는 경우, `jewelmatch` 폴더를 만들고 빌드 결과물을 그 안에 복사합니다:

```bash
# 빌드 후 jewelmatch 폴더 생성 및 복사
flutter build web --release --base-href "/jewelmatch/"
mkdir -p jewelmatch
cp -r build/web/* jewelmatch/
```

`jewelmatch/` 폴더를 업로드하면 `https://example.com/jewelmatch/` 에서 서비스됩니다.

**방법 B: Nginx/Apache 등 직접 설정 가능한 서버**

1. `build/web/` 폴더 전체를 웹 서버에 업로드합니다.
2. 서버에서 `/jewelmatch/` 경로가 `build/web/` 내용을 가리키도록 설정합니다.

**예시 (Nginx):**
```nginx
location /jewelmatch/ {
    alias /path/to/build/web/;
    try_files $uri $uri/ /jewelmatch/index.html;
}
```

**예시 (Apache):**
```apache
Alias /jewelmatch /path/to/build/web
<Directory /path/to/build/web>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
    RewriteEngine On
    RewriteBase /jewelmatch/
    RewriteRule ^index\.html$ - [L]
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule . /jewelmatch/index.html [L]
</Directory>
```

### 로컬 확인

빌드 후 로컬에서 서브패스 동작을 확인하려면:

```bash
# Python으로 간단 서버 실행 (build/web에서)
cd build/web
python3 -m http.server 8080
```

그 다음 브라우저에서 `http://localhost:8080/jewelmatch/` 로 접속합니다.

> **참고:** Python http.server는 서브패스 리다이렉트를 완벽히 처리하지 못할 수 있습니다. 실제 배포 환경과 비슷하게 테스트하려면 Nginx/Apache 등으로 확인하는 것이 좋습니다.

### base-href 규칙

- 반드시 `/`로 시작하고 `/`로 끝나야 합니다.
- 예: `"/jewelmatch/"` ✅
- 예: `"/jewelmatch"` ❌ (끝에 `/` 없음)
- 루트에서 서비스할 경우: `"/"`

### 관련 파일

- `web/index.html`: `<base href="$FLUTTER_BASE_HREF">` — 빌드 시 `--base-href` 값으로 치환됨
- `lib/router.dart`: GoRouter 경로 설정 (서브패스는 base-href로 자동 처리)

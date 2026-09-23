#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ENV_FILE="$ROOT_DIR/.env"
DEPLOY_URL="${MATCH_DEPLOY_URL:-}"
DEPLOY_TOKEN="${MATCH_DEPLOY_TOKEN:-}"
BASE_HREF="/match/"
PACKAGE_DIR="$ROOT_DIR/match"
ZIP_PATH="$ROOT_DIR/match.zip"
CURRENT_STEP="startup"
TOTAL_STEPS=7

usage() {
  cat <<'EOF'
Usage:
  tools/deploy_match_web.sh [options]

Options:
  --env-file <path>      Env file path. Default: .env
  --deploy-url <url>     Override MATCH_DEPLOY_URL
  --token <token>        Override MATCH_DEPLOY_TOKEN
  -h, --help             Show this help.

Required env:
  MATCH_DEPLOY_URL=https://cheng80.myqnapcloud.com/deploy_match.php
  MATCH_DEPLOY_TOKEN=<same token as /share/Web/.match_deploy.env>

Flow:
  1. Remove stale build/web, match/, and match.zip.
  2. flutter build web --release --base-href "/match/" --wasm --no-web-resources-cdn
     (config/supabase.json이 있으면 --dart-define-from-file로 Supabase 연결 값을 넣는다)
  3. Patch Flutter web deprecated Intl checks.
  4. Copy build/web/* into local match/ and add Wasm isolation headers.
  5. Create match.zip and upload it to NAS deploy PHP.
EOF
}

log_step() {
  local step_number="$1"
  local message="$2"
  CURRENT_STEP="$message"
  echo
  echo "[$step_number/$TOTAL_STEPS] $message"
}

log_info() {
  echo "  - $*"
}

fail() {
  local message="$1"
  echo
  echo "ERROR at step: $CURRENT_STEP" >&2
  echo "$message" >&2
  exit 1
}

on_error() {
  local exit_code=$?
  echo
  echo "ERROR at step: $CURRENT_STEP" >&2
  echo "Command failed with exit code $exit_code." >&2
  exit "$exit_code"
}

trap on_error ERR

load_env_file() {
  local file_path="$1"
  [[ -f "$file_path" ]] || return 0

  local line key value
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    [[ "$line" == *"="* ]] || continue

    key="${line%%=*}"
    value="${line#*=}"
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"

    case "$key" in
      MATCH_DEPLOY_URL)
        if [[ -z "${MATCH_DEPLOY_URL:-}" && -z "$DEPLOY_URL" ]]; then
          DEPLOY_URL="$value"
        fi
        ;;
      MATCH_DEPLOY_TOKEN)
        if [[ -z "${MATCH_DEPLOY_TOKEN:-}" && -z "$DEPLOY_TOKEN" ]]; then
          DEPLOY_TOKEN="$value"
        fi
        ;;
    esac
  done < "$file_path"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file)
      ENV_FILE="${2:?missing env file path}"
      shift 2
      ;;
    --deploy-url)
      DEPLOY_URL="${2:?missing deploy url}"
      shift 2
      ;;
    --token)
      DEPLOY_TOKEN="${2:?missing deploy token}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

load_env_file "$ENV_FILE"

log_step 1 "환경 설정 확인"
log_info "env file: $ENV_FILE"

if [[ -z "$DEPLOY_URL" ]]; then
  fail "MATCH_DEPLOY_URL is required. Set it in $ENV_FILE or pass --deploy-url."
fi
log_info "deploy URL: $DEPLOY_URL"

if [[ -z "$DEPLOY_TOKEN" ]]; then
  fail "MATCH_DEPLOY_TOKEN is required. Set it in $ENV_FILE or pass --token."
fi

if [[ "$DEPLOY_TOKEN" == "replace_with_output_of_openssl_rand_hex_32" ]]; then
  fail "MATCH_DEPLOY_TOKEN still has the placeholder value. Generate a real token with: openssl rand -hex 32"
fi
log_info "deploy token: configured (${#DEPLOY_TOKEN} chars)"

if ! command -v flutter >/dev/null 2>&1; then
  fail "flutter command not found."
fi
log_info "flutter: $(command -v flutter)"

if ! command -v dart >/dev/null 2>&1; then
  fail "dart command not found."
fi
log_info "dart: $(command -v dart)"

if ! command -v zip >/dev/null 2>&1; then
  fail "zip command not found."
fi
log_info "zip: $(command -v zip)"

if ! command -v curl >/dev/null 2>&1; then
  fail "curl command not found."
fi
log_info "curl: $(command -v curl)"

log_step 2 "기존 웹 빌드 산출물 정리"
rm -rf "$ROOT_DIR/build/web" "$PACKAGE_DIR"
rm -f "$ZIP_PATH"
log_info "removed build/web, match/, and match.zip"

log_step 3 "Flutter 웹 릴리즈 빌드"
log_info "base href: $BASE_HREF"
SUPABASE_DEFINE_ARGS=()
if [[ -f "$ROOT_DIR/config/supabase.json" ]]; then
  SUPABASE_DEFINE_ARGS=(--dart-define-from-file=config/supabase.json)
  log_info "supabase: config/supabase.json"
else
  log_info "supabase: config/supabase.json 없음. 랭킹, 광고 제한 확인, 이벤트 기록이 꺼진 빌드다"
fi
flutter build web --release --base-href "$BASE_HREF" --wasm --no-web-resources-cdn \
  ${SUPABASE_DEFINE_ARGS[@]+"${SUPABASE_DEFINE_ARGS[@]}"}

if [[ ! -f "$ROOT_DIR/build/web/index.html" ]]; then
  fail "Flutter build completed but build/web/index.html was not created."
fi

log_step 4 "Flutter 웹 산출물 패치"
dart run tools/patch_flutter_web_deprecations.dart

log_step 5 "최신 build/web를 match 폴더로 패키징"
log_info "package directory: $PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"
cp -R build/web/. "$PACKAGE_DIR/"
log_info "copied current build/web into match/"

cat > "$PACKAGE_DIR/.htaccess" <<'EOF'
DirectoryIndex index.html
ErrorDocument 404 /match/index.html

<IfModule mod_mime.c>
  AddType application/wasm .wasm
</IfModule>

<IfModule mod_headers.c>
  Header always set Cross-Origin-Opener-Policy "same-origin"
  Header always set Cross-Origin-Embedder-Policy "require-corp"
  Header always set Cross-Origin-Resource-Policy "same-origin"

  # Flutter 웹 코드 파일은 이름에 해시가 없다. 재방문 브라우저가 이전 배포의 main.dart.mjs나
  # main.dart.wasm을 캐시에서 꺼내 새 파일과 섞으면 Wasm이 멈춘다(2026-09-24 실기기 확인).
  # 매번 서버에 확인하게 하고, 바뀌지 않았으면 304로 끝난다.
  <FilesMatch "\.(html|js|mjs|wasm|json)$">
    Header set Cache-Control "no-cache"
  </FilesMatch>
</IfModule>

<IfModule mod_rewrite.c>
  RewriteEngine On
  RewriteBase /match/

  RewriteCond %{REQUEST_FILENAME} -f [OR]
  RewriteCond %{REQUEST_FILENAME} -d
  RewriteRule ^ - [L]

  RewriteRule ^ index.html [L]
</IfModule>
EOF

log_info "added Wasm headers and SPA fallback rewrite: .htaccess"

log_step 6 "zip 압축 및 NAS 업로드"
log_info "zip path: $ZIP_PATH"
zip -qry "$ZIP_PATH" "$(basename "$PACKAGE_DIR")"
zip_size="$(du -h "$ZIP_PATH" | awk '{print $1}')"
log_info "zip size: $zip_size"

response_file="$(mktemp)"
cleanup_response_file() {
  rm -f "$response_file"
}
trap cleanup_response_file EXIT

log_info "uploading: $ZIP_PATH"
http_code="$(
  curl -sS \
    -o "$response_file" \
    -w "%{http_code}" \
    -X POST "$DEPLOY_URL" \
    -H "X-Deploy-Token: $DEPLOY_TOKEN" \
    -F "file=@$ZIP_PATH;type=application/zip"
)"

log_info "HTTP $http_code"
cat "$response_file"
echo
cleanup_response_file
trap - EXIT

if [[ "$http_code" != "200" ]]; then
  fail "Deploy failed. Review the HTTP status and JSON response above."
fi

log_step 7 "배포 결과 확인"
log_info "server response: OK"
log_info "public URL: https://cheng80.myqnapcloud.com/match/"
log_info "local package: $PACKAGE_DIR"
log_info "local zip: $ZIP_PATH"

echo
echo "Deploy complete."

#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ENV_FILE="$ROOT_DIR/.env"
DEPLOY_URL="${MATCH_DEPLOY_URL:-}"
DEPLOY_TOKEN="${MATCH_DEPLOY_TOKEN:-}"
BASE_HREF="/match/"
OUTPUT_DIR="$ROOT_DIR/tmp/nas-web-$(date +%Y%m%d-%H%M%S)"
PACKAGE_DIR=""
ZIP_PATH=""
BUILD_DIR=""
SENTRY_ENV_FILE="$ROOT_DIR/.env.sentry"
USE_SENTRY=1
USE_GA4=1
SENTRY_DEFINES=""
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
  --output-dir <path>   Fresh output folder. Default: tmp/nas-web-<timestamp>
  --sentry-env-file <path>  Sentry env file. Default: .env.sentry
  --no-sentry            Build without Sentry even if .env.sentry is configured.
  --no-ga4               Build without GA4 even if config/ga4.json exists.
  -h, --help             Show this help.

Required env:
  MATCH_DEPLOY_URL=https://cheng80.myqnapcloud.com/deploy_match.php
  MATCH_DEPLOY_TOKEN=<same token as /share/Web/.match_deploy.env>

Flow:
  1. Create a fresh task output folder under tmp/.
  2. flutter build web --release --base-href "/match/" --wasm --no-web-resources-cdn
     (config/pocketbase.json 필수. 없으면 배포를 중단한다)
  3. Patch Flutter web deprecated Intl checks.
  4. Copy build/web/* into local match/ and add Wasm isolation headers.
  5. Create match.zip and upload it to NAS deploy PHP.

Sentry (PLAN-012, tools/sentry_web_build.py):
  .env.sentry가 없거나 값이 모두 비어 있으면 종전 빌드와 같다. 일부만 있거나 형식이 틀리면 중단한다.
  설정되어 있으면 --source-maps로 빌드하고 공개 define(SENTRY_DSN, SENTRY_RELEASE 등)만 앱에 넣는다.
  패치 뒤 JS map을 sentry CLI(기존 로그인)로 올리고, 업로드 실패 시 패키징과 배포를 하지 않는다.
  *.map은 match 폴더와 ZIP에서 모두 제외한다(원본은 output/web에 남는다).
  SENTRY_TEST_PROJECT(.env.sentry 또는 환경변수, 선택)가 있으면 같은 debug ID JS를 QA 프로젝트에도 올린다.
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
    --output-dir)
      OUTPUT_DIR="${2:?missing output path}"
      shift 2
      ;;
    --token)
      DEPLOY_TOKEN="${2:?missing deploy token}"
      shift 2
      ;;
    --sentry-env-file)
      SENTRY_ENV_FILE="${2:?missing sentry env file path}"
      shift 2
      ;;
    --no-sentry)
      USE_SENTRY=0
      shift
      ;;
    --no-ga4)
      USE_GA4=0
      shift
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

log_step 2 "새 웹 빌드 경로 준비"
[[ "$OUTPUT_DIR" == /* ]] || OUTPUT_DIR="$ROOT_DIR/$OUTPUT_DIR"
[[ ! -e "$OUTPUT_DIR" ]] || fail "Output folder already exists: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
BUILD_DIR="$OUTPUT_DIR/web"
PACKAGE_DIR="$OUTPUT_DIR/match"
ZIP_PATH="$OUTPUT_DIR/match.zip"
log_info "output: $OUTPUT_DIR"

log_step 3 "Flutter 웹 릴리즈 빌드"
log_info "base href: $BASE_HREF"
BACKEND_DEFINE_ARGS=()
backend_define="$(bash tools/backend_define.sh --required)"
BACKEND_DEFINE_ARGS=("$backend_define")
log_info "backend: $backend_define"
GA4_BUILD_ARGS=()
if [[ "$USE_GA4" == "1" ]]; then
  # config/ga4.json이 없으면 비활성, 있으면 검증하고 공개 define으로 추가한다(형식 오류는 여기서 중단).
  ga4_define="$(bash tools/ga4_define.sh)"
  if [[ -n "$ga4_define" ]]; then
    GA4_BUILD_ARGS=("$ga4_define")
    log_info "ga4: enabled ($ga4_define)"
  else
    log_info "ga4: disabled (config/ga4.json 없음)"
  fi
fi
SENTRY_BUILD_ARGS=()
if [[ "$USE_SENTRY" == "1" ]]; then
  command -v python3 >/dev/null 2>&1 || fail "python3 command not found."
  sentry_defines_file="$OUTPUT_DIR/sentry-defines.json"
  python3 tools/sentry_web_build.py define --env-file "$SENTRY_ENV_FILE" --out "$sentry_defines_file"
  if [[ -f "$sentry_defines_file" ]]; then
    command -v sentry >/dev/null 2>&1 || fail "sentry command not found."
    SENTRY_DEFINES="$sentry_defines_file"
    SENTRY_BUILD_ARGS=(--source-maps "--dart-define-from-file=$sentry_defines_file")
  fi
fi
flutter build web --release --base-href "$BASE_HREF" --wasm --no-web-resources-cdn \
  --output "$BUILD_DIR" --dart-define=TELEMETRY_ENV=production "${BACKEND_DEFINE_ARGS[@]}" \
  ${GA4_BUILD_ARGS[@]+"${GA4_BUILD_ARGS[@]}"} \
  ${SENTRY_BUILD_ARGS[@]+"${SENTRY_BUILD_ARGS[@]}"}

if [[ ! -f "$BUILD_DIR/index.html" ]]; then
  fail "Flutter build completed but output index.html was not created."
fi

log_step 4 "Flutter 웹 산출물 패치"
dart run tools/patch_flutter_web_deprecations.dart "$BUILD_DIR"
if [[ -n "$SENTRY_DEFINES" ]]; then
  # 패치가 끝난 최종 JS 기준으로 올려야 debug ID가 배포 파일과 맞는다. 실패하면 여기서 중단한다.
  python3 tools/sentry_web_build.py upload --env-file "$SENTRY_ENV_FILE" \
    --web-dir "$BUILD_DIR" --define-file "$SENTRY_DEFINES"
fi

log_step 5 "최신 build/web를 match 폴더로 패키징"
log_info "package directory: $PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"
cp -R "$BUILD_DIR/." "$PACKAGE_DIR/"
log_info "copied current build/web into match/"
if [[ -n "$SENTRY_DEFINES" ]]; then
  python3 tools/sentry_web_build.py strip-maps --dir "$PACKAGE_DIR"
fi

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
(cd "$OUTPUT_DIR" && zip -qry "$ZIP_PATH" "$(basename "$PACKAGE_DIR")")
python3 tools/sentry_web_build.py check-zip --zip "$ZIP_PATH" ${SENTRY_DEFINES:+--define-file "$SENTRY_DEFINES"}
zip_size="$(du -h "$ZIP_PATH" | awk '{print $1}')"
log_info "zip size: $zip_size"

response_file="$OUTPUT_DIR/deploy-response.json"
cleanup_response_file() {
  : # 결과 파일은 작업 폴더에 보존한다.
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

python3 - "$response_file" <<'PYVERIFY'
import json, sys
with open(sys.argv[1]) as f:
    result = json.load(f)
if result.get('result') != 'OK':
    raise SystemExit('NAS deployment did not return result=OK')
PYVERIFY

log_step 7 "배포 결과 확인"
log_info "server response: OK"
log_info "public URL: https://cheng80.myqnapcloud.com/match/"
log_info "local package: $PACKAGE_DIR"
log_info "local zip: $ZIP_PATH"

echo
echo "Deploy complete."

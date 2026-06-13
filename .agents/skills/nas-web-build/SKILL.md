---
name: nas-web-build
description: Run the Jewel Match NAS web build/deploy workflow and verify the deployed site matches the local build. Use when the user says "나스웹빌드 해줘", "나스 웹 빌드", "NAS 웹 배포", "jewelmatch NAS deploy", or asks to run tools/deploy_match_web.sh and then check remote hashes.
---

# NAS Web Build

## Workflow

Use this skill only from the repository root for `/Users/cheng80/Desktop/jewelmatch`.

1. Run the deploy script:

```bash
tools/deploy_match_web.sh
```

2. If the script fails, stop. Report the failed step and the relevant error output. Do not print `.env`, `.match_deploy.env`, deploy tokens, passwords, or secret values.

3. If the script succeeds, verify that the deployed site matches the current local `build/web` output by comparing SHA-256 hashes for these files:

```text
index.html
flutter_bootstrap.js
flutter.js
main.dart.js
manifest.json
version.json
assets/AssetManifest.bin.json
assets/FontManifest.json
```

Use this command pattern:

```bash
set -euo pipefail
base='https://cheng80.myqnapcloud.com/match'
files=(index.html flutter_bootstrap.js flutter.js main.dart.js manifest.json version.json assets/AssetManifest.bin.json assets/FontManifest.json)
for f in "${files[@]}"; do
  local_path="build/web/$f"
  remote_path="/tmp/match_remote_${f//\//_}"
  if [[ ! -f "$local_path" ]]; then
    printf 'MISS local %s\n' "$f"
    continue
  fi
  curl -L -sS -o "$remote_path" "$base/$f"
  local_sha="$(shasum -a 256 "$local_path" | awk '{print $1}')"
  remote_sha="$(shasum -a 256 "$remote_path" | awk '{print $1}')"
  if [[ "$local_sha" == "$remote_sha" ]]; then
    printf 'OK   %s %s\n' "$f" "$local_sha"
  else
    printf 'DIFF %s local=%s remote=%s\n' "$f" "$local_sha" "$remote_sha"
  fi
done
```

4. Verify the public entrypoint responds:

```bash
curl -L -sS -o /tmp/match_index_check.html \
  -w 'status=%{http_code} size=%{size_download} final_url=%{url_effective}\n' \
  https://cheng80.myqnapcloud.com/match/
```

5. Verify the uploaded zip was removed from NAS:

```bash
curl -L -sS -o /tmp/match_zip_check \
  -w 'zip_status=%{http_code} zip_size=%{size_download}\n' \
  https://cheng80.myqnapcloud.com/match.zip
```

Expected `zip_status` is `404`.

## Reporting

Report in Korean with:

- Deploy script result: success or failure.
- Remote entrypoint status.
- Hash comparison summary: all OK or list of DIFF/MISS files.
- Zip cleanup result.
- Any warnings, such as Flutter wasm dry-run warnings, only if relevant.

Keep secrets out of the response. Mention only that tokens were configured if needed.

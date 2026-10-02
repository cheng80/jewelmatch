# Stone Match 검증 전용 관리자

운영 테스트는 `verify-admin@stonematch.local`만 사용한다. 기존 소유자 관리자의 암호를 재설정하거나 로그인 검증에 사용하지 않는다. 운영 유지보수/최초 등록용 `.env.pocketbase`와 검증용 자격 파일을 분리한다. 소유자 자격 파일로 대체하는 fallback은 없다.

## 자격 파일과 재사용

- 기본 파일: `pocketbase/.local/remote-admin.env`, Git 제외, 일반 파일0600, 부모 폴더0700.
- 키: `REMOTE_ADMIN_EMAIL`, `REMOTE_ADMIN_PASSWORD`. 암호는 작업 PC의 `randomBytes(24)`를48자리 hex로 저장한다. 실제 값은 문서, 로그, 화면, 커밋과 명령 인자에 넣지 않는다.
- 기본 `check` 실행은 위 파일만 읽는다. 새 체크아웃/워크트리에서 기존 파일을 사용하려면 `--credentials <절대 경로>`로 파일 경로를 지정한다. 자격 파일을 Git에 추가하거나 중복 복사하지 않는다.
- 이 계정은 제한된 역할의 계정이 아니라 검증 용도를 분리한 실제 PocketBase superuser다. 보유한 자격정보에 관리자 권한이 있으므로 소유자 파일과 같은 수준으로 보호한다.

```sh
npm install
npm run test:verify-admin
npm run pb:verify-admin:check
```

## 최초 등록 또는 검증 계정 갱신

```sh
npm run pb:verify-admin:provision
```

등록 도구는 `stonematch-pb.fastmake.net`, Mac mini의 `/Users/cheng80/Servers/stonematch`, `127.0.0.1:8090`만 대상으로 한다. SSH 키 기본값은 `~/.ssh/stonematch_macmini_ed25519`, 호스트는 `cheng80@100.92.43.82`다. `--bootstrap-env`, `--ssh-key`, `--ssh-host`, `--credentials`, `--out`으로 파일/연결 경로를 지정할 수 있다. 비밀번호를 받는 CLI 옵션은 제공하지 않는다.

1. 자격 파일이 없으면 작업 PC에서 생성한다. 존재하면0600과 이메일/암호 형식을 검사하고 같은 파일을 재사용한다. 파일 권한 오류를 무시하거나 소유자 자격 파일로 대체하지 않는다.
2. 등록 전에 실행 중 `pb_data/data.db`와 `auxiliary.db`를 각각 `sqlite3 .backup`으로 `/Users/cheng80/Servers/backups/stonematch-verify-admin-<시각>-<고유값>/`에 복사한다. 백업 디렉터리0700, 파일0600, `integrity_check=ok`와 SHA256을 확인한다. 완료된 백업 사본의 검증은 `mode=ro&immutable=1`로 열어 WAL/SHM 임시 파일을 만들지 않는다. 실행 중 원본 DB에는 immutable을 사용하지 않는다. 두 DB는 각각 일관된 온라인 백업이며, 파일 저장소 전체 스냅샷이나 두 DB를 아우르는 단일 트랜잭션 백업을 의미하지 않는다. 이 작업은 관리자 레코드만 변경한다.
3. 최초 운영 구성에는 기존 소유자 한 명만 있었다. 이 계정은 새 검증 계정 등록 권한으로만 인증한다. 등록 이후의 테스트는 새 계정으로만 실행한다. 소유자 암호/레코드 수정은 하지 않는다.
4. `bootstrap` 인증과 새 계정 정보를 SSH stdin JSON으로 전달한다. 서버 SDK가 `_superusers`의 정확한 이메일을 찾아 create 또는 기존 검증 계정에만 update한다. SDK 오류 원문에는 제출한 암호가 포함될 수 있어 출력하지 않는다.
5. 실행 파일과 SDK는 Stone Match의 `.local/verification-admin/`에 둔다. 최초 실행에 이미 설치된 Node 바이너리를 읽어 Stone Match 경로로 복사했으며 pixeltown의 파일/프로세스/8091/2567은 변경하지 않았다. 이후에는 Stone Match의 Node를 재사용한다. SDK는 `package.json`의 검증한0.26.9 버전을 사용한다.
6. 등록 전후 소유자와 다른 기존 superuser 레코드의 해시가 동일한지 확인한다. 출력에는 작업 상태, 백업 경로와 이메일 목록만 포함한다. 보고서는 `tmp/verification-admin/`에 보존한다.

기존 검증 계정 update는 그 계정의 인증 세션을 무효화할 수 있다. 다른 관리자 계정을 갱신하지 않는다. 일반 검증에는 `check`만 실행하고, `provision`은 등록/갱신할 때만 실행한다.

## 관리자 권한 검증 계약

Stone Match에는 Colyseus Monitor가 없다. PocketBase 자체 관리 화면 `/_/`는 공개 SPA이므로 화면 셸200만으로 관리자 인증 성공을 판단하지 않는다. 파일의 검증 계정 로그인, 관리자 전용 컬렉션 조회와 기존 대시보드 보호 API를 함께 검증한다.

| 경로/조건 | 기대 결과 |
|---|---|
| 검증 계정 `_superusers` 로그인 | 인증 성공, 해당 이메일/superuser 확인 |
| PocketBase `/_/` 화면 셸 | 200, 공개 셸임을 구분 |
| 검증 계정 `sm_daily_metrics` 조회 | 200 |
| 대시보드 `/api/observability?provider=sentry&env=production&days=7`, 검증 계정 | 200 |
| 같은 보호 API, 다른 Origin | 403 |
| 같은 보호 API, 미로그인/일반 게임 플레이어/잘못된 토큰 | 각각401 |
| PocketBase 로그인, 검증 계정의 틀린 암호 | 400, PocketBase 원래 계약 유지 |

일반 사용자 거절 검증에는 임시 `sm_players` 계정1개를 만들고 `finally`에서 정확히 그 계정만 삭제한다. 랭킹, 광고 지급, 이벤트 삽입, 집계 재계산과 기존 일반 사용자 변경은 하지 않는다. 정리 실패도 전체 검증 실패로 기록한다. 서비스용 superuser는 현재 없으므로 서비스 계정 관리 화면 로그인 거부는 적용 대상이 없다. 향후 저장 전용 계정을 도입하면 대시보드의 브라우저 로그인과 서버 인증에서 명시적으로 제외해야 한다. 공개 게임 Origin이나 PocketBase CORS를 Monitor 규칙처럼 변경하지 않는다.

## 폐기

운영 백업을 확보한 뒤 `_superusers`에서 정확한 `verify-admin@stonematch.local` 레코드만 삭제하고 성공을 확인한다. 다음으로 로컬 `pocketbase/.local/remote-admin.env`를 삭제한다. 기존 소유자 계정과 다른 서비스 계정은 삭제하지 않는다. 이번 적용에서는 검증 계정과 로컬 파일을 다음 검증을 위해 보존했다.

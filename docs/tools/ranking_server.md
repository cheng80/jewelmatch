# 랭킹 서버 운영

랭킹 초기화는 NAS에서 JSON을 백업한 뒤 한 모드씩 실행한다. 관리자 토큰은 `/share/Web/.match_deploy.env`의 `MATCH_DEPLOY_TOKEN`을 재사용하며 URL, 요청 body, 로그에 넣지 않는다.

## 사전 백업

NAS 파일 관리 도구에서 초기화할 파일을 웹 루트 밖의 접근 제한된 백업 폴더로 복사한다.

- 타임 랭킹: `/share/Web/matchranking/ranking_data.json`
- 레벨 랭킹: `/share/Web/matchranking/ranking_level_data.json`

예: 백업 폴더의 `ranking_level_data.backup-20260809.json`

## 건수 확인

로컬 `.env`의 토큰을 셸 환경에 불러온 뒤 dry-run을 실행한다. 출력이나 셸 기록에 토큰 값을 직접 적지 않는다.

```bash
set -a
source .env
set +a

curl -sS -X POST \
  'https://cheng80.myqnapcloud.com/matchranking/ranking.php?action=reset' \
  -H 'Content-Type: application/json' \
  -H "X-Ranking-Admin-Token: $MATCH_DEPLOY_TOKEN" \
  --data '{"mode":"level","dryRun":true}'
```

응답의 `count`가 백업한 JSON의 항목 수와 다르면 실행을 중단한다. 실제 요청의 `expectedCount`에는 이 값을 그대로 사용한다. 타임 랭킹은 body의 `mode`를 `time`으로 바꾼다.

## 실제 초기화

건수와 백업을 확인한 뒤 한 모드만 초기화한다.

```bash
curl -sS -X POST \
  'https://cheng80.myqnapcloud.com/matchranking/ranking.php?action=reset' \
  -H 'Content-Type: application/json' \
  -H "X-Ranking-Admin-Token: $MATCH_DEPLOY_TOKEN" \
  --data '{"mode":"level","expectedCount":0,"confirm":"RESET level"}'
```

예시의 `expectedCount` 0은 dry-run 응답의 실제 `count`로 바꾼다. 그 사이 건수가 달라지면 서버는 409 `ranking_count_changed`로 중단한다. 타임 랭킹은 `mode`를 `time`, 확인 문자열을 `RESET time`으로 함께 바꾼다. 성공 응답의 `removed`를 확인하고 `action=list&mode=level` 또는 `action=list&mode=time`이 빈 목록인지 확인한다. 다른 모드의 목록도 변경되지 않았는지 확인한다.

## 수동 복원

문제가 있으면 랭킹 요청을 중단하고 백업 파일을 원래 파일명으로 되돌린다. 파일 소유자와 쓰기 권한이 기존 JSON과 같은지 확인한 뒤 목록 API의 건수와 상위 기록을 재확인한다. 복원 API와 전체 모드 동시 초기화 기능은 제공하지 않는다.

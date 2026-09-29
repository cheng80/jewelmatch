# 이전 Supabase 서버 기록

2026-09-29부터 Stone Match의 실행 백엔드는 PocketBase다. 이 폴더의 SQL과 설정은 이전 구현과 원본 데이터 복구를 위한 이력이며 앱 실행, 테스트, 빌드와 신규 배포에 필요하지 않다.

현재 구현은 `pocketbase/pb_hooks/`, `pocketbase/pb_migrations/`, `lib/services/backend/pocketbase_gateway.dart`를 따른다. 새 설정 예시는 `config/pocketbase.example.json`이다.

기존 Supabase 프로젝트와 원본 데이터는 보존한다. 이 폴더의 과거 배포 절차를 현재 운영 절차로 사용하지 않는다.

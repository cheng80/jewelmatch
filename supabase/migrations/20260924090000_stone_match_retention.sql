-- Stone Match 보존 기간 정리 (2026-09-24)
-- game_events 90일, ad_refill_claims 35일을 넘긴 행을 pg_cron으로 매일 지운다.
-- 오래된 익명 사용자(auth.users) 정리는 이 마이그레이션에 넣지 않는다(관리자 API로 따로 처리).
-- 여러 번 실행해도 안전하다: 함수는 create or replace, 작업은 이름으로 먼저 해제한 뒤 다시 등록한다.

-- 1. 정리 함수 --------------------------------------------------------------

-- 90일 지난 이벤트 로그를 지운다. 삭제 행 수를 돌려준다.
create or replace function private.purge_game_events(p_retention interval default interval '90 days')
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_deleted bigint;
begin
  delete from public.game_events e
  where e.created_at < now() - p_retention;
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

-- 일일 제한 판정은 KST 오늘 날짜의 행만 보므로 35일 넘은 행은 필요 없다.
create or replace function private.purge_ad_refill_claims(p_retention_days integer default 35)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_deleted bigint;
begin
  delete from public.ad_refill_claims a
  where a.claim_date < (now() at time zone 'Asia/Seoul')::date - p_retention_days;
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke all on function private.purge_game_events(interval) from public, anon, authenticated;
revoke all on function private.purge_ad_refill_claims(integer) from public, anon, authenticated;

-- 2. 스케줄 -----------------------------------------------------------------
-- KST 04:00 = UTC 19:00(전날). KST 04:10 = UTC 19:10.
-- pg_cron을 쓸 수 없는 환경(로컬 등)에서는 알림만 남기고 넘어간다.

do $$
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
      create extension pg_cron with schema pg_catalog;
    else
      raise notice 'pg_cron 사용 불가: 정리 작업을 등록하지 않았다.';
      return;
    end if;
  end if;

  -- 같은 이름의 기존 작업을 해제해 다시 실행해도 중복되지 않게 한다.
  perform cron.unschedule(j.jobid)
  from cron.job j
  where j.jobname in ('stone_match_purge_game_events', 'stone_match_purge_ad_refill_claims');

  perform cron.schedule(
    'stone_match_purge_game_events',
    '0 19 * * *',
    'select private.purge_game_events()'
  );
  perform cron.schedule(
    'stone_match_purge_ad_refill_claims',
    '10 19 * * *',
    'select private.purge_ad_refill_claims()'
  );
end;
$$;

-- Stone Match 비활성 익명 사용자 정리 (2026-09-24)
-- 90일 넘게 활동(가입, 로그인, 세션 갱신)이 없는 익명 사용자를 매일 지운다.
-- Supabase 공식 문서(Auth, Anonymous Sign-Ins)가 안내하는 SQL과 pg_cron 방식을 따르되,
-- 생성일 대신 마지막 활동 시각을 기준으로 해 계속 플레이하는 사용자는 지우지 않는다.
-- 연결된 행: ranking_entries는 user_id가 null로 바뀌어 공개 기록이 남고,
-- ad_refill_claims와 game_events는 함께 지워진다(on delete cascade).
-- 지워진 사용자의 클라이언트는 토큰 갱신이 거절되면 새 익명 사용자로 가입한다(SupabaseGateway).
-- 여러 번 실행해도 안전하다.

create or replace function private.purge_inactive_anonymous_users(
  p_inactive_days integer default 90,
  p_dry_run boolean default false
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  -- 실수로 짧은 값을 넣어도 30일보다 최근 사용자는 지우지 않는다.
  v_cutoff timestamptz := now() - make_interval(days => greatest(coalesce(p_inactive_days, 90), 30));
  v_count bigint;
begin
  if p_dry_run then
    select count(*) into v_count
    from auth.users u
    where u.is_anonymous is true
      and u.created_at < v_cutoff
      and coalesce(u.last_sign_in_at, u.created_at) < v_cutoff
      and not exists (
        select 1 from auth.sessions s
        where s.user_id = u.id
          and (s.updated_at >= v_cutoff
            or s.created_at >= v_cutoff
            or s.refreshed_at >= (v_cutoff at time zone 'UTC'))
      );
    return v_count;
  end if;

  delete from auth.users u
  where u.is_anonymous is true
    and u.created_at < v_cutoff
    and coalesce(u.last_sign_in_at, u.created_at) < v_cutoff
    and not exists (
      select 1 from auth.sessions s
      where s.user_id = u.id
        and (s.updated_at >= v_cutoff
          or s.created_at >= v_cutoff
          or s.refreshed_at >= (v_cutoff at time zone 'UTC'))
    );
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function private.purge_inactive_anonymous_users(integer, boolean) from public, anon, authenticated;

-- KST 04:20 = UTC 19:20(전날). 보존 정리 작업(04:00, 04:10) 뒤에 돈다.
do $$
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    raise notice 'pg_cron 사용 불가: 익명 사용자 정리 작업을 등록하지 않았다.';
    return;
  end if;

  perform cron.unschedule(j.jobid)
  from cron.job j
  where j.jobname = 'stone_match_purge_inactive_anonymous_users';

  perform cron.schedule(
    'stone_match_purge_inactive_anonymous_users',
    '20 19 * * *',
    'select private.purge_inactive_anonymous_users()'
  );
end;
$$;

-- Stone Match 주간 랭킹 조회 계획 보강 (2026-09-24, 검수 P2-1)
-- PG17은 SQL 함수 본문을 인자 없이(generic) 계획하므로 "p_mode <> 'time' or week_start = ..." 조건을 접지 못하고
-- 주간 인덱스 대신 전체 기간 점수 인덱스를 훑는다. 기록을 지우지 않는 설계라 비용이 계속 커진다.
-- time과 그 밖의 모드를 별도 문장으로 나눠 각 문장이 알맞은 인덱스를 쓰게 한다.
-- 동작, 시그니처, 반환 형식, 권한은 20260924120000과 같다. 이름 정규식은 init과 같은 \uXXXX 이스케이프로 적는다.
-- 여러 번 실행해도 안전하다.

create or replace function public.get_ranking(p_mode text, p_limit integer default null)
returns table (name text, score integer, ts bigint)
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_limit integer;
begin
  v_limit := least(greatest(coalesce(
    p_limit,
    (select (c.value ->> 'list_limit')::integer from public.app_config c where c.key = 'ranking'),
    30
  ), 1), 100);

  if p_mode = 'time' then
    -- 이번 주(KST 월요일 00:00 시작) 기록만. ranking_entries_mode_week_score_idx를 쓴다.
    return query
      select r.name, r.score, extract(epoch from r.created_at)::bigint
      from public.ranking_entries r
      where r.mode = 'time'
        and r.week_start = (date_trunc('week', now() at time zone 'Asia/Seoul'))::date
      order by r.score desc, r.created_at asc, r.id asc
      limit v_limit;
  else
    return query
      select r.name, r.score, extract(epoch from r.created_at)::bigint
      from public.ranking_entries r
      where r.mode = p_mode
      order by r.score desc, r.created_at asc, r.id asc
      limit v_limit;
  end if;
end;
$$;

create or replace function public.submit_ranking(p_mode text, p_name text, p_score integer)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_id bigint;
  v_created_at timestamptz;
  v_week_start date;
  v_rank bigint;
  v_limit integer;
  v_name text;
begin
  -- 금지 문자는 거부하지 않고 지운 뒤 정리한다. 입력이 비어 있으면 체크 제약이 거부한다.
  -- 입력은 있었는데 정리 뒤 보이는 문자가 남지 않으면 클라이언트 기본값과 같은 GUEST로 저장한다.
  v_name := btrim(left(btrim(regexp_replace(coalesce(p_name, ''), '[\u0001-\u001f\u007f-\u009f\u00ad\u061c\u115f\u1160\u200b\u200e\u200f\u2028-\u202e\u2060-\u2064\u2066-\u2069\u3164\ufeff\uffa0]', '', 'g')), 20));
  if btrim(coalesce(p_name, '')) <> '' and v_name !~ '[^[:space:]\u00a0\u1680\u2000-\u200d\u202f\u205f\u3000\u034f\u180e\u2800\ufe00-\ufe0f\U000e0000-\U000e007f]' then
    v_name := 'GUEST';
  end if;

  insert into public.ranking_entries (mode, name, score)
  values (p_mode, v_name, p_score)
  returning id, created_at, week_start into v_id, v_created_at, v_week_start;

  -- 타임 모드는 방금 넣은 기록과 같은 주 안에서만 순위를 센다.
  if p_mode = 'time' then
    select count(*) + 1 into v_rank
    from public.ranking_entries r
    where r.mode = 'time'
      and r.week_start = v_week_start
      and (
        r.score > p_score
        or (r.score = p_score and (r.created_at, r.id) < (v_created_at, v_id))
      );
  else
    select count(*) + 1 into v_rank
    from public.ranking_entries r
    where r.mode = p_mode
      and (
        r.score > p_score
        or (r.score = p_score and (r.created_at, r.id) < (v_created_at, v_id))
      );
  end if;

  select (c.value ->> 'list_limit')::integer into v_limit
  from public.app_config c
  where c.key = 'ranking';

  v_limit := least(greatest(coalesce(v_limit, 30), 1), 100);

  return jsonb_build_object(
    'mode', p_mode,
    'ranked', v_rank <= v_limit,
    'rank', v_rank,
    'score', p_score
  ) || case
    when p_mode = 'time' then jsonb_build_object('week_start', to_char(v_week_start, 'YYYY-MM-DD'))
    else '{}'::jsonb
  end;
end;
$$;

revoke all on function public.get_ranking(text, integer) from public;
grant execute on function public.get_ranking(text, integer) to anon, authenticated;
revoke all on function public.submit_ranking(text, text, integer) from public, anon;
grant execute on function public.submit_ranking(text, text, integer) to authenticated;

-- Stone Match 타임 모드 주간 랭킹 (2026-09-24)
-- 타임 모드 랭킹은 이번 주(KST 월요일 00:00 시작) 기록만 보여 주고 순위를 매긴다. 레벨 모드는 전체 기간 그대로다.
-- 기록은 지우지 않는다. 주가 바뀌면 조회 범위만 바뀐다.
-- RPC 시그니처, 권한, RLS, security invoker, search_path, 빈도 제한 트리거, 이름 규칙은 그대로 둔다.
-- 여러 번 실행해도 안전하다.

-- 1. 주 시작 날짜 열 ------------------------------------------------------------
-- created_at의 KST 날짜가 속한 주의 월요일. 생성 열이라 기존 행도 채워지고 클라이언트가 바꿀 수 없다.
-- Asia/Seoul은 현재 일광 절약 시간이 없어 UTC+9 고정인 클라이언트 날짜 키와 같다.

alter table public.ranking_entries
  add column if not exists week_start date
  generated always as ((date_trunc('week', created_at at time zone 'Asia/Seoul'))::date) stored;

comment on column public.ranking_entries.week_start is 'created_at 기준 KST 주의 월요일. 타임 모드 주간 랭킹 범위.';

-- security invoker RPC가 이 열로 거르므로 조회 권한이 필요하다. 개인 정보가 아니다.
grant select (week_start) on public.ranking_entries to anon, authenticated;

create index if not exists ranking_entries_mode_week_score_idx
  on public.ranking_entries (mode, week_start, score desc, created_at, id);

-- 2. RPC --------------------------------------------------------------------

create or replace function public.get_ranking(p_mode text, p_limit integer default null)
returns table (name text, score integer, ts bigint)
language sql
stable
security invoker
set search_path = ''
as $$
  select r.name, r.score, extract(epoch from r.created_at)::bigint
  from public.ranking_entries r
  where r.mode = p_mode
    and (
      p_mode <> 'time'
      or r.week_start = (date_trunc('week', now() at time zone 'Asia/Seoul'))::date
    )
  order by r.score desc, r.created_at asc, r.id asc
  limit least(greatest(coalesce(
    p_limit,
    (select (c.value ->> 'list_limit')::integer from public.app_config c where c.key = 'ranking'),
    30
  ), 1), 100);
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
  v_name := btrim(left(btrim(regexp_replace(coalesce(p_name, ''), '[\u0001-\u001f\u007f-\u009f­؜ᅟᅠ​‎‏ -‮⁠-⁤⁦-⁩ㅤ﻿ﾠ]', '', 'g')), 20));
  if btrim(coalesce(p_name, '')) <> '' and v_name !~ '[^[:space:]   -‍  　͏᠎⠀︀-️\U000e0000-\U000e007f]' then
    v_name := 'GUEST';
  end if;

  insert into public.ranking_entries (mode, name, score)
  values (p_mode, v_name, p_score)
  returning id, created_at, week_start into v_id, v_created_at, v_week_start;

  -- 타임 모드는 방금 넣은 기록과 같은 주 안에서만 순위를 센다.
  select count(*) + 1 into v_rank
  from public.ranking_entries r
  where r.mode = p_mode
    and (p_mode <> 'time' or r.week_start = v_week_start)
    and (
      r.score > p_score
      or (r.score = p_score and (r.created_at, r.id) < (v_created_at, v_id))
    );

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

-- create or replace는 기존 권한을 유지하지만 명시해 둔다.
revoke all on function public.get_ranking(text, integer) from public;
grant execute on function public.get_ranking(text, integer) to anon, authenticated;
revoke all on function public.submit_ranking(text, text, integer) from public, anon;
grant execute on function public.submit_ranking(text, text, integer) to authenticated;

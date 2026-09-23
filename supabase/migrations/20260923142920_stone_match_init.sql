-- Stone Match 초기 스키마 (2026-09-23)
-- 원격 설정, 랭킹, 광고 보충 일일 제한, 게임 이벤트 로그.
--
-- 접근 모델
-- - 클라이언트는 publishable key와 익명 로그인 JWT(authenticated 역할)로 Data API를 쓴다.
-- - public 스키마의 모든 테이블은 RLS를 켜고, anon/authenticated 권한은 필요한 열만 명시적으로 준다.
-- - user_id는 어느 테이블에서도 anon/authenticated에게 공개 조회 권한을 주지 않는다(본인 행 제외).
-- - 서버 검증은 치트 방지가 아니라 명백한 이상값과 과도한 요청을 막는 수준이다.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- 1. 원격 설정 ------------------------------------------------------------

create table public.app_config (
  key text primary key check (key ~ '^[a-z][a-z0-9_]{0,39}$'),
  value jsonb not null check (jsonb_typeof(value) = 'object'),
  description text not null default '',
  updated_at timestamptz not null default now()
);

comment on table public.app_config is '클라이언트가 읽는 원격 설정. 쓰기는 대시보드(서비스 권한)만.';

alter table public.app_config enable row level security;
revoke all on public.app_config from anon, authenticated;
grant select (key, value) on public.app_config to anon, authenticated;

create policy "app_config readable by clients"
  on public.app_config for select
  to anon, authenticated
  using (true);

insert into public.app_config (key, value, description) values
  ('ranking', '{"list_limit": 30}', '게임 내 랭킹 목록 표시 개수. 1~100'),
  ('ads', '{"daily_refill_limit": 3}', '아이템 보충 광고의 하루 최대 횟수. 날짜는 KST 기준');

-- 2. 랭킹 ----------------------------------------------------------------

create table public.ranking_entries (
  id bigint generated always as identity primary key,
  -- 사용자 삭제 후에도 공개 랭킹 기록은 남긴다. 새 행은 항상 auth.uid() 값이라 null은 삭제된 사용자의 기존 행뿐이다.
  user_id uuid default auth.uid() references auth.users (id) on delete set null,
  mode text not null check (mode in ('time', 'level')),
  -- 제어 문자, 보이지 않는 서식 문자, 방향 문자, 한글 채움 문자는 금지한다. ZWNJ(200C)와 ZWJ(200D)는 이모지와 문자 결합에 쓰이므로 허용한다.
  -- 보이는 문자가 하나도 없는 이름도 금지한다. 공백류(U+00A0, U+1680, U+2000~200A, U+202F, U+205F, U+3000)와
  -- 단독으로는 보이지 않는 결합용 문자(ZWNJ, ZWJ, U+034F, U+180E, U+2800, 변형 선택자, 태그 문자)는 보이는 문자로 치지 않는다.
  -- 로케일과 관계없이 동작하도록 직접 적는다.
  -- submit_ranking은 금지 문자를 지운 뒤 trim, 20자 절단을 하므로 그 결과는 이 제약을 통과한다.
  name text not null check (
    char_length(name) between 1 and 20
    and name = btrim(name)
    and name !~ '[\u0001-\u001f\u007f-\u009f\u00ad\u061c\u115f\u1160\u200b\u200e\u200f\u2028-\u202e\u2060-\u2064\u2066-\u2069\u3164\ufeff\uffa0]'
    and name ~ '[^[:space:]\u00a0\u1680\u2000-\u200d\u202f\u205f\u3000\u034f\u180e\u2800\ufe00-\ufe0f\U000e0000-\U000e007f]'
  ),
  score integer not null check (score > 0),
  created_at timestamptz not null default now(),
  constraint ranking_entries_score_cap check (
    (mode = 'level' and score <= 10000)
    or (mode = 'time' and score <= 1000000000)
  )
);

comment on table public.ranking_entries is '타임 점수와 레벨 완료 수 기록. 동일 이름 다중 기록 허용(BR-090).';

create index ranking_entries_mode_score_idx
  on public.ranking_entries (mode, score desc, created_at, id);
create index ranking_entries_user_recent_idx
  on public.ranking_entries (user_id, created_at desc);

alter table public.ranking_entries enable row level security;
revoke all on public.ranking_entries from anon, authenticated;
grant select (id, mode, name, score, created_at) on public.ranking_entries to anon, authenticated;
grant insert (mode, name, score) on public.ranking_entries to authenticated;

create policy "ranking readable by clients"
  on public.ranking_entries for select
  to anon, authenticated
  using (true);

create policy "ranking insert own rows"
  on public.ranking_entries for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

-- 사용자당 1분에 10건 초과 제출을 막는다. user_id 조회가 필요해 비공개 스키마의 정의자 권한 트리거로 둔다.
create or replace function private.ranking_entries_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- 같은 사용자의 동시 삽입이 한도를 넘지 않게 직렬화한다.
  perform pg_advisory_xact_lock(hashtextextended('ranking:' || new.user_id::text, 0));
  if (
    select count(*)
    from public.ranking_entries r
    where r.user_id = new.user_id
      and r.created_at > now() - interval '1 minute'
  ) >= 10 then
    raise exception 'ranking_rate_limited' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

revoke all on function private.ranking_entries_rate_limit() from public, anon, authenticated;

create trigger ranking_entries_rate_limit
  before insert on public.ranking_entries
  for each row execute function private.ranking_entries_rate_limit();

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
  returning id, created_at into v_id, v_created_at;

  select count(*) + 1 into v_rank
  from public.ranking_entries r
  where r.mode = p_mode
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
  );
end;
$$;

revoke all on function public.get_ranking(text, integer) from public;
grant execute on function public.get_ranking(text, integer) to anon, authenticated;
revoke all on function public.submit_ranking(text, text, integer) from public, anon;
grant execute on function public.submit_ranking(text, text, integer) to authenticated;

-- 3. 광고 보충 일일 제한 ------------------------------------------------------

create table public.ad_refill_claims (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  claim_date date not null default ((now() at time zone 'Asia/Seoul')::date),
  item text not null check (item ~ '^[a-zA-Z][a-zA-Z0-9_]{0,39}$'),
  created_at timestamptz not null default now()
);

comment on table public.ad_refill_claims is 'refillItem 보상 지급 기록. 하루 제한은 app_config.ads.daily_refill_limit, 날짜는 KST.';

create index ad_refill_claims_user_date_idx
  on public.ad_refill_claims (user_id, claim_date);

alter table public.ad_refill_claims enable row level security;
revoke all on public.ad_refill_claims from anon, authenticated;
grant select (id, user_id, claim_date, item, created_at) on public.ad_refill_claims to authenticated;
grant insert (item) on public.ad_refill_claims to authenticated;

create policy "ad refill claims readable by owner"
  on public.ad_refill_claims for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "ad refill claims insert own rows"
  on public.ad_refill_claims for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create or replace function public.ad_refill_status()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with lim as (
    select least(greatest(coalesce((
      select (c.value ->> 'daily_refill_limit')::integer
      from public.app_config c
      where c.key = 'ads'
    ), 3), 0), 20) as daily_limit
  ), used as (
    select count(*)::integer as used_today
    from public.ad_refill_claims a
    where a.user_id = (select auth.uid())
      and a.claim_date = (now() at time zone 'Asia/Seoul')::date
  )
  select jsonb_build_object(
    'daily_limit', lim.daily_limit,
    'used_today', used.used_today,
    'remaining', greatest(lim.daily_limit - used.used_today, 0),
    'date', (now() at time zone 'Asia/Seoul')::date
  )
  from lim, used;
$$;

create or replace function public.claim_ad_refill(p_item text)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_status jsonb;
begin
  if (select auth.uid()) is null then
    raise exception 'auth_required' using errcode = '42501';
  end if;

  -- 같은 사용자의 동시 요청이 제한을 넘지 않게 트랜잭션 단위로 직렬화한다.
  perform pg_advisory_xact_lock(hashtextextended('ad_refill:' || (select auth.uid())::text, 0));

  v_status := public.ad_refill_status();
  if (v_status ->> 'remaining')::integer <= 0 then
    return v_status || jsonb_build_object('granted', false);
  end if;

  insert into public.ad_refill_claims (item) values (p_item);

  return public.ad_refill_status() || jsonb_build_object('granted', true);
end;
$$;

revoke all on function public.ad_refill_status() from public, anon;
grant execute on function public.ad_refill_status() to authenticated;
revoke all on function public.claim_ad_refill(text) from public, anon;
grant execute on function public.claim_ad_refill(text) to authenticated;

-- 4. 게임 이벤트 로그 ------------------------------------------------------

create table public.game_events (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  session_id uuid not null,
  name text not null check (name ~ '^[a-z][a-z0-9_]{0,39}$'),
  params jsonb not null default '{}'::jsonb
    check (jsonb_typeof(params) = 'object' and pg_column_size(params) <= 2048),
  app_version text not null default '' check (char_length(app_version) <= 32),
  channel text not null default '' check (char_length(channel) <= 16),
  client_ts timestamptz,
  created_at timestamptz not null default now()
);

comment on table public.game_events is '내부 이벤트 로그. 개인 식별 정보를 넣지 않는다. 클라이언트는 쓰기만 한다.';

create index game_events_created_idx on public.game_events (created_at);
create index game_events_name_created_idx on public.game_events (name, created_at);
create index game_events_user_recent_idx on public.game_events (user_id, created_at desc);

alter table public.game_events enable row level security;
revoke all on public.game_events from anon, authenticated;
grant insert (session_id, name, params, app_version, channel, client_ts)
  on public.game_events to authenticated;

create policy "game events insert own rows"
  on public.game_events for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

-- 사용자당 1분에 300건을 넘기면 거부한다.
create or replace function private.game_events_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('game_events:' || new.user_id::text, 0));
  if (
    select count(*)
    from public.game_events e
    where e.user_id = new.user_id
      and e.created_at > now() - interval '1 minute'
  ) >= 300 then
    raise exception 'game_events_rate_limited' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

revoke all on function private.game_events_rate_limit() from public, anon, authenticated;

create trigger game_events_rate_limit
  before insert on public.game_events
  for each row execute function private.game_events_rate_limit();

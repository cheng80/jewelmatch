begin transaction isolation level repeatable read read only;
select jsonb_build_object(
 'exported_at',now(),
 'ranking_entries',coalesce((select jsonb_agg(to_jsonb(x) order by x.id) from public.ranking_entries x),'[]'::jsonb),
 'ad_refill_claims',coalesce((select jsonb_agg(to_jsonb(x) order by x.id) from public.ad_refill_claims x),'[]'::jsonb),
 'game_events',coalesce((select jsonb_agg(to_jsonb(x) order by x.id) from public.game_events x),'[]'::jsonb),
 'app_config',coalesce((select jsonb_agg(to_jsonb(x) order by x.key) from public.app_config x),'[]'::jsonb)
) as snapshot;
commit;

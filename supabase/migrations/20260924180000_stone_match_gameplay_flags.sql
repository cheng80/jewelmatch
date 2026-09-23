-- PLAN-008 실험 기능 스위치. 값 형식은 앱의 GameplayFlags.toJson과 같다.
-- 기본값은 모든 실험 꺼짐(지금 동작). 켜고 끄기는 대시보드에서 이 행의 value만 바꾼다.
-- 권한과 RLS는 init 마이그레이션 그대로(anon, authenticated 조회만).

insert into public.app_config (key, value, description) values
  (
    'gameplay',
    '{"time_reward_t1": false, "time_gem": false, "multiplier_gem": false, "seventh_color_from_level": null, "last_hurrah_combo_multiplier": true}',
    '실험 기능 스위치. 다음 새 판부터 적용. seventh_color_from_level은 null이면 6색'
  )
on conflict (key) do nothing;

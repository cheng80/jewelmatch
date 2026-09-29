routerAdd('GET', '/api/stone-match/health', (e) => require(`${__hooks}/stone_match.js`).handle(e, 'health'));
routerAdd('GET', '/api/stone-match/config/gameplay', (e) => require(`${__hooks}/stone_match.js`).handle(e, 'config/gameplay'));
routerAdd('POST', '/api/stone-match/auth/guest', (e) => require(`${__hooks}/stone_match.js`).handle(e, 'auth/guest'));
routerAdd('POST', '/api/stone-match/ranking/list', (e) => require(`${__hooks}/stone_match.js`).handle(e, 'ranking/list'));
routerAdd('POST', '/api/stone-match/ranking/submit', (e) => require(`${__hooks}/stone_match.js`).handle(e, 'ranking/submit'));
routerAdd('POST', '/api/stone-match/ads/status', (e) => require(`${__hooks}/stone_match.js`).handle(e, 'ads/status'));
routerAdd('POST', '/api/stone-match/ads/claim', (e) => require(`${__hooks}/stone_match.js`).handle(e, 'ads/claim'));
routerAdd('POST', '/api/stone-match/events', (e) => require(`${__hooks}/stone_match.js`).handle(e, 'events'));
// Superuser only: recompute sm_daily_metrics for KST days still fully inside raw retention.
routerAdd('POST', '/api/stone-match/admin/metrics/rebuild', (e) => require(`${__hooks}/stone_match.js`).handle(e, 'admin/metrics/rebuild'));
onRecordValidate((e) => {
  require(`${__hooks}/stone_match.js`).validate(e.record);
  e.next();
}, 'sm_players', 'sm_rankings', 'sm_ad_claims', 'sm_events', 'sm_config');
// PocketBase cron uses UTC by default; these preserve KST 04:00, 04:10, 04:20.
cronAdd('stone_match_events_retention', '0 19 * * *', () => require(`${__hooks}/stone_match.js`).purge($app, 'events', Date.now()));
cronAdd('stone_match_ads_retention', '10 19 * * *', () => require(`${__hooks}/stone_match.js`).purge($app, 'ads', Date.now()));
cronAdd('stone_match_players_retention', '20 19 * * *', () => require(`${__hooks}/stone_match.js`).purge($app, 'players', Date.now()));

// Shared module: handlers execute in isolated JS VMs, never capture hook globals.
const DAY = 86400000;
const UUID = /^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i;
function reject() { throw new Error('SM_REJECTED'); }
function object(v) { return v !== null && typeof v === 'object' && !Array.isArray(v); }
// Key-order independent JSON for duplicate content comparison.
function canonical(v) {
  if (Array.isArray(v)) return '[' + v.map(canonical).join(',') + ']';
  if (object(v)) return '{' + Object.keys(v).sort().map((k) => JSON.stringify(k) + ':' + canonical(v[k])).join(',') + '}';
  return JSON.stringify(v);
}
function fingerprint(row) {
  return canonical([row.name, row.session_id.toLowerCase(), row.channel, row.app_version, row.client_ts, row.params]);
}
function stamp(value) {
  // Fixed six-digit UTC precision preserves original Postgres microsecond tie order.
  if (typeof value !== 'string' || !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,6})?(?:Z|[+-]\d\d:\d\d)$/.test(value)) reject();
  const parts = value.slice(0, 19).split(/[-T:]/).map(Number);
  const days = new Date(Date.UTC(parts[0], parts[1], 0)).getUTCDate();
  if (parts[1] < 1 || parts[1] > 12 || parts[2] < 1 || parts[2] > days || parts[3] > 23 || parts[4] > 59 || parts[5] > 59) reject();
  const ms = Date.parse(value);
  if (!Number.isFinite(ms)) reject();
  const fraction = (value.match(/\.(\d+)/) || ['', ''])[1].padEnd(6, '0');
  return new Date(ms).toISOString().slice(0, 19) + '.' + fraction + 'Z';
}
function nowStamp(ms) { return new Date(ms).toISOString().replace('Z', '000Z'); }
function dateKst(ms) { return new Date(ms + 9 * 3600000).toISOString().slice(0, 10); }
function week(ms) {
  const shifted = new Date(ms + 9 * 3600000);
  shifted.setUTCDate(shifted.getUTCDate() - (shifted.getUTCDay() + 6) % 7);
  return shifted.toISOString().slice(0, 10);
}
function name(input) {
  if (typeof input !== 'string' || input.length > 4096 || input.includes('\0')) reject();
  const trim = (s) => s.replace(/^ +| +$/g, ''); // PostgreSQL btrim removes ASCII spaces.
  if (!trim(input)) reject();
  let result = Array.from(trim(input.replace(/[\u0001-\u001f\u007f-\u009f\u00ad\u061c\u115f\u1160\u200b\u200e\u200f\u2028-\u202e\u2060-\u2064\u2066-\u2069\u3164\ufeff\uffa0]/g, ''))).slice(0, 20).join('');
  result = trim(result);
  const visible = Array.from(result).some((c) => {
    const n = c.codePointAt(0);
    return !/[\s\u00a0\u1680\u2000-\u200d\u202f\u205f\u3000\u034f\u180e\u2800\ufe00-\ufe0f]/.test(c) && !(n >= 0xe0000 && n <= 0xe007f);
  });
  return visible ? result : 'GUEST';
}
function mode(v) { if (v !== 'time' && v !== 'level') reject(); return v; }
function config(app, key) {
  const rows = app.findRecordsByFilter('sm_config', 'key = {:key}', '', 1, 0, {key});
  return rows.length ? JSON.parse(rows[0].getString('value')) : null;
}
function limit(app, key, field, fallback, min, max) {
  const value = (config(app, key) || {})[field];
  return Math.min(max, Math.max(min, Number.isInteger(value) ? value : fallback));
}
function count(app, collection, filter, params) { return app.countRecords(collection, $dbx.exp(filter, params || {})); }
function save(app, collection, values) {
  const r = new Record(app.findCollectionByNameOrId(collection));
  for (const key in values) r.set(key, key === 'params' ? JSON.stringify(values[key]) : values[key]);
  app.save(r); return r;
}
function auth(e) {
  if (!e.auth || e.auth.collection().name !== 'sm_players') throw new Error('SM_UNAUTHORIZED');
  return e.auth.id;
}
function touch(app, player, ms) {
  const record = app.findRecordById('sm_players', player);
  record.set('last_active_at', nowStamp(ms)); app.save(record);
}
function quota(app, collection, player, amount, maximum, ms) {
  if (count(app, collection, 'player = {:player} AND created_at > {:cutoff}',
    {player, cutoff: nowStamp(ms - 60000)}) + amount > maximum) throw new Error('SM_RATE_LIMITED');
}
function adStatus(app, player, ms) {
  const daily_limit = limit(app, 'ads', 'daily_refill_limit', 3, 0, 20);
  const date = dateKst(ms);
  const used_today = count(app, 'sm_ad_claims', 'player = {:player} AND claim_date = {:date}', {player, date});
  return {daily_limit, used_today, remaining: Math.max(daily_limit - used_today, 0), date};
}
function event(row) {
  if (!object(row)) reject();
  const allowed = ['session_id', 'name', 'params', 'app_version', 'channel', 'client_ts'];
  if (Object.keys(row).some((k) => !allowed.includes(k))) reject();
  if (typeof row.session_id !== 'string' || !UUID.test(row.session_id)) reject();
  if (typeof row.name !== 'string' || !/^[a-z][a-z0-9_]{0,39}$/.test(row.name)) reject();
  const params = row.params === undefined ? {} : row.params;
  if (!object(params)) reject();
  let serialized;
  try { serialized = JSON.stringify(params); if (unescape(encodeURIComponent(serialized)).length > 2048) reject(); } catch (_) { reject(); }
  const inspect = (value) => {
    if (typeof value === 'string' && value.includes('\0')) reject();
    if (typeof value === 'number' && !Number.isFinite(value)) reject();
    if (value !== null && typeof value === 'object') Object.keys(value).forEach((key) => { inspect(key); inspect(value[key]); });
  };
  inspect(params);
  // Old clients without a UUID event_id are accepted without dedupe.
  const id = params.event_id;
  const result = {session_id: row.session_id.toLowerCase(), name: row.name, params,
    event_id: typeof id === 'string' && UUID.test(id) ? id.toLowerCase() : ''};
  for (const field of ['app_version', 'channel']) {
    const value = row[field] === undefined ? '' : row[field];
    if (typeof value !== 'string' || value.includes('\0') || Array.from(value).length > (field === 'channel' ? 16 : 32)) reject();
    result[field] = value;
  }
  result.client_ts = row.client_ts == null ? '' : stamp(row.client_ts);
  return result;
}
function run(e, operation, body) {
  const app = e.app;
  if (operation === 'health') return {service: 'stone-match', schema_version: 1};
  if (operation === 'admin/metrics/rebuild') {
    if (!e.hasSuperuserAuth()) throw new Error('SM_UNAUTHORIZED');
    if (!object(body)) reject();
    return rebuildMetrics(app, body.from, body.to, Date.now());
  }
  if (operation === 'config/gameplay') {
    const value = config(app, 'gameplay'); return value === null ? [] : [{value}];
  }
  if (operation === 'auth/guest') {
    if (!object(body) || typeof body.device_id !== 'string' || !/^[a-f0-9]{32}$/.test(body.device_id) || typeof body.device_secret !== 'string' || !/^[a-f0-9]{64}$/.test(body.device_secret)) reject();
    let result;
    app.runInTransaction((tx) => {
      const records = tx.findRecordsByFilter('sm_players', 'device_id = {:device}', '', 1, 0, {device: body.device_id});
      const ms = Date.now();
      let player = records[0];
      if (player) {
        if (!player.validatePassword(body.device_secret)) throw new Error('SM_UNAUTHORIZED');
      } else {
        player = new Record(tx.findCollectionByNameOrId('sm_players'));
        player.set('device_id', body.device_id); player.setPassword(body.device_secret);
        player.set('created_at', nowStamp(ms));
      }
      player.set('last_active_at', nowStamp(ms)); tx.save(player);
      result = {token: player.newAuthToken(), record: {id: player.id}, expires_in: player.collection().authToken.duration};
    });
    return result;
  }
  if (operation === 'ranking/list') {
    if (!object(body)) reject();
    const p_mode = mode(body.p_mode);
    if (body.p_limit != null && !Number.isInteger(body.p_limit)) reject();
    const size = Math.min(100, Math.max(1, body.p_limit == null ? limit(app, 'ranking', 'list_limit', 30, 1, 100) : body.p_limit));
    const rows = app.findRecordsByFilter('sm_rankings', 'mode = {:mode}' + (p_mode === 'time' ? ' && week_start = {:week}' : ''),
      '-score,created_at,order_seq', size, 0, {mode: p_mode, week: week(Date.now())});
    return rows.map((r) => ({name: r.getString('name'), score: r.getInt('score'), ts: Math.round(Date.parse(r.getString('created_at')) / 1000)}));
  }
  const player = auth(e);
  if (operation === 'ranking/submit') {
    if (!object(body)) reject();
    const p_mode = mode(body.p_mode), p_name = name(body.p_name), score = body.p_score;
    if (!Number.isInteger(score) || score <= 0 || score > (p_mode === 'level' ? 10000 : 1000000000)) reject();
    let result;
    app.runInTransaction((tx) => {
      const ms = Date.now(), created_at = nowStamp(ms), week_start = week(ms);
      quota(tx, 'sm_rankings', player, 1, 10, ms);
      touch(tx, player, ms);
      const newest = tx.findRecordsByFilter('sm_rankings', '', '-order_seq', 1, 0);
      const order_seq = newest.length ? newest[0].getInt('order_seq') + 1 : 1;
      save(tx, 'sm_rankings', {player, mode: p_mode, name: p_name, score, created_at, week_start, order_seq});
      const rank = count(tx, 'sm_rankings', 'mode = {:mode}' + (p_mode === 'time' ? ' AND week_start = {:week}' : '') +
        ' AND (score > {:score} OR (score = {:score} AND (created_at < {:ts} OR (created_at = {:ts} AND order_seq < {:seq}))))',
      {mode: p_mode, week: week_start, score, ts: created_at, seq: order_seq}) + 1;
      result = {mode: p_mode, ranked: rank <= limit(tx, 'ranking', 'list_limit', 30, 1, 100), rank, score};
      if (p_mode === 'time') result.week_start = week_start;
    });
    return result;
  }
  if (operation === 'ads/status') {
    let result;
    app.runInTransaction((tx) => {
      const ms = Date.now(); touch(tx, player, ms); result = adStatus(tx, player, ms);
    });
    return result;
  }
  if (operation === 'ads/claim') {
    if (!object(body) || typeof body.p_item !== 'string' || !/^[a-zA-Z][a-zA-Z0-9_]{0,39}$/.test(body.p_item)) reject();
    let result;
    app.runInTransaction((tx) => {
      const ms = Date.now(), status = adStatus(tx, player, ms);
      touch(tx, player, ms);
      const granted = status.remaining > 0;
      if (granted) save(tx, 'sm_ad_claims', {player, item: body.p_item, claim_date: status.date, created_at: nowStamp(ms)});
      result = Object.assign(adStatus(tx, player, ms), {granted});
    });
    return result;
  }
  if (operation === 'events') {
    if (!Array.isArray(body) || body.length < 1 || body.length > 200) reject();
    // Same event_id = same event: identical content is accepted once, different content fails the batch.
    const rows = [], byId = {};
    body.map(event).forEach((row) => {
      const prior = row.event_id && byId[row.event_id];
      if (prior && fingerprint(prior) !== fingerprint(row)) reject();
      if (!prior) rows.push(row);
      if (row.event_id) byId[row.event_id] = row;
    });
    app.runInTransaction((tx) => {
      const ids = Object.keys(byId), stored = {};
      if (ids.length) {
        tx.findAllRecords('sm_events', $dbx.hashExp({player, legacy_id: ''}), $dbx.exp("event_id != ''"), $dbx.in('event_id', ...ids)).forEach((r) => {
          stored[r.getString('event_id')] = {name: r.getString('name'), session_id: r.getString('session_id'), channel: r.getString('channel'),
            app_version: r.getString('app_version'), client_ts: r.getString('client_ts'), params: JSON.parse(r.getString('params') || '{}')};
        });
      }
      const fresh = rows.filter((row) => {
        const old = row.event_id && stored[row.event_id];
        if (old && fingerprint(old) !== fingerprint(row)) reject();
        return !old;
      });
      // Only new rows consume the 300/min quota.
      const ms = Date.now(); quota(tx, 'sm_events', player, fresh.length, 300, ms);
      touch(tx, player, ms);
      fresh.forEach((row) => save(tx, 'sm_events', Object.assign({}, row, {player, created_at: nowStamp(ms)})));
    });
    return null;
  }
  reject();
}
function handle(e, operation) {
  try {
    let body = {};
    if (e.request.method === 'POST') {
      try { body = JSON.parse(toString(e.request.body, 1048577)); } catch (_) { reject(); }
    }
    const result = run(e, operation, body);
    if (e.auth && e.auth.collection().name === 'sm_players' && ['health', 'config/gameplay', 'ranking/list'].includes(operation)) {
      e.app.runInTransaction((tx) => touch(tx, e.auth.id, Date.now()));
    }
    return result === null ? e.noContent(204) : e.json(200, result);
  } catch (error) {
    const message = String(error);
    const status = message.includes('SM_UNAUTHORIZED') ? 401 : message.includes('SM_RATE_LIMITED') ? 429 : message.includes('SM_REJECTED') ? 400 : 500;
    if (status === 500) e.app.logger().error('Stone Match operation failed', 'operation', operation);
    return e.json(status, {code: status === 401 ? 'unauthorized' : status === 429 ? 'rate_limited' : status === 400 ? 'rejected' : 'server'});
  }
}
function validate(record) {
  const collection = record.collection().name;
  for (const field of ['created_at', 'last_active_at', 'client_ts']) {
    if (record.getString(field)) record.set(field, stamp(record.getString(field)));
  }
  if (collection === 'sm_rankings') {
    if (name(record.getString('name')) !== record.getString('name')) reject();
    if (record.getString('mode') === 'level' && record.getInt('score') > 10000) reject();
    record.set('week_start', week(Date.parse(record.getString('created_at'))));
  }
  if (collection === 'sm_events') {
    const row = event({session_id: record.getString('session_id'), name: record.getString('name'),
      params: JSON.parse(record.getString('params') || '{}'), app_version: record.getString('app_version'), channel: record.getString('channel'),
      client_ts: record.getString('client_ts') || null});
    // Preserve canonical UTF-8 size even when the admin API escaped HTML characters.
    record.set('params', JSON.stringify(row.params));
    record.set('event_id', row.event_id);
  }
  if (collection === 'sm_config' && !object(JSON.parse(record.getString('value')))) reject();
}
function purge(app, kind, ms) {
  const cutoff = nowStamp(ms - 90 * DAY);
  app.runInTransaction((tx) => {
    // Aggregate first: a failed aggregate aborts the purge and keeps raw rows.
    if (kind === 'events') nightlyMetrics(tx, ms);
    if (kind === 'events') tx.db().newQuery('DELETE FROM sm_events WHERE created_at < {:cutoff}').bind({cutoff}).execute();
    else if (kind === 'ads') tx.db().newQuery('DELETE FROM sm_ad_claims WHERE claim_date < {:cutoff}').bind({cutoff: dateKst(ms - 35 * DAY)}).execute();
    else if (kind === 'players') {
      // Stale players' events are deleted here too: aggregate first so they are never dropped unaggregated,
      // even if the earlier events cron failed.
      nightlyMetrics(tx, ms);
      // Explicit SQL mirrors ON DELETE SET NULL / CASCADE without touching other apps.
      const predicate = 'SELECT id FROM sm_players WHERE created_at < {:cutoff} AND last_active_at < {:cutoff}';
      tx.db().newQuery(`UPDATE sm_rankings SET player = '' WHERE player IN (${predicate})`).bind({cutoff}).execute();
      for (const table of ['sm_events', 'sm_ad_claims']) tx.db().newQuery(`DELETE FROM ${table} WHERE player IN (${predicate})`).bind({cutoff}).execute();
      // Use PocketBase deletion for auth-origin/token side effects and relation hooks.
      let rows;
      do {
        rows = tx.findRecordsByFilter('sm_players', 'created_at < {:cutoff} && last_active_at < {:cutoff}', '', 200, 0, {cutoff});
        rows.forEach((r) => tx.delete(r));
      } while (rows.length === 200);
    } else reject();
  });
}

// Daily metrics (admin only). Day = KST date of server created_at, so late client clocks never move rows.
// A day is recomputed only while all of its raw rows are inside the 90-day retention window (completeness
// = complete). A day that still has raw rows past the cutoff but was never aggregated (first deploy, long job
// outage) is aggregated once from what remains (completeness = partial) before purge deletes it.
// Existing aggregates outside the window are never overwritten. Recompute = delete that day's rows + insert.
// Attempt ends are matched to a start-day cohort only if received within 8 KST days of that day's start;
// the nightly recomputes the last 8 complete days, so day D is final at D+8 04:00 KST with the same window.
// Later ends leave the round unknown. Ends only count for the
// start's telemetry_env; a round whose only ends carry another env (QA toggled mid-round) is env_changed.
const WHO = "CASE WHEN player != '' THEN player WHEN legacy_user_id != '' THEN 'legacy:' || legacy_user_id END";
function metricRows(where) {
  // Normalized raw rows. uniq dedupes retries/legacy duplicates; rows without event_id count individually.
  return `SELECT id, name, session_id, channel, app_version, who,
      CASE WHEN event_id != '' THEN COALESCE(who, '') || '|' || event_id ELSE id END AS uniq,
      CASE WHEN json_extract(p, '$.telemetry_env') IN ('production', 'qa', 'development', 'test') THEN json_extract(p, '$.telemetry_env') ELSE 'unknown' END AS env,
      CASE WHEN json_extract(p, '$.mode') IN ('simple', 'progression', 'timed', 'time', 'level') THEN json_extract(p, '$.mode') ELSE '' END AS mode,
      CASE WHEN json_type(p, '$.run_id') = 'text' AND json_type(p, '$.round_seq') = 'integer'
        THEN COALESCE(who, '') || '|' || json_extract(p, '$.run_id') || '|' || json_extract(p, '$.round_seq') END AS round
    FROM (SELECT id, name, session_id, channel, app_version, event_id, ${WHO} AS who,
      CASE WHEN json_valid(params) THEN params END AS p FROM sm_events WHERE ${where})`;
}
const METRICS_SQL = `WITH ev AS (${metricRows('created_at >= {:start} AND created_at < {:end}')}),
  starts AS (SELECT round, MIN(env) env, MIN(channel) channel, MIN(app_version) app_version, MIN(mode) mode,
      MIN(who) who, MIN(session_id) session_id FROM ev WHERE name = 'round_start' AND round IS NOT NULL GROUP BY round),
  ends AS MATERIALIZED (SELECT round, env, COUNT(DISTINCT uniq) attempts
    FROM (${metricRows("name = 'round_end' AND created_at >= {:start} AND created_at < {:until}")}) WHERE round IS NOT NULL GROUP BY round, env),
  cohort AS (SELECT s.env, s.channel, s.app_version, s.mode, s.who, s.session_id,
      SUM(CASE WHEN e.env = s.env THEN e.attempts END) same, MAX(e.env IS NOT NULL AND e.env != s.env) other
    FROM starts s LEFT JOIN ends e ON e.round = s.round GROUP BY s.round),
  m AS (
    SELECT 'day' kind, '*' env, '*' channel, '*' app_version, '*' mode, '*' event_name, COUNT(DISTINCT uniq) events, COUNT(*) raw_rows,
      COUNT(DISTINCT who) players, COUNT(DISTINCT session_id) sessions, 0 round_starts, 0 attempt_ends, 0 rounds_ended, 0 rounds_env_changed,
      0 rounds_unknown FROM ev
    UNION ALL SELECT 'env', env, '*', '*', '*', '*', COUNT(DISTINCT uniq), COUNT(*), COUNT(DISTINCT who), COUNT(DISTINCT session_id), 0, 0, 0, 0, 0
      FROM ev GROUP BY env
    UNION ALL SELECT 'event', env, channel, app_version, mode, name, COUNT(DISTINCT uniq), COUNT(*), COUNT(DISTINCT who), COUNT(DISTINCT session_id), 0, 0, 0, 0, 0
      FROM ev GROUP BY env, channel, app_version, mode, name
    UNION ALL SELECT 'rounds', env, channel, app_version, mode, 'round_start', 0, 0, COUNT(DISTINCT who), COUNT(DISTINCT session_id),
      COUNT(*), COALESCE(SUM(same), 0), COUNT(same), SUM(same IS NULL AND other), SUM(same IS NULL AND NOT other)
      FROM cohort GROUP BY env, channel, app_version, mode)
  INSERT INTO sm_daily_metrics (key, kind, day, env, channel, app_version, mode, event_name, events, raw_rows, players, sessions,
    round_starts, attempt_ends, rounds_ended, rounds_env_changed, rounds_unknown, completeness, computed_at, definition)
  SELECT kind || '|' || {:day} || '|' || env || '|' || channel || '|' || app_version || '|' || mode || '|' || event_name,
    kind, {:day}, env, channel, app_version, mode, event_name, events, raw_rows, players, sessions,
    round_starts, attempt_ends, rounds_ended, rounds_env_changed, rounds_unknown, {:completeness}, {:computed}, 1 FROM m`;
function dayStart(day) { return Date.parse(day + 'T00:00:00+09:00'); }
function aggregateDay(app, day, ms, completeness) {
  const start = dayStart(day);
  app.db().newQuery('DELETE FROM sm_daily_metrics WHERE day = {:day}').bind({day}).execute();
  app.db().newQuery(METRICS_SQL).bind({day, start: nowStamp(start), end: nowStamp(start + DAY), until: nowStamp(start + 8 * DAY),
    completeness: completeness || 'complete', computed: nowStamp(ms)}).execute();
}
function aggregatedDays(app, from) {
  const done = {};
  app.findAllRecords('sm_daily_metrics', $dbx.hashExp({kind: 'day'}), $dbx.exp('day >= {:day}', {day: from}))
    .forEach((r) => { done[r.getString('day')] = true; });
  return done;
}
// Days that still have raw rows older than the cutoff (not fully retained) and no aggregate yet.
function unaggregatedOldDays(app, ms, done) {
  const rows = arrayOf(new DynamicModel({day: ''}));
  app.db().newQuery("SELECT DISTINCT date(substr(created_at, 1, 19), '+9 hours') AS day FROM sm_events WHERE created_at < {:cutoff}")
    .bind({cutoff: nowStamp(dayStart(dateKst(ms - 90 * DAY)) + DAY)}).all(rows);
  return rows.map((r) => r.day).filter((day) => !done[day] && dayStart(day) < ms - 90 * DAY);
}
// Days whose raw rows are all still retained, newest first, excluding today (still open).
function retainedDays(ms) {
  const days = [];
  for (let start = dayStart(dateKst(ms)) - DAY; start >= ms - 90 * DAY; start -= DAY) days.push(dateKst(start));
  return days;
}
// Nightly, before purge: the last 8 complete days (late round ends), any retained day never aggregated,
// and a one-time partial aggregate of never-aggregated days the purge is about to (partly) delete.
function nightlyMetrics(app, ms) {
  const days = retainedDays(ms);
  const done = aggregatedDays(app, '0000-00-00');
  days.forEach((day, i) => { if (i < 8 || !done[day]) aggregateDay(app, day, ms, 'complete'); });
  unaggregatedOldDays(app, ms, done).forEach((day) => aggregateDay(app, day, ms, 'partial'));
}
function rebuildMetrics(app, from, to, ms) {
  const valid = (d) => typeof d === 'string' && /^\d{4}-\d\d-\d\d$/.test(d) && Number.isFinite(dayStart(d)) && dateKst(dayStart(d)) === d;
  if (!valid(from) || !valid(to) || from > to || dayStart(to) - dayStart(from) > 100 * DAY) reject();
  const retained = {};
  retainedDays(ms).forEach((day) => { retained[day] = true; });
  const result = {rebuilt: [], partial: [], skipped: []};
  app.runInTransaction((tx) => {
    const old = {};
    unaggregatedOldDays(tx, ms, aggregatedDays(tx, from)).forEach((day) => { old[day] = true; });
    for (let start = dayStart(from); start <= dayStart(to); start += DAY) {
      const day = dateKst(start);
      if (retained[day]) { aggregateDay(tx, day, ms, 'complete'); result.rebuilt.push(day); }
      // Admin backfill for a missed old day: only once, never over an existing aggregate.
      else if (old[day]) { aggregateDay(tx, day, ms, 'partial'); result.partial.push(day); }
      else result.skipped.push(day);
    }
  });
  return result;
}
module.exports = {handle, validate, purge, week, dateKst, stamp, name};

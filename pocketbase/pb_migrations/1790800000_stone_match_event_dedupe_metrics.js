// PocketBase 0.39.7. Follow-up to 1790680000 (already applied in production; never edit that file).
// Adds server event_id dedupe and the admin-only sm_daily_metrics aggregate collection.
migrate((app) => {
  const uuid = '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$';
  const events = app.findCollectionByNameOrId('sm_events');
  events.fields.add(new TextField({name: 'event_id', max: 36, pattern: uuid}));
  app.save(events);
  // Backfill from params.event_id (Step 1 clients). Other/invalid values stay '' = no dedupe.
  const hex = (n) => '[0-9a-f]'.repeat(n);
  const glob = [hex(8), hex(4), hex(4), hex(4), hex(12)].join('-');
  app.db().newQuery(`UPDATE sm_events SET event_id = lower(json_extract(params, '$.event_id'))
    WHERE CASE WHEN json_valid(params) AND json_type(params, '$.event_id') = 'text'
      THEN lower(json_extract(params, '$.event_id')) GLOB {:glob} ELSE 0 END`).bind({glob}).execute();
  // Same owner + same id: keep the earliest (created_at, id). Imported legacy rows (legacy_id != '')
  // are original history and are never deleted; aggregation dedupes them by legacy_user_id instead.
  const removed = app.db().newQuery(`DELETE FROM sm_events WHERE id IN (SELECT id FROM (SELECT id,
    ROW_NUMBER() OVER (PARTITION BY player, event_id ORDER BY created_at, id) AS n
    FROM sm_events WHERE legacy_id = '' AND event_id != '') WHERE n > 1)`).execute().rowsAffected();
  app.logger().info('Stone Match event dedupe migration', 'removed_duplicates', removed);
  events.indexes.push("CREATE UNIQUE INDEX sm_events_dedupe ON sm_events (player, event_id) WHERE event_id != '' AND legacy_id = ''");
  app.save(events);

  const text = (name, extra) => Object.assign({type: 'text', name, max: 64}, extra || {});
  const count = (name) => ({type: 'number', name, min: 0, onlyInt: true});
  app.save(new Collection({name: 'sm_daily_metrics', type: 'base',
    listRule: null, viewRule: null, createRule: null, updateRule: null, deleteRule: null,
    fields: [text('key', {required: true, max: 255}),
      {type: 'select', name: 'kind', required: true, values: ['day', 'env', 'event', 'rounds'], maxSelect: 1},
      text('day', {required: true, pattern: '^\\d{4}-\\d{2}-\\d{2}$'}),
      text('env'), text('channel'), text('app_version'), text('mode'), text('event_name'),
      count('events'), count('raw_rows'), count('players'), count('sessions'),
      count('round_starts'), count('attempt_ends'), count('rounds_ended'), count('rounds_env_changed'), count('rounds_unknown'),
      // complete: every raw row of the day was retained when computed. partial: first computed after the
      // retention cutoff passed the day's start (first deploy or a long job outage), so rows may be missing.
      {type: 'select', name: 'completeness', required: true, values: ['complete', 'partial'], maxSelect: 1},
      text('computed_at', {required: true}), count('definition')],
    // key is a readable label, not a constraint: channel/app_version are client strings and may contain '|'.
    // Each day is replaced as a whole in one transaction, so reruns cannot duplicate rows.
    indexes: ['CREATE INDEX sm_daily_metrics_key ON sm_daily_metrics (key)',
      'CREATE INDEX sm_daily_metrics_day ON sm_daily_metrics (day, kind)']}));
}, (app) => {
  // Deleted duplicate rows cannot be restored; this only removes the added schema.
  app.delete(app.findCollectionByNameOrId('sm_daily_metrics'));
  const events = app.findCollectionByNameOrId('sm_events');
  events.indexes = events.indexes.filter((sql) => !sql.includes('sm_events_dedupe'));
  events.fields.removeByName('event_id');
  app.save(events);
});

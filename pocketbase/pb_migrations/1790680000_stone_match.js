// PocketBase 0.39.7. Only Stone Match collections are created or removed.
migrate((app) => {
  const text = (name, extra) => Object.assign({type: 'text', name, max: 255}, extra || {});
  const players = new Collection({
    type: 'auth', name: 'sm_players',
    listRule: null, viewRule: null, createRule: null, updateRule: null, deleteRule: null,
    authRule: null, manageRule: null,
    passwordAuth: {enabled: false}, oauth2: {enabled: false}, otp: {enabled: false},
    authAlert: {enabled: false}, authToken: {duration: 604800},
    fields: [text('device_id', {required: true, pattern: '^[a-f0-9]{32}$'}),
      text('created_at', {required: true}), text('last_active_at', {required: true})],
    indexes: ['CREATE UNIQUE INDEX sm_players_device ON sm_players (device_id)'],
  });
  players.fields.add(new EmailField({name: 'email', required: false}));
  app.save(players);
  const historical = (cascade) => [
    {type: 'relation',name: 'player', collectionId: players.id, maxSelect: 1, cascadeDelete: !!cascade},
    text('legacy_id'), text('legacy_user_id'), text('created_at', {required: true}),
  ];
  const create = (name, fields, indexes) => {
    app.save(new Collection({name, type: 'base', fields,
      listRule: null, viewRule: null, createRule: null, updateRule: null, deleteRule: null,
      indexes: indexes || []}));
  };
  const legacy = (name) => `CREATE UNIQUE INDEX ${name}_legacy ON ${name} (legacy_id) WHERE legacy_id != ''`;
  create('sm_rankings', historical().concat([
    {type: 'select',name: 'mode', required: true, values: ['time', 'level'], maxSelect: 1},
    text('name', {required: true, max: 20}),
    {type: 'number',name: 'score', required: true, min: 1, max: 1000000000, onlyInt: true},
    text('week_start', {required: true, pattern: '^\\d{4}-\\d{2}-\\d{2}$'}),
    {type: 'number',name: 'order_seq', required: true, min: 1, max: 9007199254740991, onlyInt: true},
  ]), [legacy('sm_rankings'),
    'CREATE UNIQUE INDEX sm_rankings_order ON sm_rankings (order_seq)',
    'CREATE INDEX sm_rankings_week ON sm_rankings (mode, week_start, score DESC, created_at, order_seq)',
    'CREATE INDEX sm_rankings_all ON sm_rankings (mode, score DESC, created_at, order_seq)',
    'CREATE INDEX sm_rankings_recent ON sm_rankings (player, created_at)']);
  create('sm_ad_claims', historical(true).concat([
    text('item', {required: true, pattern: '^[a-zA-Z][a-zA-Z0-9_]{0,39}$'}),
    text('claim_date', {required: true, pattern: '^\\d{4}-\\d{2}-\\d{2}$'}),
  ]), [legacy('sm_ad_claims'), 'CREATE INDEX sm_ad_claims_day ON sm_ad_claims (player, claim_date)',
    'CREATE INDEX sm_ad_claims_retention ON sm_ad_claims (claim_date)']);
  create('sm_events', historical(true).concat([
    text('session_id', {required: true, pattern: '^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$'}),
    text('name', {required: true, pattern: '^[a-z][a-z0-9_]{0,39}$'}),
    {type: 'json',name: 'params', maxSize: 2048},
    text('app_version', {max: 32}), text('channel', {max: 16}), text('client_ts'),
  ]), [legacy('sm_events'), 'CREATE INDEX sm_events_recent ON sm_events (player, created_at)',
    'CREATE INDEX sm_events_retention ON sm_events (created_at)',
    'CREATE INDEX sm_events_name ON sm_events (name, created_at)']);
  create('sm_config', [text('key', {required: true, pattern: '^[a-z][a-z0-9_]{0,39}$'}),
    {type: 'json',name: 'value', required: true, maxSize: 16384}],
  ['CREATE UNIQUE INDEX sm_config_key ON sm_config (key)']);
  const defaults = {
    ranking: {list_limit: 30}, ads: {daily_refill_limit: 3},
    gameplay: {time_reward_t1: false, time_gem: false, multiplier_gem: false,
      seventh_color_from_level: null, last_hurrah_combo_multiplier: false},
  };
  for (const key in defaults) {
    const record = new Record(app.findCollectionByNameOrId('sm_config'));
    record.set('key', key); record.set('value', defaults[key]); app.save(record);
  }
}, (app) => {
  // Explicit migrate down is destructive; never run this on production as a rollback.
  for (const name of ['sm_events', 'sm_ad_claims', 'sm_rankings', 'sm_config', 'sm_players']) {
    app.delete(app.findCollectionByNameOrId(name));
  }
});

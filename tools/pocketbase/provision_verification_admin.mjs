// Executed over SSH. The complete credential payload arrives only on stdin.
import PocketBase from './pocketbase.es.mjs';

try {
  let input = '';
  for await (const chunk of process.stdin) input += chunk;
  const {bootstrap, email, password} = JSON.parse(input);
  if (email !== 'verify-admin@stonematch.local' || bootstrap.email === email || !/^[a-f0-9]{48}$/.test(password)) {
    throw new Error('Invalid provisioning payload');
  }
  const pb = new PocketBase('http://127.0.0.1:8090');
  pb.autoCancellation(false);
  await pb.collection('_superusers').authWithPassword(bootstrap.email, bootstrap.password);
  let record;
  try { record = await pb.collection('_superusers').getFirstListItem(pb.filter('email={:email}', {email})); }
  catch (error) { if (error.status !== 404) throw error; }
  const data = {email, password, passwordConfirm: password, verified: true};
  const action = record ? 'updated' : 'created';
  if (record) await pb.collection('_superusers').update(record.id, data);
  else await pb.collection('_superusers').create(data);
  const records = await pb.collection('_superusers').getFullList({fields: 'email'});
  pb.authStore.clear();
  console.log(JSON.stringify({action, emails: records.map(r => r.email).sort()}));
} catch (error) {
  // SDK errors may contain submitted passwords. Never print their message/body.
  console.error(JSON.stringify({error: 'Verification administrator provisioning failed', status: error.status || null}));
  process.exitCode = 1;
}

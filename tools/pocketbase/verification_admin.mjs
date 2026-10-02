import {readFile, writeFile, mkdir, lstat, open} from 'node:fs/promises';
import {randomBytes} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import PocketBase from 'pocketbase';

export const EMAIL = 'verify-admin@stonematch.local';
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const PB_URL = 'https://stonematch-pb.fastmake.net';
const DASHBOARD = 'https://stomematch-dashboard.pages.dev';
const REMOTE_ROOT = '/Users/cheng80/Servers/stonematch';

export function parseEnv(text) {
  return Object.fromEntries(text.split(/\r?\n/).filter(l => l.trim() && !l.trim().startsWith('#') && l.includes('=')).map(l => {
    const i=l.indexOf('='); return [l.slice(0,i).trim(),l.slice(i+1).trim().replace(/^(["'])(.*)\1$/, '$2')];
  }));
}

export async function readCredentials(filename) {
  const stat=await lstat(filename);
  if (!stat.isFile() || stat.isSymbolicLink() || (stat.mode & 0o777) !== 0o600) throw new Error('Credential file must be a regular 0600 file');
  const env=parseEnv(await readFile(filename,'utf8'));
  if(env.REMOTE_ADMIN_EMAIL!==EMAIL || !/^[a-f0-9]{48}$/.test(env.REMOTE_ADMIN_PASSWORD || '')) throw new Error('Invalid verification administrator credentials');
  return {email:env.REMOTE_ADMIN_EMAIL,password:env.REMOTE_ADMIN_PASSWORD};
}

function run(command,args,input) {
  const result=spawnSync(command,args,{input,encoding:'utf8',maxBuffer:2**20});
  if(result.error || result.status!==0) throw new Error(`${command} failed (exit ${result.status ?? 'unavailable'}); private output suppressed`);
  return result.stdout;
}

const BACKUP = String.raw`import pathlib,subprocess,sqlite3,json,hashlib,datetime,uuid
root=pathlib.Path('/Users/cheng80/Servers/stonematch')
out=pathlib.Path('/Users/cheng80/Servers/backups')/('stonematch-verify-admin-'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S')+'-'+uuid.uuid4().hex[:8])
out.mkdir(mode=0o700)
files=[]
for name in ['data.db','auxiliary.db']:
 p=out/name
 r=subprocess.run(['sqlite3',str(root/'pb_data'/name),'.backup "'+str(p)+'"'],capture_output=True)
 if r.returncode: raise SystemExit('SQLite online backup failed')
 p.chmod(0o600)
 db=sqlite3.connect(p.as_uri()+'?mode=ro&immutable=1',uri=True); assert db.execute('pragma integrity_check').fetchone()[0]=='ok'; db.close()
 files.append({'name':name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'integrity':'ok'})
db=sqlite3.connect((out/'data.db').as_uri()+'?mode=ro&immutable=1',uri=True);db.row_factory=sqlite3.Row
rows=[dict(r) for r in db.execute('select * from _superusers order by email')];db.close()
digests={r['email']:hashlib.sha256(json.dumps(r,sort_keys=True).encode()).hexdigest() for r in rows}
report={'backup':str(out),'files':files,'existing_superuser_digests':digests,'emails':[r['email'] for r in rows]}
(out/'before.json').write_text(json.dumps(report));(out/'before.json').chmod(0o600)
print(json.dumps(report))`;

async function provision(options) {
  const filename=options.credentials;
  await mkdir(path.dirname(filename),{recursive:true,mode:0o700});
  const ignored=run('git',['-C',path.dirname(filename),'check-ignore','--',filename]);
  if(!ignored.trim()) throw new Error('Credential path must be Git ignored');
  let creds;
  try { creds=await readCredentials(filename); }
  catch(error) {
    if(error.code!=='ENOENT') throw error;
    const handle=await open(filename,'wx',0o600);
    try { await handle.writeFile(`REMOTE_ADMIN_EMAIL=${EMAIL}\nREMOTE_ADMIN_PASSWORD=${randomBytes(24).toString('hex')}\n`); }
    finally { await handle.close(); }
    creds=await readCredentials(filename);
  }
  const env=parseEnv(await readFile(options.bootstrap,'utf8'));
  if(env.POCKETBASE_URL?.replace(/\/$/,'')!==PB_URL || !env.POCKETBASE_ADMIN_EMAIL || !env.POCKETBASE_ADMIN_PASSWORD || env.POCKETBASE_ADMIN_EMAIL===EMAIL) throw new Error('Invalid Stone Match bootstrap environment');
  const ssh=['-o','BatchMode=yes','-o','ConnectTimeout=10','-o','IdentitiesOnly=yes','-i',options.key,options.host];
  const backup=JSON.parse(run('ssh',[...ssh,'python3 -'],BACKUP));
  await mkdir(options.out,{recursive:true,mode:0o700});
  await writeFile(path.join(options.out,'backup.json'),JSON.stringify(backup,null,2),{mode:0o600});
  const stage=REMOTE_ROOT+'/.local/verification-admin';
  // Borrow only the already-installed Node binary; copy it into Stone Match.
  run('ssh',[...ssh,`umask 077; mkdir -p ${stage}; if [ ! -x ${stage}/node ]; then cp /Users/cheng80/Servers/pixeltown-colyseus/runtime/bin/node ${stage}/node; fi; chmod 700 ${stage} ${stage}/node`]);
  const scp=['-o','BatchMode=yes','-o','ConnectTimeout=10','-o','IdentitiesOnly=yes','-i',options.key];
  run('scp',[...scp,path.join(ROOT,'node_modules/pocketbase/dist/pocketbase.es.mjs'),`${options.host}:${stage}/pocketbase.es.mjs`]);
  run('scp',[...scp,path.join(ROOT,'tools/pocketbase/provision_verification_admin.mjs'),`${options.host}:${stage}/provision.mjs`]);
  const payload=JSON.stringify({bootstrap:{email:env.POCKETBASE_ADMIN_EMAIL,password:env.POCKETBASE_ADMIN_PASSWORD},...creds});
  const result=JSON.parse(run('ssh',[...ssh,`${stage}/node ${stage}/provision.mjs`],payload));
  const compare=String.raw`import pathlib,json,sqlite3,hashlib
before=json.loads(pathlib.Path(${JSON.stringify(backup.backup+'/before.json')}).read_text())
db=sqlite3.connect('/Users/cheng80/Servers/stonematch/pb_data/data.db');db.row_factory=sqlite3.Row
rows=[dict(r) for r in db.execute('select * from _superusers order by email')];db.close()
after={r['email']:hashlib.sha256(json.dumps(r,sort_keys=True).encode()).hexdigest() for r in rows}
assert all(after.get(email)==digest for email,digest in before['existing_superuser_digests'].items() if email!='verify-admin@stonematch.local')
assert set(after)==set(before['existing_superuser_digests'])|{'verify-admin@stonematch.local'}
print(json.dumps({'owner_and_other_superusers_unchanged':True,'emails':sorted(after)}))`;
  const preserved=JSON.parse(run('ssh',[...ssh,'python3 -'],compare));
  const report={...result,...preserved,backup:backup.backup,credentialFile:filename};
  await writeFile(path.join(options.out,'provision.json'),JSON.stringify(report,null,2),{mode:0o600});
  console.log(JSON.stringify(report));
}

async function check(options) {
  const creds=await readCredentials(options.credentials);
  const pb=new PocketBase(PB_URL);pb.autoCancellation(false);
  const results=[];let playerId;
  const verify=async(name,fn)=>{
    try { results.push({name,ok:true,...await fn()}); }
    catch(error) { results.push({name,ok:false,status:error.status || null}); }
  };
  const response=async(url,headers={})=>fetch(url,{headers,redirect:'manual',signal:AbortSignal.timeout(20000)});
  const expect=async(url,status,headers)=>{const r=await response(url,headers);await r.body?.cancel();if(r.status!==status)throw {status:r.status};return r.status;};
  try {
    await verify('dedicated_superuser',async()=>{const auth=await pb.collection('_superusers').authWithPassword(creds.email,creds.password);if(!pb.authStore.isSuperuser || auth.record.email!==EMAIL)throw new Error();return {authenticated:true};});
    if(!pb.authStore.isSuperuser) throw new Error('Verification administrator authentication failed');
    await verify('administrator_page',async()=>({status:await expect(PB_URL+'/_/',200)}));
    await verify('administrator_collection',async()=>{await pb.collection('sm_daily_metrics').getList(1,1,{fields:'id'});return {status:200};});
    const endpoint=DASHBOARD+'/api/observability?provider=sentry&env=production&days=7';
    const admin={Authorization:'Bearer '+pb.authStore.token};
    await verify('administrator_api',async()=>({status:await expect(endpoint,200,admin)}));
    await verify('other_origin',async()=>({status:await expect(endpoint,403,{...admin,Origin:'https://unapproved.example'})}));
    await verify('anonymous',async()=>({status:await expect(endpoint,401)}));
    await verify('wrong_token',async()=>({status:await expect(endpoint,401,{Authorization:'Bearer invalid-verification-token'})}));
    await verify('wrong_password',async()=>{
      const client=new PocketBase(PB_URL);
      try {await client.collection('_superusers').authWithPassword(creds.email,randomBytes(24).toString('hex'));throw new Error();}
      catch(error){if(error.status!==400)throw error;return {status:400,nativePocketBaseContract:true};}
    });
    await verify('ordinary_player',async()=>{
      const guest=await pb.send('/api/stone-match/auth/guest',{method:'POST',headers:{Authorization:''},body:{device_id:randomBytes(16).toString('hex'),device_secret:randomBytes(32).toString('hex')}});
      playerId=guest.record.id;
      return {status:await expect(endpoint,401,{Authorization:'Bearer '+guest.token})};
    });
    await verify('superuser_email_list',async()=>({emails:(await pb.collection('_superusers').getFullList({fields:'email'})).map(r=>r.email).sort()}));
  } finally {
    if(playerId) await verify('temporary_player_cleanup',async()=>{await pb.collection('sm_players').delete(playerId);return {deleted:true};});
    pb.authStore.clear();
    await mkdir(options.out,{recursive:true,mode:0o700});
    const report={checks:results,passed:results.filter(r=>r.ok).length,failed:results.filter(r=>!r.ok).length,ownerCredentialsUsed:false};
    await writeFile(path.join(options.out,'checks.json'),JSON.stringify(report,null,2),{mode:0o600});
    console.log(JSON.stringify(report));
    if(report.failed)process.exitCode=1;
  }
}

async function main() {
  const args=process.argv.slice(2),mode=args[0];
  if(args.includes('--help')){console.log('node tools/pocketbase/verification_admin.mjs provision|check [--credentials <0600 env>] [--bootstrap-env <env>] [--ssh-key <key>] [--ssh-host <host>] [--out <directory>]');return;}
  const allowed=new Set(['--credentials','--bootstrap-env','--ssh-key','--ssh-host','--out']);
  for(let i=1;i<args.length;i+=2)if(!allowed.has(args[i])||!args[i+1]||args[i+1].startsWith('--'))throw new Error('Invalid command options');
  const value=(key,fallback)=>{const i=args.indexOf(key);return i<0?fallback:args[i+1];};
  const options={credentials:path.resolve(value('--credentials',path.join(ROOT,'pocketbase/.local/remote-admin.env'))),bootstrap:path.resolve(value('--bootstrap-env',path.join(ROOT,'.env.pocketbase'))),key:path.resolve(value('--ssh-key',path.join(process.env.HOME,'.ssh/stonematch_macmini_ed25519'))),host:value('--ssh-host','cheng80@100.92.43.82'),out:path.resolve(value('--out',path.join(ROOT,'tmp/verification-admin')))};
  if(mode==='provision')await provision(options);
  else if(mode==='check')await check(options);
  else throw new Error('Choose provision or check');
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))main().catch(()=>{console.error('Verification administrator operation failed; credentials and private responses suppressed.');process.exitCode=1;});

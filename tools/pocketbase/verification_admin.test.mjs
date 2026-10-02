import assert from 'node:assert/strict';
import test from 'node:test';
import {mkdtemp, mkdir, writeFile, chmod, symlink, rm} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {EMAIL, parseEnv, readCredentials} from './verification_admin.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
async function fixture(fn) {
  await mkdir(path.join(root,'tmp'),{recursive:true});
  const folder=await mkdtemp(path.join(root,'tmp/verify-admin-test-'));
  const filename=path.join(folder,'remote-admin.env');
  await writeFile(filename,`REMOTE_ADMIN_EMAIL=${EMAIL}\nREMOTE_ADMIN_PASSWORD=${'a'.repeat(48)}\n`,{mode:0o600});
  try {await fn(filename,folder);} finally {await rm(folder,{recursive:true,force:true});}
}
test('secure verification credential file accepts a 24-byte hex password',()=>fixture(async filename=>{
  const c=await readCredentials(filename);
  assert.equal(c.email,EMAIL);assert.equal(c.password.length,48);
}));
test('readable by other users is rejected without exposing the password',()=>fixture(async filename=>{
  await chmod(filename,0o644);
  await assert.rejects(readCredentials(filename),/regular 0600 file/);
}));
test('symlinks cannot redirect the verification file to owner credentials',()=>fixture(async(filename,folder)=>{
  const alias=path.join(folder,'alias.env');await symlink(filename,alias);
  await assert.rejects(readCredentials(alias),/regular 0600 file/);
}));
test('owner credentials and undersized passwords are rejected',()=>fixture(async filename=>{
  await writeFile(filename,`REMOTE_ADMIN_EMAIL=owner@example.invalid\nREMOTE_ADMIN_PASSWORD=${'a'.repeat(48)}\n`);
  await assert.rejects(readCredentials(filename),/Invalid verification administrator credentials/);
  await writeFile(filename,`REMOTE_ADMIN_EMAIL=${EMAIL}\nREMOTE_ADMIN_PASSWORD=short\n`);
  await assert.rejects(readCredentials(filename),/Invalid verification administrator credentials/);
}));
test('environment parser treats values as data, including quotes and equals signs',()=>{
  assert.deepEqual(parseEnv('# comment\nKEY="a=b"\nOTHER=\'value\'\n'),{KEY:'a=b',OTHER:'value'});
});

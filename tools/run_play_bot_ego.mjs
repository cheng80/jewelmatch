import { readFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const value = (name, fallback) => args.includes(name) ? args[args.indexOf(name) + 1] : fallback;
if (args.includes('--help')) {
  console.log('node tools/run_play_bot_ego.mjs [--space <id>] [--url <game-root>] [--out <directory>]');
} else {
  const space = value('--space', null);
  if (space !== null && (!Number.isInteger(Number(space)) || Number(space) < 1)) throw new Error('Invalid --space');
  const config = { root, space: space === null ? null : Number(space),
    url: value('--url', 'https://cheng80.myqnapcloud.com/match/'),
    out: path.resolve(value('--out', path.join(root, 'tmp/play-bot/ego-latest'))) };
  const source = await readFile(path.join(root, 'tools/play_bot_ego.mjs'), 'utf8');
  const child = spawn(process.env.EGO_BROWSER_CLI || 'ego-browser', ['nodejs'], { stdio: ['pipe', 'inherit', 'inherit'] });
  child.stdin.end(`globalThis.STONE_BOT_CONFIG = ${JSON.stringify(config)};\n${source}`);
  child.on('error', error => { console.error(error.message); process.exitCode = 1; });
  child.on('exit', code => { process.exitCode = code || 0; });
}

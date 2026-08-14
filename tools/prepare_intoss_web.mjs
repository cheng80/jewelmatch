import { readFile, writeFile } from 'node:fs/promises';
import { build } from 'esbuild';

const indexPath = 'build/web/index.html';
const bridgeName = 'intoss_ads_bundle.js';

await build({
  entryPoints: ['web/intoss_ads.js'],
  bundle: true,
  format: 'iife',
  outfile: `build/web/${bridgeName}`,
});

const index = await readFile(indexPath, 'utf8');
if (!index.includes(bridgeName)) {
  const bootstrap = '<script src="flutter_bootstrap.js"';
  if (!index.includes(bootstrap)) {
    throw new Error('Flutter bootstrap script was not found');
  }
  await writeFile(
    indexPath,
    index.replace(
      bootstrap,
      `<script src="${bridgeName}"></script>\n  <script src="flutter_bootstrap.js"`,
    ),
  );
}

// Renders art/characters/*.svg to PNG at 3x via headless Chromium (playwright).
// usage: PLAYWRIGHT_PATH=/opt/node-tools/node_modules/playwright node tools/render_svg.mjs <outdir>
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_PATH || 'playwright');
import fs from 'fs';
import path from 'path';
const dir = 'art/characters';
const out = process.argv[2];
fs.mkdirSync(out, { recursive: true });
const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
const page = await browser.newPage({ viewport: { width: 200, height: 240 }, deviceScaleFactor: 3 });
for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.svg'))) {
  const svg = fs.readFileSync(path.join(dir, f), 'utf8');
  await page.setContent(`<html><body style="margin:0;background:#000">${svg}</body></html>`);
  await page.screenshot({ path: path.join(out, f.replace('.svg', '.png')), clip: { x: 0, y: 0, width: 200, height: 240 } });
}
await browser.close();

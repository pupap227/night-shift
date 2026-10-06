// Smoke-test the web build in Chromium with iPhone emulation (touch, DPR 3).
// usage: PLAYWRIGHT_PATH=... node tools/test_web.mjs http://127.0.0.1:8765/ outdir [portrait|landscape]
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_PATH || 'playwright');
const [url, out, orient = 'portrait'] = process.argv.slice(2);
const vp = orient === 'portrait' ? { width: 390, height: 844 } : { width: 844, height: 390 };
const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const ctx = await browser.newContext({ viewport: vp, deviceScaleFactor: 3, isMobile: true, hasTouch: true,
  userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1' });
const page = await ctx.newPage();
const logs = [];
page.on('console', m => logs.push(m.type() + ': ' + m.text()));
page.on('pageerror', e => logs.push('PAGEERROR: ' + e.message));
await page.goto(url);
await page.waitForTimeout(25000);
await page.screenshot({ path: `${out}/web_${orient}_0.png` });
// Tap "НАЧАТЬ СМЕНУ" (bottom area of the title column) with a real touch event.
const tapY = orient === 'portrait' ? 645 : 330;
await page.touchscreen.tap(vp.width / 2, tapY);
await page.waitForTimeout(6000);
await page.screenshot({ path: `${out}/web_${orient}_1.png` });
console.log(logs.filter(l => !l.includes('WebGL')).slice(-25).join('\n'));
await browser.close();

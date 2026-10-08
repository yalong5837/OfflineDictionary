// Renders assets/icon/icon.svg to PNG with Playwright's Chromium:
//   node tools/render_icon.mjs assets/icon/icon.svg assets/icon/icon.png full
//   node tools/render_icon.mjs assets/icon/icon.svg assets/icon/icon_foreground.png foreground
import { chromium } from 'playwright';
import { readFileSync } from 'fs';
const [svgPath, out, mode] = process.argv.slice(2);
let svg = readFileSync(svgPath, 'utf8');
if (mode === 'foreground') {
  // Transparent background, artwork shrunk into Android's adaptive-icon safe zone.
  svg = svg.replace(/<rect id="background"[^>]*\/>/, '')
           .replace('<g id="foreground">', '<g id="foreground" transform="translate(512 512) scale(0.86) translate(-512 -512)">');
}
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1024, height: 1024 } });
await page.setContent(`<html><body style="margin:0;background:transparent">${svg}</body></html>`);
await page.waitForTimeout(300);
await page.screenshot({ path: out, omitBackground: mode === 'foreground', clip: { x: 0, y: 0, width: 1024, height: 1024 } });
await browser.close();

// Renders the PWA's PNG icons from public/icon.svg with Playwright's Chromium (already a dev
// dependency): 192 and 512 for the manifest, a full-bleed 512 maskable one (artwork inside the
// 80 % safe zone), and the 180 px apple-touch-icon. Run: node tools/pwa-icons.mjs
import { readFileSync } from "node:fs";
import { chromium } from "@playwright/test";

const svg = readFileSync("public/icon.svg", "utf8");
const inner = svg.replace(/^<svg[^>]*>/, "").replace(/<\/svg>\s*$/, "");
const maskable = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><rect width="512" height="512" fill="#0f766e"/><g transform="translate(51.2 51.2) scale(0.8)">${inner}</g></svg>`;
// iOS rounds the corners itself and shows transparency as black: a square, full-bleed tile.
const apple = maskable;

const browser = await chromium.launch();
const page = await browser.newPage();
for (const [file, size, art] of [
  ["public/icon-192.png", 192, svg],
  ["public/icon-512.png", 512, svg],
  ["public/icon-maskable-512.png", 512, maskable],
  ["public/apple-touch-icon.png", 180, apple],
]) {
  await page.setViewportSize({ width: size, height: size });
  await page.setContent(`<html><body style="margin:0;background:transparent">${art.replace("<svg ", `<svg width="${size}" height="${size}" `)}</body></html>`);
  await page.screenshot({ path: file, omitBackground: true });
  console.log(file, size);
}
await browser.close();

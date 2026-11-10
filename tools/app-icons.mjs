// Renders the Flutter app's launcher icons and splash art from public/icon.svg (the PWA's icon,
// so web and app look the same), with Playwright's Chromium. Run: node tools/app-icons.mjs
//
// Android: legacy mipmap ic_launcher (the rounded tile), adaptive foreground + monochrome
// (themed icons, Android 13+) with the art inside the 66 dp safe circle, splash art.
// iOS: every size in AppIcon.appiconset, square and opaque (Apple rejects an alpha channel:
// rendered as JPEG, then turned into PNG by sips), and the launch-screen art at 1x/2x/3x.
import { execFileSync } from "node:child_process";
import { readFileSync, rmSync } from "node:fs";
import { chromium } from "@playwright/test";

const TEAL = "#0f766e";
const svg = readFileSync("public/icon.svg", "utf8");
const inner = svg.replace(/^<svg[^>]*>/, "").replace(/<\/svg>\s*$/, "");
const art = inner.replace(/<rect[^>]*\/>/, ""); // the book and "DE", without the tile
// The art spans about x 136–376, y 150–456 (centre 256, 303).
const centred = (s, body) => `<g transform="translate(256 256) scale(${s}) translate(-256 -303)">${body}</g>`;
const doc = (body, viewBox = "0 0 512 512") => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${viewBox}">${body}</svg>`;

const foreground = doc(centred(0.8, art)); // 0.8 × the art's diagonal fits the 66/108 safe circle
const monochrome = doc(centred(0.8, art.replace(/fill="#f4d58d"/, 'fill="#ffffff" fill-opacity="0.6"').replace(/fill="#[0-9a-f]{6}"/g, (m) => (m.includes("0.6") ? m : 'fill="#ffffff"'))));
const iosTile = doc(`<rect width="512" height="512" fill="${TEAL}"/>${inner}`); // iOS rounds the corners itself
const splash = doc(art, "96 143 320 320");

const res = "app/android/app/src/main/res";
const densities = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
const jobs = [];
for (const [d, k] of Object.entries(densities)) {
  jobs.push([`${res}/mipmap-${d}/ic_launcher.png`, 48 * k, svg]);
  jobs.push([`${res}/mipmap-${d}/ic_launcher_foreground.png`, 108 * k, foreground]);
  jobs.push([`${res}/mipmap-${d}/ic_launcher_monochrome.png`, 108 * k, monochrome]);
}
jobs.push([`${res}/drawable-xxxhdpi/splash_art.png`, 480, splash]); // 120 dp; Android scales it down
const launch = "app/ios/Runner/Assets.xcassets/LaunchImage.imageset";
for (const [suffix, k] of [["", 1], ["@2x", 2], ["@3x", 3]]) jobs.push([`${launch}/LaunchImage${suffix}.png`, 120 * k, splash]);

const iconSet = "app/ios/Runner/Assets.xcassets/AppIcon.appiconset";
const ios = JSON.parse(readFileSync(`${iconSet}/Contents.json`, "utf8")).images;
const opaque = new Map();
for (const i of ios) opaque.set(`${iconSet}/${i.filename}`, Math.round(parseFloat(i.size) * parseInt(i.scale)));

const browser = await chromium.launch();
const page = await browser.newPage();
async function render(file, size, body, type) {
  await page.setViewportSize({ width: size, height: size });
  await page.setContent(`<html><body style="margin:0;background:transparent">${body.replace("<svg ", `<svg width="${size}" height="${size}" `)}</body></html>`);
  await page.screenshot({ path: file, type, ...(type === "png" ? { omitBackground: true } : { quality: 100 }) });
}
for (const [file, size, body] of jobs) await render(file, size, body, "png");
for (const [file, size] of opaque) {
  const jpg = file.replace(/\.png$/, ".jpg");
  await render(jpg, size, iosTile, "jpeg");
  execFileSync("sips", ["-s", "format", "png", jpg, "--out", file], { stdio: "ignore" });
  rmSync(jpg);
}
await browser.close();
console.log(`${jobs.length} Android/launch images, ${opaque.size} iOS icons (opaque)`);

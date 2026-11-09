import { expect, test } from "@playwright/test";

test("installable icons: 192 and 512 PNG, a maskable one, and an apple-touch-icon (BUG-12)", async ({ page, request }) => {
  await page.goto("./");
  const manifest = await (await request.get("./manifest.webmanifest")).json();
  const icons = manifest.icons as { src: string; sizes: string; type: string; purpose: string }[];
  for (const size of ["192x192", "512x512"]) expect(icons.some((i) => i.sizes === size && i.type === "image/png")).toBe(true);
  expect(icons.some((i) => i.purpose === "maskable" && i.type === "image/png")).toBe(true);
  const apple = await page.locator('link[rel="apple-touch-icon"]').getAttribute("href");
  for (const src of [...icons.map((i) => i.src), apple!]) {
    const r = await request.get(src);
    expect(r.status(), src).toBe(200);
  }
});

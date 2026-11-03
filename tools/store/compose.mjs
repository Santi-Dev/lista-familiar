// Compone las imágenes del carrusel de la App Store: captura de la app + titular sobre fondo de marca.
// Uso: node compose.mjs [carpetaCapturas=raw] [carpetaSalida=out] [claro|oscuro=claro]
// Entrada: <carpetaCapturas>/<pantalla>-light.png (o -dark.png), tal como las genera el workflow ios-preview
//          con device = "iPhone 17 Pro Max" (1320x2868).
// Salida:  <carpetaSalida>/NN-<pantalla>.jpg a 1320x2868, sin transparencia (requisito de App Store Connect).
import { chromium } from "playwright-core";
import { existsSync, mkdirSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const rawDir = resolve(here, process.argv[2] ?? "raw");
const outDir = resolve(here, process.argv[3] ?? "out");
const mode = (process.argv[4] ?? "claro") === "oscuro" ? "dark" : "light";
const config = JSON.parse(readFileSync(join(here, "store.json"), "utf8"));
mkdirSync(outDir, { recursive: true });

// Navegador instalado en el sistema (Edge en Windows, Chrome si no): no hace falta descargar Chromium.
const candidates = [
  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe",
  "C:/Program Files/Microsoft/Edge/Application/msedge.exe",
  "C:/Program Files/Google/Chrome/Application/chrome.exe",
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/usr/bin/google-chrome",
];
const executablePath = candidates.find(existsSync);
if (!executablePath) throw new Error("No encuentro Edge ni Chrome instalados.");

const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;");

const html = ({ title, subtitle, dataUrl }) => `<!doctype html><html lang="es"><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Nunito:wght@600;800;900&display=swap" rel="stylesheet">
<style>
  :root { --w: ${config.width}px; --h: ${config.height}px; }
  * { box-sizing: border-box; margin: 0; }
  body { width: var(--w); height: var(--h); overflow: hidden; position: relative;
    font-family: "Nunito", ui-rounded, "Segoe UI Variable", system-ui, sans-serif; color: #fff;
    background: radial-gradient(1200px 900px at 85% 8%, rgba(255,255,255,.20), transparent 60%),
                linear-gradient(165deg, #3d9c66 0%, #2E7D4F 48%, #1c573a 100%); }
  .dot { position: absolute; border-radius: 50%; background: rgba(255,255,255,.07); }
  .d1 { width: 760px; height: 760px; left: -280px; top: 1500px; }
  .d2 { width: 520px; height: 520px; right: -200px; top: 560px; background: rgba(224,122,46,.22); }
  header { position: absolute; top: 170px; left: 0; right: 0; padding: 0 96px; text-align: center; }
  h1 { font-size: 118px; line-height: 1.06; font-weight: 900; letter-spacing: -2px; text-wrap: balance; }
  p  { margin-top: 30px; font-size: 54px; line-height: 1.25; font-weight: 600; color: rgba(255,255,255,.88); text-wrap: balance; }
  .phone { position: absolute; left: 160px; top: 800px; width: 1000px; border-radius: 128px; overflow: hidden;
    background: #000; box-shadow: 0 0 0 16px #101010, 0 0 0 20px #3a3a3c, 0 70px 140px rgba(0,0,0,.45); }
  .phone img { display: block; width: 100%; }
</style></head><body>
  <div class="dot d1"></div><div class="dot d2"></div>
  <header><h1>${esc(title)}</h1><p>${esc(subtitle)}</p></header>
  <div class="phone"><img src="${dataUrl}"></div>
</body></html>`;

const browser = await chromium.launch({ executablePath, headless: true });
const page = await browser.newPage({ viewport: { width: config.width, height: config.height }, deviceScaleFactor: 1 });

let n = 0;
for (const slide of config.slides) {
  n += 1;
  const src = join(rawDir, `${slide.screen}-${mode}.png`);
  if (!existsSync(src)) { console.warn(`Falta ${src}, se omite`); continue; }
  const dataUrl = `data:image/png;base64,${readFileSync(src).toString("base64")}`;
  await page.setContent(html({ ...slide, dataUrl }), { waitUntil: "networkidle" });
  await page.evaluate(() => document.fonts.ready);
  const out = join(outDir, `${String(n).padStart(2, "0")}-${slide.screen}.jpg`);
  await page.screenshot({ path: out, type: "jpeg", quality: 96, clip: { x: 0, y: 0, width: config.width, height: config.height } });
  console.log("OK", out);
}
await browser.close();

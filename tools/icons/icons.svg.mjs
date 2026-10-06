import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import { ICONS } from "./icons.defs.mjs";
import { PAL, INK } from "./lib.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "..", "..");
const outPng = path.join(repoRoot, "assets", "ui", "icons.png");
const outLuau = path.join(repoRoot, "src", "client", "Controllers", "UIController", "IconAtlas.luau");
const previewDir =
  process.env.ICON_PREVIEW_DIR ?? "/tmp/claude-0/-home-user-roblox/cfca3bfc-86a9-5332-85e8-d3c4c8004d87/scratchpad";
const cell = 128;
const columns = 8;
const atlasSize = 1024;

const palDefs = Object.entries(PAL)
  .map(
    ([name, [top, mid, bot]]) =>
      `<linearGradient id="${name}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${top}"/><stop offset=".5" stop-color="${mid}"/><stop offset="1" stop-color="${bot}"/></linearGradient>`,
  )
  .join("");

const shades = JSON.stringify(Object.fromEntries(Object.entries(PAL).map(([name, p]) => [name, p[3]])));

const cells = ICONS.map(([name, body], index) => {
  const x = (index % columns) * cell;
  const y = Math.floor(index / columns) * cell;
  return `<g transform="translate(${x} ${y})"><g class="icon" data-name="${name}" filter="url(#drop)">${body}</g></g>`;
}).join("");

const pageScript = `
const NS = "http://www.w3.org/2000/svg";
const SHADES = ${shades};
const defs = document.getElementById("defs");
const mk = (tag) => document.createElementNS(NS, tag);
let count = 0;
function shapeOf(el) {
  const c = el.cloneNode(false);
  for (const a of [...c.attributes]) {
    if (a.name === "class" || a.name === "transform" || a.name.startsWith("data-")) c.removeAttribute(a.name);
  }
  c.removeAttribute("fill");
  c.removeAttribute("stroke");
  const rule = el.getAttribute("fill-rule");
  if (rule) c.setAttribute("clip-rule", rule);
  return c;
}
function gloss(bb, spec) {
  const g = spec ? spec.split(",").map(Number) : [0.28, 0.2, 0.2, 0.08, -28];
  const cx = bb.x + bb.width * g[0];
  const cy = bb.y + bb.height * g[1];
  const rx = Math.max(3, bb.width * g[2]);
  const ry = Math.max(2, bb.height * g[3]);
  const out = mk("g");
  out.setAttribute("class", "gl");
  out.setAttribute("fill", "#fff");
  out.setAttribute("fill-opacity", ".45");
  const e = mk("ellipse");
  e.setAttribute("cx", cx); e.setAttribute("cy", cy); e.setAttribute("rx", rx); e.setAttribute("ry", ry);
  e.setAttribute("transform", "rotate(" + g[4] + " " + cx + " " + cy + ")");
  out.appendChild(e);
  const d = mk("circle");
  d.setAttribute("cx", cx - rx * 0.55);
  d.setAttribute("cy", cy + ry * 2.8);
  d.setAttribute("r", Math.max(1.4, ry * 0.5));
  out.appendChild(d);
  return out;
}
for (const el of [...document.querySelectorAll(".part")]) {
  const id = "cp" + count++;
  const bb = el.getBBox();
  const pal = el.dataset.pal;
  const w = el.dataset.w === undefined ? 7 : Number(el.dataset.w);
  const wrap = mk("g");
  const tr = el.getAttribute("transform");
  if (tr) wrap.setAttribute("transform", tr);
  const cp = mk("clipPath");
  cp.id = id;
  cp.appendChild(shapeOf(el));
  defs.appendChild(cp);
  const inner = mk("g");
  inner.setAttribute("clip-path", "url(#" + id + ")");
  if (!el.dataset.ns) {
    const base = shapeOf(el);
    base.setAttribute("fill", SHADES[pal]);
    inner.appendChild(base);
    const lift = mk("g");
    lift.setAttribute("transform", "translate(0,-5)");
    const top = shapeOf(el);
    top.setAttribute("fill", "url(#" + pal + ")");
    lift.appendChild(top);
    inner.appendChild(lift);
  } else {
    const top = shapeOf(el);
    top.setAttribute("fill", "url(#" + pal + ")");
    inner.appendChild(top);
  }
  if (!el.dataset.ng) inner.appendChild(gloss(bb, el.dataset.g));
  wrap.appendChild(inner);
  if (w > 0) {
    const outline = shapeOf(el);
    outline.removeAttribute("clip-rule");
    const rule = el.getAttribute("fill-rule");
    if (rule) outline.setAttribute("fill-rule", rule);
    outline.setAttribute("fill", "none");
    outline.setAttribute("stroke", "${INK}");
    outline.setAttribute("stroke-width", w);
    outline.setAttribute("stroke-linejoin", "round");
    outline.setAttribute("stroke-linecap", "round");
    wrap.appendChild(outline);
  }
  el.replaceWith(wrap);
}
for (const el of [...document.querySelectorAll(".glossonly")]) {
  const id = "cp" + count++;
  const bb = el.getBBox();
  const cp = mk("clipPath");
  cp.id = id;
  cp.appendChild(shapeOf(el));
  defs.appendChild(cp);
  const inner = mk("g");
  inner.setAttribute("clip-path", "url(#" + id + ")");
  inner.appendChild(gloss(bb, el.dataset.g));
  el.replaceWith(inner);
}
window.applyFits = (fits) => {
  for (const g of document.querySelectorAll(".icon")) {
    const fit = fits[g.dataset.name];
    if (fit) g.setAttribute("transform", "translate(" + fit.tx + " " + fit.ty + ") scale(" + fit.s + ")");
  }
};
`;

const atlasHtml = `<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;background:transparent}svg{display:block}</style></head><body>
<svg xmlns="${"http://www.w3.org/2000/svg"}" width="${atlasSize}" height="${atlasSize}" viewBox="0 0 ${atlasSize} ${atlasSize}">
<defs id="defs">${palDefs}<filter id="drop" x="-20%" y="-20%" width="140%" height="145%"><feDropShadow dx="0" dy="4" stdDeviation="1.6" flood-color="#000" flood-opacity=".26"/></filter></defs>
${cells}
</svg><script>${pageScript}</script></body></html>`;

function writeLuau() {
  let image = "";
  try {
    const existing = fs.readFileSync(outLuau, "utf8").match(/\tImage = "([^"]*)",/);
    if (existing) image = existing[1];
  } catch {}
  const names = ICONS.map(([name]) => name);
  const rects = names
    .map((name, i) => `\t\t${name} = Vector2.new(${(i % columns) * cell}, ${Math.floor(i / columns) * cell}),`)
    .join("\n");
  const source = `--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiAssets = require(ReplicatedStorage.Config.UiAssets)

export type Atlas = {
	Image: string,
	CellSize: number,
	Fallback: string,
	Rects: { [string]: Vector2 },
	Aliases: { [string]: string },
	Has: (name: string) -> boolean,
	Apply: (label: ImageLabel | ImageButton, name: string) -> boolean,
}

local rects = table.freeze({
${rects.replace(/^\t\t/gm, "\t")}
})

local aliases = table.freeze({
	Market = "Shop",
	Trophy = "Leaderboard",
	Coin = "Clicks",
	Flask = "Potion",
	Dice = "Roll",
	Burst = "Fire",
})

local function rectOf(name: string): Vector2?
	return rects[aliases[name] or name]
end

local function apply(label: ImageLabel | ImageButton, name: string): boolean
	local rect = rectOf(name)
	if UiAssets.IconAtlas == "" or rect == nil then
		return false
	end
	local target: any = label
	target.Image = UiAssets.IconAtlas
	target.ImageRectOffset = rect
	target.ImageRectSize = Vector2.new(UiAssets.IconCell, UiAssets.IconCell)
	return true
end

local IconAtlas: Atlas = table.freeze({
	Image = UiAssets.IconAtlas,
	CellSize = UiAssets.IconCell,
	Fallback = "Star",
	Rects = rects,
	Aliases = aliases,
	Has = function(name: string): boolean
		return rectOf(name) ~= nil
	end,
	Apply = apply,
})

return IconAtlas
`;
  fs.writeFileSync(outLuau, source);
}

function loadPlaywright() {
  for (const base of ["/opt/node22/lib/node_modules/", "/opt/node-tools/node_modules/"]) {
    try {
      return createRequire(base)("playwright");
    } catch {}
  }
  return createRequire(import.meta.url)("playwright");
}

async function launch(playwright) {
  const options = { args: ["--no-sandbox", "--allow-file-access-from-files"] };
  try {
    return await playwright.chromium.launch(options);
  } catch {
    return playwright.chromium.launch({ ...options, executablePath: "/opt/pw-browsers/chromium" });
  }
}

const checker =
  "background-color:#d9d9e3;background-image:linear-gradient(45deg,#bfbfd0 25%,transparent 25%,transparent 75%,#bfbfd0 75%),linear-gradient(45deg,#bfbfd0 25%,transparent 25%,transparent 75%,#bfbfd0 75%);background-size:24px 24px;background-position:0 0,12px 12px";

function previewHtml(png) {
  const items = ICONS.map(([name], i) => {
    const x = (i % columns) * cell;
    const y = Math.floor(i / columns) * cell;
    return `<div class="c"><div class="i" style="background-position:-${x}px -${y}px"></div><span>${name}</span></div>`;
  }).join("");
  return `<!doctype html><html><head><meta charset="utf-8"><style>
body{margin:0;${checker};font:600 12px sans-serif;color:#222}
.g{display:grid;grid-template-columns:repeat(${columns},140px);gap:6px;padding:10px;width:max-content}
.c{display:flex;flex-direction:column;align-items:center}
.i{width:128px;height:128px;background-image:url('file://${png}');background-repeat:no-repeat}
</style></head><body><div class="g">${items}</div></body></html>`;
}

function smallHtml(png, size, dark) {
  const items = ICONS.map(([name], i) => {
    const x = ((i % columns) * cell * size) / cell;
    const y = (Math.floor(i / columns) * cell * size) / cell;
    return `<div class="s" style="background-position:-${x}px -${y}px" title="${name}"></div>`;
  }).join("");
  return `<!doctype html><html><head><meta charset="utf-8"><style>
body{margin:0;background:${dark ? "#2a2d3e" : "#f2f2f7"}}
.g{display:grid;grid-template-columns:repeat(11,${size + 8}px);gap:4px;padding:6px;width:max-content}
.s{width:${size}px;height:${size}px;margin:4px;background-image:url('file://${png}');background-size:${(atlasSize * size) / cell}px ${(atlasSize * size) / cell}px;background-repeat:no-repeat}
</style></head><body><div class="g">${items}</div></body></html>`;
}

async function main() {
  fs.mkdirSync(previewDir, { recursive: true });
  const playwright = loadPlaywright();
  const browser = await launch(playwright);
  const htmlPath = path.join(previewDir, "icons-atlas.html");
  fs.writeFileSync(htmlPath, atlasHtml);
  const page = await browser.newPage({ viewport: { width: atlasSize, height: atlasSize }, deviceScaleFactor: 1 });
  page.on("pageerror", (e) => console.error("pageerror", e.message));
  await page.goto(`file://${htmlPath}`);
  const measure = await browser.newPage();
  const probe = async (file) => {
    const target = path.join(previewDir, "icons-probe.html");
    fs.writeFileSync(target, `<canvas id="c"></canvas><img id="i" src="file://${file}">`);
    await measure.goto(`file://${target}`);
    return measure.evaluate(
      async ({ cell, columns, names }) => {
        const img = document.getElementById("i");
        await img.decode();
        const c = document.getElementById("c");
        c.width = img.width;
        c.height = img.height;
        const ctx = c.getContext("2d");
        ctx.drawImage(img, 0, 0);
        return names.map((name, i) => {
          const x0 = (i % columns) * cell;
          const y0 = Math.floor(i / columns) * cell;
          const data = ctx.getImageData(x0, y0, cell, cell).data;
          let minX = cell, minY = cell, maxX = -1, maxY = -1, edge = 0;
          for (let y = 0; y < cell; y += 1) {
            for (let x = 0; x < cell; x += 1) {
              const alpha = data[(y * cell + x) * 4 + 3];
              if (alpha > 200) {
                if (x < minX) minX = x;
                if (x > maxX) maxX = x;
                if (y < minY) minY = y;
                if (y > maxY) maxY = y;
              }
              if (alpha > 6 && (x < 2 || y < 2 || x >= cell - 2 || y >= cell - 2)) edge += 1;
            }
          }
          return { name, minX, minY, maxX: maxX + 1, maxY: maxY + 1, edge };
        });
      },
      { cell, columns, names: ICONS.map(([n]) => n) },
    );
  };
  const raw = path.join(previewDir, "icons-raw.png");
  await page.screenshot({ path: raw, omitBackground: true, clip: { x: 0, y: 0, width: atlasSize, height: atlasSize } });
  const first = await probe(raw);
  const fits = {};
  const limitL = 8, limitT = 8, limitR = 120, limitB = 114;
  for (const b of first) {
    const w = b.maxX - b.minX;
    const h = b.maxY - b.minY;
    const s = Math.min(1, (limitR - limitL) / w, (limitB - limitT) / h);
    const cx = (b.minX + b.maxX) / 2;
    const cy = (b.minY + b.maxY) / 2;
    let nx = cx - (w * s) / 2, ny = cy - (h * s) / 2;
    const dx = Math.max(0, limitL - nx) - Math.max(0, nx + w * s - limitR);
    const dy = Math.max(0, limitT - ny) - Math.max(0, ny + h * s - limitB);
    if (s < 1 || dx !== 0 || dy !== 0) {
      const sx = cx - cx * s + dx;
      const sy = cy - cy * s + dy;
      fits[b.name] = { s, tx: sx, ty: sy };
      console.log(`fit ${b.name} s=${s.toFixed(3)} dx=${dx.toFixed(1)} dy=${dy.toFixed(1)}`);
    }
  }
  await page.evaluate((f) => window.applyFits(f), fits);
  fs.mkdirSync(path.dirname(outPng), { recursive: true });
  await page.screenshot({ path: outPng, omitBackground: true, clip: { x: 0, y: 0, width: atlasSize, height: atlasSize } });
  await page.close();
  writeLuau();

  const shots = [
    ["icons-preview.png", previewHtml(outPng), { width: 8 * 146 + 20, height: 8 * 160 }, 1],
    ["icons-small-light.html", smallHtml(outPng, 40, false), { width: 11 * 56 + 20, height: 6 * 56 + 20 }, 1],
    ["icons-small-dark.html", smallHtml(outPng, 40, true), { width: 11 * 56 + 20, height: 6 * 56 + 20 }, 1],
  ];
  for (const [file, html, viewport, scale] of shots) {
    const p = await browser.newPage({ viewport, deviceScaleFactor: scale });
    const target = path.join(previewDir, file.replace(/\.png$/, ".html"));
    fs.writeFileSync(target, html);
    await p.goto(`file://${target}`);
    await p.screenshot({ path: path.join(previewDir, file.replace(/\.html$/, ".png")) });
    await p.close();
  }
  for (const tone of ["light", "dark"]) {
    const small = path.join(previewDir, `icons-small-${tone}.png`);
    const html = `<!doctype html><html><body style="margin:0;background:#888"><img src="file://${small}" style="image-rendering:pixelated;width:${(11 * 56 + 20) * 3}px;display:block"></body></html>`;
    const target = path.join(previewDir, `icons-zoom-${tone}.html`);
    fs.writeFileSync(target, html);
    const p = await browser.newPage({ viewport: { width: (11 * 56 + 20) * 3, height: (6 * 56 + 20) * 3 } });
    await p.goto(`file://${target}`);
    await p.screenshot({ path: path.join(previewDir, `icons-zoom-${tone}.png`) });
    await p.close();
  }
  const edge = await (async () => {
    const p = await browser.newPage();
    if (true) {
      const res = await probe(outPng);
      await p.close();
      return { size: [atlasSize, atlasSize], bad: res.filter((r) => r.edge > 0).map((r) => r.name) };
    }
    const target = path.join(previewDir, "icons-edge.html");
    fs.writeFileSync(target, `<canvas id="c"></canvas><img id="i" src="file://${outPng}">`);
    await p.goto(`file://${target}`);
    const result = await p.evaluate(
      async ({ cell, columns, names }) => {
        const img = document.getElementById("i");
        await img.decode();
        const c = document.getElementById("c");
        c.width = img.width;
        c.height = img.height;
        const ctx = c.getContext("2d");
        ctx.drawImage(img, 0, 0);
        const bad = [];
        names.forEach((name, i) => {
          const x0 = (i % columns) * cell;
          const y0 = Math.floor(i / columns) * cell;
          const data = ctx.getImageData(x0, y0, cell, cell).data;
          for (let k = 0; k < cell; k += 1) {
            for (const [px, py] of [[k, 0], [k, cell - 1], [0, k], [cell - 1, k], [k, 1], [k, cell - 2], [1, k], [cell - 2, k], [k, 2], [k, cell - 3], [2, k], [cell - 3, k]]) {
              if (data[(py * cell + px) * 4 + 3] > 6) bad.push(name);
            }
          }
        });
        return { size: [img.width, img.height], bad: [...new Set(bad)] };
      },
      { cell, columns, names: ICONS.map(([n]) => n) },
    );
    await p.close();
    return result;
  })();
  console.log("atlas", edge.size.join("x"), "edge-touching:", edge.bad.join(",") || "none");
  await browser.close();
  console.log(`icons: ${ICONS.length}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

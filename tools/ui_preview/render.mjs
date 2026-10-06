import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "..", "..");
const cacheDir = path.join(here, ".cache");
const [jsonDir, pngDir, ...flags] = process.argv.slice(2);
const isDebug = flags.includes("--debug");
const onlyName = flags.find((flag) => !flag.startsWith("--"));

const fontFiles = {
  FredokaOne: ["FredokaOne.ttf", "fredokaone/v15/k3kUo8kEI-tA1RRcTZGmTmHB.ttf"],
  LuckiestGuy: ["LuckiestGuy.ttf", "luckiestguy/v25/_gP_1RrxsjcxVyin9l9n_j2RSg.ttf"],
  Gotham: ["Montserrat800.ttf", "montserrat/v31/JTUHjIg1_i6t8kCHKm4532VJOt5-QNFgpCvr70w-.ttf"],
};

const imageFiles = {
  139344523881737: "assets/ui/pattern.png",
  121612761607168: "assets/ui/burst.png",
};

function ensureFonts() {
  fs.mkdirSync(cacheDir, { recursive: true });
  const faces = [];
  for (const [family, [file, remote]] of Object.entries(fontFiles)) {
    const target = path.join(cacheDir, file);
    if (!fs.existsSync(target)) {
      try {
        execFileSync("curl", ["-sS", "-m", "30", "-f", "-o", target, `https://fonts.gstatic.com/s/${remote}`], {
          stdio: "ignore",
        });
      } catch {
        fs.rmSync(target, { force: true });
      }
    }
    if (fs.existsSync(target)) {
      faces.push(`@font-face{font-family:'${family}';src:url('file://${target}');font-weight:100 900;}`);
    }
  }
  return faces.join("\n");
}

const fontStacks = {
  FredokaOne: "'FredokaOne','Fredoka One','DejaVu Sans',sans-serif",
  LuckiestGuy: "'LuckiestGuy','Luckiest Guy','DejaVu Sans',sans-serif",
  Gotham: "'Gotham','Montserrat','DejaVu Sans',sans-serif",
};

function familyOf(font) {
  if (font === "FredokaOne") return "FredokaOne";
  if (font === "LuckiestGuy") return "LuckiestGuy";
  return "Gotham";
}

function css(color, alpha = 0) {
  const opacity = Math.max(0, Math.min(1, 1 - alpha));
  return `rgba(${color[0]},${color[1]},${color[2]},${+opacity.toFixed(3)})`;
}

function escapeHtml(text) {
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function sample(points, time) {
  if (time <= points[0][0]) return points[0].slice(1);
  for (let index = 1; index < points.length; index += 1) {
    const [t1, ...v1] = points[index];
    const [t0, ...v0] = points[index - 1];
    if (time <= t1) {
      const span = t1 - t0;
      const mix = span <= 1e-6 ? 1 : (time - t0) / span;
      return v0.map((value, i) => value + (v1[i] - value) * mix);
    }
  }
  return points[points.length - 1].slice(1);
}

function gradientCss(gradient, bg, bgAlpha) {
  const times = new Set();
  gradient.colors.forEach((point) => times.add(point[0]));
  gradient.alphas.forEach((point) => times.add(point[0]));
  const ordered = [...times].sort((a, b) => a - b);
  const multiplier = bg ?? [255, 255, 255];
  const stops = ordered.map((time) => {
    const color = sample(gradient.colors, time);
    const alpha = sample(gradient.alphas, time)[0];
    const merged = 1 - (1 - bgAlpha) * (1 - alpha);
    const rgb = color.map((value, i) => Math.round((value * multiplier[i]) / 255));
    return `${css(rgb, merged)} ${+(time * 100).toFixed(2)}%`;
  });
  return `linear-gradient(${gradient.rotation + 90}deg,${stops.join(",")})`;
}

function strokeShadow(stroke) {
  const color = stroke.gradient ? stroke.gradient.colors[0].slice(1) : stroke.color;
  return `0 0 0 ${stroke.thickness}px ${css(color, stroke.alpha)}`;
}

function textShadow(stroke) {
  const radius = stroke.thickness;
  const count = Math.max(12, Math.ceil(radius * 8));
  const color = css(stroke.color, stroke.alpha);
  const shadows = [];
  for (const ring of [1, 0.55]) {
    for (let index = 0; index < count; index += 1) {
      const angle = (index / count) * Math.PI * 2;
      shadows.push(`${(Math.cos(angle) * radius * ring).toFixed(2)}px ${(Math.sin(angle) * radius * ring).toFixed(2)}px 0 ${color}`);
    }
  }
  return shadows.join(",");
}

function imageUrl(id) {
  const match = /(\d+)/.exec(id);
  const file = match ? imageFiles[match[1]] : null;
  return file ? `file://${path.join(repoRoot, file)}` : null;
}

const justify = { Top: "flex-start", Center: "center", Bottom: "flex-end" };
const items = { Left: "flex-start", Center: "center", Right: "flex-end" };

function arr(value) {
  return Array.isArray(value) ? value : [];
}

function kids(node) {
  const value = node.children;
  return Array.isArray(value) ? value : [];
}

function renderNode(node) {
  const style = [
    `left:${node.x}px`,
    `top:${node.y}px`,
    `width:${node.w}px`,
    `height:${node.h}px`,
    `z-index:${node.z}`,
  ];
  if (node.rot) style.push(`transform:rotate(${node.rot}deg)`);
  if (node.clip) style.push("overflow:hidden");
  if (node.corner) style.push(`border-radius:${node.corner}px`);
  const shadows = [];
  if (node.border) shadows.push(`0 0 0 ${node.border.size}px ${css(node.border.color)}`);
  for (const stroke of arr(node.strokes)) shadows.push(strokeShadow(stroke));
  if (node.bg || node.gradient) {
    const bgAlpha = node.bgAlpha ?? 0;
    if (node.gradient && node.text && !node.bg) {
    } else if (node.gradient) {
      style.push(`background:${gradientCss(node.gradient, node.bg, bgAlpha)}`);
    } else {
      style.push(`background:${css(node.bg, bgAlpha)}`);
    }
  }
  if (shadows.length) style.push(`box-shadow:${shadows.join(",")}`);
  const classes = ["n"];
  if (isDebug && node.text && node.text.overflow) classes.push("overflow");
  const inner = [];
  if (node.image) {
    const url = imageUrl(node.image.id);
    const opacity = 1 - node.image.alpha;
    const tint = node.image.color;
    const isWhite = tint[0] === 255 && tint[1] === 255 && tint[2] === 255;
    let size = "100% 100%";
    let repeat = "no-repeat";
    if (node.image.scaleType === "Tile") {
      size = `${node.image.tileW}px ${node.image.tileH}px`;
      repeat = "repeat";
    } else if (node.image.scaleType === "Fit") {
      size = "contain";
    } else if (node.image.scaleType === "Crop") {
      size = "cover";
    }
    const isAtlas = typeof node.image.id === "string" && (node.image.id.includes("preview-atlas") || node.image.id.includes("103213574924512"));
    if (isAtlas) {
      const atlasUrl = `file://${path.join(repoRoot, "assets/ui/icons.png")}`;
      const rw = node.image.rectW || 1024;
      const rh = node.image.rectH || 1024;
      const sx = node.w / rw;
      const sy = node.h / rh;
      const geometry = `${(1024 * sx).toFixed(2)}px ${(1024 * sy).toFixed(2)}px`;
      const position = `${(-(node.image.rectX || 0) * sx).toFixed(2)}px ${(-(node.image.rectY || 0) * sy).toFixed(2)}px`;
      const rounding = node.corner ? `;border-radius:${node.corner}px` : "";
      const picture = `position:absolute;inset:0;background:url('${atlasUrl}') ${position}/${geometry} no-repeat${rounding}`;
      const tinted = isWhite
        ? ""
        : `<div style="position:absolute;inset:0;mix-blend-mode:multiply;background-color:${css(tint)};-webkit-mask:url('${atlasUrl}') ${position}/${geometry} no-repeat;mask:url('${atlasUrl}') ${position}/${geometry} no-repeat"></div>`;
      inner.push(`<div style="position:absolute;inset:0;isolation:isolate;opacity:${opacity}"><div style="${picture}"></div>${tinted}</div>`);
    } else if (url) {
      const layer = [
        "position:absolute;inset:0",
        `opacity:${opacity}`,
        isWhite
          ? `background:url('${url}') center/${size} ${repeat}`
          : `background-color:${css(tint)};-webkit-mask:url('${url}') center/${size} ${repeat};mask:url('${url}') center/${size} ${repeat}`,
      ];
      if (node.corner) layer.push(`border-radius:${node.corner}px`);
      inner.push(`<div style="${layer.join(";")}"></div>`);
    } else {
      inner.push(`<div class="missing">image</div>`);
    }
  }
  if (node.text) {
    const text = node.text;
    const family = familyOf(text.font);
    const body = text.rich ? text.lines.join("<br>") : escapeHtml(text.lines.join("\n"));
    const shadow = text.stroke ? `text-shadow:${textShadow(text.stroke)};` : "";
    const layer = [
      "position:absolute",
      `left:${text.padL}px`,
      `right:${text.padR}px`,
      `top:${text.padT}px`,
      `bottom:${text.padB}px`,
      "display:flex",
      "flex-direction:column",
      `justify-content:${justify[text.yAlign] ?? "center"}`,
      `align-items:${items[text.xAlign] ?? "center"}`,
      `text-align:${text.xAlign.toLowerCase()}`,
      "white-space:pre",
      `font-family:${fontStacks[family]}`,
      `font-size:${text.size}px`,
      `line-height:${text.size}px`,
      `color:${css(text.color, text.alpha)}`,
      shadow,
    ];
    inner.push(`<div style="${layer.join(";")}">${body}</div>`);
  }
  for (const child of kids(node)) inner.push(renderNode(child));
  if (node.scroll && node.scroll.needsY && node.scroll.thickness > 0) {
    const ratio = node.h / node.scroll.canvasH;
    const bar = [
      "position:absolute",
      `right:0`,
      `width:${node.scroll.thickness}px`,
      `top:${(node.scroll.posY * ratio).toFixed(1)}px`,
      `height:${(node.h * ratio).toFixed(1)}px`,
      `border-radius:${node.scroll.thickness}px`,
      `background:${css(node.scroll.color, 0.1)}`,
      "z-index:9999",
    ];
    inner.push(`<div style="${bar.join(";")}"></div>`);
  }
  if (node.scroll && node.scroll.needsX && node.scroll.thickness > 0) {
    const ratio = node.w / node.scroll.canvasW;
    const bar = [
      "position:absolute",
      "bottom:0",
      `height:${node.scroll.thickness}px`,
      `left:${(node.scroll.posX * ratio).toFixed(1)}px`,
      `width:${(node.w * ratio).toFixed(1)}px`,
      `border-radius:${node.scroll.thickness}px`,
      `background:${css(node.scroll.color, 0.1)}`,
      "z-index:9999",
    ];
    inner.push(`<div style="${bar.join(";")}"></div>`);
  }
  return `<div class="${classes.join(" ")}" data-name="${escapeHtml(node.name)}" style="${style.join(";")}">${inner.join("")}</div>`;
}

function renderPage(scene, fontFaces) {
  const guis = arr(scene.guis)
    .map((gui, index) => {
      const body = kids(gui).map(renderNode).join("");
      return `<div class="gui" data-gui="${gui.name}" style="top:${gui.inset}px;width:${gui.w}px;height:${gui.h}px;z-index:${index + 1}">${body}</div>`;
    })
    .join("");
  return `<!doctype html><html><head><meta charset="utf-8"><style>
${fontFaces}
html,body{margin:0;padding:0;background:#000}
#screen{position:relative;width:${scene.width}px;height:${scene.height}px;overflow:hidden;background:linear-gradient(180deg,#8fd0f4 0%,#c7ecff 38%,#9ed17a 38.2%,#6fb85a 100%)}
.decor{position:absolute;border-radius:50%;background:rgba(255,255,255,.55)}
.ground{position:absolute;left:0;right:0;top:44%;bottom:0;background:repeating-linear-gradient(90deg,rgba(0,0,0,.05) 0 80px,rgba(0,0,0,0) 80px 160px)}
.topbar{position:absolute;left:0;top:0;right:0;height:36px;background:rgba(20,22,28,.92);z-index:0}
.topbar i{position:absolute;top:6px;width:24px;height:24px;border-radius:50%;background:#5b6070}
.gui{position:absolute;left:0;overflow:hidden}
.n{position:absolute;box-sizing:border-box}
.missing{position:absolute;inset:0;background:repeating-linear-gradient(45deg,#d0d,#d0d 6px,#222 6px,#222 12px);opacity:.5;color:#fff;font:10px sans-serif}
.overflow{outline:2px dashed #ff2d2d;outline-offset:1px}
</style></head><body><div id="screen"><div class="ground"></div><div class="decor" style="left:90px;top:70px;width:180px;height:50px"></div><div class="decor" style="left:900px;top:110px;width:220px;height:60px"></div><div class="topbar"><i style="left:10px"></i><i style="left:44px"></i></div>${guis}</div></body></html>`;
}

async function main() {
  const globalRequire = createRequire("/opt/node22/lib/node_modules/");
  let playwright;
  try {
    playwright = globalRequire("playwright");
  } catch {
    playwright = createRequire(import.meta.url)("playwright");
  }
  const fontFaces = ensureFonts();
  fs.mkdirSync(pngDir, { recursive: true });
  const files = fs.readdirSync(jsonDir).filter((file) => file.endsWith(".json"));
  const launch = { args: ["--no-sandbox", "--font-render-hinting=none", "--allow-file-access-from-files"] };
  const defaultPath = "/opt/pw-browsers/chromium";
  let browser;
  try {
    browser = await playwright.chromium.launch(launch);
  } catch {
    browser = await playwright.chromium.launch({ ...launch, executablePath: defaultPath });
  }
  const htmlDir = path.join(jsonDir, "html");
  fs.mkdirSync(htmlDir, { recursive: true });
  for (const file of files) {
    const name = file.replace(/\.json$/, "");
    if (onlyName && onlyName !== name) continue;
    const scene = JSON.parse(fs.readFileSync(path.join(jsonDir, file), "utf8"));
    const htmlPath = path.join(htmlDir, `${name}.html`);
    fs.writeFileSync(htmlPath, renderPage(scene, fontFaces));
    const page = await browser.newPage({ viewport: { width: scene.width, height: scene.height } });
    await page.goto(`file://${htmlPath}`);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: path.join(pngDir, `${name}.png`) });
    await page.close();
    const overflowing = countOverflow(scene);
    console.log(`rendered ${name}${overflowing ? ` (text overflow: ${overflowing})` : ""}`);
  }
  await browser.close();
}

function countOverflow(scene) {
  let total = 0;
  const walk = (node) => {
    if (node.text && node.text.overflow) total += 1;
    kids(node).forEach(walk);
  };
  arr(scene.guis).forEach((gui) => kids(gui).forEach(walk));
  return total;
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

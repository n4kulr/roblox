export const INK = "#1A1530";

export const PAL = {
  cream: ["#FFFFFF", "#FFF7E2", "#EBDCB6", "#C9B88E"],
  tan: ["#F6E9C9", "#E2D0A4", "#C4AD7C", "#9C8858"],
  green: ["#C8FA7A", "#5DDB4A", "#25A844", "#167A30"],
  lime: ["#E4FF8A", "#A6EC3C", "#5CBF2A", "#3C8F1C"],
  blue: ["#9BE0FF", "#3F95F2", "#2557D6", "#173F9C"],
  sky: ["#D6F6FF", "#7ED2F7", "#35A3E8", "#1E78BE"],
  navy: ["#6C7CF0", "#3E48C8", "#2A2C93", "#1D1E6C"],
  red: ["#FF9494", "#F2394C", "#C21C3C", "#8E1230"],
  pink: ["#FFB2E8", "#F466C9", "#C73AB2", "#8F2688"],
  purple: ["#D7A4FF", "#A45CEE", "#6F36CC", "#4C2394"],
  gold: ["#FFF59A", "#FFCB2E", "#F29A0E", "#BE6C06"],
  yellow: ["#FFFBB0", "#FFE23A", "#FFB814", "#D88808"],
  orange: ["#FFC68A", "#FF8E2C", "#E5601A", "#A83E10"],
  brown: ["#E0A468", "#B26A32", "#7F441C", "#59300F"],
  gray: ["#F1F4FB", "#B9C2DB", "#7683A6", "#525E80"],
  dark: ["#8A90B4", "#575C82", "#34365A", "#222440"],
  glass: ["#FFFFFF", "#DDF4FF", "#A8DDF5", "#78BCE0"],
  skin: ["#FFE8C8", "#FFCB92", "#EBA25E", "#C27A38"],
  white: ["#FFFFFF", "#FFFFFF", "#E4EAF6", "#BFC8DE"],
};

export const f = (n) => +n.toFixed(2);
export const pol = (cx, cy, r, a) => [cx + r * Math.cos((a * Math.PI) / 180), cy + r * Math.sin((a * Math.PI) / 180)];
export const poly = (pts) => `M${pts.map((p) => `${f(p[0])} ${f(p[1])}`).join("L")}Z`;
export const rotPts = (pts, cx, cy, a) =>
  pts.map(([x, y]) => {
    const r = (a * Math.PI) / 180;
    const dx = x - cx;
    const dy = y - cy;
    return [cx + dx * Math.cos(r) - dy * Math.sin(r), cy + dx * Math.sin(r) + dy * Math.cos(r)];
  });

export const path = (d) => `<path d="${d}"/>`;
export const polyEl = (pts) => path(poly(pts));
export const rect = (x, y, w, h, r = 0) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}"/>`;
export const circ = (cx, cy, r) => `<circle cx="${cx}" cy="${cy}" r="${r}"/>`;
export const ell = (cx, cy, rx, ry, rot = 0) =>
  `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}"${rot ? ` transform="rotate(${rot} ${cx} ${cy})"` : ""}/>`;

export function P(shape, pal, o = {}) {
  let attrs = `class="part" data-pal="${pal}"`;
  if (o.w !== undefined) attrs += ` data-w="${o.w}"`;
  if (o.g) attrs += ` data-g="${o.g.join(",")}"`;
  if (o.ng) attrs += ` data-ng="1"`;
  if (o.ns) attrs += ` data-ns="1"`;
  if (o.rule) attrs += ` fill-rule="evenodd"`;
  return shape.replace(/^<(\w+)/, `<$1 ${attrs}`);
}

export function GL(shape, g) {
  return shape.replace(/^<(\w+)/, `<$1 class="glossonly" data-g="${g.join(",")}"`);
}

export const ln = (d, w = 5, color = INK) =>
  `<path d="${d}" fill="none" stroke="${color}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>`;
export const tube = (d, w, color, rim = 5) => ln(d, w + rim * 2, INK) + ln(d, w, color);
export const fillOnly = (shape, fill, extra = "") => shape.replace(/^<(\w+)/, `<$1 fill="${fill}" ${extra}`);
export const O = (shape, fill, w = 4, stroke = INK) =>
  shape.replace(
    /^<(\w+)/,
    `<$1 fill="${fill}" stroke="${stroke}" stroke-width="${w}" stroke-linejoin="round" stroke-linecap="round"`,
  );
export const S = (shape, w = 7, stroke = INK) =>
  shape.replace(
    /^<(\w+)/,
    `<$1 fill="none" stroke="${stroke}" stroke-width="${w}" stroke-linejoin="round" stroke-linecap="round"`,
  );
export const grad = (shape, pal, w = 4) =>
  shape.replace(
    /^<(\w+)/,
    `<$1 fill="url(#${pal})" stroke="${INK}" stroke-width="${w}" stroke-linejoin="round" stroke-linecap="round"`,
  );

let clipCount = 0;
export function clip(shape, inner) {
  const id = `uc${clipCount++}`;
  return `<clipPath id="${id}">${shape}</clipPath><g clip-path="url(#${id})">${inner}</g>`;
}

export function starPts(cx, cy, R, r, n = 5, rot = -90) {
  const pts = [];
  for (let i = 0; i < n * 2; i += 1) {
    pts.push(pol(cx, cy, i % 2 === 0 ? R : r, rot + (i * 180) / n));
  }
  return pts;
}

export function sparkle(cx, cy, R, k = 0.2) {
  const c = R * k;
  return path(
    `M${cx} ${cy - R}Q${cx + c} ${cy - c} ${cx + R} ${cy}Q${cx + c} ${cy + c} ${cx} ${cy + R}Q${cx - c} ${cy + c} ${cx - R} ${cy}Q${cx - c} ${cy - c} ${cx} ${cy - R}Z`,
  );
}

export function ringArrow(cx, cy, r1, r2, a0, a1, head, spread) {
  const rm = (r1 + r2) / 2;
  const n = 28;
  const end = a1 - head;
  const pts = [];
  for (let i = 0; i <= n; i += 1) pts.push(pol(cx, cy, r1, a0 + ((end - a0) * i) / n));
  pts.push(pol(cx, cy, r1 + spread, end));
  pts.push(pol(cx, cy, rm, a1));
  pts.push(pol(cx, cy, r2 - spread, end));
  for (let i = n; i >= 0; i -= 1) pts.push(pol(cx, cy, r2, a0 + ((end - a0) * i) / n));
  return polyEl(pts);
}

export const CHECK = [
  [-28, 2],
  [-17, -9],
  [-6, 2],
  [21, -25],
  [32, -14],
  [-6, 24],
];

export function checkPts(cx, cy, s = 1) {
  return CHECK.map(([x, y]) => [cx + x * s, cy + y * s]);
}

export function plusPts(cx, cy, L, t, rot = 0) {
  const pts = [
    [-t, -L], [t, -L], [t, -t], [L, -t], [L, t], [t, t],
    [t, L], [-t, L], [-t, t], [-L, t], [-L, -t], [-t, -t],
  ].map(([x, y]) => [cx + x, cy + y]);
  return rot ? rotPts(pts, cx, cy, rot) : pts;
}

export function hexPts(cx, cy, R, rot = -90) {
  const pts = [];
  for (let i = 0; i < 6; i += 1) pts.push(pol(cx, cy, R, rot + i * 60));
  return pts;
}

export function gearPath(cx, cy, teeth, ro, ri, hole) {
  const pts = [];
  const step = 360 / teeth;
  for (let i = 0; i < teeth; i += 1) {
    const a = -90 + i * step;
    pts.push(pol(cx, cy, ri, a - step * 0.3));
    pts.push(pol(cx, cy, ro, a - step * 0.17));
    pts.push(pol(cx, cy, ro, a + step * 0.17));
    pts.push(pol(cx, cy, ri, a + step * 0.3));
  }
  const outer = poly(pts);
  const h = `M${cx + hole} ${cy}A${hole} ${hole} 0 1 0 ${cx - hole} ${cy}A${hole} ${hole} 0 1 0 ${cx + hole} ${cy}Z`;
  return path(outer + h);
}

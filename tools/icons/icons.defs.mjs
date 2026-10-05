import {
  INK, P, ln, tube, O, S, grad, clip, path, polyEl, rect, circ, ell, starPts, sparkle, ringArrow,
  checkPts, plusPts, hexPts, gearPath, rotPts, fillOnly, GL,
} from "./lib.mjs";

const keycap = (x, y, w, h, base = "tan", top = "cream", inset = 6, rise = 8) =>
  P(rect(x, y + rise, w, h - rise, 18), base) +
  P(rect(x + inset, y, w - inset * 2, h - rise - 8, 14), top);

const letterA = (cx, cy, s = 1, w = 9) =>
  ln(`M${cx - 17 * s} ${cy + 17 * s}L${cx} ${cy - 18 * s}L${cx + 17 * s} ${cy + 17 * s}M${cx - 9 * s} ${cy + 4 * s}H${cx + 9 * s}`, w * s);

const leaf = (angle, cx, cy, s, off = 0) => {
  const raw = [
    [0, 0], [-8, -8], [-26, -18], [-26, -36], [-26, -50], [-8, -56], [0, -40],
    [8, -56], [26, -50], [26, -36], [26, -18], [8, -8], [0, 0],
  ].map(([x, y]) => [cx + x * s, cy + y * s - off]);
  const p = rotPts(raw, cx, cy, angle);
  const q = (i) => `${p[i][0].toFixed(2)} ${p[i][1].toFixed(2)}`;
  return `M${q(0)}C${q(1)} ${q(2)} ${q(3)}C${q(4)} ${q(5)} ${q(6)}C${q(7)} ${q(8)} ${q(9)}C${q(10)} ${q(11)} ${q(12)}Z`;
};

const veinOf = (angle, cx, cy, s, off = 0) => {
  const p = rotPts([[cx, cy - 6 * s - off], [cx, cy - 36 * s - off]], cx, cy, angle);
  return `M${p[0][0].toFixed(2)} ${p[0][1].toFixed(2)}L${p[1][0].toFixed(2)} ${p[1][1].toFixed(2)}`;
};

const person = (cx, headY, s, bodyPal, skinPal = "skin") =>
  P(path(`M${cx - 26 * s} 114V${98 - (1 - s) * 30}Q${cx - 26 * s} ${headY + 26 * s} ${cx} ${headY + 26 * s}Q${cx + 26 * s} ${headY + 26 * s} ${cx + 26 * s} ${98 - (1 - s) * 30}V114Z`), bodyPal) +
  P(circ(cx, headY, 17 * s), skinPal);

const coinStack = (cx, cy) =>
  P(path(`M${cx - 38} ${cy}V${cy + 13}A38 14 0 0 0 ${cx + 38} ${cy + 13}V${cy}A38 14 0 0 1 ${cx - 38} ${cy}Z`), "orange", { ng: true, w: 5 }) +
  P(ell(cx, cy, 38, 14), "gold", { w: 5, g: [0.3, 0.3, 0.2, 0.14, -12] }) +
  S(ell(cx, cy, 25, 8), 3.5, "#C9780A");

const shopStripe = (i) => {
  const n = 6;
  const tw = 84 / n;
  const bw = 104 / n;
  const tx = 22 + i * tw;
  const bx = 12 + i * bw;
  return P(
    path(`M${tx} 20L${tx + tw} 20L${bx + bw} 52Q${bx + bw / 2} 66 ${bx} 52Z`),
    i % 2 === 0 ? "red" : "cream",
    { w: 5, g: [0.3, 0.2, 0.22, 0.1, -20] },
  );
};

const brickRows = () => {
  let out = "";
  for (let row = 0; row < 4; row += 1) {
    const y = 24 + row * 21;
    const odd = row % 2 === 1;
    const xs = odd
      ? [[18, 12], [34, 28], [66, 28], [98, 12]]
      : [[18, 28], [50, 28], [82, 28]];
    for (const [x, w] of xs) out += O(rect(x, y, w, 17, 4), "url(#orange)", 3.5);
  }
  return out;
};

const kbKeys = () => {
  let out = "";
  const rows = [
    { y: 40, count: 5, color: "cream" },
    { y: 59, count: 4, color: "cream" },
  ];
  for (const row of rows) {
    const total = row.count * 15 + (row.count - 1) * 4;
    const x0 = 64 - total / 2;
    for (let i = 0; i < row.count; i += 1) {
      const accent = row.y === 40 && i === 4 ? "sky" : row.y === 59 && i === 0 ? "pink" : row.color;
      out += O(rect(x0 + i * 19, row.y, 15, 15, 4), `url(#${accent})`, 3);
    }
  }
  out += O(rect(34, 78, 60, 15, 5), "url(#cream)", 3);
  return out;
};

export const ICONS = [
  [
    "Keys",
    keycap(12, 16, 104, 98, "tan", "cream", 10, 14) + letterA(64, 50, 1.05, 9.5),
  ],
  [
    "Upgrades",
    P(polyEl([[64, 52], [116, 92], [116, 114], [64, 74], [12, 114], [12, 92]]), "green") +
      P(polyEl([[64, 12], [116, 52], [116, 74], [64, 34], [12, 74], [12, 52]]), "lime"),
  ],
  [
    "Index",
    P(rect(26, 20, 90, 96, 10), "cream") +
      P(rect(12, 10, 94, 100, 14), "blue") +
      ln("M34 16V104", 4, "#173F9C") +
      keycap(46, 32, 48, 46, "tan", "cream", 6, 8) +
      letterA(70, 50, 0.4, 9) +
      P(path("M82 10V34L90 28L98 34V10Z"), "red", { w: 4, ng: true }),
  ],
  [
    "Rebirth",
    P(ringArrow(64, 64, 45, 21, 205, 345, 40, 9), "pink") +
      P(ringArrow(64, 64, 45, 21, 25, 165, 40, 9), "purple"),
  ],
  [
    "Daily",
    P(rect(14, 22, 100, 92, 16), "cream") +
      P(path("M14 54V38Q14 22 30 22H98Q114 22 114 38V54Z"), "red") +
      P(rect(34, 8, 12, 24, 6), "gray", { w: 5, ng: true }) +
      P(rect(82, 8, 12, 24, 6), "gray", { w: 5, ng: true }) +
      P(polyEl(checkPts(64, 82, 0.95)), "green", { w: 5 }),
  ],
  [
    "Gift",
    P(rect(18, 54, 92, 60, 10), "red") +
      P(rect(54, 54, 20, 60), "gold", { w: 5, ng: true }) +
      P(rect(12, 36, 104, 26, 9), "red", { g: [0.25, 0.3, 0.16, 0.2, 0] }) +
      P(rect(54, 36, 20, 26), "gold", { w: 5, ng: true }) +
      P(path("M64 36C36 40 20 26 32 14C44 4 62 20 64 36Z"), "gold", { w: 5 }) +
      P(path("M64 36C92 40 108 26 96 14C84 4 66 20 64 36Z"), "gold", { w: 5 }) +
      P(circ(64, 36, 8), "yellow", { w: 5 }),
  ],
  [
    "Store",
    tube("M44 48V36Q44 14 64 14Q84 14 84 36V48", 8, "#F5EEDD", 5) +
      P(path("M22 42H106L112 106Q112 116 102 116H26Q16 116 16 106Z"), "red") +
      P(polyEl(starPts(64, 82, 22, 10)), "gold", { w: 5 }),
  ],
  [
    "Leaderboard",
    tube("M34 28H20Q16 54 40 62", 6, "#F5B516", 5) +
      tube("M94 28H108Q112 54 88 62", 6, "#F5B516", 5) +
      P(rect(54, 78, 20, 24), "orange", { w: 6, ng: true }) +
      P(rect(32, 98, 64, 18, 7), "orange", { w: 6 }) +
      P(path("M32 14H96V48Q96 84 64 88Q32 84 32 48Z"), "gold") +
      P(polyEl(starPts(64, 48, 17, 8)), "cream", { w: 4, ng: true }),
  ],
  [
    "Pass",
    `<g transform="rotate(-9 64 64)">` +
      P(path("M12 36Q12 28 20 28H108Q116 28 116 36V54A10 10 0 0 0 116 74V92Q116 100 108 100H20Q12 100 12 92V74A10 10 0 0 0 12 54Z"), "orange") +
      ln("M92 36V46M92 56V72M92 82V92", 4, "#8E3A10") +
      P(polyEl(starPts(52, 64, 24, 11)), "yellow", { w: 5 }) +
      `</g>`,
  ],
  [
    "Shop",
    P(rect(18, 50, 92, 64, 8), "brown") +
      P(rect(10, 92, 108, 16, 7), "tan", { w: 6 }) +
      keycap(44, 66, 40, 34, "tan", "cream", 5, 6) +
      [0, 1, 2, 3, 4, 5].map(shopStripe).join(""),
  ],
  [
    "Home",
    P(rect(82, 18, 16, 36, 4), "brown", { w: 6, ng: true }) +
      P(rect(22, 52, 84, 62, 8), "cream") +
      P(path("M64 10L120 58H8Z"), "red", { w: 8 }) +
      P(path("M52 114V86Q52 76 62 76Q72 76 72 86V114Z"), "brown", { w: 5 }) +
      P(rect(80, 70, 18, 18, 4), "sky", { w: 5 }),
  ],
  [
    "Settings",
    P(gearPath(64, 64, 8, 52, 38, 17), "gray", { rule: true, g: [0.3, 0.2, 0.2, 0.08, -28] }),
  ],
  [
    "Roll",
    keycap(10, 30, 92, 86, "orange", "yellow", 8, 12) +
      [[34, 46], [70, 46], [34, 74], [70, 74], [52, 60]].map(([x, y]) => fillOnly(circ(x, y, 6.5), INK)).join("") +
      P(sparkle(102, 30, 22, 0.16), "white", { w: 5, ng: true }),
  ],
  [
    "Auto",
    P(ringArrow(64, 64, 46, 24, -70, 225, 52, 12), "blue") +
      P(polyEl([[58, 48], [58, 80], [84, 64]]), "cream", { w: 5, ng: true }),
  ],
  [
    "Golden",
    P(polyEl(starPts(62, 68, 52, 25)), "gold", { w: 7, g: [0.3, 0.3, 0.14, 0.08, -35] }) +
      P(sparkle(108, 22, 14, 0.2), "white", { w: 4, ng: true }) +
      P(sparkle(18, 30, 9, 0.2), "white", { w: 3.5, ng: true }),
  ],
  [
    "Clicks",
    P(circ(64, 64, 52), "gold") +
      S(circ(64, 64, 39), 4, "#D68A0A") +
      O(rect(40, 58, 48, 34, 9), "#E5A416", 3, "#B8700A") +
      O(rect(46, 40, 36, 40, 8), "#FFE680", 3, "#B8700A") +
      ln("M54 66L64 46L74 66M58 60H70", 5, "#B8700A"),
  ],
  [
    "Luck",
    tube("M64 68C62 88 60 104 76 114", 7, "#2E9B3A", 5) +
      [45, 135, 225, 315].map((a) => P(path(leaf(a, 64, 62, 1.1, 5)), "green", { w: 6, g: [0.3, 0.28, 0.22, 0.1, -20] })).join("") +
      [45, 135, 225, 315].map((a) => ln(veinOf(a, 64, 62, 1.1, 5), 3.5, "#D4FA8C")).join("") +
      P(circ(64, 62, 9), "lime", { w: 5, g: [0.3, 0.3, 0.25, 0.2, -20] }) +
      P(sparkle(106, 26, 14, 0.2), "white", { w: 4, ng: true }) +
      P(sparkle(20, 104, 9, 0.2), "white", { w: 3.5, ng: true }),
  ],
  [
    "Speed",
    P(polyEl([[70, 8], [92, 8], [74, 46], [102, 46], [44, 120], [54, 68], [26, 68]]), "yellow", { w: 7, g: [0.4, 0.2, 0.12, 0.07, -50] }),
  ],
  [
    "Slots",
    P(rect(10, 30, 108, 70, 14), "gray") + kbKeys(),
  ],
  [
    "Income",
    coinStack(61, 88) + coinStack(67, 68) + coinStack(61, 48) + coinStack(66, 28),
  ],
  [
    "Walls",
    P(rect(12, 18, 104, 92, 12), "tan", { ng: true, ns: true, w: 0 }) + brickRows() + S(rect(12, 18, 104, 92, 12), 7) + GL(rect(12, 18, 104, 92, 12), [0.25, 0.14, 0.2, 0.05, -4]),
  ],
  [
    "LockTime",
    P(path("M64 10L108 26V58Q108 94 64 118Q20 94 20 58V26Z"), "red") +
      ln("M36 62H92", 14, "#FF9A3C") +
      ln("M36 62H92", 8, "#FFF3A0") +
      P(sparkle(64, 62, 14, 0.2), "white", { w: 0, ng: true, ns: true }) +
      P(circ(32, 62, 11), "dark", { w: 5, g: [0.35, 0.3, 0.2, 0.15, 0] }) +
      P(circ(96, 62, 11), "dark", { w: 5, g: [0.35, 0.3, 0.2, 0.15, 0] }) +
      P(circ(32, 62, 4), "red", { w: 0, ng: true, ns: true }) +
      P(circ(96, 62, 4), "red", { w: 0, ng: true, ns: true }),
  ],
  [
    "Lock",
    tube("M42 58V40Q42 14 64 14Q86 14 86 40V58", 10, "#C8D0E6", 5) +
      P(rect(22, 54, 84, 62, 16), "gold") +
      fillOnly(circ(64, 80, 9), INK) +
      fillOnly(rect(60, 82, 8, 18, 3), INK),
  ],
  [
    "Unlock",
    tube("M42 58V40Q42 14 64 14Q86 14 86 38V44", 10, "#C8D0E6", 5) +
      P(rect(22, 54, 84, 62, 16), "green") +
      fillOnly(circ(64, 80, 9), INK) +
      fillOnly(rect(60, 82, 8, 18, 3), INK),
  ],
  [
    "Trade",
    P(polyEl([[12, 25], [76, 25], [76, 12], [116, 36], [76, 60], [76, 47], [12, 47]]), "green") +
      P(polyEl([[116, 81], [52, 81], [52, 68], [12, 92], [52, 116], [52, 103], [116, 103]]), "orange"),
  ],
  [
    "Sound",
    tube("M92 46Q106 64 92 82", 6, "#7FD3FF", 5) +
      tube("M104 30Q128 64 104 98", 6, "#7FD3FF", 5) +
      P(rect(10, 44, 30, 40, 8), "gray") +
      P(path("M36 44L68 20Q76 14 76 24V104Q76 114 68 108L36 84Z"), "gray"),
  ],
  [
    "Music",
    P(rect(48, 30, 10, 66), "purple", { w: 6, ng: true }) +
      P(rect(98, 18, 10, 66), "purple", { w: 6, ng: true }) +
      P(polyEl([[48, 24], [108, 10], [108, 38], [48, 52]]), "pink", { w: 6 }) +
      P(ell(38, 96, 19, 14, -22), "navy", { w: 6 }) +
      P(ell(88, 84, 19, 14, -22), "navy", { w: 6 }),
  ],
  [
    "Graphics",
    P(rect(34, 88, 60, 24, 8), "gray", { w: 6 }) +
      P(rect(50, 82, 28, 14), "gray", { w: 6, ng: true }) +
      P(rect(10, 14, 108, 74, 12), "dark") +
      O(rect(20, 24, 88, 54, 4), "url(#sky)", 0) +
      fillOnly(circ(88, 42, 8), "#FFE23A") +
      clip(rect(20, 24, 88, 54, 4), O(path("M14 80V64Q40 40 62 62Q84 76 114 52V80Z"), "url(#green)", 3.5)) +
      S(rect(20, 24, 88, 54, 4), 4.5),
  ],
  [
    "Code",
    P(rect(10, 18, 108, 92, 16), "navy") +
      fillOnly(circ(28, 34, 4.5), "#FF6B6B") +
      fillOnly(circ(42, 34, 4.5), "#FFD84A") +
      fillOnly(circ(56, 34, 4.5), "#5CE05C") +
      tube("M48 56L28 76L48 96", 7, "#FFFFFF", 4) +
      tube("M80 56L100 76L80 96", 7, "#FFFFFF", 4) +
      tube("M70 52L58 100", 7, "#FFE23A", 4),
  ],
  [
    "Crown",
    P(path("M24 92L18 42L42 64L64 26L86 64L110 42L104 92Z"), "gold", { w: 7, g: [0.3, 0.3, 0.18, 0.1, -20] }) +
      P(rect(20, 84, 88, 26, 9), "orange", { w: 7, g: [0.3, 0.25, 0.2, 0.15, 0] }) +
      P(circ(18, 40, 8), "yellow", { w: 5, ng: true }) +
      P(circ(64, 22, 8), "yellow", { w: 5, ng: true }) +
      P(circ(110, 40, 8), "yellow", { w: 5, ng: true }) +
      P(circ(38, 97, 6.5), "red", { w: 3.5, ng: true }) +
      P(circ(64, 97, 6.5), "sky", { w: 3.5, ng: true }) +
      P(circ(90, 97, 6.5), "red", { w: 3.5, ng: true }),
  ],
  [
    "Check",
    P(circ(64, 64, 52), "green") + P(polyEl(checkPts(64, 66, 1.05)), "white", { w: 5, ng: true }),
  ],
  [
    "Close",
    P(circ(64, 64, 52), "red") + P(polyEl(plusPts(64, 64, 26, 9, 45)), "white", { w: 5, ng: true }),
  ],
  [
    "Plus",
    P(circ(64, 64, 52), "green") + P(polyEl(plusPts(64, 64, 27, 9)), "white", { w: 5, ng: true }),
  ],
  [
    "Minus",
    P(circ(64, 64, 52), "orange") + P(rect(34, 54, 60, 20, 6), "white", { w: 5, ng: true }),
  ],
  [
    "Robux",
    P(polyEl(hexPts(64, 64, 56)), "green", { w: 7, g: [0.3, 0.25, 0.2, 0.1, -25] }) +
      S(polyEl(hexPts(64, 64, 41)), 4, "#167A30") +
      tube("M50 42V88M50 42H72Q86 42 86 55Q86 68 72 68H50M70 68L88 88", 8, "#FFFFFF", 4),
  ],
  [
    "Clock",
    P(circ(64, 64, 52), "blue") +
      O(circ(64, 64, 38), "url(#cream)", 4) +
      ln("M64 34V40M64 88V94M34 64H40M88 64H94", 5) +
      ln("M64 64V44", 7) +
      ln("M64 64L80 74", 7) +
      fillOnly(circ(64, 64, 6), "#F2394C", `stroke="${INK}" stroke-width="3"`),
  ],
  [
    "Warning",
    P(path("M64 12L116 102Q122 114 108 114H20Q6 114 12 102Z"), "yellow", { w: 8, g: [0.3, 0.3, 0.14, 0.08, -35] }) +
      fillOnly(rect(58, 44, 12, 34, 6), INK) +
      fillOnly(circ(64, 95, 7), INK),
  ],
  [
    "Thief",
    P(circ(64, 68, 48), "skin") +
      P(path("M16 62Q14 14 64 14Q114 14 112 62Q64 48 16 62Z"), "dark", { w: 7 }) +
      P(rect(14, 62, 100, 28, 14), "dark", { w: 6 }) +
      O(ell(44, 76, 11, 9), "#FFFFFF", 3.5) +
      O(ell(84, 76, 11, 9), "#FFFFFF", 3.5) +
      fillOnly(circ(47, 77, 5), INK) +
      fillOnly(circ(87, 77, 5), INK) +
      ln("M52 102Q64 110 76 102", 5),
  ],
  [
    "Sparkle",
    P(sparkle(56, 68, 50, 0.24), "yellow", { w: 6, g: [0.3, 0.35, 0.1, 0.07, -50] }) +
      P(sparkle(102, 26, 20, 0.18), "white", { w: 5, ng: true }) +
      P(sparkle(24, 100, 14, 0.18), "white", { w: 4.5, ng: true }),
  ],
  [
    "Potion",
    P(rect(46, 6, 36, 20, 6), "brown", { w: 6 }) +
      P(path("M50 22H78V46Q114 62 112 92Q110 116 64 116Q18 116 16 92Q14 62 50 46Z"), "glass", { w: 7, ns: true }) +
      clip(
        path("M50 22H78V46Q114 62 112 92Q110 116 64 116Q18 116 16 92Q14 62 50 46Z"),
        O(path("M0 78Q32 68 64 78Q96 88 128 76V128H0Z"), "url(#pink)", 0),
      ) +
      S(path("M50 22H78V46Q114 62 112 92Q110 116 64 116Q18 116 16 92Q14 62 50 46Z"), 7) +
      `<g fill="#FFF" fill-opacity=".85">${circ(48, 96, 5)}${circ(70, 88, 3.5)}${circ(84, 100, 4.5)}</g>` +
      `<ellipse cx="38" cy="78" rx="5" ry="12" transform="rotate(25 38 78)" fill="#FFF" fill-opacity=".6"/>`,
  ],
  [
    "Globe",
    P(circ(64, 64, 52), "sky", { ns: true, ng: true, w: 0 }) +
      clip(
        circ(64, 64, 52),
        O(path("M26 44Q38 26 58 36Q64 50 50 58Q44 74 34 64Z"), "url(#green)", 3.5, "#157A3A") +
          O(path("M72 68Q94 58 106 76Q100 98 80 104Q66 90 72 68Z"), "url(#green)", 3.5, "#157A3A") +
          O(path("M70 20Q90 18 98 32Q84 42 72 34Z"), "url(#green)", 3.5, "#157A3A"),
      ) +
      S(circ(64, 64, 52), 7) +
      GL(circ(64, 64, 52), [0.3, 0.22, 0.2, 0.08, -30]),
  ],
  [
    "People",
    person(30, 52, 0.82, "blue") + person(98, 52, 0.82, "orange") + person(64, 38, 1, "green"),
  ],
  [
    "Run",
    P(path("M12 38Q12 26 26 26H46Q56 46 76 52L102 60Q118 66 118 84V98H12Z"), "red") +
      ln("M36 76Q64 82 100 68", 6, "#FFFFFF") +
      ln("M52 44L62 36M64 50L74 42M76 56L86 48", 5, "#FFFFFF") +
      P(path("M8 96H122V104Q122 116 110 116H20Q8 116 8 104Z"), "white", { w: 6, g: [0.3, 0.3, 0.2, 0.2, 0] }),
  ],
  [
    "Gem",
    P(polyEl([[30, 16], [98, 16], [118, 46], [64, 114], [10, 46]]), "sky", { w: 7, ng: true }) +
      `<path d="M44 46L64 16L84 46Z" fill="#FFF" fill-opacity=".4"/>` +
      ln("M10 46H118M30 16L44 46L64 114M98 16L84 46L64 114M44 46L64 16L84 46", 4) +
      P(ell(38, 30, 10, 5, -30), "white", { w: 0, ng: true, ns: true }),
  ],
  [
    "Season",
    P(path("M44 82L30 120L50 110L60 122L68 88Z"), "red", { w: 6 }) +
      P(path("M84 82L98 120L78 110L68 122L60 88Z"), "red", { w: 6 }) +
      P(polyEl(starPts(64, 54, 48, 40, 14)), "gold", { w: 6 }) +
      P(circ(64, 54, 30), "orange", { w: 5 }) +
      P(polyEl(starPts(64, 54, 22, 10)), "yellow", { w: 4, ng: true }),
  ],
  [
    "Arrow",
    P(polyEl([[12, 46], [64, 46], [64, 18], [116, 64], [64, 110], [64, 82], [12, 82]]), "blue", { w: 7, g: [0.3, 0.25, 0.2, 0.08, -10] }),
  ],
  [
    "Info",
    P(circ(64, 64, 52), "blue") +
      P(circ(64, 36, 8.5), "white", { w: 4, ng: true }) +
      P(rect(55, 52, 18, 46, 6), "white", { w: 4, ng: true }),
  ],
  [
    "Fire",
    P(path("M66 8Q70 34 90 50Q112 68 104 92Q96 118 64 118Q32 118 24 92Q18 70 38 52Q40 66 50 70Q46 38 66 8Z"), "orange", { w: 7 }) +
      P(path("M64 58Q72 76 84 88Q92 108 64 110Q36 108 44 88Q56 78 64 58Z"), "yellow", { w: 0, ng: true, ns: true }),
  ],
  [
    "Heart",
    P(path("M64 112C20 80 8 56 14 38C20 20 48 14 64 38C80 14 108 20 114 38C120 56 108 80 64 112Z"), "red", { w: 7, g: [0.28, 0.28, 0.14, 0.09, -35] }),
  ],
  [
    "Bell",
    P(circ(64, 106, 10), "orange", { w: 6, ng: true }) +
      P(path("M64 8Q76 8 76 20Q102 28 102 62V80L114 92V100H14V92L26 80V62Q26 28 52 20Q52 8 64 8Z"), "gold", { w: 7 }),
  ],
  [
    "Search",
    tube("M80 80L108 108", 14, "#B5612B", 5) +
      P(circ(52, 52, 38), "gray", { w: 7, ng: true }) +
      P(circ(52, 52, 25), "glass", { w: 4.5, g: [0.3, 0.28, 0.2, 0.1, -35] }),
  ],
  [
    "Sell",
    P(path("M12 64L44 32Q48 28 54 28H100Q110 28 110 38V90Q110 100 100 100H54Q48 100 44 96Z"), "red") +
      fillOnly(circ(36, 64, 7), "#FFFFFF", `stroke="${INK}" stroke-width="4"`) +
      P(circ(86, 84, 30), "gold", { w: 7 }) +
      P(rect(70, 80, 32, 10, 4), "orange", { w: 4, ng: true }),
  ],
  [
    "Equip",
    keycap(8, 14, 90, 86, "tan", "cream", 8, 12) +
      letterA(53, 40, 0.8, 9) +
      P(circ(92, 92, 28), "green", { w: 7 }) +
      P(polyEl(checkPts(92, 93, 0.6)), "white", { w: 4, ng: true }),
  ],
  [
    "Star",
    P(polyEl(starPts(64, 68, 56, 26)), "yellow", { w: 7, g: [0.3, 0.3, 0.14, 0.08, -35] }),
  ],
  [
    "Megaphone",
    `<g transform="rotate(-12 64 64)">` +
      P(rect(32, 78, 20, 36, 8), "dark", { w: 6 }) +
      P(path("M18 50H44L96 20Q106 16 106 28V92Q106 104 96 100L44 78H18Q8 78 8 70V58Q8 50 18 50Z"), "red") +
      P(ell(106, 60, 10, 36), "yellow", { w: 6, ng: true }) +
      `</g>`,
  ],
];

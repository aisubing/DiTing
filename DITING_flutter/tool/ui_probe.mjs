// 真机 UI 取证脚本：通过 Dart VM Service 驱动 debug 包逐页跳转，
// 抓 screencap 截图 + 屏幕上所有文本/容器的真实全局矩形，再做量化体检。
//
// 用法：
//   node tool/ui_probe.mjs launch                 # 起 app 并连上 VM Service
//   node tool/ui_probe.mjs one /settings          # 单页：跳 + 截图 + 体检
//   node tool/ui_probe.mjs all [limit]            # 批量：tool/routes.txt 全量
//   node tool/ui_probe.mjs scroll /settings 3     # 下滑 3 屏逐屏体检
//   node tool/ui_probe.mjs tap 120 300            # 按逻辑坐标点按（换算物理像素）
//   node tool/ui_probe.mjs sheet /logs 205 430 请求详情  # 点开浮层后取证（含顶栏遮挡判据）
//   node tool/ui_probe.mjs shot /settings name    # 只截图
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const SERIAL = process.env.DITING_SERIAL || '';
const OUT = path.resolve('tool/uiprobe');
const ROUTES_FILE = process.env.DITING_ROUTES
  ? path.resolve(process.env.DITING_ROUTES)
  : path.resolve('tool/routes.txt');
const adb = (...a) => execFileSync('adb', [...(SERIAL ? ['-s', SERIAL] : []), ...a], { maxBuffer: 1 << 28 });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

let ws = null;
let nextId = 1;
let isolateId = null;
let dpr = 3.25;
const pending = new Map();

function send(method, params = {}) {
  const id = nextId++;
  ws.send(JSON.stringify({ jsonrpc: '2.0', id, method, params }));
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error(`${method} 超时`));
    }, 15000);
    pending.set(id, {
      resolve: (v) => {
        clearTimeout(timer);
        resolve(v);
      },
      reject: (e) => {
        clearTimeout(timer);
        reject(e);
      },
    });
  });
}

async function openSocket(url) {
  for (let attempt = 0; attempt < 15; attempt++) {
    try {
      const s = new WebSocket(url);
      await new Promise((res, rej) => {
        const t = setTimeout(() => rej(new Error('ws timeout')), 4000);
        s.onopen = () => {
          clearTimeout(t);
          res();
        };
        s.onerror = (e) => {
          clearTimeout(t);
          rej(new Error(`ws error: ${e.type || e.message}`));
        };
      });
      return s;
    } catch {
      await sleep(600);
    }
  }
  throw new Error(`无法连接 VM Service: ${url}`);
}

async function connect({ attach = false } = {}) {
  if (!attach) {
    adb('logcat', '-c');
    adb('shell', 'am', 'force-stop', 'com.haoze.diting');
    await sleep(300);
    adb('shell', 'am', 'start', '-n', 'com.haoze.diting/.MainActivity');
  }
  let uri = null;
  for (let i = 0; i < 40 && !uri; i++) {
    // 附着模式只看已有日志：先 `-c` 会把「服务已监听」那行清掉，附着就再没有来源了。
    const log = adb('logcat', '-d').toString('utf8');
    const m = log.match(/Dart VM service is listening on (http:\/\/127\.0\.0\.1:(\d+)\/([^/]+)\/)/);
    if (m) uri = { url: m[1], port: m[2], token: m[3] };
    else await sleep(700);
  }
  if (!uri) throw new Error('VM service URI not found in logcat');
  adb('forward', `tcp:${uri.port}`, `tcp:${uri.port}`);
  ws = await openSocket(`ws://127.0.0.1:${uri.port}/${uri.token}/ws`);
  ws.onmessage = (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.id && pending.has(msg.id)) {
      const { resolve, reject } = pending.get(msg.id);
      pending.delete(msg.id);
      if (msg.error) reject(new Error(JSON.stringify(msg.error)));
      else resolve(msg.result);
    }
  };
  ws.onerror = () => {};
  // 设备上可能同时挂着多个 isolate（重启中的旧 isolate 还没回收），
  // 只有注册了探针扩展的那个才是当前 UI isolate。
  //
  // 刚 `am start` 时 UI isolate 还没跑到注册扩展那一步，一次查不到就报错会把
  // 「启动慢」误判成「探针没注册」；所以这里轮询到超时为止。
  for (let attempt = 0; attempt < 30; attempt++) {
    const vm = await send('getVM');
    for (const iso of vm.isolates ?? []) {
      isolateId = iso.id;
      try {
        await ext('ext.diting.probe');
        return uri;
      } catch {
        /* 换下一个 isolate */
      }
    }
    await sleep(500);
  }
  throw new Error('没有任何 isolate 注册 ext.diting.probe');
}

async function ext(method, args = {}) {
  // 真机 debug 包由 `am start` 直接拉起，VM Service 没有 DDS 包裹，
  // 服务扩展要以 `ext.` 方法名直调；`callServiceExtension` 只在 DDS 下存在。
  let r;
  try {
    r = await send(method, { isolateId, ...args });
  } catch {
    r = await send('callServiceExtension', { method, args: { isolateId, ...args } });
  }
  try {
    return JSON.parse(r);
  } catch {
    return r;
  }
}

async function probe() {
  const p = await ext('ext.diting.probe');
  if (p.screen) dpr = p.screen.dpr;
  return p;
}

function slug(loc) {
  return loc.replace(/^\/+/, '').replace(/[^a-zA-Z0-9]+/g, '_') || 'home';
}

function shot(name) {
  fs.mkdirSync(OUT, { recursive: true });
  const buf = adb('exec-out', 'screencap', '-p');
  const file = path.join(OUT, `${name}.png`);
  fs.writeFileSync(file, buf);
  return file;
}

/** 量化体检：把「看起来不对」翻译成可复查的数字。 */
function audit(p, label) {
  const f = [];
  if (p.error) return [`${label}: 探针失败 ${p.error}`];
  const { w: SW, h: SH, dpr: DPR } = p.screen;
  // 探针里的 pad 是物理像素（FlutterView.viewPadding 口径），换算成 dp 才能和文本坐标比。
  const pad = { top: p.pad.top / DPR, bottom: p.pad.bottom / DPR };
  const bar = (p.boxes || []).filter((b) => b.k === 'AppBar').sort((a, b) => b.y + b.h - (a.y + a.h))[0];
  const barBottom = bar ? bar.y + bar.h : pad.top;
  const dock = (p.boxes || []).find((b) => b.k.includes('NavigationDock'));
  const inDock = (t) => dock && t.y >= dock.y - 1 && t.y + t.h <= dock.y + dock.h + 1;
  const visible = p.texts.filter((t) => !t.off && t.y >= 0 && t.y + t.h <= SH);
  // 被视口裁掉的行没有真的画到屏幕上（列表停在中间时最后一行必然顶到视口底边），
  // 只有落在视口内、又落进系统栏留白里的才算问题。
  const painted = visible.filter((t) => t.y + t.h <= (t.vb ?? SH) + 0.5);
  const content = visible.filter((t) => !inDock(t) && !t.bar && t.y >= barBottom - 2);
  if (visible.length === 0) f.push(`${label}: 屏幕无可见文本（空白页？）`);
  else if (visible.length < 4 && (p.boxes || []).some((b) => b.k === 'PageBody'))
    f.push(`${label}: 正文近乎空白（整页只有 ${visible.length} 行文本）`);
  for (const d of p.diag || []) f.push(`${label}: 渲染异常 ${d}`);
  for (const t of painted) {
    if (t.clip) f.push(`${label}: 文本超出右边界 需${t.w}dp 可用${(SW - t.x).toFixed(1)}dp: 「${t.s}」`);
    if (t.y < barBottom - 2 && !inDock(t) && !t.bar && t.y + t.h > pad.top)
      f.push(`${label}: 内容画进顶栏区(y=${t.y} < 栏底 ${barBottom.toFixed(1)}): 「${t.s}」`);
    // 系统手势条区域：正文画进导航条留白里才算问题，滚动折行不算。
    if (t.y + t.h > SH - pad.bottom + 1 && !inDock(t))
      f.push(`${label}: 正文侵入系统导航条区(${t.y + t.h} > ${(SH - pad.bottom).toFixed(1)}): 「${t.s}」`);
  }
  // 顶栏下方留白：看的是「第一个画上屏幕的东西」（文本或卡片/图），不是第一行文本——
  // 卡头、图标格这类没有文本的块同样占住这段空间，不能算空档。
  // 名单要和 debug_probe.dart 的 `_structureTypes` 同步：漏一类就会把「它占住的那段」
  // 量成留白。`Chart` 漏过一次（traffic/home 各报假留白），私有内容件
  // （`_FeatureCard`）漏过一次（hub 报 514dp 假留白），`CustomPaint`/`Button`/
  // `GlyphIcon`（首页大圆钮、扫码取景框、关于页图标）也漏过一次。
  const effectLayers = /^(?:ImageFiltered|FadeIn|Animated|Semantics|Focus|Mouse|Scrollable|Viewport|Sliver|Layout|Padding|Constrained|Offstage|Visibility|Theme|Inherited|Builder|ValueListenable|ScaffoldMessenger|ScaffoldScope|CommonScaffold|AppBarInsetScope|PageBody|AppBarClearance|_Body|_Glass)/;
  const scaffoldLayers = /(?:_Scaffold|_Material|_Ink|_Tooltip|_ErrorWidget|_Hero|_EffectiveText|_SizeChanged|_Merge|_InlineSpan|CardEntrance|FloatingActionButtonTransition)/;
  const blockBoxes = (p.boxes || []).filter(
    (b) =>
      /Card|Grid|Image|Header|Control|Gallery|Strip|Field|Chart|Tile|Code|Preview|Frame|Panel|Button|CustomPaint|GlyphIcon|EditableText|TextField/.test(
        b.k,
      ) &&
      !effectLayers.test(b.k) &&
      !scaffoldLayers.test(b.k) &&
      b.w > 40 &&
      b.h > 40 &&
      // 铺满整屏的是滚动容器/效果层，不是内容块；留着它「首个内容」永远是栏底，
      // 顶栏空档就再也量不出来了。
      b.h < SH * 0.7 &&
      b.y >= barBottom - 2 &&
      b.y < SH - 1 &&
      // 浮条自己的毛玻璃层也是 `CustomPaint`，算成内容块会把「列表到底之后的
      // 正常空白」报成 270dp 留白（tools 页）。
      !(dock && b.y >= dock.y - 1 && b.y < dock.y + dock.h),
  );
  const firstBox = blockBoxes.sort((a, b) => a.y - b.y)[0];
  const firstText = content.filter((t) => t.y > barBottom - 8).sort((a, b) => a.y - b.y)[0];
  const first =
    firstBox && (!firstText || firstBox.y <= firstText.y)
      ? { y: firstBox.y, s: `${firstBox.k} 块` }
      : firstText;
  // 居中/撑满排版的页面（引导步骤、扫码取景框、空状态）内容上下留白本来就对称，
  // 按「栏下到内容的距离」判会把它报成异常空档。两种情形都不算塌陷：
  //   - 下方已经没有余量（内容一直排到区底）→ 撑满整屏的版式，上方那点空隙是它
  //     自己的呼吸位（扫码页取景框、`档案不存在` 空状态）；
  //   - 上下都有余量且量级相当 → 居中排版（引导步骤）。
  // 只有「上方空、下方也空、但两者明显不等」才是内容被推下去的塌陷。
  //
  // 可用区底边取内容文本所属**滚动视口**的底边（`vb`），不是屏幕底边：钉在屏底
  // 的按钮在视口之外，用屏幕底算会让「下方空隙」几乎为 0，居中因此判不出来
  // （引导页被这样误报过一次）。
  const bodyBottom = (() => {
    const tally = new Map();
    for (const t of content) tally.set(t.vb ?? SH, (tally.get(t.vb ?? SH) || 0) + 1);
    return tally.size ? [...tally.entries()].sort((a, b) => b[1] - a[1])[0][0] : SH;
  })();
  const lastInArea = content
    .filter((t) => t.y + t.h <= bodyBottom + 0.5)
    .reduce((m, t) => Math.max(m, t.y + t.h), 0);
  const gapAbove = first ? first.y - barBottom : 0;
  const gapBelow = first ? bodyBottom - lastInArea : 0;
  const centered =
    first && (gapBelow < 60 || (gapAbove > 60 && gapAbove / gapBelow < 2.5));
  if (first && !centered) {
    const gap = first.y - barBottom;
    // 块（卡头/卡片）紧贴栏底是正常的：它自己带内边距，文本不会压到栏上。
    if (gap > 60) f.push(`${label}: 顶栏下空档 ${gap.toFixed(0)}dp（首块「${first.s}」y=${first.y.toFixed(1)}，栏底=${barBottom.toFixed(0)}，内容区底=${bodyBottom.toFixed(0)}，下方余 ${gapBelow.toFixed(0)}）`);
    else if (firstText && gap < 6 && firstText.y - barBottom < 6)
      f.push(`${label}: 正文顶到栏底仅 ${(firstText.y - barBottom).toFixed(0)}dp: 「${firstText.s}」`);
  }
  // 左边距一致性——只比「卡片外壳」的左边缘，不比任意文本。
  //
  // 试过按「视觉行行首」统计文本：卡片内部一行里并排放 chip / 数值 / 说明，
  // 行首本身就该不同（connections、requests、dns_queries 各报 4–5 组，
  // 看截图全是齐的）。也试过拿 `ListHeader` 的矩形当参照列——它是通栏容器
  // （x=0），文字才在 16，于是把每张正常卡片都报成「缩进过多」。
  //
  // 只判「最外层壳」：内部的行（`ListItem` / 卡里套的卡）天然比壳再缩进十几
  // dp，那是行内排版不是页面边距（WebDAV 表单被这样误报过一次）。
  // 期望列取设计常量 16（`pageContentPadding`），容差 8。
  const shellCandidates = (p.boxes || []).filter(
    (b) =>
      /^(?:CommonCard|DecorationListItem|ListTile)/.test(b.k) &&
      b.w > SW * 0.5 &&
      b.y >= barBottom - 2 &&
      b.y < SH - 1,
  );
  const contains = (a, b) =>
    b.x >= a.x - 0.5 &&
    b.y >= a.y - 0.5 &&
    b.x + b.w <= a.x + a.w + 0.5 &&
    b.y + b.h <= a.y + a.h + 0.5 &&
    b.w * b.h < a.w * a.h;
  const seenRect = new Set();
  const cardLike = shellCandidates.filter((a) => {
    if (shellCandidates.some((b) => b !== a && contains(b, a))) return false;
    const k = `${a.x},${a.y},${a.w},${a.h}`;
    if (seenRect.has(k)) return false;
    seenRect.add(k);
    return true;
  });
  const touching = cardLike.filter((b) => b.x < 1 || b.x + b.w > SW - 1);
  if (touching.length) {
    f.push(`${label}: 卡片贴住屏幕边沿 ${touching.length} 处（首处 x=${touching[0].x} w=${touching[0].w}，屏宽 ${SW}）`);
  }
  const over = cardLike.filter((b) => b.x > 24);
  if (over.length) {
    f.push(`${label}: 卡片缩进超过设计列 16 处（首处 x=${over[0].x}，疑重复加边距）`);
  }
  // 异常留白：内容区内相邻块（文本或卡片/图）纵向空隙。
  //
  // 先剔掉「被更大的块包住」的条目：360 高的输入框里那几行提示文字，和卡片里
  // 的每行文本，都不该参与空隙计算——否则「提示文字底部 → 下一张卡顶部」会被
  // 量成 262dp 留白，而那段距离其实是输入框自己的内部空间（/rules/batch）。
  const rects = [
    ...content.map((t) => ({ y: t.y, h: t.h, s: t.s, x: t.x, w: t.w })),
    ...blockBoxes.map((b) => ({ y: b.y, h: b.h, s: b.k, x: b.x, w: b.w })),
  ];
  const inside = (a, b) =>
    a !== b &&
    a.y >= b.y - 0.5 &&
    a.y + a.h <= b.y + b.h + 0.5 &&
    a.x >= b.x - 0.5 &&
    a.x + a.w <= b.x + b.w + 0.5 &&
    a.h * a.w < b.h * b.w;
  const items = rects
    .filter((a) => !rects.some((b) => inside(a, b)))
    // 钉在屏底的按钮/浮条在滚动视口之外，它们与正文之间的大空隙是「内容不满一屏」
    // 的正常结果，不是塌陷的留白（引导页的「下一步」被这样误报过一次）。
    .filter((a) => a.y < bodyBottom - 1)
    .sort((a, b) => a.y - b.y);
  let maxGap = 0,
    gapAt = '';
  for (let i = 1; i < items.length; i++) {
    const gap = items[i].y - (items[i - 1].y + items[i - 1].h);
    if (gap > maxGap) {
      maxGap = gap;
      gapAt = `${items[i - 1].s}→${items[i].s}`;
    }
  }
  if (maxGap > 90) f.push(`${label}: 纵向留白 ${maxGap.toFixed(0)}dp（${gapAt}）`);
  // 底栏遮挡：内容文本落进浮条矩形（浮条自己的标签除外）
  if (dock) {
    for (const t of painted) {
      if (!inDock(t) && !t.bar && t.y + t.h > dock.y + 2 && t.y < dock.y + dock.h)
        f.push(`${label}: 文本被底栏盖住: 「${t.s}」`);
    }
  }
  return f;
}

async function gotoRoute(loc, waitMs = 900) {
  // 刚启动时 `rootNavigatorKey.currentContext` 还是空的，`go` 会静默返回
  // `ok: false`（探针不报错），于是「跳页成功」其实是首页——之前量到的
  // 一屏首页文本就是这么来的。这里验返回体，失败就重试。
  for (let attempt = 0; attempt < 10; attempt++) {
    const r = await ext('ext.diting.go', { loc });
    if (r && r.ok) {
      await sleep(waitMs);
      return;
    }
    await sleep(500);
  }
  throw new Error(`跳转到 ${loc} 失败（导航器未就绪）`);
}

/** 两次探针之间的最大纵向位移：动画/回弹没停时，矩形与截图会对不上。 */
function layoutShift(a, b) {
  const byLabel = new Map((a.texts || []).map((t) => [t.s, t.y]));
  let d = 0;
  for (const t of b.texts || []) {
    if (byLabel.has(t.s)) d = Math.max(d, Math.abs(byLabel.get(t.s) - t.y));
  }
  return d;
}

/** 跳页面并取证：确保截图与矩形来自同一个静止画面。 */
async function capture(loc, move = true, suffix = '') {
  if (move) await gotoRoute(loc);
  const s = slug(loc) + suffix;
  let p = await probe();
  shot(s);
  const again = await probe();
  if (layoutShift(p, again) > 2) {
    p = again;
    shot(s);
  }
  return p;
}

async function swipeUp() {
  const { w, h } = adb('shell', 'wm', 'size').toString().match(/(\d+)x(\d+)/).slice(1).map(Number);
  adb('shell', 'input', 'swipe', String(w / 2), String(h * 0.75), String(w / 2), String(h * 0.3), '260');
  await sleep(500);
}

async function main() {
  const [cmd, a1, a2, a3, a4] = process.argv.slice(2);

  // 体检规则本身可以离线跑：改判据不该逼一次真机往返，否则每次调阈值都要重连设备。
  //
  // 只跑 `routes.txt` 里还在的页：目录里会留着早期临时路由（`/profiles_edit`
  // 这类已被路径参数化取代）的 dump，它们量的是不存在的页面，会把结果污染成
  // 一堆「页面不存在」的假发现。
  if (cmd === 'reaudit') {
    const live = new Set(
      fs
        .readFileSync(ROUTES_FILE, 'utf8')
        .split(/\r?\n/)
        .map((l) => l.trim())
        .filter((l) => l && !l.startsWith('#'))
        .map(slug),
    );
    const files = fs
      .readdirSync(OUT)
      .filter((f) => f.endsWith('.json') && f !== 'summary.json')
      .filter((f) => live.has(f.replace(/\.json$/, '')))
      .filter((f) => !a1 || f.startsWith(slug(a1) + '.'))
      .sort();
    const skipped = fs
      .readdirSync(OUT)
      .filter((f) => f.endsWith('.json') && f !== 'summary.json' && !live.has(f.replace(/\.json$/, '')));
    const bad = [];
    for (const f of files) {
      const p = JSON.parse(fs.readFileSync(path.join(OUT, f), 'utf8'));
      const label = f.replace(/\.json$/, '');
      const findings = audit(p, label);
      if (findings.length) {
        bad.push(label);
        console.log(findings.join('\n'));
      }
    }
    console.log(
      `\n===== 离线复检：${files.length} 页（跳过 ${skipped.length} 份非当前路由的旧 dump），${bad.length} 页有发现 =====`,
    );
    return;
  }

  // `now` 只量当前画面，必须附着到已经在跑的实例：`one`/`sheet` 都会重启 app，
  // 一重启浮层就没了，量到的是重启后的首页。
  await connect({ attach: cmd === 'now' });
  fs.mkdirSync(OUT, { recursive: true });

  if (cmd === 'one') {
    const p = await capture(a1);
    const s = slug(a1);
    fs.writeFileSync(path.join(OUT, `${s}.json`), JSON.stringify(p, null, 1));
    const f = audit(p, a1);
    console.log(f.length ? f.join('\n') : `${a1}: OK (${p.texts.filter((t) => !t.off).length} 文本)`);
  } else if (cmd === 'tail') {
    // 滚到列表底部再体检：浮条留白、系统手势条留白只有在末屏才暴露得出来。
    await gotoRoute(a1);
    for (let i = 0; i < 8; i++) {
      const before = await probe();
      await swipeUp();
      if (layoutShift(before, await probe()) < 2) break;
    }
    const p = await capture(a1, false, '_tail');
    fs.writeFileSync(path.join(OUT, `${slug(a1)}_tail.json`), JSON.stringify(p, null, 1));
    const f = audit(p, `${a1} 滚到底`);
    console.log(f.length ? f.join('\n') : `${a1} 滚到底: OK`);
  } else if (cmd === 'all') {
    const routes = fs
      .readFileSync(ROUTES_FILE, 'utf8')
      .split(/\r?\n/)
      .map((l) => l.trim())
      .filter((l) => l && !l.startsWith('#'))
      .slice(0, a1 ? Number(a1) : undefined);
    const summary = [];
    for (const r of routes) {
      try {
        const p = await capture(r);
        const s = slug(r);
        fs.writeFileSync(path.join(OUT, `${s}.json`), JSON.stringify(p));
        const f = audit(p, r);
        summary.push({ r, n: p.texts?.filter((t) => !t.off).length ?? 0, findings: f });
        console.log(f.length ? f.join('\n') : `${r}: OK`);
      } catch (e) {
        console.log(`${r}: 探针异常 ${String(e).slice(0, 120)}`);
        summary.push({ r, n: -1, findings: [`${r}: 异常 ${String(e).slice(0, 120)}`] });
      }
    }
    fs.writeFileSync(path.join(OUT, 'summary.json'), JSON.stringify(summary, null, 1));
    const bad = summary.filter((s) => s.findings.length);
    console.log(`\n===== 汇总：${summary.length} 页，${bad.length} 页有发现 =====`);
    for (const s of bad) console.log(`${s.r} [${s.findings.length}]`);
  } else if (cmd === 'scroll') {
    await gotoRoute(a1);
    const n = Number(a2 || 3);
    for (let i = 0; i < n; i++) {
      if (i) await swipeUp();
      const p = await probe();
      const s = `${slug(a1)}_s${i}`;
      fs.writeFileSync(path.join(OUT, `${s}.json`), JSON.stringify(p));
      shot(s);
      const f = audit(p, `${a1}#${i}`);
      console.log(f.length ? f.join('\n') : `${a1}#${i}: OK`);
    }
  } else if (cmd === 'tap') {
    await probe(); // 先刷 dpr，否则默认 3.25 在 dpr=2.625 的机器上会点偏。
    const x = Math.round(Number(a1) * dpr);
    const y = Math.round(Number(a2) * dpr);
    adb('shell', 'input', 'tap', String(x), String(y));
    await sleep(900);
    console.log(`tap 逻辑(${a1},${a2}) → 物理(${x},${y}) dpr=${dpr}`);
  } else if (cmd === 'sheet') {
    // 浮层体检：跳页 → 点按打开浮层 → 在原地重新取证。
    // `one` 只量路由首屏，浮层里的顶栏遮挡量不到；而浮层的顶栏是
    // `FloatingHeader`（盖在正文上），判据得靠正文首行的 y 与栏底比。
    await gotoRoute(a1);
    // `dpr` 只有 `probe()` 会从真机刷新；不先取一次就会用默认 3.25 换算，
    // 点按落到屏幕别处（验证过：dpr=2.625 的机器点空了）。
    await probe();
    const x = Math.round(Number(a2) * dpr);
    const y = Math.round(Number(a3) * dpr);
    adb('shell', 'input', 'tap', String(x), String(y));
    await sleep(1200);
    const label = `${a1} ⊃ ${a4 || `tap(${a2},${a3})`}`;
    const p = await capture(label, false);
    fs.writeFileSync(path.join(OUT, `${slug(label)}.json`), JSON.stringify(p, null, 1));
    const f = audit(p, label);
    console.log(f.length ? f.join('\n') : `${label}: OK (${p.texts.filter((t) => !t.off).length} 文本)`);
  } else if (cmd === 'now') {
    // 量「当前屏幕」而不跳页：浮层里的顶栏遮挡只有在点开之后才量得到，
    // 一旦 `go` 就会把浮层关掉。
    const label = a1 || 'now';
    const p = await capture(label, false);
    fs.writeFileSync(path.join(OUT, `${slug(label)}.json`), JSON.stringify(p, null, 1));
    const f = audit(p, label);
    console.log(f.length ? f.join('\n') : `${label}: OK (${p.texts.filter((t) => !t.off).length} 文本)`);
  } else if (cmd === 'shot') {
    if (a1) await gotoRoute(a1);
    shot(a2 || `shot_${Date.now()}`);
    console.log('shot saved');
  } else if (cmd === 'raw') {
    await gotoRoute(a1);
    console.log(JSON.stringify(await probe(), null, 1));
  } else {
    console.log('unknown cmd');
  }
  ws.close();
  process.exit(0);
}

main().catch((e) => {
  console.error('FATAL', e);
  process.exit(1);
});

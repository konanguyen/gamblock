// Inject a temporary CSS rule into the open Chrome tab to hide the
// gambling banners discovered on animehay17.site (via CDP :9222).
const targets = await (await fetch('http://localhost:9222/json/list')).json();
const target = process.argv[2] || 'animehay17.site';
const page = targets.find(t => t.type === 'page' && t.url.includes(target));
if (!page) {
  console.log('Khong tim thay tab:', target);
  process.exit(1);
}
const ws = new WebSocket(page.webSocketDebuggerUrl);
let id = 0;
const pending = new Map();
ws.addEventListener('message', e => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
});
await new Promise((res, rej) => {
  ws.addEventListener('open', res, { once: true });
  ws.addEventListener('error', rej, { once: true });
});
function send(method, params = {}) {
  const msgId = ++id;
  return new Promise(resolve => { pending.set(msgId, resolve); ws.send(JSON.stringify({ id: msgId, method, params })); });
}
const expression = `(() => {
  const id = 'gamblock-hide-ads';
  let style = document.getElementById(id);
  if (!style) {
    style = document.createElement('style');
    style.id = id;
    document.documentElement.appendChild(style);
  }
  style.textContent = 'img[src*="/ad_banner/"], div:has(> img[src*="/ad_banner/"]) { display: none !important; }';
  return { hidden: [...document.querySelectorAll('img[src*="/ad_banner/"]')].map(i => i.src) };
})()`;
const res = await send('Runtime.evaluate', { expression, returnByValue: true });
console.log('Da an banner:', JSON.stringify(res.result?.result?.value ?? res));
ws.close();

// Inspect the open Chrome page via CDP on localhost:9222 and extract
// gambling-related ad links / hosts. Treat all page data as untrusted.
import { writeFile } from 'node:fs/promises';

const endpoint = 'http://localhost:9222/json/list';
const targetUrl = process.argv[2] || 'animehay17.site';

const targets = await (await fetch(endpoint)).json();
const page = targets.find(t => t.type === 'page' && t.url.includes(targetUrl));
if (!page) {
  console.error('Khong tim thay tab chua:', targetUrl);
  console.error(targets.filter(t => t.type === 'page').map(t => t.url).join('\n'));
  process.exit(1);
}

const ws = new WebSocket(page.webSocketDebuggerUrl);
let id = 0;
const pending = new Map();
ws.addEventListener('message', e => {
  const msg = JSON.parse(e.data);
  if (msg.id && pending.has(msg.id)) {
    pending.get(msg.id)(msg);
    pending.delete(msg.id);
  }
});
await new Promise((res, rej) => {
  ws.addEventListener('open', res, { once: true });
  ws.addEventListener('error', rej, { once: true });
});
function send(method, params = {}) {
  const msgId = ++id;
  return new Promise(resolve => {
    pending.set(msgId, resolve);
    ws.send(JSON.stringify({ id: msgId, method, params }));
  });
}

const expression = `(() => {
  const kw = /casino|bet|betting|bookmaker|slot|nổ hũ|no hu|cờ bạc|ca do|cá độ|đá gà|da ga|thể thao|the thao|188bet|fun88|w88|m88|stake|roobet|i9bet|bk8|vn88|qh88|sunwin|hitclub|b52|1xbet|okbet|luck8|new88|go88|iwin|bet365/i;
  const items = [];
  const hosts = {};
  const addHost = (u) => { try { const h = new URL(u, location.href).hostname; if (h && h !== location.hostname) hosts[h] = (hosts[h] || 0) + 1; } catch {} };
  for (const el of document.querySelectorAll('a[href], img[src], iframe[src], script[src], video[src], source[src]')) {
    const url = el.href || el.src || '';
    addHost(url);
    const text = (el.innerText || el.alt || el.title || '').trim().slice(0, 150);
    if (kw.test(text) || kw.test(url)) {
      const parent = el.closest('a') || el.parentElement?.closest('a');
      items.push({
        tag: el.tagName.toLowerCase(),
        text,
        url: String(url).slice(0, 400),
        link: parent ? String(parent.href).slice(0, 400) : '',
        parent: (el.parentElement?.outerHTML || '').slice(0, 600),
      });
    }
  }
  for (const el of document.querySelectorAll('div,span,button,p,li')) {
    if (el.children.length > 3) continue;
    const text = (el.innerText || '').trim();
    if (text.length > 3 && text.length < 160 && kw.test(text)) {
      const a = el.closest('a');
      items.push({ tag: 'text', text, url: a ? a.href : '' });
    }
  }
  return { title: document.title, url: location.href, items: items.slice(0, 300), hosts };
})()`;

const result = await send('Runtime.evaluate', { expression, returnByValue: true });
const data = result.result?.result?.value ?? result;
await writeFile(new URL('../data/observed-ads.json', import.meta.url), JSON.stringify(data, null, 2), 'utf8');
console.log('Tab:', data.title, '|', data.url);
console.log('Gambling-related items:', data.items?.length ?? 0);
console.log('External hosts:', Object.keys(data.hosts || {}).length);
for (const item of (data.items || []).slice(0, 60)) {
  console.log(`- [${item.tag}] ${item.text} ${item.url}`);
}
ws.close();

// Coordinates the POS page, the WhatsApp Web tab and (for the Windows app) the
// local bridge at 127.0.0.1. The content scripts cannot reach the bridge
// themselves: WhatsApp Web's CSP blocks it.
const BASE = 'http://127.0.0.1:47618';
const HEADERS = { 'X-Cafe-Client': 'whatsapp-bridge' };
const WA_TABS = 'https://web.whatsapp.com/*';

// Only ONE WhatsApp tab may take bridge jobs (Windows app). Extra tabs stay idle.
let leaderTab = null;
let leaderSeen = 0;
const LEASE_MS = 8000;

function isLeader(tabId) {
  const now = Date.now();
  if (leaderTab === null || leaderTab === tabId || now - leaderSeen > LEASE_MS) {
    leaderTab = tabId;
    leaderSeen = now;
    return true;
  }
  return false;
}

const store = chrome.storage.session;
const getKey = async (key) => (await store.get(key))[key];

// POS web page -> WhatsApp tab. Reuses an open WhatsApp tab, else opens one.
async function startFromPos(job, posTabId) {
  if (!/^\d{8,15}$/.test(job.phone || '')) throw new Error('Invalid phone number');
  await store.set({ [`route:${job.id}`]: { posTabId } });

  const url = `https://web.whatsapp.com/send?phone=${job.phone}`;
  const open = await chrome.tabs.query({ url: WA_TABS });
  const existing = open.find((tab) => tab.id === leaderTab) || open[0];

  let tabId;
  if (existing && existing.id !== undefined) {
    tabId = existing.id;
    await store.set({ [`pending:${tabId}`]: job });
    await chrome.tabs.update(tabId, { url, active: true });
    if (existing.windowId !== undefined) {
      await chrome.windows.update(existing.windowId, { focused: true });
    }
  } else {
    const created = await chrome.tabs.create({ url, active: true });
    tabId = created.id;
    await store.set({ [`pending:${tabId}`]: job });
  }
}

async function deliverResult(body) {
  const route = await getKey(`route:${body.id}`);
  if (route && route.posTabId !== undefined) {
    await store.remove(`route:${body.id}`);
    try {
      await chrome.tabs.sendMessage(route.posTabId, { type: 'result', body });
    } catch (_) {}
    // Back to the POS once WhatsApp is done.
    try {
      const tab = await chrome.tabs.update(route.posTabId, { active: true });
      if (tab && tab.windowId !== undefined) {
        await chrome.windows.update(tab.windowId, { focused: true });
      }
    } catch (_) {}
    return;
  }
  await fetch(`${BASE}/wa/result`, {
    method: 'POST',
    headers: { ...HEADERS, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  (async () => {
    try {
      const tabId = sender && sender.tab ? sender.tab.id : -1;
      if (message.type === 'next') {
        if (!isLeader(tabId)) {
          sendResponse({ job: null });
          return;
        }
        const response = await fetch(`${BASE}/wa/next`, { headers: HEADERS });
        sendResponse({ job: response.status === 200 ? await response.json() : null });
      } else if (message.type === 'takeJob') {
        const key = `pending:${tabId}`;
        const job = await getKey(key);
        if (job) await store.remove(key);
        sendResponse({ job: job || null });
      } else if (message.type === 'posSend') {
        await startFromPos(message.job, tabId);
        sendResponse({ ok: true });
      } else if (message.type === 'result') {
        await deliverResult(message.body);
        sendResponse({ ok: true });
      } else {
        sendResponse({ job: null });
      }
    } catch (error) {
      sendResponse({ job: null, ok: false, error: String(error) });
    }
  })();
  return true; // async response
});

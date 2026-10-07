// Talks to the Cafe 618 POS app on this computer (127.0.0.1 only). The content
// script cannot do this itself: WhatsApp Web's CSP blocks it.
const BASE = 'http://127.0.0.1:47618';
const HEADERS = { 'X-Cafe-Client': 'whatsapp-bridge' };

// Only ONE WhatsApp tab may take jobs. Extra open tabs stay idle, so a receipt is
// never opened or sent from several tabs at once.
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

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  (async () => {
    try {
      if (message.type === 'next') {
        const tabId = sender && sender.tab ? sender.tab.id : -1;
        if (!isLeader(tabId)) {
          sendResponse({ job: null });
          return;
        }
        const response = await fetch(`${BASE}/wa/next`, { headers: HEADERS });
        sendResponse({ job: response.status === 200 ? await response.json() : null });
      } else if (message.type === 'result') {
        await fetch(`${BASE}/wa/result`, {
          method: 'POST',
          headers: { ...HEADERS, 'Content-Type': 'application/json' },
          body: JSON.stringify(message.body),
        });
        sendResponse({ ok: true });
      } else {
        sendResponse({ job: null });
      }
    } catch (error) {
      sendResponse({ job: null, error: String(error) });
    }
  })();
  return true; // async response
});

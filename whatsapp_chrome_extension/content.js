// Runs inside your WhatsApp Web tab. Asks the POS app for a pending receipt,
// opens that customer's chat in THIS tab, pastes the image and presses send.
// WhatsApp changes its page now and then: if a selector below stops matching,
// update it here.
(() => {
  const COMPOSER =
    'footer div[contenteditable="true"], div[contenteditable="true"][role="textbox"][data-tab]';
  const SEND =
    '[data-icon="send"], [data-icon="wds-ic-send-filled"], [data-testid="send"], ' +
    'button[aria-label="Send"], [role="button"][aria-label="Send"], [aria-label="إرسال"]';
  const QR = 'div[data-ref], canvas[aria-label*="QR"]';
  const KEY = 'cafe618Job';

  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
  const ask = (message) =>
    new Promise((resolve) => {
      try {
        chrome.runtime.sendMessage(message, (response) => {
          void chrome.runtime.lastError;
          resolve(response || null);
        });
      } catch (_) {
        resolve(null);
      }
    });

  async function waitFor(check, timeoutMs, stepMs = 400) {
    const end = Date.now() + timeoutMs;
    while (Date.now() < end) {
      const value = check();
      if (value) return value;
      await sleep(stepMs);
    }
    return null;
  }

  const report = (id, status, detail) => ask({ type: 'result', body: { id, status, detail } });

  async function run(job) {
    let qrSeen = 0;
    const state = await waitFor(() => {
      if (document.querySelector(COMPOSER)) return 'ready';
      qrSeen = document.querySelector(QR) ? qrSeen + 1 : 0;
      return qrSeen >= 4 ? 'qr' : null;
    }, 60000);
    if (state === 'qr') return report(job.id, 'needsLogin');
    if (state !== 'ready') return report(job.id, 'failedBeforeSend', 'Chat did not open in time');

    await sleep(1500);
    // Never press send on someone's unsent draft text.
    if (document.querySelector(SEND)) {
      return report(job.id, 'failedBeforeSend', 'The chat has an unsent draft');
    }

    const input = document.querySelector(COMPOSER);
    input.focus();
    const binary = atob(job.image);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    const data = new DataTransfer();
    data.items.add(new File([bytes], job.fileName || 'invoice.png', { type: 'image/png' }));
    input.dispatchEvent(
      new ClipboardEvent('paste', { clipboardData: data, bubbles: true, cancelable: true }),
    );

    const preview = await waitFor(() => document.querySelector(SEND), 15000);
    if (!preview) return report(job.id, 'failedBeforeSend', 'Image preview did not appear');

    (preview.closest('button, [role="button"]') || preview).click();
    const closed = await waitFor(() => !document.querySelector(SEND), 20000);
    return report(job.id, closed ? 'sent' : 'uncertain');
  }

  async function main() {
    // A receipt requested by the POS web page: the extension has already pointed
    // this tab at the customer's chat. A freshly opened tab may ask a moment
    // before the job is stored, so try a few times.
    for (let attempt = 0; attempt < 3; attempt++) {
      const taken = await ask({ type: 'takeJob' });
      if (taken && taken.job) {
        try {
          await run(taken.job);
        } catch (error) {
          await report(taken.job.id, 'uncertain', String(error));
        }
        break;
      }
      await sleep(700);
    }

    // A job from the Windows app survives the reload that opens the chat.
    const pending = sessionStorage.getItem(KEY);
    if (pending) {
      sessionStorage.removeItem(KEY);
      try {
        await run(JSON.parse(pending));
      } catch (error) {
        await report(JSON.parse(pending).id, 'uncertain', String(error));
      }
    }
    for (;;) {
      const response = await ask({ type: 'next' });
      if (response && response.job) {
        sessionStorage.setItem(KEY, JSON.stringify(response.job));
        location.href = `https://web.whatsapp.com/send?phone=${encodeURIComponent(response.job.phone)}`;
        return;
      }
      await sleep(response && response.error ? 5000 : 1500);
    }
  }

  main();
})();

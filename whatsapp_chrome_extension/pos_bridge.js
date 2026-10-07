// Runs inside the Cafe 618 POS web page. Relays "send this receipt" requests
// from the page to the extension and the result back. Only the page itself
// (same window, same origin) can talk to it.
(() => {
  const FROM_PAGE = 'cafe618-pos';
  const FROM_EXT = 'cafe618-ext';

  const post = (message) =>
    window.postMessage({ source: FROM_EXT, ...message }, location.origin);

  window.addEventListener('message', (event) => {
    if (event.source !== window || event.origin !== location.origin) return;
    const data = event.data;
    if (!data || data.source !== FROM_PAGE) return;

    if (data.type === 'wa-ping') {
      post({ type: 'wa-pong' });
      return;
    }
    if (data.type === 'wa-send' && data.job && typeof data.job.phone === 'string') {
      const job = data.job;
      try {
        chrome.runtime.sendMessage({ type: 'posSend', job }, (response) => {
          void chrome.runtime.lastError;
          if (!response || !response.ok) {
            post({
              type: 'wa-result',
              body: {
                id: job.id,
                status: 'failedBeforeSend',
                detail: (response && response.error) || 'Extension did not answer',
              },
            });
          }
        });
      } catch (error) {
        post({
          type: 'wa-result',
          body: { id: job.id, status: 'failedBeforeSend', detail: String(error) },
        });
      }
    }
  });

  chrome.runtime.onMessage.addListener((message) => {
    if (message && message.type === 'result') {
      post({ type: 'wa-result', body: message.body });
    }
  });

  post({ type: 'wa-pong' });
})();

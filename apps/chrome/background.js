// Dots Capture — the whole capture in one gesture. Runs in *your* tab:
// logged-in, rendered, exactly what you see. The native host does the
// article extraction and writes straight into your vault, so this works
// even when the Dots app is closed.

const HOST = "blog.dots.capture";

async function capture(tab) {
  if (!tab?.id) {
    return;
  }
  try {
    const [{ result }] = await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: () => ({
        url: location.href,
        title: document.title,
        html: document.documentElement.outerHTML,
        selection: String(getSelection() ?? ""),
      }),
    });
    const reply = await chrome.runtime.sendNativeMessage(HOST, result);
    badge(tab.id, reply?.ok ? "✓" : "!", reply?.ok ? "#2E7D32" : "#C62828");
  } catch (error) {
    console.error("Dots capture failed:", error);
    badge(tab.id, "!", "#C62828");
  }
}

function badge(tabId, text, color) {
  chrome.action.setBadgeBackgroundColor({ tabId, color });
  chrome.action.setBadgeText({ tabId, text });
  setTimeout(() => chrome.action.setBadgeText({ tabId, text: "" }), 1600);
}

chrome.action.onClicked.addListener(capture);

chrome.commands.onCommand.addListener(async (command) => {
  if (command !== "capture-page") {
    return;
  }
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  await capture(tab);
});

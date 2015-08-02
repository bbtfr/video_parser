(function() {
  var port = null, logs = null;

  function appendLog(obj) {
    var li = document.createElement("li");
    li.textContent = typeof obj === "string" ? obj : JSON.stringify(obj);
    logs.appendChild(li);
  }

  function startFetch() {
    var videoLinkRegexInput = document.querySelector("#video-link-regex-input");
    var videoLinkRegex = videoLinkRegexInput.value || "\\.mp4|\\.m3u8|\\.ts";

    var videoPageReadyTimeoutInput = document.querySelector("#video-page-ready-timeout-input");
    var videoPageReadyTimeout = parseInt(videoPageReadyTimeoutInput.value) || 20;

    var videoSnifferTimeoutInput = document.querySelector("#video-sniffer-timeout-input");
    var videoSnifferTimeout = parseInt(videoSnifferTimeoutInput.value) || 10;

    var videoDownloadConcurrentInput = document.querySelector("#video-download-concurrent-input");
    var videoDownloadConcurrent = parseInt(videoDownloadConcurrentInput.value) || 3;

    var videoPageUrlsTextarea = document.querySelector("#video-page-urls-textarea");
    var videoPageUrls = videoPageUrlsTextarea.value;

    port.postMessage({
      command: "webRequest",
      regex: videoLinkRegex,
      tabId: chrome.devtools.inspectedWindow.tabId,
      pageReadyTimeout: videoPageReadyTimeout,
      snifferTimeout: videoSnifferTimeout,
      downloadConcurrent: videoDownloadConcurrent,
      urls: videoPageUrls
    });

    appendLog("Start Fetching...");
  }

  function listener() {
    logs = document.querySelector("#logs");

    var startFetchButton = document.querySelector("#start-fetch-button");
    startFetchButton.addEventListener("click", startFetch);

    port = chrome.runtime.connect({ name: "devpanel" });
    port.onMessage.addListener(function (message) {
      appendLog(message.message);
    });
  }

  window.addEventListener("load", listener);
})();

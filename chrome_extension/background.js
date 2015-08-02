chrome.runtime.onConnect.addListener(function(port) {
  console.log("Connect: ", port);

  var webRequestRegex = null, urls = null, options = null, currentPageUrl = null,
    waitingTime = 0, waiting = null, downloadReady = false, pageReady = false;

  var messageListener = function(message, port) {
    console.log("Receive Message: ", message, port);

    options = message;

    webRequestRegex = new RegExp(message.regex);

    urls = message.urls.split("\n");
    var index = urls.indexOf("");
    while (index > -1) {
      urls.splice(index, 1);
      index = urls.indexOf("");
    }

    console.log("Options: ", webRequestRegex, urls);

    if (urls.length == 0) {
      port.postMessage({ message: "Nothing to Download!" });
    }

    if (waiting) clearInterval(waiting);
    if (!chrome.webRequest.onBeforeRequest.hasListener(webRequestListener)) {
      chrome.webRequest.onBeforeRequest.addListener(webRequestListener, { urls: ["<all_urls>"] });
    }

    waiting = setInterval(regularCheck, 1000);
    goNextPage();
  };

  var webRequestListener = function(request) {
    var filename = request.url.replace(/^.*\//, "").replace(/\?.*$/, "");
    if (request.tabId != options.tabId ||
      !webRequestRegex.test(request.url) ||
      !webRequestRegex.test(filename)
      ) return;
    console.log("Sniffer: ", request, filename);

    port.postMessage({ message: request.url });
    download({ url: request.url, filename: filename });

    blob = new Blob([currentPageUrl], { type: "octet/stream" }),
    url = window.URL.createObjectURL(blob);
    download({ url: url, filename: filename + '.url' });
  };

  function regularCheck() {
    console.debug("Regular Check: ", waitingTime, pageReady, downloadReady);

    try {
      if (!pageReady) {
        chrome.tabs.executeScript(options.tabId, { code: "window.__videoParserPageReady" },
          function(result) {
            console.debug("Page Ready Check: ", result);
            if (result[0]) pageReady = true;
            else if (result[0] === null) waitingTime--;
        });
      }

      if (!downloadReady) {
        chrome.downloads.search({ state: "in_progress" }, function(results) {
          console.debug("Download Ready Check: ", results.length, options.downloadConcurrent);
          if (results.length < options.downloadConcurrent) downloadReady = true;
        });
      }

      if (pageReady && downloadReady) waitingTime--;
      if (waitingTime <= 0) goNextPage();

    } catch (e) {
      waitingTime += 1;
      throw e;
    }
  }

  function setWaitingTime(timeout) {
    if (waitingTime < timeout) waitingTime = timeout;
  }

  function download(message) {
    var url = message.url;
    console.log("Download: " + url);

    chrome.downloads.download(message, function(downloadId) {
      setWaitingTime(options.snifferTimeout);
      downloadReady = false;
      pageReady = true;
    });
  }

  function executeScript() {
    chrome.tabs.executeScript(options.tabId, { code: " \
          window.__videoParserPageReady = false; \
          window.addEventListener(\"load\", function() { \
            window.__videoParserPageReady = true; \
          }); \
          "
    });
  }

  function goNextPage() {
    if (urls.length > 0) {
      currentPageUrl = urls.pop();
      console.log("Parse Page: " + currentPageUrl, urls);

      setWaitingTime(options.pageReadyTimeout);
      pageReady = false;

      chrome.tabs.update(options.tabId, { url: currentPageUrl }, executeScript);

    } else {
      clearInterval(waiting);
      port.postMessage({ message: "Download Finished!" });
    }
  }

  port.onMessage.addListener(messageListener);
  port.onDisconnect.addListener(function() {
    console.log("Disconnect: ", port);

    if (waiting) clearInterval(waiting);
    port.onMessage.removeListener(messageListener);
    chrome.webRequest.onBeforeRequest.removeListener(webRequestListener);
  });
});

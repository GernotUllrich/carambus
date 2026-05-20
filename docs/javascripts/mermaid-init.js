// Mermaid-Initialisierung für mkdocs-material.
// Lädt Mermaid mit dem Theme passend zum aktuellen Material-Color-Scheme
// und re-rendert Diagramme bei Theme-Toggle (Dark/Light Mode).

(function () {
  function pickTheme() {
    var scheme = document.body.getAttribute("data-md-color-scheme");
    return scheme === "slate" ? "dark" : "default";
  }

  function renderAll() {
    if (typeof mermaid === "undefined") return;
    mermaid.initialize({
      startOnLoad: false,
      theme: pickTheme(),
      securityLevel: "loose"
    });
    var nodes = document.querySelectorAll(".mermaid:not([data-processed='true'])");
    if (nodes.length === 0) return;
    mermaid.run({ nodes: nodes });
  }

  // mkdocs-material reload-on-navigation: hooks ins document$-Observable
  if (typeof document$ !== "undefined" && typeof document$.subscribe === "function") {
    document$.subscribe(renderAll);
  } else {
    document.addEventListener("DOMContentLoaded", renderAll);
  }

  // Re-render bei Theme-Toggle
  var observer = new MutationObserver(function (mutations) {
    for (var i = 0; i < mutations.length; i++) {
      if (mutations[i].attributeName === "data-md-color-scheme") {
        // Theme gewechselt — bestehende Renders zurücksetzen und neu zeichnen
        document.querySelectorAll(".mermaid").forEach(function (el) {
          if (el.getAttribute("data-processed") === "true") {
            el.removeAttribute("data-processed");
            // Original-Source aus dem ersten Text-Node wiederherstellen wenn cached
            if (el.dataset.source) {
              el.innerHTML = el.dataset.source;
            }
          }
        });
        renderAll();
        break;
      }
    }
  });
  observer.observe(document.body, { attributes: true });
})();

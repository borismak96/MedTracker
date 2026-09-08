(function () {
  var storageKey = "pillpal-lang";

  function fromQuery() {
    try {
      var q = new URLSearchParams(window.location.search).get("lang");
      if (q === "en") return "en";
      if (q === "zh" || q === "zh-Hant" || q === "zh-TW") return "zh-Hant";
    } catch (e) {}
    return null;
  }

  function preferredLang() {
    var queryLang = fromQuery();
    if (queryLang) return queryLang;
    try {
      var saved = localStorage.getItem(storageKey);
      if (saved === "en" || saved === "zh-Hant") return saved;
    } catch (e) {}
    var nav = (navigator.language || navigator.userLanguage || "en").toLowerCase();
    return nav.indexOf("zh") === 0 ? "zh-Hant" : "en";
  }

  function applyLang(lang) {
    var value = lang === "zh-Hant" ? "zh-Hant" : "en";
    document.documentElement.setAttribute("data-lang", value);
    document.documentElement.setAttribute("lang", value === "zh-Hant" ? "zh-Hant" : "en");
    try {
      localStorage.setItem(storageKey, value);
    } catch (e) {}
    document.querySelectorAll("[data-set-lang]").forEach(function (button) {
      button.setAttribute("aria-pressed", button.getAttribute("data-set-lang") === value ? "true" : "false");
    });
  }

  applyLang(preferredLang());

  document.querySelectorAll("[data-set-lang]").forEach(function (button) {
    button.addEventListener("click", function () {
      applyLang(button.getAttribute("data-set-lang"));
      try {
        var url = new URL(window.location.href);
        url.searchParams.set("lang", button.getAttribute("data-set-lang") === "zh-Hant" ? "zh-Hant" : "en");
        history.replaceState({}, "", url);
      } catch (e) {}
    });
  });
})();

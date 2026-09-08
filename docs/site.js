(function () {
  var storageKey = "pillpal-lang";

  function preferredLang() {
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
    });
  });
})();

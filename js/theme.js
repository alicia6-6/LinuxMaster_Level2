(function () {
  var STORAGE_KEY = "theme";

  function systemPrefersDark() {
    return window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
  }

  function getSavedTheme() {
    try { return localStorage.getItem(STORAGE_KEY); } catch (e) { return null; }
  }

  function applyTheme(theme) {
    if (theme === "light" || theme === "dark") {
      document.documentElement.setAttribute("data-theme", theme);
    } else {
      document.documentElement.removeAttribute("data-theme");
    }
  }

  function currentEffectiveTheme() {
    var saved = getSavedTheme();
    if (saved === "light" || saved === "dark") return saved;
    return systemPrefersDark() ? "dark" : "light";
  }

  function updateToggleUI() {
    var btn = document.getElementById("themeToggle");
    if (!btn) return;
    var effective = currentEffectiveTheme();
    btn.textContent = effective === "dark" ? "☀️" : "🌙";
    var label = effective === "dark" ? "라이트 테마로 전환" : "다크 테마로 전환";
    btn.setAttribute("aria-label", label);
    btn.title = label;
  }

  function setTheme(theme) {
    try { localStorage.setItem(STORAGE_KEY, theme); } catch (e) {}
    applyTheme(theme);
    updateToggleUI();
  }

  document.addEventListener("DOMContentLoaded", function () {
    updateToggleUI();
    var btn = document.getElementById("themeToggle");
    if (btn) {
      btn.addEventListener("click", function () {
        setTheme(currentEffectiveTheme() === "dark" ? "light" : "dark");
      });
    }
  });

  if (window.matchMedia) {
    window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", function () {
      if (!getSavedTheme()) updateToggleUI();
    });
  }
})();

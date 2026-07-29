// 리눅스마스터 2급 암기장 - static web viewer
// Mirrors the Flutter app's behavior (lib/state, lib/screens) using
// localStorage instead of shared_preferences. No build step, no CDN deps.

(function () {
  "use strict";

  const CATEGORY_ICONS = {
    "리눅스개요": "ℹ️",
    "라이선스배포판": "⚖️",
    "설치파티션": "💾",
    "부팅부트로더": "⏻",
    "파일시스템": "🗂️",
    "사용자그룹관리": "👥",
    "파일디렉토리명령어": "📁",
    "텍스트처리명령어": "📄",
    "리다이렉션파이프": "🔀",
    "셸환경변수": "⌨️",
    "네트워크명령어": "🌐",
    "시스템관리": "⚙️",
    "기타": "🧩",
  };

  const PROGRESS_KEY = "lm2_progress_v1";
  const THEME_KEY = "lm2_theme_mode_v1";
  const LAST = { UNSEEN: 0, CORRECT: 1, WRONG: 2 };

  // ---------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------
  function loadProgress() {
    try {
      const raw = localStorage.getItem(PROGRESS_KEY);
      return raw ? JSON.parse(raw) : {};
    } catch (e) {
      return {};
    }
  }

  function saveProgress(progress) {
    try {
      localStorage.setItem(PROGRESS_KEY, JSON.stringify(progress));
    } catch (e) {
      /* ignore quota/availability errors (e.g. some file:// contexts) */
    }
  }

  function loadThemeMode() {
    try {
      return localStorage.getItem(THEME_KEY) || "system";
    } catch (e) {
      return "system";
    }
  }

  function saveThemeMode(mode) {
    try {
      localStorage.setItem(THEME_KEY, mode);
    } catch (e) {
      /* ignore */
    }
  }

  function applyTheme(mode) {
    const root = document.documentElement;
    if (mode === "light" || mode === "dark") {
      root.setAttribute("data-theme", mode);
    } else {
      root.removeAttribute("data-theme");
    }
  }

  // ---------------------------------------------------------------------
  // App-wide state (mirrors lib/state/app_state.dart)
  // ---------------------------------------------------------------------
  const state = {
    questions: QUESTIONS.slice(),
    progress: loadProgress(),
    themeMode: loadThemeMode(),
  };
  applyTheme(state.themeMode);

  function progressFor(id) {
    return state.progress[id] || { last: LAST.UNSEEN, correct: 0, wrong: 0, bookmark: false };
  }

  function ensureProgress(id) {
    if (!state.progress[id]) {
      state.progress[id] = { last: LAST.UNSEEN, correct: 0, wrong: 0, bookmark: false };
    }
    return state.progress[id];
  }

  function categoriesInOrder() {
    const seen = [];
    for (const q of state.questions) {
      if (!seen.includes(q.category)) seen.push(q.category);
    }
    return seen;
  }

  function questionsInCategory(cat) {
    return state.questions.filter((q) => q.category === cat);
  }

  function wrongQuestions() {
    return state.questions.filter((q) => progressFor(q.id).last === LAST.WRONG);
  }

  function bookmarkedQuestions() {
    return state.questions.filter((q) => progressFor(q.id).bookmark);
  }

  function totalCount() {
    return state.questions.length;
  }

  function solvedCount() {
    return Object.values(state.progress).filter((p) => p.last !== LAST.UNSEEN).length;
  }

  function correctCount() {
    return Object.values(state.progress).filter((p) => p.last === LAST.CORRECT).length;
  }

  function overallAccuracy() {
    const s = solvedCount();
    return s === 0 ? 0 : correctCount() / s;
  }

  function statFor(cat) {
    const qs = questionsInCategory(cat);
    let solved = 0;
    let correct = 0;
    for (const q of qs) {
      const p = progressFor(q.id);
      if (p.last !== LAST.UNSEEN) solved++;
      if (p.last === LAST.CORRECT) correct++;
    }
    return { category: cat, total: qs.length, solved, correct };
  }

  function recordAnswer(id, wasCorrect) {
    const p = ensureProgress(id);
    p.last = wasCorrect ? LAST.CORRECT : LAST.WRONG;
    if (wasCorrect) p.correct++;
    else p.wrong++;
    saveProgress(state.progress);
  }

  function toggleBookmark(id) {
    const p = ensureProgress(id);
    p.bookmark = !p.bookmark;
    saveProgress(state.progress);
  }

  function hasOptions(q) {
    return Array.isArray(q.options) && q.options.length > 0;
  }

  function shuffle(arr) {
    const a = arr.slice();
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  }

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  // ---------------------------------------------------------------------
  // SmartText equivalent: renders multi-line text, treating shell-command /
  // path-looking lines as a monospace "code block" (mirrors
  // lib/widgets/smart_text.dart).
  // ---------------------------------------------------------------------
  const CODE_HINT = /^[#$[].*|.*[@~].*|^[a-zA-Z_./-]+\s*[-[].*|^\s*[①②③④⑤].*/;

  function looksLikeCode(line) {
    const trimmed = line.trim();
    if (!trimmed) return false;
    const koreanChars = (trimmed.match(/[가-힣]/g) || []).length;
    const ratio = koreanChars / trimmed.length;
    if (ratio > 0.35) return false;
    if (
      trimmed.startsWith("#") ||
      trimmed.startsWith("$") ||
      trimmed.startsWith("[") ||
      trimmed.includes("@") ||
      trimmed.includes("/etc/") ||
      trimmed.includes("/dev/") ||
      trimmed.includes("->")
    ) {
      return true;
    }
    return CODE_HINT.test(trimmed) && ratio < 0.2;
  }

  function smartTextHtml(text) {
    const lines = text.split("\n");
    const out = [];
    let codeBuffer = null;

    function flushCode() {
      if (!codeBuffer || codeBuffer.length === 0) return;
      out.push(`<div class="smart-code">${escapeHtml(codeBuffer.join("\n"))}</div>`);
      codeBuffer = null;
    }

    for (const line of lines) {
      if (looksLikeCode(line)) {
        (codeBuffer = codeBuffer || []).push(line);
      } else {
        flushCode();
        if (line.trim() === "") {
          out.push('<div style="height:6px"></div>');
        } else {
          out.push(`<p class="smart-line">${escapeHtml(line)}</p>`);
        }
      }
    }
    flushCode();
    return out.join("");
  }

  // ---------------------------------------------------------------------
  // Ring progress SVG (mirrors lib/widgets/progress_ring.dart)
  // ---------------------------------------------------------------------
  function ringHtml(value, size, label, onPrimary) {
    const stroke = size >= 120 ? 12 : 10;
    const r = (size - stroke) / 2;
    const c = 2 * Math.PI * r;
    const v = Math.max(0, Math.min(1, value));
    const dash = c * v;
    const pctFont = Math.round(size * 0.22);
    const capFont = Math.max(10, Math.round(size * 0.1));
    return `
      <div class="ring${onPrimary ? " on-primary" : ""}" style="width:${size}px;height:${size}px">
        <svg width="${size}" height="${size}">
          <circle cx="${size / 2}" cy="${size / 2}" r="${r}" stroke="${onPrimary ? "rgba(255,255,255,0.35)" : "var(--surface-container-highest)"}" stroke-width="${stroke}" fill="none" />
          <circle cx="${size / 2}" cy="${size / 2}" r="${r}" stroke="${onPrimary ? "#fff" : "var(--primary)"}" stroke-width="${stroke}" fill="none"
            stroke-linecap="round" stroke-dasharray="${dash} ${c}" />
        </svg>
        <div class="ring-label" style="font-size:${pctFont}px">
          <span class="ring-pct">${Math.round(v * 100)}%</span>
          ${label ? `<span class="ring-caption" style="font-size:${capFont}px">${label}</span>` : ""}
        </div>
      </div>`;
  }

  // ---------------------------------------------------------------------
  // Router / rendering
  // ---------------------------------------------------------------------
  const app = document.getElementById("app");
  let quizSession = null; // active quiz session object while in quiz view

  function go(view) {
    if (view === "home") renderHome();
  }

  // ---- Home -------------------------------------------------------------
  function renderHome() {
    quizSession = null;
    const cats = categoriesInOrder();
    const solved = solvedCount();
    const total = totalCount();
    const ratio = total === 0 ? 0 : solved / total;

    app.innerHTML = `
      <div class="appbar">
        <h1>리눅스마스터 2급 암기장</h1>
        <button class="icon-btn" id="theme-btn" title="테마">🌗</button>
      </div>

      <div class="hero-card">
        ${ringHtml(ratio, 96, "학습률", true)}
        <div class="hero-text">
          <p class="hero-title">${solved} / ${total} 문항 학습</p>
          <p class="hero-sub">정답률 ${Math.round(overallAccuracy() * 100)}%</p>
          <p class="hero-msg">${solved === 0 ? "오늘부터 시작해볼까요? 🐧" : "꾸준히 잘하고 있어요!"}</p>
        </div>
      </div>

      <div class="actions-row">
        <button class="action-btn" id="btn-all" style="background:var(--primary);color:var(--on-primary)">
          <span class="a-icon">🔀</span>
          <span class="a-text">
            <span class="a-label">전체 학습</span>
            <span class="a-sub">${total}문항 랜덤</span>
          </span>
        </button>
        <button class="action-btn" id="btn-wrong" style="background:var(--error-container);color:var(--on-error-container)">
          <span class="a-icon">⚠️</span>
          <span class="a-text">
            <span class="a-label">오답노트</span>
            <span class="a-sub">${wrongQuestions().length}문항</span>
          </span>
        </button>
      </div>
      <div class="action-btn-wrap">
        <button class="action-btn-wide" id="btn-bookmark" style="background:var(--tertiary-container);color:var(--on-tertiary-container)">
          <span class="a-icon">⭐</span>
          <span class="a-text">
            <span class="a-label">즐겨찾기</span>
            <span class="a-sub">북마크한 ${bookmarkedQuestions().length}문항 복습하기</span>
          </span>
        </button>
      </div>

      <div class="cat-heading">카테고리별 학습</div>
      <div class="cat-grid">
        ${cats
          .map((cat) => {
            const stat = statFor(cat);
            const pct = stat.total === 0 ? 0 : (stat.solved / stat.total) * 100;
            return `
            <button class="cat-card" data-cat="${escapeHtml(cat)}">
              <div class="cat-icon-box">${CATEGORY_ICONS[cat] || "🧩"}</div>
              <div class="cat-name">${escapeHtml(cat)}</div>
              <div class="cat-count">${stat.solved}/${stat.total}문항</div>
              <div class="cat-bar"><div class="cat-bar-fill" style="width:${pct}%"></div></div>
            </button>`;
          })
          .join("")}
      </div>
    `;

    document.getElementById("theme-btn").onclick = showThemeSheet;
    document.getElementById("btn-all").onclick = () => startSession(state.questions, "전체 학습");
    document.getElementById("btn-wrong").onclick = () => startSession(wrongQuestions(), "오답노트");
    document.getElementById("btn-bookmark").onclick = () => startSession(bookmarkedQuestions(), "즐겨찾기");
    app.querySelectorAll(".cat-card").forEach((btn) => {
      btn.onclick = () => {
        const cat = btn.getAttribute("data-cat");
        startSession(questionsInCategory(cat), cat);
      };
    });
  }

  function showThemeSheet() {
    const wrap = document.createElement("div");
    wrap.className = "theme-sheet";
    wrap.innerHTML = `
      <div class="theme-sheet-inner">
        ${themeTile("system", "시스템 기본", "📱")}
        ${themeTile("light", "라이트 모드", "☀️")}
        ${themeTile("dark", "다크 모드", "🌙")}
      </div>`;
    wrap.addEventListener("click", (e) => {
      if (e.target === wrap) wrap.remove();
    });
    document.body.appendChild(wrap);
    wrap.querySelectorAll("[data-mode]").forEach((btn) => {
      btn.onclick = () => {
        state.themeMode = btn.getAttribute("data-mode");
        saveThemeMode(state.themeMode);
        applyTheme(state.themeMode);
        wrap.remove();
      };
    });
  }

  function themeTile(mode, label, icon) {
    const selected = state.themeMode === mode;
    return `<button class="theme-tile" data-mode="${mode}">
      <span>${icon}</span><span>${label}</span>
      ${selected ? '<span class="t-check">✓</span>' : ""}
    </button>`;
  }

  // ---- Quiz session -------------------------------------------------------
  function startSession(questions, title) {
    if (!questions || questions.length === 0) {
      alert("아직 문제가 없어요.");
      return;
    }
    quizSession = {
      title,
      queue: shuffle(questions),
      index: 0,
      selected: null,
      answered: false,
      correct: 0,
      missed: [],
    };
    renderQuiz();
  }

  function qsCurrent() {
    return quizSession.queue[quizSession.index];
  }

  function selectOption(optionIndex) {
    if (quizSession.answered || !hasOptions(qsCurrent())) return;
    quizSession.selected = optionIndex;
    quizSession.answered = true;
    const correct = optionIndex === qsCurrent().answerIndex;
    if (correct) quizSession.correct++;
    else quizSession.missed.push(qsCurrent());
    recordAnswer(qsCurrent().id, correct);
    renderQuiz();
  }

  function revealAnswer() {
    if (quizSession.answered) return;
    quizSession.answered = true;
    renderQuiz();
  }

  function selfGrade(wasCorrect) {
    if (!quizSession.answered) return;
    if (wasCorrect) quizSession.correct++;
    else quizSession.missed.push(qsCurrent());
    recordAnswer(qsCurrent().id, wasCorrect);
    renderQuiz();
  }

  function quizNext() {
    if (quizSession.index >= quizSession.queue.length - 1) {
      renderResult();
      return;
    }
    quizSession.index++;
    quizSession.selected = null;
    quizSession.answered = false;
    renderQuiz();
  }

  function confirmExit() {
    if (quizSession.index === 0 && !quizSession.answered) {
      renderHome();
      return;
    }
    const backdrop = document.createElement("div");
    backdrop.className = "exit-dialog-backdrop";
    backdrop.innerHTML = `
      <div class="exit-dialog">
        <h3>학습을 종료할까요?</h3>
        <p>지금까지의 정답/오답 기록은 저장돼요.</p>
        <div class="dialog-actions">
          <button id="dlg-cancel">계속하기</button>
          <button id="dlg-ok" class="filled">종료</button>
        </div>
      </div>`;
    document.body.appendChild(backdrop);
    backdrop.querySelector("#dlg-cancel").onclick = () => backdrop.remove();
    backdrop.querySelector("#dlg-ok").onclick = () => {
      backdrop.remove();
      renderHome();
    };
  }

  function optionStateClass(i) {
    if (!quizSession.answered) return "";
    if (i === qsCurrent().answerIndex) return "correct";
    if (i === quizSession.selected) return "wrong-selected";
    return "wrong-dim";
  }

  const OPTION_LABELS = ["①", "②", "③", "④", "⑤"];

  function renderQuiz() {
    const q = qsCurrent();
    const lines = q.question.split("\n");
    const firstLine = lines[0];
    const rest = lines.slice(1).join("\n");
    const canAdvance =
      quizSession.answered &&
      (hasOptions(q) || quizSession.correct + quizSession.missed.length >= quizSession.index + 1);

    app.innerHTML = `
      <div class="appbar">
        <button class="icon-btn" id="quiz-close">✕</button>
        <h1 style="font-size:17px">${escapeHtml(quizSession.title)}</h1>
        <button class="icon-btn" id="quiz-bookmark">${progressFor(q.id).bookmark ? "⭐" : "☆"}</button>
      </div>
      <div class="quiz-header">
        <div class="quiz-progress-bar"><div class="quiz-progress-fill" style="width:${(quizSession.index / quizSession.queue.length) * 100}%"></div></div>
        <span class="quiz-count">${quizSession.index + 1} / ${quizSession.queue.length}</span>
      </div>
      <div class="quiz-body">
        <span class="chip">${escapeHtml(q.category)}</span>
        <p class="q-text">${escapeHtml(firstLine)}</p>
        ${rest ? `<div class="q-detail">${smartTextHtml(rest)}</div>` : ""}
        <div class="options">
          ${
            hasOptions(q)
              ? q.options
                  .map(
                    (opt, i) => `
              <button class="option ${optionStateClass(i)}" data-i="${i}" ${quizSession.answered ? "disabled" : ""}>
                <span class="opt-label">${OPTION_LABELS[i] || i + 1 + "."}</span>
                <span class="opt-text">${escapeHtml(opt)}</span>
                ${
                  quizSession.answered && i === q.answerIndex
                    ? '<span class="opt-icon">✅</span>'
                    : quizSession.answered && i === quizSession.selected && i !== q.answerIndex
                      ? '<span class="opt-icon">❌</span>'
                      : ""
                }
              </button>`
                  )
                  .join("")
              : shortAnswerHtml(q)
          }
        </div>
        ${quizSession.answered ? explanationHtml(q) : ""}
      </div>
      <div class="quiz-bottom">
        <button class="btn-primary" id="quiz-next" ${canAdvance ? "" : "disabled"}>
          ${quizSession.index >= quizSession.queue.length - 1 ? "결과 보기" : "다음 문제"}
        </button>
      </div>
    `;

    document.getElementById("quiz-close").onclick = confirmExit;
    document.getElementById("quiz-bookmark").onclick = () => {
      toggleBookmark(q.id);
      renderQuiz();
    };
    document.getElementById("quiz-next").onclick = quizNext;
    if (hasOptions(q)) {
      app.querySelectorAll(".option").forEach((btn) => {
        btn.onclick = () => selectOption(parseInt(btn.getAttribute("data-i"), 10));
      });
    } else if (!quizSession.answered) {
      const revealBtn = document.getElementById("reveal-btn");
      if (revealBtn) revealBtn.onclick = revealAnswer;
    } else {
      const wrongBtn = document.getElementById("sg-wrong");
      const rightBtn = document.getElementById("sg-right");
      if (wrongBtn) wrongBtn.onclick = () => selfGrade(false);
      if (rightBtn) rightBtn.onclick = () => selfGrade(true);
    }
  }

  function shortAnswerHtml(q) {
    if (!quizSession.answered) {
      return `<button class="reveal-btn" id="reveal-btn">👁 정답 확인하기</button>`;
    }
    return `
      <div class="answer-card">
        <span class="a-tag">정답</span>
        <span class="a-val">${escapeHtml(q.answerText)}</span>
      </div>`;
  }

  function explanationHtml(q) {
    const body = q.explanation && q.explanation.trim()
      ? `<div class="e-body">${smartTextHtml(q.explanation)}</div>`
      : `<div class="e-empty">이 문제는 별도 해설이 제공되지 않았어요. 정답을 기준으로 관련 명령어/개념을 다시 확인해보세요.</div>`;
    const needsSelfGrade = !hasOptions(q);
    return `
      <div class="explain-card">
        <div class="e-head">💡 해설</div>
        ${body}
        ${
          needsSelfGrade
            ? `<div class="self-grade">
                <span class="sg-label">맞혔나요?</span>
                <div class="sg-row">
                  <button class="sg-btn" id="sg-wrong">✕ 틀렸어요</button>
                  <button class="sg-btn primary" id="sg-right">✓ 맞혔어요</button>
                </div>
              </div>`
            : ""
        }
      </div>`;
  }

  // ---- Result -------------------------------------------------------------
  function messageFor(ratio) {
    if (ratio >= 0.9) return "완벽해요! 🎉";
    if (ratio >= 0.7) return "좋아요, 거의 다 왔어요!";
    if (ratio >= 0.4) return "조금만 더 복습해봐요";
    return "오답노트로 다시 정리해봐요";
  }

  function renderResult() {
    const session = quizSession;
    const total = session.correct + session.missed.length;
    const ratio = total === 0 ? 0 : session.correct / total;

    app.innerHTML = `
      <div class="appbar">
        <h1>${escapeHtml(session.title)} 결과</h1>
      </div>
      <div class="result-body">
        <div class="result-center">
          ${ringHtml(ratio, 140, "정답률", false)}
          <p class="result-msg">${messageFor(ratio)}</p>
          <p class="result-sub">${total}문항 중 ${session.correct}개 정답</p>
        </div>
        <div class="stat-row">
          <div class="stat-chip" style="background:color-mix(in srgb, var(--correct) 12%, transparent);color:var(--correct)">
            <div class="s-icon">✅</div>
            <span class="s-value">${session.correct}</span>
            <span class="s-label">정답</span>
          </div>
          <div class="stat-chip" style="background:color-mix(in srgb, var(--wrong) 12%, transparent);color:var(--wrong)">
            <div class="s-icon">❌</div>
            <span class="s-value">${session.missed.length}</span>
            <span class="s-label">오답</span>
          </div>
        </div>
        ${
          session.missed.length > 0
            ? `<div class="missed-heading">틀린 문제 다시보기</div>
               ${session.missed
                 .map(
                   (q) => `
                <div class="missed-card">
                  <p class="m-q">${escapeHtml(q.question.split("\n")[0])}</p>
                  <p class="m-a">정답: ${escapeHtml(q.answerText)}</p>
                </div>`
                 )
                 .join("")}`
            : ""
        }
        <div class="result-actions">
          <button class="btn-outline" id="res-home">홈으로</button>
          ${session.missed.length > 0 ? `<button class="btn-primary" id="res-retry">오답만 다시 풀기</button>` : ""}
        </div>
      </div>
    `;

    document.getElementById("res-home").onclick = renderHome;
    const retryBtn = document.getElementById("res-retry");
    if (retryBtn) {
      retryBtn.onclick = () => startSession(session.missed, `${session.title} · 오답 다시풀기`);
    }
  }

  // ---------------------------------------------------------------------
  renderHome();
})();

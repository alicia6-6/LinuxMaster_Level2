// 문제 데이터 로딩 및 공통 유틸리티
const DATA_URL = "data/questions.json";
const WRONG_NOTE_KEY = "lm2_wrong_note_v1";
const EXAM_HISTORY_KEY = "lm2_exam_history_v1";

let _cache = null;

async function loadQuestionBank() {
  if (_cache) return _cache;
  const res = await fetch(DATA_URL, { cache: "no-store" });
  if (!res.ok) throw new Error("문제 데이터를 불러오지 못했습니다.");
  const json = await res.json();
  _cache = json;
  return json;
}

function normalizeText(str) {
  return String(str || "")
    .replace(/[！-～]/g, (ch) => String.fromCharCode(ch.charCodeAt(0) - 0xfee0)) // 전각(full-width) 문자 -> 반각
    .replace(/[‐-―−]/g, "-") // en-dash/em-dash/minus 등 다양한 대시 -> 하이픈
    .replace(/\s+/g, "")
    .replace(/[.,·・\-()\[\]{}'"“”‘’!?~%]/g, "")
    .toLowerCase();
}

function levenshtein(a, b) {
  const m = a.length;
  const n = b.length;
  if (!m) return n;
  if (!n) return m;
  let prev = Array.from({ length: n + 1 }, (_, j) => j);
  for (let i = 1; i <= m; i++) {
    const curr = [i];
    for (let j = 1; j <= n; j++) {
      curr[j] = a[i - 1] === b[j - 1] ? prev[j - 1] : 1 + Math.min(prev[j - 1], prev[j], curr[j - 1]);
    }
    prev = curr;
  }
  return prev[n];
}

function textSimilarity(a, b) {
  const d = levenshtein(a, b);
  const len = Math.max(a.length, b.length) || 1;
  return 1 - d / len;
}

// 정답 텍스트가 실질적으로 같은지 판별한다.
// 단축키([Ctrl]+[c] vs [Ctrl]+[z]), 숫자(포트/IP/시그널 번호), 짧은 명령어/옵션(csh vs tcsh, df vs du)은
// 한 글자 차이로 완전히 다른 의미이므로 정확히 일치해야 하고,
// 긴 인명/외래어("리처드 스톨먼" vs "리처드 스톨만") 등은 편집 거리 1 이내의 표기 차이를 허용한다.
function isSameAnswer(ansA, ansB) {
  const na = normalizeText(ansA);
  const nb = normalizeText(ansB);
  if (!na || !nb) return false;
  if (na === nb) return true;
  if (na.includes("ctrl") || nb.includes("ctrl")) return false;
  if (/\d/.test(na) || /\d/.test(nb)) return na === nb;
  if (na.length <= 5 || nb.length <= 5) return false;
  const d = levenshtein(na, nb);
  return d <= 1 && na.length >= 6;
}

// 두 문제가 실질적으로 같은 문제(재출제)인지 판별한다.
// 1. 같은 회차의 문제는 중복으로 보지 않는다.
// 2. 정답 내용이 실질적으로 같아야 한다.
// 3. 지문(imageText)이 있는 경우 지문의 유사도를 함께 비교하고,
//    텍스트 문제의 경우 문장 표현의 유사도를 유연하게 비교한다.
function isSameQuestion(qa, qb) {
  if (qa.round === qb.round) return false;

  const ansA = (qa.choices || [])[qa.answer - 1] || "";
  const ansB = (qb.choices || [])[qb.answer - 1] || "";
  if (!isSameAnswer(ansA, ansB)) return false;

  const nqa = qa._nq || normalizeText(qa.question);
  const nqb = qb._nq || normalizeText(qb.question);

  const hasItA = Boolean(qa.imageText);
  const hasItB = Boolean(qb.imageText);

  if (hasItA && hasItB) {
    const itA = qa._nit || normalizeText(qa.imageText);
    const itB = qb._nit || normalizeText(qb.imageText);
    const itSim = textSimilarity(itA, itB);
    const qSim = textSimilarity(nqa, nqb);
    return itSim >= 0.65 || (qSim >= 0.85 && itSim >= 0.35);
  }

  if (!hasItA && !hasItB) {
    const qSim = textSimilarity(nqa, nqb);
    return qSim >= 0.68;
  }

  const it = qa._nit || qb._nit || normalizeText(qa.imageText || qb.imageText);
  const qText = hasItA ? nqb : nqa;
  return textSimilarity(it, qText) >= 0.65;
}

let _clusterCache = null;
let _clusterCacheSource = null;

// Disjoint-Set(Union-Find)을 이용해 전체 문제 은행을 유사 문제 클러스터로 그룹화한다.
function getClusters(questions) {
  if (_clusterCache && _clusterCacheSource === questions) return _clusterCache;
  const n = questions.length;
  const pre = questions.map((q) => ({
    ...q,
    _nq: normalizeText(q.question),
    _nit: normalizeText(q.imageText || ""),
  }));

  const parent = Array.from({ length: n }, (_, i) => i);
  function find(i) { return parent[i] === i ? i : (parent[i] = find(parent[i])); }
  function union(i, j) { parent[find(i)] = find(j); }

  for (let i = 0; i < n; i++) {
    for (let j = i + 1; j < n; j++) {
      if (isSameQuestion(pre[i], pre[j])) {
        union(i, j);
      }
    }
  }

  const clusters = new Map();
  for (let i = 0; i < n; i++) {
    const root = find(i);
    if (!clusters.has(root)) clusters.set(root, []);
    clusters.get(root).push(questions[i]);
  }

  _clusterCache = clusters;
  _clusterCacheSource = questions;
  return clusters;
}

// 2회 이상 출제된 빈출 문제를 추출한다.
function getFrequentQuestions(questions, minCount = 2) {
  const clusters = getClusters(questions);
  const result = [];
  clusters.forEach((members) => {
    const rounds = [...new Set(members.map((q) => q.round))];
    if (rounds.length < minCount) return;
    const sorted = [...members].sort((a, b) => (a.round > b.round ? 1 : -1));
    const rep = sorted[sorted.length - 1];
    result.push({
      ...rep,
      freqCount: rounds.length,
      freqRounds: rounds,
    });
  });
  result.sort((a, b) => b.freqCount - a.freqCount);
  return result;
}

// 같은 문제가 여러 회차에 중복 출제된 경우 최신 1개만 남겨 랜덤 모드에서 중복 출제를 방지한다.
function dedupeQuestions(questions) {
  const clusters = getClusters(questions);
  const result = [];
  clusters.forEach((members) => {
    const sorted = [...members].sort((a, b) => (a.round > b.round ? 1 : -1));
    result.push(sorted[sorted.length - 1]);
  });
  return result;
}

function getRounds(questions) {
  const set = new Set(questions.map((q) => q.round));
  return [...set].sort();
}

function shuffle(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

// ---- 오답노트 (localStorage) ----
function loadWrongNote() {
  try {
    return JSON.parse(localStorage.getItem(WRONG_NOTE_KEY) || "{}");
  } catch {
    return {};
  }
}

function saveWrongNote(note) {
  localStorage.setItem(WRONG_NOTE_KEY, JSON.stringify(note));
}

function markAnswerResult(question, isCorrect) {
  const note = loadWrongNote();
  if (isCorrect) {
    if (note[question.id]) delete note[question.id];
  } else {
    note[question.id] = { ...question, missedAt: new Date().toISOString() };
  }
  saveWrongNote(note);
}

function getWrongQuestions() {
  const note = loadWrongNote();
  return Object.values(note);
}

function clearWrongNote() {
  saveWrongNote({});
}

// ---- 모의고사 응시 기록 (localStorage) ----
function loadExamHistory() {
  try {
    return JSON.parse(localStorage.getItem(EXAM_HISTORY_KEY) || "[]");
  } catch {
    return [];
  }
}

function saveExamAttempt(entry) {
  const history = loadExamHistory();
  history.unshift(entry);
  localStorage.setItem(EXAM_HISTORY_KEY, JSON.stringify(history.slice(0, 200)));
}

function getExamAttempts(round) {
  const history = loadExamHistory();
  return round ? history.filter((e) => e.round === round) : history;
}

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

// 보기 순서가 회차마다 다를 수 있으므로, A의 각 보기를 B에서 가장 비슷한 보기와 짝지어
// 평균 유사도를 낸다(순서 무관 비교).
function choiceSetSimilarity(choicesA, choicesB) {
  const normA = choicesA.map(normalizeText);
  const normB = choicesB.map(normalizeText);
  if (!normA.length) return 0;
  const total = normA.reduce((sum, a) => sum + normB.reduce((max, b) => Math.max(max, textSimilarity(a, b)), 0), 0);
  return total / normA.length;
}

function bestMatchIndex(target, list) {
  let bestIdx = -1;
  let best = -1;
  list.forEach((item, i) => {
    const s = textSimilarity(target, item);
    if (s > best) { best = s; bestIdx = i; }
  });
  return bestIdx;
}

// bestMatchIndex는 아무리 약한 유사도라도 "그나마 가장 비슷한" 항목의 인덱스를 항상 돌려준다.
// 보기가 셸/파일시스템/편집기 이름처럼 짧은 전문 용어일 때는 이게 오히려 함정이 된다.
// 예를 들어 "csh"는 "tcsh"와 글자가 겨우 하나 달라 얼핏 비슷해 보이지만(유사도 0.75) 실제로는
// 전혀 다른 셸이다. 그래서 정답이 정말 같은 항목을 가리키는지 확인할 때는 최소 유사도
// 기준(ANSWER_MATCH_THRESHOLD)을 만족 못 하면 매칭 자체를 포기(-1)하도록 강화한 버전을 쓴다.
const ANSWER_MATCH_THRESHOLD = 0.92;

function bestMatchIndexStrict(target, list) {
  let bestIdx = -1;
  let best = -1;
  list.forEach((item, i) => {
    const s = textSimilarity(target, item);
    if (s > best) { best = s; bestIdx = i; }
  });
  return best >= ANSWER_MATCH_THRESHOLD ? bestIdx : -1;
}

const NEAR_DUP_THRESHOLD = 0.7;

// 오탈자/띄어쓰기/용어 표기만 살짝 다르게 재출제된 문제를 잡아낸다. 문제 문장이 완전히
// 같은 것끼리만 비교해(우연히 같은 문장 틀을 재사용한 서로 다른 문제와 섞이지 않도록),
// 보기 내용이 실질적으로 같고(threshold 이상) 정답 위치도 서로 대응할 때만 중복으로 본다.
function dedupeNearMatches(questions) {
  const groups = new Map();
  questions.forEach((q) => {
    const key = normalizeText(q.question);
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(q);
  });

  const drop = new Set();
  groups.forEach((group) => {
    if (group.length < 2) return;
    for (let i = 0; i < group.length; i++) {
      if (drop.has(group[i].id)) continue;
      for (let j = i + 1; j < group.length; j++) {
        if (drop.has(group[j].id)) continue;
        const simScore = choiceSetSimilarity(group[i].choices || [], group[j].choices || []);
        if (simScore < NEAR_DUP_THRESHOLD) continue;
        const answerA = normalizeText((group[i].choices || [])[group[i].answer - 1] || "");
        const matchIdx = bestMatchIndexStrict(answerA, (group[j].choices || []).map(normalizeText));
        if (matchIdx !== group[j].answer - 1) continue; // 정답 위치가 안 맞으면 실제로는 다른 문제
        drop.add(group[j].id);
      }
    }
  });

  return questions.filter((q) => !drop.has(q.id));
}

// 동일/유사 문제를 하나의 그룹으로 묶어 출제 빈도를 계산한다.
function groupByFrequency(questions) {
  const groups = new Map();
  questions.forEach((q) => {
    const key = normalizeText(q.question);
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(q);
  });
  return groups;
}

// 문제 텍스트만 같다고 같은 문제로 보지 않는다. 특히 이미지에 실제 내용이 들어있고
// 지문은 "다음 ( 괄호 ) 안에 들어갈 내용으로 알맞은 것은?"처럼 매우 일반적인 문제가 많아,
// 텍스트만으로 묶으면 서로 전혀 다른 문제들이 하나의 "빈출문제"로 잘못 뭉쳐진다. 그래서
// 텍스트가 같은 그룹 안에서도 보기 구성이 실질적으로 비슷하고(dedupeNearMatches와 동일한
// 유사도 기준) 정답 위치까지 대응하는 것들끼리만 다시 소그룹으로 묶는다.
function clusterByChoices(arr) {
  const clusters = [];
  arr.forEach((q) => {
    const qAnswerText = normalizeText((q.choices || [])[q.answer - 1] || "");
    const cluster = clusters.find((c) => {
      const rep = c[0];
      if (choiceSetSimilarity(q.choices || [], rep.choices || []) < NEAR_DUP_THRESHOLD) return false;
      const repMatchIdx = bestMatchIndexStrict(qAnswerText, (rep.choices || []).map(normalizeText));
      return repMatchIdx === rep.answer - 1;
    });
    if (cluster) cluster.push(q);
    else clusters.push([q]);
  });
  return clusters;
}

function getFrequentQuestions(questions, minCount = 2) {
  const groups = groupByFrequency(questions);
  const result = [];
  groups.forEach((arr) => {
    if (arr.length < minCount) return;
    clusterByChoices(arr).forEach((cluster) => {
      if (cluster.length < minCount) return;
      const sorted = [...cluster].sort((a, b) => (a.round > b.round ? 1 : -1));
      const rep = sorted[sorted.length - 1];
      result.push({
        ...rep,
        freqCount: cluster.length,
        freqRounds: [...new Set(cluster.map((a) => a.round))],
      });
    });
  });
  result.sort((a, b) => b.freqCount - a.freqCount);
  return result;
}

// 같은 문제가 여러 회차에 그대로 재출제된 경우(보기 순서만 다를 수 있음) 랜덤 모드에서
// 한 번만 나오도록 걸러낸다. 빈출문제/회차별 모의고사는 회차별 원본 데이터가 그대로 있어야
// 하므로 이 함수는 원본 배열을 바꾸지 않고 별도 목록만 만들어 반환한다.
function dedupeQuestions(questions) {
  const seen = new Set();
  const exact = [];
  questions.forEach((q) => {
    const key = normalizeText(q.question) + "|" + (q.choices || []).map(normalizeText).sort().join(",");
    if (seen.has(key)) return;
    seen.add(key);
    exact.push(q);
  });
  return dedupeNearMatches(exact);
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

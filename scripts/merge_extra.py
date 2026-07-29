# -*- coding: utf-8 -*-
"""
Merges additional PDF-mined questions (pdf_extra_part1.json / pdf_extra_part2.json)
into the existing linux_master2/assets/data/questions.json, deduplicating
against what's already there and against each other.
"""
import json
import re

BASE_PATH = r"c:/Users/min/Desktop/LinuxMaster_Level2/linux_master2/assets/data/questions.json"
EXTRA_PATHS = [
    r"c:/Users/min/Desktop/LinuxMaster_Level2/scripts/pdf_extra_part1.json",
    r"c:/Users/min/Desktop/LinuxMaster_Level2/scripts/pdf_extra_part2.json",
]

VALID_CATEGORIES = {
    "리눅스개요", "라이선스배포판", "설치파티션", "부팅부트로더", "파일시스템",
    "사용자그룹관리", "파일디렉토리명령어", "텍스트처리명령어", "리다이렉션파이프",
    "셸환경변수", "네트워크명령어", "시스템관리", "기타",
}


def normalize(text: str) -> str:
    t = re.sub(r"\s+", "", text)
    t = re.sub(r"[.,?!()\[\]{}~\-:;\"'‘’“”]", "", t)
    return t.lower()


def load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def main():
    base = load_json(BASE_PATH)
    seen_norm = {normalize(q["question"]): q for q in base}

    added = []
    skipped_dupe = 0
    skipped_bad = 0
    per_file_counts = {}

    for path in EXTRA_PATHS:
        try:
            items = load_json(path)
        except FileNotFoundError:
            print(f"MISSING: {path}")
            continue
        count_this_file = 0
        for it in items:
            q = (it.get("question") or "").strip()
            if not q:
                skipped_bad += 1
                continue
            options = it.get("options") or []
            answer_index = it.get("answerIndex", -1)
            answer_text = (it.get("answerText") or "").strip()
            category = it.get("category") or "기타"
            if category not in VALID_CATEGORIES:
                category = "기타"

            if options and (not isinstance(answer_index, int) or not (0 <= answer_index < len(options))):
                skipped_bad += 1
                continue
            if options:
                answer_text = options[answer_index]
            if not options and not answer_text:
                skipped_bad += 1
                continue

            key = normalize(q)
            if key in seen_norm:
                skipped_dupe += 1
                continue

            new_item = {
                "id": "",  # assigned later
                "category": category,
                "question": q,
                "options": [str(o) for o in options],
                "answerIndex": answer_index if options else -1,
                "answerText": answer_text,
                "explanation": (it.get("explanation") or "").strip(),
            }
            added.append(new_item)
            seen_norm[key] = new_item
            count_this_file += 1
        per_file_counts[path] = count_this_file

    merged = base + added
    for n, item in enumerate(merged, 1):
        item["id"] = f"q-{n:04d}"

    with open(BASE_PATH, "w", encoding="utf-8") as f:
        json.dump(merged, f, ensure_ascii=False, indent=2)

    report = [
        f"base_count={len(base)}",
        f"added={len(added)}",
        f"skipped_dupe={skipped_dupe}",
        f"skipped_bad={skipped_bad}",
        f"final_count={len(merged)}",
        f"per_file={per_file_counts}",
    ]
    cats = {}
    for it in merged:
        cats[it["category"]] = cats.get(it["category"], 0) + 1
    report.append(f"categories={cats}")

    with open(
        r"C:/Users/min/AppData/Local/Temp/claude/c--Users-min-Desktop-LinuxMaster-Level2/dd41fba1-8486-4eed-8e2a-1fd34dad436f/scratchpad/merge_report.txt",
        "w", encoding="utf-8",
    ) as f:
        f.write("\n".join(report))
    print("\n".join(report))


if __name__ == "__main__":
    main()

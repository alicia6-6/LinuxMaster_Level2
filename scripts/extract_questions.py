# -*- coding: utf-8 -*-
"""
Parses the cleaned linux_master_2.html text dump into structured quiz JSON
for the Flutter study app.

Strategy: anchor blocks on "정답" (answer) lines, since digit+period patterns
(question numbering) collide with IP addresses / timestamps / traceroute hop
numbers that appear inside question bodies. Circled-number option markers
(①②③④) are essentially unambiguous.
"""
import json
import re
import sys

SRC = r"C:/Users/min/AppData/Local/Temp/claude/c--Users-min-Desktop-LinuxMaster-Level2/dd41fba1-8486-4eed-8e2a-1fd34dad436f/scratchpad/linux_master_2_clean.txt"
OUT = r"c:/Users/min/Desktop/LinuxMaster_Level2/linux_master2/assets/data/questions.json"

CIRCLED = {"①": 0, "②": 1, "③": 2, "④": 3, "⑤": 4}

Q_NUM_RE = re.compile(r"^(\d{1,3})(-(\d{1,2}))?\.\s*(.*)$")
OPT_RE = re.compile(r"^([①②③④⑤])\s*(.*)$")
EXPL_MARK_RE = re.compile(r"^▶\s*해설\s*$")
ANSWER_LINE_RE = re.compile(r"정답\s*[:：]?\s*([①②③④⑤]|\S+)")

NOISE_SUBSTR = [
    "리눅스마스터 2급 2차족보",
    "blog.naver.com/shadow879",
    "본 문제와 해설은 임의로 작성된",
    "당황하시지 마시고",
    "2026년 2급 1차 온라인",
    "온라인 시험 준비물",
    "PC 또는 노트북",
    "웹캠",
    "2026년부터는 위의 준비물",
    "시험 중 검색하거나",
    "===",
    "자료 수정 시점",
    "아래의 내용을 위주로",
]


def is_noise(line: str) -> bool:
    s = line.strip()
    if not s:
        return True
    if s in ("스마트폰", "마이크"):
        return True
    for n in NOISE_SUBSTR:
        if n in s:
            return True
    return False


CATEGORY_RULES = [
    ("부팅부트로더", ["GRUB", "LILO", "부트로더", "부트매니저", "런레벨", "runlevel", "MBR", "init ", "/etc/inittab", "부팅"]),
    ("설치파티션", ["파티션", "fdisk", "설치 유형", "Disk Druid", "볼륨", "LVM", "RAID", "설치 시", "파일시스템 유형", "스왑"]),
    ("파일시스템", ["저널링", "ext2", "ext3", "ext4", "마운트", "mount", "umount", "/etc/fstab", "fsck", "파일 시스템", "파일시스템"]),
    ("사용자그룹관리", ["useradd", "usermod", "userdel", "passwd", "그룹", "group", "/etc/passwd", "/etc/shadow", "/etc/group", "UID", "GID", "계정", "chage", "su "]),
    ("네트워크명령어", ["ifconfig", "ping", "traceroute", "netstat", "route", "nslookup", "dig", "host", "hostname", "네트워크", "DHCP", "DNS", "IP 주소", "wall", "write", "mesg", "talk"]),
    ("셸환경변수", ["PATH", "환경변수", "alias", "export", "bash_profile", "쉘", "셸", "profile"]),
    ("리다이렉션파이프", ["리다이렉션", "파이프", ">>", "표준입력", "표준출력", "표준에러"]),
    ("텍스트처리명령어", ["grep", "sed", "awk", "cut ", "sort ", "uniq", "diff", "cmp", "wc ", "split", "head", "tail", "cat ", "more", "less", "find "]),
    ("파일디렉토리명령어", ["ls ", "ls-", "mkdir", "rmdir", "cp ", "mv ", "rm ", "touch", "chmod", "chown", "ln ", "디렉터리", "디렉토리", "파일명"]),
    ("라이선스배포판", ["GPL", "LGPL", "BSD", "MIT", "라이선스", "배포판", "리눅스 배포", "GNU", "FSF", "오픈소스", "자유 소프트웨어", "커널"]),
    ("시스템관리", ["shutdown", "reboot", "halt", "poweroff", "프로세스", "시그널", "kill", "rpm", "yum", "패키지"]),
]


def guess_category(text: str) -> str:
    for cat, keys in CATEGORY_RULES:
        for k in keys:
            if k in text:
                return cat
    return "기타"


def clean_join(lines):
    lines = [l.rstrip() for l in lines]
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    return "\n".join(lines)


def load_lines(start_line, end_line):
    with open(SRC, encoding="utf-8") as f:
        all_lines = [l.rstrip("\n") for l in f.readlines()]
    return all_lines[start_line - 1:end_line]


def parse(start_line, end_line):
    raw = load_lines(start_line, end_line)
    lines = [l for l in raw if not is_noise(l)]

    # anchor indices: lines containing an answer marker
    anchors = [i for i, l in enumerate(lines) if "정답" in l and ANSWER_LINE_RE.search(l)]

    items = []
    prev_end = 0
    for a in anchors:
        block = lines[prev_end:a + 1]
        prev_end = a + 1
        if not block:
            continue

        ans_match = ANSWER_LINE_RE.search(block[-1])
        answer_marker = ans_match.group(1) if ans_match else None
        body = block[:-1]  # everything before the 정답 line

        expl_idx = None
        for i, l in enumerate(body):
            if EXPL_MARK_RE.match(l.strip()):
                expl_idx = i
                break

        qopt_section = body[:expl_idx] if expl_idx is not None else body
        expl_section = body[expl_idx + 1:] if expl_idx is not None else []

        # strip leading question number label e.g. "37." or "8-1."
        src_num = None
        if qopt_section:
            m = Q_NUM_RE.match(qopt_section[0].strip())
            if m:
                num_main, _, num_sub, rest_first = m.groups()
                src_num = num_main + (f"-{num_sub}" if num_sub else "")
                qopt_section = [rest_first] + qopt_section[1:]

        opt_idx = [i for i, l in enumerate(qopt_section) if OPT_RE.match(l.strip())]
        q_lines = qopt_section[:opt_idx[0]] if opt_idx else qopt_section

        options = []
        if opt_idx:
            bounds = opt_idx + [len(qopt_section)]
            for oi in range(len(opt_idx)):
                seg = qopt_section[bounds[oi]:bounds[oi + 1]]
                if not seg:
                    continue
                om = OPT_RE.match(seg[0].strip())
                options.append(clean_join([om.group(2)] + seg[1:]))

        question_text = clean_join(q_lines)
        explanation = clean_join(expl_section)

        answer_index = -1
        answer_text = ""
        if answer_marker in CIRCLED:
            answer_index = CIRCLED[answer_marker]
            if 0 <= answer_index < len(options):
                answer_text = options[answer_index]
        elif answer_marker:
            answer_text = answer_marker

        if not question_text.strip():
            continue

        cat_source = question_text + " " + " ".join(options)
        items.append({
            "srcNum": src_num or "",
            "category": guess_category(cat_source),
            "question": question_text,
            "options": options,
            "answerIndex": answer_index,
            "answerText": answer_text,
            "explanation": explanation,
        })
    return items


if __name__ == "__main__":
    start = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    end = int(sys.argv[2]) if len(sys.argv) > 2 else 3126
    items = parse(start, end)
    ordered = []
    for i, it in enumerate(items, 1):
        ordered.append({
            "id": f"q-{i:04d}",
            "category": it["category"],
            "question": it["question"],
            "options": it["options"],
            "answerIndex": it["answerIndex"],
            "answerText": it["answerText"],
            "explanation": it["explanation"],
            "srcNum": it["srcNum"],
        })
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(ordered, f, ensure_ascii=False, indent=2)
    print(f"wrote {len(ordered)} items to {OUT}")

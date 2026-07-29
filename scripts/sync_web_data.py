# -*- coding: utf-8 -*-
"""
Regenerates linux_master2_web/js/data.js from the Flutter app's question bank
(linux_master2/assets/data/questions.json) so the static web viewer always
shows the same content as the app. Run this after editing questions.json:

    python scripts/sync_web_data.py
"""
import json

SRC = r"c:/Users/min/Desktop/LinuxMaster_Level2/linux_master2/assets/data/questions.json"
OUT = r"c:/Users/min/Desktop/LinuxMaster_Level2/linux_master2_web/js/data.js"

with open(SRC, encoding="utf-8") as f:
    data = json.load(f)

body = json.dumps(data, ensure_ascii=False, indent=2)
out = (
    "// Auto-generated from linux_master2/assets/data/questions.json\n"
    "// Do not edit by hand -- run scripts/sync_web_data.py instead.\n"
    f"const QUESTIONS = {body};\n"
)

with open(OUT, "w", encoding="utf-8") as f:
    f.write(out)

print(f"wrote {len(data)} questions to {OUT}")

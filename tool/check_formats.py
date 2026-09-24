import json
import re

with open('tool/en_entries.json', 'r', encoding='utf-8') as f:
    entries = json.load(f)

# Inspect how values are structured:
# Are there multiline strings or special characters?
print(f"Total entries: {len(entries)}")
for i, item in enumerate(entries):
    k = item['key']
    v = item['val']
    if not (v.startswith("'") and v.endswith("',")):
        print(f"Special format at index {i}: key={k}, val={v[:40]}")

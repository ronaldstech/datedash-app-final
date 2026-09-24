import json

with open('tool/en_entries.json', 'r', encoding='utf-8') as f:
    entries = json.load(f)

print(f"Total keys to translate: {len(entries)}")
sample_indices = [0, 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 980]
for idx in sample_indices:
    if idx < len(entries):
        print(f"[{idx}] {entries[idx]['key']} -> {entries[idx]['val'][:60]}")

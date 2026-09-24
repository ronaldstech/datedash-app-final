import json

with open('tool/en_entries.json', 'r', encoding='utf-8') as f:
    entries = json.load(f)

for i in range(0, len(entries), 100):
    chunk = entries[i:i+100]
    with open(f'tool/en_chunk_{i//100}.json', 'w', encoding='utf-8') as cf:
        json.dump(chunk, cf, ensure_ascii=False, indent=2)

print(f"Created {(len(entries)+99)//100} chunk files")

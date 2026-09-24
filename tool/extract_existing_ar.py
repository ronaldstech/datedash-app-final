import re
import json

def parse_translations(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    entries = []
    current_key = None
    current_val_lines = []

    key_regex = re.compile(r"^\s*'([a-zA-Z0-9_]+)'\s*:\s*(.*)$")

    for line in lines:
        m = key_regex.match(line)
        if m:
            if current_key is not None:
                entries.append((current_key, ''.join(current_val_lines).strip()))
            current_key = m.group(1)
            current_val_lines = [m.group(2)]
        elif current_key is not None:
            current_val_lines.append(line)
            if line.strip().endswith("',") or line.strip().endswith('",'):
                entries.append((current_key, ''.join(current_val_lines).strip()))
                current_key = None
                current_val_lines = []

    if current_key is not None:
        entries.append((current_key, ''.join(current_val_lines).strip()))

    return dict(entries)

ar_existing = parse_translations('lib/translations/ar_translations.dart')
en_existing = parse_translations('lib/translations/en_translations.dart')

already_translated = {}
for k, v in ar_existing.items():
    if k in en_existing and ar_existing[k] != en_existing[k]:
        already_translated[k] = v

print(f"Already translated in AR: {len(already_translated)}")
with open('tool/ar_already_translated.json', 'w', encoding='utf-8') as f:
    json.dump(already_translated, f, ensure_ascii=False, indent=2)

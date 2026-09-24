import json
import re

def parse_entries(file_path):
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

    result = {}
    for k, raw_v in entries:
        # Strip trailing comma
        v = raw_v
        if v.endswith(','):
            v = v[:-1].strip()
        # Clean quotes if single line
        # Check if wrapped in '...'
        # Notice string could be multiline or concatenated
        result[k] = (raw_v, v)
    return entries

en_entries = parse_entries('lib/translations/en_translations.dart')
print(f"Total entries: {len(en_entries)}")
with open('tool/en_entries.json', 'w', encoding='utf-8') as f:
    json.dump([{'key': k, 'val': v} for k, v in en_entries], f, ensure_ascii=False, indent=2)
print("Saved to tool/en_entries.json")

import re

def parse_translations(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    entries = []
    current_key = None
    current_val_lines = []
    in_entry = False

    key_regex = re.compile(r"^\s*'([a-zA-Z0-9_]+)'\s*:\s*(.*)$")

    for line in lines:
        m = key_regex.match(line)
        if m:
            if current_key is not None:
                entries.append((current_key, ''.join(current_val_lines).strip()))
            current_key = m.group(1)
            rest = m.group(2)
            current_val_lines = [rest]
        elif current_key is not None:
            current_val_lines.append(line)
            if line.strip().endswith("',") or line.strip().endswith('",'):
                entries.append((current_key, ''.join(current_val_lines).strip()))
                current_key = None
                current_val_lines = []

    if current_key is not None:
        entries.append((current_key, ''.join(current_val_lines).strip()))

    return entries

en_entries = parse_translations('lib/translations/en_translations.dart')
ar_entries = parse_translations('lib/translations/ar_translations.dart')

print(f"EN entries count: {len(en_entries)}")
print(f"AR entries count: {len(ar_entries)}")

en_keys = [k for k, v in en_entries]
ar_keys = [k for k, v in ar_entries]

missing_in_ar = [k for k in en_keys if k not in set(ar_keys)]
print(f"Missing in AR: {len(missing_in_ar)}")
extra_in_ar = [k for k in ar_keys if k not in set(en_keys)]
print(f"Extra in AR: {len(extra_in_ar)}")

# Check how many are identical to English
en_dict = dict(en_entries)
ar_dict = dict(ar_entries)

identical = [k for k in ar_keys if k in en_dict and ar_dict[k] == en_dict[k]]
print(f"Identical in AR to EN: {len(identical)}")

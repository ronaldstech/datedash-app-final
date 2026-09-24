import json
import re
from ar_dict import AR_TRANSLATIONS

with open('tool/en_entries.json', 'r', encoding='utf-8') as f:
    en_entries = json.load(f)

# Verify placeholder preservation between English and Arabic
# E.g., {n}, {name}, {count}, {seconds}, {price}, etc.
placeholder_re = re.compile(r'\{([a-zA-Z0-9_\.]+)\}')

placeholder_mismatches = []
for entry in en_entries:
    k = entry['key']
    en_v = entry['val']
    ar_v = AR_TRANSLATIONS.get(k, '')
    
    en_matches = set(placeholder_re.findall(en_v))
    ar_matches = set(placeholder_re.findall(ar_v))
    
    if en_matches != ar_matches:
        placeholder_mismatches.append((k, en_matches, ar_matches, en_v, ar_v))

print(f"Placeholder mismatches: {len(placeholder_mismatches)}")
for m in placeholder_mismatches:
    print(f"Key: {m[0]}")
    print(f"  EN placeholders: {m[1]} in {m[3]}")
    print(f"  AR placeholders: {m[2]} in {m[4]}")

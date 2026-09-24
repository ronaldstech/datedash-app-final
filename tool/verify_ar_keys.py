import json
from ar_dict import AR_TRANSLATIONS

with open('tool/en_entries.json', 'r', encoding='utf-8') as f:
    en_entries = json.load(f)

en_keys = [e['key'] for e in en_entries]
ar_keys = list(AR_TRANSLATIONS.keys())

missing = [k for k in en_keys if k not in AR_TRANSLATIONS]
extra = [k for k in AR_TRANSLATIONS if k not in set(en_keys)]

print(f"Total en_keys: {len(en_keys)}")
print(f"Total AR_TRANSLATIONS: {len(ar_keys)}")
print(f"Missing from AR_TRANSLATIONS: {len(missing)} -> {missing}")
print(f"Extra in AR_TRANSLATIONS: {len(extra)} -> {extra}")

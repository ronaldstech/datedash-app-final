import re
import sys

def replace_in_file(path, replacements):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    for old, new in replacements:
        content = content.replace(old, new)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

replace_in_file('lib/screens/settings_screen.dart', [
    ('if (credits < 50)', 'if (sparks < 50)'),
    ('.credits ?? 0', '.sparks ?? 0')
])

replace_in_file('lib/screens/transactions_screen.dart', [
    ('tx.creditAmount', 'tx.sparkAmount')
])

replace_in_file('lib/services/auth_service.dart', [
    ('sparks: 0,', 'sparks: 0,'), # actually auth_service might pass `sparks:` where `credits:` is expected, wait
    ('credits: 0,', 'sparks: 0,'),
    ('credits: 10,', 'sparks: 10,')
])

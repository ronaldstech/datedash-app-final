import re

with open('lib/widgets/profile_detail_sheet.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix other broken string literals
content = re.sub(r"'([^']+)\),", r"'\1'),", content)
content = re.sub(r"'([^']+)\)\,\n", r"'\1'),\n", content)
content = re.sub(r"'([^']+)\)\n", r"'\1')\n", content)
content = re.sub(r"'([^']+)\}\n", r"'\1'}\n", content)

with open('lib/widgets/profile_detail_sheet.dart', 'w', encoding='utf-8') as f:
    f.write(content)

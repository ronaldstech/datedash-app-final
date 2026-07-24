import re

with open('lib/widgets/profile_detail_sheet.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("['icon]", "['icon']")
content = content.replace("['label]", "['label']")
content = content.replace("['value]", "['value']")

content = re.sub(r"getString\('([^']+)\),", r"getString('\1'),", content)
content = re.sub(r"getString\('([^']+)\)", r"getString('\1')", content)

with open('lib/widgets/profile_detail_sheet.dart', 'w', encoding='utf-8') as f:
    f.write(content)

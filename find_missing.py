import json
import re

with open(r'c:\Users\USER\dev\animal_warfare\assets\abilities.json', 'r', encoding='utf-8') as f:
    abilities = json.load(f)

existing = set(a['name'] for a in abilities)

with open(r'c:\Users\USER\.gemini\antigravity\brain\990bf871-ceb8-45f6-a066-4f4f8abbdb28\task.md', 'r', encoding='utf-8') as f:
    text = f.read()

# Extract from task.md
matches = re.findall(r'Implement `([^`]+)`', text)

missing = []

# task.md also has lists like `Queenly Majesty`, `Dazzling` so we should just grab all code blocks after "Implement" and then split them if there's commas outside, but `regex` grabbed just the first one. Let's just grab all code blocks in the line starting with "Implement"
for line in text.split('\n'):
    if 'Implement' in line:
        for m in re.findall(r'`([^`]+)`', line):
            missing.append(m)

final_missing = []
for m in missing:
    for sub in m.split('/'):
        sub = sub.strip()
        if sub and sub not in existing:
            final_missing.append(sub)

print('Missing:')
print(', '.join(final_missing))

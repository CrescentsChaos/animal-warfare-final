import json

with open(r'c:\Users\USER\dev\animal_warfare\assets\Organisms.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

for i, org in enumerate(data):
    if 'tiger' in org['name'].lower():
        print(f"Found at index {i}: {org['name']}")

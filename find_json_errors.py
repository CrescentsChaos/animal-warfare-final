import json

with open('assets/Organisms.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

for i, entry in enumerate(data):
    for key, value in entry.items():
        # Print if anything is unexpected based on Organism model
        if key in ['attack', 'defense', 'power', 'resistance', 'health', 'speed']:
            if not isinstance(value, int):
                print(f"Index {i}, Organism {entry.get('name')}: field '{key}' is {type(value)} (value: {value!r})")
        elif key in ['name', 'scientific_name', 'habitat', 'drops', 'abilities', 'category', 'moves', 'sprite', 'rarity', 'description']:
            if not isinstance(value, str) and value is not None:
                print(f"Index {i}, Organism {entry.get('name')}: field '{key}' is {type(value)} (value: {value!r})")
        elif key == 'types':
            if not isinstance(value, list):
                 print(f"Index {i}, Organism {entry.get('name')}: field '{key}' is {type(value)} (value: {value!r})")
            else:
                for item in value:
                    if not isinstance(item, str):
                        print(f"Index {i}, Organism {entry.get('name')}: field 'types' contains non-string {type(item)} (value: {item!r})")

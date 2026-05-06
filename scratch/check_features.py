import json

with open(r'c:\Users\USER\dev\animal_warfare\assets\ml\sprite_features.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

if "Royal Bengal Tiger" in data:
    print("Royal Bengal Tiger FOUND in sprite_features.json")
    print(json.dumps(data["Royal Bengal Tiger"], indent=2))
else:
    print("Royal Bengal Tiger NOT FOUND in sprite_features.json")

# Also check for Siberian Tiger to see if it's there
if "Siberian Tiger" in data:
    print("Siberian Tiger FOUND in sprite_features.json")
else:
    print("Siberian Tiger NOT FOUND in sprite_features.json")

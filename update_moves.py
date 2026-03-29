import json

file_path = r"c:\Users\USER\dev\animal_warfare\assets\moves.json"
new_moves = [
    {"name": "After You", "description": "The user helps the target and makes it go next.", "baseDamage": 0, "type": "basic", "stamina": 15, "category": "status", "effects": [{"type": "afterYou", "target": "opponent"}]},
    {"name": "Baton Pass", "description": "Switches out, passing stat changes and some volatile statuses to the newcomer.", "baseDamage": 0, "type": "basic", "stamina": 40, "category": "status", "isBatonPass": True, "effects": [{"type": "batonPass", "target": "self"}]},
    {"name": "Beat Up", "description": "Every member in the party attacks for each hit.", "baseDamage": 0, "type": "darkness", "stamina": 10, "category": "physical", "isBeatUp": True, "effects": [{"type": "beatUp", "target": "opponent"}]},
    {"name": "Bestow", "description": "The user gives its held item to the target.", "baseDamage": 0, "type": "basic", "stamina": 15, "category": "status", "effects": [{"type": "bestow", "target": "opponent"}]},
    {"name": "Trick", "description": "The user catches the target off guard and swaps held items with it.", "baseDamage": 0, "type": "basic", "stamina": 10, "category": "status", "effects": [{"type": "trick", "target": "opponent"}]},
    {"name": "Clear Smog", "description": "The user throws a clump of special mud to reset the target's stat changes.", "baseDamage": 50, "type": "poison", "stamina": 15, "category": "special", "isClearSmog": True, "effects": [{"type": "clearSmog", "target": "opponent"}]},
    {"name": "Corrosive Gas", "description": "The user surrounds everything in a highly acidic gas that melts held items.", "baseDamage": 0, "type": "poison", "stamina": 40, "category": "status", "targetCount": "multiple", "effects": [{"type": "corrosiveGas", "target": "opponent"}]},
    {"name": "Dream Eater", "description": "The user eats the dreams of a sleeping target. It heals half the damage dealt.", "baseDamage": 100, "type": "spectral", "stamina": 15, "category": "special", "drainPercent": 0.5, "isDreamEater": True, "effects": [{"type": "dreamEater", "target": "opponent"}]},
    {"name": "Fell Stinger", "description": "If this move knocks out the target, the user's Attack stat rises drastically.", "baseDamage": 50, "type": "arthropod", "stamina": 25, "category": "physical", "effects": [{"type": "fellStinger", "target": "self"}]},
    {"name": "Explosion", "description": "The user attacks everything around it by causing a tremendous explosion. The user faints.", "baseDamage": 250, "type": "basic", "stamina": 5, "accuracy": 100, "category": "physical", "targetCount": "multiple", "isSelfDestruct": True},
    {"name": "Entrainment", "description": "The user dances with the target to copy its ability with the target's.", "baseDamage": 0, "type": "basic", "stamina": 15, "category": "status", "effects": [{"type": "entrainment", "target": "opponent"}]},
    {"name": "Fling", "description": "The user flings its held item at the target to attack. Power depends on item.", "baseDamage": 0, "type": "basic", "stamina": 10, "category": "physical", "isFling": True, "effects": [{"type": "fling", "target": "opponent"}]},
    {"name": "Foul Play", "description": "The user turns the target's power against it. Uses target's Attack stat.", "baseDamage": 95, "type": "darkness", "stamina": 15, "category": "physical", "isFoulPlay": True, "effects": [{"type": "foulPlay", "target": "opponent"}]},
    {"name": "Jaw Lock", "description": "This move prevents both the user and the target from escaping.", "baseDamage": 80, "type": "darkness", "stamina": 10, "category": "physical", "isBite": True, "isJawLock": True, "effects": [{"type": "jawLock", "target": "opponent"}]},
    {"name": "Pursuit", "description": "Power doubles if the target is switching out.", "baseDamage": 40, "type": "darkness", "stamina": 20, "category": "physical", "isPursuit": True, "effects": [{"type": "pursuit", "target": "opponent"}]},
    {"name": "Leech Seed", "description": "The user plants a seed on the target that drains HP each turn to heal the user.", "baseDamage": 0, "type": "grass", "stamina": 10, "category": "status", "isLeechSeed": True, "effects": [{"type": "leechSeed", "target": "opponent"}]}
]

try:
    with open(file_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    # Check for duplicates by name
    existing_names = {move["name"] for move in data}
    for new_move in new_moves:
        if new_move["name"] not in existing_names:
            data.append(new_move)
        else:
            # Update existing move if needed
            for i, existing_move in enumerate(data):
                if existing_move["name"] == new_move["name"]:
                    data[i] = new_move
                    break
                    
    with open(file_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4)
    print("Successfully updated moves.json")
except Exception as e:
    print(f"Error: {e}")

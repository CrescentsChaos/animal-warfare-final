import json
import random

diet_types = [
    "Herbivore", "Carnivore", "Omnivore", "Insectivore", "Piscivore", 
    "Frugivore", "Nectarivore", "Scavenger", "Detritivore", 
    "Filter Feeder", "Parasite", "Sanguivore", "Non-feeding"
]

animal_classes = [
    "Mammal", "Bird", "Reptile", "Amphibian", "Fish", "Insect", 
    "Arachnid", "Crustacean", "Mollusk", "Annelid", "Cnidarian", 
    "Echinoderm", "Other Invertebrate"
]

templates = []

# Predator-Prey Interaction Templates (40)
predator_verbs = ["Targets", "Hunts", "Tracks", "Lurks Near", "Pursues", "Stalks", "Challenges"]
for i in range(40):
    verb = random.choice(predator_verbs)
    templates.append({
        "headline": f"{verb} in the {{habitat}}: {{name}} vs {{name2}}",
        "body": "In a display of raw survival, a {name} was spotted {v} a {name2}. This {diet} predator is known for its {moves} move, which it uses to dominate the {habitat} food chain. Local {animal_class} experts are monitoring the situation closely.",
        "category": "DISCOVERY",
        "type": "comparison"
    })

# Diet-Specific Observations (30)
for i in range(30):
    diet = random.choice(diet_types)
    templates.append({
        "headline": f"Special Report: The {{diet}} Lifestyle of the {{name}}",
        "body": "Recent studies in the {habitat} have revealed how the {name} thrives as a {diet}. Whether it's {v} or interacting with other {animal_class} species, this {rarity} organism shows remarkable adaptation. Its {hp} HP and {speed} SPD are key to its success.",
        "category": "ECOLOGY"
    })

# Habitat & Spawning (30)
for i in range(30):
    templates.append({
        "headline": "Hidden Habitats: Exploring {spawn_tiles} with {name}",
        "body": "The {habitat} holds many secrets, but none as intriguing as the {name}. Spawning near {spawn_tiles}, this {animal_class} uses its {moves} to defend its territory. Travelers are advised to watch for {v} individuals near the center of the {habitat}.",
        "category": "EXPLORATION"
    })

print(json.dumps(templates, indent=2))

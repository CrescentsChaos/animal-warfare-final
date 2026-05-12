import json

new_templates = [
    # --- PREDATOR / PREY & HUNTING ---
    {
        "headline": "Predator Alert: {name} on the Prowl",
        "body": "Sightings of {name} in the {habitat} have increased. As a formidable {diet} {animal_class}, it utilizes {moves} to dominate its territory on {spawn_tiles}.",
        "category": "ECOLOGY"
    },
    {
        "headline": "The Hunt is On: {name} vs {name2}",
        "body": "In a rare display of {habitat} hierarchy, a {name} was seen shadowing a {name2}. The {name}'s {attack} ATK makes it a lethal threat to any {animal_class} in its path.",
        "category": "ECOLOGY",
        "type": "comparison"
    },
    {
        "headline": "Survival of the Fittest: {name}'s Ambush Tactics",
        "body": "Hidden among the {spawn_tiles}, {name} waits for the perfect moment to strike. This {diet} master of {habitat} uses {abilities} to remain undetected by unsuspecting prey.",
        "category": "SCIENCE"
    },
    {
        "headline": "Dangerous Encounters: {name} Spotted Near {habitat}",
        "body": "Adventurers are warned that {name} has been active during {active_time}. Its {power} PWR and aggressive {diet} nature make it one of the most dangerous {animal_class} specimens in the region.",
        "category": "EXPLORATION"
    },
    {
        "headline": "Nature's Assassin: The {name} Technique",
        "body": "Witnesses describe the {name} as a 'blur of scales and fur'. With {speed} SPD, this {diet} hunter can close the gap on {name2} before they even sense danger.",
        "category": "ECOLOGY",
        "type": "comparison"
    },
    
    # --- BIOMETRICS & SCALE ---
    {
        "headline": "Goliath of the {habitat}: {name} Weighs In at {weight}kg",
        "body": "New biometric data confirms {name} is a true heavyweight. At {weight} kg and {size} m, its sheer bulk provides a robust λ of {robustness}. It truly is a titan of the {animal_class} group.",
        "category": "BIOMETRICS"
    },
    {
        "headline": "Size Comparison: {name} vs {name2}",
        "body": "While {name2} relies on agility, {name} uses its {size} m frame to intimidate. The weight difference is staggering, with {name} hitting {weight} kg on the scales.",
        "category": "BIOMETRICS",
        "type": "comparison"
    },
    {
        "headline": "The Robustness of a Legend: {name}'s Physicality",
        "body": "Scientists are marveling at {name}'s {robustness} robustness score. This {animal_class} is built like a tank, boasting {defense} DEF and {resistance} RES to survive anything {habitat} throws at it.",
        "category": "BIOMETRICS"
    },
    {
        "headline": "Miniature Marvel: The Surprising Scale of {name}",
        "body": "Don't let the {size} m stature fool you. {name} packs a punch with {power} PWR, proving that in the {habitat}, size isn't everything for a {animal_class}.",
        "category": "BIOMETRICS"
    },
    
    # --- HABITAT & ECOLOGY ---
    {
        "headline": "Domain Mastery: Why {name} Owns the {habitat}",
        "body": "From the {spawn_tiles} to the canopy, {name} is perfectly adapted. Its {types} typing gives it an edge in the {habitat} climate that other {animal_class} species simply lack.",
        "category": "ECOLOGY"
    },
    {
        "headline": "Territorial Dispute: {name} Expands in {habitat}",
        "body": "Recent shifts in {habitat} resources have pushed {name} into new regions of {spawn_tiles}. This could spell trouble for the local {name2} population.",
        "category": "CONSERVATION",
        "type": "comparison"
    },
    {
        "headline": "Ecological Keystone: The Importance of {name}",
        "body": "If {name} were to disappear from {habitat}, the entire food web would collapse. As a {diet}, it regulates the population of various {animal_class} species near {spawn_tiles}.",
        "category": "CONSERVATION"
    },
    
    # --- BATTLE & COMPETITIVE ---
    {
        "headline": "The Unstoppable Wall: {name}'s Defensive Meta",
        "body": "Pro trainers are calling {name} the ultimate anchor. With {hp} HP and {defense} DEF, it can stall out even the strongest {types} sweepers in the {habitat}.",
        "category": "BATTLE META"
    },
    {
        "headline": "Meta Shift: Is {name} the New Top Tier?",
        "body": "Since the discovery of {abilities} synergy, {name} usage has spiked. Its {speed} SPD and {moves} combo is currently dominating the {habitat} ladder.",
        "category": "BATTLE META"
    },
    {
        "headline": "Calculated Advantage: {name} vs {name2}",
        "body": "In a head-to-head, {name} brings {power} PWR to the table. While {name2} has better {resistance} RES, it struggles to mitigate the raw {attack} ATK of its {rarity} rival.",
        "category": "STATISTICS",
        "type": "comparison"
    }
]

# Generate more variants by rotating headlines and bodies
categories = ["ECOLOGY", "SCIENCE", "BATTLE META", "EXPLORATION", "BIOMETRICS", "CONSERVATION", "DISCOVERY", "STATISTICS", "PROFILE"]
adjectives = ["Massive", "Rare", "Elusive", "Fierce", "Ancient", "Enigmatic", "Deadly", "Colossal", "Miniature", "Radiant"]
verbs = ["Hunting", "Spotted", "Discovered", "Studied", "Tracked", "Ambushing", "Defending", "Evolving", "Migrating"]

# Generate ~100 more
for i in range(100):
    adj = adjectives[i % len(adjectives)]
    v = verbs[i % len(verbs)]
    cat = categories[i % len(categories)]
    
    if i % 3 == 0: # Predator / Prey focus
        new_templates.append({
            "headline": f"{adj} {v}: {adj} {{name}} Targets {{name2}}",
            "body": f"Dramatic footage from {{habitat}} shows a {{name}} {{v}} near {{spawn_tiles}}. As a {{diet}} {{animal_class}}, it uses {{moves}} to secure its place in the food chain. Experts note its {{power}} PWR is a major factor.",
            "category": cat,
            "type": "comparison"
        })
    elif i % 3 == 1: # Biometric focus
        new_templates.append({
            "headline": f"Biometric Report: The {adj} Scale of {{name}}",
            "body": f"The {{name}} continues to baffle scientists with its {{weight}} kg mass and {{size}} m height. This {{rarity}} {{animal_class}} has a robustness λ of {{robustness}}, making it an outlier in the {{habitat}} biome.",
            "category": "BIOMETRICS"
        })
    else: # General curiosity
        new_templates.append({
            "headline": f"Discovery: {adj} {{name}} Activity in {{habitat}}",
            "body": f"Researchers found {{name}} traces on {{spawn_tiles}} today. This {{rarity}} specimen is known for its {{abilities}} and unique {{types}} typing. Its BST of {{bst}} confirms its status as a high-tier {{animal_class}}.",
            "category": cat
        })

# Load current news_config.json
with open('assets/news_config.json', 'r', encoding='utf-8') as f:
    config = json.load(f)

# Append new templates
config['templates'].extend(new_templates)

# Deduplicate by headline (optional but good for cleanup)
seen = set()
unique_templates = []
for t in config['templates']:
    if t['headline'] not in seen:
        unique_templates.append(t)
        seen.add(t['headline'])

config['templates'] = unique_templates

# Save back
with open('assets/news_config.json', 'w', encoding='utf-8') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)

print(f"Successfully added {len(new_templates)} new high-quality templates to news_config.json.")

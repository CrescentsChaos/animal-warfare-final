import json
import random

# Categories from news_config.json
categories = [
    'ECOLOGY', 'SCIENCE', 'BATTLE META', 'EXPLORATION',
    'TAXONOMY', 'CONSERVATION', 'BIOMETRICS', 'WEATHER',
    'DISCOVERY', 'STATISTICS', 'PROFILE', 'OPINION', 'GENERAL'
]

# Polarizing comment templates (Positive and Negative)
polarizing_comments = {
    'ECOLOGY': [
        "This is exactly what's wrong with our ecosystem management. Absolute disaster.",
        "The {habitat} is dying and all we do is write articles about {name}. Pathetic.",
        "Beautifully captured. The {name} is the soul of the {habitat}.",
        "I'm sick of hearing about {name}. What about the other species?",
        "Finally, someone addresses the {habitat} crisis correctly!",
        "Total nonsense. I've been to {habitat} and {name} is nowhere to be found.",
        "A masterpiece of ecological reporting. Keep it up!",
        "Whoever wrote this clearly has never stepped foot in the {habitat}.",
        "The {name} is a parasite, not a 'keystone species'. Learn biology.",
        "Protectors of the {habitat}, unite! We must save the {name}!",
        "Just another fluff piece to ignore the real issues in {habitat}.",
        "Incredible insight into the life of {name}. I'm moved.",
        "Stop romanticizing predators like {name}. They are dangerous pests.",
        "The balance of {habitat} is art, and {name} is the artist.",
        "This article is funded by big corporate interests in {habitat}. I'm not buying it.",
        "Simply stunning. I hope my kids get to see a {name} someday.",
        "I'm reporting this for misinformation. {name} doesn't live in {habitat}.",
        "The detail here is amazing. {habitat} looks so vibrant.",
        "Another day, another useless update about {name}. Get a life.",
        "The {name} is a symbol of hope for the {habitat}. Stay strong!"
    ],
    'SCIENCE': [
        "Pseudocience at its finest. This 'research' is a joke.",
        "The methodology here is so flawed it hurts to read.",
        "A breakthrough! The {name} genetic sequence changes everything.",
        "I've peer-reviewed better papers written by toddlers.",
        "Finally, some real data on {name}. Scientific community rejoices!",
        "The {scientific_name} classification is obviously wrong. Re-read the textbooks.",
        "Stunning lab work. The {drops} analysis is revolutionary.",
        "Where are the citations? This is just anecdotal garbage.",
        "The {name} is the missing link we've been searching for!",
        "Waste of tax dollars. Who cares about {name} DNA?",
        "Brilliant deduction. The {animal_class} connection is genius.",
        "This belongs in a sci-fi novel, not a scientific journal.",
        "The {name} is a biological marvel. Simply incredible.",
        "Contradictory findings. Previous studies say the exact opposite.",
        "The depth of this {name} study is unparalleled. Bravo!",
        "I don't trust these 'experts'. They've been wrong about {habitat} before.",
        "The {drops} have properties we can't even imagine yet. Exciting!",
        "Boring. Call me when you find a Mythical creature, not another {name}.",
        "The {scientific_name} nomenclature is perfectly applied here.",
        "This isn't science, it's just propaganda for {name} fanboys."
    ],
    'BATTLE META': [
        "Absolute trash tier. {name} is a complete waste of a slot.",
        "If you use {name} in the {habitat}, you're asking to lose. Period.",
        "GOD TIER! {name} with {moves} is literally unstoppable.",
        "Buff {name} or delete it. This is unplayable.",
        "Finally a counter to the current meta! {name} is the hero we need.",
        "Imagine thinking {name} is good. Literal clown takes here.",
        "The {moves} combo is broken. NERF IT NOW.",
        "I just swept a whole team with my {name}. Best day ever!",
        "Total garbage. {name} gets countered by literally everything.",
        "The {habitat} meta is so stale. {name} adds nothing.",
        "Underrated gem. {name}'s {abilities} is a sleeper hit.",
        "I'm quitting if they don't fix {name}'s scaling. Pathetic.",
        "Pro players use {name} for a reason. Get good, scrubs.",
        "The {power} PWR on {name} is a lie. It hits like a wet noodle.",
        "Absolute masterclass in strategy. Using {name} in {habitat} is genius.",
        "Stop posting these fake 'meta' guides. {name} is D-tier at best.",
        "The {moves} animation is so slow. It's basically a self-stun.",
        "I love the new {name} tech. Completely changed my game.",
        "Noob bait. Only low-rank players think {name} is viable.",
        "The {name} is the king of the {habitat} arena. Fight me!"
    ]
}

# General polarizing comments for the rest of categories
general_polarizing = [
    "I've seen better content on a bathroom wall. Horrible.",
    "Life-changing. I will never look at {name} the same way again.",
    "This is a disgrace to journalism. Absolute clickbait.",
    "Finally, high-quality reporting in the {habitat} region!",
    "Who even cares? This is so irrelevant.",
    "The {name} is a total fraud. I'm unsubscribing.",
    "Incredible! I'm sharing this with everyone I know.",
    "Worst article of the year. Congrats on hitting rock bottom.",
    "The {habitat} is lucky to have writers like this. Beautiful.",
    "I'm literally crying. The {name} story is so heartbreaking.",
    "Fake news. This never happened.",
    "Wow. Just wow. {name} is truly a legend.",
    "Is this a joke? Because I'm not laughing.",
    "The most important thing I've read all week. Essential.",
    "Stop wasting our time with {name}. Post something real.",
    "A beacon of light in a dark world. Thank you for this.",
    "Garbage. Pure, unadulterated garbage.",
    "I'm officially a {name} stan now. Fight me.",
    "This belongs in the trash. Along with {name}.",
    "Absolutely breathtaking. The {habitat} is a wonder."
]

def generate_polarizing_comments():
    with open('assets/news_config.json', 'r', encoding='utf-8') as f:
        config = json.load(f)
    
    templates = config.get('comment_templates', {})
    
    for cat in categories:
        if cat not in templates:
            templates[cat] = []
        
        # Add 20 polarizing comments
        specific = polarizing_comments.get(cat, general_polarizing)
        templates[cat].extend(specific)
        
        # Ensure diversity and no duplicates
        templates[cat] = list(set(templates[cat]))
        
    config['comment_templates'] = templates
    
    with open('assets/news_config.json', 'w', encoding='utf-8') as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
    
    print(f"Successfully expanded comment templates for {len(categories)} categories.")

if __name__ == "__main__":
    generate_polarizing_comments()

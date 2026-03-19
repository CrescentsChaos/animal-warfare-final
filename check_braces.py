
import os

filepath = r'c:\Users\USER\dev\animal_warfare\lib\game\battle_manager.dart'
if not os.path.exists(filepath):
    print(f"File not found: {filepath}")
    exit(1)

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

balance = 0
for i, line in enumerate(lines):
    # Ignore comments
    line = line.split('//')[0]
    # Rough check for strings (to avoid braces in strings)
    # This is a bit simplified but should work for most cases
    in_string = False
    for char in line:
        if char == "'" or char == '"':
            in_string = not in_string
        if not in_string:
            if char == '{':
                balance += 1
            elif char == '}':
                balance -= 1
                if balance < 1:
                    print(f"Brace balance became {balance} at line {i+1}: {line.strip()}")


import re
import os

def trace_it_again(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    def comment_replacer(match):
        newlines = match.group(0).count('\n')
        return '\n' * newlines if newlines > 0 else ' '
    content = re.sub(r'/\*.*?\*/', comment_replacer, content, flags=re.DOTALL)
    
    lines = content.split('\n')
    balance = 0
    in_class = False
    
    for i, line in enumerate(lines, 1):
        line_orig = line
        line = re.sub(r'//.*', '', line)
        line = re.sub(r"'(?:\\.|[^'])*'", "''", line)
        line = re.sub(r'"(?:\\.|[^"])*"', '""', line)
        
        opened = line.count('{')
        closed = line.count('}')
        
        if not in_class:
            if 'class DoubleBattleManager' in line_orig:
                in_class = True
                balance = 1
            continue

        balance += opened
        balance -= closed
        
        if i >= 1580 and i <= 1605:
             print(f"L{i:4d} | B:{balance} | O:{opened} C:{closed} | {line_orig.strip()}")

if __name__ == "__main__":
    trace_it_again(r"c:\Users\USER\dev\animal_warfare\lib\game\double_battle_manager.dart")

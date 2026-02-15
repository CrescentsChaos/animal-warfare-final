
import re

with open(r'c:\Users\USER\dev\animal_warfare\lib\models\move.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Try to find the start and end of the list manually
start_marker = 'static const List<Move> _allMoves = ['
start_idx = content.find(start_marker)
if start_idx == -1:
    print("Start marker not found")
else:
    print(f"Found start marker at {start_idx}")
    # Find the matching closing bracket
    bracket_count = 0
    end_idx = -1
    for i in range(start_idx + len(start_marker), len(content)):
        if content[i] == '[': bracket_count += 1
        elif content[i] == ']':
            if bracket_count == 0:
                end_idx = i
                break
            bracket_count -= 1
    
    if end_idx != -1:
        print(f"Found end marker at {end_idx}")
        moves_block = content[start_idx + len(start_marker):end_idx]
        print(f"Moves block length: {len(moves_block)}")
        
        # Check for individual Move( patterns
        move_starts = list(re.finditer(r'Move\(', moves_block))
        print(f"Number of 'Move(' starts found: {len(move_starts)}")
        # Print first few chars of each start to confirm
        for i, m in enumerate(move_starts[:5]):
            print(f"Start {i}: {moves_block[m.start():m.start()+50]!r}")
    else:
        print("End marker not found")

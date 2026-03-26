import json
import os
import re

def find_missing_moves():
    organisms_path = os.path.join('assets', 'Organisms.json')
    moves_path = os.path.join('assets', 'moves.json')

    if not os.path.exists(organisms_path):
        print(f"Error: {organisms_path} not found.")
        return
    if not os.path.exists(moves_path):
        print(f"Error: {moves_path} not found.")
        return

    with open(organisms_path, 'r', encoding='utf-8') as f:
        organisms = json.load(f)

    with open(moves_path, 'r', encoding='utf-8') as f:
        moves_data = json.load(f)

    implemented_moves = {m['name'].strip().lower() for m in moves_data}
    
    missing_moves_map = {} # move_name -> list of organisms using it

    for org in organisms:
        org_name = org.get('name', 'Unknown')
        moves_str = org.get('moves', '')
        if not moves_str:
            continue
            
        # Clean up the moves string: remove newlines/tabs, then split by comma
        clean_moves_str = re.sub(r'\s+', ' ', moves_str)
        org_moves = [m.strip() for m in clean_moves_str.split(',') if m.strip()]
        
        for move in org_moves:
            if move.lower() not in implemented_moves:
                if move not in missing_moves_map:
                    missing_moves_map[move] = []
                missing_moves_map[move].append(org_name)

    if not missing_moves_map:
        print("All moves are implemented!")
    else:
        # Sort by move name
        sorted_moves = sorted(missing_moves_map.keys())
        print(f"TOTAL MISSING MOVES: {len(sorted_moves)}")
        for move in sorted_moves:
            orgs = missing_moves_map[move]
            # Show the move and the FIRST organism that uses it
            print(f"MISSING: [{move}] | Sample User: {orgs[0]}")

if __name__ == "__main__":
    find_missing_moves()

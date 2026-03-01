import os

files = ['dbm_part1.dart', 'dbm_part2.dart', 'dbm_part3.dart', 'dbm_part4.dart', 'dbm_part5.dart']
out_path = os.path.join('lib', 'game', 'double_battle_manager.dart')

with open(out_path, 'w', encoding='utf-8') as outfile:
    for f in files:
        with open(f, 'r', encoding='utf-8') as infile:
            outfile.write(infile.read())
            outfile.write('\n')
        # Clean up part files
        os.remove(f)

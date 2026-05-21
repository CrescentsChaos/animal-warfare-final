import os
import json

sprites_dir = os.path.join('assets', 'sprites')
out_path = os.path.join('assets', 'sprite_list.json')

sprites = []
for f in os.listdir(sprites_dir):
    if f.endswith('.png'):
        sprites.append(f)

with open(out_path, 'w') as f:
    json.dump(sprites, f)

print(f"Generated {len(sprites)} sprites to {out_path}")

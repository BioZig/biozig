import json
import sys

data = json.load(open('eon_report.json'))
dead = [n for n in data['eon_report'] if n['category'] == 'ZERO']
bail = [n for n in data['eon_report'] if n['category'] == 'HIGH']

print('### Category ZERO (Unviable)')
for n in dead:
    ref = f"{n['reference_pos']} ({n['reference_aa']})" if n['reference_pos'] is not None else "-"
    print(f"* **Node {n['node']}** | Ref Pos: `{ref}` | Rigidity: `{n['rigidity']:.4f}` | Degree: `{n['degree']:.4f}`")

print('\n### Category HIGH (Plastic Hubs)')
for n in bail[:15]:
    ref = f"{n['reference_pos']} ({n['reference_aa']})" if n['reference_pos'] is not None else "-"
    print(f"* **Node {n['node']}** | Ref Pos: `{ref}` | Rigidity: `{n['rigidity']:.4f}` | Degree: `{n['degree']:.4f}`")
if len(bail) > 15:
    print(f'*(...and {len(bail)-15} more HIGH nodes)*')

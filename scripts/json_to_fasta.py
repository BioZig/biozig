import json
import sys

def json_to_fasta(json_file, fasta_file):
    with open(json_file, 'r') as f:
        data = json.load(f)
    
    with open(fasta_file, 'w') as f:
        for i, item in enumerate(data.get('sequences', [])):
            header = item.get('header', f'Sequence_{i}')
            header = header.lstrip('>').replace(' ', '_').replace(',', '')
            seq = item.get('sequence', '')
            f.write(f">{header}\n{seq}\n")

if __name__ == "__main__":
    json_to_fasta(sys.argv[1], sys.argv[2])

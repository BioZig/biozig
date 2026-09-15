import json
import sys

def main():
    try:
        with open('data/card/card.json') as f:
            card_data = json.load(f)
    except Exception as e:
        print(f"Error loading card.json: {e}")
        return

    oxa23_entries = []
    
    for obj in card_data.values():
        if type(obj) == dict and 'ARO_name' in obj:
            name = obj['ARO_name'].lower()
            if 'oxa-23' in name:
                oxa23_entries.append(obj)
                
    if not oxa23_entries:
        print("No OXA-23 entries found in CARD.")
        return
        
    print(f"Found {len(oxa23_entries)} OXA-23 entries in CARD.")
    for entry in oxa23_entries:
        print(f"\n--- {entry['ARO_name']} (ARO:{entry.get('ARO_accession', 'N/A')}) ---")
        print(f"Description: {entry.get('ARO_description', 'None')[:200]}...")
        if 'model_sequences' in entry:
            print("Model sequences exist.")
            for seq_id, seq_data in entry['model_sequences'].items():
                if 'mutation' in seq_data or 'variant' in seq_data:
                    print(f"Mutations found: {seq_data}")
        
        # also print any known mutations or SNPs listed in CARD
        if 'SNPs' in entry:
            print(f"Known SNPs: {entry['SNPs']}")

if __name__ == '__main__':
    main()

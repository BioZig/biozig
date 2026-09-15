import urllib.request
import urllib.parse
import xml.etree.ElementTree as ET
import time
import os

def fetch_hiv_protease(output_file, retmax=2500):
    print(f"Searching NCBI Protein database for HIV-1 Protease (target: {retmax} sequences)...")
    
    # Query: HIV-1, protease, length ~99 aa
    query = "HIV-1[Organism] AND protease[ProteinName] AND 90:110[SequenceLength]"
    encoded_query = urllib.parse.quote(query)
    
    search_url = f"https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=protein&term={encoded_query}&retmax={retmax}&usehistory=y"
    
    try:
        response = urllib.request.urlopen(search_url)
        xml_data = response.read()
        root = ET.fromstring(xml_data)
        
        count = int(root.find('Count').text)
        query_key = root.find('QueryKey').text
        webenv = root.find('WebEnv').text
        
        print(f"Found {count} matching sequences. Fetching {min(count, retmax)}...")
        
        fetch_url = f"https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=protein&query_key={query_key}&WebEnv={webenv}&rettype=fasta&retmode=text&retmax={retmax}"
        
        print("Downloading FASTA... (this may take a minute depending on NCBI servers)")
        fasta_response = urllib.request.urlopen(fetch_url)
        fasta_data = fasta_response.read().decode('utf-8')
        
        # Simple QC: ensure we only save up to exactly `retmax`
        sequences = fasta_data.strip().split('\n>')
        if len(sequences) > 1:
            sequences = [sequences[0]] + ['>' + s for s in sequences[1:]]
        
        # Limit to requested amount
        final_sequences = sequences[:retmax]
        
        os.makedirs(os.path.dirname(output_file), exist_ok=True)
        with open(output_file, 'w') as f:
            f.write('\n'.join(final_sequences) + '\n')
            
        print(f"Successfully saved {len(final_sequences)} sequences to {output_file}")
        
    except Exception as e:
        print(f"Error fetching data: {e}")

if __name__ == "__main__":
    fetch_hiv_protease("data/hiv_pr_2500.fasta", 2500)

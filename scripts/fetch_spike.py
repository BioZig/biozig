import os
import sys
import time
from Bio import Entrez
from Bio import SeqIO

Entrez.email = "sulky@example.com"
MAX_RETRIES = 3

def fetch_sars_cov_2_spike(output_file, max_records=2500):
    query = '"SARS-CoV-2"[Organism] AND spike[Protein Name] AND 1200:1300[Sequence Length]'
    print(f"Searching NCBI for: {query}")
    
    handle = Entrez.esearch(db="protein", term=query, retmax=max_records)
    record = Entrez.read(handle)
    handle.close()
    
    id_list = record["IdList"]
    count = len(id_list)
    print(f"Found {count} records. Fetching FASTA...")
    
    if count == 0:
        print("No records found.")
        sys.exit(1)
        
    records_fetched = 0
    batch_size = 500
    
    with open(output_file, "w") as out_f:
        for start in range(0, count, batch_size):
            end = min(count, start + batch_size)
            batch_ids = id_list[start:end]
            print(f"Fetching batch {start+1} to {end}...")
            
            for attempt in range(MAX_RETRIES):
                try:
                    fetch_handle = Entrez.efetch(db="protein", id=batch_ids, rettype="fasta", retmode="text")
                    data = fetch_handle.read()
                    fetch_handle.close()
                    out_f.write(data)
                    records_fetched += len(batch_ids)
                    break
                except Exception as e:
                    print(f"Error on batch: {e}. Retrying in 5 seconds...")
                    time.sleep(5)
            time.sleep(0.5)
            
    print(f"Successfully saved {records_fetched} sequences to {output_file}")

if __name__ == "__main__":
    os.makedirs("data", exist_ok=True)
    fetch_sars_cov_2_spike("data/spike_2500.fasta", max_records=2500)

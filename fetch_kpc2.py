import urllib.request
import json
import xml.etree.ElementTree as ET
import time

def fetch_kpc2():
    print("Searching for KPC-2 (Klebsiella pneumoniae carbapenemase 2) sequences on NCBI Protein...")
    # Search for KPC-2 sequences, limited to 500
    search_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=protein&term=KPC-2%20AND%20Klebsiella%20pneumoniae[Organism]&retmax=500&retmode=json"
    
    req = urllib.request.urlopen(search_url)
    res = json.loads(req.read())
    id_list = res["esearchresult"]["idlist"]
    print(f"Found {len(id_list)} sequences. Fetching FASTA...")
    
    if not id_list:
        print("No sequences found.")
        return

    ids = ",".join(id_list)
    fetch_url = f"https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=protein&id={ids}&rettype=fasta&retmode=text"
    
    req = urllib.request.urlopen(fetch_url)
    fasta_data = req.read().decode("utf-8")
    
    with open("data/kpc2_500.fasta", "w") as f:
        f.write(fasta_data)
        
    print("Saved to data/kpc2_500.fasta")

if __name__ == "__main__":
    fetch_kpc2()

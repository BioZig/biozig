import sys

def preprocess(input_file, output_file):
    node_map = {}
    next_id = 0
    with open(input_file, 'r') as f_in, open(output_file, 'w') as f_out:
        # Skip header if it exists
        first_line = f_in.readline()
        if "protein1" not in first_line:
            f_in.seek(0)
            
        for line in f_in:
            parts = line.strip().split()
            if len(parts) >= 2:
                u, v = parts[0], parts[1]
                if u not in node_map:
                    node_map[u] = next_id
                    next_id += 1
                if v not in node_map:
                    node_map[v] = next_id
                    next_id += 1
                
                weight = parts[2] if len(parts) > 2 else "1.0"
                f_out.write(f"{node_map[u]} {node_map[v]} {weight}\n")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python preprocess_stringdb.py <input_raw.txt> <output_integer.txt>")
        sys.exit(1)
    preprocess(sys.argv[1], sys.argv[2])
    print(f"Preprocessed {sys.argv[1]} into integer-mapped EdgeList: {sys.argv[2]}")

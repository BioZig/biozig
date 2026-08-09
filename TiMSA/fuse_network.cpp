#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <unordered_map>
#include <cmath>
#include <algorithm>

using namespace std;

int main(int argc, char* argv[]) {
    if (argc < 3) {
        cerr << "Usage: " << argv[0] << " <rigidity_out_file> <output_csv>\n";
        return 1;
    }

    string in_file = argv[1];
    string out_file = argv[2];

    ifstream in(in_file);
    if (!in) {
        cerr << "Could not open " << in_file << "\n";
        return 1;
    }

    vector<string> msa;
    vector<double> rigidities;
    string line;
    bool is_consensus = false;

    string current_seq = "";
    while (getline(in, line)) {
        if (line.empty()) continue;
        if (line.find("Loaded") == 0) continue;
        
        if (line.find(">TiMSA_Consensus") == 0) {
            if (!current_seq.empty()) {
                msa.push_back(current_seq);
                current_seq = "";
            }
            is_consensus = true;
            continue;
        }
        if (line[0] == '>') {
            if (!current_seq.empty()) {
                msa.push_back(current_seq);
                current_seq = "";
            }
            is_consensus = false;
            continue;
        }

        if (line.find("Col ") == 0) {
            if (!current_seq.empty()) {
                msa.push_back(current_seq);
                current_seq = "";
            }
            size_t colon = line.find(':');
            if (colon != string::npos) {
                string val_str = line.substr(colon + 1);
                rigidities.push_back(stod(val_str));
            }
        } else {
            if (!is_consensus) {
                line.erase(line.find_last_not_of(" \n\r\t") + 1);
                current_seq += line;
            }
        }
    }
    if (!current_seq.empty()) {
        msa.push_back(current_seq);
    }

    cout << "Read " << msa.size() << " sequences and " << rigidities.size() << " rigidity floats.\n";
    if (msa.empty() || rigidities.empty()) return 1;

    size_t num_cols = msa[0].size();
    size_t cols_to_process = min(num_cols, rigidities.size());

    ofstream out(out_file);
    out << "Source,Target,Weight\n";

    double n_f = msa.size();
    
    for (size_t i = 0; i < cols_to_process; ++i) {
        double h_i = 0;
        unordered_map<char, double> counts_i;
        for (const auto& seq : msa) counts_i[seq[i]]++;
        for (auto kv : counts_i) {
            double p = kv.second / n_f;
            h_i -= p * log2(p);
        }
        if (h_i == 0) continue;

        for (size_t j = i + 1; j < cols_to_process; ++j) {
            double h_j = 0;
            unordered_map<char, double> counts_j;
            for (const auto& seq : msa) counts_j[seq[j]]++;
            for (auto kv : counts_j) {
                double p = kv.second / n_f;
                h_j -= p * log2(p);
            }
            if (h_j == 0) continue;

            unordered_map<string, double> joint;
            for (size_t s = 0; s < msa.size(); ++s) {
                string pair = "";
                pair += msa[s][i];
                pair += msa[s][j];
                joint[pair]++;
            }

            double h_ij = 0;
            for (auto kv : joint) {
                double p = kv.second / n_f;
                h_ij -= p * log2(p);
            }

            double mi = h_i + h_j - h_ij;
            if (mi > 0.00001) {
                double weight = mi * (abs(rigidities[i]) + abs(rigidities[j]));
                if (weight > 0.0) {
                    out << "Col_" << i << ",Col_" << j << "," << weight << "\n";
                }
            }
        }
    }
    cout << "Fusion complete. Output written to " << out_file << "\n";
    return 0;
}

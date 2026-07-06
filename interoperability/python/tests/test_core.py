import unittest
from biozig import (
    BioZigContext,
    ping,
    align_global,
    shannon_entropy,
    translate_dna,
    hamming_distance,
    levenshtein_distance,
    DeBruijnGraph,
    search_motif_exact,
    count_kmers,
    SuffixTree,
    FMIndex,
)

class TestBioZigCore(unittest.TestCase):
    def test_ping(self):
        self.assertEqual(ping(), 42)

    def test_context_and_alignment(self):
        with BioZigContext() as ctx:
            res = align_global("ACGT", "ACGC", 1, -1, -1)
            self.assertIn("score", res)
            
    def test_entropy_and_translation(self):
        with BioZigContext():
            ent = shannon_entropy("ACGT")
            self.assertGreater(ent, 0.0)
            
            prot = translate_dna("ATGCAA")
            self.assertEqual(prot, "MQ")
            
    def test_distances(self):
        with BioZigContext():
            h = hamming_distance("ACGT", "ACGC")
            self.assertEqual(h, 1)
            l = levenshtein_distance("ACGT", "ACGC")
            self.assertEqual(l, 1)

    def test_graphs_and_trees(self):
        with BioZigContext():
            dbg = DeBruijnGraph(3)
            dbg.add_sequence("ACGTC")
            
            tree = SuffixTree("ACGTACGT")
            
            fmi = FMIndex("ACGTACGT")
            c = fmi.count("CGT")
            self.assertIsNotNone(c)
            
    def test_motif_and_kmers(self):
        with BioZigContext():
            kmers = count_kmers("ACGT", 2)
            self.assertEqual(kmers, 3)
            
            hits = search_motif_exact("ACGTACGT", "CGT")
            self.assertEqual(len(hits), 2)

if __name__ == '__main__':
    unittest.main()

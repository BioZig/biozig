import ctypes
from .core import lib

lib.biozig_hamming_distance.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
lib.biozig_hamming_distance.restype = ctypes.c_longlong

lib.biozig_levenshtein_distance.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
lib.biozig_levenshtein_distance.restype = ctypes.c_longlong

def hamming_distance(seq_a: str, seq_b: str) -> int:
    res = lib.biozig_hamming_distance(seq_a.encode('utf-8'), seq_b.encode('utf-8'))
    if res == -1:
        raise ValueError("Error computing hamming distance (perhaps context not initialized, or invalid DNA)")
    return res

def levenshtein_distance(seq_a: str, seq_b: str) -> int:
    res = lib.biozig_levenshtein_distance(seq_a.encode('utf-8'), seq_b.encode('utf-8'))
    if res == -1:
        raise ValueError("Error computing levenshtein distance (perhaps context not initialized, or invalid DNA)")
    return res

class CBiozigDeBruijnGraph(ctypes.Structure):
    _fields_ = [("ptr", ctypes.c_void_p)]

lib.biozig_debruijn_graph_create.argtypes = [ctypes.c_int]
lib.biozig_debruijn_graph_create.restype = CBiozigDeBruijnGraph

lib.biozig_debruijn_graph_add_sequence.argtypes = [CBiozigDeBruijnGraph, ctypes.c_char_p]
lib.biozig_debruijn_graph_add_sequence.restype = ctypes.c_int

lib.biozig_debruijn_graph_destroy.argtypes = [CBiozigDeBruijnGraph]
lib.biozig_debruijn_graph_destroy.restype = None

class DeBruijnGraph:
    def __init__(self, k: int):
        self._dbg = lib.biozig_debruijn_graph_create(k)
        if not self._dbg.ptr:
            raise RuntimeError("Failed to create DeBruijnGraph")
            
    def add_sequence(self, seq: str):
        res = lib.biozig_debruijn_graph_add_sequence(self._dbg, seq.encode('utf-8'))
        if res != 0:
            raise ValueError("Failed to add sequence to DeBruijnGraph")

class CBiozigMotifHits(ctypes.Structure):
    _fields_ = [("positions", ctypes.POINTER(ctypes.c_longlong)),
                ("count", ctypes.c_int)]

lib.biozig_search_motif_exact.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
lib.biozig_search_motif_exact.restype = CBiozigMotifHits

def search_motif_exact(seq: str, motif: str):
    res = lib.biozig_search_motif_exact(seq.encode('utf-8'), motif.encode('utf-8'))
    if not res.positions and res.count == 0:
        return []
    return [res.positions[i] for i in range(res.count)]

lib.biozig_count_kmers.argtypes = [ctypes.c_char_p, ctypes.c_int]
lib.biozig_count_kmers.restype = ctypes.c_longlong

def count_kmers(seq: str, k: int) -> int:
    res = lib.biozig_count_kmers(seq.encode('utf-8'), k)
    if res == -1:
        raise ValueError("Error counting kmers")
    return res

class CBiozigSuffixTree(ctypes.Structure):
    _fields_ = [("ptr", ctypes.c_void_p)]

lib.biozig_suffix_tree_create.argtypes = [ctypes.c_char_p]
lib.biozig_suffix_tree_create.restype = CBiozigSuffixTree
lib.biozig_suffix_tree_destroy.argtypes = [CBiozigSuffixTree]
lib.biozig_suffix_tree_destroy.restype = None

class SuffixTree:
    def __init__(self, seq: str):
        self._tree = lib.biozig_suffix_tree_create(seq.encode('utf-8'))
        if not self._tree.ptr:
            raise RuntimeError("Failed to create SuffixTree")

class CBiozigFMIndex(ctypes.Structure):
    _fields_ = [("ptr", ctypes.c_void_p)]

class CBiozigRange(ctypes.Structure):
    _fields_ = [("start", ctypes.c_longlong), ("end", ctypes.c_longlong)]

lib.biozig_fmindex_create.argtypes = [ctypes.c_char_p]
lib.biozig_fmindex_create.restype = CBiozigFMIndex

lib.biozig_fmindex_count.argtypes = [CBiozigFMIndex, ctypes.c_char_p]
lib.biozig_fmindex_count.restype = CBiozigRange

lib.biozig_fmindex_destroy.argtypes = [CBiozigFMIndex]
lib.biozig_fmindex_destroy.restype = None

class FMIndex:
    def __init__(self, seq: str):
        self._fmi = lib.biozig_fmindex_create(seq.encode('utf-8'))
        if not self._fmi.ptr:
            raise RuntimeError("Failed to create FMIndex")
            
    def count(self, query: str):
        res = lib.biozig_fmindex_count(self._fmi, query.encode('utf-8'))
        if res.start == -1 and res.end == -1:
            raise ValueError("Error counting in FMIndex")
        return (res.start, res.end)

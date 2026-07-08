import ctypes
import os
import platform
import sys

def _load_library():
    # Attempt to load the biozig shared library
    base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    lib_dir = os.path.join(base_dir, "zig-out", "lib")
    
    system = platform.system()
    if system == "Darwin":
        lib_name = "libbiozig.dylib"
    elif system == "Windows":
        lib_name = "biozig.dll"
    else:
        lib_name = "libbiozig.so"
        
    lib_path = os.path.join(lib_dir, lib_name)
    
    if not os.path.exists(lib_path):
        # Fallback to current directory for testing if needed
        if os.path.exists(lib_name):
            lib_path = lib_name
        else:
            raise FileNotFoundError(f"Could not find BioZig shared library at {lib_path}")
            
    return ctypes.CDLL(lib_path)

lib = _load_library()

# Setup C types for core functions
lib.biozig_context_create.argtypes = []
lib.biozig_context_create.restype = ctypes.c_int

lib.biozig_context_destroy.argtypes = []
lib.biozig_context_destroy.restype = ctypes.c_int

lib.biozig_ping.argtypes = []
lib.biozig_ping.restype = ctypes.c_int

class CBiozigAlignmentResult(ctypes.Structure):
    _fields_ = [
        ("score", ctypes.c_int),
        ("aligned_a", ctypes.c_char_p),
        ("aligned_b", ctypes.c_char_p),
    ]

lib.biozig_align_global.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
lib.biozig_align_global.restype = CBiozigAlignmentResult

lib.biozig_shannon_entropy.argtypes = [ctypes.c_char_p]
lib.biozig_shannon_entropy.restype = ctypes.c_double

lib.biozig_translate_dna.argtypes = [ctypes.c_char_p]
lib.biozig_translate_dna.restype = ctypes.c_char_p

# Network streaming endpoints
lib.biozig_net_start.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
lib.biozig_net_start.restype = ctypes.c_void_p

lib.biozig_net_read_chunk.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t]
lib.biozig_net_read_chunk.restype = ctypes.c_size_t

lib.biozig_net_stop.argtypes = [ctypes.c_void_p]
lib.biozig_net_stop.restype = None



class BioZigContext:
    def __init__(self):
        self._active = False
        
    def __enter__(self):
        res = lib.biozig_context_create()
        if res != 0:
            raise RuntimeError("Failed to create BioZig context (perhaps already initialized?)")
        self._active = True
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self._active:
            lib.biozig_context_destroy()
            self._active = False

def ping():
    return lib.biozig_ping()

def align_global(seq_a: str, seq_b: str, match_score: int = 1, mismatch_penalty: int = -1, gap_penalty: int = -1):
    res = lib.biozig_align_global(seq_a.encode('utf-8'), seq_b.encode('utf-8'), match_score, mismatch_penalty, gap_penalty)
    if res.score == -999999:
        raise ValueError("Alignment failed or context not initialized.")
    return {
        'score': res.score,
        'aligned_a': res.aligned_a.decode('utf-8'),
        'aligned_b': res.aligned_b.decode('utf-8')
    }

def shannon_entropy(seq: str) -> float:
    return lib.biozig_shannon_entropy(seq.encode('utf-8'))

def translate_dna(seq: str) -> str:
    res = lib.biozig_translate_dna(seq.encode('utf-8'))
    if res is None:
        raise ValueError("Translation failed or context not initialized.")
    return res.decode('utf-8')

def stream_genome(db: str, query: str):
    """
    Generator that streams a genome dynamically from a database over the network.
    The background Zig thread handles network I/O, while Python consumes the O(1) buffer.
    """
    handle = lib.biozig_net_start(db.encode('utf-8'), query.encode('utf-8'))
    if not handle:
        raise RuntimeError(f"Failed to start network stream for {db} : {query}. (Ensure context is created)")
    
    buf_size = 8192
    buffer = ctypes.create_string_buffer(buf_size)
    
    try:
        while True:
            # We explicitly allow other Python threads to run while Zig blocks on network condition variables
            bytes_read = lib.biozig_net_read_chunk(handle, buffer, buf_size)
            if bytes_read == 0:
                break
            yield buffer.raw[:bytes_read]
    finally:
        lib.biozig_net_stop(handle)

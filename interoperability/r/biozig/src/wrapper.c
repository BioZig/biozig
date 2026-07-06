#include <R.h>
#include <Rinternals.h>

// Forward declarations from BioZig C-ABI
int biozig_context_create();
int biozig_context_destroy();
int biozig_ping();
double biozig_shannon_entropy(const char* seq_c);
const char* biozig_translate_dna(const char* seq_c);

struct CBiozigAlignmentResult {
    int score;
    const char* aligned_a;
    const char* aligned_b;
};

struct CBiozigAlignmentResult biozig_align_global(
    const char* seq_a_c,
    const char* seq_b_c,
    int match_score,
    int mismatch_penalty,
    int gap_penalty
);

SEXP r_biozig_context_create() {
    int res = biozig_context_create();
    return ScalarInteger(res);
}

SEXP r_biozig_context_destroy() {
    int res = biozig_context_destroy();
    return ScalarInteger(res);
}

SEXP r_biozig_ping() {
    int res = biozig_ping();
    return ScalarInteger(res);
}

SEXP r_biozig_shannon_entropy(SEXP seq) {
    if (!isString(seq) || length(seq) == 0) {
        error("seq must be a string");
    }
    const char* c_seq = CHAR(STRING_ELT(seq, 0));
    double res = biozig_shannon_entropy(c_seq);
    return ScalarReal(res);
}

SEXP r_biozig_translate_dna(SEXP seq) {
    if (!isString(seq) || length(seq) == 0) {
        error("seq must be a string");
    }
    const char* c_seq = CHAR(STRING_ELT(seq, 0));
    const char* res = biozig_translate_dna(c_seq);
    if (!res) {
        return R_NilValue;
    }
    return mkString(res);
}

SEXP r_biozig_align_global(SEXP seq_a, SEXP seq_b, SEXP match, SEXP mismatch, SEXP gap) {
    if (!isString(seq_a) || !isString(seq_b)) {
        error("seq_a and seq_b must be strings");
    }
    const char* c_seq_a = CHAR(STRING_ELT(seq_a, 0));
    const char* c_seq_b = CHAR(STRING_ELT(seq_b, 0));
    int c_match = asInteger(match);
    int c_mismatch = asInteger(mismatch);
    int c_gap = asInteger(gap);
    
    struct CBiozigAlignmentResult res = biozig_align_global(c_seq_a, c_seq_b, c_match, c_mismatch, c_gap);
    
    const char* names[] = {"score", "aligned_a", "aligned_b", ""};
    SEXP list = PROTECT(mkNamed(VECSXP, names));
    SET_VECTOR_ELT(list, 0, ScalarInteger(res.score));
    SET_VECTOR_ELT(list, 1, res.aligned_a ? mkString(res.aligned_a) : R_NilValue);
    SET_VECTOR_ELT(list, 2, res.aligned_b ? mkString(res.aligned_b) : R_NilValue);
    UNPROTECT(1);
    
    return list;
}

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Simulated header for the exported BioZig C ABI
extern int biozig_context_create();
extern int biozig_context_destroy();
extern int biozig_ping();

typedef struct {
    int score;
    const char* aligned_a;
    const char* aligned_b;
} CBiozigAlignmentResult;

extern CBiozigAlignmentResult biozig_align_global(
    const char* seq_a,
    const char* seq_b,
    int match_score,
    int mismatch_penalty,
    int gap_penalty
);

extern double biozig_shannon_entropy(const char* seq);
extern const char* biozig_translate_dna(const char* seq);

int main() {
    printf("[C-ABI] Initializing BioZig Context...\n");
    if (biozig_context_create() != 0) {
        fprintf(stderr, "Failed to initialize context!\n");
        return 1;
    }

    printf("[C-ABI] Context Ping = %d\n", biozig_ping());

    const char* seq1 = "ACACACTA";
    const char* seq2 = "AGCACACA";
    
    printf("[C-ABI] Executing Needleman-Wunsch Alignment...\n");
    printf("[C-ABI] Sequence 1: %s\n", seq1);
    printf("[C-ABI] Sequence 2: %s\n", seq2);

    CBiozigAlignmentResult res = biozig_align_global(seq1, seq2, 2, -1, -2);
    
    if (res.score == -999999) {
        fprintf(stderr, "Alignment failed natively inside Zig Engine.\n");
        return 1;
    }

    printf("[C-ABI] Alignment Successful!\n");
    printf("Score: %d\n", res.score);
    printf("Algn A: %s\n", res.aligned_a);
    printf("Algn B: %s\n", res.aligned_b);

    printf("\n[C-ABI] Executing DNA Translation...\n");
    const char* coding_seq = "ATGCGTACGTTAGCCTAG";
    const char* protein = biozig_translate_dna(coding_seq);
    if (!protein) {
        fprintf(stderr, "Translation failed natively inside Zig Engine.\n");
        return 1;
    }
    printf("DNA:     %s\n", coding_seq);
    printf("Protein: %s\n", protein);

    printf("\n[C-ABI] Executing Shannon Entropy...\n");
    double entropy = biozig_shannon_entropy(coding_seq);
    printf("Sequence: %s\n", coding_seq);
    printf("Entropy:  %.4f bits\n", entropy);

    printf("\n[C-ABI] Destroying Context Arena...\n");
    if (biozig_context_destroy() != 0) {
        fprintf(stderr, "Failed to destroy context!\n");
        return 1;
    }

    printf("[C-ABI] All Memory Flushed. Exit Code 0.\n");
    return 0;
}
